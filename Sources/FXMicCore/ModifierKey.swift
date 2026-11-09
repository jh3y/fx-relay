import CoreGraphics

/// Momentary modifier keys only. Caps Lock and Fn have different system behavior.
public enum ModifierKey: UInt16, CaseIterable, Sendable {
    case option = 58, rightOption = 61
    case control = 59, rightControl = 62
    case shift = 56, rightShift = 60
    case command = 55, rightCommand = 54

    public var label: String {
        switch self {
        case .option: return "⌥ Option"
        case .rightOption: return "Right ⌥ Option"
        case .control: return "⌃ Control"
        case .rightControl: return "Right ⌃ Control"
        case .shift: return "⇧ Shift"
        case .rightShift: return "Right ⇧ Shift"
        case .command: return "⌘ Command"
        case .rightCommand: return "Right ⌘ Command"
        }
    }
    public var chord: KeyChord { .init(rawValue, label: label) }
    public var flag: CGEventFlags {
        switch self {
        case .option, .rightOption: return .maskAlternate
        case .control, .rightControl: return .maskControl
        case .shift, .rightShift: return .maskShift
        case .command, .rightCommand: return .maskCommand
        }
    }
    /// Device-specific flags distinguish left/right for listeners that bind a side.
    public var flags: CGEventFlags {
        let device: UInt64
        switch self {
        case .option: device = 0x20
        case .rightOption: device = 0x40
        case .control: device = 0x01
        case .rightControl: device = 0x2000
        case .shift: device = 0x02
        case .rightShift: device = 0x04
        case .command: device = 0x08
        case .rightCommand: device = 0x10
        }
        return flag.union(CGEventFlags(rawValue: device))
    }

    /// Global state can echo our own synthetic press. A release must explicitly
    /// remove the side we own, retaining the shared flag only for the other side.
    /// Same-side physical and synthetic presses cannot be separated by this query.
    public func releasing(from current: CGEventFlags) -> CGEventFlags {
        var remaining = current.subtracting(flags)
        if let opposite = Self.allCases.first(where: { $0 != self && $0.flag == flag }),
           current.contains(opposite.flags.subtracting(flag)) {
            remaining.insert(flag)
        }
        return remaining
    }
}
