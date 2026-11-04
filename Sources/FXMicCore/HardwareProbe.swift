import Foundation

/// Measurement-only summaries. Audio samples never leave the capture queue.
public struct ProbeChannel: Codable, Sendable {
    public let rmsDB: Double
    public let peakDB: Double
    public let mean: Double
    public let maximumSampleChange: Double
}

public struct ProbeWindow: Sendable {
    public let startUptime: Double
    public let endUptime: Double
    public let sampleRate: Double
    public let sampleCount: Int
    public let channels: [ProbeChannel]
}

public enum HardwareProbe {
    /// Covers every sample in each delivered buffer, including its short final window.
    /// Times estimate buffer end from callback arrival; these are not hardware timestamps.
    /// This inexpensive extra pass runs only during the optional FX-button check.
    public static func analyze(channels: [[Float]], sampleRate: Double, receivedAt: Double) -> [ProbeWindow] {
        guard sampleRate.isFinite, sampleRate >= 8000, sampleRate <= 384000,
              receivedAt.isFinite, let count = channels.first?.count, count > 0,
              channels.count <= 64, channels.allSatisfy({ $0.count == count }) else { return [] }
        let windowSize = max(1, Int(sampleRate * 0.01))
        let bufferStart = receivedAt - Double(count) / sampleRate
        var result: [ProbeWindow] = []
        for start in stride(from: 0, to: count, by: windowSize) {
            let end = min(count, start + windowSize)
            var stats: [ProbeChannel] = []
            for channel in channels {
                var sum = 0.0, squares = 0.0, peak = 0.0, change = 0.0
                var previous = Double(channel[max(0, start - 1)])
                for index in start..<end {
                    let value = Double(channel[index])
                    guard value.isFinite else { return [] }
                    sum += value; squares += value * value
                    peak = max(peak, abs(value)); change = max(change, abs(value - previous))
                    previous = value
                }
                stats.append(ProbeChannel(rmsDB: db(sqrt(squares / Double(end - start))),
                    peakDB: db(peak), mean: sum / Double(end - start), maximumSampleChange: change))
            }
            result.append(ProbeWindow(startUptime: bufferStart + Double(start) / sampleRate,
                endUptime: bufferStart + Double(end) / sampleRate, sampleRate: sampleRate,
                sampleCount: end - start, channels: stats))
        }
        return result
    }

    private static func db(_ amplitude: Double) -> Double { max(-120, 20 * log10(max(amplitude, 0.000001))) }
}

public struct ProbeMeasurement: Codable, Sendable {
    public let startedAtSeconds: Double
    public let endedAtSeconds: Double
    public let stepID: String
    public let phase: String
    public let sampleRate: Double
    public let sampleCount: Int
    public let channels: [ProbeChannel]
}

public struct HardwareProbeReport: Codable, Sendable {
    public private(set) var maximumWindowSeconds = 0.01
    public private(set) var timestampBasis = "Buffer end estimated from capture callback arrival; not hardware timestamps. Windows may overlap in wall time due to callback jitter."
    public private(set) var capacity = 40000
    public var omittedWindows = 0
    public var measurements: [ProbeMeasurement] = []
}
