import AVFoundation
import FXMicCore

/// Session configuration never runs on the main thread. Only this selected input is attached;
/// there is no playback output, device-format write, default-device write, or audio file.
final class AudioCaptureEngine {
    private let queue = DispatchQueue(label: "com.jhey.fxmicbridge.capture", qos: .userInitiated)
    private var session: AVCaptureSession?
    private var processor: AudioSampleProcessor?
    private var observers: [NSObjectProtocol] = []
    private var timeout: DispatchSourceTimer?
    private var generation = UUID()
    private var detailedSpectrum = false

    func start(deviceUID: String, threshold: Double, configuration: BridgeConfiguration,
               onControl: @escaping (ControlFrame) -> Void,
               onProbe: @escaping (UUID, [ProbeWindow]) -> Void,
               onFrame: @escaping (SignalSnapshot) -> Void,
               onSignal: @escaping (Bool) -> Void,
               onError: @escaping (String) -> Void) {
        queue.async { [self] in
            stopSession()
            let token = generation
            do {
                guard let device = AVCaptureDevice(uniqueID: deviceUID), device.hasMediaType(.audio) else {
                    throw CaptureError.message("The selected input is unavailable to AVFoundation. Reconnect it or select another input.")
                }
                let input = try AVCaptureDeviceInput(device: device)
                let session = AVCaptureSession()
                let output = AVCaptureAudioDataOutput()
                output.audioSettings = [AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMIsFloatKey: true, AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false]
                guard session.canAddInput(input), session.canAddOutput(output) else {
                    throw CaptureError.message("This device cannot provide an audio capture stream.")
                }
                session.beginConfiguration()
                session.addInput(input)
                session.addOutput(output)
                session.commitConfiguration()
                let processor = AudioSampleProcessor(threshold: threshold, configuration: configuration,
                    detailedSpectrum: detailedSpectrum,
                    onControl: onControl, onProbe: onProbe, onFrame: onFrame, onSignal: onSignal,
                    onError: { [weak self] message in self?.fail(message, token: token, onError: onError) })
                output.setSampleBufferDelegate(processor, queue: processor.queue)
                self.session = session
                self.processor = processor
                for name in [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.wasInterruptedNotification] {
                    observers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { [weak self] notification in
                        let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error
                        self?.fail(error?.localizedDescription ?? "Audio capture was interrupted. Resume monitoring to retry.", token: token, onError: onError)
                    })
                }
                session.startRunning()
                guard session.isRunning else { throw CaptureError.message("Audio capture could not start.") }
                let timer = DispatchSource.makeTimerSource(queue: queue)
                timer.schedule(deadline: .now() + 4, repeating: 1, leeway: .milliseconds(100))
                timer.setEventHandler { [weak self, weak processor] in
                    guard let self, let processor, self.generation == token else { return }
                    if processor.secondsSinceLastBuffer > 3 {
                        self.stopSession()
                        onError("No audio buffers received for 3 seconds. Check the device and microphone permission, then resume monitoring.")
                    }
                }
                timeout = timer
                timer.resume()
            } catch {
                stopSession()
                onError(error.localizedDescription)
            }
        }
    }

    func setThreshold(_ value: Double) {
        queue.async { [weak self] in self?.processor?.setThreshold(value) }
    }

    func setProbeSession(_ id: UUID?) {
        queue.async { [weak self] in self?.processor?.setProbeSession(id) }
    }

    func setDetailedSpectrum(_ enabled: Bool) {
        queue.async { [weak self] in
            guard let self, self.detailedSpectrum != enabled else { return }
            self.detailedSpectrum = enabled
            self.processor?.setDetailedSpectrum(enabled)
        }
    }

    func stop() { queue.async { [self] in stopSession() } }

    private func fail(_ message: String, token: UUID, onError: @escaping (String) -> Void) {
        queue.async { [weak self] in
            guard let self, self.generation == token else { return }
            self.stopSession()
            onError(message)
        }
    }

    private func stopSession() {
        generation = UUID()
        timeout?.cancel()
        timeout = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        session?.outputs.compactMap { $0 as? AVCaptureAudioDataOutput }.forEach {
            $0.setSampleBufferDelegate(nil, queue: nil)
        }
        session?.stopRunning()
        processor = nil
        session = nil
    }
}

private enum CaptureError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
