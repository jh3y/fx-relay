import AppKit
import FXMicCore
import Observation

@MainActor @Observable
final class ProfileManager {
    private(set) var library: ProfileLibrary
    var error: String?
    var onWillChange: (() -> Void)?
    var onChange: (() -> Void)?
    private let store: ProfileStore
    var selected: BridgeProfile { library.selected }

    init(legacy: BridgeConfiguration, defaults: UserDefaults = .standard) {
        store = ProfileStore(defaults: defaults)
        do { library = try store.load(legacy: legacy, includeLegacy: defaults.data(forKey: "bridge.configuration.v2") != nil) }
        catch { library = ProfileLibrary(legacy: legacy); self.error = "Could not load profiles: \(error.localizedDescription). Saved data has not been replaced." }
    }
    func select(_ id: UUID) {
        guard id != library.selectedID, library.profiles.contains(where: { $0.id == id }) else { return }
        var next = library; next.selectedID = id; commit(next)
    }
    func update(configuration: BridgeConfiguration, name: String? = nil) {
        var next = library
        guard let index = next.profiles.firstIndex(where: { $0.id == next.selectedID }) else { return }
        if next.profiles[index].configuration != configuration.validated() { next.profiles[index].template = nil }
        next.profiles[index].configuration = configuration.validated()
        if let name { next.profiles[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines) }
        commit(next)
    }
    func create(duplicate: Bool) {
        var configuration = duplicate ? selected.configuration : BridgeConfiguration()
        if !duplicate {
            configuration.handleAction = .init(.none)
            for i in configuration.tones.indices { configuration.tones[i].action = .init(.none) }
        }
        add(BridgeProfile(name: duplicate ? String((selected.name + " Copy").prefix(80)) : "New Profile",
                          configuration: configuration))
    }
    func create(template: ProfileTemplate) { add(template.makeProfile()) }
    func deleteSelected() {
        guard library.profiles.count > 1 else { return }
        var next = library; next.profiles.removeAll { $0.id == next.selectedID }
        next.selectedID = next.profiles[0].id; commit(next)
    }
    func importJSON() {
        let panel = NSOpenPanel(); panel.title = "Import FX-MIC Profile"
        panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        panel.begin { [weak self] result in
            guard let self, result == .OK, let url = panel.url else { return }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 262144 else { throw ProfileError.invalid("Profile file is larger than 256 KB.") }
                var profile = try ProfileCodec.decode(Data(contentsOf: url))
                profile.id = UUID() // Import is always a new copy, never a silent overwrite.
                self.add(profile)
            } catch { self.error = "Import failed: \(error.localizedDescription)" }
        }
    }
    func exportJSON() {
        do {
            let data = try ProfileCodec.encode(selected)
            let panel = NSSavePanel(); panel.title = "Export FX-MIC Profile"
            panel.nameFieldStringValue = "FXMIC-profile.json"; panel.allowedContentTypes = [.json]
            panel.begin { [weak self] result in
                guard result == .OK, let url = panel.url else { return }
                do { try data.write(to: url, options: .atomic) }
                catch { self?.error = "Export failed: \(error.localizedDescription)" }
            }
        } catch { self.error = error.localizedDescription }
    }
    private func add(_ profile: BridgeProfile) {
        var next = library; next.profiles.append(profile); next.selectedID = profile.id; commit(next)
    }
    private func commit(_ next: ProfileLibrary) {
        do {
            try store.save(next)
            onWillChange?()
            library = next; error = nil; onChange?()
        } catch { self.error = error.localizedDescription }
    }
}
