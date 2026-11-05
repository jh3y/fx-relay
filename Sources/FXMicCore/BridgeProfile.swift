import Foundation

public struct BridgeProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var configuration: BridgeConfiguration
    public var template: String?
    public init(name: String, configuration: BridgeConfiguration = .init(), id: UUID = UUID()) {
        self.id = id; self.name = name; self.configuration = configuration
    }
}

public struct ProfileLibrary: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var selectedID: UUID
    public var profiles: [BridgeProfile]
    public init(legacy: BridgeConfiguration) {
        let first = BridgeProfile(name: "Agent Voice", configuration: legacy.validated())
        profiles = [first]; selectedID = first.id
    }
    public var selected: BridgeProfile { profiles.first { $0.id == selectedID } ?? profiles[0] }
}

public enum ProfileError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

/// JSON is configuration only. Imported profiles are validated and added as a copy;
/// no file can arm output, choose a target process, or execute a program.
public enum ProfileCodec {
    private struct Document: Codable { var schemaVersion = 3; var profile: BridgeProfile }
    public static func validate(_ profile: BridgeProfile) throws {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw ProfileError.invalid(message) }
        }
        try require(!profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && profile.name.count <= 80,
                    "Use a profile name of 1–80 characters.")
        let c = profile.configuration
        try require(c == c.validated(), "Detector settings or bank names are outside supported limits.")
        for i in c.tones.indices {
            for j in c.tones.indices where j > i {
                try require(abs(c.tones[i].frequency - c.tones[j].frequency) > 2 * c.toleranceHz + 30,
                            "Cue frequencies overlap. Separate them by more than twice the tolerance plus 30 Hz.")
            }
        }
        for action in [c.handleAction] + c.handleActions + c.tones.map(\.action) {
            try require(action.delivery != .systemShortcut || action.kind == .shortcut,
                        "System delivery is available only for Shortcut actions.")
            try require(action.chord.keyCode <= 127 && action.chord.modifiers <= 15 && action.chord.label.count <= 80,
                        "Invalid key or shortcut.")
            try require(action.text.utf16.count <= 1024 && !action.text.unicodeScalars.contains {
                $0.properties.generalCategory == .control || $0.value == 0x2028 || $0.value == 0x2029
            }, "Text actions accept one line, up to 1,024 UTF-16 units. Use the Enter option to submit.")
            try require(action.enterDelay.isFinite && (0 ... 3).contains(action.enterDelay),
                        "Enter delay must be between 0 and 3 seconds.")
            try require(action.kind != .typeText || !action.text.isEmpty, "Enter some text for the Type Text action.")
        }
    }
    public static func encode(_ profile: BridgeProfile) throws -> Data {
        try validate(profile)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(Document(profile: profile))
    }
    public static func decode(_ data: Data) throws -> BridgeProfile {
        guard data.count <= 262144 else { throw ProfileError.invalid("Profile file is larger than 256 KB.") }
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard (1 ... 3).contains(document.schemaVersion) else { throw ProfileError.invalid("Unsupported profile version.") }
        try validate(document.profile)
        return document.profile
    }
}

public final class ProfileStore {
    private let defaults: UserDefaults
    private let key = "bridge.profiles.v4"
    private let starterKey = "bridge.starters.v1"
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func load(legacy: BridgeConfiguration, includeLegacy: Bool = true) throws -> ProfileLibrary {
        let data = defaults.data(forKey: key) ?? defaults.data(forKey: "bridge.profiles.v3") ?? defaults.data(forKey: "bridge.profiles.v2") ?? defaults.data(forKey: "bridge.profiles.v1")
        var library: ProfileLibrary
        if let data { library = try JSONDecoder().decode(ProfileLibrary.self, from: data) }
        else if includeLegacy { library = ProfileLibrary(legacy: legacy) }
        else {
            let first = ProfileTemplate.codex.makeProfile()
            library = ProfileLibrary(legacy: first.configuration)
            library.profiles = [BridgeProfile(name: first.name, configuration: first.configuration, id: ProfileTemplate.codex.starterID)]
            library.profiles[0].template = ProfileTemplate.codex.rawValue
            library.selectedID = ProfileTemplate.codex.starterID
        }
        try validate(library)
        if !defaults.bool(forKey: starterKey) {
            for template in ProfileTemplate.starters where library.profiles.count < 32 {
                if !library.profiles.contains(where: { $0.id == template.starterID }) {
                    var profile = template.makeProfile(); profile.id = template.starterID
                    library.profiles.append(profile)
                }
            }
            try save(library)
            defaults.set(true, forKey: starterKey)
        }
        if !defaults.bool(forKey: "bridge.bank-starter.v1") {
            if library.profiles.count < 32 && !library.profiles.contains(where: { $0.id == ProfileTemplate.bankWorkflows.starterID }) {
                var profile = ProfileTemplate.bankWorkflows.makeProfile(); profile.id = ProfileTemplate.bankWorkflows.starterID
                library.profiles.append(profile)
            }
            try save(library)
            defaults.set(true, forKey: "bridge.bank-starter.v1")
        }
        return library
    }
    public func save(_ library: ProfileLibrary) throws {
        try validate(library)
        defaults.set(try JSONEncoder().encode(library), forKey: key)
    }
    private func validate(_ library: ProfileLibrary) throws {
        guard library.schemaVersion == 1, (1 ... 32).contains(library.profiles.count),
              Set(library.profiles.map(\.id)).count == library.profiles.count,
              library.profiles.contains(where: { $0.id == library.selectedID }) else {
            throw ProfileError.invalid("Invalid profile library or more than 32 profiles.")
        }
        try library.profiles.forEach(ProfileCodec.validate)
    }
}
