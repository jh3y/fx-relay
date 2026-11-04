import Foundation
import Observation
import XCTest
@testable import FXMicCore

final class LiveReadingsTests: XCTestCase {
    func testHiddenViewsDoNotInvalidateButLatestAndHistoryRemainFresh() async {
        await MainActor.run {
            let readings = LiveReadings(), analyzer = SignalAnalyzer()
            let changes = ChangeCounter()
            withObservationTracking {
                _ = readings.monitorSnapshot
                _ = readings.menuSnapshot
                _ = readings.history
            } onChange: { changes.increment() }
            for index in 0...300 {
                readings.append(analyzer.analyze(channels: [[0.1]], sampleRate: 48000, time: Double(index) / 15)!)
            }
            XCTAssertEqual(changes.value, 0, "A retained hidden view must not receive frame invalidations")
            XCTAssertEqual(readings.latest.capturedAtUptime, 20)
            XCTAssertEqual(readings.latest.sampleRate, 48000)
            readings.setVisible(.monitor, source: UUID(), visible: true)
            XCTAssertEqual(changes.value, 1)
            XCTAssertEqual(readings.monitorSnapshot.capturedAtUptime, 20)
            XCTAssertEqual(readings.history.last?.time, 20)
            XCTAssertGreaterThanOrEqual(readings.history.first!.time, 10)
            XCTAssertLessThanOrEqual(readings.history.count, 151)
        }
    }

    func testPopoverUpdatesCannotInvalidateHiddenMonitorAndReopenUsesLatest() async {
        await MainActor.run {
            let readings = LiveReadings(), analyzer = SignalAnalyzer()
            let menu = UUID(), monitor = UUID(), monitorChanges = ChangeCounter()
            readings.setVisible(.menu, source: menu, visible: true)
            withObservationTracking {
                _ = readings.monitorSnapshot
                _ = readings.history
            } onChange: { monitorChanges.increment() }
            readings.append(analyzer.analyze(channels: [[0.2]], sampleRate: 48000, time: 1)!)
            XCTAssertEqual(readings.menuSnapshot.capturedAtUptime, 1)
            XCTAssertEqual(monitorChanges.value, 0)
            readings.setVisible(.monitor, source: monitor, visible: true)
            XCTAssertEqual(readings.monitorSnapshot.capturedAtUptime, 1)
            readings.setVisible(.monitor, source: monitor, visible: false)
            readings.append(analyzer.analyze(channels: [[0.3]], sampleRate: 48000, time: 2)!)
            XCTAssertEqual(readings.monitorSnapshot.capturedAtUptime, 1)
            XCTAssertEqual(readings.menuSnapshot.capturedAtUptime, 2)
            readings.setVisible(.monitor, source: monitor, visible: true)
            XCTAssertEqual(readings.monitorSnapshot.capturedAtUptime, 2)
            XCTAssertEqual(readings.history.last?.time, 2)
        }
    }

    func testDismantlingOldWindowObserverCannotHideItsReplacement() async {
        await MainActor.run {
            let readings = LiveReadings(), analyzer = SignalAnalyzer()
            let old = UUID(), replacement = UUID()
            readings.setVisible(.monitor, source: old, visible: true)
            readings.setVisible(.monitor, source: replacement, visible: true)
            readings.setVisible(.monitor, source: old, visible: false)
            readings.append(analyzer.analyze(channels: [[0.1]], sampleRate: 48000, time: 1)!)
            XCTAssertTrue(readings.isVisible(.monitor))
            XCTAssertEqual(readings.monitorSnapshot.capturedAtUptime, 1)
            readings.setVisible(.monitor, source: replacement, visible: false)
            readings.append(analyzer.analyze(channels: [[0.1]], sampleRate: 48000, time: 2)!)
            XCTAssertFalse(readings.isVisible(.monitor))
            XCTAssertEqual(readings.monitorSnapshot.capturedAtUptime, 1)
        }
    }

    func testCaptureResetClearsStaleReadingsAndDoesNotLoseVisibleSurface() async {
        await MainActor.run {
            let readings = LiveReadings(), analyzer = SignalAnalyzer(), source = UUID()
            readings.setVisible(.monitor, source: source, visible: true)
            readings.append(analyzer.analyze(channels: [[0.1]], sampleRate: 48000, time: 1)!)
            readings.reset()
            XCTAssertEqual(readings.latest.sampleRate, 0)
            XCTAssertEqual(readings.monitorSnapshot.sampleRate, 0)
            XCTAssertEqual(readings.menuSnapshot.sampleRate, 0)
            XCTAssertTrue(readings.history.isEmpty)
            readings.append(analyzer.analyze(channels: [[0.2]], sampleRate: 48000, time: 3)!)
            XCTAssertEqual(readings.monitorSnapshot.capturedAtUptime, 3)
            XCTAssertEqual(readings.history.count, 1)
        }
    }
}

private final class ChangeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
}
