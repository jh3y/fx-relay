import AppKit
import SwiftUI

@main
struct FXMicBridgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = BridgeModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Image(nsImage: MenuBarGlyph.image(status: model.statusSymbol))
                .accessibilityLabel("FX Relay · \(model.status)")
                .help("FX Relay · \(model.status)")
        }
        .menuBarExtraStyle(.window)

        monitorWindow.defaultLaunchBehavior(.suppressed)
        Window("FX Relay — Mappings", id: "mappings") {
            MappingWindowView(model: model)
        }
        .defaultSize(width: 1020, height: 740)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)

        Window("FX Relay — Setup", id: "setup") {
            SetupWindowView(model: model)
        }
        .defaultSize(width: 680, height: 670)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(model.utilityPreferences.introductionDismissed ? .suppressed : .presented)

        Window("FX Relay — Bank Reference", id: "cheat-sheet") {
            BankReferenceView(model: model)
        }
        .windowResizability(.contentSize)
        .windowLevel(model.utilityPreferences.keepCheatSheetOnTop ? .floating : .normal)
        .defaultLaunchBehavior(.suppressed)
    }

    private var monitorWindow: some Scene {
        Window("FX Relay — Signal Monitor", id: "signal-monitor") {
            SignalMonitorView(model: model)
        }
        .defaultSize(width: 720, height: 850)
        .windowResizability(.contentMinSize)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var eventMonitor: Any?
    private var terminationSignals: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Deliberately a menu-bar utility: no Dock icon, monitor opens on demand.
        NSApp.setActivationPolicy(.accessory)
        if let icon = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            NSApp.applicationIconImage = NSImage(contentsOf: icon)
        }
        configureTerminationSignals()
        if TerminalDeliveryCheck.runIfRequested() { return }
        BridgeModel.shared.start()
        if !BridgeModel.shared.utilityPreferences.introductionDismissed {
            NSApp.activate(ignoringOtherApps: true)
        }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            guard event.keyCode == 49,
                  event.cgEvent?.getIntegerValueField(.eventSourceUserData) == ActionDispatcher.testMarker else { return event }
            BridgeModel.shared.receiveTestEvent(isDown: event.type == .keyDown)
            // Only our own tagged test events are consumed, so they cannot re-press the TEST button.
            return nil
        }
    }

    private func configureTerminationSignals() {
        for code in [SIGTERM, SIGINT] {
            signal(code, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: code, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            terminationSignals.append(source)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        TerminalDeliveryCheck.cancel()
        BridgeModel.shared.shutdown()
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        terminationSignals.forEach { $0.cancel() }
    }
}
