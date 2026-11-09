import AppKit
import ApplicationServices
import FXMicCore

/// Explicit developer check of the real HID -> AppKit path. Uses Shift so Hex's
/// Option shortcut is not activated. No audio and no ordinary keys are captured.
@MainActor enum ModifierReleaseCheck {
    private static var task: Task<Void, Never>?
    private static var lease: HeldKeyLease?
    private static var window: NSWindow?
    private static var monitor: Any?
    nonisolated private static let marker: Int64 = 0x4658525000

    private final class Records: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [[String: Any]] = []
        func append(_ entry: [String: Any]) { lock.lock(); entries.append(entry); lock.unlock() }
        func snapshot() -> [[String: Any]] { lock.lock(); defer { lock.unlock() }; return entries }
    }

    static func runIfRequested() -> Bool {
        guard let i = CommandLine.arguments.firstIndex(of: "--modifier-release-check"),
              CommandLine.arguments.indices.contains(i + 1) else { return false }
        let destination = URL(fileURLWithPath: CommandLine.arguments[i + 1])
        task = Task {
            var result: [String: Any] = ["appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
                                         "key": "Left Shift", "audioCaptured": false]
            let posted = Records(), received = Records(), tapped = Records()
            var tap: CFMachPort?
            var tapSource: CFRunLoopSource?
            do {
                guard AXIsProcessTrusted() else { throw Failure("Accessibility permission required; no keys sent") }
                let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
                tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                    eventsOfInterest: eventMask, callback: { _, type, event, context in
                        let tag = event.getIntegerValueField(.eventSourceUserData)
                        if let context, ((ModifierReleaseCheck.marker ... ModifierReleaseCheck.marker + 110).contains(tag) || tag == 0x4658425247),
                           event.getIntegerValueField(.keyboardEventKeycode) == Int64(ModifierKey.shift.rawValue) {
                            let records = Unmanaged<Records>.fromOpaque(context).takeUnretainedValue()
                            records.append(["marker": tag, "type": type.rawValue, "flags": event.flags.rawValue,
                                            "shiftDown": event.flags.contains(.maskShift)])
                        }
                        return Unmanaged.passUnretained(event)
                    }, userInfo: Unmanaged.passUnretained(tapped).toOpaque())
                guard let tap else { throw Failure("Could not observe native delivery; no keys sent") }
                tapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes)
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 150),
                                      styleMask: [.titled], backing: .buffered, defer: false)
                self.window = window
                window.isReleasedWhenClosed = false
                window.title = "FX Relay — Modifier release check"
                let label = NSTextField(wrappingLabelWithString: "Checking modifier release…\nNo audio is captured. This window closes automatically.")
                label.frame = NSRect(x: 24, y: 35, width: 370, height: 80)
                window.contentView?.addSubview(label)
                window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
                monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                    if let cg = event.cgEvent {
                        let tag = cg.getIntegerValueField(.eventSourceUserData)
                        if ((marker ... marker + 110).contains(tag) || tag == 0x4658425247), event.keyCode == ModifierKey.shift.rawValue {
                            received.append(["marker": tag, "flags": cg.flags.rawValue, "shiftDown": cg.flags.contains(.maskShift)])
                        }
                    }
                    return event
                }
                // LaunchServices may finish activating after didFinishLaunching.
                for _ in 0..<10 {
                    if NSApp.isActive && window.isKeyWindow { break }
                    try await Task.sleep(for: .milliseconds(100))
                }
                var phases: [[String: Any]] = []
                var passed = true
                for (index, name) in ["legacy-copy", "fixed-release", "fixed-expiry", "fixed-next-hold"].enumerated() {
                    guard NSApp.isActive, window.isKeyWindow, AXIsProcessTrusted() else {
                        throw Failure("Diagnostic window lost focus or permission; stopped")
                    }
                    let initial = CGEventSource.flagsState(.hidSystemState)
                    guard initial.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand]).isEmpty else {
                        throw Failure("A modifier was already active; no new hold started")
                    }
                    let tag = marker + Int64(index)
                    let receivedStart = received.snapshot().count
                    let tappedStart = tapped.snapshot().count
                    // Prepare emergency cleanup before reproducing the old release.
                    guard let cleanup = CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState),
                                                virtualKey: ModifierKey.shift.rawValue, keyDown: false) else {
                        throw Failure("Could not prepare cleanup")
                    }
                    cleanup.type = .flagsChanged
                    cleanup.setIntegerValueField(.eventSourceUserData, value: tag + 100)
                    let sink = QuartzChordSink(pid: getpid(), chord: ModifierKey.shift.chord, systemShortcut: true, post: { original in
                        let event = original
                        let release = !event.flags.contains(.maskShift)
                        let state = CGEventSource.flagsState(.hidSystemState)
                        if index == 0 && release { event.flags = state } // v0.7.1 behavior
                        // Keep the sink's original marker. Reassigning it on an
                        // existing event did not change the marker received by macOS.
                        posted.append(["phase": name, "type": event.type.rawValue, "releaseRequested": release, "flags": event.flags.rawValue,
                                       "queriedHIDFlags": state.rawValue, "shiftDown": event.flags.contains(.maskShift)])
                        event.post(tap: .cghidEventTap)
                        if index == 0 && release {
                            cleanup.flags = ModifierKey.shift.releasing(from: state)
                            cleanup.timestamp = DispatchTime.now().uptimeNanoseconds
                            cleanup.post(tap: .cghidEventTap)
                        }
                    })
                    let current = HeldKeyLease(); lease = current
                    guard current.hold(sink, duration: index == 2 ? 0.15 : 0.6, onRelease: {}) else {
                        throw Failure("Could not acquire diagnostic modifier")
                    }
                    try await Task.sleep(for: .milliseconds(250))
                    let beforeRelease = CGEventSource.flagsState(.hidSystemState)
                    current.release()
                    try await Task.sleep(for: .milliseconds(100))
                    let final = CGEventSource.flagsState(.combinedSessionState)
                    let arrivals = Array(received.snapshot().dropFirst(receivedStart))
                    let tapArrivals = Array(tapped.snapshot().dropFirst(tappedStart))
                    phases.append(["name": name, "hidBeforeRelease": beforeRelease.rawValue,
                                   "sessionAfterRelease": final.rawValue, "received": arrivals, "tapped": tapArrivals])
                    result["phases"] = phases
                    if index > 0 {
                        passed = passed && [arrivals, tapArrivals].allSatisfy {
                            $0.count == 2 && $0.first?["shiftDown"] as? Bool == true && $0.last?["shiftDown"] as? Bool == false
                        } && !final.contains(.maskShift)
                    }
                }
                result["phases"] = phases
                result["legacyRetainedModifier"] = posted.snapshot().contains {
                    $0["phase"] as? String == "legacy-copy" && $0["releaseRequested"] as? Bool == true && $0["shiftDown"] as? Bool == true
                }
                result["status"] = passed ? "passed" : "native-delivery-failed"
            } catch { result["status"] = "stopped"; result["error"] = error.localizedDescription }
            lease?.release(); lease = nil
            result["posted"] = posted.snapshot(); result["received"] = received.snapshot(); result["tapped"] = tapped.snapshot()
            if let tap { CFMachPortInvalidate(tap) }
            if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: destination, options: .atomic)
            window?.close(); window = nil
            NSApp.terminate(nil)
        }
        return true
    }

    static func cancel() { task?.cancel(); lease?.release(); lease = nil }
    private struct Failure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
