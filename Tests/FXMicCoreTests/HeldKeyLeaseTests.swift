import XCTest
@testable import FXMicCore

private final class RecordingSink: KeyEventSink {
    private let lock = NSLock()
    var canPrepare = true
    private var events: [String] = []
    var recorded: [String] { lock.lock(); defer { lock.unlock() }; return events }
    func prepare() -> Bool { canPrepare }
    func keyDown() { lock.lock(); events.append("down"); lock.unlock() }
    func keyUp() { lock.lock(); events.append("up"); lock.unlock() }
}

final class HeldKeyLeaseTests: XCTestCase {
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
