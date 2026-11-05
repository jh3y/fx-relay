import FXMicCore
import SwiftUI

struct BankHandleEditor: View {
    @Binding var configuration: BridgeConfiguration
    let bank: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            BridgeStyle.label("HANDLE / THIS BANK")
            ActionEditor(title: "", action: $configuration.handleActions[bank]).id(bank)
            Text("This mapping applies only to this bank. Choose None to use the handle as a physical mic gate without sending keys.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("After changing FX on the mic, play a sample to identify the bank. A sample mapped to None can select a bank without firing a macro. You can also select the handle bank explicitly in Signal Monitor.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if configuration.handleActions[bank].kind == .holdKey && configuration.handleActions[bank].chord.keyCode == 49 {
                Label("Claude Code's terminal hold mode expects repeats. Choose Hold Key — Continuous for that workflow; ordinary Hold Key sends just one down/up pair.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(20).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct HandleRoutingView: View {
    let model: BridgeModel
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 10) {
            Picker("Handle bank", selection: Binding(get: { model.handleBank ?? -1 }, set: { model.selectHandleBank($0 < 0 ? nil : $0) })) {
                Text("Await a sample").tag(-1)
                ForEach(0..<BridgeConfiguration.bankCount, id: \.self) { bank in
                    Text(model.bridgeConfiguration.bankNames[bank]).tag(bank)
                }
            }.disabled(model.diagnostics.isRecording)
            Text(model.currentHandleAction.map { "Handle: " + $0.label } ?? "Handle: waiting for bank identity")
                .font(.caption)
            if !compact {
                HStack {
                    Label(model.detectedPTT ? "Sound detector: ACTIVE" : "Sound detector: idle", systemImage: model.detectedPTT ? "waveform" : "waveform.slash")
                    Spacer()
                    Text(model.actions.pttHeld ? "Key DOWN posted" : model.actions.isArmed ? "Output armed" : "Preview · no keys posted")
                }.font(.caption)
                Text(model.handleStatus).font(.callout)
                Text(String(format: "PTT activation %.0f dBFS · confirm %.0f ms · release %.0f ms", model.bridgeConfiguration.activationDB,
                            model.bridgeConfiguration.activationDelay * 1000, model.bridgeConfiguration.releaseDelay * 1000))
                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                Text("Detection runs even when the action is None or output is off. Speaking must cross the PTT threshold; squeezing silently may show no change. The signal meter threshold is separate.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Text(model.handleBankSource == .manual ? "Manually selected · next sample updates the bank" : "Last cue selects the bank · silent FX changes are not detected")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
