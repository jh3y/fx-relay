import AppKit
import SwiftUI

/// SwiftUI may retain a closed window's view tree. AppKit supplies actual visibility.
struct WindowVisibilityObserver: NSViewRepresentable {
    let onChange: (UUID, Bool) -> Void
    var onClose: () -> Void = {}

    func makeNSView(context: Context) -> VisibilityProbe {
        let view = VisibilityProbe()
        view.onChange = onChange
        view.onClose = onClose
        return view
    }

    func updateNSView(_ view: VisibilityProbe, context: Context) {
        view.onChange = onChange
        view.onClose = onClose
        view.refresh()
    }

    static func dismantleNSView(_ view: VisibilityProbe, coordinator: ()) {
        view.stopTracking()
    }

    final class VisibilityProbe: NSView {
        var onChange: (UUID, Bool) -> Void = { _, _ in }
        var onClose: () -> Void = {}
        private let source = UUID()
        private var lastVisible: Bool?
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeObservers()
            guard let window else { publish(false); return }
            for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                         NSWindow.didDeminiaturizeNotification, NSWindow.didBecomeKeyNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                })
            }
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.publish(false)
                    let close = self.onClose
                    DispatchQueue.main.async { close() }
                }
            })
            for name in [NSApplication.didHideNotification, NSApplication.didUnhideNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: NSApp, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                })
            }
            refresh()
        }

        func refresh() {
            guard let window else { publish(false); return }
            publish(window.isVisible && !window.isMiniaturized && !NSApp.isHidden && window.occlusionState.contains(.visible))
        }

        func stopTracking() {
            removeObservers()
            publish(false)
        }

        private func publish(_ visible: Bool) {
            guard lastVisible != visible else { return }
            lastVisible = visible
            let callback = onChange, source = source
            // Never mutate observable SwiftUI state during a representable update.
            DispatchQueue.main.async { callback(source, visible) }
        }

        private func removeObservers() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
        }

        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}
