import FXMicCore
import SwiftUI

/// Diagnostics-only controls. Editing lives in the separate mapping window.
struct BridgeControlsView: View {
    let model: BridgeModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                BridgeStyle.label("CONTROL EVENTS")
                Spacer()
                Text(model.actions.bridgeStatus).font(.caption).foregroundStyle(.secondary)
            }
            HandleRoutingView(model: model)
            Divider()
            ForEach(0..<BridgeConfiguration.bankCount, id: \.self) { bank in
                HStack {
                    Text(model.bridgeConfiguration.bankNames[bank]).font(.caption).lineLimit(1).frame(width: 110, alignment: .leading)
                    ForEach(0..<4) { slot in
                        let index = bank * 4 + slot
                        Text("\(slot + 1) / \(model.toneCounts[index])")
                            .font(.system(.caption, design: .monospaced)).frame(maxWidth: .infinity)
                            .padding(8).background(model.detectedTone == index ? BridgeStyle.orange.opacity(0.2) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
                    }
                    if !model.bridgeConfiguration.enabledBanks[bank] {
                        Text("OFF").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                            .help("Actions disabled for this bank; preview recognition remains active")
                    }
                }
            }
            Text(model.lastRecognizedControl.map { "Last played: " + model.bridgeConfiguration.controlLabel($0) } ?? "Play a sample to identify its bank and slot.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Clear Check", action: model.resetBridgeCheck).disabled(model.diagnostics.isRecording)
                Button("Save Bridge Check", action: model.exportBridgeCheck)
            }
        }
    }
}
