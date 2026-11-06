import AVFoundation
import FXMicCore
import SwiftUI

struct SetupWindowView: View {
    let model: BridgeModel
    @State private var step = 0
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    private let titles = ["Access", "Input", "Cue pack", "Workflow"]
    init(model: BridgeModel, initialStep: Int = 0) {
        self.model = model
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                BridgeBrand()
                Spacer()
                BridgeStyle.label("SETUP / \(String(format: "%02d", step + 1))")
            }.padding(24)
            HStack(spacing: 0) {
                ForEach(0..<4) { index in
                    Button { step = index } label: {
                        HStack(spacing: 8) {
                            Text(String(format: "%02d", index + 1)).font(.system(.caption, design: .monospaced))
                            Text(titles[index]).font(.callout.weight(step == index ? .semibold : .regular))
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(step == index ? BridgeStyle.orange : Color.secondary)
                            .background(step == index ? BridgeStyle.orange.opacity(0.08) : .clear)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(model.micSetup.busy)
                        .accessibilityAddTraits(step == index ? [.isSelected] : [])
                }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch step {
                    case 0: accessStep
                    case 1: inputStep
                    case 2: cueStep
                    default: workflowStep
                    }
                }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button("Set Up Later") { finish() }.disabled(model.micSetup.busy)
                Spacer()
                if step > 0 { Button("Back") { step -= 1 }.disabled(model.micSetup.busy) }
                Button(step == 3 ? "Done" : "Continue") {
                    if step == 3 { finish() } else { step += 1 }
                }.buttonStyle(.borderedProminent).tint(BridgeStyle.orange)
                    .disabled(model.micSetup.busy || !canContinue)
                    .keyboardShortcut(.defaultAction)
            }.padding(20)
        }
        .frame(minWidth: 620, idealWidth: 680, minHeight: 570, idealHeight: 670)
        .tint(BridgeStyle.orange)
        .background(WindowVisibilityObserver(onChange: { source, visible in
            model.readings.setVisible(.menu, source: source, visible: visible)
        }))
        .onAppear { model.refreshPermissions() }
    }

    private var canContinue: Bool {
        switch step {
        case 0: return model.permissions.microphone == .authorized && model.permissions.accessibility
        case 1: return model.isRunning
        case 2: return true // Hardware installation is optional, never a silent overwrite.
        default: return model.readiness == .ready
        }
    }
    private func finish() {
        model.utilityPreferences.dismissIntroduction()
        dismissWindow(id: "setup")
    }
    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 26, weight: .semibold))
            Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var accessStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Your mic. Your commands.", "FX Relay turns the mic’s control signals into keys and shortcuts. Speech stays with the app you choose.")
            permissionRow("Microphone", symbol: "mic", allowed: model.permissions.microphone == .authorized,
                          detail: "Measure levels and recognise the mic’s control cues.") {
                if model.permissions.microphone == .notDetermined { model.requestMicrophone() }
                else { model.permissions.openSettings("Microphone") }
            }
            Divider()
            permissionRow("Accessibility", symbol: "keyboard", allowed: model.permissions.accessibility,
                          detail: "Send your mappings to the app you are using.") {
                model.permissions.requestAccessibility()
            }
            Text("You can change both permissions in System Settings → Privacy & Security. FX Relay does not transcribe, upload or play your audio.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func permissionRow(_ title: String, symbol: String, allowed: Bool, detail: String,
                               action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.title2).frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if allowed { Label("Allowed", systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(.green) }
            else { Button("Allow…", action: action) }
        }
    }
    private var inputStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("Connect the signal.", "Connect the FX-MIC’s audio output to your adapter, then choose that input below. USB-C is used separately to load the cue pack.")
            InputPicker(model: model)
            MenuLevelView(model: model)
            ReadinessView(model: model)
            if !model.monitoringEnabled { Button("Resume Monitoring", action: model.toggleMonitoring) }
            Text("Hold the handle and speak: the meter should rise. FX Relay leaves your Mac’s default input unchanged. Select this same adapter in your voice or dictation app.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
    private var cueStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            MicSetupView(model: model)
            if model.micSetup.needsReload && !model.monitoringEnabled {
                Button("I’ve Ejected the Mic — Resume", action: model.toggleMonitoring)
            }
            Text("Already using a compatible cue pack? Continue with it. Installing is optional here; you can return to Setup at any time.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
    private var workflowStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            heading("Make it yours.", "A profile holds all four banks, including a separate handle mapping for each. Select an existing profile, then customise it in Mappings.")
            ProfilePicker(model: model)
            if let name = model.profiles.selected.template, let template = ProfileTemplate(rawValue: name) {
                Text(template.summary).font(.callout).foregroundStyle(.secondary)
            }
            Text("Change FX on the mic, then play a sample to identify the bank. The orange button alone is silent. For sound-based PTT, squeeze and start speaking.")
                .font(.callout).foregroundStyle(.secondary)
            Divider()
            ReadinessView(model: model)
            if !model.monitoringEnabled { Button("Resume Monitoring", action: model.toggleMonitoring) }
            LaunchAtLoginToggle(manager: model.loginItem)
            HStack {
                Button("Edit Mappings…") { openWindow(id: "mappings") }
                Button("Open Bank Reference…") { openWindow(id: "cheat-sheet") }
            }
        }
    }
}
