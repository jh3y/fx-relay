import XCTest
@testable import FXMicCore

final class BankHandleTests: XCTestCase {
    private func frame(_ active: Bool = false, transition: Bool? = nil, cue: Int? = nil, level: Double? = nil) -> ControlFrame {
        ControlFrame(time: 1, rmsDB: level ?? (active || cue != nil ? -30 : -90), sampleRate: 48000, channel: 1,
            pttActive: active, pttTransition: transition, pttEvaluation: nil,
            tone: ToneObservation(candidate: cue, detected: cue, heldControl: cue, frequency: nil, confidence: 1))
    }
    private var mixed: BridgeConfiguration { ProfileTemplate.bankWorkflows.makeProfile().configuration }

    func testExplicitStartupBankWorksImmediatelyAfterQuietAndNextCueOverridesIt() {
        var router = BankHandleRouter(startupBank: 0)
        XCTAssertEqual(router.bank, 0); XCTAssertEqual(router.source, .startup)
        XCTAssertNil(router.process(frame(true, transition: true), configuration: mixed).activation)
        _ = router.process(frame(), configuration: mixed)
        XCTAssertEqual(router.process(frame(true, transition: true), configuration: mixed).activation?.kind, .holdKeyContinuous)
        let cue = router.process(frame(cue: 7), configuration: mixed)
        XCTAssertTrue(cue.release); XCTAssertEqual(router.bank, 1); XCTAssertEqual(router.source, .cue)
        router.reset(preservingBank: true)
        XCTAssertEqual(router.bank, 1)
        router.reset()
        XCTAssertEqual(router.bank, 0); XCTAssertEqual(router.source, .startup)
    }

    func testDifferentMappingsDoNotGuessBankAtStartup() {
        var router = BankHandleRouter()
        _ = router.process(frame(), configuration: mixed)
        let speech = router.process(frame(true, transition: true), configuration: mixed)
        XCTAssertNil(speech.activation); XCTAssertEqual(speech.state, .unknownBank)
        XCTAssertNil(router.bank)
    }
    func testCueMappedToNoneStillIdentifiesHandleBankAndRequiresQuiet() {
        var router = BankHandleRouter()
        let selected = router.process(frame(cue: 3), configuration: mixed)
        XCTAssertTrue(selected.bankChanged); XCTAssertTrue(selected.release)
        XCTAssertEqual(router.bank, 0); XCTAssertEqual(router.source, .cue)
        XCTAssertEqual(mixed.action(for: 3).kind, .none)
        XCTAssertNil(router.process(frame(true, transition: true), configuration: mixed).activation)
        _ = router.process(frame(), configuration: mixed)
        XCTAssertEqual(router.process(frame(true, transition: true), configuration: mixed).activation, .init(.holdKeyContinuous, .space))
        XCTAssertNil(router.process(frame(true), configuration: mixed).activation)
        XCTAssertTrue(router.process(frame(false, transition: false), configuration: mixed).release)
    }
    func testBankChangeDuringHoldReleasesOldKeyAndDoesNotPressReplacement() {
        var config = mixed
        config.handleActions[1] = .init(.holdKey, .init(48, label: "Tab"))
        var router = BankHandleRouter(); router.select(0)
        _ = router.process(frame(), configuration: config)
        XCTAssertEqual(router.process(frame(true, transition: true), configuration: config).activation?.chord, .space)
        let changed = router.process(frame(true, cue: 7), configuration: config)
        XCTAssertTrue(changed.release); XCTAssertNil(changed.activation)
        XCTAssertEqual(changed.state, .waitingForQuiet)
        XCTAssertNil(router.process(frame(true), configuration: config).activation)
        // Pending sound activation is not silence, even before the detector becomes active.
        _ = router.process(frame(level: -30), configuration: config)
        XCTAssertEqual(router.state, .waitingForQuiet)
        _ = router.process(frame(), configuration: config)
        XCTAssertEqual(router.process(frame(true, transition: true), configuration: config).activation?.chord.keyCode, 48)
    }
    func testNoneBankObservesSoundWithoutKeyboardAction() {
        var router = BankHandleRouter(); router.select(1)
        _ = router.process(frame(), configuration: mixed)
        let speech = router.process(frame(true, transition: true), configuration: mixed)
        XCTAssertEqual(speech.state, .unassigned); XCTAssertNil(speech.activation)
    }
    func testManualSelectionIsReplacedByNextCueAndResetForgetsBank() {
        var router = BankHandleRouter(); router.select(0)
        XCTAssertEqual(router.source, .manual)
        _ = router.process(frame(cue: 11), configuration: mixed)
        XCTAssertEqual(router.bank, 2); XCTAssertEqual(router.source, .cue)
        router.reset(); XCTAssertNil(router.bank)
        XCTAssertEqual(router.process(frame(), configuration: mixed).state, .unknownBank)
        router.select(90); XCTAssertNil(router.bank)
    }
    func testLegacyUniformMappingStillWorksWithoutBankIdentity() {
        let config = BridgeConfiguration()
        var router = BankHandleRouter()
        _ = router.process(frame(), configuration: config)
        XCTAssertEqual(router.process(frame(true, transition: true), configuration: config).activation, config.handleAction)
        XCTAssertNil(router.bank)
    }

    func testMappingResetKeepsKnownCueBankButRequiresQuietBeforeNewAction() {
        var router = BankHandleRouter()
        _ = router.process(frame(cue: 3), configuration: mixed)
        _ = router.process(frame(), configuration: mixed)
        XCTAssertNotNil(router.process(frame(true, transition: true), configuration: mixed).activation)
        router.reset(preservingBank: true)
        XCTAssertEqual(router.bank, 0); XCTAssertEqual(router.source, .cue)
        var edited = mixed; edited.handleActions[0] = .init(.holdKey, .init(48, label: "Tab"))
        let stillSpeaking = router.process(frame(true, transition: true), configuration: edited)
        XCTAssertTrue(stillSpeaking.release); XCTAssertNil(stillSpeaking.activation)
        XCTAssertEqual(stillSpeaking.state, .waitingForQuiet)
        _ = router.process(frame(), configuration: edited)
        XCTAssertEqual(router.process(frame(true, transition: true), configuration: edited).activation?.chord.keyCode, 48)
    }

    func testMappingResetKeepsManualBankButOrdinaryResetForgetsIt() {
        var router = BankHandleRouter(); router.select(1)
        router.reset(preservingBank: true)
        XCTAssertEqual(router.bank, 1); XCTAssertEqual(router.source, .manual)
        _ = router.process(frame(cue: 3), configuration: mixed)
        XCTAssertEqual(router.bank, 0); XCTAssertEqual(router.source, .cue)
        router.reset()
        XCTAssertNil(router.bank); XCTAssertNil(router.source)
        XCTAssertEqual(router.process(frame(), configuration: mixed).state, .unknownBank)
    }
    func testMappingChangeAndManualSwitchRequireReleaseAndFreshSpeech() {
        var router = BankHandleRouter(); router.select(0)
        _ = router.process(frame(), configuration: mixed)
        _ = router.process(frame(true, transition: true), configuration: mixed)
        var changed = mixed; changed.handleActions[0] = .init(.keystroke, .init(36, label: "Return"))
        let result = router.process(frame(true), configuration: changed)
        XCTAssertTrue(result.release); XCTAssertNil(result.activation)
        router.select(1)
        XCTAssertTrue(router.process(frame(true), configuration: changed).release)
    }
    func testSchemaFourRoundTripAndLegacyGlobalMigration() throws {
        let profile = ProfileTemplate.bankWorkflows.makeProfile()
        let data = try ProfileCodec.encode(profile)
        XCTAssertEqual(try ProfileCodec.decode(data), profile)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["schemaVersion"] as? Int, 5)
        json["schemaVersion"] = 2
        var c = json["profile"] as! [String: Any]
        var config = c["configuration"] as! [String: Any]
        config.removeValue(forKey: "bankHandleActions"); config["pttEnabled"] = true
        config["handleAction"] = ["kind":"holdKey", "chord":["keyCode":49,"label":"Space","modifiers":0]]
        c["configuration"] = config; json["profile"] = c
        let migrated = try ProfileCodec.decode(JSONSerialization.data(withJSONObject: json)).configuration
        XCTAssertNil(migrated.bankHandleActions)
        XCTAssertEqual(migrated.handleActions, Array(repeating: BridgeAction(.holdKey), count: 4))
        var invalid = profile; invalid.configuration.bankHandleActions = [.init(.none)]
        XCTAssertThrowsError(try ProfileCodec.encode(invalid))
        invalid = profile; invalid.configuration.handleActions[2] = .init(.typeText)
        XCTAssertThrowsError(try ProfileCodec.encode(invalid))
    }
    func testV3StorePreservedAndBankStarterAddedOnlyOnce() throws {
        let suite = "FXMIC.bank-migration.\(UUID())"
        let isolated = UserDefaults(suiteName: suite)!
        defer { isolated.removePersistentDomain(forName: suite) }
        let old = ProfileLibrary(legacy: BridgeConfiguration())
        let bytes = try JSONEncoder().encode(old)
        isolated.set(bytes, forKey: "bridge.profiles.v3"); isolated.set(true, forKey: "bridge.starters.v1")
        let store = ProfileStore(defaults: isolated)
        var loaded = try store.load(legacy: .init())
        XCTAssertEqual(loaded.selected, old.selected)
        XCTAssertEqual(isolated.data(forKey: "bridge.profiles.v3"), bytes)
        XCTAssertEqual(loaded.profiles.count, 2)
        loaded.profiles.removeAll { $0.id == ProfileTemplate.bankWorkflows.starterID }; try store.save(loaded)
        XCTAssertEqual(try store.load(legacy: .init()), loaded)
    }
}
