import Accelerate
import Foundation

public struct ToneObservation: Sendable {
    public let candidate: Int?
    public let detected: Int?
    public let heldControl: Int?
    public let frequency: Double?
    public let confidence: Double
}

public protocol ToneDetecting: AnyObject {
    func analyze(samples: [Float], sampleRate: Double, rmsDB: Double, time: Double) -> ToneObservation
}

/// Narrow-band sine projections (Accelerate dot products), bounded to sixteen configured targets.
/// A cue must dominate the entire signal and competing targets, persist, then rearm in silence.
public final class ToneDetector: ToneDetecting {
    private struct Probe { let slot: Int; let frequency: Double; let cosine: [Float]; let sine: [Float] }
    private let configuration: BridgeConfiguration
    private var probes: [Probe] = []
    private var rate = 0.0
    private var count = 0
    private var candidate: Int?
    private var candidateDuration = 0.0
    private var previousTime: Double?
    private var latched = false
    private var quietSince: Double?
    private var heldControl: Int?
    private var lastMatch = -Double.infinity
    private var lastEvent = -Double.infinity
    public init(configuration: BridgeConfiguration) { self.configuration = configuration.validated() }

    public func analyze(samples: [Float], sampleRate: Double, rmsDB: Double, time: Double) -> ToneObservation {
        var bestSlot: Int?
        var bestFrequency: Double?
        var confidence = 0.0
        if rmsDB >= configuration.toneFloorDB && !samples.isEmpty {
            prepare(count: samples.count, rate: sampleRate)
            var energy: Float = 0
            vDSP_svesq(samples, 1, &energy, vDSP_Length(samples.count))
            var scores = [Double](repeating: 0, count: configuration.tones.count)
            var frequencies = [Double](repeating: 0, count: configuration.tones.count)
            for probe in probes {
                var c: Float = 0, s: Float = 0
                vDSP_dotpr(samples, 1, probe.cosine, 1, &c, vDSP_Length(samples.count))
                vDSP_dotpr(samples, 1, probe.sine, 1, &s, vDSP_Length(samples.count))
                let score = Double(2 * (c * c + s * s)) / max(1e-20, Double(samples.count) * Double(energy))
                if score > scores[probe.slot] { scores[probe.slot] = score; frequencies[probe.slot] = probe.frequency }
            }
            let ranked = scores.indices.sorted { scores[$0] > scores[$1] }
            let first = ranked[0]
            confidence = min(1, scores[first])
            // The looser candidate threshold suppresses tone edges before they can open PTT.
            if scores[first] >= 0.65 && scores[first] > scores[ranked[1]] * 3,
               abs(frequencies[first] - configuration.tones[first].frequency) <= configuration.toleranceHz + 0.001 {
                bestSlot = first; bestFrequency = frequencies[first]
            }
        }
        if rmsDB < configuration.toneFloorDB {
            if quietSince == nil { quietSince = time }
            if time - quietSince! >= 0.12 { latched = false }
        } else { quietSince = nil }
        if let heldControl, bestSlot == heldControl { lastMatch = time }
        if time - lastMatch >= 0.12 { heldControl = nil }

        let stable = confidence >= 0.85 ? bestSlot : nil
        let duration = Double(samples.count) / sampleRate
        // Count actual analyzed signal duration, including the first stable block.
        // A timestamp gap never contributes unobserved time toward a short cue.
        if candidate != stable || previousTime.map({ abs(time - $0 - duration) > 0.01 }) == true {
            candidateDuration = 0
        }
        candidate = stable
        candidateDuration = stable == nil ? 0 : candidateDuration + duration
        previousTime = time
        var detected: Int?
        if let stable, !latched, candidateDuration + 0.000001 >= configuration.minimumToneDuration,
           time - lastEvent >= configuration.cooldown {
            detected = stable; heldControl = stable; lastMatch = time; lastEvent = time; latched = true
        }
        return ToneObservation(candidate: bestSlot, detected: detected, heldControl: heldControl,
                               frequency: bestFrequency, confidence: confidence)
    }

    private func prepare(count: Int, rate: Double) {
        guard count != self.count || rate != self.rate else { return }
        self.count = count; self.rate = rate
        probes = []
        for (slot, definition) in configuration.tones.enumerated() {
            // Guard probes outside the accepted band avoid accepting an out-of-band peak
            // merely because it leaks into the outermost accepted probe.
            for offset in stride(from: -configuration.toleranceHz - 15, through: configuration.toleranceHz + 15, by: 5) {
                let frequency = definition.frequency + offset
                guard frequency < rate / 2 - 50 else { continue }
                let phases = (0..<count).map { 2 * Double.pi * frequency * Double($0) / rate }
                probes.append(Probe(slot: slot, frequency: frequency, cosine: phases.map { Float(cos($0)) }, sine: phases.map { Float(sin($0)) }))
            }
        }
    }
}
