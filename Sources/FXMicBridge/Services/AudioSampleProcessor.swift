import AVFoundation
import FXMicCore

/// AVFoundation invokes this on a dedicated serial delegate queue, outside the audio render thread.
final class AudioSampleProcessor: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    let queue = DispatchQueue(label: "com.jhey.fxmicbridge.analysis", qos: .userInitiated)
    private let analyzer: SignalAnalyzing = SignalAnalyzer()
    private var presence = SignalPresence()
    private var threshold: Double
    private var lastUIUpdate = -Double.infinity
    private let heartbeatLock = NSLock()
    private var lastBuffer = ProcessInfo.processInfo.systemUptime
    private var failed = false
    private let onFrame: (SignalSnapshot) -> Void
    private let onSignal: (Bool) -> Void
    private let onError: (String) -> Void
    private let controls: ControlAnalyzer
    private let onControl: (ControlFrame) -> Void
    private let onProbe: (UUID, [ProbeWindow]) -> Void
    private var probeSessionID: UUID?

    init(threshold: Double, configuration: BridgeConfiguration, onControl: @escaping (ControlFrame) -> Void,
         onProbe: @escaping (UUID, [ProbeWindow]) -> Void,
         onFrame: @escaping (SignalSnapshot) -> Void,
         onSignal: @escaping (Bool) -> Void, onError: @escaping (String) -> Void) {
        self.threshold = threshold
        self.controls = ControlAnalyzer(configuration: configuration)
        self.onControl = onControl
        self.onProbe = onProbe
        self.onFrame = onFrame
        self.onSignal = onSignal
        self.onError = onError
    }

    var secondsSinceLastBuffer: Double {
        heartbeatLock.lock()
        defer { heartbeatLock.unlock() }
        return ProcessInfo.processInfo.systemUptime - lastBuffer
    }

    func setThreshold(_ value: Double) { queue.async { [weak self] in self?.threshold = value } }
    func setProbeSession(_ id: UUID?) { queue.async { [weak self] in self?.probeSessionID = id } }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard !failed else { return }
        let time = ProcessInfo.processInfo.systemUptime
        heartbeatLock.lock()
        lastBuffer = time
        heartbeatLock.unlock()
        do {
            let (channels, rate) = try PCMReader.read(sampleBuffer)
            guard let snapshot = analyzer.analyze(channels: channels, sampleRate: rate, time: time) else {
                throw PCMReader.ReadError.invalidBuffer
            }
            if let id = probeSessionID {
                onProbe(id, HardwareProbe.analyze(channels: channels, sampleRate: rate, receivedAt: time))
            }
            if let transition = presence.update(rmsDB: snapshot.rmsDB, thresholdDB: threshold) { onSignal(transition) }
            for frame in controls.analyze(samples: channels[snapshot.analyzedChannel - 1], sampleRate: rate,
                                          channel: snapshot.analyzedChannel, time: time) { onControl(frame) }
            if time - lastUIUpdate >= 1.0 / 15 {
                lastUIUpdate = time
                onFrame(snapshot)
            }
        } catch {
            failed = true
            onError("Cannot analyze the selected input: \(error.localizedDescription)")
        }
    }
}

/// Retains the CMBlockBuffer until all channel data has been copied. Accepts both PCM layouts.
enum PCMReader {
    enum ReadError: LocalizedError {
        case invalidBuffer
        var errorDescription: String? { "Expected valid 32-bit floating-point PCM audio." }
    }

    static func read(_ buffer: CMSampleBuffer) throws -> ([[Float]], Double) {
        guard let description = CMSampleBufferGetFormatDescription(buffer),
              let format = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee,
              format.mFormatID == kAudioFormatLinearPCM,
              format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
              format.mBitsPerChannel == 32,
              format.mChannelsPerFrame > 0,
              format.mChannelsPerFrame <= 64 else { throw ReadError.invalidBuffer }
        let frames = CMSampleBufferGetNumSamples(buffer)
        guard frames > 0, frames <= 262144 else { throw ReadError.invalidBuffer }
        var size = 0
        var retained: CMBlockBuffer?
        let query = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(buffer,
            bufferListSizeNeededOut: &size, bufferListOut: nil, bufferListSize: 0,
            blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: nil)
        guard query == noErr, size >= MemoryLayout<AudioBufferList>.size else { throw ReadError.invalidBuffer }
        let memory = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 16)
        defer { memory.deallocate() }
        let list = memory.assumingMemoryBound(to: AudioBufferList.self)
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(buffer,
            bufferListSizeNeededOut: nil, bufferListOut: list, bufferListSize: size,
            blockBufferAllocator: nil, blockBufferMemoryAllocator: nil,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment), blockBufferOut: &retained)
        guard status == noErr else { throw ReadError.invalidBuffer }
        return try withExtendedLifetime(retained) {
            var channels: [[Float]] = []
            for audioBuffer in UnsafeMutableAudioBufferListPointer(list) {
                let channelCount = Int(audioBuffer.mNumberChannels)
                guard channelCount > 0, let data = audioBuffer.mData,
                      Int(audioBuffer.mDataByteSize) >= frames * channelCount * MemoryLayout<Float>.size else {
                    throw ReadError.invalidBuffer
                }
                let samples = data.assumingMemoryBound(to: Float.self)
                for channel in 0..<channelCount {
                    channels.append((0..<frames).map { samples[$0 * channelCount + channel] })
                }
            }
            guard channels.count == Int(format.mChannelsPerFrame) else { throw ReadError.invalidBuffer }
            return (channels, format.mSampleRate)
        }
    }
}
