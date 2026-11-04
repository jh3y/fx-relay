import FXMicCore
import SwiftUI

struct DetectionSettingsView: View {
    @Binding var configuration: BridgeConfiguration
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            BridgeStyle.label("ADVANCED / SIGNAL ANALYSIS")
            Text("Detection").font(.title.weight(.semibold))
            Text("These settings affect recognition, not the mic's audio sent to other apps.").foregroundStyle(.secondary)
            GroupBox("Sound-based PTT") {
                VStack(spacing: 16) {
                    parameter("Activation", value: $configuration.activationDB, range: -90 ... -10, suffix: "dBFS")
                    parameter("Release below", value: $configuration.releaseDB, range: -100 ... configuration.activationDB, suffix: "dBFS")
                    seconds("Start confirmation", value: $configuration.activationDelay, range: 0 ... 0.4)
                    seconds("Release delay", value: $configuration.releaseDelay, range: 0.15 ... 3)
                }.padding(12)
            }
            Text("Confirmation rejects brief noise but delays the start of a hold. Quiet held and released handles cannot be distinguished reliably with the current hardware signal.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            GroupBox("Sample recognition") {
                VStack(spacing: 16) {
                    parameter("Minimum level", value: $configuration.toneFloorDB, range: -80 ... -10, suffix: "dBFS")
                    parameter("Tolerance ±", value: $configuration.toleranceHz, range: 5 ... 40, suffix: "Hz")
                    seconds("Minimum duration", value: $configuration.minimumToneDuration, range: 0.08 ... 0.25)
                    seconds("Cooldown", value: $configuration.cooldown, range: 0.2 ... 2)
                }.padding(12)
            }
        }
    }
    private func parameter(_ name: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        HStack {
            Text(name).frame(width: 120, alignment: .leading)
            Slider(value: value, in: range, step: 1)
            Text("\(Int(value.wrappedValue)) \(suffix)").font(.system(.caption, design: .monospaced)).frame(width: 80, alignment: .trailing)
        }
    }
    private func seconds(_ name: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(name).frame(width: 120, alignment: .leading)
            Slider(value: value, in: range, step: 0.01)
            Text("\(Int((value.wrappedValue * 1000).rounded())) ms").font(.system(.caption, design: .monospaced)).frame(width: 80, alignment: .trailing)
        }
    }
}
