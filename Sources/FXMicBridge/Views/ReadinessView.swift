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
