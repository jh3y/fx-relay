import Foundation

/// A bounded, measurement-only test script. Times use the same monotonic clock as capture.
public final class DiagnosticSession {
    public static let maximumSeconds: Double = 300
    public static let maximumMeasurements = 4600
    public static let maximumEvents = 3000
    public private(set) var report: DiagnosticReport
    public private(set) var stepIndex = 0
    public private(set) var measurementStart: Double?
    public private(set) var isFinished = false
    private let startedAtUptime: Double
    private var lastFrameTime = -Double.infinity
    private var stepReadyAt: Double = 0

    public init(metadata: DiagnosticMetadata, uptime: Double, date: Date = Date(), check: DiagnosticCheck = .full) {
        startedAtUptime = uptime
        report = DiagnosticReport(id: UUID(), startedAt: date, metadata: metadata,
                                  protocolSteps: check.steps)
        if check == .fxButton { report.hardwareProbe = HardwareProbeReport() }
        event("Diagnostic session started; measurements only", at: uptime)
    }

    public var currentStep: DiagnosticStep? {
        guard !isFinished, stepIndex < report.protocolSteps.count else { return nil }
        return report.protocolSteps[stepIndex]
    }

    public func phase(at uptime: Double) -> String {
        guard !isFinished else { return "finished" }
        guard let start = measurementStart else { return "ready" }
        return elapsed(uptime) < start ? "countdown" : "measuring"
    }

    public func secondsRemaining(at uptime: Double) -> Int {
        guard let start = measurementStart, let step = currentStep else { return 0 }
        let now = elapsed(uptime)
        return Int(ceil(max(0, (now < start ? start : start + step.duration) - now)))
    }

    public func beginStep(at uptime: Double) {
        guard !isFinished, measurementStart == nil, let step = currentStep else { return }
        measurementStart = elapsed(uptime) + 3
        event("Preparing: \(step.title); measure after 3 seconds", at: uptime)
    }

    public func skipStep(at uptime: Double) {
        guard !isFinished, measurementStart == nil, let step = currentStep else { return }
        report.stepResults.append(.init(stepID: step.id, outcome: "skipped", measurementStartedAt: nil, endedAt: elapsed(uptime)))
        event("Skipped: \(step.title)", at: uptime)
        stepIndex += 1
        stepReadyAt = elapsed(uptime)
        if currentStep == nil { finish(reason: "Protocol finished (includes skipped steps)", at: uptime) }
    }

    /// Returns true when the step changes or the session finishes.
    @discardableResult public func tick(at uptime: Double) -> Bool {
        guard !isFinished else { return false }
        if elapsed(uptime) >= Self.maximumSeconds {
            finish(reason: "Five-minute limit reached; partial report", at: uptime)
            return true
        }
        if let start = measurementStart, let step = currentStep, elapsed(uptime) >= start + step.duration {
            report.stepResults.append(.init(stepID: step.id, outcome: "completed", measurementStartedAt: start, endedAt: start + step.duration))
            event("Completed: \(step.title)", at: uptime)
            measurementStart = nil
            stepIndex += 1
            stepReadyAt = elapsed(uptime)
            if currentStep == nil {
                let skipped = report.stepResults.contains { $0.outcome == "skipped" }
                finish(reason: skipped ? "Protocol finished (includes skipped steps)" : "Protocol completed", at: uptime)
            }
            return true
        }
        return false
    }

    public func append(_ snapshot: SignalSnapshot, threshold: Double) {
        guard !isFinished, snapshot.capturedAtUptime >= startedAtUptime,
              elapsed(snapshot.capturedAtUptime) < Self.maximumSeconds,
              snapshot.capturedAtUptime > lastFrameTime,
              report.measurements.count < Self.maximumMeasurements,
              let step = currentStep else { return }
        // Exclude queued frames predating a new step and frames beyond the measured interval.
        let elapsedTime = elapsed(snapshot.capturedAtUptime)
        guard elapsedTime >= stepReadyAt else { return }
        let start = measurementStart
        let framePhase: String
        if let start, elapsedTime >= start, elapsedTime < start + step.duration { framePhase = "measuring" }
        else if let start, elapsedTime < start { framePhase = "countdown" }
        else { framePhase = "ready" }
        lastFrameTime = snapshot.capturedAtUptime
        report.measurements.append(.init(snapshot: snapshot, elapsed: elapsedTime,
            stepID: step.id, phase: framePhase, threshold: threshold))
    }

    public func appendProbe(_ windows: [ProbeWindow], sessionID: UUID) {
        guard !isFinished, report.id == sessionID, report.hardwareProbe != nil else { return }
        for window in windows {
            let start = window.startUptime - startedAtUptime
            let end = window.endUptime - startedAtUptime
            guard start >= 0, end < Self.maximumSeconds,
                  report.hardwareProbe!.measurements.count < report.hardwareProbe!.capacity else {
                report.hardwareProbe?.omittedWindows += 1
                continue
            }
            // Label using capture time, not main-thread delivery time. In-flight buffers can
            // arrive after the timer advances the UI to the next step.
            var id = currentStep?.id ?? "between_steps"
            var phase = "boundary"
            if let previous = report.stepResults.last(where: {
                if let from = $0.measurementStartedAt { return start >= from && end <= $0.endedAt }
                return false
            }) {
                id = previous.stepID; phase = "measuring"
            } else if let step = currentStep, start >= stepReadyAt {
                if let from = measurementStart {
                    if end <= from { phase = "countdown" }
                    else if start >= from && end <= from + step.duration { phase = "measuring" }
                    else if start >= from + step.duration { phase = "ready" }
                } else { phase = "ready" }
            }
            report.hardwareProbe?.measurements.append(ProbeMeasurement(startedAtSeconds: start,
                endedAtSeconds: end, stepID: id, phase: phase, sampleRate: window.sampleRate,
                sampleCount: window.sampleCount, channels: window.channels))
        }
    }

    public func setObservation(_ text: String, for stepID: String) {
        guard !isFinished, report.protocolSteps.contains(where: { $0.id == stepID }) else { return }
        if report.stepObservations == nil { report.stepObservations = [:] }
        report.stepObservations?[stepID] = String(text.prefix(500))
    }

    public func event(_ message: String, at uptime: Double) {
        guard !isFinished, report.events.count < Self.maximumEvents else { return }
        report.events.append(.init(elapsedSeconds: elapsed(uptime), message: String(message.prefix(2000))))
    }

    public func setNotes(_ notes: String) { report.metadata.notes = String(notes.prefix(8000)) }

    public func finish(reason: String, at uptime: Double) {
        guard !isFinished else { return }
        if let step = currentStep, let start = measurementStart {
            report.stepResults.append(.init(stepID: step.id, outcome: "interrupted", measurementStartedAt: start,
                                           endedAt: elapsed(uptime)))
        }
        event("Session ended: \(reason)", at: uptime)
        report.durationSeconds = elapsed(uptime)
        report.endReason = reason
        measurementStart = nil
        isFinished = true
    }

    private func elapsed(_ uptime: Double) -> Double { max(0, uptime - startedAtUptime) }
}
