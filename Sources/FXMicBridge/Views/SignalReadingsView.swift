import FXMicCore
import SwiftUI

/// Observe fast-changing measurements here so the monitor's controls stay outside that update scope.
struct SignalReadingsView: View {
    let model: BridgeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            measurements
            threshold
            VStack(alignment: .leading, spacing: 8) {
                Text("AMPLITUDE HISTORY").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HistoryChart(points: model.readings.history, threshold: model.settings.thresholdDB)
            }
            spectrum
        }
    }

    private var measurements: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("INPUT LEVEL").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Label(model.isRunning ? (model.signalPresent ? "SIGNAL" : "NO SIGNAL") : "NO INPUT", systemImage: "circle.fill")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(model.signalPresent ? Color.green : Color.secondary)
            }
            LevelMeter(rmsDB: model.readings.monitorSnapshot.rmsDB, peakDB: model.readings.monitorSnapshot.peakDB, threshold: model.settings.thresholdDB).frame(height: 14)
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                metric("RMS", String(format: "%.1f", model.readings.monitorSnapshot.rmsDB), "dBFS")
                metric("Peak", String(format: "%.1f", model.readings.monitorSnapshot.peakDB), "dBFS")
                Spacer()
                if model.readings.monitorSnapshot.sampleRate > 0 {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(String(format: "%.0f Hz · %d ch", model.readings.monitorSnapshot.sampleRate, model.readings.monitorSnapshot.channelCount))
                        Text("Loudest channel: \(model.readings.monitorSnapshot.analyzedChannel)")
                    }.font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var threshold: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Signal threshold").font(.callout)
                Slider(value: Binding(get: { model.settings.thresholdDB }, set: { model.setThreshold(($0 * 2).rounded() / 2) }), in: -100 ... -6) { editing in
                    if !editing { model.thresholdEditingEnded() }
                }
                .accessibilityLabel("Signal threshold")
                Text(String(format: "%.1f dBFS", model.settings.thresholdDB))
                    .font(.system(.callout, design: .monospaced)).frame(width: 94, alignment: .trailing)
            }
            Text("Orange line · logs when RMS crosses this level. Adjust while testing released, held, and speaking states.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var spectrum: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Show spectrum", isOn: Binding(get: { model.settings.showSpectrum }, set: model.setSpectrumVisible))
                    .toggleStyle(.checkbox)
                Spacer()
                Text(model.readings.monitorSnapshot.dominantFrequency.map { String(format: "Dominant  %.1f Hz", $0) } ?? "Dominant  —")
                    .font(.system(.callout, design: .monospaced))
            }
            if model.settings.showSpectrum {
                SpectrumChart(snapshot: model.readings.monitorSnapshot)
                Text(String(format: "Peak concentration %.0f%% · 4,096-sample Hann FFT · spectral peak, not a recognized control", model.readings.monitorSnapshot.peakConcentration * 100))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func metric(_ label: String, _ value: String, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.title2, design: .monospaced).weight(.medium)).monospacedDigit()
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
    }
}
