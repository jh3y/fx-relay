import Foundation
import CoreGraphics

/// Ordinary keys go to the captured process; explicitly configured system shortcuts
/// enter the HID event stream. Both events exist before any down is posted.
public final class QuartzChordSink: RepeatingKeyEventSink {
    private let chord: KeyChord
    private var down: CGEvent?
    private var up: CGEvent?
    private var repeatDown: CGEvent?
    private let systemShortcut: Bool
    private let post: (CGEvent) -> Void
    private let currentFlags: () -> CGEventFlags
    public init(pid: pid_t, chord: KeyChord, systemShortcut: Bool = false,
                currentFlags: @escaping () -> CGEventFlags = { CGEventSource.flagsState(.hidSystemState) },
                post: ((CGEvent) -> Void)? = nil) {
        self.chord = chord
        self.systemShortcut = systemShortcut
        self.currentFlags = currentFlags
        self.post = post ?? { event in
            if systemShortcut { event.post(tap: .cghidEventTap) } else { event.postToPid(pid) }
        }
    }
    public func prepare() -> Bool {
        down = nil; up = nil; repeatDown = nil
        guard chord.keyCode <= 127 else { return false }
        if let modifier = chord.modifierKey {
            // Do not take ownership of a modifier already active before our press.
            guard chord.modifiers == 0, !currentFlags().contains(modifier.flag) else { return false }
        }
        let source = CGEventSource(stateID: .privateState)
        down = CGEvent(keyboardEventSource: source, virtualKey: chord.keyCode, keyDown: true)
        up = CGEvent(keyboardEventSource: source, virtualKey: chord.keyCode, keyDown: false)
        repeatDown = CGEvent(keyboardEventSource: source, virtualKey: chord.keyCode, keyDown: true)
        var flags: CGEventFlags = []
        if chord.modifiers & 1 != 0 { flags.insert(.maskControl) }
        if chord.modifiers & 2 != 0 { flags.insert(.maskAlternate) }
        if chord.modifiers & 4 != 0 { flags.insert(.maskShift) }
        if chord.modifiers & 8 != 0 { flags.insert(.maskCommand) }
        for event in [down, up, repeatDown].compactMap({ $0 }) {
            event.flags = flags
            event.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
            event.setIntegerValueField(.eventSourceUserData, value: 0x4658425247)
        }
        // Process-targeted autorepeat-marked events can reach an AppKit receiver
        // without becoming terminal input. The real iTerm PTY check received only
        // the initial Space with that combination. Ordinary targeted keyDowns
        // delivered every repeat, so terminal clients can detect their cadence.
        // The system event stream retains native autorepeat semantics.
        repeatDown?.setIntegerValueField(.keyboardEventAutorepeat, value: systemShortcut ? 1 : 0)
        if let modifier = chord.modifierKey {
            down?.type = .flagsChanged
            down?.flags = modifier.flags
            up?.type = .flagsChanged
            up?.flags = []
        }
        return down != nil && up != nil && repeatDown != nil
    }
    public func keyDown() {
        if let modifier = chord.modifierKey { down?.flags = currentFlags().union(modifier.flags) }
        send(down)
    }
    public func keyUp() {
        // Posting through HID can put our own modifier in the queried state.
        // Copying it verbatim made a supposed release another modifier-down.
        if let modifier = chord.modifierKey { up?.flags = modifier.releasing(from: currentFlags()) }
        send(up)
    }
    public func keyRepeat() { if chord.modifierKey == nil { send(repeatDown) } }
    private func send(_ event: CGEvent?) {
        guard let event else { return }
        event.timestamp = DispatchTime.now().uptimeNanoseconds
        post(event)
    }
}
