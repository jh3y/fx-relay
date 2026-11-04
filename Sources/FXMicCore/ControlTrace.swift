import Foundation

/// The previous block evaluated by PTT after the current block supplies cue lookahead.
public struct PTTEvaluation: Codable, Sendable {
    public let blockEndUptime: Double
    public let rmsDB: Double
    public let suppressed: Bool
    public let activeBefore: Bool
    public let activeAfter: Bool
    public let transition: Bool?
    public let confirmationStartedAtUptime: Double?
}

public struct ControlTraceSample: Codable, Sendable {
    public let blockEndUptime: Double
    public let receivedAtUptime: Double
    public let rmsDB: Double
    public let sampleRate: Double
    /// One-based audio channel and cue numbers, matching the monitor.
    public let channel: Int
    public let toneCandidate: Int?
    public let toneDetected: Int?
    public let toneConfidence: Double
    public let pttActive: Bool
    public let pttEvaluation: PTTEvaluation?

    init(_ frame: ControlFrame, receivedAtUptime: Double) {
        blockEndUptime = frame.time
        self.receivedAtUptime = receivedAtUptime
        rmsDB = frame.rmsDB; sampleRate = frame.sampleRate; channel = frame.channel
        toneCandidate = frame.tone.candidate.map { $0 + 1 }
        toneDetected = frame.tone.detected.map { $0 + 1 }
        toneConfidence = frame.tone.confidence
        pttActive = frame.pttActive; pttEvaluation = frame.pttEvaluation
    }
}

/// Last state processed by the model at a check boundary, not a physical handle measurement.
public struct ControlStateCheckpoint: Codable, Sendable {
    public let observedAtUptime: Double
    public let lastControlBlockEndUptime: Double?
    public let pttActive: Bool
    public let captureRunning: Bool

    public init(observedAtUptime: Double, lastControlBlockEndUptime: Double?,
                pttActive: Bool, captureRunning: Bool) {
        self.observedAtUptime = observedAtUptime
        self.lastControlBlockEndUptime = lastControlBlockEndUptime
        self.pttActive = pttActive; self.captureRunning = captureRunning
    }
}

public struct ControlTraceReport: Codable, Sendable {
    public let blockDurationSeconds: Double
    public let capacity: Int
    public let droppedSampleCount: Int
    public let ignoredBeforeStartCount: Int
    public let startedAt: String
    public let startReason: String
    public let initialState: ControlStateCheckpoint
    public let finalState: ControlStateCheckpoint
    public let stoppedAtUptime: Double?
    public let stopReason: String?
    public let samples: [ControlTraceSample]
}

/// A bounded, non-observable ring. Appending does not format dates or shift stored samples.
/// The owning serial context supplies all calls; no audio samples are retained.
public struct ControlTraceRecorder {
    public let capacity: Int
    private var storage: [ControlTraceSample] = []
    private var next = 0
    private var dropped = 0
    private var ignored = 0
    private var initialState: ControlStateCheckpoint?
    private var startedAt = ""
    private var startReason = ""
    private var stoppedAtUptime: Double?
    private var stopReason: String?

    public init(capacity: Int = 3000) {
        precondition(capacity > 0)
        self.capacity = capacity
        storage.reserveCapacity(capacity)
    }

    public mutating func begin(at date: Date, state: ControlStateCheckpoint, reason: String) {
        storage.removeAll(keepingCapacity: true)
        next = 0; dropped = 0; ignored = 0
        initialState = state; startedAt = Self.timestamp(date); startReason = reason
        stoppedAtUptime = nil; stopReason = nil
    }

    public mutating func append(_ frame: ControlFrame, receivedAtUptime: Double) {
        guard let initialState, stoppedAtUptime == nil else { return }
        // Reset can run while earlier capture callbacks are queued for the model.
        guard frame.time >= initialState.observedAtUptime else { ignored += 1; return }
        let sample = ControlTraceSample(frame, receivedAtUptime: receivedAtUptime)
        if storage.count < capacity { storage.append(sample) }
        else { storage[next] = sample; next = (next + 1) % capacity; dropped += 1 }
    }

    public mutating func stop(at uptime: Double, reason: String) {
        guard initialState != nil, stoppedAtUptime == nil else { return }
        stoppedAtUptime = uptime; stopReason = reason
    }

    public func snapshot(finalState: ControlStateCheckpoint) -> ControlTraceReport? {
        guard let initialState else { return nil }
        let samples = next == 0 ? storage : Array(storage[next...]) + Array(storage[..<next])
        return ControlTraceReport(blockDurationSeconds: 0.04, capacity: capacity,
            droppedSampleCount: dropped, ignoredBeforeStartCount: ignored,
            startedAt: startedAt, startReason: startReason,
            initialState: initialState, finalState: finalState,
            stoppedAtUptime: stoppedAtUptime, stopReason: stopReason, samples: samples)
    }

    public static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
