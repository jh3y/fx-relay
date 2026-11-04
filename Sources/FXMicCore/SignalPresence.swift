/// Plain threshold crossings for instrumentation; intentionally no PTT semantics.
public struct SignalPresence {
    public private(set) var isPresent = false
    public init() {}

    /// Returns the new state only on a transition.
    public mutating func update(rmsDB: Double, thresholdDB: Double) -> Bool? {
        let next = rmsDB.isFinite && rmsDB >= thresholdDB
        guard next != isPresent else { return nil }
        isPresent = next
        return next
    }

    public mutating func reset() -> Bool {
        let wasPresent = isPresent
        isPresent = false
        return wasPresent
    }
}
