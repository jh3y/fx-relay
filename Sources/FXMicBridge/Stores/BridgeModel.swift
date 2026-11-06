import AppKit
import AVFoundation
import FXMicCore
import Observation
import OSLog

@MainActor @Observable
final class BridgeModel {
    static let shared = BridgeModel()
    let permissions = PermissionManager()
    let actions = ActionDispatcher()
    let micSetup = MicSetupModel()
    let diagnostics = DiagnosticRecorder()
    let readings = LiveReadings()
    let profiles: ProfileManager
    private(set) var devices: [AudioInputDevice] = []
    private(set) var settings: MonitorSettings
    private(set) var bridgeConfiguration: BridgeConfiguration
    private(set) var detectedPTT = false
    @ObservationIgnored private var handleRouter = BankHandleRouter(startupBank: 0)
    private(set) var handleBank: Int? = 0
    private(set) var handleBankSource: BankHandleRouter.Source? = .startup
    private(set) var handleRouteState = BankHandleRouter.State.waitingForQuiet
    private(set) var detectedTone: Int?
    private(set) var toneCounts = [Int](repeating: 0, count: BridgeConfiguration.controlCount)
    private(set) var lastRecognizedControl: Int?
    var hasUnsavedMappings = false { didSet { reconcileOutput() } }
    private var lastToneTime = -Double.infinity
    @ObservationIgnored private var checkFrames: [BridgeCheckFrame] = []
    @ObservationIgnored private var controlTrace = ControlTraceRecorder()
    @ObservationIgnored private var lastControlBlockEndUptime: Double?
    private(set) var events: [MonitorEvent] = []
    private(set) var isRunning = false
    private(set) var isStarting = false
    private(set) var signalPresent = false
    private(set) var monitoringEnabled = true
    private(set) var errorMessage: String?
    private(set) var receivedTestDowns = 0
    private(set) var receivedTestUps = 0
    private let store: SettingsStore
    private let deviceManager = AudioDeviceManager()
    private let capture = AudioCaptureEngine()
    private let logger = Logger(subsystem: "com.jhey.fxmicbridge", category: "events")
    private var generation = UUID()
    private var started = false
    private var sleeping = false
    private var observers: [NSObjectProtocol] = []
    private var permissionTimer: Timer?

    init(defaults: UserDefaults = .standard) {
        store = SettingsStore(defaults: defaults)
        settings = store.load()
        monitoringEnabled = store.loadMonitoringEnabled()
        profiles = ProfileManager(legacy: store.loadBridge(), defaults: defaults)
        bridgeConfiguration = profiles.selected.configuration
        micSetup.onWillInstall = { [weak self] in
            self?.monitoringEnabled = false
            self?.stopCapture(reason: "Installing mic cue pack")
        }
        profiles.onWillChange = { [weak self] next in
            guard let self else { return }
            // Bank identity belongs to the cue layout. Editing keyboard actions
            // does not move the physical selector; a different cue layout invalidates it.
            let sameCues = self.bridgeConfiguration.tones.map(\.frequency) == next.configuration.tones.map(\.frequency)
            self.stopCapture(reason: "Profile or mappings changed", preservingHandleBank: sameCues)
        }
        profiles.onChange = { [weak self] in
            guard let self else { return }
            self.bridgeConfiguration = self.profiles.selected.configuration
            self.hasUnsavedMappings = false
            self.lastRecognizedControl = nil; self.toneCounts = [Int](repeating: 0, count: BridgeConfiguration.controlCount)
            self.log("Profile saved/selected · \(self.profiles.selected.name)")
            self.reconcileCapture()
        }
    }

    var selectedDevice: AudioInputDevice? { devices.first { $0.id == settings.selectedDeviceUID } }
    var selectedDeviceName: String { selectedDevice?.name ?? settings.selectedDeviceName }

    var status: String {
        if permissions.microphone != .authorized { return "Microphone permission needed" }
        if settings.selectedDeviceUID.isEmpty { return "Select an input" }
        if selectedDevice == nil { return "Selected input disconnected" }
        if errorMessage != nil { return "Capture error" }
        if !monitoringEnabled || sleeping { return "Monitoring paused" }
        if isStarting { return "Connecting…" }
        if isRunning && detectedTone != nil { return "TONE DETECTED · \(bridgeConfiguration.controlLabel(detectedTone!))" }
        if isRunning && detectedPTT { return actions.pttHeld ? "PTT ACTIVE · key held" : "HANDLE SIGNAL · " + handleStatus }
        if isRunning { return signalPresent ? "Signal present" : "Connected · no signal" }
        return "Ready"
    }

    var statusSymbol: String {
        if permissions.microphone != .authorized || !permissions.accessibility || errorMessage != nil { return "exclamationmark.triangle" }
        if actions.isHeld || actions.pttHeld { return "keyboard.fill" }
        if detectedTone != nil { return "bolt.circle.fill" }
        if detectedPTT { return "waveform.circle.fill" }
        if !isRunning { return "mic.slash" }
        return signalPresent ? "waveform" : "mic"
    }

    func start() {
        guard !started else { return }
        started = true
        actions.onEvent = { [weak self] in self?.log($0) }
        diagnostics.onEvent = { [weak self] in self?.log($0) }
        diagnostics.onProbeSessionChanged = { [weak self] in self?.capture.setProbeSession($0) }
        deviceManager.onChange = { [weak self] in self?.devicesChanged($0) }
        deviceManager.onError = { [weak self] in self?.log($0) }
        deviceManager.start()
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.reconcileOutput() } })
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshPermissions(); self?.reconcileOutput() }
            })
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.sleeping = true
                    self.stopCapture(reason: "Mac sleeping or session locked")
                }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.sleeping = false
                    self?.refreshPermissions()
                    self?.reconcileCapture()
                }
            })
        }
        // A low-frequency permission check catches revocation while the monitor is in the background.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
        permissionTimer?.tolerance = 0.5
        log("Bridge ready · automatic output to the focused app")
    }

    func chooseDevice(_ uid: String) {
        guard uid != settings.selectedDeviceUID else { return }
        stopCapture(reason: "Input selection changed")
        settings.selectedDeviceUID = uid
        settings.selectedDeviceName = devices.first { $0.id == uid }?.name ?? ""
        store.save(settings)
        errorMessage = nil
        log(uid.isEmpty ? "Input deselected" : "Input selected · \(settings.selectedDeviceName)")
        reconcileCapture()
    }

    func setThreshold(_ value: Double) {
        settings.thresholdDB = min(-6, max(-100, value))
        store.save(settings)
        capture.setThreshold(settings.thresholdDB)
    }

    func thresholdEditingEnded() { log(String(format: "Signal threshold · %.1f dBFS", settings.thresholdDB)) }

    func setSpectrumVisible(_ visible: Bool) {
        settings.showSpectrum = visible
        store.save(settings)
    }

    func applyBridgeConfiguration(_ configuration: BridgeConfiguration) {
        profiles.update(configuration: configuration)
    }

    var currentHandleAction: BridgeAction? { bridgeConfiguration.resolvedHandleAction(for: handleBank) }
    var handleStatus: String {
        switch handleRouteState {
        case .unknownBank: return "Select a handle bank or play a sample"
        case .unassigned: return "No keyboard action in this bank"
        case .waitingForQuiet: return "Waiting for quiet before the next handle action"
        case .ready: return "Ready · speak while holding the handle"
        case .active: return actions.pttHeld ? "Key held · \(currentHandleAction?.label ?? "")" : "Signal active · \(actions.isArmed ? "see event log" : "output suspended")"
        }
    }
    func selectHandleBank(_ bank: Int?) {
        actions.disable(reason: "Handle bank selected manually")
        handleRouter.select(bank)
        refreshHandleRouting()
        log(handleBank.map { "Handle bank selected manually · " + bridgeConfiguration.bankNames[$0] } ?? "Handle bank cleared; awaiting a sample")
    }
    private func refreshHandleRouting() {
        if handleBank != handleRouter.bank { handleBank = handleRouter.bank }
        if handleBankSource != handleRouter.source { handleBankSource = handleRouter.source }
        if handleRouteState != handleRouter.state { handleRouteState = handleRouter.state }
    }

    private func reconcileOutput() {
        let reason: String?
        if !monitoringEnabled { reason = "Paused" }
        else if sleeping { reason = "Mac sleeping or session locked" }
        else if !permissions.accessibility { reason = "Accessibility permission needed" }
        else if !isRunning { reason = errorMessage ?? "Waiting for microphone" }
        else if diagnostics.isRecording { reason = "Guided check · observing only" }
        else if hasUnsavedMappings { reason = "Apply or revert your mapping changes" }
        else if micSetup.busy { reason = "Installing mic cue pack" }
        else { reason = nil }
        actions.setAvailability(blockedBy: reason)
    }

    func exportBridgeCheck() {
        let panel = NSSavePanel()
        panel.title = "Save Bridge Check"
        panel.nameFieldStringValue = "FXMIC-bridge-check-\(Int(Date().timeIntervalSince1970)).json"
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.allowedContentTypes = [.json]
        struct Check: Encodable {
            let schemaVersion = 4
            let profile: BridgeProfile
            let version: String; let input: String; let configuration: BridgeConfiguration
            let handleBank: Int?; let handleBankSource: BankHandleRouter.Source?; let handleRouteState: BankHandleRouter.State
            let toneCounts: [Int]; let rmsDB: Double; let peakDB: Double; let events: [String]
            let savedAt: String; let recentMeasurements: [BridgeCheckFrame]
            let exportedAtUptime: Double; let keyboardOutputEnabled: Bool
            let controlTrace: ControlTraceReport?; let eventRecords: [BridgeCheckEvent]
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = ProcessInfo.processInfo.systemUptime
        let check = Check(profile: profiles.selected, version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            input: selectedDeviceName, configuration: bridgeConfiguration, handleBank: handleBank, handleBankSource: handleBankSource,
            handleRouteState: handleRouteState, toneCounts: toneCounts,
            rmsDB: readings.latest.rmsDB, peakDB: readings.latest.peakDB,
            events: events.map { "\(formatter.string(from: $0.time)) \($0.message)" },
            savedAt: formatter.string(from: Date()), recentMeasurements: checkFrames,
            exportedAtUptime: now, keyboardOutputEnabled: actions.isArmed,
            controlTrace: controlTrace.snapshot(finalState: controlCheckpoint(at: now)),
            eventRecords: events.map { BridgeCheckEvent(loggedAt: formatter.string(from: $0.time),
                loggedAtUptime: $0.uptime, analysisUptime: $0.analysisUptime, message: $0.message) })
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(check) else { log("Could not encode bridge check"); return }
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do { try data.write(to: url, options: .atomic); self?.log("Bridge check saved · \(url.lastPathComponent)") }
            catch { self?.log("Bridge check save failed · \(error.localizedDescription)") }
        }
    }

    func resetBridgeCheck() {
        checkFrames.removeAll(); toneCounts = [Int](repeating: 0, count: BridgeConfiguration.controlCount); events.removeAll(); lastRecognizedControl = nil
        beginControlTrace(reason: "Reset Check")
        log("Check cleared · PTT \(detectedPTT ? "active" : "inactive") · \(actions.bridgeStatus)")
    }

    private func controlCheckpoint(at uptime: Double) -> ControlStateCheckpoint {
        ControlStateCheckpoint(observedAtUptime: uptime, lastControlBlockEndUptime: lastControlBlockEndUptime,
            pttActive: detectedPTT, captureRunning: isRunning)
    }

    private func beginControlTrace(reason: String) {
        let now = ProcessInfo.processInfo.systemUptime
        controlTrace.begin(at: Date(), state: controlCheckpoint(at: now), reason: reason)
    }

    func toggleMonitoring() {
        guard !micSetup.busy else { return }
        if monitoringEnabled {
            monitoringEnabled = false
            store.saveMonitoringEnabled(false)
            stopCapture(reason: "Paused", preservingHandleBank: true)
        } else {
            monitoringEnabled = true
            store.saveMonitoringEnabled(true)
            errorMessage = nil
            reconcileCapture()
        }
    }

    func requestMicrophone() {
        permissions.requestMicrophone { [weak self] in self?.reconcileCapture(); self?.reconcileOutput() }
    }

    func refreshDevices() { deviceManager.refresh() }

    func refreshPermissions() {
        let oldMicrophone = permissions.microphone
        let oldAccessibility = permissions.accessibility
        permissions.refresh()
        if oldAccessibility && !permissions.accessibility {
            actions.cancel(reason: "Accessibility permission revoked")
            actions.disable(reason: "Accessibility permission revoked")
            log("Accessibility permission revoked")
        }
        if oldMicrophone != permissions.microphone {
            if permissions.microphone != .authorized { stopCapture(reason: "Microphone permission unavailable") }
            else { reconcileCapture() }
        }
        reconcileOutput()
    }

    func receiveTestEvent(isDown: Bool) {
        if isDown { receivedTestDowns += 1 } else { receivedTestUps += 1 }
        log("TEST Space \(isDown ? "DOWN" : "UP") received by this app")
    }

    func startDiagnostic() {
        guard isRunning else { return }
        actions.cancel(reason: "Starting hardware diagnostics")
        actions.disable(reason: "Starting hardware diagnostics")
        let captureGeneration = generation
        let info = Bundle.main.infoDictionary ?? [:]
        let metadata = DiagnosticMetadata(appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info["CFBundleVersion"] as? String ?? "unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            inputName: selectedDeviceName, initialThresholdDB: settings.thresholdDB,
            sampleRate: readings.latest.sampleRate, channelCount: readings.latest.channelCount, notes: diagnostics.notes)
        diagnostics.start(metadata: metadata, canStart: { self.isRunning && self.generation == captureGeneration })
    }

    func testKeyboard(destination: TestDestination) {
        guard !diagnostics.isRecording else { return }
        actions.testSpace(destination: destination)
    }

    func clearEvents() { events.removeAll() }

    func monitorClosed() {
        actions.cancel(reason: "Signal Monitor closed")
        diagnostics.finish(reason: "Signal Monitor closed; partial report")
    }

    func copyEvents() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let text = events.map { "\(formatter.string(from: $0.time))  \($0.message)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func log(_ message: String, analysisUptime: Double? = nil) {
        diagnostics.addEvent(message)
        events.append(MonitorEvent(message: message, analysisUptime: analysisUptime))
        if events.count > 300 { events.removeFirst(events.count - 300) }
        logger.info("\(message, privacy: .public)")
    }

    func shutdown() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        stopCapture(reason: "App quitting")
        diagnostics.finish(reason: "App quitting", waitForSave: true)
    }

    private func devicesChanged(_ inputs: [AudioInputDevice]) {
        let oldDevice = selectedDevice
        devices = inputs
        if let oldDevice, selectedDevice == nil {
            stopCapture(reason: "Input disconnected")
            log("Input disconnected · \(oldDevice.name)")
        } else if let selectedDevice, oldDevice != selectedDevice {
            stopCapture(reason: "Input reconnected or changed")
            errorMessage = nil
            settings.selectedDeviceName = selectedDevice.name
            store.save(settings)
            log("Input available · \(selectedDevice.name)")
            reconcileCapture()
        }
    }

    private func reconcileCapture() {
        guard monitoringEnabled, !sleeping, !isRunning, !isStarting,
              permissions.microphone == .authorized, let device = selectedDevice else { return }
        errorMessage = nil
        isStarting = true
        checkFrames.removeAll()
        lastControlBlockEndUptime = nil
        beginControlTrace(reason: "Capture started")
        let token = UUID()
        generation = token
        capture.start(deviceUID: device.id, threshold: settings.thresholdDB, configuration: bridgeConfiguration,
            onControl: { [weak self] frame in
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.lastControlBlockEndUptime = frame.time
                    self.controlTrace.append(frame, receivedAtUptime: ProcessInfo.processInfo.systemUptime)
                    if self.detectedPTT != frame.pttActive { self.detectedPTT = frame.pttActive }
                    let handle = self.handleRouter.process(frame, configuration: self.bridgeConfiguration)
                    self.refreshHandleRouting()
                    if handle.bankChanged, let bank = self.handleBank {
                        self.log("Handle bank identified · \(self.bridgeConfiguration.bankNames[bank]) · \(self.currentHandleAction?.label ?? "Unknown")", analysisUptime: frame.time)
                    }
                    if let down = frame.pttTransition {
                        self.log("\(down ? "PTT DOWN" : "PTT UP") detected\(self.actions.isArmed ? "" : " · preview")",
                            analysisUptime: frame.pttEvaluation?.blockEndUptime)
                        if down && handle.activation == nil {
                            self.log("Handle action not sent · \(self.handleStatus)", analysisUptime: frame.time)
                        }
                    }
                    if let slot = frame.tone.detected {
                        self.toneCounts[slot] += 1; self.detectedTone = slot; self.lastRecognizedControl = slot; self.lastToneTime = frame.time
                        self.log(String(format: "%@ · tone %.0f Hz · confidence %.0f%%%@", self.bridgeConfiguration.controlLabel(slot),
                            frame.tone.frequency ?? self.bridgeConfiguration.tones[slot].frequency,
                            frame.tone.confidence * 100, self.actions.isArmed ? "" : " · preview"), analysisUptime: frame.time)
                    }
                    if self.detectedTone != nil, frame.time - self.lastToneTime > 0.6 { self.detectedTone = nil }
                    self.reconcileOutput()
                    self.actions.process(frame, configuration: self.bridgeConfiguration, handle: handle)
                }
            },
            onProbe: { [weak self] sessionID, windows in
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.diagnostics.appendProbe(windows, sessionID: sessionID)
                }
            }, onFrame: { [weak self] frame in
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    if self.isStarting {
                        self.log("Capture started · \(Int(frame.sampleRate)) Hz · \(frame.channelCount) channel(s)")
                        self.isStarting = false
                    }
                    if !self.isRunning { self.isRunning = true }
                    self.readings.append(frame)
                    self.diagnostics.append(frame, threshold: self.settings.thresholdDB)
                    let now = ProcessInfo.processInfo.systemUptime
                    if now - (self.checkFrames.last?.uptime ?? -.infinity) >= 0.2 {
                        self.checkFrames.append(BridgeCheckFrame(uptime: now, rmsDB: frame.rmsDB, peakDB: frame.peakDB,
                            dominantFrequency: frame.dominantFrequency, spectrumAgeSeconds: frame.spectrumAgeSeconds,
                            peakConcentration: frame.peakConcentration, spectrum: frame.compactSpectrum,
                            sampleRate: frame.sampleRate, analyzedChannel: frame.analyzedChannel))
                        if self.checkFrames.count > 600 { self.checkFrames.removeFirst(self.checkFrames.count - 600) }
                    }
                }
            }, onSignal: { [weak self] present in
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.signalPresent = present
                    self.log(present ? "signal started" : "signal ended")
                }
            }, onError: { [weak self] message in
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.log("ERROR · \(message)")
                    self.stopCapture(reason: "Capture error")
                    self.errorMessage = message
                }
            })
    }

    private func stopCapture(reason: String, preservingHandleBank: Bool = false) {
        generation = UUID()
        controlTrace.stop(at: ProcessInfo.processInfo.systemUptime, reason: reason)
        actions.cancel(reason: reason)
        actions.disable(reason: reason)
        capture.stop()
        if signalPresent { log("signal ended · \(reason)") }
        if isRunning || isStarting { log("Capture stopped · \(reason)") }
        diagnostics.finish(reason: reason)
        isRunning = false
        isStarting = false
        signalPresent = false
        detectedPTT = false; detectedTone = nil
        handleRouter.reset(preservingBank: preservingHandleBank); refreshHandleRouting()
        readings.reset()
        reconcileOutput()
    }
}

private struct BridgeCheckEvent: Encodable {
    let loggedAt: String
    let loggedAtUptime: Double
    let analysisUptime: Double?
    let message: String
}

private struct BridgeCheckFrame: Encodable {
    let uptime: Double
    let rmsDB: Double
    let peakDB: Double
    let dominantFrequency: Double?
    let spectrumAgeSeconds: Double?
    let peakConcentration: Double
    let spectrum: CompactSpectrum
    let sampleRate: Double
    let analyzedChannel: Int
}
