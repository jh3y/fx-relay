import AppKit
import FXMicCore
import SwiftUI

struct HardwareSetupView: View {
    let model: BridgeModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            MicSetupView(model: model)
            VStack(alignment: .leading, spacing: 16) {
                BridgeStyle.label("02 / CHOOSE YOUR WORKFLOW")
                Text("Your mic. Your software.").font(.title2.weight(.semibold))
                Text("Starter profiles are editable. They send keys and commands; your chosen app handles speech.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                ForEach(ProfileTemplate.starters) { template in
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(template.rawValue).font(.headline)
                            Text(template.summary).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Add Copy") { model.profiles.create(template: template) }
                            .disabled(model.hasUnsavedMappings || model.diagnostics.isRecording)
                    }.padding(.vertical, 5)
                    if template != ProfileTemplate.starters.last { Divider() }
                }
            }.padding(20).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            DisclosureGroup("Set up Apple Dictation") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("In System Settings → Keyboard, enable Dictation and choose the FX-MIC audio adapter. Set its custom shortcut to Control + Option + D (⌃⌥D), or record a different combination in the profile.")
                    Text("Arm output and focus a blank text field. Play sample 1, wait for Apple's Dictation indicator, then squeeze the handle and speak. Release the handle and play sample 1 again to finish. Sample 2 sends Escape. The handle sends no key in this profile.")
                    Button("Open Keyboard Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
                    }
                }.font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.top, 12)
            }
            DisclosureGroup("Other dictation apps & compatibility") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Use the Dictation Shortcut template for MacWhisper or Superwhisper. Match a regular custom shortcut in that app, then test it in a blank document. Configure only the dictation service you intend to use for that shortcut.")
                    Text("Claude Code's terminal hold mode depends on key repeats. The Tap starter uses a single Space press instead, after you enable /voice tap. A second tap may submit the prompt. The generic Hold-Space template remains available for compatible apps.")
                    Text("Codex's F8 voice toggle depends on your CLI build/session. Desktop voice hotkeys are configured separately. These are configurable examples, not automatic integrations.")
                }.font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.top, 12)
            }
            Text("Orange chooses the bank; the sample selector chooses a slot; PLAY fires its action. Silent selector changes are not observable. No-FX shares Base / FX 1.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
