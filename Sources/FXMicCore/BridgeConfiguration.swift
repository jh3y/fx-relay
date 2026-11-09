import Foundation

public struct KeyChord: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    /// Portable mask: control=1, option=2, shift=4, command=8.
    public var modifiers: UInt8
    public var label: String
    public init(_ keyCode: UInt16, modifiers: UInt8 = 0, label: String) {
        self.keyCode = keyCode; self.modifiers = modifiers & 15; self.label = label
    }
    public static let space = KeyChord(49, label: "Space")
    public var modifierKey: ModifierKey? { ModifierKey(rawValue: keyCode) }
    public static let presets: [KeyChord] = [.space, .init(36, label: "Return"), .init(53, label: "Escape"),
        .init(48, label: "Tab"), .init(8, modifiers: 1, label: "⌃C"), .init(40, modifiers: 8, label: "⌘K"),
        .init(48, modifiers: 4, label: "⇧⇥"), .init(35, modifiers: 12, label: "⇧⌘P")]
}

public struct BridgeAction: Codable, Equatable, Sendable {
    public enum Delivery: String, Codable, CaseIterable, Sendable { case targetApp, systemShortcut }
    public enum Kind: String, Codable, CaseIterable, Sendable { case none, holdKey, holdKeyContinuous, keystroke, shortcut, typeText }
    public var kind: Kind
    public var chord: KeyChord
    public var text = ""
    public var pressEnter = false
    public var enterDelay = 0.3
    public var delivery = Delivery.targetApp
    public init(_ kind: Kind, _ chord: KeyChord = .space) { self.kind = kind; self.chord = chord }
    public var isHold: Bool { kind == .holdKey || kind == .holdKeyContinuous }
    public var supportsSystemDelivery: Bool { kind == .shortcut || kind == .holdKey }
    public var usesSystemDelivery: Bool { supportsSystemDelivery && delivery == .systemShortcut }
    public var label: String {
        if kind == .none { return "Unassigned" }
        if kind == .typeText { return "\(text.isEmpty ? "Type text" : String(text.prefix(28)))\(pressEnter ? " ↵" : "")" }
        if kind == .holdKeyContinuous { return "\(chord.label) · Continuous Hold" }
        return "\(chord.label)\(kind == .holdKey ? " · Hold" : "")"
    }
    private enum CodingKeys: String, CodingKey { case kind, chord, text, pressEnter, enterDelay, delivery }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(Kind.self, forKey: .kind)
        chord = try c.decodeIfPresent(KeyChord.self, forKey: .chord) ?? .space
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        pressEnter = try c.decodeIfPresent(Bool.self, forKey: .pressEnter) ?? false
        enterDelay = try c.decodeIfPresent(Double.self, forKey: .enterDelay) ?? 0.3
        delivery = try c.decodeIfPresent(Delivery.self, forKey: .delivery) ?? .targetApp
    }
}

public struct ToneDefinition: Codable, Equatable, Sendable {
    public var frequency: Double
    public var action: BridgeAction
    public init(_ frequency: Double, action: BridgeAction) { self.frequency = frequency; self.action = action }
}

public struct BridgeConfiguration: Codable, Equatable, Sendable {
    public static let bankCount = 4
    public static let controlCount = 16
    public static let frequencies: [Double] = [1500, 2300, 3100, 3900, 2751, 4218, 5685, 7153,
                                               818, 1254, 1690, 2126, 2915, 4469, 6023, 7578]
    public var bankNames = ["Base / FX 1", "FX 2", "FX 3", "FX 4"]
    // Detection always suppresses known tones from PTT; action dispatch is opt-in.
    public var enabledBanks = [true, true, false, false]
    public var activationDB = -60.0
    public var activationDelay = 0.12
    public var releaseDB = -65.0
    public var releaseDelay = 0.9
    public var pttEnabled = true
    public var handleAction = BridgeAction(.holdKey)
    /// Nil keeps the legacy global mapping. New edits use one action per FX bank.
    public var bankHandleActions: [BridgeAction]?
    public var handleActions: [BridgeAction] {
        get { bankHandleActions ?? Array(repeating: pttEnabled ? handleAction : .init(.none), count: Self.bankCount) }
        set { bankHandleActions = newValue }
    }
    public var toneFloorDB = -50.0
    public var toleranceHz = 20.0
    public var minimumToneDuration = 0.10
    public var cooldown = 0.4
    public var tones: [ToneDefinition] = [
        .init(1500, action: .init(.keystroke, .init(36, label: "Return"))),
        .init(2300, action: .init(.keystroke, .init(53, label: "Escape"))),
        .init(3100, action: .init(.shortcut, .init(8, modifiers: 1, label: "⌃C"))),
        .init(3900, action: .init(.none)),
        .init(2751, action: .init(.none)), .init(4218, action: .init(.none)),
        .init(5685, action: .init(.none)), .init(7153, action: .init(.none)),
        .init(818, action: .init(.none)), .init(1254, action: .init(.none)),
        .init(1690, action: .init(.none)), .init(2126, action: .init(.none)),
        .init(2915, action: .init(.none)), .init(4469, action: .init(.none)),
        .init(6023, action: .init(.none)), .init(7578, action: .init(.none))]
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case activationDB, activationDelay, releaseDB, releaseDelay, pttEnabled, handleAction
        case toneFloorDB, toleranceHz, minimumToneDuration, cooldown, tones, bankNames, enabledBanks, bankHandleActions
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        activationDB = try values.decode(Double.self, forKey: .activationDB)
        // Older profiles keep every existing mapping/threshold and gain confirmation.
        activationDelay = try values.decodeIfPresent(Double.self, forKey: .activationDelay) ?? 0.12
        releaseDB = try values.decode(Double.self, forKey: .releaseDB)
        releaseDelay = try values.decode(Double.self, forKey: .releaseDelay)
        pttEnabled = try values.decode(Bool.self, forKey: .pttEnabled)
        handleAction = try values.decode(BridgeAction.self, forKey: .handleAction)
        bankHandleActions = try values.decodeIfPresent([BridgeAction].self, forKey: .bankHandleActions)
        toneFloorDB = try values.decode(Double.self, forKey: .toneFloorDB)
        toleranceHz = try values.decode(Double.self, forKey: .toleranceHz)
        minimumToneDuration = try values.decode(Double.self, forKey: .minimumToneDuration)
        cooldown = try values.decode(Double.self, forKey: .cooldown)
        tones = try values.decode([ToneDefinition].self, forKey: .tones)
        bankNames = try values.decodeIfPresent([String].self, forKey: .bankNames) ?? ["Base", "FX 2"]
        enabledBanks = try values.decodeIfPresent([Bool].self, forKey: .enabledBanks) ?? [true, true, false, false]
        migrateBanks()
    }
    private mutating func migrateBanks() {
        if tones.count == 4 || tones.count == 8 { tones += Self().tones.dropFirst(tones.count) }
        if bankNames.count == 2 { bankNames += ["FX 3", "FX 4"] }
    }
    public func validated() -> Self {
        var c = self
        func clamp(_ x: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
            x.isFinite ? min(range.upperBound, max(range.lowerBound, x)) : fallback
        }
        c.activationDB = clamp(c.activationDB, -90 ... -10, -60)
        c.activationDelay = clamp(c.activationDelay, 0 ... 0.4, 0.12)
        c.releaseDB = clamp(c.releaseDB, -100 ... c.activationDB, c.activationDB - 5)
        c.releaseDelay = clamp(c.releaseDelay, 0.15 ... 3, 0.9)
        c.toneFloorDB = clamp(c.toneFloorDB, -80 ... -10, -50)
        c.toleranceHz = clamp(c.toleranceHz, 5 ... 40, 20)
        c.minimumToneDuration = clamp(c.minimumToneDuration, 0.08 ... 0.25, 0.1)
        c.cooldown = clamp(c.cooldown, 0.2 ... 2, 0.4)
        c.migrateBanks()
        if c.tones.count != Self.controlCount { c.tones = Self().tones }
        if c.bankNames.count != Self.bankCount { c.bankNames = Self().bankNames }
        if c.enabledBanks.count != Self.bankCount { c.enabledBanks = Self().enabledBanks }
        if let handles = c.bankHandleActions, handles.count != Self.bankCount {
            c.bankHandleActions = Array(repeating: .init(.none), count: Self.bankCount)
        }
        for i in c.bankNames.indices {
            c.bankNames[i] = String(c.bankNames[i].trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
            if c.bankNames[i].isEmpty { c.bankNames[i] = "Bank \(i + 1)" }
        }
        for i in c.tones.indices { c.tones[i].frequency = clamp(c.tones[i].frequency, 500 ... 8000, Self().tones[i].frequency) }
        return c
    }

    public func controlLabel(_ index: Int) -> String {
        guard tones.indices.contains(index), bankNames.indices.contains(index / 4) else { return "Unknown cue" }
        return "\(bankNames[index / 4]) · Sample \(index % 4 + 1)"
    }
    public func action(for index: Int) -> BridgeAction {
        guard tones.indices.contains(index), enabledBanks.indices.contains(index / 4), enabledBanks[index / 4] else { return .init(.none) }
        return tones[index].action
    }
    /// A silent selector cannot identify a bank. A uniform mapping is safe without bank identity.
    public func resolvedHandleAction(for bank: Int?) -> BridgeAction? {
        let actions = handleActions
        guard actions.count == Self.bankCount else { return nil }
        if let bank, actions.indices.contains(bank) { return actions[bank] }
        return actions.allSatisfy { $0 == actions[0] } ? actions[0] : nil
    }
}
