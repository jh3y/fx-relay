// Offscreen rendering of the actual SwiftUI views, not desktop automation.
// Uses an isolated preference suite; never starts capture or posts keyboard events.
import AppKit
import FXMicCore
import SwiftUI

@main struct RenderUI {
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let suite = "com.jhey.fxmicbridge.preview.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = BridgeModel(defaults: defaults)
        let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "docs/previews/v0.7.0")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func render(_ name: String, page: Int, slot: Int = 0, surface: String = "mappings", width: CGFloat, height: CGFloat, dark: Bool = false) throws {
            app.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let content: AnyView
            switch surface {
            case "monitor": content = AnyView(SignalMonitorView(model: model))
            case "menu": content = AnyView(MenuBarView(model: model))
            case "reference": content = AnyView(BankReferenceView(model: model))
            case "onboarding": content = AnyView(SetupWindowView(model: model, initialStep: page))
            default: content = AnyView(MappingWindowView(model: model, initialPage: page, initialSlot: slot))
            }
            let view = content
                .environment(\.colorScheme, dark ? .dark : .light)
                .frame(width: width, height: height)
                .background(Color(nsColor: .windowBackgroundColor))
            let host = NSHostingView(rootView: view)
            host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            host.frame = CGRect(x: 0, y: 0, width: width, height: height)
            host.layoutSubtreeIfNeeded()
            guard host.fittingSize.width <= width + 1, host.fittingSize.height <= height + 1 else {
                throw NSError(domain: "LayoutOverflow", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(name): fitting size \(host.fittingSize) exceeds \(width) × \(height)"])
            }
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "Render", code: 2) }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "Render", code: 3) }
            try data.write(to: output.appendingPathComponent(name + ".png"))
            print("\(name): fitting \(host.fittingSize), viewport \(width) × \(height)")
        }
        try render("mappings-base", page: 0, width: 1020, height: 740)
        try render("mappings-fx4-small", page: 3, width: 860, height: 560)
        model.profiles.select(ProfileTemplate.bankWorkflows.starterID)
        try render("bank-handle", page: 0, slot: -1, width: 1020, height: 740)
        try render("bank-handle-small", page: 0, slot: -1, width: 860, height: 560)
        try render("handle-overview", page: -1, width: 1020, height: 740, dark: true)
        try render("signal-monitor", page: 0, surface: "monitor", width: 760, height: 1000)
        try render("menu", page: 0, surface: "menu", width: 380, height: 800)
        try render("bank-reference", page: 0, surface: "reference", width: 620, height: 650)
        try render("bank-reference-dark", page: 0, surface: "reference", width: 580, height: 650, dark: true)
        try render("onboarding-access", page: 0, surface: "onboarding", width: 680, height: 670)
        try render("onboarding-input", page: 1, surface: "onboarding", width: 620, height: 570)
        try render("onboarding-cues", page: 2, surface: "onboarding", width: 680, height: 670, dark: true)
        try render("onboarding-workflow", page: 3, surface: "onboarding", width: 680, height: 670)
        model.profiles.select(ProfileTemplate.appleDictation.starterID)
        try render("apple-dictation", page: 0, width: 1020, height: 740)
        try render("setup-dark", page: -3, width: 1020, height: 740, dark: true)
    }
}
