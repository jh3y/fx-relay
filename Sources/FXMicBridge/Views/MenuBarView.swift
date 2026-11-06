import FXMicCore
import SwiftUI

struct MenuBarView: View {
    let model: BridgeModel
    private var referenceBank: Int { model.handleBank ?? 0 }
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BridgeBrand(compact: true)
            Divider()
            InputPicker(model: model, compact: true)
            ConnectionStatus(model: model)
            MenuLevelView(model: model)
            PermissionNotice(model: model)
            ProfilePicker(model: model)
            HandleRoutingView(model: model, compact: true)
            VStack(alignment: .leading, spacing: 8) {
                BridgeStyle.label("SAMPLE ACTIONS")
                ForEach(0..<4) { slot in
                    let index = referenceBank * 4 + slot
                    HStack {
                        Text(String(format: "%02d", slot + 1)).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        Text(model.bridgeConfiguration.tones[index].action.label).font(.caption).lineLimit(1)
                        Spacer()
                        if model.lastRecognizedControl == index { Circle().fill(BridgeStyle.orange).frame(width: 5, height: 5) }
                    }
                }
            }
            Text(model.lastRecognizedControl.map { "Last played: " + model.bridgeConfiguration.controlLabel($0) } ?? "Play a sample to identify its bank and slot.")
                .font(.caption2).foregroundStyle(.secondary)
            HStack {
                Label(model.actions.bridgeStatus, systemImage: model.monitoringEnabled ? "bolt.circle" : "pause.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(model.monitoringEnabled ? "Pause" : "Resume", action: model.toggleMonitoring)
                    .disabled(model.micSetup.busy)
            }
            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button {
                    openWindow(id: "mappings"); NSApp.activate(ignoringOtherApps: true)
                } label: { Label("Edit Mappings", systemImage: "slider.horizontal.3") }
                .buttonStyle(.borderedProminent).tint(BridgeStyle.orange)
                Spacer()
                Button("Signal Monitor") { openWindow(id: "signal-monitor"); NSApp.activate(ignoringOtherApps: true) }
            }
            Divider()
            HStack {
                Button("About") { NSApp.orderFrontStandardAboutPanel(nil); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
            .buttonStyle(.plain).font(.caption)
        }
        .padding(18)
        .frame(width: 380)
        .background(WindowVisibilityObserver(onChange: { source, visible in
            model.readings.setVisible(.menu, source: source, visible: visible)
        }))
        .onAppear { model.refreshPermissions() }
        .tint(BridgeStyle.orange)
    }
}

/// Keep the popover's buttons and permission controls independent of meter refreshes.
private struct MenuLevelView: View {
    let model: BridgeModel

    var body: some View {
        VStack(spacing: 14) {
            LevelMeter(rmsDB: model.readings.menuSnapshot.rmsDB, peakDB: model.readings.menuSnapshot.peakDB, threshold: model.settings.thresholdDB)
                .frame(height: 9)
            HStack {
                Text(String(format: "RMS  %.1f dBFS", model.readings.menuSnapshot.rmsDB))
                Spacer()
                Text(model.signalPresent ? "SIGNAL" : "NO SIGNAL")
            }
            .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
        }
    }
}
