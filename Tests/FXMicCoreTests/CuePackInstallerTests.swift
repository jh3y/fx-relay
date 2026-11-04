import Foundation
import XCTest
@testable import FXMicCore

final class CuePackInstallerTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!
    private var volume: URL { root.appendingPathComponent("FX MIC DISK") }
    private var backups: URL { root.appendingPathComponent("Backups") }
    private var packs: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("hardware") }
    private var service: CuePackInstaller { CuePackInstaller(packs: packs, backups: backups, requireMountedVolume: false) }
    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent("FXMIC-install-test-\(UUID())")
        try fm.createDirectory(at: volume, withIntermediateDirectories: true)
        try Data("Original audio".utf8).write(to: volume.appendingPathComponent("original.wav"))
    }
    override func tearDownWithError() throws { try fm.removeItem(at: root) }
    private func contents() throws -> [String: Data] {
        var files: [String: Data] = [:]
        for path in try fm.contentsOfDirectory(at: volume, includingPropertiesForKeys: nil) {
            files[path.lastPathComponent] = try Data(contentsOf: path)
        }
        return files
    }
    private func installOld(_ version: Int) throws {
        for name in ["1.wav", "2.wav", "3.wav", "4.wav", "config.json"] {
            try fm.copyItem(at: packs.appendingPathComponent("agent-cues-v\(version)/\(name)"), to: volume.appendingPathComponent(name))
        }
    }
    func testFreshInstallAndRestorePreserveOriginalFiles() throws {
        let original = try contents(), plan = try service.inspect(volume)
        XCTAssertEqual(plan.state, .fresh); XCTAssertEqual(plan.filesToWrite.count, 5)
        XCTAssertEqual(try contents(), original)
        let backup = try service.install(plan)
        XCTAssertEqual(try service.inspect(volume).state, .current)
        XCTAssertEqual(try contents()["original.wav"], original["original.wav"])
        try service.restore(backup: backup, volume: volume)
        XCTAssertEqual(try contents(), original)
        XCTAssertThrowsError(try service.restore(backup: backup, volume: volume))
    }
    func testKnownUpgradeChangesOnlyConfigAndCanRestore() throws {
        try installOld(2)
        let original = try contents(), plan = try service.inspect(volume)
        XCTAssertEqual(plan.state, .upgrade); XCTAssertEqual(plan.filesToWrite, ["config.json"])
        let backup = try service.install(plan)
        let after = try contents()
        XCTAssertEqual(original.keys.filter { original[$0] != after[$0] }, ["config.json"])
        XCTAssertThrowsError(try service.install(service.inspect(volume)))
        try service.restore(backup: backup, volume: volume)
        XCTAssertEqual(try contents(), original)
    }
    func testCustomConfigAndChangedSampleAreRejectedWithoutWrites() throws {
        try Data("custom".utf8).write(to: volume.appendingPathComponent("config.json"))
        let before = try contents()
        XCTAssertThrowsError(try service.inspect(volume)); XCTAssertEqual(try contents(), before)
        try fm.removeItem(at: volume.appendingPathComponent("config.json"))
        try Data("my sample".utf8).write(to: volume.appendingPathComponent("1.wav"))
        XCTAssertThrowsError(try service.inspect(volume))
    }
    func testChangedFilesOrDisconnectionInvalidatePlan() throws {
        let plan = try service.inspect(volume)
        try Data("edited".utf8).write(to: volume.appendingPathComponent("original.wav"))
        XCTAssertThrowsError(try service.install(plan))
        XCTAssertFalse(fm.fileExists(atPath: volume.appendingPathComponent("config.json").path))
        let next = try service.inspect(volume)
        try fm.moveItem(at: volume, to: root.appendingPathComponent("disconnected"))
        XCTAssertThrowsError(try service.install(next))
    }
    func testBootVolumeSymlinkAndReservedDirectoryRefused() throws {
        let boot = root.appendingPathComponent("FX MIC BOOT")
        try fm.createDirectory(at: boot, withIntermediateDirectories: false)
        XCTAssertThrowsError(try service.inspect(boot))
        try fm.createSymbolicLink(at: volume.appendingPathComponent("config.json"), withDestinationURL: root.appendingPathComponent("unrelated"))
        XCTAssertThrowsError(try service.inspect(volume))
        try fm.removeItem(at: volume.appendingPathComponent("config.json"))
        try fm.createDirectory(at: volume.appendingPathComponent("config.json"), withIntermediateDirectories: false)
        XCTAssertThrowsError(try service.inspect(volume))
    }
    func testRestoreRejectsModifiedDeviceAndCorruptBackup() throws {
        try installOld(1)
        let backup = try service.install(service.inspect(volume))
        try Data("corrupt".utf8).write(to: backup.appendingPathComponent("config.json"))
        let before = try contents()
        XCTAssertThrowsError(try service.restore(backup: backup, volume: volume))
        XCTAssertEqual(try contents(), before)
        try Data("user changes".utf8).write(to: volume.appendingPathComponent("2.wav"))
        XCTAssertThrowsError(try service.restore(backup: backup, volume: volume))
    }
    func testFolderNamedLikeDiskIsNotAcceptedAsMountedHardware() throws {
        let realOnly = CuePackInstaller(packs: packs, backups: backups)
        XCTAssertThrowsError(try realOnly.inspect(volume))
    }
}
