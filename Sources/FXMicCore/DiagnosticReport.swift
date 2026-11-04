import Foundation

public enum DiagnosticCheck: String, CaseIterable, Identifiable, Sendable {
    case fxButton, handle, full

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .fxButton: return "Orange FX button · 12 steps"
        case .handle: return "Handle only · 3 steps"
        case .full: return "Handle and buttons · 11 steps"
        }
    }
    public var steps: [DiagnosticStep] {
        switch self {
        case .fxButton: return DiagnosticStep.fxButtonCheck
        case .handle: return Array(DiagnosticStep.hardwareCheck.prefix(3))
        case .full: return DiagnosticStep.hardwareCheck
        }
    }
}

public struct DiagnosticStep: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    /// Optional so saved v0.1.1 reports still decode without this additive field.
    public let preparation: String?
    public let instruction: String
    public let duration: Double

    public static let fxButtonCheck: [DiagnosticStep] = {
        let preparation = "Release the trigger NOW and leave it released for this entire check. Stay quiet. Wait for MEASURING before touching any button."
        func step(_ id: String, _ title: String, _ instruction: String) -> DiagnosticStep {
            .init(id: id, title: title, preparation: preparation, instruction: instruction, duration: 6)
        }
        return [
            step("fx_baseline", "Quiet baseline", "Keep the trigger released. Hold the mic still, stay quiet and leave all buttons alone. Note which FX lights are lit."),
            step("fx_handling_before", "Handling comparison", "Gently reposition your fingers around the mic once NOW, as if reaching for orange. Do not press any button or squeeze the trigger.")
        ] + (1...6).map { index in
            step("fx_press_\(index)", "Orange press \(index) of 6", "Press and release ONLY the orange FX-mode button once NOW. Keep the trigger released. Do not press sample play or the sample selector. Note which FX lights are lit afterward.")
        } + [
            step("fx_sample_selector", "Sample selector alone", "Press the sample SELECTOR once NOW. Keep the trigger released. Do not press orange or sample play. Note the selected sample light."),
            step("fx_sample_play", "Sample playback comparison", "Press sample PLAY (bottom-right) once NOW. Keep the trigger released. Let the sound finish. Leave orange and the selector alone."),
            step("fx_handling_after", "Repeat handling comparison", "Gently reposition your fingers once NOW without pressing any button or squeezing the trigger. Stay quiet."),
            step("fx_final_quiet", "Final quiet baseline", "Keep the trigger released. Hold the mic still, stay quiet and leave all buttons alone.")
        ]
    }()

    public static let hardwareCheck: [DiagnosticStep] = [
        .init(id: "released", title: "Trigger released",
              preparation: "Let go of the trigger now. Stay quiet. Leave every button alone.",
              instruction: "Keep the trigger released. Stay quiet and leave the buttons alone until this step finishes.", duration: 6),
        .init(id: "held_silent", title: "Trigger held · quiet",
              preparation: "Squeeze and keep holding the trigger NOW, before starting the countdown. Stay quiet and leave every button alone.",
              instruction: "Keep holding the trigger continuously. Stay quiet and leave the buttons alone until this step finishes.", duration: 6),
        .init(id: "held_speaking", title: "Trigger held · speaking",
              preparation: "Squeeze and keep holding the trigger NOW, before starting the countdown. Wait to speak until MEASURING appears.",
              instruction: "Keep holding the trigger. Say: one, two, three, testing the microphone. Pause briefly and repeat until this step finishes.", duration: 8),
        .init(id: "sample_play_released", title: "Sample play · trigger released",
              preparation: "Let go of the trigger now. Find the sample play button (bottom-right), but do not press it yet. Stay quiet.",
              instruction: "Keep the trigger released. Press sample play once NOW, then let the sound finish. Stay quiet.", duration: 8),
        .init(id: "sample_play_held", title: "Sample play · trigger held",
              preparation: "Squeeze and keep holding the trigger NOW. Stay quiet. Find sample play (bottom-right), but do not press it yet.",
              instruction: "Keep holding the trigger. Press sample play once NOW, then let the sound finish. Stay quiet.", duration: 8),
        .init(id: "sample_selector_only", title: "Sample selector alone",
              preparation: "Release the trigger NOW. Stay quiet. Find the sample SELECTOR, but do not press it yet. Skip if unsure which button it is.",
              instruction: "Keep the trigger released. Press the sample selector once NOW. Do not press play or speak. Silence is a useful result.", duration: 6),
        .init(id: "sample_selector_then_play", title: "Sample selector → sample play",
              preparation: "Squeeze and keep holding the trigger NOW. Stay quiet. Find both sample PLAY and sample SELECTOR. Leave them alone during the countdown.",
              instruction: "Keep holding the trigger. Press PLAY now. Let the sound finish, press the sample SELECTOR once, then press PLAY again. Stay quiet.", duration: 12),
        .init(id: "preset_selector_only", title: "Effect preset selector alone",
              preparation: "Release the trigger NOW. Stay quiet. Find the orange effect PRESET selector, but do not press it yet. Skip if unsure.",
              instruction: "Keep the trigger released. Press the effect preset selector once NOW. Do not press play or speak. Note the lit preset LED.", duration: 6),
        .init(id: "preset_then_play", title: "Effect preset → sample play",
              preparation: "Keep the preset you just selected. Squeeze and keep holding the trigger NOW. Stay quiet. Wait to press sample play.",
              instruction: "Keep holding the trigger. Press sample play once NOW, then let the sound finish. Stay quiet.", duration: 8),
        .init(id: "preset_speaking", title: "New preset · speaking",
              preparation: "Keep the same preset. Squeeze and keep holding the trigger NOW. Stay quiet until MEASURING appears.",
              instruction: "Keep holding the trigger. Say: one, two, three, testing the microphone. Pause briefly and repeat until this step finishes.", duration: 8),
        .init(id: "released_again", title: "Trigger released again",
              preparation: "Let go of the trigger now. Stay quiet and let any sample or effect tail finish before starting the countdown.",
              instruction: "Keep the trigger released. Stay quiet and leave every button alone until this step finishes.", duration: 6)
    ]
}

public struct DiagnosticMetadata: Codable, Sendable {
    public let appVersion: String
    public let appBuild: String
    public let osVersion: String
    public let inputName: String
    public let initialThresholdDB: Double
    public let sampleRate: Double
    public let channelCount: Int
    public var notes: String
    public private(set) var rawAudioIncluded = false
    public private(set) var fftSize = SignalAnalyzer.fftSize
    public private(set) var measurementRateLimitHz = 15
    public private(set) var spectrumRateLimitHz = 10
    public private(set) var referenceRepository = "https://github.com/tajchert/tink-agent"

    public init(appVersion: String, appBuild: String, osVersion: String, inputName: String,
                initialThresholdDB: Double, sampleRate: Double, channelCount: Int, notes: String) {
        self.appVersion = appVersion; self.appBuild = appBuild; self.osVersion = osVersion
        self.inputName = inputName; self.initialThresholdDB = initialThresholdDB
        self.sampleRate = sampleRate; self.channelCount = channelCount; self.notes = notes
    }
}

public struct DiagnosticEvent: Codable, Sendable {
    public let elapsedSeconds: Double
    public let message: String
}

public struct DiagnosticStepResult: Codable, Sendable {
    public let stepID: String
    public let outcome: String
    public let measurementStartedAt: Double?
    public let endedAt: Double
}

public struct DiagnosticMeasurement: Codable, Sendable {
    public let elapsedSeconds: Double
    public let stepID: String
    public let phase: String
    public let rmsDB: Double
    public let peakDB: Double
    public let channelRMSDB: [Double]
    public let channelPeakDB: [Double]
    public let thresholdDB: Double
    public let signalPresent: Bool
    public let dominantFrequencyHz: Double?
    public let peakConcentration: Double
    public let sampleRate: Double
    public let analyzedChannel: Int
    public let spectrumAgeSeconds: Double?
    public let spectralPeaks: [SpectralPeak]
    /// 64 logarithmic bands from 20 Hz to min(20 kHz, Nyquist); maximum FFT-bin dB in each band.
    public let spectrumBandsDB: [Float]

    init(snapshot: SignalSnapshot, elapsed: Double, stepID: String, phase: String, threshold: Double) {
        elapsedSeconds = elapsed; self.stepID = stepID; self.phase = phase
        rmsDB = snapshot.rmsDB; peakDB = snapshot.peakDB
        channelRMSDB = snapshot.channelRMSDB; channelPeakDB = snapshot.channelPeakDB
        thresholdDB = threshold; signalPresent = snapshot.rmsDB >= threshold
        dominantFrequencyHz = snapshot.dominantFrequency; peakConcentration = snapshot.peakConcentration
        sampleRate = snapshot.sampleRate; analyzedChannel = snapshot.analyzedChannel
        spectrumAgeSeconds = snapshot.spectrumAgeSeconds
        spectralPeaks = snapshot.compactSpectrum.peaks
        spectrumBandsDB = snapshot.compactSpectrum.bandsDB
    }
}

public struct DiagnosticReport: Codable, Sendable {
    public var schemaVersion = 1
    public let id: UUID
    public let startedAt: Date
    public var metadata: DiagnosticMetadata
    public let protocolSteps: [DiagnosticStep]
    public var events: [DiagnosticEvent] = []
    public var measurements: [DiagnosticMeasurement] = []
    public var stepResults: [DiagnosticStepResult] = []
    public var durationSeconds: Double = 0
    public var endReason: String?
    /// Additive optional fields preserve decoding of older diagnostic reports.
    public var hardwareProbe: HardwareProbeReport?
    public var stepObservations: [String: String]?

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
