import Foundation

/// Automatic output follows the focused app, but a gesture may never continue
/// into a new target. A fresh quiet frame must precede the next action.
public struct ForegroundOutputGate {
    public private(set) var targetPID: Int32?
    public private(set) var waitingForQuiet = true
    private var changedAt = Double.infinity

    public init() {}

    /// A true result requires the dispatcher to release all keys to the OLD
    /// target and cancel pending text before accepting events for the new one.
    @discardableResult public mutating func update(targetPID next: Int32?, at time: Double) -> Bool {
        guard next != targetPID else { return false }
        targetPID = next
        changedAt = time
        waitingForQuiet = true
        return true
    }

    public mutating func reset() { self = Self() }

    public mutating func accepts(frameTime: Double, now: Double, quiet: Bool) -> Bool {
        guard targetPID != nil, frameTime.isFinite, now.isFinite,
              frameTime >= changedAt, frameTime <= now, now - frameTime < 0.25 else { return false }
        if waitingForQuiet {
            if quiet { waitingForQuiet = false }
            return false
        }
        return true
    }
}
