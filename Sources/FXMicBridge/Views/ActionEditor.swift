import AppKit
import FXMicCore
import SwiftUI

struct ActionEditor: View {
    let title: String
    @Binding var action: BridgeAction
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !title.isEmpty { Text(title).font(.headline) }
            Picker("Action", selection: $action.kind) {
                Text("None").tag(BridgeAction.Kind.none)
                Text("Hold Key").tag(BridgeAction.Kind.holdKey)
                if action.chord.modifierKey == nil {
                    Text("Hold Key — Continuous").tag(BridgeAction.Kind.holdKeyContinuous)
                }
                Text("Keystroke").tag(BridgeAction.Kind.keystroke)
                Text("Shortcut").tag(BridgeAction.Kind.shortcut)
                Text("Type Text").tag(BridgeAction.Kind.typeText)
            }.pickerStyle(.menu)
            if action.kind != .none && action.kind != .typeText {
                Text(action.chord.label).font(.system(size: 32, weight: .medium, design: .monospaced))
                    .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
                    .padding(.horizontal, 16).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                HStack {
                    Menu("Choose key") {
                        ForEach(KeyChord.presets.indices, id: \.self) { index in
                            Button(KeyChord.presets[index].label) { action.chord = KeyChord.presets[index] }
                        }
                        Divider()
                        ForEach(ModifierKey.allCases, id: \.rawValue) { modifier in
                            Button(modifier.label) {
                                action.chord = modifier.chord
                                if action.kind == .holdKeyContinuous { action.kind = .holdKey }
                                if action.supportsSystemDelivery { action.delivery = .systemShortcut }
                            }
                        }
                    }.fixedSize()
                    ShortcutRecorder(chord: $action.chord)
                }
                if action.supportsSystemDelivery {
                    Picker("Send to", selection: $action.delivery) {
                        Text("Focused target app").tag(BridgeAction.Delivery.targetApp)
                        Text("macOS / system shortcut").tag(BridgeAction.Delivery.systemShortcut)
                    }
                    if action.delivery == .systemShortcut {
                        Text(action.chord.modifierKey != nil
                             ? "Sends modifier changes to macOS and global shortcut listeners. Match the key in your dictation app. Focus changes and Pause release the modifier."
                             : "For shortcuts handled by macOS or a global dictation app. Match its configured shortcut. Focus changes and Pause release held keys.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if action.kind == .typeText {
                TextField("Text to type, e.g. /voice", text: $action.text).textFieldStyle(.roundedBorder).controlSize(.large)
                Toggle("Press Enter afterward", isOn: $action.pressEnter).toggleStyle(.checkbox)
                if action.pressEnter {
                    HStack {
                        Text("Wait")
                        TextField("Delay", value: $action.enterDelay, format: .number).frame(width: 70).textFieldStyle(.roundedBorder)
                        Text("seconds before Enter")
                    }.font(.callout)
                }
                Text("One line. Leave Enter off to submit with a separate sample.").font(.caption).foregroundStyle(.secondary)
            } else if action.kind == .none {
                Text("Recognize the input without sending any keys.").foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if action.kind == .holdKey {
                Text(action.chord.modifierKey != nil
                     ? "One modifier press, then release when the sound gate ends. Other bridge key actions are skipped while it is held. A silent squeeze alone is not detected."
                     : "One key down, then one key up when the signal ends. No repeated key presses.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if action.kind == .holdKeyContinuous {
                Text("One key down, continuous key-repeat events while active, then one key up. Use Space with Claude Code’s /voice hold. Repeats continue through the configured release delay; ordinary text fields will receive repeated characters.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: action.kind) { _, value in
            if !action.supportsSystemDelivery { action.delivery = .targetApp }
        }
    }
}

/// Local monitoring consumes only the combination explicitly being recorded, inside this app.
private struct ShortcutRecorder: View {
    @Binding var chord: KeyChord
    @State private var monitor: Any?
    var body: some View {
        Button(monitor == nil ? "Record…" : "Press keys · Cancel") {
            if monitor != nil { stop(); return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard event.keyCode <= 127, ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(event.keyCode) else { return nil }
                var mask: UInt8 = 0
                var prefix = ""
                if event.modifierFlags.contains(.control) { mask |= 1; prefix += "⌃" }
                if event.modifierFlags.contains(.option) { mask |= 2; prefix += "⌥" }
                if event.modifierFlags.contains(.shift) { mask |= 4; prefix += "⇧" }
                if event.modifierFlags.contains(.command) { mask |= 8; prefix += "⌘" }
                let named = KeyChord.presets.first { $0.keyCode == event.keyCode && $0.modifiers == 0 }?.label
                let label = named ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
                chord = KeyChord(event.keyCode, modifiers: mask, label: prefix + label)
                stop(); return nil
            }
        }
        .onDisappear(perform: stop)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in stop() }
    }
    private func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
}
