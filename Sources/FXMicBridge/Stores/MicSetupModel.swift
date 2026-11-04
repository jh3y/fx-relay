import AppKit
import FXMicCore
import Observation

@MainActor @Observable final class MicSetupModel {
    private(set) var plan: CuePackPlan?
    private(set) var busy = false
    private(set) var message = "Connect USB-C and expose FX MIC DISK to install all four banks."
    private(set) var error: String?
    private(set) var backup: URL?
    private(set) var needsReload = false
    var onWillInstall: (() -> Void)?
    private var installer: CuePackInstaller {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return CuePackInstaller(packs: Bundle.main.resourceURL!.appendingPathComponent("CuePacks"),
                                backups: support.appendingPathComponent("FX-MIC Bridge/Mic Backups"))
    }
    func chooseDisk() {
        let panel = NSOpenPanel()
        panel.title = "Select FX MIC DISK"
        panel.message = "Select the mic's normal USB drive. This first step only inspects its files."
        panel.directoryURL = URL(fileURLWithPath: "/Volumes")
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url { self?.inspect(url) }
        }
    }
    private func inspect(_ url: URL) {
        busy = true; error = nil; plan = nil; needsReload = false
        let service = installer
        Task {
            let result = await Task.detached(priority: .utility) { Result { try service.inspect(url) } }.value
            busy = false
            switch result {
            case .success(let value):
                plan = value
                message = value.state == .current ? "All four banks are already installed." :
                    value.state == .fresh ? "Ready to install four banks and four cue samples." : "Ready to upgrade the existing pack to four banks."
            case .failure(let failure): error = failure.localizedDescription
            }
        }
    }
    func install() {
        guard let plan, !busy, plan.state != .current else { return }
        onWillInstall?(); busy = true; error = nil
        let service = installer
        Task {
            let result = await Task.detached(priority: .utility) { Result { try service.install(plan) } }.value
            busy = false
            switch result {
            case .success(let url):
                backup = url; needsReload = true; self.plan = nil
                message = "Four banks installed. Eject FX MIC DISK in Finder, then resume monitoring."
            case .failure(let failure): error = failure.localizedDescription; self.plan = nil
            }
        }
    }
    func restoreLastInstallation() {
        guard let backup, let plan, !busy else { return }
        onWillInstall?(); busy = true; error = nil
        let service = installer
        Task {
            let result = await Task.detached(priority: .utility) { Result { try service.restore(backup: backup, volume: plan.volume) } }.value
            busy = false
            switch result {
            case .success:
                self.backup = nil; self.plan = nil; needsReload = true
                message = "Previous configuration restored. Eject FX MIC DISK in Finder, then resume monitoring."
            case .failure(let failure): error = failure.localizedDescription
            }
        }
    }
    func revealBackup() { if let backup { NSWorkspace.shared.activateFileViewerSelecting([backup]) } }
}
