import Foundation

@MainActor public protocol TextActionSink: AnyObject {
    /// Implementations must post a balanced down/up pair before returning.
    func type(_ utf16: [UInt16]) -> Bool
    func enter() -> Bool
}

/// One cancellable text action at a time. No clipboard, shell, or background typing.
@MainActor public final class TextActionRunner {
    public private(set) var isBusy = false
    private var task: Task<Void, Never>?
    private var generation = UUID()
    public init() {}
    public func cancel() {
        generation = UUID(); task?.cancel(); task = nil; isBusy = false
    }
    public static func chunks(_ text: String) -> [[UInt16]] {
        var chunks: [[UInt16]] = [], current: [UInt16] = []
        for scalar in text.unicodeScalars {
            let units = Array(String(scalar).utf16)
            if current.count + units.count > 20 { chunks.append(current); current = [] }
            current += units
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
    @discardableResult public func start(_ action: BridgeAction, sink: TextActionSink,
        isAllowed: @escaping @MainActor () -> Bool,
        finished: @escaping @MainActor (Bool) -> Void) -> Bool {
        guard !isBusy, action.kind == .typeText, !action.text.isEmpty,
              action.text.utf16.count <= 1024, action.enterDelay.isFinite,
              (0 ... 3).contains(action.enterDelay), isAllowed() else { return false }
        let token = UUID(); generation = token; isBusy = true
        task = Task { [weak self] in
            guard let self else { return }
            var success = false
            defer {
                if generation == token { isBusy = false; task = nil; finished(success) }
            }
            for chunk in Self.chunks(action.text) {
                guard !Task.isCancelled, generation == token, isAllowed(), sink.type(chunk) else { return }
                do { try await Task.sleep(for: .milliseconds(8)) } catch { return }
            }
            if action.pressEnter {
                do { try await Task.sleep(for: .seconds(action.enterDelay)) } catch { return }
                guard !Task.isCancelled, generation == token, isAllowed(), sink.enter() else { return }
            }
            success = true
        }
        return true
    }
}
