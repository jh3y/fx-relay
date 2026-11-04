import ApplicationServices
import FXMicCore

/// Balanced Unicode events addressed to the already-armed process; clipboard untouched.
@MainActor final class QuartzTextSink: TextActionSink {
    private let pid: pid_t
    init(pid: pid_t) { self.pid = pid }
    func type(_ utf16: [UInt16]) -> Bool {
        guard !utf16.isEmpty, utf16.count <= 20 else { return false }
        return post(key: 0, utf16: utf16)
    }
    func enter() -> Bool { post(key: 36, utf16: []) }
    private func post(key: CGKeyCode, utf16: [UInt16]) -> Bool {
        let source = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) else { return false }
        for event in [down, up] {
            event.flags = []
            event.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
            event.setIntegerValueField(.eventSourceUserData, value: 0x4658425247)
            if !utf16.isEmpty {
                utf16.withUnsafeBufferPointer { units in
                    event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units.baseAddress!)
                }
            }
        }
        down.postToPid(pid); up.postToPid(pid)
        return true
    }
}
