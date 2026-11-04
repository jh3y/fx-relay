import Foundation

struct MonitorEvent: Identifiable {
    let id = UUID()
    let time = Date()
    let uptime = ProcessInfo.processInfo.systemUptime
    let message: String
    let analysisUptime: Double?

    init(message: String, analysisUptime: Double? = nil) {
        self.message = message
        self.analysisUptime = analysisUptime
    }
}
