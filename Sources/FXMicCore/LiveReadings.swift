import Foundation
import Observation

public struct LevelPoint: Sendable {
    public let time: Double
    public let rmsDB: Double
    public let peakDB: Double
}

/// Presentation only. Capture, control detection and report collection do not depend on visibility.
@MainActor @Observable
public final class LiveReadings {
    public enum Surface: Hashable { case monitor, menu }

    public private(set) var monitorSnapshot = SignalSnapshot.empty
    public private(set) var menuSnapshot = SignalSnapshot.empty
    public private(set) var history: [LevelPoint] = []
    @ObservationIgnored public private(set) var latest = SignalSnapshot.empty
    @ObservationIgnored private var recentHistory: [LevelPoint] = []
    @ObservationIgnored private var visibleSources: [Surface: Set<UUID>] = [:]

    public init() {}

    public func setVisible(_ surface: Surface, source: UUID, visible: Bool) {
        let wasVisible = isVisible(surface)
        if visible { visibleSources[surface, default: []].insert(source) }
        else { visibleSources[surface]?.remove(source) }
        if !wasVisible && isVisible(surface) { publish(surface) }
    }

    public func isVisible(_ surface: Surface) -> Bool {
        !(visibleSources[surface]?.isEmpty ?? true)
    }

    public func append(_ snapshot: SignalSnapshot) {
        latest = snapshot
        recentHistory.append(LevelPoint(time: snapshot.capturedAtUptime, rmsDB: snapshot.rmsDB, peakDB: snapshot.peakDB))
        recentHistory.removeAll { snapshot.capturedAtUptime - $0.time > 10 }
        // Also bound memory if a caller supplies repeated/non-advancing timestamps.
        if recentHistory.count > 200 { recentHistory.removeFirst(recentHistory.count - 200) }
        if isVisible(.monitor) { publish(.monitor) }
        if isVisible(.menu) { publish(.menu) }
    }

    public func reset() {
        latest = .empty
        recentHistory.removeAll()
        monitorSnapshot = .empty
        menuSnapshot = .empty
        history.removeAll()
    }

    private func publish(_ surface: Surface) {
        switch surface {
        case .monitor:
            monitorSnapshot = latest
            history = recentHistory
        case .menu:
            menuSnapshot = latest
        }
    }
}
