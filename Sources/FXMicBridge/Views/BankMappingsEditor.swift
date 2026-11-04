import FXMicCore
import SwiftUI

struct BankMappingsEditor: View {
    @Binding var configuration: BridgeConfiguration
    let bank: Int
    @Binding var selectedSlot: Int
    private var index: Int { bank * 4 + selectedSlot }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Text(String(format: "%02d", bank + 1))
                    .font(.system(size: 34, weight: .light, design: .monospaced)).foregroundStyle(BridgeStyle.orange)
                VStack(alignment: .leading, spacing: 7) {
                    BridgeStyle.label("EDITING BANK / FOUR SAMPLES")
                    HStack(spacing: 8) {
                        TextField("Bank name", text: $configuration.bankNames[bank])
                            .textFieldStyle(.plain).font(.system(size: 25, weight: .semibold))
                        Image(systemName: "pencil").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 12)
                Toggle("Actions", isOn: $configuration.enabledBanks[bank]).toggleStyle(.switch).controlSize(.small)
                    .fixedSize().help("Disable this bank's actions while keeping preview recognition active")
            }
            Text(bank == 0 ? "No FX light and FX 1 share this bank. Select a sample on the mic, then press PLAY." : "Select FX \(bank + 1) with orange. Select a sample, then press PLAY to fire its action.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                ForEach(0..<4) { sample in
                    Button { selectedSlot = sample } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(String(format: "%02d", sample + 1)).font(.system(size: 24, weight: .medium, design: .monospaced))
                                Spacer()
                                Circle().fill(selectedSlot == sample ? BridgeStyle.orange : Color.secondary.opacity(0.2)).frame(width: 6, height: 6)
                            }
                            Text(configuration.tones[bank * 4 + sample].action.label).font(.callout).lineLimit(1)
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedSlot == sample ? BridgeStyle.orange.opacity(0.10) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selectedSlot == sample ? BridgeStyle.orange.opacity(0.65) : Color.primary.opacity(0.06)))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("Edit sample \(sample + 1)")
                        .help(configuration.tones[bank * 4 + sample].action.label)
                }
            }
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    BridgeStyle.label("SAMPLE \(String(format: "%02d", selectedSlot + 1)) / ACTION")
                    Spacer()
                    Text(configuration.enabledBanks[bank] ? "ENABLED" : "PREVIEW ONLY")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(configuration.enabledBanks[bank] ? BridgeStyle.orange : .secondary)
                }
                ActionEditor(title: "", action: $configuration.tones[index].action).id(index)
            }.padding(20).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
            DisclosureGroup {
                HStack {
                    TextField("Frequency", value: $configuration.tones[index].frequency, format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.roundedBorder).frame(width: 100)
                    Text("Hz · change only for a different cue pack").foregroundStyle(.secondary)
                }.padding(.top, 8)
            } label: {
                HStack {
                    Text("Cue tuning")
                    Spacer()
                    Text("\(Int(configuration.tones[index].frequency)) Hz").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                }
            }.font(.callout)
            if !configuration.enabledBanks[bank] {
                Text("This bank is in preview only. Enable Actions above when you want these mappings to fire.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
