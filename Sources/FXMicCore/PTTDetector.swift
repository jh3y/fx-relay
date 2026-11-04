import Foundation

public protocol PTTDetecting {
    var isActive: Bool { get }
    mutating func update(rmsDB: Double, time: Double, suppress: Bool) -> Bool?
}

/// Sound activity only: silence cannot tell us whether the physical handle is squeezed.
public struct PTTDetector: PTTDetecting {
    public private(set) var isActive = false
    public private(set) var confirmationStartedAtUptime: Double?
    private var quietSince: Double?
    private var lastInputTime: Double?
    private let configuration: BridgeConfiguration
    public init(configuration: BridgeConfiguration) { self.configuration = configuration.validated() }
    public mutating func update(rmsDB: Double, time: Double, suppress: Bool) -> Bool? {
        guard configuration.pttEnabled else { return nil }
        // Input normally arrives in 40 ms blocks. Missing input must not count
        // as sustained activation, including after a format change or stall.
        if let lastInputTime, time <= lastInputTime || time - lastInputTime > 0.1 {
            confirmationStartedAtUptime = nil
        }
        lastInputTime = time
        if !isActive {
            guard !suppress && rmsDB >= configuration.activationDB else {
                confirmationStartedAtUptime = nil
                return nil
            }
            if confirmationStartedAtUptime == nil { confirmationStartedAtUptime = time }
            if time - confirmationStartedAtUptime! + 0.000001 >= configuration.activationDelay {
                isActive = true; quietSince = nil; confirmationStartedAtUptime = nil
                return true
            }
        } else if suppress || rmsDB < configuration.releaseDB {
            if quietSince == nil { quietSince = time }
            if time - quietSince! + 0.000001 >= configuration.releaseDelay {
                isActive = false; quietSince = nil; return false
            }
        } else { quietSince = nil }
        return nil
    }
}
