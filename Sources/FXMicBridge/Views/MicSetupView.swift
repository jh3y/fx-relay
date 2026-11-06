import SwiftUI

struct MicSetupView: View {
    let model: BridgeModel
    private var setup: MicSetupModel { model.micSetup }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    BridgeStyle.label("01 / HARDWARE")
                    Text("Four banks. Ready when you are.").font(.title2.weight(.semibold))
                }
                Spacer()
                Image(systemName: "externaldrive.fill").font(.system(size: 28)).foregroundStyle(BridgeStyle.orange)
            }
            Text("The standard cue pack includes Base / FX 1, FX 2, FX 3 and FX 4. USB-C loads the pack; your audio adapter carries the control signals during use.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(0..<4) { bank in
                    VStack(spacing: 6) {
                        Text(String(format: "%02d", bank + 1)).font(.system(.title3, design: .monospaced))
                        Text(bank == 0 ? "BASE / FX 1" : "FX \(bank + 1)").font(.system(size: 9, design: .monospaced))
                    }.frame(maxWidth: .infinity).padding(12)
                        .background(BridgeStyle.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            Text(setup.message).font(.callout).fixedSize(horizontal: false, vertical: true)
            if let plan = setup.plan, !plan.filesToWrite.isEmpty {
                Text("Will write: \(plan.filesToWrite.joined(separator: ", ")). Existing files are checked first and replacements are backed up on this Mac.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Choose FX MIC DISK…", action: setup.chooseDisk)
                if let plan = setup.plan, !plan.filesToWrite.isEmpty {
                    Button("Install Four Banks", action: setup.install).buttonStyle(.borderedProminent).tint(BridgeStyle.orange)
                }
                if setup.busy { ProgressView().controlSize(.small) }
            }.disabled(setup.busy || model.diagnostics.isRecording || model.hasUnsavedMappings)
            if setup.backup != nil {
                HStack {
                    Button("Show Backup", action: setup.revealBackup)
                    if setup.plan != nil {
                        Button("Restore Previous Setup", action: setup.restoreLastInstallation)
                            .disabled(setup.busy || model.diagnostics.isRecording || model.hasUnsavedMappings)
                    }
                }
            }
            if let error = setup.error { Text(error).foregroundStyle(.red).font(.callout).fixedSize(horizontal: false, vertical: true) }
            Text("After ejecting, resume from the menu bar and check each bank with Signal Monitor focused. A custom or unexpected pack is left for you to review. Firmware is managed separately.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(20).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}
