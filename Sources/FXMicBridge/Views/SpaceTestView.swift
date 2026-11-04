import SwiftUI

struct SpaceTestView: View {
    let model: BridgeModel
    @State private var destination = TestDestination.monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("KEYBOARD OUTPUT CHECK").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(model.actions.status).font(.caption).foregroundStyle(model.actions.isHeld ? Color.orange : Color.secondary)
            }
            Text("This button makes the Mac hold and release Space. It does not listen for an FX-MIC button, test the audio input, or turn on push-to-talk. You can skip it while recording hardware measurements.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Picker("Send to", selection: $destination) {
                    ForEach(TestDestination.allCases) { Text($0.rawValue).tag($0) }
                }.disabled(model.actions.isBusy)
                Button("Send Space for 1 Second") { model.testKeyboard(destination: destination) }
                    .disabled(!model.permissions.accessibility || model.actions.isBusy || model.diagnostics.isRecording)
                if model.actions.isBusy { Button("Release / Cancel") { model.actions.cancel(reason: "Manual release") } }
            }
            Text(destination == .monitor
                 ? "Posts one Space down, then one Space up after 1 second. Receipt is verified here in the event log."
                 : "Click Send Space, then focus your target app within 3 seconds. Space is held there for 1 second and released to the same app. The receipt counters below only verify events sent to This app.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label("Received DOWN: \(model.receivedTestDowns)", systemImage: "arrow.down")
                Label("Received UP: \(model.receivedTestUps)", systemImage: "arrow.up")
            }.font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
        }
    }
}
