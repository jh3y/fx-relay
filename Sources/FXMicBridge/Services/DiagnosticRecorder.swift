import AppKit
import FXMicCore
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class DiagnosticRecorder {
    private(set) var isRecording = false
    private(set) var isSaving = false
    private(set) var step: DiagnosticStep?
    private(set) var stepNumber = 1
    private(set) var stepCount = DiagnosticCheck.fxButton.steps.count
    var selectedCheck = DiagnosticCheck.fxButton
    private(set) var phase = "ready"
    private(set) var secondsRemaining = 0
    private(set) var measurementCount = 0
    private(set) var probeMeasurementCount = 0
    var stepObservations: [String: String] = [:]
    private(set) var savedURL: URL?
    private(set) var errorMessage: String?
    private(set) var completionMessage: String?
    var notes = "" { didSet { session?.setNotes(notes) } }
    var onEvent: ((String) -> Void)?
    var onProbeSessionChanged: ((UUID?) -> Void)?
    private var session: DiagnosticSession?
    private var destination: URL?
    private var timer: Timer?
    private let writer = DispatchQueue(label: "com.jhey.fxmicbridge.diagnostic-export", qos: .utility)
    private var lastCheckpoint: Double = 0

    func start(metadata: DiagnosticMetadata, canStart: () -> Bool) {
        guard !isRecording, !isSaving, errorMessage == nil else { return }
        let panel = NSSavePanel()
        panel.title = "Save FX-MIC diagnostic report"
        panel.message = "This file contains levels, frequencies, notes, and events. It contains no audio or transcript. Choose where to save it; progress is saved every 10 seconds."
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "FXMIC-diagnostic-\(Self.filenameDate()).json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url, canStart() else { return }
        let now = ProcessInfo.processInfo.systemUptime
        session = DiagnosticSession(metadata: metadata, uptime: now, check: selectedCheck)
        stepCount = selectedCheck.steps.count
        session?.setNotes(notes)
        destination = url
        savedURL = nil
        completionMessage = nil
        measurementCount = 0
        probeMeasurementCount = 0
        stepObservations = [:]
        lastCheckpoint = now
        isRecording = true
        onProbeSessionChanged?(selectedCheck == .fxButton ? session?.report.id : nil)
        refreshProgress(now)
        saveCheckpoint(final: false)
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer?.tolerance = 0.05
        onEvent?("Diagnostic recording started · measurements only")
    }

    func beginStep() {
        guard isRecording else { return }
        let now = ProcessInfo.processInfo.systemUptime
        session?.beginStep(at: now)
        refreshProgress(now)
    }

    func skipStep() {
        guard isRecording else { return }
        session?.skipStep(at: ProcessInfo.processInfo.systemUptime)
        tick()
    }

    func append(_ snapshot: SignalSnapshot, threshold: Double) {
        guard isRecording else { return }
        session?.append(snapshot, threshold: threshold)
    }

    func addEvent(_ message: String) {
        guard isRecording else { return }
        session?.event(message, at: ProcessInfo.processInfo.systemUptime)
    }

    func appendProbe(_ windows: [ProbeWindow], sessionID: UUID) {
        guard isRecording else { return }
        session?.appendProbe(windows, sessionID: sessionID)
    }

    func setObservation(_ text: String, stepID: String) {
        guard isRecording else { return }
        let value = String(text.prefix(500))
        stepObservations[stepID] = value
        session?.setObservation(value, for: stepID)
    }

    func finish(reason: String, waitForSave: Bool = false) {
        guard isRecording else {
            if waitForSave { writer.sync {} }
            return
        }
        session?.finish(reason: reason, at: ProcessInfo.processInfo.systemUptime)
        isRecording = false
        onProbeSessionChanged?(nil)
        timer?.invalidate()
        timer = nil
        completionMessage = session?.report.endReason
        phase = "finished"
        measurementCount = session?.report.measurements.count ?? 0
        probeMeasurementCount = session?.report.hardwareProbe?.measurements.count ?? 0
        onEvent?("Diagnostic recording stopped · \(reason)")
        saveCheckpoint(final: true, wait: waitForSave)
    }

    func saveAgain() {
        guard !isRecording, !isSaving, session != nil else { return }
        let panel = NSSavePanel()
        panel.title = "Save diagnostic report again"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = destination?.lastPathComponent ?? "FXMIC-diagnostic.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        destination = url
        errorMessage = nil
        saveCheckpoint(final: true)
    }

    func revealSavedFile() {
        if let savedURL { NSWorkspace.shared.activateFileViewerSelecting([savedURL]) }
    }

    private func tick() {
        guard isRecording, let session else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let changed = session.tick(at: now)
        if session.isFinished {
            finish(reason: session.report.endReason ?? "Finished")
            return
        }
        refreshProgress(now)
        if changed { onEvent?("Diagnostic step complete · prepare step \(stepNumber)") }
        if now - lastCheckpoint >= 10 {
            lastCheckpoint = now
            saveCheckpoint(final: false)
        }
    }

    private func refreshProgress(_ now: Double) {
        guard let session else { return }
        if step != session.currentStep { step = session.currentStep }
        stepNumber = session.stepIndex + 1
        let nextPhase = session.phase(at: now)
        if phase != nextPhase { phase = nextPhase }
        let remaining = session.secondsRemaining(at: now)
        if secondsRemaining != remaining { secondsRemaining = remaining }
        measurementCount = session.report.measurements.count
        probeMeasurementCount = session.report.hardwareProbe?.measurements.count ?? 0
    }

    private func saveCheckpoint(final: Bool, wait: Bool = false) {
        guard let report = session?.report, let url = destination else { return }
        if final { isSaving = true }
        let work = { () -> String? in
            do { try report.encoded().write(to: url, options: .atomic); return nil }
            catch { return error.localizedDescription }
        }
        if wait {
            let error = writer.sync(execute: work)
            exportFinished(id: report.id, url: url, error: error, final: final)
        } else {
            writer.async { [weak self] in
                let error = work()
                DispatchQueue.main.async { self?.exportFinished(id: report.id, url: url, error: error, final: final) }
            }
        }
    }

    private func exportFinished(id: UUID, url: URL, error: String?, final: Bool) {
        guard session?.report.id == id else { return }
        if final { isSaving = false }
        if let error {
            errorMessage = "Report could not be saved: \(error). Your measurements are still in memory. Stop the check and use Save Report Again."
        } else {
            errorMessage = nil
            savedURL = url
            if final { onEvent?("Diagnostic report saved · \(url.lastPathComponent)") }
        }
    }

    private static func filenameDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
