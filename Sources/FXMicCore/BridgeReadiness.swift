import Foundation

/// Operational readiness is separate from an action being held or the foreground
/// app temporarily suppressing output. A device name alone never means ready.
public enum BridgeReadiness: Equatable, Sendable {
    case microphonePermission, accessibilityPermission, chooseInput, disconnected
    case paused, installing, captureError, connecting, waitingForAudio, diagnostic, unsavedMappings
    case ready

    public static func evaluate(microphone: Bool, accessibility: Bool, inputSelected: Bool,
                                inputAvailable: Bool, monitoring: Bool, sleeping: Bool,
                                installing: Bool, captureError: Bool, starting: Bool,
                                receivingAudio: Bool, diagnostic: Bool, unsavedMappings: Bool) -> Self {
        if !microphone { return .microphonePermission }
        if !accessibility { return .accessibilityPermission }
        if !inputSelected { return .chooseInput }
        if !inputAvailable { return .disconnected }
        if installing { return .installing }
        if !monitoring || sleeping { return .paused }
        if captureError { return .captureError }
        if starting { return .connecting }
        if !receivingAudio { return .waitingForAudio }
        if diagnostic { return .diagnostic }
        if unsavedMappings { return .unsavedMappings }
        return .ready
    }

    public var title: String {
        switch self {
        case .microphonePermission: return "Allow microphone access"
        case .accessibilityPermission: return "Allow keyboard control"
        case .chooseInput: return "Choose your audio input"
        case .disconnected: return "Input disconnected"
        case .paused: return "Paused"
        case .installing: return "Setting up your mic"
        case .captureError: return "Input needs attention"
        case .connecting: return "Connecting…"
        case .waitingForAudio: return "Waiting for audio capture"
        case .diagnostic: return "Diagnostic check running"
        case .unsavedMappings: return "Apply your changes"
        case .ready: return "Ready"
        }
    }
    public var detail: String {
        switch self {
        case .microphonePermission: return "Microphone permission lets FX Relay measure the selected input."
        case .accessibilityPermission: return "Accessibility permission lets FX Relay send your mapped keys."
        case .chooseInput: return "Select the adapter connected to the FX-MIC."
        case .disconnected: return "Reconnect your selected adapter, or choose another input."
        case .paused: return "Resume when you want the mic to control your apps."
        case .installing: return "Capture is paused while the cue pack is being installed."
        case .captureError: return "Check the input connection in Signal Monitor."
        case .connecting, .waitingForAudio: return "Waiting for the first audio measurements from this input."
        case .diagnostic: return "Measuring controls without sending keys."
        case .unsavedMappings: return "Apply or revert your mapping edits to resume output."
        case .ready: return "Switch to your app. Your mappings work automatically."
        }
    }
}
