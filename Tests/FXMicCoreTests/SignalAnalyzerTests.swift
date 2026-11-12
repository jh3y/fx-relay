import XCTest
@testable import FXMicCore

final class SignalAnalyzerTests: XCTestCase {
    private func sine(_ hz: Double, rate: Double = 48000, amplitude: Double = 0.5, count: Int = 4096) -> [Float] {
        (0..<count).map { Float(amplitude * sin(2 * .pi * hz * Double($0) / rate)) }
    }

    func testSilenceHasFiniteFloorAndNoFrequency() throws {
        let result = try XCTUnwrap(SignalAnalyzer().analyze(channels: [[Float](repeating: 0, count: 4096)], sampleRate: 48000, time: 0))
        XCTAssertEqual(result.rmsDB, -120)
        XCTAssertEqual(result.peakDB, -120)
        XCTAssertNil(result.dominantFrequency)
        XCTAssertEqual(result.peakConcentration, 0)
    }

    func testKnownTonesAcrossCommonSampleRates() throws {
        for rate in [44100.0, 48000.0, 96000.0] {
            for frequency in [1500.0, 2300.0, 3100.0, 3900.0] {
                let analyzer = SignalAnalyzer()
                let result = try XCTUnwrap(analyzer.analyze(channels: [sine(frequency, rate: rate)], sampleRate: rate, time: 0))
                XCTAssertEqual(try XCTUnwrap(result.dominantFrequency), frequency, accuracy: 2)
                XCTAssertEqual(result.rmsDB, -9.03, accuracy: 0.08)
                XCTAssertEqual(result.peakDB, -6.02, accuracy: 0.04)
                XCTAssertGreaterThan(result.peakConcentration, 0.97)
            }
        }
    }

    func testOppositePhaseChannelsDoNotCancel() throws {
        let signal = sine(2300)
        let result = try XCTUnwrap(SignalAnalyzer().analyze(channels: [signal, signal.map { -$0 }], sampleRate: 48000, time: 0))
        XCTAssertEqual(result.rmsDB, -9.03, accuracy: 0.08)
        XCTAssertEqual(try XCTUnwrap(result.dominantFrequency), 2300, accuracy: 2)
    }

    func testStrongestChannelAndStreamingFFT() throws {
        let analyzer = SignalAnalyzer()
        let signal = sine(3100)
        var result: SignalSnapshot?
        for index in 0..<4 {
            let chunk = Array(signal[(index * 1024)..<((index + 1) * 1024)])
            result = analyzer.analyze(channels: [chunk.map { $0 * 0.1 }, chunk], sampleRate: 48000, time: Double(index) * 0.03)
        }
        XCTAssertEqual(result?.analyzedChannel, 2)
        XCTAssertEqual(try XCTUnwrap(result?.dominantFrequency), 3100, accuracy: 2)
        analyzer.reset()
        let next = analyzer.analyze(channels: [sine(1500, count: 1024)], sampleRate: 44100, time: 1)
        XCTAssertNil(next?.dominantFrequency)
        XCTAssertTrue(next?.spectrumDB.isEmpty == true)
    }

    func testInvalidInputIsRejected() {
        let analyzer = SignalAnalyzer()
        XCTAssertNil(analyzer.analyze(channels: [], sampleRate: 48000, time: 0))
        XCTAssertNil(analyzer.analyze(channels: [[.nan]], sampleRate: 48000, time: 0))
        XCTAssertNil(analyzer.analyze(channels: [[1]], sampleRate: 0, time: 0))
    }

    func testBackgroundSpectrumKeepsLevelsFreshAndLiveModeResumesImmediately() throws {
        let analyzer = SignalAnalyzer()
        analyzer.setSpectrumRefreshInterval(1)
        let first = try XCTUnwrap(analyzer.analyze(channels: [sine(1500)], sampleRate: 48000, time: 0))
        XCTAssertEqual(try XCTUnwrap(first.dominantFrequency), 1500, accuracy: 2)
        let next = try XCTUnwrap(analyzer.analyze(channels: [sine(2300, amplitude: 0.1)], sampleRate: 48000, time: 0.2))
        XCTAssertEqual(next.rmsDB, -23.01, accuracy: 0.08, "Levels must not wait for the diagnostic FFT")
        XCTAssertEqual(try XCTUnwrap(next.spectrumAgeSeconds), 0.2, accuracy: 0.001)
        analyzer.setSpectrumRefreshInterval(0.1)
        let live = try XCTUnwrap(analyzer.analyze(channels: [sine(2300)], sampleRate: 48000, time: 0.21))
        XCTAssertEqual(try XCTUnwrap(live.dominantFrequency), 2300, accuracy: 2)
        XCTAssertEqual(live.spectrumAgeSeconds, 0)
    }

    func testBackgroundSpectrumRefreshesAndResetsWhenChannelOrRateChanges() throws {
        let analyzer = SignalAnalyzer()
        analyzer.setSpectrumRefreshInterval(1)
        _ = analyzer.analyze(channels: [sine(1500)], sampleRate: 48000, time: 0)
        let refreshed = try XCTUnwrap(analyzer.analyze(channels: [sine(2300)], sampleRate: 48000, time: 1.01))
        XCTAssertEqual(try XCTUnwrap(refreshed.dominantFrequency), 2300, accuracy: 2)
        let changed = try XCTUnwrap(analyzer.analyze(channels: [sine(3100, amplitude: 0.01), sine(3900)], sampleRate: 48000, time: 1.02))
        XCTAssertEqual(changed.analyzedChannel, 2)
        XCTAssertEqual(try XCTUnwrap(changed.dominantFrequency), 3900, accuracy: 2)
        let rateChanged = try XCTUnwrap(analyzer.analyze(channels: [sine(1500, rate: 44100, count: 1024)], sampleRate: 44100, time: 1.03))
        XCTAssertTrue(rateChanged.spectrumDB.isEmpty)
        XCTAssertNil(rateChanged.dominantFrequency)
        XCTAssertNil(rateChanged.spectrumAgeSeconds)
    }

    func testSignalOnlyEmitsTransitions() {
        var presence = SignalPresence()
        XCTAssertNil(presence.update(rmsDB: -80, thresholdDB: -45))
        XCTAssertEqual(presence.update(rmsDB: -30, thresholdDB: -45), true)
        XCTAssertNil(presence.update(rmsDB: -20, thresholdDB: -45))
        XCTAssertEqual(presence.update(rmsDB: -80, thresholdDB: -45), false)
        XCTAssertNil(presence.update(rmsDB: -90, thresholdDB: -45))
        XCTAssertFalse(presence.reset())
        XCTAssertEqual(presence.update(rmsDB: -45, thresholdDB: -45), true)
        XCTAssertTrue(presence.reset())
        XCTAssertFalse(presence.isPresent)
    }
}
