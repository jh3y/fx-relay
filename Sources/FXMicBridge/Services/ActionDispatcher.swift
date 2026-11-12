import AppKit
import ApplicationServices
import FXMicCore
import Observation

enum TestDestination: String, CaseIterable, Identifiable {
    case monitor = "This app"
    case frontmost = "Target app in 3 seconds"
    var id: String { rawValue }
}

struct KeyboardTarget: Equatable {
    let processIdentifier: pid_t
    let localizedName: String?
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
    private(set) var bridgeStatus = "Connecting microphone…"
    private(set) var pttHeld = false
    private var target: KeyboardTarget?
    private var gate = ForegroundOutputGate()
    private var unavailableReason: String? = "Connecting microphone…"
    private var held: [Int: (lease: HeldKeyLease, chord: KeyChord, token: UUID)] = [:]
    private let textRunner = TextActionRunner()
    private var lastFrameAt = -Double.infinity
    private let frontmost: @MainActor () -> KeyboardTarget?
    private let hasAccessibility: () -> Bool
    private let utilityFocused: @MainActor () -> Bool
    private let now: () -> Double
    private let makeKeySink: (pid_t, KeyChord, Bool) -> KeyEventSink
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    init(frontmost: @escaping @MainActor () -> KeyboardTarget? = {
             guard let app = NSWorkspace.shared.frontmostApplication, !app.isTerminated else { return nil }
             return KeyboardTarget(processIdentifier: app.processIdentifier, localizedName: app.localizedName)
         },
         hasAccessibility: @escaping () -> Bool = { AXIsProcessTrusted() },
         utilityFocused: @escaping @MainActor () -> Bool = { NSApp.isActive },
         now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime },
         makeKeySink: @escaping (pid_t, KeyChord, Bool) -> KeyEventSink = {
             QuartzChordSink(pid: $0, chord: $1, systemShortcut: $2)
         }) {
        self.frontmost = frontmost; self.hasAccessibility = hasAccessibility
        self.utilityFocused = utilityFocused; self.now = now; self.makeKeySink = makeKeySink
    }

    /// Availability belongs to the app lifecycle, not a user-operated arm switch.
    func setAvailability(blockedBy reason: String?, checkFocusImmediately: Bool = true) {
        unavailableReason = reason
        if checkFocusImmediately { checkFocus() }
    }

    func checkFocus() {
        var reason = unavailableReason
        if reason == nil && !hasAccessibility() { reason = "Accessibility permission needed" }
        if reason == nil && isBusy { reason = "Manual keyboard test running" }
        let focused = frontmost()
        if reason == nil && (utilityFocused() || focused?.processIdentifier == ownPID) {
            reason = "Ready · switch to your app"
        }
        let next = reason == nil ? focused : nil
        if gate.update(targetPID: next?.processIdentifier, at: now()) {
            textRunner.cancel()
            for id in Array(held.keys) { release(id: id, reason: "Focused app changed or output suspended") }
            target = next
            if let next { onEvent?("Output ready → \(next.localizedName ?? "focused app"); waiting for quiet") }
        }
        if isArmed != (next != nil) { isArmed = next != nil }
        let nextStatus = reason ?? (next == nil ? "Ready · switch to your app" :
            "\(gate.waitingForQuiet ? "Waiting for quiet" : "Ready") · \(next?.localizedName ?? "focused app")")
        if bridgeStatus != nextStatus { bridgeStatus = nextStatus }
    }

    /// Interrupt the current gesture. Fresh frames may resume automatically once
    /// availability and focus permit; an interrupted gesture is never replayed.
    func disable(reason: String) {
        let wasEnabled = isArmed
        textRunner.cancel()
        for id in Array(held.keys) { release(id: id, reason: reason) }
        gate.reset()
        isArmed = false; target = nil; pttHeld = false
        bridgeStatus = reason
        if wasEnabled { onEvent?("Output suspended · \(reason)") }
    }

    func process(_ frame: ControlFrame, configuration: BridgeConfiguration, handle: BankHandleRouter.Decision) {
        if handle.release { release(id: 0, reason: handle.bankChanged ? "Handle bank changed" : "Handle signal ended or mapping changed") }
        if handle.bankChanged {
            textRunner.cancel()
            for id in Array(held.keys) { release(id: id, reason: "Bank changed") }
        }
        // One fresh focus/permission check per frame, including while disarmed.
        // Lifecycle notifications still check immediately; no cached permission or target is used.
        checkFocus()
        guard isArmed else { return }
        guard now() - frame.time < 0.25 else {
            disable(reason: "Stale audio"); return
        }
        let quiet = !frame.pttActive && frame.rmsDB < configuration.releaseDB &&
            frame.tone.candidate == nil && frame.tone.heldControl == nil && frame.tone.detected == nil
        guard gate.accepts(frameTime: frame.time, now: now(), quiet: quiet) else { return }
        lastFrameAt = frame.time
        // End a sample hold before renewing/repeating it on this frame.
        for id in Array(held.keys) where id > 0 && frame.tone.heldControl != id - 1 {
            release(id: id, reason: "Tone ended")
        }
        for value in held.values {
            if !value.lease.renew(duration: 0.6) { disable(reason: "Key safety timeout"); return }
            value.lease.repeatIfDue()
        }
        if let action = handle.activation { activate(action, id: 0) }
        if !frame.pttActive { release(id: 0, reason: "PTT ended") }
        if let slot = frame.tone.detected { activate(configuration.action(for: slot), id: slot + 1) }
    }

    private func activate(_ action: BridgeAction, id: Int) {
        guard action.kind != .none, let target, frontmost()?.processIdentifier == target.processIdentifier else { return }
        guard !textRunner.isBusy else { onEvent?("Control \(id) skipped · text action still running"); return }
        // A global modifier can alter another macro or be cleared by its flags.
        // Serialize modifier gestures with all other bridge key actions.
        guard !held.values.contains(where: { $0.chord.modifierKey != nil }),
              action.chord.modifierKey == nil || held.isEmpty else {
            onEvent?("Control \(id) skipped · modifier holds cannot overlap other key actions"); return
        }
        if action.kind == .typeText {
            guard held.isEmpty else { onEvent?("Control \(id) skipped · release held keys before typing text"); return }
            let pid = target.processIdentifier
            let started = textRunner.start(action, sink: QuartzTextSink(pid: pid), isAllowed: { [weak self] in
                guard let self else { return false }
                return self.isArmed && !self.utilityFocused() && self.target?.processIdentifier == pid &&
                    self.frontmost()?.processIdentifier == pid && self.hasAccessibility() &&
                    self.now() - self.lastFrameAt < 0.25
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
        let sink = makeKeySink(target.processIdentifier, action.chord,
                               action.usesSystemDelivery)
        if action.isHold {
            let lease = HeldKeyLease(), token = UUID()
            guard lease.hold(sink, duration: 0.6, continuous: action.kind == .holdKeyContinuous, onRelease: { [weak self] in
                DispatchQueue.main.async {
                    guard let self, self.held[id]?.token == token else { return }
                    self.disable(reason: "Key safety timeout")
                }
            }) else { disable(reason: "Could not prepare keyboard events"); return }
            held[id] = (lease, action.chord, token)
            if id == 0 { pttHeld = true }
            onEvent?("\(id == 0 ? "PTT" : "Control \(id)") DOWN posted · \(action.chord.label)\(action.kind == .holdKeyContinuous ? " · continuous repeat" : "")\(action.usesSystemDelivery ? " · macOS shortcut" : "")")
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
        let repeats = value.lease.repeatsPosted
        onEvent?("\(id == 0 ? "PTT" : "Control \(id)") UP posted · \(value.chord.label)\(repeats > 0 ? " · \(repeats) repeats" : "") · \(reason)")
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
