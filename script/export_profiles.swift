import Foundation
import FXMicCore

let directory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "profiles")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for (template, name) in [(ProfileTemplate.codex, "codex"), (.claude, "claude-code-tap"), (.appleDictation, "apple-dictation"), (.dictationShortcut, "dictation-shortcut"), (.bankWorkflows, "agent-banks")] {
    var profile = template.makeProfile(); profile.id = template.starterID
    try ProfileCodec.encode(profile).write(to: directory.appendingPathComponent(name + ".json"), options: .atomic)
    print("Exported \(name).json")
}
