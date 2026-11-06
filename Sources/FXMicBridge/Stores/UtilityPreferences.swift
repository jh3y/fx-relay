import Foundation
import Observation

@MainActor @Observable final class UtilityPreferences {
    private let defaults: UserDefaults
    private(set) var introductionDismissed: Bool
    var keepCheatSheetOnTop: Bool { didSet { defaults.set(keepCheatSheetOnTop, forKey: "utility.cheatSheetOnTop.v1") } }

    init(defaults: UserDefaults, hasExistingInput: Bool) {
        self.defaults = defaults
        // Existing users keep their working profile and do not get forced through
        // a first-run wizard after upgrading. Setup remains available in the menu.
        introductionDismissed = defaults.object(forKey: "utility.introductionDismissed.v1") as? Bool ?? hasExistingInput
        keepCheatSheetOnTop = defaults.bool(forKey: "utility.cheatSheetOnTop.v1")
    }

    func dismissIntroduction() {
        introductionDismissed = true
        defaults.set(true, forKey: "utility.introductionDismissed.v1")
    }
}
