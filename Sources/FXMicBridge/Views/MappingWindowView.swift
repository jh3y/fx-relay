import FXMicCore
import SwiftUI

struct MappingWindowView: View {
    let model: BridgeModel
    @State private var draft = BridgeConfiguration()
    @State private var page = 0
    @State private var slot = 0
    @Environment(\.openWindow) private var openWindow
    private var dirty: Bool { draft != model.bridgeConfiguration }
    init(model: BridgeModel, initialPage: Int = 0, initialSlot: Int = 0) {
        self.model = model
        _draft = State(initialValue: model.bridgeConfiguration)
        _page = State(initialValue: initialPage)
        _slot = State(initialValue: initialSlot)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BridgeBrand()
                Spacer(minLength: 30)
                ProfileControlsView(model: model).frame(width: 310)
            }.padding(22)
            Divider()
            HStack(spacing: 0) {
                GeometryReader { geometry in
                    ScrollView {
                        sidebar.frame(minHeight: geometry.size.height, alignment: .top)
                    }
                }.frame(width: 180)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if page >= 0 {
                            if let name = model.profiles.selected.template, let template = ProfileTemplate(rawValue: name) {
                                Label(template.summary, systemImage: "info.circle")
                                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            BankMappingsEditor(configuration: $draft, bank: page, selectedSlot: $slot)
                                .id(model.profiles.library.selectedID)
                        } else if page == -1 {
                            BridgeStyle.label("HANDLE / BANK MAPPINGS")
                            Text("A handle action for each bank").font(.title.weight(.semibold))
                            Text("Profiles save all four banks. The active handle mapping follows the last played sample, or a bank you select explicitly. Orange alone does not identify the selected bank.")
                                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            ForEach(0..<BridgeConfiguration.bankCount, id: \.self) { bank in
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(draft.bankNames[bank]).font(.headline)
                                        Text(draft.handleActions[bank].label).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Edit handle") { page = bank; slot = -1 }
                                }.padding(14).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                            }
                            Text("Sound detection always runs. None means no keyboard action in that bank. Quiet pauses can release a held key; silence is not a physical handle-position sensor.")
                                .font(.callout).foregroundStyle(.secondary)
                        } else if page == -2 {
                            DetectionSettingsView(configuration: $draft)
                        } else {
                            HardwareSetupView(model: model)
                        }
                        if let error = model.profiles.error { Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
                    }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.frame(maxHeight: .infinity)
            Divider()
            HStack(spacing: 12) {
                Circle().fill(dirty ? BridgeStyle.orange : Color.secondary.opacity(0.45)).frame(width: 6, height: 6)
                Text(dirty ? "Unsaved changes · output off" : "Saved locally").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Revert") { draft = model.bridgeConfiguration }.disabled(!dirty)
                Button("Apply Changes") { model.applyBridgeConfiguration(draft) }
                    .buttonStyle(.borderedProminent).tint(BridgeStyle.orange)
                    .disabled(!dirty || model.diagnostics.isRecording).keyboardShortcut("s", modifiers: .command)
            }.padding(.horizontal, 22).padding(.vertical, 14)
        }
        .frame(minWidth: 860, minHeight: 560)
        .tint(BridgeStyle.orange)
        .onAppear { draft = model.bridgeConfiguration }
        .onChange(of: model.bridgeConfiguration) { _, value in draft = value }
        .onChange(of: draft) { _, value in
            model.hasUnsavedMappings = value != model.bridgeConfiguration
            if model.hasUnsavedMappings { model.actions.disable(reason: "Editing mappings") }
        }
        .background(WindowVisibilityObserver(onChange: { _, _ in }, onClose: {
            draft = model.bridgeConfiguration; model.hasUnsavedMappings = false
            model.actions.disable(reason: "Mappings closed")
        }))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            BridgeStyle.label("BANKS").padding(.bottom, 6)
            ForEach(0..<BridgeConfiguration.bankCount, id: \.self) { bank in
                Button { page = bank; if slot >= 0 { slot = 0 } } label: {
                    HStack(spacing: 9) {
                        Text(String(format: "%02d", bank + 1)).font(.system(.caption, design: .monospaced))
                            .foregroundStyle(page == bank ? BridgeStyle.orange : Color.secondary)
                        Text(draft.bankNames[bank]).lineLimit(1)
                        Spacer(minLength: 0)
                        if !draft.enabledBanks[bank] { Circle().stroke(.secondary, lineWidth: 1).frame(width: 5, height: 5) }
                    }.padding(.horizontal, 10).padding(.vertical, 10)
                        .background(page == bank ? BridgeStyle.orange.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            Divider().padding(.vertical, 10)
            navigation("Handle banks", icon: "hand.draw", page: -1)
            navigation("Detection", icon: "slider.horizontal.3", page: -2)
            navigation("Mic & Workflows", icon: "wrench.and.screwdriver", page: -3)
            Spacer(minLength: 24)
            Button("Signal Monitor") { openWindow(id: "signal-monitor") }.buttonStyle(.link)
            Text("FX → BANK\nSAMPLE → SLOT\nPLAY → ACTION")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Text("FX RELAY / 0.6").font(.system(size: 9, design: .monospaced)).tracking(1.2).foregroundStyle(.tertiary)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func navigation(_ title: String, icon: String, page value: Int) -> some View {
        Button { page = value } label: {
            Label(title, systemImage: icon).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 7).foregroundStyle(page == value ? BridgeStyle.orange : Color.primary)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
