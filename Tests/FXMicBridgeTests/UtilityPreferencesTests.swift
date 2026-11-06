import XCTest
@testable import FXMicBridge

@MainActor final class UtilityPreferencesTests: XCTestCase {
    private func isolated(_ body: (UserDefaults) -> Void) {
        let name = "FXRelay.utility.tests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        body(defaults)
    }
    func testFreshInstallOffersSetupUntilDismissed() {
        isolated { defaults in
            let prefs = UtilityPreferences(defaults: defaults, hasExistingInput: false)
            XCTAssertFalse(prefs.introductionDismissed)
            prefs.dismissIntroduction()
            XCTAssertTrue(UtilityPreferences(defaults: defaults, hasExistingInput: false).introductionDismissed)
        }
    }
    func testUpgradeDoesNotForceSetupOrReplaceProfileData() {
        isolated { defaults in
            let profileBytes = Data("user profile with a custom bank 4".utf8)
            defaults.set(profileBytes, forKey: "bridge.profiles.v5")
            let prefs = UtilityPreferences(defaults: defaults, hasExistingInput: true)
            XCTAssertTrue(prefs.introductionDismissed)
            XCTAssertEqual(defaults.data(forKey: "bridge.profiles.v5"), profileBytes)
        }
    }
    func testFloatingReferencePreferenceSurvivesRestartWithoutChangingLoginItems() {
        isolated { defaults in
            let prefs = UtilityPreferences(defaults: defaults, hasExistingInput: false)
            XCTAssertFalse(prefs.keepCheatSheetOnTop)
            prefs.keepCheatSheetOnTop = true
            XCTAssertTrue(UtilityPreferences(defaults: defaults, hasExistingInput: false).keepCheatSheetOnTop)
        }
    }
}
