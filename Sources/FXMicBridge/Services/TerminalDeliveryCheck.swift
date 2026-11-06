import AppKit
import ApplicationServices
import FXMicCore

/// Explicit developer diagnostic. No audio capture; only Space is emitted, and
/// only while the uniquely named test window is focused. Never selects a user tab.
@MainActor enum TerminalDeliveryCheck {
    private static var task: Task<Void, Never>?
    private static var lease: HeldKeyLease?

    static func runIfRequested() -> Bool {
        guard let index = CommandLine.arguments.firstIndex(of: "--terminal-delivery-check"),
              CommandLine.arguments.indices.contains(index + 1) else { return false }
        let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        task = Task {
            var result: [String: Any] = ["appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"]
            do {
                let request = try JSONDecoder().decode(Request.self, from: Data(contentsOf: directory.appendingPathComponent("request.json")))
                guard UUID(uuidString: request.token) != nil, AXIsProcessTrusted() else {
                    throw Failure("FX Relay needs Accessibility permission for the terminal check")
                }
                let marker = "FX Relay Terminal Check " + request.token
                guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2") else {
                    throw Failure("iTerm2 is not installed")
                }
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                try await NSWorkspace.shared.open([directory.appendingPathComponent("Receiver.command")],
                    withApplicationAt: terminal, configuration: configuration)
                var target: pid_t?
                let deadline = ProcessInfo.processInfo.systemUptime + 20
                while ProcessInfo.processInfo.systemUptime < deadline {
                    try await Task.sleep(for: .milliseconds(100))
                    if FileManager.default.fileExists(atPath: directory.appendingPathComponent("ready.json").path),
                       let pid = focusedTestWindow(marker: marker) { target = pid; break }
                }
                guard let target else { throw Failure("The isolated receiver window did not become ready and focused; no keys sent") }
                var phases: [[String: Any]] = []
                for mode in ["legacy-marked-pid", "direct-pid"] {
                    guard focusedTestWindow(marker: marker) == target else { throw Failure("Test window lost focus; stopped") }
                    try write(["phase": mode], to: directory.appendingPathComponent("phase.json"))
                    try await Task.sleep(for: .milliseconds(150))
                    var downs = 0
                    let sink = QuartzChordSink(pid: target, chord: .space,
                        post: mode == "legacy-marked-pid" ? { event in
                            if event.type == .keyDown {
                                event.setIntegerValueField(.keyboardEventAutorepeat, value: downs == 0 ? 0 : 1)
                                downs += 1
                            }
                            event.postToPid(target)
                        } : nil)
                    let current = HeldKeyLease()
                    lease = current
                    guard focusedTestWindow(marker: marker) == target,
                          current.hold(sink, duration: 0.6, continuous: true, onRelease: {}) else {
                        throw Failure("Could not start isolated Space hold")
                    }
                    do {
                        for _ in 0..<40 {
                            try await Task.sleep(for: .milliseconds(40))
                            guard AXIsProcessTrusted(), focusedTestWindow(marker: marker) == target,
                                  current.renew(duration: 0.6) else { throw Failure("Focus, permission or key lease changed; stopped") }
                            current.repeatIfDue()
                        }
                    } catch { current.release(); throw error }
                    current.release()
                    phases.append(["mode": mode, "downsPosted": 1, "repeatsPosted": current.repeatsPosted, "upsPosted": 1])
                    try await Task.sleep(for: .milliseconds(250))
                }
                result["phases"] = phases
                result["status"] = "completed"
            } catch { result["status"] = "stopped"; result["error"] = error.localizedDescription }
            lease?.release(); lease = nil
            try? write(result, to: directory.appendingPathComponent("sender.json"))
            try? write(["done": true], to: directory.appendingPathComponent("done.json"))
            NSApp.terminate(nil)
        }
        return true
    }

    static func cancel() { task?.cancel(); lease?.release(); lease = nil }

    private static func focusedTestWindow(marker: String) -> pid_t? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier == "com.googlecode.iterm2", !app.isTerminated else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.15)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window, CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(unsafeBitCast(window, to: AXUIElement.self), kAXTitleAttribute as CFString, &title) == .success,
              let title = title as? String, title.contains(marker) else { return nil }
        return app.processIdentifier
    }

    private static func write(_ value: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
    }
    private struct Request: Decodable { let token: String }
    private struct Failure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
