import XCTest
@testable import FXMicCore

final class BridgeReadinessTests: XCTestCase {
    private func state(microphone: Bool = true, accessibility: Bool = true, selected: Bool = true,
                       available: Bool = true, monitoring: Bool = true, starting: Bool = false,
                       audio: Bool = true, error: Bool = false, diagnostic: Bool = false,
                       edits: Bool = false) -> BridgeReadiness {
        .evaluate(microphone: microphone, accessibility: accessibility, inputSelected: selected,
                  inputAvailable: available, monitoring: monitoring, sleeping: false, installing: false,
                  captureError: error, starting: starting, receivingAudio: audio, diagnostic: diagnostic,
                  unsavedMappings: edits)
    }
    func testConnectedAdapterWithoutMicrophonePermissionIsNotReady() {
        XCTAssertEqual(state(microphone: false, audio: false), .microphonePermission)
    }
    func testLiveMeterWithoutKeyboardPermissionIsNotReady() {
        XCTAssertEqual(state(accessibility: false), .accessibilityPermission)
    }
    func testCaptureMustActuallyDeliverMeasurements() {
        XCTAssertEqual(state(starting: true, audio: false), .connecting)
        XCTAssertEqual(state(audio: false), .waitingForAudio)
        XCTAssertEqual(state(), .ready)
    }
    func testDisconnectAndCaptureErrorCannotShowReadyFromOldMeasurements() {
        XCTAssertEqual(state(available: false), .disconnected)
        XCTAssertEqual(state(error: true), .captureError)
    }
    func testObservationOnlyAndPendingEditsAreNotOperationallyReady() {
        XCTAssertEqual(state(monitoring: false), .paused)
        XCTAssertEqual(state(diagnostic: true), .diagnostic)
        XCTAssertEqual(state(edits: true), .unsavedMappings)
    }
}
