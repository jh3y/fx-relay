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
        let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "docs/previews/v0.8.0")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func render(_ name: String, page: Int, slot: Int = 0, surface: String = "mappings", width: CGFloat, height: CGFloat, dark: Bool = false, accessible: Bool = false) throws {
            ContactPreviewAppearance.accessible = accessible
            let appearance: NSAppearance.Name = accessible ? (dark ? .accessibilityHighContrastDarkAqua : .accessibilityHighContrastAqua) : (dark ? .darkAqua : .aqua)
            app.appearance = NSAppearance(named: appearance)
            let content: AnyView
            switch surface {
            case "monitor": content = AnyView(SignalMonitorView(model: model))
            case "readings": content = AnyView(SignalReadingsView(model: model).padding(24).bridgeSurface())
            case "menu": content = AnyView(MenuBarView(model: model))
            case "reference": content = AnyView(BankReferenceView(model: model))
            case "onboarding": content = AnyView(SetupWindowView(model: model, initialStep: page))
            default: content = AnyView(MappingWindowView(model: model, initialPage: page, initialSlot: slot))
            }
            var canvasHeight = height
            if surface == "menu" {
                let measurement = NSHostingView(rootView: content.environment(\.colorScheme, dark ? .dark : .light).frame(width: width))
                let natural = measurement.fittingSize
                canvasHeight = natural.height
                print("\(name): natural size \(natural)")
                guard natural.height <= height + 1 else { throw NSError(domain: "PopoverOverflow", code: 4, userInfo: [NSLocalizedDescriptionKey: "\(name): natural height \(natural.height) exceeds \(height)"]) }
            }
            let view = content
                .environment(\.colorScheme, dark ? .dark : .light)
                .frame(width: width, height: canvasHeight)
                .background(Color(nsColor: .windowBackgroundColor))
            let host = NSHostingView(rootView: view)
            host.appearance = NSAppearance(named: appearance)
            host.frame = CGRect(x: 0, y: 0, width: width, height: canvasHeight)
            let window = NSWindow(contentRect: host.frame, styleMask: [.titled, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: appearance)
            window.contentView = host
            // Native List/AppKit controls populate on a later run-loop turn.
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            host.layoutSubtreeIfNeeded()
            defer { window.close() }
            guard host.fittingSize.width <= width + 1, host.fittingSize.height <= height + 1 else {
                throw NSError(domain: "LayoutOverflow", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(name): fitting size \(host.fittingSize) exceeds \(width) × \(height)"])
            }
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "Render", code: 2) }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "Render", code: 3) }
            try data.write(to: output.appendingPathComponent(name + ".png"))
            print("\(name): fitting \(host.fittingSize), viewport \(width) × \(height)")
        }

        // All fixtures are private, compile-only UI state. No capture or key dispatch.
        model.profiles.select(ProfileTemplate.bankWorkflows.starterID)
        for dark in [false, true] {
            let mode = dark ? "dark" : "light"
            model.prepareVisualPreview()
            try render("menu-" + mode, page: 0, surface: "menu", width: 380, height: 560, dark: dark)
            try render("samples-" + mode, page: 0, width: 1000, height: 760, dark: dark)
            try render("handle-" + mode, page: 0, slot: -1, width: 1000, height: 760, dark: dark)
            try render("handle-small-" + mode, page: 0, slot: -1, width: 820, height: 560, dark: dark)
            try render("detection-" + mode, page: -2, width: 1000, height: 760, dark: dark)
            try render("handle-overview-" + mode, page: -1, width: 1000, height: 760, dark: dark)
            try render("workflows-" + mode, page: -3, width: 1000, height: 760, dark: dark)
            try render("reference-" + mode, page: 0, surface: "reference", width: 620, height: 580, dark: dark)
            try render("monitor-" + mode, page: 0, surface: "monitor", width: 760, height: 1000, dark: dark)
            try render("monitor-readings-" + mode, page: 0, surface: "readings", width: 760, height: 560, dark: dark)
            for step in 0..<4 {
                try render("setup-\(step)-" + mode, page: step, surface: "onboarding", width: 680, height: 670, dark: dark)
            }
            try render("menu-accessible-" + mode, page: 0, surface: "menu", width: 380, height: 560, dark: dark, accessible: true)
        }
        for (name, state) in [("permission", BridgeReadiness.microphonePermission), ("disconnected", .disconnected), ("no-input", .chooseInput), ("paused", .paused), ("error", .captureError), ("unsaved", .unsavedMappings)] {
            model.prepareVisualPreview(state: state)
            try render("menu-" + name, page: 0, surface: "menu", width: 380, height: 640, dark: name == "paused")
        }
        model.prepareVisualPreview(unknownBank: true)
        try render("menu-unknown-bank", page: 0, surface: "menu", width: 380, height: 560)
        var long = model.bridgeConfiguration
        long.bankNames[0] = "Claude Code — my everyday voice workspace"
        long.tones[0].action = .init(.none)
        var text = BridgeAction(.typeText); text.text = "/voice with a longer command for layout review"; text.pressEnter = true
        long.tones[1].action = text
        model.profiles.update(configuration: long, name: "Everyday engineering — agents and documentation")
        model.prepareVisualPreview(longNames: true)
        try render("menu-long-names", page: 0, surface: "menu", width: 380, height: 560)
        try render("samples-long-names", page: 0, slot: 1, width: 820, height: 560)
        var modifier = BridgeAction(.holdKey, ModifierKey.option.chord); modifier.delivery = .systemShortcut
        long.handleActions[0] = modifier
        model.profiles.update(configuration: long)
        model.prepareVisualPreview()
        try render("handle-option", page: 0, slot: -1, width: 1000, height: 760, dark: true)
        for status in ["mic", "keyboard.fill", "bolt.circle.fill", "mic.slash", "exclamationmark.triangle"] {
            let image = MenuBarGlyph.image(status: status)
            for points in [16, 18] {
                for scale in [1, 2] {
                    let size = points * scale
                    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
                    NSGraphicsContext.restoreGraphicsState()
                    try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("symbol-\(status)-\(points)@\(scale)x.png"))
                }
            }
        }
    }
}
