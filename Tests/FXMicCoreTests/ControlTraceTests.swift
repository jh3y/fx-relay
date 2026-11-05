import XCTest
@testable import FXMicCore

final class ControlTraceTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_793_306_571.125)

    private func checkpoint(_ time: Double, active: Bool = false, running: Bool = true,
                            latest: Double? = nil) -> ControlStateCheckpoint {
        .init(observedAtUptime: time, lastControlBlockEndUptime: latest,
              pttActive: active, captureRunning: running)
    }

    private func frames(_ samples: [Float], configuration: BridgeConfiguration = .init()) -> [ControlFrame] {
        let analyzer = ControlAnalyzer(configuration: configuration)
        return stride(from: 0, to: samples.count, by: 512).flatMap { offset in
            let end = min(offset + 512, samples.count)
            return analyzer.analyze(samples: Array(samples[offset..<end]), sampleRate: 48000,
                channel: 1, time: Double(end) / 48000)
        }
    }

    private func pulse() -> [Float] {
        // Thirty milliseconds inside the second 40 ms detector block. A 5 Hz
        // instantaneous level export at 0.0, 0.2, ... seconds misses this input.
        [Float](repeating: 0, count: 2048) + [Float](repeating: 0.02, count: 1440)
            + [Float](repeating: 0, count: 60000)
    }

    private var immediate: BridgeConfiguration {
        var config = BridgeConfiguration(); config.activationDelay = 0; return config
    }

    func testShortBurstSurvivesExportWithCorrectLookaheadAndReleaseTiming() throws {
        let input = pulse()
        for index in stride(from: 0, to: input.count, by: 9600) { XCTAssertEqual(input[index], 0) }
        let output = frames(input, configuration: immediate)
        var recorder = ControlTraceRecorder()
        recorder.begin(at: date, state: checkpoint(0), reason: "test")
        for frame in output { recorder.append(frame, receivedAtUptime: frame.time + 0.003) }
        let report = try XCTUnwrap(recorder.snapshot(finalState: checkpoint(1.4)))
        XCTAssertEqual(report.samples.count, output.count)
        let transitions = report.samples.filter { $0.pttEvaluation?.transition != nil }
        XCTAssertEqual(transitions.compactMap { $0.pttEvaluation?.transition }, [true, false])
        let down = try XCTUnwrap(transitions.first)
        let evaluation = try XCTUnwrap(down.pttEvaluation)
        XCTAssertEqual(evaluation.blockEndUptime, 0.08, accuracy: 0.000001)
        XCTAssertEqual(down.blockEndUptime - evaluation.blockEndUptime, 0.04, accuracy: 0.000001)
        XCTAssertGreaterThan(evaluation.rmsDB, -60)
        XCTAssertLessThan(down.rmsDB, -100) // The current/lookahead block is already quiet.
        XCTAssertFalse(evaluation.activeBefore)
        XCTAssertTrue(evaluation.activeAfter)
        XCTAssertFalse(evaluation.suppressed)
        let up = try XCTUnwrap(transitions.last?.pttEvaluation)
        XCTAssertGreaterThanOrEqual(up.blockEndUptime - 0.12, 0.9)
        XCTAssertLessThan(up.blockEndUptime - 0.12, 0.941)
        XCTAssertFalse(report.finalState.pttActive)
        XCTAssertNil(report.samples.first?.pttEvaluation) // No invented evaluation during warmup.
    }

    func testCueSuppressionIsRecordedWithoutChangingDetections() throws {
        let samples = (0..<14400).map { Float(0.2 * sin(2 * .pi * 2300 * Double($0) / 48000)) }
            + [Float](repeating: 0, count: 24000)
        var recorder = ControlTraceRecorder()
        recorder.begin(at: date, state: checkpoint(0), reason: "cue")
        for frame in frames(samples) { recorder.append(frame, receivedAtUptime: frame.time) }
        let report = try XCTUnwrap(recorder.snapshot(finalState: checkpoint(0.8)))
        XCTAssertEqual(report.samples.compactMap(\.toneDetected), [2]) // One-based exported cue.
        XCTAssertTrue(report.samples.contains { $0.pttEvaluation?.suppressed == true })
        XCTAssertTrue(report.samples.compactMap { $0.pttEvaluation?.transition }.isEmpty)
        XCTAssertTrue(report.samples.allSatisfy { !$0.pttActive })
    }

    func testRingRetainsLatestFramesInOrderAndReportsTruncation() throws {
        let output = frames([Float](repeating: 0.02, count: 19200))
        var recorder = ControlTraceRecorder(capacity: 4)
        recorder.begin(at: date, state: checkpoint(0), reason: "ring")
        for frame in output { recorder.append(frame, receivedAtUptime: frame.time) }
        let report = try XCTUnwrap(recorder.snapshot(finalState: checkpoint(0.4, active: true)))
        XCTAssertEqual(report.samples.map(\.blockEndUptime), output.suffix(4).map(\.time))
        XCTAssertEqual(report.droppedSampleCount, output.count - 4)
        XCTAssertEqual(report.samples.first?.pttEvaluation?.activeBefore, true)
        XCTAssertFalse(report.initialState.pttActive)
        XCTAssertTrue(report.finalState.pttActive)
        // Export must be an independent snapshot while capture continues.
        recorder.begin(at: date, state: checkpoint(1), reason: "new session")
        XCTAssertEqual(report.samples.count, 4)
    }

    func testResetWhileActiveCapturesStartingStateAndExcludesQueuedOldFrames() throws {
        let output = frames([Float](repeating: 0.02, count: 19200))
        var recorder = ControlTraceRecorder(capacity: 4)
        recorder.begin(at: date, state: checkpoint(0), reason: "first")
        for frame in output.prefix(5) { recorder.append(frame, receivedAtUptime: frame.time) }
        recorder.begin(at: date, state: checkpoint(0.205, active: true, latest: 0.2), reason: "Reset Check")
        for frame in output { recorder.append(frame, receivedAtUptime: frame.time + 0.22) }
        let report = try XCTUnwrap(recorder.snapshot(finalState: checkpoint(0.7, active: true, latest: 0.4)))
        XCTAssertTrue(report.initialState.pttActive)
        XCTAssertEqual(report.initialState.lastControlBlockEndUptime, 0.2)
        XCTAssertEqual(report.ignoredBeforeStartCount, 5)
        XCTAssertEqual(report.droppedSampleCount, 1)
        XCTAssertTrue(report.samples.allSatisfy { $0.blockEndUptime > 0.205 })
        XCTAssertTrue(report.samples.compactMap { $0.pttEvaluation?.transition }.isEmpty)
    }

    func testStopFreezesTraceAndRestartDoesNotMixCaptureSessions() throws {
        let output = frames(pulse(), configuration: immediate)
        var recorder = ControlTraceRecorder()
        XCTAssertNil(recorder.snapshot(finalState: checkpoint(0)))
        recorder.begin(at: date, state: checkpoint(0, running: false), reason: "Capture started")
        for frame in output.prefix(4) { recorder.append(frame, receivedAtUptime: frame.time) }
        recorder.stop(at: 0.17, reason: "Input disconnected")
        for frame in output.dropFirst(4) { recorder.append(frame, receivedAtUptime: frame.time) }
        let report = try XCTUnwrap(recorder.snapshot(finalState: checkpoint(2, running: false)))
        XCTAssertEqual(report.samples.count, 4)
        XCTAssertEqual(report.stoppedAtUptime, 0.17)
        XCTAssertEqual(report.stopReason, "Input disconnected")
        XCTAssertFalse(report.finalState.captureRunning)
        XCTAssertTrue(report.samples.last!.pttActive) // Historical state survives the lifecycle release.
        recorder.begin(at: date, state: checkpoint(2, running: false), reason: "Capture started")
        let restarted = try XCTUnwrap(recorder.snapshot(finalState: checkpoint(2)))
        XCTAssertTrue(restarted.samples.isEmpty)
        XCTAssertNil(restarted.stopReason)
        XCTAssertEqual(restarted.droppedSampleCount, 0)
    }

    func testReportJSONKeepsFractionalTimesAndSubthresholdState() throws {
        var config = BridgeConfiguration(); config.pttEnabled = false; config.activationDB = -10
        var recorder = ControlTraceRecorder()
        recorder.begin(at: date, state: checkpoint(0, running: false), reason: "Capture started")
        for frame in frames(pulse(), configuration: config) {
            recorder.append(frame, receivedAtUptime: frame.time + 0.001234)
        }
        let report = try XCTUnwrap(recorder.snapshot(finalState: checkpoint(1.4)))
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(ControlTraceReport.self, from: data)
        XCTAssertEqual(decoded.startedAt, "2026-10-29T20:42:51.125Z")
        XCTAssertEqual(decoded.samples[1].receivedAtUptime - decoded.samples[1].blockEndUptime, 0.001234, accuracy: 1e-10)
        XCTAssertTrue(decoded.samples.compactMap { $0.pttEvaluation?.transition }.isEmpty)
        XCTAssertTrue(decoded.samples.allSatisfy { !$0.pttActive })
        XCTAssertTrue(decoded.samples.contains { $0.rmsDB > -60 })
        XCTAssertEqual(decoded.blockDurationSeconds, 0.04)
    }
}
