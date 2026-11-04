import AppKit
import ApplicationServices
import FXMicCore
import Observation

enum TestDestination: String, CaseIterable, Identifiable {
    case monitor = "This app"
    case frontmost = "Target app in 3 seconds"
    var id: String { rawValue }
}

@MainActor @Observable
final class ActionDispatcher {
    nonisolated static let testMarker: Int64 = 0x46584D4943
    private(set) var isBusy = false
    private(set) var isHeld = false
    private(set) var status = "Ready to test"
    var onEvent: ((String) -> Void)?
    private let lease = HeldKeyLease()
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private(set) var isArmed = false
    private(set) var isArming = false
    private(set) var bridgeStatus = "Preview · keyboard output off"
    private(set) var pttHeld = false
    private var target: NSRunningApplication?
    private var armTask: Task<Void, Never>?
    private var armGeneration = UUID()
    private var held: [Int: (lease: HeldKeyLease, chord: KeyChord, token: UUID)] = [:]
    private var waitingForQuiet = true
    private var armedAt = Double.infinity
    private let textRunner = TextActionRunner()
    private var lastFrameAt = -Double.infinity

    func arm() {
        cancel(reason: "Enabling bridge")
        disable(reason: "New target")
        guard AXIsProcessTrusted() else { bridgeStatus = "Accessibility permission needed"; return }
        isArming = true
        let token = UUID()
        armGeneration = token
        armTask = Task { [weak self] in
            guard let self else { return }
            for seconds in (1...3).reversed() {
                bridgeStatus = "Focus your target app · \(seconds)…"
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, armGeneration == token else { return }
            }
            guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
                  app.processIdentifier != NSRunningApplication.current.processIdentifier, !app.isTerminated else {
                disable(reason: "Focus a different app before enabling output"); return
            }
            target = app
            armedAt = ProcessInfo.processInfo.systemUptime
            isArming = false; isArmed = true; waitingForQuiet = true
            bridgeStatus = "Waiting for silence · \(app.localizedName ?? "target app")"
            onEvent?("Keyboard output enabled → \(app.localizedName ?? "target app"); waiting for silence")
        }
    }

    func checkFocus() {
        guard isArmed else { return }
        if target?.isTerminated != false || target?.processIdentifier != NSWorkspace.shared.frontmostApplication?.processIdentifier {
            disable(reason: "Target app lost focus")
        }
    }

    func disable(reason: String) {
        let wasEnabled = isArmed || isArming
        armGeneration = UUID(); armTask?.cancel(); armTask = nil
        textRunner.cancel()
        isArmed = false; isArming = false; target = nil; waitingForQuiet = true
        for id in Array(held.keys) { release(id: id, reason: reason) }
        pttHeld = false
        bridgeStatus = wasEnabled ? "Output off · \(reason)" : "Preview · keyboard output off"
        if wasEnabled { onEvent?("Keyboard output disabled · \(reason)") }
    }

    func process(_ frame: ControlFrame, configuration: BridgeConfiguration) {
        guard isArmed else { return }
        guard frame.time >= armedAt else { return }
        checkFocus()
        guard isArmed else { return }
        guard AXIsProcessTrusted(), ProcessInfo.processInfo.systemUptime - frame.time < 0.25 else {
            disable(reason: "Permission missing or stale audio"); return
        }
        lastFrameAt = frame.time
        for value in held.values {
            if !value.lease.renew(duration: 0.6) { disable(reason: "Key safety timeout"); return }
        }
        if waitingForQuiet {
            if !frame.pttActive && frame.tone.candidate == nil && frame.tone.heldControl == nil {
                waitingForQuiet = false
                bridgeStatus = "Keyboard output → \(target?.localizedName ?? "target app")"
            }
            return
        }
        if frame.pttTransition == true { activate(configuration.handleAction, id: 0) }
        if !frame.pttActive { release(id: 0, reason: "PTT ended") }
        for id in Array(held.keys) where id > 0 && frame.tone.heldControl != id - 1 {
            release(id: id, reason: "Tone ended")
        }
        if let slot = frame.tone.detected { activate(configuration.action(for: slot), id: slot + 1) }
    }

    private func activate(_ action: BridgeAction, id: Int) {
        guard action.kind != .none, let target, !target.isTerminated else { return }
        guard !textRunner.isBusy else { onEvent?("Control \(id) skipped · text action still running"); return }
        if action.kind == .typeText {
            guard held.isEmpty else { onEvent?("Control \(id) skipped · release held keys before typing text"); return }
            let pid = target.processIdentifier
            let started = textRunner.start(action, sink: QuartzTextSink(pid: pid), isAllowed: { [weak self] in
                guard let self else { return false }
                return self.isArmed && self.target?.processIdentifier == pid && self.target?.isTerminated == false &&
                    NSWorkspace.shared.frontmostApplication?.processIdentifier == pid && AXIsProcessTrusted() &&
                    ProcessInfo.processInfo.systemUptime - self.lastFrameAt < 0.25
            }, finished: { [weak self] success in
                self?.onEvent?("Control \(id) text action \(success ? "posted" : "stopped before completion")")
                if !success { self?.disable(reason: "Text action interrupted") }
            })
            if started { onEvent?("Control \(id) typing \(action.text.utf16.count) units\(action.pressEnter ? " · Enter scheduled" : "")") }
            else { onEvent?("Control \(id) text action could not start") }
            return
        }
        // Never press an already-held key again, including a macro mapped to the PTT key.
        guard !held.values.contains(where: { $0.chord.keyCode == action.chord.keyCode }) else {
            onEvent?("Control \(id) skipped · key already held"); return
        }
        let sink = QuartzChordSink(pid: target.processIdentifier, chord: action.chord,
                                   systemShortcut: action.kind == .shortcut && action.delivery == .systemShortcut)
        if action.kind == .holdKey {
            let lease = HeldKeyLease(), token = UUID()
            guard lease.hold(sink, duration: 0.6, onRelease: { [weak self] in
                DispatchQueue.main.async {
                    guard let self, self.held[id]?.token == token else { return }
                    self.disable(reason: "Key safety timeout")
                }
            }) else { disable(reason: "Could not prepare keyboard events"); return }
            held[id] = (lease, action.chord, token)
            if id == 0 { pttHeld = true }
            onEvent?("\(id == 0 ? "PTT" : "Control \(id)") DOWN posted · \(action.chord.label)")
        } else {
            guard sink.prepare() else { disable(reason: "Could not prepare keyboard events"); return }
            sink.keyDown(); sink.keyUp()
            onEvent?("Control \(id) keystroke posted · \(action.chord.label) · \(action.delivery == .systemShortcut ? "macOS shortcut" : "target app")")
        }
    }

    private func release(id: Int, reason: String) {
        guard let value = held.removeValue(forKey: id) else { return }
        value.lease.release()
        if id == 0 { pttHeld = false }
        onEvent?("\(id == 0 ? "PTT" : "Control \(id)") UP posted · \(value.chord.label) · \(reason)")
    }

    func testSpace(destination: TestDestination) {
        guard !isBusy, AXIsProcessTrusted() else { return }
        disable(reason: "Manual keyboard test")
        isBusy = true
        let token = UUID()
        generation = token
        task = Task { [weak self] in
            guard let self else { return }
            if destination == .frontmost {
                for seconds in (1...3).reversed() {
                    status = "Switch to target app · \(seconds)…"
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled, generation == token else { return }
                }
            }
            guard AXIsProcessTrusted() else { cancel(reason: "Accessibility permission unavailable"); return }
            let target = destination == .monitor ? NSRunningApplication.current : NSWorkspace.shared.frontmostApplication
            guard let target, !target.isTerminated,
                  destination == .monitor || target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                cancel(reason: "No target app selected; test cancelled")
                return
            }
            let name = target.localizedName ?? "target app"
            let sink = QuartzSpaceSink(pid: target.processIdentifier)
            guard lease.hold(sink, duration: 1, onRelease: { [weak self] in
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.isHeld = false
                    self.isBusy = false
                    self.status = "Space released"
                    self.onEvent?("TEST Space UP posted → \(name)")
                }
            }) else { cancel(reason: "Could not create the keyboard events"); return }
            isHeld = true
            status = "Space held · 1 second"
            onEvent?("TEST Space DOWN posted → \(name)")
        }
    }

    func cancel(reason: String) {
        let wasBusy = isBusy
        let wasHeld = isHeld
        generation = UUID()
        task?.cancel()
        task = nil
        lease.release() // Synchronous and idempotent; even if permissions were just revoked.
        isHeld = false
        isBusy = false
        if wasBusy {
            status = "Test stopped"
            onEvent?(wasHeld ? "TEST Space UP posted · \(reason)" : "Test cancelled · \(reason)")
        }
    }
}

/// Ordinary keys go to the captured process; explicitly configured system shortcuts
/// enter the HID event stream. Both events exist before any down is posted.
private final class QuartzChordSink: KeyEventSink {
    private let pid: pid_t
    private let chord: KeyChord
    private let systemShortcut: Bool
    private var down: CGEvent?
    private var up: CGEvent?
    init(pid: pid_t, chord: KeyChord, systemShortcut: Bool = false) {
        self.pid = pid; self.chord = chord; self.systemShortcut = systemShortcut
    }
    func prepare() -> Bool {
        guard chord.keyCode <= 127 else { return false }
        let source = CGEventSource(stateID: .privateState)
        down = CGEvent(keyboardEventSource: source, virtualKey: chord.keyCode, keyDown: true)
        up = CGEvent(keyboardEventSource: source, virtualKey: chord.keyCode, keyDown: false)
        var flags: CGEventFlags = []
        if chord.modifiers & 1 != 0 { flags.insert(.maskControl) }
        if chord.modifiers & 2 != 0 { flags.insert(.maskAlternate) }
        if chord.modifiers & 4 != 0 { flags.insert(.maskShift) }
        if chord.modifiers & 8 != 0 { flags.insert(.maskCommand) }
        for event in [down, up].compactMap({ $0 }) {
            event.flags = flags
            event.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
            event.setIntegerValueField(.eventSourceUserData, value: 0x4658425247)
        }
        return down != nil && up != nil
    }
    func keyDown() { if systemShortcut { down?.post(tap: .cghidEventTap) } else { down?.postToPid(pid) } }
    func keyUp() { if systemShortcut { up?.post(tap: .cghidEventTap) } else { up?.postToPid(pid) } }
}

private final class QuartzSpaceSink: KeyEventSink {
    private let pid: pid_t
    private var down: CGEvent?
    private var up: CGEvent?

    init(pid: pid_t) { self.pid = pid }

    func prepare() -> Bool {
        let source = CGEventSource(stateID: .privateState)
        down = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: true)
        up = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: false)
        for event in [down, up].compactMap({ $0 }) {
            event.flags = []
            event.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
            event.setIntegerValueField(.eventSourceUserData, value: ActionDispatcher.testMarker)
        }
        return down != nil && up != nil
    }

    func keyDown() { down?.postToPid(pid) }
    func keyUp() { up?.postToPid(pid) }
}
