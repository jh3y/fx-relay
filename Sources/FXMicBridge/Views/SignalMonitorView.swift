import FXMicCore
import SwiftUI

struct SignalMonitorView: View {
    let model: BridgeModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Signal Monitor").font(.system(size: 20, weight: .semibold))
                        Text("Live input levels, control events and diagnostics.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")")
                        .font(.system(.caption2, design: .monospaced).weight(.medium))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    InputPicker(model: model)
                    Button("Refresh", systemImage: "arrow.clockwise", action: model.refreshDevices).labelStyle(.iconOnly)
                }
                ConnectionStatus(model: model)
                PermissionNotice(model: model)
                if let error = model.errorMessage { Text(error).font(.callout).foregroundStyle(.red) }
                HStack {
                    Text(model.profiles.selected.name).font(.headline)
                    Spacer()
                    Button("Edit Mappings") { openWindow(id: "mappings") }
                }
                BridgeControlsView(model: model)
                Divider()
                DisclosureGroup("Guided hardware recording") { DiagnosticRecorderView(model: model).padding(.top, 8) }
                Divider()
                SignalReadingsView(model: model)
                Divider()
                DisclosureGroup("Optional: test keyboard output") {
                    SpaceTestView(model: model).padding(.top, 8)
                }
                Divider()
                EventLogView(model: model)
                Text("Output follows your focused app automatically. Pause or resume from the menu bar. The bridge observes audio; your target app still receives the original microphone signal, including cue tones. No speech recognition or audio routing.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .frame(minWidth: 640, minHeight: 560)
        .bridgeSurface()
        .background(WindowVisibilityObserver(onChange: { source, visible in
            model.setMonitorVisible(source: source, visible: visible)
        }, onClose: model.monitorClosed))
        .onAppear { model.refreshPermissions() }
        .onDisappear(perform: model.monitorClosed)
    }

}
