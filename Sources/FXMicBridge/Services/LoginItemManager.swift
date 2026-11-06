import Observation
import ServiceManagement

/// The OS registration is the source of truth, including changes made in Settings.
@MainActor @Observable final class LoginItemManager {
    private(set) var status: SMAppService.Status = .notRegistered
    private(set) var error: String?
    var isRegistered: Bool { status == .enabled || status == .requiresApproval }

    func refresh() { status = SMAppService.mainApp.status }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        refresh()
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
