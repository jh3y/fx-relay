import Foundation

/// The sink prepares both events before any key is pressed, then retains the release event.
public protocol KeyEventSink: AnyObject {
    func prepare() -> Bool
    func keyDown()
    func keyUp()
}

/// One down, at most one matching up. Timer runs independently of the UI/capture queues.
public final class HeldKeyLease {
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.jhey.fxmicbridge.key-release", qos: .userInteractive)
    private var sink: KeyEventSink?
    private var timer: DispatchSourceTimer?
    private var released: (() -> Void)?
    private var deadline = DispatchTime.now()

    public init() {}
    deinit { release() }

    @discardableResult
    public func hold(_ newSink: KeyEventSink, duration: TimeInterval, onRelease: @escaping () -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard sink == nil, newSink.prepare() else { return false }
        sink = newSink
        released = onRelease
        let timer = DispatchSource.makeTimerSource(queue: queue)
        deadline = .now() + min(max(duration, 0.01), 2)
        timer.schedule(deadline: deadline)
        timer.setEventHandler { [weak self] in self?.expire() }
        self.timer = timer
        newSink.keyDown()
        timer.resume()
        return true
    }

    /// Renew only while fresh capture/control frames reach the UI. Never sends another down.
    @discardableResult public func renew(duration: TimeInterval) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard sink != nil, DispatchTime.now() < deadline else { return false }
        deadline = .now() + min(max(duration, 0.01), 2)
        timer?.schedule(deadline: deadline)
        return true
    }

    private func expire() {
        lock.lock()
        guard sink != nil, DispatchTime.now() >= deadline else { lock.unlock(); return }
        let callback = releaseLocked()
        lock.unlock()
        callback?()
    }

    public func release() {
        lock.lock()
        let callback = releaseLocked()
        lock.unlock()
        callback?()
    }

    private func releaseLocked() -> (() -> Void)? {
        guard let sink else { return nil }
        sink.keyUp()
        self.sink = nil
        timer?.cancel()
        timer = nil
        let callback = released
        released = nil
        return callback
    }
}
