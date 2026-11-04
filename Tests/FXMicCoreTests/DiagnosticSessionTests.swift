import XCTest
@testable import FXMicCore

final class DiagnosticSessionTests: XCTestCase {
    private func session() -> DiagnosticSession {
        DiagnosticSession(metadata: .init(appVersion: "test", appBuild: "0", osVersion: "test",
            inputName: "Synthetic input", initialThresholdDB: -45, sampleRate: 48000,
            channelCount: 2, notes: "Synthetic fixture; no hardware"), uptime: 100)
    }

    private func frame(at time: Double) -> SignalSnapshot {
        let tone = (0..<4096).map { Float(0.5 * sin(2 * .pi * 2300 * Double($0) / 48000)) }
        return SignalAnalyzer().analyze(channels: [tone, tone.map { $0 * 0.1 }], sampleRate: 48000, time: time)!
    }

    func testCountdownDoesNotContaminateMeasuredStep() {
        let session = session()
        session.append(frame(at: 99), threshold: -45)
        XCTAssertTrue(session.report.measurements.isEmpty)
        session.append(frame(at: 100.5), threshold: -45)
        session.beginStep(at: 101)
        session.append(frame(at: 103), threshold: -45)
        session.append(frame(at: 104), threshold: -45)
        XCTAssertEqual(session.report.measurements.map(\.phase), ["ready", "countdown", "measuring"])
        XCTAssertEqual(session.secondsRemaining(at: 103), 1)
        XCTAssertEqual(session.secondsRemaining(at: 104), 6)
        XCTAssertTrue(session.tick(at: 110))
        XCTAssertEqual(session.currentStep?.id, "held_silent")
        XCTAssertEqual(session.report.stepResults.first?.measurementStartedAt, 4)
        XCTAssertEqual(session.report.stepResults.first?.endedAt, 10)
        XCTAssertEqual(session.phase(at: 111), "ready")
    }

    func testInterruptionIsExportedAndRecordingStops() throws {
        let session = session()
        session.beginStep(at: 100)
        session.append(frame(at: 104), threshold: -45)
        session.event("Input disconnected", at: 105)
        session.finish(reason: "Input disconnected", at: 105)
        session.finish(reason: "Other reason", at: 106)
        session.append(frame(at: 107), threshold: -45)
        XCTAssertEqual(session.report.measurements.count, 1)
        XCTAssertEqual(session.report.stepResults.first?.outcome, "interrupted")
        XCTAssertEqual(session.report.endReason, "Input disconnected")
        XCTAssertTrue(session.report.events.contains { $0.message == "Input disconnected" })
        let decoded = try JSONDecoder.diagnostic.decode(DiagnosticReport.self, from: session.report.encoded())
        XCTAssertEqual(decoded.endReason, "Input disconnected")
        XCTAssertFalse(decoded.metadata.rawAudioIncluded)
    }

    func testSilenceAndNoSignalAreRecorded() {
        let session = session()
        session.beginStep(at: 100)
        let silence = SignalAnalyzer().analyze(channels: [[Float](repeating: 0, count: 4096)], sampleRate: 48000, time: 104)!
        session.append(silence, threshold: -45)
        XCTAssertEqual(session.report.measurements.first?.rmsDB, -120)
        XCTAssertEqual(session.report.measurements.first?.signalPresent, false)
        XCTAssertEqual(session.report.measurements.first?.phase, "measuring")
    }

    func testAllStepsCompleteAndSkippedStepsStayExplicit() {
        let session = session()
        session.skipStep(at: 101)
        XCTAssertEqual(session.report.stepResults.first?.outcome, "skipped")
        var now = 102.0
        while let step = session.currentStep {
            session.beginStep(at: now)
            now += 3 + step.duration
            session.tick(at: now)
        }
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.report.stepResults.count, DiagnosticStep.hardwareCheck.count)
        XCTAssertEqual(session.report.stepResults.filter { $0.outcome == "skipped" }.count, 1)
        XCTAssertEqual(session.report.endReason, "Protocol finished (includes skipped steps)")
    }

    func testReportContainsCompactSpectrumAndPerChannelMeasurements() throws {
        let session = session()
        session.beginStep(at: 100)
        session.append(frame(at: 104), threshold: -45)
        let measurement = try XCTUnwrap(session.report.measurements.first)
        XCTAssertEqual(measurement.channelRMSDB.count, 2)
        XCTAssertEqual(measurement.channelRMSDB[0] - measurement.channelRMSDB[1], 20, accuracy: 0.01)
        XCTAssertEqual(measurement.spectrumBandsDB.count, 64)
        XCTAssertEqual(try XCTUnwrap(measurement.spectralPeaks.first?.frequencyHz), 2300, accuracy: 12)
        XCTAssertLessThanOrEqual(measurement.spectralPeaks.count, 6)
        XCTAssertEqual(measurement.spectrumAgeSeconds, 0)
        let json = String(decoding: try session.report.encoded(), as: UTF8.self)
        XCTAssertFalse(json.contains("spectrumDB"))
        XCTAssertFalse(json.contains("transcript"))
        XCTAssertLessThan(json.utf8.count, 16000)
    }

    func testFiveMinuteLimitAndDuplicateFrameProtection() {
        let session = session()
        let frame = frame(at: 101)
        session.append(frame, threshold: -45)
        session.append(frame, threshold: -45)
        session.append(self.frame(at: 400), threshold: -45)
        XCTAssertEqual(session.report.measurements.count, 1)
        XCTAssertTrue(session.tick(at: 400))
        XCTAssertTrue(session.isFinished)
        XCTAssertEqual(session.report.durationSeconds, 300)
    }

    func testSummaryScriptReadsSwiftReportAndExcludesPreparation() throws {
        let session = session()
        session.append(frame(at: 100.5), threshold: -45)
        session.beginStep(at: 101)
        session.append(frame(at: 103), threshold: -45)
        let silence = SignalAnalyzer().analyze(channels: [[Float](repeating: 0, count: 4096)],
                                               sampleRate: 48000, time: 104)!
        session.append(silence, threshold: -45)
        session.tick(at: 110)
        session.beginStep(at: 111)
        session.append(frame(at: 115), threshold: -45)
        // A concentrated peak at the noise floor must not be summarized as a useful tone.
        let quietTone = (0..<4096).map { Float(0.0001 * sin(2 * .pi * 3100 * Double($0) / 48000)) }
        let quietFrame = SignalAnalyzer().analyze(channels: [quietTone], sampleRate: 48000, time: 115.1)!
        XCTAssertGreaterThan(quietFrame.peakConcentration, 0.8)
        XCTAssertNotNil(quietFrame.dominantFrequency)
        session.append(quietFrame, threshold: -45)
        session.finish(reason: "Synthetic export test", at: 116)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fxmic-\(UUID()).json")
        try session.report.encoded().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [root.appendingPathComponent("script/summarize_diagnostic.py").path, url.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0, output)
        XCTAssertTrue(output.contains("| Trigger released | completed | 1 | -120.0 / -120.0 / -120.0 | -120.0 | — |"), output)
        XCTAssertTrue(output.contains("| Trigger held · quiet | interrupted | 2 |"), output)
        XCTAssertTrue(output.contains("median 2300; 1 frame"), output)
    }

    func testShortHandleCheckFinishesAfterThreeSteps() {
        let short = DiagnosticSession(metadata: session().report.metadata, uptime: 100, check: .handle)
        XCTAssertEqual(short.report.protocolSteps.map(\.id), ["released", "held_silent", "held_speaking"])
        var now = 100.0
        while let step = short.currentStep {
            short.beginStep(at: now)
            now += 3 + step.duration
            short.tick(at: now)
        }
        XCTAssertTrue(short.isFinished)
        XCTAssertEqual(short.report.stepResults.count, 3)
        XCTAssertEqual(short.report.endReason, "Protocol completed")
    }

    func testOldReportsDecodeWithoutPreparationInstructions() throws {
        let report = session().report
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: report.encoded()) as? [String: Any])
        let steps = try XCTUnwrap(json["protocolSteps"] as? [[String: Any]])
        json["protocolSteps"] = steps.map { step in
            var oldStep = step
            oldStep.removeValue(forKey: "preparation")
            return oldStep
        }
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder.diagnostic.decode(DiagnosticReport.self, from: data)
        XCTAssertEqual(decoded.protocolSteps.map(\.id), report.protocolSteps.map(\.id))
        XCTAssertTrue(decoded.protocolSteps.allSatisfy { $0.preparation == nil })
    }
}

private extension JSONDecoder {
    static var diagnostic: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
