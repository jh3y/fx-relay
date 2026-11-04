import CryptoKit
import Foundation

public struct CuePackPlan: Sendable {
    public enum State: String, Sendable { case fresh, upgrade, current }
    public let volume: URL
    public let state: State
    public let filesToWrite: [String]
    public let fingerprints: [String: String]
    public let volumeIdentity: UInt64
}

public struct CuePackReceipt: Codable, Sendable {
    public var status: String
    public let volume: String
    public let installedAt: Date
    public let previousHashes: [String: String]
    public let installedHashes: [String: String]
    public let changedFiles: [String]
}

public enum CuePackError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}

/// Installs the bundled four-bank pack; no process execution, audio changes or firmware writes.
/// A captured plan must still match every visible root file immediately before writing.
public final class CuePackInstaller: @unchecked Sendable {
    private let packs: URL
    private let backups: URL
    private let requireMountedVolume: Bool
    private let fm = FileManager.default
    private static let names = ["1.wav", "2.wav", "3.wav", "4.wav", "config.json"]
    private struct Manifest: Decodable {
        struct File: Decodable { let bytes: Int; let sha256: String }
        let packVersion: Int
        let deviceFiles: [String: File]
    }
    public init(packs: URL, backups: URL, requireMountedVolume: Bool = true) {
        self.packs = packs; self.backups = backups; self.requireMountedVolume = requireMountedVolume
    }
    public func inspect(_ volume: URL) throws -> CuePackPlan {
        let identity = try checkVolume(volume)
        let target = try pack(version: 3)
        for name in Self.names {
            var directory = ObjCBool(false)
            if fm.fileExists(atPath: volume.appendingPathComponent(name).path, isDirectory: &directory), directory.boolValue {
                throw CuePackError.invalid("A folder occupies \(name). Installation stopped before any files were written.")
            }
        }
        let current = try fingerprints(volume)
        let config = current["config.json"]
        let isCurrent = config == hash(target["config.json"]!)
        if let config, !isCurrent {
            let known = try [1, 2].map { hash(try pack(version: $0)["config.json"]!) }
            guard known.contains(config) else { throw CuePackError.invalid("This mic has a custom configuration. Export it and prepare a compatible setup before installing; nothing has been changed.") }
        }
        for name in Self.names where name != "config.json" {
            if let existing = current[name], existing != hash(target[name]!) {
                throw CuePackError.invalid("\(name) contains a different sample. Installation stopped to preserve it.")
            }
            if config != nil && current[name] == nil { throw CuePackError.invalid("The installed pack is incomplete (\(name) is missing). Restore it before upgrading.") }
        }
        let changes = Self.names.filter { current[$0] != hash(target[$0]!) }
        return CuePackPlan(volume: volume, state: isCurrent ? .current : config == nil ? .fresh : .upgrade,
                           filesToWrite: changes, fingerprints: current, volumeIdentity: identity)
    }
    @discardableResult public func install(_ plan: CuePackPlan) throws -> URL {
        guard !plan.filesToWrite.isEmpty else { throw CuePackError.invalid("All four banks are already installed.") }
        let target = try pack(version: 3)
        try requireUnchanged(plan, expected: plan.fingerprints)
        let capacity = try plan.volume.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity ?? 0
        let needed = plan.filesToWrite.reduce(32768) { $0 + target[$1]!.count + 8192 }
        guard capacity > needed else { throw CuePackError.invalid("The mic needs at least \(needed / 1024) KB free to stage this pack.") }
        guard !backups.resolvingSymlinksInPath().path.hasPrefix(plan.volume.resolvingSymlinksInPath().path + "/") else {
            throw CuePackError.invalid("Backups must be on the Mac, outside the mic.")
        }
        let backup = backups.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: backup, withIntermediateDirectories: true)
        for name in plan.filesToWrite where plan.fingerprints[name] != nil {
            let data = try Data(contentsOf: plan.volume.appendingPathComponent(name))
            guard hash(data) == plan.fingerprints[name] else { throw CuePackError.invalid("\(name) changed during backup.") }
            try data.write(to: backup.appendingPathComponent(name), options: .withoutOverwriting)
        }
        let installed = target.mapValues(hash)
        var receipt = CuePackReceipt(status: "prepared", volume: plan.volume.path, installedAt: Date(),
                                     previousHashes: plan.fingerprints, installedHashes: installed, changedFiles: plan.filesToWrite)
        try save(receipt, at: backup)
        var expected = plan.fingerprints
        do {
            // Config is last: every referenced sample exists before the new config appears.
            for name in plan.filesToWrite {
                try requireUnchanged(plan, expected: expected)
                try target[name]!.write(to: plan.volume.appendingPathComponent(name), options: .atomic)
                expected[name] = installed[name]
                try requireUnchanged(plan, expected: expected)
            }
            receipt.status = "verified"; try save(receipt, at: backup)
            return backup
        } catch {
            receipt.status = "incomplete"; try? save(receipt, at: backup)
            throw CuePackError.invalid("Installation stopped: \(error.localizedDescription) Backup: \(backup.path). Keep this backup for recovery.")
        }
    }
    public func restore(backup: URL, volume: URL) throws {
        guard backup.resolvingSymlinksInPath().deletingLastPathComponent() == backups.resolvingSymlinksInPath(),
              !(try isSymlink(backup)) else { throw CuePackError.invalid("Select an original backup from this app.") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var receipt = try decoder.decode(CuePackReceipt.self, from: Data(contentsOf: backup.appendingPathComponent("receipt.json")))
        guard receipt.status == "verified", receipt.volume == volume.path,
              Set(receipt.changedFiles).isSubset(of: Set(Self.names)), !receipt.changedFiles.isEmpty else {
            throw CuePackError.invalid("This backup is not a completed installation for the selected mic.")
        }
        guard receipt.installedHashes == (try pack(version: 3)).mapValues(hash) else { throw CuePackError.invalid("The installation receipt does not match the bundled pack.") }
        var expected = receipt.previousHashes
        for name in receipt.changedFiles { expected[name] = receipt.installedHashes[name] }
        let plan = CuePackPlan(volume: volume, state: .current, filesToWrite: [], fingerprints: expected,
                               volumeIdentity: try checkVolume(volume))
        try requireUnchanged(plan, expected: expected)
        // Validate every original before modifying the device.
        var originals: [String: Data] = [:]
        for name in receipt.changedFiles where receipt.previousHashes[name] != nil {
            let file = backup.appendingPathComponent(name)
            guard !(try isSymlink(file)) else { throw CuePackError.invalid("Refusing a linked backup file.") }
            let data = try Data(contentsOf: file)
            guard hash(data) == receipt.previousHashes[name] else { throw CuePackError.invalid("The backup checksum failed for \(name).") }
            originals[name] = data
        }
        for name in receipt.changedFiles.reversed() {
            try requireUnchanged(plan, expected: expected)
            let file = volume.appendingPathComponent(name)
            if let data = originals[name] { try data.write(to: file, options: .atomic) }
            else { try fm.removeItem(at: file) }
            expected[name] = receipt.previousHashes[name]
        }
        try requireUnchanged(plan, expected: receipt.previousHashes)
        receipt.status = "restored"; try save(receipt, at: backup)
    }
    private func pack(version: Int) throws -> [String: Data] {
        let root = packs.appendingPathComponent("agent-cues-v\(version)")
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: root.appendingPathComponent("manifest.json")))
        guard manifest.packVersion == version, Set(manifest.deviceFiles.keys) == Set(Self.names) else {
            throw CuePackError.invalid("The bundled cue pack is invalid. Reinstall the app.")
        }
        var result: [String: Data] = [:]
        for name in Self.names {
            let url = root.appendingPathComponent(name)
            guard !(try isSymlink(url)) else { throw CuePackError.invalid("Refusing a linked cue file.") }
            let data = try Data(contentsOf: url), spec = manifest.deviceFiles[name]!
            guard data.count == spec.bytes, hash(data) == spec.sha256 else { throw CuePackError.invalid("Bundled cue checksum failed: \(name).") }
            result[name] = data
        }
        return result
    }
    private func checkVolume(_ volume: URL) throws -> UInt64 {
        guard !(try isSymlink(volume)), volume.lastPathComponent.uppercased().replacingOccurrences(of: "-", with: " ") == "FX MIC DISK" else {
            throw CuePackError.invalid("Choose the normal FX MIC DISK drive, not FX MIC BOOT or a folder inside it.")
        }
        if requireMountedVolume {
            let values = try volume.resourceValues(forKeys: [.volumeIsInternalKey, .isDirectoryKey])
            let mounted = fm.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: []) ?? []
            guard volume.deletingLastPathComponent().path == "/Volumes", mounted.contains(where: { $0.standardizedFileURL == volume.standardizedFileURL }),
                  values.volumeIsInternal == false, values.isDirectory == true else {
                throw CuePackError.invalid("The selected FX MIC DISK is not a mounted external volume.")
            }
        }
        guard let number = try fm.attributesOfFileSystem(forPath: volume.path)[.systemNumber] as? NSNumber else {
            throw CuePackError.invalid("The mic disconnected.")
        }
        return number.uint64Value
    }
    private func fingerprints(_ volume: URL) throws -> [String: String] {
        var result: [String: String] = [:]
        for file in try fm.contentsOfDirectory(at: volume, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            guard !(try isSymlink(file)) else { throw CuePackError.invalid("Refusing a linked device file: \(file.lastPathComponent).") }
            if try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                result[file.lastPathComponent] = hash(try Data(contentsOf: file))
            }
        }
        return result
    }
    private func requireUnchanged(_ plan: CuePackPlan, expected: [String: String]) throws {
        guard try checkVolume(plan.volume) == plan.volumeIdentity, try fingerprints(plan.volume) == expected else {
            throw CuePackError.invalid("The mic disconnected or its files changed. Inspect it again before installing.")
        }
    }
    private func isSymlink(_ url: URL) throws -> Bool { try url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true }
    private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private func save(_ receipt: CuePackReceipt, at backup: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(receipt).write(to: backup.appendingPathComponent("receipt.json"), options: .atomic)
    }
}
