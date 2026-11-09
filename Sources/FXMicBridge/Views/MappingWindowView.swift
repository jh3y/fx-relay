import FXMicCore
import SwiftUI

struct MappingWindowView: View {
    let model: BridgeModel
    @State private var draft = BridgeConfiguration()
    @State private var page: Int? = 0
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
            HSplitView {
                List(selection: $page) {
                    Section("Banks") {
                        ForEach(0..<BridgeConfiguration.bankCount, id: \.self) { bank in
                            HStack(spacing: 9) {
                                Text(String(format: "%02d", bank + 1)).font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary).frame(width: 22)
                                Text(draft.bankNames[bank]).lineLimit(1)
                                Spacer(minLength: 0)
                                if !draft.enabledBanks[bank] { Image(systemName: "speaker.slash").font(.caption2).help("Sample actions disabled") }
                            }.padding(.vertical, 4).tag(bank)
                                .help(draft.bankNames[bank] + " · edit only")
                        }
                    }
                    Section("Configuration") {
                        Label("Handle Banks", systemImage: "hand.draw").tag(-1)
                        Label("Detection", systemImage: "slider.horizontal.3").tag(-2)
                        Label("Mic & Workflows", systemImage: "wrench.and.screwdriver").tag(-3)
                    }
                }.listStyle(.sidebar)
                    .frame(minWidth: 180, idealWidth: 210, maxWidth: 270)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if let page, page >= 0 {
                            BankMappingsEditor(configuration: $draft, bank: page, selectedSlot: $slot)
                                .id(model.profiles.library.selectedID)
                            if let name = model.profiles.selected.template, let template = ProfileTemplate(rawValue: name) {
                                DisclosureGroup("Workflow guidance") {
                                    Text(template.summary).font(.callout).foregroundStyle(.secondary).padding(.top, 8)
                                }
                            }
                        } else if page == -1 { handleOverview }
                        else if page == -2 { DetectionSettingsView(configuration: $draft) }
                        else { HardwareSetupView(model: model) }
                        if let error = model.profiles.error { Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
                    }.padding(24).frame(maxWidth: 780, alignment: .leading).frame(maxWidth: .infinity, alignment: .topLeading)
                }.frame(minWidth: 590, maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            HStack(spacing: 10) {
                Label(dirty ? "Unsaved changes · output suspended" : "Saved", systemImage: dirty ? "pencil.circle" : "checkmark.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Button("Revert") { draft = model.bridgeConfiguration }.disabled(!dirty)
                Button("Apply Changes") { model.applyBridgeConfiguration(draft) }
                    .buttonStyle(.borderedProminent).disabled(!dirty || model.diagnostics.isRecording)
                    .keyboardShortcut("s", modifiers: .command)
            }.padding(.horizontal, 20).padding(.vertical, 12)
        }.frame(minWidth: 820, minHeight: 560).bridgeSurface()
            .toolbar {
                ToolbarItem(placement: .navigation) { ContactSymbol().frame(width: 20, height: 20) }
                ToolbarItem(placement: .principal) { ProfileControlsView(model: model).frame(width: 300) }
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button("Setup…") { openWindow(id: "setup") }
                        Button("Bank Reference") { openWindow(id: "cheat-sheet") }
                        Button("Signal Monitor") { openWindow(id: "signal-monitor") }
                    } label: { Label("Tools", systemImage: "ellipsis.circle") }
                    .help("Setup, bank reference and diagnostics")
                }
            }
            .onAppear { draft = model.bridgeConfiguration }
            .onChange(of: model.bridgeConfiguration) { _, value in draft = value }
            .onChange(of: draft) { _, value in model.hasUnsavedMappings = value != model.bridgeConfiguration }
            .background(WindowVisibilityObserver(onChange: { _, _ in }, onClose: {
                draft = model.bridgeConfiguration; model.hasUnsavedMappings = false
            }))
    }
    private var handleOverview: some View {
        VStack(alignment: .leading, spacing: 18) {
            BridgePageHeading(title: "Handle Banks", detail: "Each bank has its own handle action. Editing a bank does not activate it.")
            ForEach(0..<BridgeConfiguration.bankCount, id: \.self) { bank in
                HStack(spacing: 14) {
                    Text(String(format: "%02d", bank + 1)).font(.system(size: 15, design: .monospaced)).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(draft.bankNames[bank]).fontWeight(.medium).lineLimit(1)
                        Text(draft.handleActions[bank].label).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit…") { page = bank; slot = -1 }
                }.padding(.vertical, 9)
                Divider()
            }
            DisclosureGroup("How banks follow the mic") {
                Text("Play a sample after changing FX to identify the bank, or choose Current bank in the menu bar. Orange alone is silent. An unassigned sample can identify a bank without firing an action. Quiet pauses can release a key; silence does not reveal physical handle position.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.top, 8)
            }
        }
    }
}
