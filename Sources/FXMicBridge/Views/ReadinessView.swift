import FXMicCore
import SwiftUI
import ServiceManagement

struct ReadinessView: View {
    let model: BridgeModel
    var compact = false
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: model.readiness == .ready ? "checkmark.circle.fill" :
                    model.readiness == .paused ? "pause.circle" : "exclamationmark.circle")
                .font(.system(size: 17)).foregroundStyle(model.readiness == .ready ? Color.green : BridgeStyle.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.readiness.title).font(.system(size: 13, weight: .semibold))
                if !compact || model.readiness != .ready {
                    Text(model.errorMessage ?? model.readiness.detail)
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }.accessibilityElement(children: .combine)
    }
}

struct LaunchAtLoginToggle: View {
    let manager: LoginItemManager
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Launch at Login", isOn: Binding(get: { manager.isRegistered }, set: manager.setEnabled))
                .toggleStyle(.switch).controlSize(.small)
            if manager.status == .requiresApproval {
                Button("Allow in Login Items Settings…", action: manager.openSettings).font(.caption)
            }
            if let error = manager.error {
                Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
        }.onAppear { manager.refresh() }
    }
}

/// Short operational state; signal activity remains separate in the input meter.
struct ReadinessBadge: View {
    let readiness: FXMicCore.BridgeReadiness
    private var title: String {
        switch readiness {
        case .ready: return "Ready"
        case .paused: return "Paused"
        case .microphonePermission, .accessibilityPermission: return "Access needed"
        case .chooseInput: return "Choose input"
        case .disconnected: return "Disconnected"
        case .unsavedMappings: return "Editing"
        case .diagnostic: return "Measuring"
        case .captureError: return "Input error"
        case .installing: return "Installing"
        case .connecting, .waitingForAudio: return "Connecting"
        }
    }
    var body: some View {
        Label(title, systemImage: readiness == .ready ? "checkmark.circle" : readiness == .paused ? "pause.circle" : "exclamationmark.circle")
            .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            .lineLimit(1).help(readiness.title + ": " + readiness.detail)
            .accessibilityLabel(readiness.title)
    }
}
