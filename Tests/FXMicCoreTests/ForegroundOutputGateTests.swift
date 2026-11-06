import XCTest
@testable import FXMicCore

final class ForegroundOutputGateTests: XCTestCase {
    func testLaunchNeedsFreshQuietButNoManualArming() {
        var gate = ForegroundOutputGate()
        XCTAssertTrue(gate.update(targetPID: 101, at: 10))
        XCTAssertFalse(gate.accepts(frameTime: 9.99, now: 10.01, quiet: true))
        XCTAssertFalse(gate.accepts(frameTime: 10.02, now: 10.03, quiet: false))
        XCTAssertTrue(gate.waitingForQuiet)
        XCTAssertFalse(gate.accepts(frameTime: 10.04, now: 10.05, quiet: true))
        XCTAssertTrue(gate.accepts(frameTime: 10.08, now: 10.09, quiet: false))
    }

    func testFocusSwitchRequestsReleaseAndDoesNotCarryAnActiveGesture() {
        var gate = ForegroundOutputGate()
        gate.update(targetPID: 101, at: 10)
        _ = gate.accepts(frameTime: 10.01, now: 10.02, quiet: true)
        XCTAssertTrue(gate.accepts(frameTime: 10.04, now: 10.05, quiet: false))
        XCTAssertTrue(gate.update(targetPID: 202, at: 11))
        XCTAssertFalse(gate.accepts(frameTime: 10.99, now: 11.01, quiet: true))
        XCTAssertFalse(gate.accepts(frameTime: 11.02, now: 11.03, quiet: false))
        XCTAssertFalse(gate.accepts(frameTime: 11.04, now: 11.05, quiet: true))
        XCTAssertTrue(gate.accepts(frameTime: 11.08, now: 11.09, quiet: false))
        XCTAssertEqual(gate.targetPID, 202)
    }

    func testUnavailableOrUtilityFocusReleasesAndResumesAutomatically() {
        var gate = ForegroundOutputGate()
        gate.update(targetPID: 101, at: 10)
        _ = gate.accepts(frameTime: 10.01, now: 10.02, quiet: true)
        XCTAssertTrue(gate.update(targetPID: nil, at: 11))
        XCTAssertFalse(gate.accepts(frameTime: 11.01, now: 11.02, quiet: false))
        XCTAssertFalse(gate.update(targetPID: nil, at: 12))
        XCTAssertTrue(gate.update(targetPID: 101, at: 13))
        XCTAssertFalse(gate.accepts(frameTime: 13.01, now: 13.02, quiet: true))
        XCTAssertTrue(gate.accepts(frameTime: 13.04, now: 13.05, quiet: false))
    }

    func testStableFocusDoesNotContinuouslyRearmAndStaleOrInvalidFramesAreRejected() {
        var gate = ForegroundOutputGate()
        gate.update(targetPID: 101, at: 10)
        _ = gate.accepts(frameTime: 10.01, now: 10.02, quiet: true)
        XCTAssertFalse(gate.update(targetPID: 101, at: 11))
        XCTAssertTrue(gate.accepts(frameTime: 11.01, now: 11.02, quiet: false))
        XCTAssertFalse(gate.accepts(frameTime: 11.01, now: 11.5, quiet: false))
        XCTAssertFalse(gate.accepts(frameTime: 12, now: 11.5, quiet: false))
        XCTAssertFalse(gate.accepts(frameTime: .nan, now: 12, quiet: true))
        gate.reset()
        XCTAssertNil(gate.targetPID)
        XCTAssertTrue(gate.waitingForQuiet)
    }
}
