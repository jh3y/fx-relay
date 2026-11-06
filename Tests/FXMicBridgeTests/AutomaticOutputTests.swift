import AppKit
import XCTest
@testable import FXMicCore
@testable import FXMicBridge

@MainActor final class AutomaticOutputTests: XCTestCase {
    private final class Sink: RepeatingKeyEventSink {
        private let lock = NSLock()
        private var counts = [0, 0, 0]
        private func count(_ index: Int) -> Int { lock.lock(); defer { lock.unlock() }; return counts[index] }
        private func record(_ index: Int) { lock.lock(); defer { lock.unlock() }; counts[index] += 1 }
        var downs: Int { count(0) }
        var ups: Int { count(1) }
        var repeats: Int { count(2) }
        func prepare() -> Bool { true }
        func keyDown() { record(0) }
        func keyUp() { record(1) }
        func keyRepeat() { record(2) }
    }
    @MainActor private final class Harness {
        var time = 100.0
        var trusted = true
        var utilityFocused = false
        var focused = true
        var sinks: [Sink] = []
        var log: [String] = []
        var router = BankHandleRouter(startupBank: 0)
        var config = BridgeConfiguration()
        lazy var dispatcher = ActionDispatcher(
            frontmost: { [unowned self] in self.focused ? KeyboardTarget(processIdentifier: 101, localizedName: "Test target") : nil },
            hasAccessibility: { [unowned self] in self.trusted }, utilityFocused: { [unowned self] in self.utilityFocused }, now: { [unowned self] in self.time },
            makeKeySink: { [unowned self] _, _, _ in let sink = Sink(); self.sinks.append(sink); return sink })
        init() {
            config.handleActions = Array(repeating: .init(.holdKeyContinuous), count: 4)
            dispatcher.onEvent = { [weak self] in self?.log.append($0) }
        }
        func frame(active: Bool, transition: Bool? = nil) {
            time += 0.04
            let frame = ControlFrame(time: time - 0.001, rmsDB: active ? -30 : -90, sampleRate: 48000, channel: 0,
                pttActive: active, pttTransition: transition, pttEvaluation: nil,
                tone: ToneObservation(candidate: nil, detected: nil, heldControl: nil, frequency: nil, confidence: 0))
            dispatcher.process(frame, configuration: config, handle: router.process(frame, configuration: config))
        }
        func readyAndHold() {
            dispatcher.setAvailability(blockedBy: nil)
            frame(active: false)
            frame(active: true, transition: true)
        }
        func cleanUp() { dispatcher.disable(reason: "Test complete"); dispatcher.onEvent = nil }
    }

    func testAutomaticContinuousHoldPostsRepeatsThenOneRelease() async throws {
        let h = Harness(); defer { h.cleanUp() }
        h.readyAndHold()
        XCTAssertEqual(h.sinks.count, 1)
        XCTAssertTrue(h.dispatcher.pttHeld)
        try await Task.sleep(for: .milliseconds(45))
        h.frame(active: true)
        h.frame(active: false, transition: false)
        XCTAssertEqual(h.sinks.first?.downs, 1)
        XCTAssertEqual(h.sinks.first?.repeats, 1)
        XCTAssertEqual(h.sinks.first?.ups, 1)
        XCTAssertFalse(h.dispatcher.pttHeld)
        XCTAssertTrue(h.log.contains { $0.contains("UP posted") && $0.contains("1 repeats") })
    }

    func testUtilityFocusReleasesAndReturningNeedsNewGestureWithoutEnableButton() async {
        let h = Harness(); defer { h.cleanUp() }
        h.readyAndHold()
        h.utilityFocused = true
        h.dispatcher.checkFocus()
        XCTAssertEqual(h.sinks.first?.ups, 1)
        XCTAssertFalse(h.dispatcher.isArmed)
        h.utilityFocused = false
        h.dispatcher.checkFocus()
        XCTAssertTrue(h.dispatcher.isArmed)
        h.frame(active: true)
        XCTAssertEqual(h.sinks.count, 1)
        h.frame(active: false, transition: false)
        h.frame(active: true, transition: true)
        XCTAssertEqual(h.sinks.count, 2)
        XCTAssertEqual(h.sinks.last?.downs, 1)
    }

    func testPausePermissionLossAndDisconnectReleaseAndAutomaticallyRecover() async {
        for reason in ["Paused", "Input disconnected", "Apply or revert your mapping changes", "Guided check"] {
            let h = Harness(); defer { h.cleanUp() }
            h.readyAndHold()
            h.dispatcher.setAvailability(blockedBy: reason)
            XCTAssertEqual(h.sinks.first?.ups, 1)
            h.frame(active: true)
            XCTAssertEqual(h.sinks.count, 1)
            h.dispatcher.setAvailability(blockedBy: nil)
            h.frame(active: false, transition: false)
            h.frame(active: true, transition: true)
            XCTAssertEqual(h.sinks.count, 2)
            h.trusted = false
            h.dispatcher.checkFocus()
            XCTAssertEqual(h.sinks.last?.ups, 1)
            h.trusted = true
            h.dispatcher.checkFocus()
            h.frame(active: true)
            XCTAssertEqual(h.sinks.count, 2)
        }
    }

    func testAbsentFocusAndStaleCaptureNeverContinueRepeating() async throws {
        let h = Harness(); defer { h.cleanUp() }
        h.readyAndHold()
        h.focused = false
        h.dispatcher.checkFocus()
        XCTAssertEqual(h.sinks.first?.ups, 1)
        h.focused = true
        h.dispatcher.checkFocus()
        h.frame(active: false, transition: false)
        h.frame(active: true, transition: true)
        let stale = ControlFrame(time: h.time - 1, rmsDB: -30, sampleRate: 48000, channel: 0,
            pttActive: true, pttTransition: nil, pttEvaluation: nil,
            tone: ToneObservation(candidate: nil, detected: nil, heldControl: nil, frequency: nil, confidence: 0))
        h.dispatcher.process(stale, configuration: h.config, handle: h.router.process(stale, configuration: h.config))
        XCTAssertEqual(h.sinks.last?.ups, 1)
        XCTAssertFalse(h.dispatcher.pttHeld)
        XCTAssertEqual(h.sinks.last?.repeats, 0)
    }

    func testNewInstallDefaultsToRunningAndExplicitPauseSurvivesRestart() async {
        let name = "FXRelay.pause-test.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.loadMonitoringEnabled())
        store.saveMonitoringEnabled(false)
        XCTAssertFalse(SettingsStore(defaults: defaults).loadMonitoringEnabled())
        store.saveMonitoringEnabled(true)
        XCTAssertTrue(SettingsStore(defaults: defaults).loadMonitoringEnabled())
    }
}
