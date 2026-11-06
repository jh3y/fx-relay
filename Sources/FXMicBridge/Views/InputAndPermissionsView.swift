import AVFoundation
import SwiftUI

struct InputPicker: View {
    let model: BridgeModel
    var compact = false

    var body: some View {
        Picker("Input", selection: Binding(get: { model.settings.selectedDeviceUID }, set: model.chooseDevice)) {
            Text("Choose an audio input…").tag("")
            if !model.settings.selectedDeviceUID.isEmpty, model.selectedDevice == nil {
                Text("\(model.selectedDeviceName) (offline)").tag(model.settings.selectedDeviceUID)
            }
            ForEach(model.devices) { device in
                Text(compact ? String(device.name.prefix(28)) : device.name).tag(device.id)
            }
        }
        .help(model.selectedDeviceName.isEmpty ? "Choose the input connected to your FX-MIC" : model.selectedDeviceName)
    }
}

struct PermissionNotice: View {
    let model: BridgeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.permissions.microphone != .authorized {
                Label("Microphone access is needed to measure your selected input.", systemImage: "mic.slash")
                    .font(.callout)
                if model.permissions.microphone == .notDetermined {
                    Button("Allow Microphone Access", action: model.requestMicrophone)
                } else {
                    Button("Open Microphone Settings") { model.permissions.openSettings("Microphone") }
                }
            }
            if !model.permissions.accessibility {
                Label("Allow Accessibility to send your mapped keys and shortcuts.", systemImage: "keyboard")
                    .font(.callout)
                Button("Open Accessibility Settings") { model.permissions.requestAccessibility() }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ConnectionStatus: View {
    let model: BridgeModel

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(model.isRunning ? Color.green : Color.orange).frame(width: 7, height: 7)
            Text(model.status).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
