import Foundation

/// Routes already-detected sound transitions; it never infers a silent orange-button press.
public struct BankHandleRouter: Sendable {
    public enum Source: String, Codable, Sendable { case cue, manual }
    public enum State: String, Codable, Sendable { case unknownBank, unassigned, waitingForQuiet, ready, active }
    public struct Decision: Equatable, Sendable {
        public let release: Bool
        public let activation: BridgeAction?
        public let bankChanged: Bool
        public let state: State
    }
    public private(set) var bank: Int?
    public private(set) var source: Source?
    public private(set) var state: State = .waitingForQuiet
    private var waitingForQuiet = true
    private var previousAction: BridgeAction?
    private var active = false
    private var pendingRelease = false

    public init() {}
    public mutating func reset() { self = Self() }
    public mutating func select(_ bank: Int?) {
        self.bank = bank.flatMap { (0..<BridgeConfiguration.bankCount).contains($0) ? $0 : nil }
        source = self.bank == nil ? nil : .manual
        waitingForQuiet = true; active = false; pendingRelease = true
        state = .waitingForQuiet
    }
    public mutating func process(_ frame: ControlFrame, configuration: BridgeConfiguration) -> Decision {
        var changed = false
        if let slot = frame.tone.detected, (0..<BridgeConfiguration.controlCount).contains(slot) {
            let next = slot / 4
            changed = bank != next
            bank = next; source = .cue
        }
        let action = configuration.resolvedHandleAction(for: bank)
        let mappingChanged = action != previousAction
        previousAction = action
        let mustRelease = pendingRelease || changed || mappingChanged || !frame.pttActive
        pendingRelease = false
        if changed || mappingChanged {
            waitingForQuiet = true; active = false
        }
        if !frame.pttActive { active = false }
        // A cue itself is not the quiet interval required before a different handle action.
        if !frame.pttActive && frame.rmsDB < configuration.releaseDB && frame.tone.candidate == nil && frame.tone.heldControl == nil && frame.tone.detected == nil {
            waitingForQuiet = false
        }
        var activation: BridgeAction?
        if action == nil { state = .unknownBank }
        else if action?.kind == BridgeAction.Kind.none { state = .unassigned }
        else if waitingForQuiet { state = .waitingForQuiet }
        else {
            if frame.pttTransition == true && !active { activation = action; active = true }
            state = active ? .active : .ready
        }
        return Decision(release: mustRelease, activation: activation, bankChanged: changed, state: state)
    }
}
