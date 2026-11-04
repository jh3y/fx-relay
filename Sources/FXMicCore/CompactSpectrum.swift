import Foundation

public struct SpectralPeak: Codable, Sendable {
    public let frequencyHz: Double
    public let levelDB: Float
}

/// Prepared alongside the FFT on the analysis queue, then reused by report snapshots.
public struct CompactSpectrum: Codable, Sendable {
    public let peaks: [SpectralPeak]
    public let bandsDB: [Float]
    public static let empty = CompactSpectrum(peaks: [], bandsDB: [])

    private init(peaks: [SpectralPeak], bandsDB: [Float]) {
        self.peaks = peaks
        self.bandsDB = bandsDB
    }

    init(spectrum: [Float], sampleRate: Double) {
        let upper = min(20000, sampleRate / 2)
        var bands = [Float](repeating: -120, count: 64)
        var peaks: [SpectralPeak] = []
        if spectrum.count > 2, upper > 20 {
            let logRange = log(upper / 20)
            for bin in 1..<(spectrum.count - 1) {
                let hz = Double(bin) * sampleRate / Double(SignalAnalyzer.fftSize)
                guard hz >= 20, hz <= upper else { continue }
                let band = min(63, max(0, Int(log(hz / 20) / logRange * 64)))
                bands[band] = max(bands[band], spectrum[bin])
                if spectrum[bin] > -100, spectrum[bin] > spectrum[bin - 1], spectrum[bin] >= spectrum[bin + 1] {
                    peaks.append(SpectralPeak(frequencyHz: hz, levelDB: spectrum[bin]))
                }
            }
        }
        self.peaks = Array(peaks.sorted { $0.levelDB > $1.levelDB }.prefix(6))
        bandsDB = spectrum.isEmpty ? [] : bands
    }
}
