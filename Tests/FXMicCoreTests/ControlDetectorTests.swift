import XCTest
@testable import FXMicCore

final class ControlDetectorTests: XCTestCase {
    private func sine(_ hz: Double, duration: Double, rate: Double = 48000, amplitude: Double = 0.2) -> [Float] {
        (0..<Int(rate * duration)).map { Float(amplitude * sin(2 * .pi * hz * Double($0) / rate)) }
    }
    private func analyze(_ samples: [Float], rate: Double = 48000, configuration: BridgeConfiguration = .init()) -> [ControlFrame] {
        let analyzer = ControlAnalyzer(configuration: configuration)
        var frames: [ControlFrame] = []
        // Deliberately use capture buffers that do not align with the detector window.
        for start in stride(from: 0, to: samples.count, by: 512) {
            let end = min(start + 512, samples.count)
            frames += analyzer.analyze(samples: Array(samples[start..<end]), sampleRate: rate, channel: 1, time: Double(end) / rate)
        }
        return frames
    }
    func testPTTHysteresisDelayAndTransitionsOnly() {
        var c = BridgeConfiguration(); c.activationDB = -60; c.releaseDB = -65; c.activationDelay = 0
        var ptt = PTTDetector(configuration: c)
        XCTAssertNil(ptt.update(rmsDB: -80, time: 0, suppress: false))
        XCTAssertEqual(ptt.update(rmsDB: -55, time: 0.1, suppress: false), true)
        XCTAssertNil(ptt.update(rmsDB: -62, time: 0.2, suppress: false))
        XCTAssertNil(ptt.update(rmsDB: -80, time: 0.3, suppress: false))
        XCTAssertNil(ptt.update(rmsDB: -80, time: 1.19, suppress: false))
        XCTAssertEqual(ptt.update(rmsDB: -80, time: 1.2, suppress: false), false)
        XCTAssertNil(ptt.update(rmsDB: -80, time: 1.3, suppress: false))
        XCTAssertNil(ptt.update(rmsDB: -20, time: 1.4, suppress: true))
    }
    func testSpeechResumesBeforeReleaseAndNoActionStillDetects() {
        var immediate = BridgeConfiguration(); immediate.activationDelay = 0
        var ptt = PTTDetector(configuration: immediate)
        XCTAssertEqual(ptt.update(rmsDB: -40, time: 0, suppress: false), true)
        _ = ptt.update(rmsDB: -90, time: 0.1, suppress: false)
        XCTAssertNil(ptt.update(rmsDB: -40, time: 0.8, suppress: false))
        XCTAssertNil(ptt.update(rmsDB: -90, time: 0.9, suppress: false))
        XCTAssertNil(ptt.update(rmsDB: -90, time: 1.5, suppress: false))
        XCTAssertEqual(ptt.update(rmsDB: -90, time: 1.8, suppress: false), false)
        var c = BridgeConfiguration(); c.pttEnabled = false; c.activationDelay = 0
        var preview = PTTDetector(configuration: c)
        XCTAssertEqual(preview.update(rmsDB: -20, time: 0, suppress: false), true)
        XCTAssertEqual(c.resolvedHandleAction(for: nil)?.kind, BridgeAction.Kind.none)
    }
    func testEveryCueFiresOnceAndDoesNotActivatePTTAtDifferentRates() {
        for rate in [32000.0, 44100, 48000, 96000] {
            for (slot, frequency) in [1500.0, 2300, 3100, 3900].enumerated() {
                let samples = sine(frequency, duration: 0.3, rate: rate) + [Float](repeating: 0, count: Int(rate))
                let frames = analyze(samples, rate: rate)
                XCTAssertEqual(frames.compactMap { $0.tone.detected }, [slot], "rate \(rate), slot \(slot)")
                XCTAssertTrue(frames.compactMap(\.pttTransition).isEmpty)
                XCTAssertNil(frames.last?.tone.heldControl)
            }
        }
    }
    func testInstalledCuePackFilesRecognizeTheirSlotsWithoutPTT() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for slot in 0..<4 {
            let data = try Data(contentsOf: root.appendingPathComponent("hardware/agent-cues-v1/\(slot + 1).wav"))
            XCTAssertEqual(String(data: data[0..<4], encoding: .ascii), "RIFF")
            XCTAssertEqual(String(data: data[36..<40], encoding: .ascii), "data")
            let samples: [Float] = stride(from: 44, to: data.count, by: 2).map {
                Float(Int16(bitPattern: UInt16(data[$0]) | UInt16(data[$0 + 1]) << 8)) / 32768
            }
            let frames = analyze([Float](repeating: 0, count: 1517) + samples + [Float](repeating: 0, count: 24000))
            XCTAssertEqual(frames.compactMap { $0.tone.detected }, [slot])
            XCTAssertTrue(frames.compactMap(\.pttTransition).isEmpty)
        }
    }
    func testCueOnsetsAndFadesAcrossBlockBoundariesCannotOpenPTT() {
        for leading in stride(from: 0, to: 1920, by: 160) {
            var cue = sine(2300, duration: 0.3)
            for i in 0..<480 {
                cue[i] *= Float(i) / 480
                cue[cue.count - 1 - i] *= Float(i) / 480
            }
            let frames = analyze([Float](repeating: 0, count: leading) + cue + [Float](repeating: 0, count: 48000))
            XCTAssertEqual(frames.compactMap { $0.tone.detected }, [1])
            XCTAssertTrue(frames.compactMap(\.pttTransition).isEmpty, "onset offset \(leading)")
        }
    }
    func testContinuousTonePurityDipsAndSlotChangesDoNotRetriggerUntilSilence() {
        let tone = sine(1500, duration: 0.6)
        let other = sine(3100, duration: 0.6)
        let mixed = zip(sine(1500, duration: 0.2), sine(600, duration: 0.2)).map(+)
        let frames = analyze(tone + mixed + tone + other + [Float](repeating: 0, count: 12000) + other)
        XCTAssertEqual(frames.compactMap { $0.tone.detected }, [0, 2])
    }
    func testShortBurstLowLevelAndOutsideToleranceAreRejected() {
        for samples in [sine(2300, duration: 0.06), sine(2300, duration: 0.5, amplitude: 0.0001), sine(2335, duration: 0.5)] {
            XCTAssertTrue(analyze(samples).compactMap { $0.tone.detected }.isEmpty)
        }
        XCTAssertEqual(analyze(sine(2315, duration: 0.3)).compactMap { $0.tone.detected }, [1])
    }
    func testNoiseHarmonicsAndCompetingTonesAreRejected() {
        var state: UInt32 = 42
        let noise: [Float] = (0..<48000).map { _ in
            state = 1664525 &* state &+ 1013904223
            return (Float(state) / Float(UInt32.max) * 2 - 1) * 0.1
        }
        let competing = zip(sine(1500, duration: 1), sine(2300, duration: 1)).map(+)
        let vowel = zip(sine(2300, duration: 1, amplitude: 0.1), sine(1150, duration: 1, amplitude: 0.2)).map(+)
        for samples in [noise, competing, vowel] {
            let frames = analyze(samples)
            XCTAssertTrue(frames.compactMap { $0.tone.detected }.isEmpty)
            XCTAssertEqual(frames.compactMap(\.pttTransition), [true])
        }
    }
    func testCooldownRequiresBothSilenceAndElapsedTime() {
        var c = BridgeConfiguration(); c.cooldown = 1
        let tone = sine(3900, duration: 0.2)
        let quiet = [Float](repeating: 0, count: 9600)
        let frames = analyze(tone + quiet + tone + quiet + quiet + tone + quiet, configuration: c)
        XCTAssertEqual(frames.compactMap { $0.tone.detected }, [3, 3])
    }
    func testConfigurationRoundTripAndInvalidLimits() throws {
        var c = BridgeConfiguration()
        c.handleAction = .init(.holdKey, .init(48, modifiers: 4, label: "⇧⇥"))
        c.activationDB = -200; c.releaseDB = 0; c.releaseDelay = 50; c.tones = []
        let validated = c.validated()
        XCTAssertEqual(validated.activationDB, -90)
        XCTAssertEqual(validated.releaseDB, -90)
        XCTAssertEqual(validated.releaseDelay, 3)
        XCTAssertEqual(validated.tones.count, 16)
        XCTAssertEqual(try JSONDecoder().decode(BridgeConfiguration.self, from: JSONEncoder().encode(validated)), validated)
    }
}
