import CoreGraphics
import XCTest
@testable import FXMicCore

final class ModifierHoldTests: XCTestCase {
    func testStandaloneModifiersProduceFlagTransitionsWithoutRepeats() {
        for modifier in ModifierKey.allCases {
            var events: [CGEvent] = []
            let sink = QuartzChordSink(pid: 0, chord: modifier.chord, systemShortcut: true,
                                      hardwareFlags: { [] }, post: { events.append($0.copy()!) })
            XCTAssertTrue(sink.prepare())
            sink.keyDown(); sink.keyRepeat(); sink.keyRepeat(); sink.keyUp()
            XCTAssertEqual(events.map(\.type), [.flagsChanged, .flagsChanged])
            XCTAssertEqual(events.map(\.flags), [modifier.flags, []])
            XCTAssertTrue(events.allSatisfy { $0.getIntegerValueField(.keyboardEventKeycode) == Int64(modifier.rawValue) })
            XCTAssertTrue(events.allSatisfy { $0.getIntegerValueField(.keyboardEventAutorepeat) == 0 })
        }
    }

    func testReleasePreservesPhysicalKeysPressedDuringTheHold() {
        var physical: CGEventFlags = .maskShift
        var events: [CGEvent] = []
        let sink = QuartzChordSink(pid: 0, chord: ModifierKey.option.chord, systemShortcut: true,
                                  hardwareFlags: { physical }, post: { events.append($0.copy()!) })
        XCTAssertTrue(sink.prepare()); sink.keyDown()
        XCTAssertEqual(events.first?.flags, ModifierKey.option.flags.union(.maskShift))
        physical = ModifierKey.rightOption.flags.union(.maskControl)
        sink.keyUp()
        XCTAssertEqual(events.last?.flags, physical)
        XCTAssertEqual((events.last?.flags.rawValue ?? 0) & 0x20, 0) // left Option is no longer ours
    }

    func testAlreadyPressedModifierAndUnsupportedChordNeverPost() {
        for (chord, physical) in [(ModifierKey.option.chord, CGEventFlags.maskAlternate),
                                 (KeyChord(58, modifiers: 8, label: "Invalid"), CGEventFlags())] {
            var count = 0
            let sink = QuartzChordSink(pid: 0, chord: chord, systemShortcut: true,
                                      hardwareFlags: { physical }, post: { _ in count += 1 })
            XCTAssertFalse(sink.prepare())
            sink.keyDown(); sink.keyRepeat(); sink.keyUp()
            XCTAssertEqual(count, 0)
        }
    }

    func testSystemHoldProfileRoundTripPreservesPreviousLibrary() throws {
        let name = "FXRelay.modifier-test.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let old = ProfileLibrary(legacy: .init())
        let bytes = try JSONEncoder().encode(old)
        defaults.set(bytes, forKey: "bridge.profiles.v5")
        defaults.set(true, forKey: "bridge.starters.v1")
        defaults.set(true, forKey: "bridge.bank-starter.v1")
        let store = ProfileStore(defaults: defaults)
        var library = try store.load(legacy: .init())
        XCTAssertEqual(library, old)
        var action = BridgeAction(.holdKey, ModifierKey.option.chord)
        action.delivery = .systemShortcut
        library.profiles[0].configuration.handleActions[0] = action
        try store.save(library)
        XCTAssertEqual(defaults.data(forKey: "bridge.profiles.v5"), bytes)
        XCTAssertEqual(try store.load(legacy: .init()), library)
        XCTAssertEqual(try ProfileCodec.decode(ProfileCodec.encode(library.selected)), library.selected)
        library.profiles[0].configuration.handleActions[0].kind = .holdKeyContinuous
        XCTAssertThrowsError(try ProfileCodec.validate(library.selected))
    }
}
