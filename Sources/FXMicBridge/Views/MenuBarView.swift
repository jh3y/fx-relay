import FXMicCore
import SwiftUI

struct MenuBarView: View {
    let model: BridgeModel
    private var referenceBank: Int { model.handleBank ?? 0 }
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                BridgeBrand(compact: true)
                Spacer()
                Menu {
                    Button("Setup…") { show("setup") }
                    Button("About FX Relay") { NSApp.orderFrontStandardAboutPanel(nil); NSApp.activate(ignoringOtherApps: true) }
                    Divider()
                    Button("Quit FX Relay") { NSApp.terminate(nil) }.keyboardShortcut("q")
                } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                    .menuStyle(.borderlessButton).fixedSize().help("Setup, About and Quit")
            }
            HStack(alignment: .top) {
                ReadinessView(model: model, compact: true)
                Button(model.monitoringEnabled ? "Pause" : "Resume", action: model.toggleMonitoring)
                    .controlSize(.small).disabled(model.micSetup.busy)
            }.padding(12).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 9))
            if model.readiness == .microphonePermission || model.readiness == .accessibilityPermission {
                Button("Complete Permission Setup…") { show("setup") }
                    .buttonStyle(.borderedProminent).tint(BridgeStyle.orange)
            }
            ProfilePicker(model: model)
            VStack(alignment: .leading, spacing: 12) {
                HandleRoutingView(model: model, compact: true)
                Divider()
                HStack {
                    BridgeStyle.label("SAMPLE / ACTION")
                    Spacer()
                    if !model.bridgeConfiguration.enabledBanks[referenceBank] {
                        Text("BANK OFF").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                if model.handleBank != nil {
                    ForEach(0..<4) { slot in
                        ControlReferenceRow(model: model, index: referenceBank * 4 + slot)
                    }
                } else {
                    Text("Your actions appear once a bank is identified.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(14).background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.08)))
            VStack(alignment: .leading, spacing: 9) {
                InputPicker(model: model, compact: true)
                MenuLevelView(model: model)
            }
            HStack {
                Button { show("mappings") } label: { Label("Mappings", systemImage: "slider.horizontal.3") }
                    .buttonStyle(.borderedProminent).tint(BridgeStyle.orange)
                Spacer()
                Button { show("cheat-sheet") } label: { Label("Bank Reference", systemImage: "square.grid.2x2") }
            }
            Divider()
            LaunchAtLoginToggle(manager: model.loginItem).font(.callout)
            HStack {
                Button("Setup…") { show("setup") }
                Spacer()
                Button("Signal Monitor") { show("signal-monitor") }
            }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
        }
        .padding(18).frame(width: 380)
        .background(WindowVisibilityObserver(onChange: { source, visible in
            model.readings.setVisible(.menu, source: source, visible: visible)
        }))
        .onAppear { model.refreshPermissions() }
        .tint(BridgeStyle.orange)
    }
    private func show(_ id: String) { openWindow(id: id); NSApp.activate(ignoringOtherApps: true) }
}

/// Isolated from controls so meter updates do not invalidate the whole popover.
struct MenuLevelView: View {
    let model: BridgeModel
    var body: some View {
        VStack(spacing: 6) {
            LevelMeter(rmsDB: model.readings.menuSnapshot.rmsDB, peakDB: model.readings.menuSnapshot.peakDB, threshold: model.settings.thresholdDB)
                .frame(height: 5)
            HStack {
                Text(String(format: "RMS  %.1f dBFS", model.readings.menuSnapshot.rmsDB))
                Spacer()
                Text(model.isRunning ? (model.signalPresent ? "SIGNAL" : "NO SIGNAL") : "INPUT OFF")
            }.font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
        }
    }
}

struct ControlReferenceRow: View {
    let model: BridgeModel
    let index: Int
    private var active: Bool { model.detectedTone == index }
    var body: some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", index % 4 + 1))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(active ? BridgeStyle.orange : Color.secondary)
                .frame(width: 23, height: 23)
                .background(active ? BridgeStyle.orange.opacity(0.15) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
            Text(model.bridgeConfiguration.tones[index].action.label)
                .font(.system(size: 12)).lineLimit(1)
                .help(model.bridgeConfiguration.tones[index].action.label)
            Spacer(minLength: 0)
            if active { Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(BridgeStyle.orange).accessibilityLabel("Detected") }
        }.accessibilityElement(children: .combine)
    }
}
