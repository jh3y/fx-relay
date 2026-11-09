import FXMicCore
import SwiftUI

struct BankMappingsEditor: View {
    @Binding var configuration: BridgeConfiguration
    let bank: Int
    @Binding var selectedSlot: Int
    private var index: Int { bank * 4 + selectedSlot }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Text(String(format: "%02d", bank + 1)).font(.system(size: 22, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Editing bank").font(.caption).foregroundStyle(.secondary)
                    TextField("Bank name", text: $configuration.bankNames[bank])
                        .textFieldStyle(.plain).font(.system(size: 20, weight: .semibold))
                        .accessibilityLabel("Bank \(bank + 1) name")
                }
                Spacer(minLength: 12)
                Toggle("Samples enabled", isOn: $configuration.enabledBanks[bank])
                    .toggleStyle(.switch).controlSize(.small).fixedSize()
                    .help("Enables sample actions only; the handle is configured separately")
            }
            Divider()
            Picker("Configure", selection: Binding(get: { selectedSlot < 0 }, set: { selectedSlot = $0 ? -1 : 0 })) {
                Text("Samples").tag(false); Text("Handle").tag(true)
            }.pickerStyle(.segmented).frame(width: 240)
            if selectedSlot < 0 { BankHandleEditor(configuration: $configuration, bank: bank) }
            else {
                VStack(spacing: 0) {
                    ForEach(0..<4) { sample in
                        Button { selectedSlot = sample } label: {
                            HStack(spacing: 12) {
                                Text(String(format: "%02d", sample + 1)).font(.system(size: 12, weight: .medium, design: .monospaced)).frame(width: 24)
                                Text(configuration.tones[bank * 4 + sample].action.label).lineLimit(1)
                                Spacer(minLength: 4)
                                Image(systemName: selectedSlot == sample ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedSlot == sample ? BridgeStyle.orange : Color.secondary.opacity(0.5))
                            }.padding(.horizontal, 12).padding(.vertical, 10).contentShape(Rectangle())
                                .background(selectedSlot == sample ? BridgeStyle.selection : Color.clear)
                        }.buttonStyle(.plain)
                            .accessibilityLabel("Sample \(sample + 1): \(configuration.tones[bank * 4 + sample].action.label)")
                            .accessibilityAddTraits(selectedSlot == sample ? [.isSelected] : [])
                        if sample < 3 { Divider() }
                    }
                }.clipShape(RoundedRectangle(cornerRadius: BridgeStyle.radius)).bridgeWell()
                HStack {
                    Text("Sample \(selectedSlot + 1)").font(.system(size: 15, weight: .semibold))
                    Spacer()
                    if !configuration.enabledBanks[bank] { Label("Preview only", systemImage: "speaker.slash").font(.caption).foregroundStyle(.secondary) }
                }
                ActionEditor(title: "", action: $configuration.tones[index].action).id(index)
                Divider()
                DisclosureGroup("Cue tuning · \(Int(configuration.tones[index].frequency)) Hz") {
                    HStack {
                        TextField("Frequency", value: $configuration.tones[index].frequency, format: .number.precision(.fractionLength(0)))
                            .textFieldStyle(.roundedBorder).frame(width: 110)
                        Text("Hz · change only for a different cue pack").font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                }
            }
        }
    }
}
