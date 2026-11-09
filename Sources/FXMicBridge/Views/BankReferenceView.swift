import FXMicCore
import SwiftUI

struct BankReferenceView: View {
    let model: BridgeModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Bank Reference").font(.system(size: 18, weight: .semibold))
                Spacer()
                Toggle(isOn: Binding(get: { model.utilityPreferences.keepCheatSheetOnTop },
                                     set: { model.utilityPreferences.keepCheatSheetOnTop = $0 })) {
                    Label("Keep on Top", systemImage: model.utilityPreferences.keepCheatSheetOnTop ? "pin.fill" : "pin")
                }.toggleStyle(.button).controlSize(.small)
            }
            HStack {
                Text(model.profiles.selected.name).font(.headline).lineLimit(1).help(model.profiles.selected.name)
                Spacer()
                Button("Edit…") { openWindow(id: "mappings"); NSApp.activate(ignoringOtherApps: true) }.font(.caption)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<BridgeConfiguration.bankCount, id: \.self) { bank in
                    bankCard(bank)
                }
            }
            HStack(spacing: 6) {
                Circle().fill(model.readiness == .ready ? Color.green : BridgeStyle.orange).frame(width: 6, height: 6)
                Text(model.readiness.title).font(.caption)
                Spacer()
                Text(model.actions.bridgeStatus).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(model.handleBank == nil ? "Bank unknown. Play a sample to identify it." : model.handleBankSource == .startup ? "Startup bank shown. Play a sample after changing FX on the mic." :
                    model.handleBankSource == .manual ? "Bank selected in FX Relay. The next sample updates it." :
                    "Bank follows the last sample. Orange alone does not update this view.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(20).frame(minWidth: 580, idealWidth: 620)
            .bridgeSurface()
    }

    private func bankCard(_ bank: Int) -> some View {
        let current = model.handleBank == bank
        let enabled = model.bridgeConfiguration.enabledBanks[bank]
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(format: "%02d", bank + 1)).font(.system(.caption, design: .monospaced)).foregroundStyle(current ? BridgeStyle.orange : Color.secondary)
                Text(model.bridgeConfiguration.bankNames[bank]).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    .help(model.bridgeConfiguration.bankNames[bank])
                Spacer(minLength: 0)
                if !enabled { Text("OFF").font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary) }
                else if current { Image(systemName: "checkmark.circle.fill").foregroundStyle(BridgeStyle.orange).accessibilityLabel("Current bank") }
            }
            HStack(spacing: 6) {
                Image(systemName: "hand.draw").foregroundStyle(current && model.detectedPTT ? BridgeStyle.orange : Color.secondary)
                Text(model.bridgeConfiguration.handleActions[bank].label).lineLimit(1)
                    .help(model.bridgeConfiguration.handleActions[bank].label)
            }.font(.caption).frame(height: 22)
            Divider()
            ForEach(0..<4) { slot in ControlReferenceRow(model: model, index: bank * 4 + slot) }
        }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
            .background(BridgeStyle.well, in: RoundedRectangle(cornerRadius: BridgeStyle.radius))
            .overlay(RoundedRectangle(cornerRadius: BridgeStyle.radius).strokeBorder(current ? BridgeStyle.orange.opacity(0.6) : Color.primary.opacity(0.09)))
    }
}
