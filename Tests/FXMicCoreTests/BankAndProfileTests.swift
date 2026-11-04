import XCTest
@testable import FXMicCore

final class BankAndProfileTests: XCTestCase {
    func testAllSixteenCuesAcrossRatesAndBlockOffsetsWithoutPTT() {
        for rate in [32000.0, 44100, 48000, 96000] {
            for slot in 0..<16 {
                let ratio = pow(2, [0.0, 10.5, -10.5, 11.5][slot / 4] / 12)
                let frequency = BridgeConfiguration.frequencies[slot]
                let duration = 0.3 / ratio, fade = 0.01 / ratio
                let cue: [Float] = (0..<Int(duration * rate)).map { i in
                    let t = Double(i) / rate
                    let envelope = max(0, min(1, min(t / fade, (duration - t) / fade)))
                    return Float(0.24 * envelope * sin(2 * .pi * frequency * t))
                }
                for offset in stride(from: 0, to: Int(0.04 * rate), by: max(1, Int(rate / 300))) {
                    let analyzer = ControlAnalyzer(configuration: .init())
                    let samples = [Float](repeating: 0, count: offset) + cue + [Float](repeating: 0, count: Int(rate * 0.5))
                    var frames: [ControlFrame] = []
                    for start in stride(from: 0, to: samples.count, by: 512) {
                        let end = min(start + 512, samples.count)
                        frames += analyzer.analyze(samples: Array(samples[start..<end]), sampleRate: rate, channel: 1, time: Double(end) / rate)
                    }
                    XCTAssertEqual(frames.compactMap { $0.tone.detected }, [slot], "rate \(rate), slot \(slot), offset \(offset)")
                    XCTAssertTrue(frames.compactMap(\.pttTransition).isEmpty, "PTT at slot \(slot), offset \(offset)")
                    XCTAssertNil(frames.last?.tone.heldControl)
                }
            }
        }
    }
    func testInactiveBanksRecognizeButResolveToNoAction() {
        var c = BridgeConfiguration()
        c.tones[8].action = .init(.keystroke, .init(36, label: "Return"))
        XCTAssertEqual(c.action(for: 8).kind, .none)
        XCTAssertEqual(c.action(for: -1).kind, .none)
        XCTAssertEqual(c.action(for: 100).kind, .none)
        c.enabledBanks[2] = true
        XCTAssertEqual(c.action(for: 8).chord.keyCode, 36)
    }
    func testTemplatesValidateAndDictationUsesSystemShortcutWithoutHandleKey() throws {
        for template in ProfileTemplate.allCases { try ProfileCodec.validate(template.makeProfile()) }
        let c = ProfileTemplate.appleDictation.makeProfile().configuration
        XCTAssertFalse(c.pttEnabled); XCTAssertEqual(c.handleAction.kind, .none)
        XCTAssertEqual(c.tones[0].action.kind, .shortcut)
        XCTAssertEqual(c.tones[0].action.delivery, .systemShortcut)
        XCTAssertEqual(c.tones[0].action.chord.keyCode, 2)
        XCTAssertEqual(c.tones[0].action.chord.modifiers, 3)
        XCTAssertEqual(c.tones[1].action.chord.keyCode, 53)
        XCTAssertEqual(c.tones[2].action.chord.keyCode, 36)
        var bad = ProfileTemplate.appleDictation.makeProfile()
        bad.configuration.handleAction.delivery = .systemShortcut
        XCTAssertThrowsError(try ProfileCodec.validate(bad))
    }
    func testVersionOneEightCueProfileMigratesNamesActionsAndDelivery() throws {
        let original = ProfileTemplate.commandVoice.makeProfile()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: ProfileCodec.encode(original)) as? [String: Any])
        object["schemaVersion"] = 1
        var profile = object["profile"] as! [String: Any]
        var c = profile["configuration"] as! [String: Any]
        c["tones"] = Array((c["tones"] as! [[String: Any]]).prefix(8)).map { tone in
            var legacy = tone
            var action = legacy["action"] as! [String: Any]; action.removeValue(forKey: "delivery")
            legacy["action"] = action; return legacy
        }
        var handle = c["handleAction"] as! [String: Any]; handle.removeValue(forKey: "delivery"); c["handleAction"] = handle
        c["bankNames"] = ["Writing", "Commands"]; c.removeValue(forKey: "enabledBanks")
        profile["configuration"] = c; object["profile"] = profile
        let loaded = try ProfileCodec.decode(JSONSerialization.data(withJSONObject: object)).configuration
        XCTAssertEqual(loaded.bankNames, ["Writing", "Commands", "FX 3", "FX 4"])
        XCTAssertEqual(loaded.tones[1].action.text, "/voice")
        XCTAssertEqual(loaded.enabledBanks, [true, true, false, false])
        XCTAssertEqual(loaded.tones.count, 16)
        XCTAssertTrue(loaded.tones.allSatisfy { $0.action.delivery == .targetApp })
        XCTAssertEqual(loaded.handleAction.delivery, .targetApp)
    }
    func testMigratedLibraryRetainsOriginalPreferenceBytes() throws {
        let suite = "FXMIC.tests.migration.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        // Isolate both versions from the user's actual preferences.
        defer { defaults.removePersistentDomain(forName: suite) }
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ProfileLibrary(legacy: .init()))) as? [String: Any])
        var profiles = object["profiles"] as! [[String: Any]]
        var c = profiles[0]["configuration"] as! [String: Any]
        c["tones"] = Array((c["tones"] as! [[String: Any]]).prefix(8))
        c["bankNames"] = ["My Base", "FX 2"]; c.removeValue(forKey: "enabledBanks")
        profiles[0]["configuration"] = c; object["profiles"] = profiles
        let original = try JSONSerialization.data(withJSONObject: object)
        defaults.set(original, forKey: "bridge.profiles.v1")
        let store = ProfileStore(defaults: defaults)
        var migrated = try store.load(legacy: .init())
        XCTAssertEqual(migrated.selected.configuration.bankNames[0], "My Base")
        XCTAssertEqual(migrated.selected.configuration.tones.count, 16)
        migrated.profiles[0].name = "Edited in v0.4"
        try store.save(migrated)
        XCTAssertEqual(defaults.data(forKey: "bridge.profiles.v1"), original)
        XCTAssertEqual(try store.load(legacy: .init()), migrated)
    }
    func testOldFourCueJSONMigratesWithoutChangingMappings() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(BridgeConfiguration())) as? [String: Any])
        object["tones"] = Array((object["tones"] as! [[String: Any]]).prefix(4))
        object.removeValue(forKey: "bankNames")
        object["handleAction"] = ["kind": "holdKey", "chord": ["keyCode": 49, "label": "Space", "modifiers": 0]]
        let decoded = try JSONDecoder().decode(BridgeConfiguration.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.tones.count, 16)
        XCTAssertEqual(decoded.handleAction, BridgeAction(.holdKey))
        XCTAssertEqual(decoded.tones[2].action.chord.modifiers, 1)
        XCTAssertTrue(decoded.tones.suffix(4).allSatisfy { $0.action.kind == .none })
    }
    func testProfileRoundTripPersistenceAndIndependentMappings() throws {
        let suite = "FXMIC.tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProfileStore(defaults: defaults)
        var library = try store.load(legacy: .init())
        var copy = library.selected; copy.id = UUID(); copy.name = "Commands"
        copy.configuration.pttEnabled = false
        var action = BridgeAction(.typeText); action.text = "/voice"; action.pressEnter = true; action.enterDelay = 0.25
        copy.configuration.tones[4].action = action
        library.profiles.append(copy); library.selectedID = copy.id
        try store.save(library)
        XCTAssertEqual(try store.load(legacy: .init()), library)
        XCTAssertEqual(try ProfileCodec.decode(ProfileCodec.encode(copy)), copy)
        XCTAssertEqual(library.profiles[0].configuration.tones[4].action.kind, .none)
    }
    func testInvalidImportsRejectUnknownVersionsActionsAndUnsafeValues() throws {
        let profile = BridgeProfile(name: "Test")
        let data = try ProfileCodec.encode(profile)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["schemaVersion"] = 9
        XCTAssertThrowsError(try ProfileCodec.decode(JSONSerialization.data(withJSONObject: object)))
        XCTAssertThrowsError(try ProfileCodec.decode(Data(repeating: 32, count: 262145)))
        let unknown = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"holdKey\"", with: "\"shellCommand\"")
        XCTAssertThrowsError(try ProfileCodec.decode(Data(unknown.utf8)))
        for text in ["one\ntwo", "one\rtwo", String(repeating: "a", count: 1025)] {
            var bad = profile; bad.configuration.handleAction = .init(.typeText); bad.configuration.handleAction.text = text
            XCTAssertThrowsError(try ProfileCodec.validate(bad))
        }
        var overlap = profile; overlap.configuration.tones[7].frequency = 1501
        XCTAssertThrowsError(try ProfileCodec.validate(overlap))
        var delay = profile; delay.configuration.handleAction.enterDelay = .infinity
        XCTAssertThrowsError(try ProfileCodec.validate(delay))
    }
    func testTextChunksPreserveSurrogatePairs() async {
        await MainActor.run {
            let text = String(repeating: "a", count: 19) + "🎙️ /voice café 👨‍👩‍👧‍👦"
            let chunks = TextActionRunner.chunks(text)
            XCTAssertTrue(chunks.allSatisfy { $0.count <= 20 })
            XCTAssertEqual(chunks.map { String(decoding: $0, as: UTF16.self) }.joined(), text)
        }
    }
}

@MainActor final class TextActionRunnerTests: XCTestCase {
    private final class Sink: TextActionSink {
        var events: [String] = []
        var onType: (() -> Void)?
        func type(_ utf16: [UInt16]) -> Bool {
            events.append(String(decoding: utf16, as: UTF16.self)); onType?(); return true
        }
        func enter() -> Bool { events.append("ENTER"); return true }
    }
    func testTextThenDelayedEnterAndNoOverlappingAction() async {
        let runner = TextActionRunner(), sink = Sink(), done = expectation(description: "complete")
        var action = BridgeAction(.typeText); action.text = "/voice"; action.pressEnter = true; action.enterDelay = 0.02
        XCTAssertTrue(runner.start(action, sink: sink, isAllowed: { true }, finished: { ok in XCTAssertTrue(ok); done.fulfill() }))
        XCTAssertFalse(runner.start(action, sink: sink, isAllowed: { true }, finished: { _ in XCTFail() }))
        await fulfillment(of: [done], timeout: 1)
        XCTAssertEqual(sink.events, ["/voice", "ENTER"])
        XCTAssertFalse(runner.isBusy)
    }
    func testCancellationDuringTextPreventsRemainingChunksAndEnter() async {
        let runner = TextActionRunner(), sink = Sink(), typed = expectation(description: "first chunk")
        var action = BridgeAction(.typeText); action.text = String(repeating: "a", count: 70); action.pressEnter = true
        sink.onType = { runner.cancel(); typed.fulfill() }
        XCTAssertTrue(runner.start(action, sink: sink, isAllowed: { true }, finished: { _ in XCTFail("Cancelled callback") }))
        await fulfillment(of: [typed], timeout: 1)
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(sink.events.count, 1); XCTAssertFalse(runner.isBusy)
    }
    func testLostTargetPermissionOrFreshAudioPreventsEnter() async {
        let runner = TextActionRunner(), sink = Sink(), done = expectation(description: "interrupted")
        var allowed = true
        var action = BridgeAction(.typeText); action.text = "/voice"; action.pressEnter = true; action.enterDelay = 0.02
        sink.onType = { allowed = false }
        XCTAssertTrue(runner.start(action, sink: sink, isAllowed: { allowed }, finished: { ok in XCTAssertFalse(ok); done.fulfill() }))
        await fulfillment(of: [done], timeout: 1)
        XCTAssertEqual(sink.events, ["/voice"])
    }
    func testTypeOnlyAndRefusedStartDoNotSubmit() async {
        let runner = TextActionRunner(), sink = Sink(), done = expectation(description: "typed")
        var action = BridgeAction(.typeText); action.text = "/compact"
        XCTAssertFalse(runner.start(action, sink: sink, isAllowed: { false }, finished: { _ in XCTFail() }))
        XCTAssertTrue(runner.start(action, sink: sink, isAllowed: { true }, finished: { ok in XCTAssertTrue(ok); done.fulfill() }))
        await fulfillment(of: [done], timeout: 1)
        XCTAssertEqual(sink.events, ["/compact"])
    }
    func testCancelWhileWaitingForEnterThenNewActionCannotSubmitOldText() async {
        let runner = TextActionRunner(), oldSink = Sink(), newSink = Sink()
        let typed = expectation(description: "old text typed"), completed = expectation(description: "new action")
        var old = BridgeAction(.typeText); old.text = "/old"; old.pressEnter = true; old.enterDelay = 0.1
        oldSink.onType = { typed.fulfill() }
        XCTAssertTrue(runner.start(old, sink: oldSink, isAllowed: { true }, finished: { _ in XCTFail("Old callback after cancellation") }))
        await fulfillment(of: [typed], timeout: 1)
        try? await Task.sleep(for: .milliseconds(20))
        runner.cancel()
        var new = BridgeAction(.typeText); new.text = "/new"
        XCTAssertTrue(runner.start(new, sink: newSink, isAllowed: { true }, finished: { ok in XCTAssertTrue(ok); completed.fulfill() }))
        await fulfillment(of: [completed], timeout: 1)
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertEqual(oldSink.events, ["/old"]); XCTAssertEqual(newSink.events, ["/new"])
    }
}
