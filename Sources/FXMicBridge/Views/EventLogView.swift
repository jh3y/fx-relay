import SwiftUI

struct EventLogView: View {
    let model: BridgeModel
    @State private var follow = true
    private static let timeFormatter: DateFormatter = {
        let value = DateFormatter()
        value.dateFormat = "HH:mm:ss.SSS"
        return value
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EVENT LOG").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Toggle("Follow", isOn: $follow).toggleStyle(.checkbox)
                Button("Copy", action: model.copyEvents)
                Button("Clear", action: model.clearEvents)
            }.controlSize(.small)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        if model.events.isEmpty { Text("No events yet").foregroundStyle(.secondary) }
                        ForEach(model.events) { event in
                            HStack(alignment: .top, spacing: 12) {
                                Text(Self.timeFormatter.string(from: event.time)).foregroundStyle(.secondary)
                                Text(event.message).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .id(event.id)
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                }
                .frame(height: 130)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                .onChange(of: model.events.last?.id) { _, id in
                    if follow, let id { proxy.scrollTo(id, anchor: .bottom) }
                }
            }
        }
    }
}
