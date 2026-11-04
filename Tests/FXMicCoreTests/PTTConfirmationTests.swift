import XCTest
@testable import FXMicCore

final class PTTConfirmationTests: XCTestCase {
    func testMeasuredThreeBlockDisturbanceDoesNotActivate() {
        // RMS values from the v0.2.3 release check; no recorded audio is retained.
        var detector = PTTDetector(configuration: .init())
        let levels = [-84.0, -46.8622, -38.1214, -55.304, -84.77, -84.0]
        for (i, level) in levels.enumerated() {
            XCTAssertNil(detector.update(rmsDB: level, time: Double(i) * 0.04, suppress: false))
        }
        XCTAssertFalse(detector.isActive)
        XCTAssertNil(detector.confirmationStartedAtUptime)
    }

    func testSustainedSoundActivatesOnceAndReleaseDelayIsUnchanged() {
        var detector = PTTDetector(configuration: .init())
        var changes: [(Double, Bool)] = []
        for i in 0..<50 {
            let time = Double(i) * 0.04
            if let change = detector.update(rmsDB: i < 20 ? -40 : -84, time: time, suppress: false) {
                changes.append((time, change))
            }
        }
        XCTAssertEqual(changes.map { $0.1 }, [true, false])
        XCTAssertEqual(changes[0].0, 0.12, accuracy: 0.000001)
        XCTAssertEqual(changes[1].0, 1.72, accuracy: 0.000001) // 0.92 s after first quiet block.
    }

    func testBriefBurstsDoNotAccumulateAcrossQuietOrCueSuppression() {
        for suppressed in [false, true] {
            var detector = PTTDetector(configuration: .init())
            for i in 0..<40 {
                let interruption = i % 3 == 2
                let level = interruption && !suppressed ? -61.0 : -40.0
                XCTAssertNil(detector.update(rmsDB: level, time: Double(i) * 0.04,
                    suppress: interruption && suppressed))
            }
            XCTAssertFalse(detector.isActive)
        }
    }

    func testMissingOrNonAdvancingInputCannotCompleteConfirmation() {
        for jump in [0.04, 0.01, 1.0] {
            var detector = PTTDetector(configuration: .init())
            XCTAssertNil(detector.update(rmsDB: -40, time: 0, suppress: false))
            XCTAssertNil(detector.update(rmsDB: -40, time: 0.04, suppress: false))
            XCTAssertNil(detector.update(rmsDB: -40, time: jump, suppress: false))
            XCTAssertEqual(detector.confirmationStartedAtUptime, jump)
        }
    }

    func testZeroSettingKeepsImmediateBehaviorAndPendingTraceExplainsWait() throws {
        var immediate = BridgeConfiguration(); immediate.activationDelay = 0
        var detector = PTTDetector(configuration: immediate)
        XCTAssertEqual(detector.update(rmsDB: -40, time: 0, suppress: false), true)
        let analyzer = ControlAnalyzer(configuration: .init())
        let frames = analyzer.analyze(samples: [Float](repeating: 0.02, count: 1920 * 8),
            sampleRate: 48000, channel: 1, time: 0.32)
        let pending = try XCTUnwrap(frames.first { $0.pttEvaluation?.confirmationStartedAtUptime != nil })
        XCTAssertFalse(pending.pttActive)
        XCTAssertNil(pending.pttTransition)
        XCTAssertEqual(frames.compactMap(\.pttTransition), [true])
        let confirmed = try XCTUnwrap(frames.first { $0.pttTransition == true })
        XCTAssertNil(confirmed.pttEvaluation?.confirmationStartedAtUptime)
    }

    func testLegacySettingsGainConfirmationWithoutLosingCustomMappings() throws {
        var expected = BridgeConfiguration()
        expected.activationDB = -47; expected.releaseDB = -58; expected.releaseDelay = 1.4
        expected.pttEnabled = false; expected.handleAction = .init(.none)
        expected.tones[2].frequency = 3330
        expected.tones[1].action = .init(.shortcut, .init(40, modifiers: 8, label: "⌘K"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(expected)) as? [String: Any])
        object.removeValue(forKey: "activationDelay")
        let migrated = try JSONDecoder().decode(BridgeConfiguration.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(migrated, expected)
        expected.activationDelay = 0
        XCTAssertEqual(try JSONDecoder().decode(BridgeConfiguration.self, from: JSONEncoder().encode(expected)), expected)
        expected.activationDelay = .nan
        XCTAssertEqual(expected.validated().activationDelay, 0.12)
        expected.activationDelay = -1
        XCTAssertEqual(expected.validated().activationDelay, 0)
        expected.activationDelay = 10
        XCTAssertEqual(expected.validated().activationDelay, 0.4)
    }
}
