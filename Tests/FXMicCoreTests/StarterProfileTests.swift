import XCTest
@testable import FXMicCore

final class StarterProfileTests: XCTestCase {
    func testFreshInstallHasWorkflowStartersAllBanksAndNoAutomaticSubmit() throws {
        let suite = "FXMIC.starters.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ProfileStore(defaults: defaults)
        let library = try store.load(legacy: .init(), includeLegacy: false)
        XCTAssertEqual(library.profiles.map(\.name), (ProfileTemplate.starters + [.bankWorkflows]).map(\.rawValue))
        XCTAssertEqual(library.selected.name, "Codex")
        XCTAssertTrue(library.profiles.allSatisfy { $0.configuration.enabledBanks == [true,true,true,true] })
        XCTAssertTrue(library.profiles.allSatisfy { !$0.configuration.pttEnabled })
        XCTAssertTrue(library.profiles.flatMap { $0.configuration.tones }.allSatisfy { !$0.action.pressEnter })
        XCTAssertEqual(library.profiles[1].configuration.tones[1].action.kind, .keystroke)
        XCTAssertEqual(library.profiles[1].configuration.tones[1].action.chord, .space)
        XCTAssertEqual(library.profiles[1].configuration.tones[4].action.text, "/voice tap")
    }
    func testUpgradeKeepsExistingChoiceAndDoesNotRecreateDeletedStarters() throws {
        let suite = "FXMIC.starters.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var old = ProfileLibrary(legacy: .init()); old.profiles[0].name = "My mappings"
        let bytes = try JSONEncoder().encode(old); defaults.set(bytes, forKey: "bridge.profiles.v2")
        let store = ProfileStore(defaults: defaults)
        var loaded = try store.load(legacy: .init())
        XCTAssertEqual(loaded.selectedID, old.selectedID)
        XCTAssertEqual(loaded.profiles.first, old.profiles.first)
        XCTAssertEqual(loaded.profiles.count, 5)
        loaded.profiles.removeAll { $0.id == ProfileTemplate.claude.starterID }
        try store.save(loaded)
        XCTAssertEqual(try store.load(legacy: .init()), loaded)
        XCTAssertEqual(defaults.data(forKey: "bridge.profiles.v2"), bytes)
    }
}
