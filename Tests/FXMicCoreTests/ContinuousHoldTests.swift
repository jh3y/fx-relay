import CoreGraphics
import XCTest
@testable import FXMicCore

final class ContinuousHoldTests: XCTestCase {
    func testNativeEventFlagsDistinguishInitialRepeatAndReleaseWithoutPostingKeys() throws {
        var events: [CGEvent] = []
        let sink = QuartzChordSink(pid: 0, chord: .init(49, modifiers: 3, label: "⌃⌥Space"), post: { events.append($0.copy()!) })
        XCTAssertTrue(sink.prepare())
        sink.keyDown(); sink.keyRepeat(); sink.keyRepeat(); sink.keyUp()
        XCTAssertEqual(events.map(\.type), [.keyDown, .keyDown, .keyDown, .keyUp])
        XCTAssertEqual(events.map { $0.getIntegerValueField(.keyboardEventAutorepeat) }, [0, 1, 1, 0])
        XCTAssertTrue(events.allSatisfy { $0.getIntegerValueField(.keyboardEventKeycode) == 49 })
        XCTAssertTrue(events.allSatisfy { $0.flags == [.maskControl, .maskAlternate] })
        XCTAssertTrue(events.allSatisfy { $0.getIntegerValueField(.eventSourceUserData) == 0x4658425247 })
        XCTAssertTrue(zip(events, events.dropFirst()).allSatisfy { $0.timestamp <= $1.timestamp })
    }

    func testInvalidNativeKeyCannotPrepareOrPost() {
        var count = 0
        let sink = QuartzChordSink(pid: 0, chord: .init(999, label: "Invalid"), post: { _ in count += 1 })
        XCTAssertFalse(sink.prepare()); sink.keyDown(); sink.keyRepeat(); sink.keyUp()
        XCTAssertEqual(count, 0)
    }

    func testContinuousProfileRoundTripAndV4StoreIsPreserved() throws {
        let suite = "FXMIC.continuous.\(UUID())"
        // Use a single named domain so cleanup cannot leave a test preference behind.
        let isolated = UserDefaults(suiteName: suite)!
        defer { isolated.removePersistentDomain(forName: suite) }
        let old = ProfileLibrary(legacy: .init())
        let bytes = try JSONEncoder().encode(old)
        isolated.set(bytes, forKey: "bridge.profiles.v4")
        isolated.set(true, forKey: "bridge.starters.v1"); isolated.set(true, forKey: "bridge.bank-starter.v1")
        let store = ProfileStore(defaults: isolated)
        var library = try store.load(legacy: .init())
        XCTAssertEqual(library, old)
        library.profiles[0].configuration.handleActions[0] = .init(.holdKeyContinuous)
        try store.save(library)
        XCTAssertEqual(isolated.data(forKey: "bridge.profiles.v4"), bytes)
        XCTAssertEqual(try store.load(legacy: .init()), library)
        let data = try ProfileCodec.encode(library.selected)
        XCTAssertEqual(try ProfileCodec.decode(data), library.selected)
        XCTAssertEqual((try JSONSerialization.jsonObject(with: data) as! [String: Any])["schemaVersion"] as? Int, 4)
        XCTAssertEqual(library.selected.configuration.handleActions[1].kind, .holdKey)
    }
}
