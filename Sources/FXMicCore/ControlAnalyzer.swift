import Accelerate
import Foundation

public struct ControlFrame: Sendable {
    public let time: Double
    public let rmsDB: Double
    public let sampleRate: Double
    public let channel: Int
    public let pttActive: Bool
    public let pttTransition: Bool?
    public let pttEvaluation: PTTEvaluation?
    public let tone: ToneObservation
}

/// Serial capture-queue analysis, independent of UI FFT refresh and input buffer boundaries.
public final class ControlAnalyzer {
    private var ptt: PTTDetector
    private let tones: ToneDetecting
    private var pending: [Float] = []
    private var rate = 0.0
    private var channel = -1
    private var suppressUntil = -Double.infinity
    private var previousLevel: (db: Double, time: Double)?
    public init(configuration: BridgeConfiguration) {
        ptt = PTTDetector(configuration: configuration)
        tones = ToneDetector(configuration: configuration)
    }
    public func analyze(samples: [Float], sampleRate: Double, channel: Int, time: Double) -> [ControlFrame] {
        if rate != sampleRate || self.channel != channel {
            pending.removeAll(keepingCapacity: true); previousLevel = nil; rate = sampleRate; self.channel = channel
        }
        guard sampleRate >= 8000, sampleRate <= 192000 else { return [] }
        let size = Int(sampleRate * 0.04)
        pending.append(contentsOf: samples)
        var frames: [ControlFrame] = []
        var offset = 0
        while pending.count - offset >= size {
            let block = Array(pending[offset..<(offset + size)])
            offset += size
            let timestamp = time - Double(pending.count - offset) / sampleRate
            var rms: Float = 0
            vDSP_rmsqv(block, 1, &rms, vDSP_Length(size))
            let db = SignalAnalyzer.decibels(rms)
            let tone = tones.analyze(samples: block, sampleRate: rate, rmsDB: db, time: timestamp)
            if tone.candidate != nil { suppressUntil = timestamp + 0.12 }
            // One block of lookahead rejects a cue that starts near a block boundary.
            // This adds 40 ms to sound gating; no audio is retained beyond these analysis blocks.
            let evaluation = previousLevel.map { level in
                let before = ptt.isActive
                let suppressed = level.time <= suppressUntil
                let transition = ptt.update(rmsDB: level.db, time: level.time, suppress: suppressed)
                return PTTEvaluation(blockEndUptime: level.time, rmsDB: level.db,
                    suppressed: suppressed, activeBefore: before, activeAfter: ptt.isActive,
                    transition: transition, confirmationStartedAtUptime: ptt.confirmationStartedAtUptime)
            }
            previousLevel = (db, timestamp)
            frames.append(ControlFrame(time: timestamp, rmsDB: db, sampleRate: rate, channel: channel,
                pttActive: ptt.isActive, pttTransition: evaluation?.transition,
                pttEvaluation: evaluation, tone: tone))
        }
        if offset > 0 { pending.removeFirst(offset) }
        return frames
    }
}
