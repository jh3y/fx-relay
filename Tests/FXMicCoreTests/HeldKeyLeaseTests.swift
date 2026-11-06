import XCTest
@testable import FXMicCore

private final class RecordingSink: RepeatingKeyEventSink {
    private let lock = NSLock()
    var canPrepare = true
    private var events: [String] = []
    var recorded: [String] { lock.lock(); defer { lock.unlock() }; return events }
    func prepare() -> Bool { canPrepare }
    func keyDown() { lock.lock(); events.append("down"); lock.unlock() }
    func keyUp() { lock.lock(); events.append("up"); lock.unlock() }
    func keyRepeat() { lock.lock(); events.append("repeat"); lock.unlock() }
}

final class HeldKeyLeaseTests: XCTestCase {
    func testContinuousRepeatsAreExplicitAndStopAfterRelease() {
        let sink = RecordingSink(), lease = HeldKeyLease()
        XCTAssertTrue(lease.hold(sink, duration: 1, continuous: true, onRelease: {}))
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertEqual(sink.recorded, ["down"]) // No independent repeat timer.
        for _ in 0..<3 {
            XCTAssertTrue(lease.renew(duration: 1))
            lease.repeatIfDue()
            Thread.sleep(forTimeInterval: 0.04)
        }
        XCTAssertEqual(sink.recorded, ["down", "repeat", "repeat", "repeat"])
        lease.release()
        for _ in 0..<100 { lease.repeatIfDue() }
        lease.release()
        XCTAssertEqual(sink.recorded, ["down", "repeat", "repeat", "repeat", "up"])
        XCTAssertEqual(lease.repeatsPosted, 3)
    }

    func testOrdinaryHoldCannotRepeatAndReusingLeaseClearsContinuousMode() {
        let sink = RecordingSink(), lease = HeldKeyLease()
        XCTAssertTrue(lease.hold(sink, duration: 1, continuous: true, onRelease: {}))
        Thread.sleep(forTimeInterval: 0.04); lease.repeatIfDue(); lease.release()
        XCTAssertTrue(lease.hold(sink, duration: 1, onRelease: {}))
        Thread.sleep(forTimeInterval: 0.04); lease.repeatIfDue(); lease.release()
        XCTAssertEqual(sink.recorded, ["down", "repeat", "up", "down", "up"])
        XCTAssertEqual(lease.repeatsPosted, 0)
    }

    func testContinuousExpiresWithoutFreshFramesAndCannotRestart() {
        let sink = RecordingSink(), lease = HeldKeyLease(), released = DispatchSemaphore(value: 0)
        XCTAssertTrue(lease.hold(sink, duration: 0.15, continuous: true, onRelease: { released.signal() }))
        // No fresh frames: expiry must release without generating repeats. Do
        // not assume this test thread is scheduled before the short deadline;
        // active repetition is exercised separately above.
        XCTAssertEqual(released.wait(timeout: .now() + 2), .success)
        XCTAssertFalse(lease.renew(duration: 1))
        lease.repeatIfDue(); lease.release()
        XCTAssertEqual(sink.recorded, ["down", "up"])
        XCTAssertEqual(lease.repeatsPosted, 0)
    }

    func testContinuousRequiresARepeatCapableSinkBeforeAnyDown() {
        final class PlainSink: KeyEventSink {
            var downs = 0
            func prepare() -> Bool { true }
            func keyDown() { downs += 1 }
            func keyUp() {}
        }
        let sink = PlainSink(), lease = HeldKeyLease()
        XCTAssertFalse(lease.hold(sink, duration: 1, continuous: true, onRelease: {}))
        XCTAssertEqual(sink.downs, 0)
    }

    func testContinuousDoesNotCatchUpWithABurst() {
        let sink = RecordingSink(), lease = HeldKeyLease()
        XCTAssertTrue(lease.hold(sink, duration: 1, continuous: true, onRelease: {}))
        Thread.sleep(forTimeInterval: 0.2)
        for _ in 0..<100 { lease.repeatIfDue() }
        lease.release()
        XCTAssertEqual(sink.recorded, ["down", "repeat", "up"])
    }

    func testRenewalKeepsOneDownThenFailsSafeWithoutMoreHeartbeats() {
        let sink = RecordingSink(), lease = HeldKeyLease()
        let released = DispatchSemaphore(value: 0)
        XCTAssertTrue(lease.hold(sink, duration: 0.2, onRelease: { released.signal() }))
        for _ in 0..<5 {
            Thread.sleep(forTimeInterval: 0.05)
            XCTAssertTrue(lease.renew(duration: 0.2))
        }
        XCTAssertEqual(sink.recorded, ["down"])
        XCTAssertEqual(released.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(sink.recorded, ["down", "up"])
        XCTAssertFalse(lease.renew(duration: 1))
    }

    func testOldTimerCannotReleaseNextHold() {
        let sink = RecordingSink(), lease = HeldKeyLease()
        XCTAssertTrue(lease.hold(sink, duration: 0.02, onRelease: {}))
        lease.release()
        XCTAssertTrue(lease.hold(sink, duration: 0.3, onRelease: {}))
        Thread.sleep(forTimeInterval: 0.08)
        XCTAssertEqual(sink.recorded, ["down", "up", "down"])
        lease.release()
        XCTAssertEqual(sink.recorded, ["down", "up", "down", "up"])
    }

    func testRepeatedHoldAndReleaseCannotRepeatDownOrUp() {
        let sink = RecordingSink()
        let lease = HeldKeyLease()
        XCTAssertTrue(lease.hold(sink, duration: 1, onRelease: {}))
        XCTAssertFalse(lease.hold(sink, duration: 1, onRelease: {}))
        lease.release()
        lease.release()
        XCTAssertEqual(sink.recorded, ["down", "up"])
    }

    func testReleaseRunsWhileMainThreadIsBlocked() {
        let sink = RecordingSink()
        let lease = HeldKeyLease()
        let released = DispatchSemaphore(value: 0)
        XCTAssertTrue(lease.hold(sink, duration: 0.03, onRelease: { released.signal() }))
        XCTAssertEqual(released.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(sink.recorded, ["down", "up"])
    }

    func testFailureToPrepareCannotPressAKey() {
        let sink = RecordingSink()
        sink.canPrepare = false
        let lease = HeldKeyLease()
        XCTAssertFalse(lease.hold(sink, duration: 1, onRelease: {}))
        lease.release()
        XCTAssertEqual(sink.recorded, [])
    }

    func testDestructionReleasesPendingKey() {
        let sink = RecordingSink()
        var lease: HeldKeyLease? = HeldKeyLease()
        XCTAssertTrue(lease!.hold(sink, duration: 1, onRelease: {}))
        lease = nil
        XCTAssertEqual(sink.recorded, ["down", "up"])
    }
}
