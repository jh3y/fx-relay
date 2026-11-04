import XCTest
@testable import FXMicCore

final class HardwareProbeTests: XCTestCase {
    private func session() -> DiagnosticSession {
        DiagnosticSession(metadata: .init(appVersion: "test", appBuild: "0", osVersion: "test",
            inputName: "Synthetic", initialThresholdDB: -45, sampleRate: 48000,
            channelCount: 1, notes: "Synthetic input"), uptime: 100, check: .fxButton)
    }

    private func window(_ start: Double, _ end: Double) -> ProbeWindow {
        ProbeWindow(startUptime: start, endUptime: end, sampleRate: 48000,
                    sampleCount: Int(((end - start) * 48000).rounded()), channels: [])
    }

    func testOneSampleClicksAndTrailingSamplesSurviveEveryWindow() {
        var input = [Float](repeating: 0, count: 1025)
        input[479] = 0.5; input[480] = -1; input[1024] = 0.25
        let windows = HardwareProbe.analyze(channels: [input, input.map { _ in 0 }], sampleRate: 48000, receivedAt: 10)
        XCTAssertEqual(windows.map(\.sampleCount), [480, 480, 65])
        XCTAssertEqual(windows.reduce(0) { $0 + $1.sampleCount }, input.count)
        XCTAssertEqual(windows[0].channels[0].peakDB, 20 * log10(0.5), accuracy: 0.001)
        XCTAssertEqual(windows[1].channels[0].peakDB, 0, accuracy: 0.001)
        XCTAssertEqual(windows[2].channels[0].peakDB, 20 * log10(0.25), accuracy: 0.001)
        XCTAssertEqual(windows[1].channels[0].maximumSampleChange, 1.5)
        XCTAssertEqual(windows[0].channels[1].rmsDB, -120)
        XCTAssertEqual(windows.last!.endUptime, 10, accuracy: 0.000001)
    }

    func testCommonRatesAndDCStatisticsWithoutAudioRetention() throws {
        for rate in [8000.0, 44100, 48000, 96000] {
            let input = [Float](repeating: 0.25, count: Int(rate * 0.023))
            let windows = HardwareProbe.analyze(channels: [input], sampleRate: rate, receivedAt: 5)
            XCTAssertEqual(windows.reduce(0) { $0 + $1.sampleCount }, input.count)
            XCTAssertTrue(windows.allSatisfy { $0.endUptime - $0.startUptime <= 0.010001 })
            XCTAssertEqual(windows[0].channels[0].rmsDB, 20 * log10(0.25), accuracy: 0.001)
            XCTAssertEqual(windows[0].channels[0].mean, 0.25)
            XCTAssertEqual(windows[0].channels[0].maximumSampleChange, 0)
        }
        XCTAssertTrue(HardwareProbe.analyze(channels: [[.nan]], sampleRate: 48000, receivedAt: 5).isEmpty)
        XCTAssertTrue(HardwareProbe.analyze(channels: [[0], []], sampleRate: 48000, receivedAt: 5).isEmpty)
        XCTAssertTrue(HardwareProbe.analyze(channels: [[0]], sampleRate: .infinity, receivedAt: 5).isEmpty)
    }

    func testProbeLabelsCountdownBoundariesAndLateDeliveryUsingCaptureTime() {
        let s = session(), id = session().report.id
        s.beginStep(at: 100)
        s.appendProbe([window(101, 101.01)], sessionID: id) // another session must be ignored
        XCTAssertEqual(s.report.hardwareProbe?.measurements.count, 0)
        s.appendProbe([window(102, 102.01), window(102.995, 103.005), window(104, 104.01)], sessionID: s.report.id)
        s.tick(at: 109.1)
        s.appendProbe([window(108.9, 108.91)], sessionID: s.report.id)
        XCTAssertEqual(s.report.hardwareProbe?.measurements.map(\.phase), ["countdown", "boundary", "measuring", "measuring"])
        XCTAssertEqual(s.report.hardwareProbe?.measurements.last?.stepID, "fx_baseline")
        XCTAssertEqual(s.currentStep?.id, "fx_handling_before")
    }

    func testProbeBoundedAndStoppedReportsRejectNewData() {
        let s = session()
        let capacity = s.report.hardwareProbe!.capacity
        s.appendProbe([window(99.99, 100)], sessionID: s.report.id)
        s.appendProbe(Array(repeating: window(101, 101.01), count: capacity + 2), sessionID: s.report.id)
        XCTAssertEqual(s.report.hardwareProbe?.measurements.count, capacity)
        XCTAssertEqual(s.report.hardwareProbe?.omittedWindows, 3)
        s.finish(reason: "Stopped", at: 102)
        s.appendProbe([window(102, 102.01)], sessionID: s.report.id)
        XCTAssertEqual(s.report.hardwareProbe?.measurements.count, capacity)
        XCTAssertEqual(s.report.hardwareProbe?.omittedWindows, 3)
    }

    func testProtocolAndObservationsRoundTripWithoutProbeInOlderReports() throws {
        let s = session()
        XCTAssertEqual(s.report.protocolSteps.count, 12)
        XCTAssertEqual(s.report.protocolSteps.filter { $0.id.hasPrefix("fx_press_") }.count, 6)
        s.setObservation("FX1; accidentally pressed twice", for: "fx_press_1")
        s.setObservation("ignored", for: "not_a_step")
        s.appendProbe(HardwareProbe.analyze(channels: [[Float](repeating: 0, count: 480)], sampleRate: 48000, receivedAt: 104), sessionID: s.report.id)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(DiagnosticReport.self, from: s.report.encoded())
        XCTAssertEqual(decoded.stepObservations?.count, 1)
        XCTAssertEqual(decoded.stepObservations?["fx_press_1"], "FX1; accidentally pressed twice")
        XCTAssertEqual(decoded.hardwareProbe?.measurements.count, 1)
        XCTAssertFalse(decoded.metadata.rawAudioIncluded)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: s.report.encoded()) as? [String: Any])
        json.removeValue(forKey: "hardwareProbe"); json.removeValue(forKey: "stepObservations")
        let old = try decoder.decode(DiagnosticReport.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.hardwareProbe); XCTAssertNil(old.stepObservations)
    }

    func testSummaryScriptIncludesFineClicksButExcludesCountdown() throws {
        let s = session()
        s.beginStep(at: 100)
        // A loud preparation signal must not hide a quiet measured baseline.
        for (time, value) in [(102.0, Float(1)), (104.0, Float(0))] {
            s.appendProbe(HardwareProbe.analyze(channels: [[Float](repeating: value, count: 480)],
                sampleRate: 48000, receivedAt: time), sessionID: s.report.id)
        }
        s.finish(reason: "Synthetic export", at: 105)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fxmic-probe-\(UUID()).json")
        try s.report.encoded().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [root.appendingPathComponent("script/summarize_diagnostic.py").path, url.path]
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, output)
        XCTAssertTrue(output.contains("| Quiet baseline | 1 | 0.010 | -120.0 / -120.0 | -120.0 | — |"), output)
        XCTAssertTrue(output.contains("Omitted windows: 0; capacity: 40000"), output)
    }
}
