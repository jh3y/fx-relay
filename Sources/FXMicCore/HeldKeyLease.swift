import Foundation

/// The sink prepares both events before any key is pressed, then retains the release event.
public protocol KeyEventSink: AnyObject {
    func prepare() -> Bool
    func keyDown()
    func keyUp()
}

/// Repeats are keyDown events marked as autorepeat, not new down/up pairs.
public protocol RepeatingKeyEventSink: KeyEventSink {
    func keyRepeat()
}

/// One initial down, optional explicit repeats, and one matching up. The expiry
/// timer runs independently of the UI/capture queues; it never generates repeats.
public final class HeldKeyLease {
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.jhey.fxmicbridge.key-release", qos: .userInteractive)
    private var sink: KeyEventSink?
    private var timer: DispatchSourceTimer?
    private var released: (() -> Void)?
    private var deadline = DispatchTime.now()
    private var repeatSink: RepeatingKeyEventSink?
    private var nextRepeatAt = DispatchTime.now()
    private var repeatCount = 0

    public var repeatsPosted: Int { lock.lock(); defer { lock.unlock() }; return repeatCount }

    public init() {}
    deinit { release() }

    @discardableResult
    public func hold(_ newSink: KeyEventSink, duration: TimeInterval, continuous: Bool = false, onRelease: @escaping () -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard sink == nil, !continuous || newSink is RepeatingKeyEventSink, newSink.prepare() else { return false }
        sink = newSink
        repeatSink = continuous ? newSink as? RepeatingKeyEventSink : nil
        repeatCount = 0
        nextRepeatAt = .now() + 0.03
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

    /// Call only after checking focus, permission and a fresh analysis frame.
    /// Normal 40 ms control frames supply ~25 repeats/s. No catch-up bursts or
    /// repeat timer: stalled capture/UI stops repeats and the lease releases.
    public func repeatIfDue() {
        lock.lock(); defer { lock.unlock() }
        let now = DispatchTime.now()
        guard let repeatSink, sink != nil, now < deadline, now >= nextRepeatAt else { return }
        repeatSink.keyRepeat()
        repeatCount += 1
        nextRepeatAt = now + 0.03
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
        repeatSink = nil
        timer?.cancel()
        timer = nil
        let callback = released
        released = nil
        return callback
    }
}
