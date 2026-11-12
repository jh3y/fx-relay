import Accelerate
import Foundation

public struct SignalSnapshot: Sendable {
    public let rmsDB: Double
    public let peakDB: Double
    public let dominantFrequency: Double?
    public let peakConcentration: Double
    public let spectrumDB: [Float]
    public let sampleRate: Double
    public let channelCount: Int
    public let analyzedChannel: Int
    public let channelRMSDB: [Double]
    public let channelPeakDB: [Double]
    public let capturedAtUptime: Double
    public let spectrumAgeSeconds: Double?
    public let compactSpectrum: CompactSpectrum

    public static let empty = SignalSnapshot(rmsDB: -120, peakDB: -120,
        dominantFrequency: nil, peakConcentration: 0, spectrumDB: [],
        sampleRate: 0, channelCount: 0, analyzedChannel: 0,
        channelRMSDB: [], channelPeakDB: [], capturedAtUptime: 0, spectrumAgeSeconds: nil,
        compactSpectrum: .empty)
}

/// Implementations are confined to the capture delegate's serial queue.
public protocol SignalAnalyzing: AnyObject {
    func analyze(channels: [[Float]], sampleRate: Double, time: Double) -> SignalSnapshot?
    func setSpectrumRefreshInterval(_ interval: TimeInterval)
    func reset()
}

/// Measurement only: no handle inference, voice activity classification, or tone actions.
public final class SignalAnalyzer: SignalAnalyzing {
    public static let fftSize = 4096
    private let setup: vDSP_DFT_Setup
    private var window = [Float](repeating: 0, count: fftSize)
    private var ring = [Float](repeating: 0, count: fftSize)
    private var real = [Float](repeating: 0, count: fftSize)
    private let imaginary = [Float](repeating: 0, count: fftSize)
    private var outReal = [Float](repeating: 0, count: fftSize)
    private var outImaginary = [Float](repeating: 0, count: fftSize)
    private var cursor = 0
    private var filled = 0
    private var previousChannel = -1
    private var previousRate = 0.0
    private var lastSpectrumTime = -Double.infinity
    private var spectrumRefreshInterval: TimeInterval = 0.1
    private var spectrum: [Float] = []
    private var compactSpectrum = CompactSpectrum.empty
    private var frequency: Double?
    private var concentration = 0.0
    private var windowSum: Float = 0

    public init() {
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(Self.fftSize), .FORWARD) else {
            preconditionFailure("Unable to allocate the spectrum transform")
        }
        self.setup = setup
        vDSP_hann_window(&window, vDSP_Length(Self.fftSize), Int32(vDSP_HANN_NORM))
        windowSum = window.reduce(0, +)
    }

    deinit { vDSP_DFT_DestroySetup(setup) }

    /// Only diagnostic frequency/spectrum work is throttled. Levels, channel choice,
    /// and the separate ControlAnalyzer continue to consume every input buffer.
    public func setSpectrumRefreshInterval(_ interval: TimeInterval) {
        spectrumRefreshInterval = interval.isFinite ? min(1, max(0.1, interval)) : 0.1
    }

    public func reset() {
        cursor = 0
        filled = 0
        previousChannel = -1
        previousRate = 0
        lastSpectrumTime = -.infinity
        spectrum = []
        compactSpectrum = .empty
        frequency = nil
        concentration = 0
    }

    public func analyze(channels: [[Float]], sampleRate: Double, time: Double) -> SignalSnapshot? {
        guard sampleRate.isFinite, sampleRate > 0,
              !channels.isEmpty, channels.allSatisfy({ !$0.isEmpty }) else { return nil }
        // Measure channels independently. A mono downmix can cancel opposite-phase inputs.
        var bestChannel = 0
        var bestRMS: Float = -1
        var peak: Float = 0
        var channelRMSDB: [Double] = []
        var channelPeakDB: [Double] = []
        for (index, channel) in channels.enumerated() {
            guard channel.allSatisfy(\.isFinite) else { return nil }
            var rms: Float = 0
            var channelPeak: Float = 0
            vDSP_rmsqv(channel, 1, &rms, vDSP_Length(channel.count))
            vDSP_maxmgv(channel, 1, &channelPeak, vDSP_Length(channel.count))
            channelRMSDB.append(Self.decibels(rms))
            channelPeakDB.append(Self.decibels(channelPeak))
            if rms > bestRMS { bestRMS = rms; bestChannel = index }
            peak = max(peak, channelPeak)
        }
        if previousChannel != bestChannel || previousRate != sampleRate {
            reset()
            previousChannel = bestChannel
            previousRate = sampleRate
        }
        for sample in channels[bestChannel] {
            ring[cursor] = sample
            cursor = (cursor + 1) % Self.fftSize
            filled = min(filled + 1, Self.fftSize)
        }
        if filled == Self.fftSize && time - lastSpectrumTime >= spectrumRefreshInterval {
            updateSpectrum(sampleRate: sampleRate)
            lastSpectrumTime = time
        }
        return SignalSnapshot(rmsDB: Self.decibels(bestRMS), peakDB: Self.decibels(peak),
            dominantFrequency: bestRMS > 0.0000316 ? frequency : nil,
            peakConcentration: concentration, spectrumDB: spectrum, sampleRate: sampleRate,
            channelCount: channels.count, analyzedChannel: bestChannel + 1,
            channelRMSDB: channelRMSDB, channelPeakDB: channelPeakDB,
            capturedAtUptime: time, spectrumAgeSeconds: spectrum.isEmpty ? nil : max(0, time - lastSpectrumTime),
            compactSpectrum: compactSpectrum)
    }

    public static func decibels(_ amplitude: Float) -> Double {
        max(-120, 20 * log10(max(Double(amplitude), 0.000001)))
    }

    private func updateSpectrum(sampleRate: Double) {
        let count = Self.fftSize
        for index in 0..<count { real[index] = ring[(cursor + index) % count] * window[index] }
        vDSP_DFT_Execute(setup, real, imaginary, &outReal, &outImaginary)
        var powers = [Float](repeating: 0, count: count / 2)
        spectrum = [Float](repeating: -120, count: count / 2)
        for bin in 1..<powers.count {
            powers[bin] = outReal[bin] * outReal[bin] + outImaginary[bin] * outImaginary[bin]
            spectrum[bin] = Float(Self.decibels(2 * sqrt(powers[bin]) / windowSum))
        }
        compactSpectrum = CompactSpectrum(spectrum: spectrum, sampleRate: sampleRate)
        let firstBin = max(1, Int(ceil(20 * Double(count) / sampleRate)))
        guard firstBin < powers.count - 1,
              let bin = (firstBin..<(powers.count - 1)).max(by: { powers[$0] < powers[$1] }),
              spectrum[bin] > -100 else { frequency = nil; concentration = 0; return }
        // Interpolation estimates the peak between FFT bins; it does not identify a control.
        let a = Double(spectrum[bin - 1]), b = Double(spectrum[bin]), c = Double(spectrum[bin + 1])
        let denominator = a - 2 * b + c
        let offset = abs(denominator) > 0.000001 ? max(-0.5, min(0.5, 0.5 * (a - c) / denominator)) : 0
        frequency = (Double(bin) + offset) * sampleRate / Double(count)
        let total = powers[firstBin...].reduce(0, +)
        concentration = total > 0 ? min(1, Double((powers[bin - 1] + powers[bin] + powers[bin + 1]) / total)) : 0
    }
}
