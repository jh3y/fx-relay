import FXMicCore
import SwiftUI

struct MenuBarView: View {
    let model: BridgeModel
    @Environment(\.openWindow) private var openWindow
    private var bank: Int { model.handleBank ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BridgeBrand(compact: true)
                Spacer(minLength: 8)
                ReadinessBadge(readiness: model.readiness)
            }.padding(.horizontal, 20).padding(.vertical, 16)
            Divider()
            VStack(alignment: .leading, spacing: 16) {
                if model.readiness != .ready && model.readiness != .paused {
                    recovery
                }
                ProfilePicker(model: model).controlSize(.regular)
                VStack(alignment: .leading, spacing: 9) {
                    Picker("Current bank", selection: Binding(get: { model.handleBank }, set: model.selectHandleBank)) {
                        ForEach(0..<BridgeConfiguration.bankCount, id: \.self) { index in
                            Text(String(format: "%02d", index + 1)).tag(Optional(index))
                        }
                    }.pickerStyle(.segmented).labelsHidden()
                        .disabled(model.diagnostics.isRecording)
                        .accessibilityLabel("Current microphone bank")
                    HStack {
                        Text(bankName)
                            .font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(bankSource).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize()
                    }.help(model.handleBank.map { model.bridgeConfiguration.bankNames[$0] } ?? "Play a sample to identify the bank")
                }
                Divider()
                HStack(spacing: 10) {
                    Image(systemName: "hand.draw").frame(width: 22)
                        .foregroundStyle(model.detectedPTT ? BridgeStyle.orange : Color.secondary)
                    Text("Handle").fontWeight(.medium)
                    Spacer(minLength: 10)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(model.currentHandleAction?.label ?? "Awaiting bank")
                            .font(.system(size: 11, design: .monospaced)).lineLimit(2)
                        if model.actions.pttHeld { Text("Key held").font(.caption2).foregroundStyle(BridgeStyle.orange) }
                    }
                }.frame(minHeight: 32)
                Divider()
                VStack(spacing: 0) {
                    HStack {
                        BridgeStyle.label("SAMPLES")
                        Spacer()
                        BridgeStyle.label(model.bridgeConfiguration.enabledBanks[bank] ? "ACTION" : "PREVIEW ONLY")
                    }.padding(.bottom, 7)
                    if model.handleBank != nil {
                        ForEach(0..<4) { slot in
                            ControlReferenceRow(model: model, index: bank * 4 + slot).frame(minHeight: 32)
                            if slot < 3 { Divider().opacity(0.55) }
                        }
                    } else {
                        Text("Play a sample to identify its bank.").font(.caption).foregroundStyle(.secondary).padding(.vertical, 36)
                    }
                }
                Divider()
                VStack(spacing: 8) {
                    InputPicker(model: model, compact: true).controlSize(.small)
                    MenuLevelView(model: model)
                }
            }.padding(20)
            Divider()
            HStack(spacing: 10) {
                Button(action: model.toggleMonitoring) {
                    Label(model.monitoringEnabled ? "Pause" : "Resume", systemImage: model.monitoringEnabled ? "pause" : "play")
                }.disabled(model.micSetup.busy)
                Spacer()
                Button("Mappings…") { show("mappings") }
                Menu {
                    Button("Setup…") { show("setup") }
                    Button("Bank Reference") { show("cheat-sheet") }
                    Button("Signal Monitor") { show("signal-monitor") }
                    Divider()
                    Button("About FX Relay") { NSApp.orderFrontStandardAboutPanel(nil); NSApp.activate(ignoringOtherApps: true) }
                    Button("Quit FX Relay") { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).fixedSize()
                    .accessibilityLabel("More: Setup, Bank Reference, Signal Monitor and Quit")
            }.controlSize(.regular).padding(.horizontal, 20).padding(.vertical, 14)
        }.frame(width: 380).bridgeSurface()
            .background(WindowVisibilityObserver(onChange: { source, visible in
                model.readings.setVisible(.menu, source: source, visible: visible)
            }))
            .onAppear { model.refreshPermissions() }
    }
    private var bankName: String {
        let name = model.handleBank.map { model.bridgeConfiguration.bankNames[$0] } ?? "Bank unknown"
        return name.count > 30 ? String(name.prefix(29)) + "…" : name
    }
    private var bankSource: String {
        switch model.handleBankSource {
        case .startup: return "Startup"
        case .manual: return "Selected here"
        case .cue: return "Last sample"
        default: return "Unidentified"
        }
    }
    private var recovery: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.errorMessage ?? model.readiness.detail).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.readiness == .microphonePermission || model.readiness == .accessibilityPermission {
                Button("Complete Permission Setup…") { show("setup") }
            } else if model.readiness == .unsavedMappings {
                Button("Review Changes…") { show("mappings") }
            } else if model.readiness == .captureError {
                Button("Inspect Input…") { show("signal-monitor") }
            }
        }
    }
    private func show(_ id: String) { openWindow(id: id); NSApp.activate(ignoringOtherApps: true) }
}

/// Fast meter observation stays isolated from the controls.
struct MenuLevelView: View {
    let model: BridgeModel
    var body: some View {
        VStack(spacing: 7) {
            LevelMeter(rmsDB: model.readings.menuSnapshot.rmsDB, peakDB: model.readings.menuSnapshot.peakDB, threshold: model.settings.thresholdDB)
                .frame(height: 5)
            HStack {
                Text(String(format: "%.1f dBFS", model.readings.menuSnapshot.rmsDB))
                Spacer()
                Text(model.isRunning ? (model.signalPresent ? "Signal" : "No signal") : "Input off")
            }.font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
        }
    }
}

struct ControlReferenceRow: View {
    let model: BridgeModel
    let index: Int
    private var active: Bool { model.detectedTone == index }
    private var action: BridgeAction { model.bridgeConfiguration.tones[index].action }
    var body: some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", index % 4 + 1))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(active ? BridgeStyle.orange : Color.secondary).frame(width: 22)
            Text(action.label).font(.system(size: 12, design: action.kind == .none ? .default : .monospaced))
                .foregroundStyle(action.kind == .none ? Color.secondary : Color.primary)
                .lineLimit(1).help(action.kind == .typeText ? action.text + (action.pressEnter ? " → Return" : "") : action.label)
            Spacer(minLength: 0)
            if active { Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(BridgeStyle.orange).accessibilityLabel("Detected") }
        }.accessibilityElement(children: .combine)
    }
}
