import AppKit
import AVFoundation
import ApplicationServices
import Observation

@MainActor @Observable
final class PermissionManager {
    private(set) var microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    private(set) var accessibility = AXIsProcessTrusted()

    func refresh() {
        microphone = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibility = AXIsProcessTrusted()
    }

    func requestMicrophone(completion: @escaping () -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
            DispatchQueue.main.async { self?.refresh(); completion() }
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibility = AXIsProcessTrustedWithOptions(options)
        openSettings("Accessibility")
    }

    func openSettings(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}

#if FXRELAY_PREVIEW
extension PermissionManager {
    func prepareVisualPreview(microphone: Bool, accessibility: Bool) {
        self.microphone = microphone ? .authorized : .denied
        self.accessibility = accessibility
    }
}
#endif
