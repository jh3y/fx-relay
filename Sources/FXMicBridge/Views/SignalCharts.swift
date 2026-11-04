import FXMicCore
import SwiftUI

struct LevelMeter: View {
    let rmsDB: Double
    let peakDB: Double
    let threshold: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(peakDB > -1 ? Color.red : Color.accentColor)
                    .frame(width: geometry.size.width * fraction(rmsDB))
                Rectangle().fill(.primary.opacity(0.65)).frame(width: 2)
                    .offset(x: max(0, geometry.size.width * fraction(peakDB) - 2))
                Rectangle().fill(.orange).frame(width: 2)
                    .offset(x: geometry.size.width * fraction(threshold))
            }
        }
        .accessibilityLabel("Input level")
        .accessibilityValue(String(format: "RMS %.1f, peak %.1f decibels full scale", rmsDB, peakDB))
    }

    private func fraction(_ db: Double) -> Double { min(1, max(0, (db + 100) / 100)) }
}

struct HistoryChart: View {
    let points: [LevelPoint]
    let threshold: Double

    var body: some View {
        VStack(spacing: 5) {
            Canvas { context, size in
                func y(_ db: Double) -> Double { size.height * (1 - min(1, max(0, (db + 100) / 100))) }
                for db in stride(from: -100.0, through: 0.0, by: 20) {
                    var grid = Path()
                    grid.move(to: CGPoint(x: 0, y: y(db)))
                    grid.addLine(to: CGPoint(x: size.width, y: y(db)))
                    context.stroke(grid, with: .color(.secondary.opacity(0.15)), lineWidth: 1)
                }
                let now = points.last?.time ?? 0
                for peak in [true, false] {
                    var path = Path()
                    for (index, point) in points.enumerated() {
                        let position = CGPoint(x: size.width * (1 - (now - point.time) / 10), y: y(peak ? point.peakDB : point.rmsDB))
                        if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
                    }
                    context.stroke(path, with: .color(peak ? .secondary.opacity(0.5) : .accentColor), lineWidth: peak ? 1 : 1.6)
                }
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y(threshold)))
                line.addLine(to: CGPoint(x: size.width, y: y(threshold)))
                context.stroke(line, with: .color(.orange.opacity(0.75)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .frame(height: 100)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            HStack {
                Text("−10 s")
                Spacer()
                Text("RMS / peak · −100 to 0 dBFS")
                Spacer()
                Text("now")
            }.font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
        }
        .accessibilityLabel("Ten second input amplitude history")
    }
}

struct SpectrumChart: View {
    let snapshot: SignalSnapshot

    var body: some View {
        VStack(spacing: 5) {
            Canvas { context, size in
                let upper = min(20000, snapshot.sampleRate > 0 ? snapshot.sampleRate / 2 : 20000)
                guard upper > 20 else { return }
                func x(_ hz: Double) -> Double { log(hz / 20) / log(upper / 20) * size.width }
                for hz in [100.0, 1000, 10000] where hz < upper {
                    var line = Path()
                    line.move(to: CGPoint(x: x(hz), y: 0))
                    line.addLine(to: CGPoint(x: x(hz), y: size.height))
                    context.stroke(line, with: .color(.secondary.opacity(0.2)), lineWidth: 1)
                }
                var path = Path()
                var started = false
                for bin in snapshot.spectrumDB.indices {
                    let hz = Double(bin) * snapshot.sampleRate / Double(SignalAnalyzer.fftSize)
                    guard hz >= 20, hz <= upper else { continue }
                    let db = Double(snapshot.spectrumDB[bin])
                    let point = CGPoint(x: x(hz), y: size.height * (1 - min(1, max(0, (db + 100) / 100))))
                    if !started { path.move(to: point); started = true } else { path.addLine(to: point) }
                }
                context.stroke(path, with: .color(.accentColor), lineWidth: 1.2)
            }
            .frame(height: 86)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            HStack {
                Text("20 Hz")
                Spacer()
                Text("log frequency · −100 to 0 dBFS")
                Spacer()
                Text(snapshot.sampleRate > 0 ? String(format: "%.0f kHz", min(20000, snapshot.sampleRate / 2) / 1000) : "20 kHz")
            }.font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
        }
        .accessibilityLabel("Frequency spectrum")
    }
}
