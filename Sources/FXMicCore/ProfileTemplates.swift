import Foundation

public enum ProfileTemplate: String, CaseIterable, Identifiable {
    case codex = "Codex", claude = "Claude Code · Tap", appleDictation = "Apple Dictation"
    case dictationShortcut = "Dictation Shortcut", blank = "Blank"
    case agentVoice = "Hold-Space Voice", commandVoice = "Command Voice"
    case bankWorkflows = "Agent Banks"
    public var id: String { rawValue }
    public static let starters: [Self] = [.codex, .claude, .appleDictation]
    /// Stable identities allow starters to be added once without renaming existing profiles.
    public var starterID: UUID {
        let suffix = Self.allCases.firstIndex(of: self)! + 1
        return UUID(uuidString: String(format: "46584D49-4342-4000-8000-%012d", suffix))!
    }
    public var summary: String {
        switch self {
        case .codex: return "F8 toggles voice in supported Codex CLI builds. The handle gates audio."
        case .claude: return "Requires /voice tap. Space starts recording; a second tap can submit the prompt."
        case .appleDictation: return "Set macOS Dictation to ⌃⌥D. Toggle from a sample; Apple transcribes."
        case .dictationShortcut: return "Match this shortcut to MacWhisper, Superwhisper or another dictation app."
        case .agentVoice: return "Sound-based hold Space for apps accepting key down/up. Terminal repeat-based PTT may not work."
        case .commandVoice: return "Type /voice or /compact, then submit separately with Return."
        case .bankWorkflows: return "Different handle actions per FX bank. Play a sample after switching. Claude hold-key compatibility needs a target-app check."
        case .blank: return "Start with sixteen empty sample mappings and no handle key."
        }
    }
    public func makeProfile() -> BridgeProfile {
        var c = BridgeConfiguration()
        c.enabledBanks = Array(repeating: true, count: BridgeConfiguration.bankCount)
        if self != .agentVoice {
            c.pttEnabled = false; c.handleAction = .init(.none)
            for i in c.tones.indices { c.tones[i].action = .init(.none) }
        }
        func text(_ value: String) -> BridgeAction { var action = BridgeAction(.typeText); action.text = value; return action }
        let enter = BridgeAction(.keystroke, .init(36, label: "Return"))
        let escape = BridgeAction(.keystroke, .init(53, label: "Escape"))
        let interrupt = BridgeAction(.shortcut, .init(8, modifiers: 1, label: "⌃C"))
        if self == .appleDictation || self == .dictationShortcut {
            var dictation = BridgeAction(.shortcut, .init(2, modifiers: 3, label: "⌃⌥D"))
            dictation.delivery = .systemShortcut
            for bank in 0..<BridgeConfiguration.bankCount {
                c.tones[bank * 4].action = dictation
                c.tones[bank * 4 + 1].action = escape
                c.tones[bank * 4 + 2].action = enter
                c.tones[bank * 4 + 3].action = .init(.shortcut, .init(6, modifiers: 8, label: "⌘Z"))
            }
        } else if self == .codex || self == .claude || self == .commandVoice {
            c.tones[0].action = enter
            c.tones[1].action = self == .codex ? .init(.keystroke, .init(100, label: "F8 · Voice")) :
                self == .claude ? .init(.keystroke, .space) : text("/voice")
            c.tones[2].action = escape
            c.tones[3].action = interrupt
            c.tones[4].action = text(self == .claude ? "/voice tap" : "/voice")
            c.tones[5].action = text(self == .claude ? "/voice off" : "/voice mute")
            c.tones[6].action = text("/compact")
            c.tones[7].action = text("/help")
            // The other banks deliberately start as useful, editable general-purpose keys.
            for (offset, chord) in [KeyChord(48, label: "Tab"), .init(48, modifiers: 4, label: "⇧⇥"),
                                    .init(126, label: "↑"), .init(125, label: "↓")].enumerated() {
                c.tones[8 + offset].action = .init(chord.modifiers == 0 ? .keystroke : .shortcut, chord)
            }
        }
        if self == .bankWorkflows {
            c.bankNames = ["Claude · FX 1", "Codex · FX 2", "Dictation · FX 3", "FX 4"]
            c.handleActions = [.init(.holdKey, .space), .init(.none), .init(.none), .init(.none)]
            c.tones[0].action = enter; c.tones[1].action = escape; c.tones[2].action = interrupt
            c.tones[4].action = .init(.keystroke, .init(100, label: "F8 · Voice"))
            c.tones[5].action = enter; c.tones[6].action = escape
            var dictation = BridgeAction(.shortcut, .init(2, modifiers: 3, label: "⌃⌥D"))
            dictation.delivery = .systemShortcut
            c.tones[8].action = dictation; c.tones[9].action = enter; c.tones[10].action = escape
            // Sample 4 stays unassigned in every bank: it identifies the bank without a macro.
        }
        var profile = BridgeProfile(name: self == .blank ? "New Profile" : rawValue, configuration: c)
        profile.template = rawValue
        return profile
    }
}
