import Foundation
import FXMicCore

struct MonitorSettings: Codable {
    var selectedDeviceUID = ""
    var selectedDeviceName = ""
    var thresholdDB = -45.0
    var showSpectrum = true
}

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "instrumentation.settings.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> MonitorSettings {
        guard let data = defaults.data(forKey: key),
              var settings = try? JSONDecoder().decode(MonitorSettings.self, from: data) else { return MonitorSettings() }
        settings.thresholdDB = settings.thresholdDB.isFinite ? min(-6, max(-100, settings.thresholdDB)) : -45
        return settings
    }

    func save(_ settings: MonitorSettings) {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: key) }
    }

    func loadBridge() -> BridgeConfiguration {
        guard let data = defaults.data(forKey: "bridge.configuration.v2"),
              let value = try? JSONDecoder().decode(BridgeConfiguration.self, from: data) else { return .init() }
        return value.validated()
    }

    func saveBridge(_ configuration: BridgeConfiguration) {
        if let data = try? JSONEncoder().encode(configuration.validated()) {
            defaults.set(data, forKey: "bridge.configuration.v2")
        }
    }
}
