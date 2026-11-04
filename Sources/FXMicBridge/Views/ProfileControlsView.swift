import FXMicCore
import SwiftUI

struct ProfilePicker: View {
    let model: BridgeModel
    var body: some View {
        Picker("Profile", selection: Binding(get: { model.profiles.library.selectedID }, set: model.profiles.select)) {
            ForEach(model.profiles.library.profiles) { profile in Text(profile.name).tag(profile.id) }
        }.disabled(model.diagnostics.isRecording || model.hasUnsavedMappings)
    }
}

struct ProfileControlsView: View {
    let model: BridgeModel
    @State private var name = ""
    @State private var renaming = false
    @State private var confirmingDelete = false
    var body: some View {
        HStack {
            ProfilePicker(model: model)
            Menu {
                Menu("New from Template") {
                    ForEach(ProfileTemplate.allCases) { template in
                        Button(template.rawValue) { model.profiles.create(template: template) }
                    }
                }
                Button("Duplicate") { model.profiles.create(duplicate: true) }
                Button("Rename…") { name = model.profiles.selected.name; renaming = true }
                Button("Delete…", role: .destructive) { confirmingDelete = true }
                    .disabled(model.profiles.library.profiles.count == 1)
                Divider()
                Button("Import JSON…", action: model.profiles.importJSON)
                Button("Export JSON…", action: model.profiles.exportJSON)
            } label: { Image(systemName: "ellipsis.circle") }
            .menuStyle(.borderlessButton).fixedSize()
            .help("Create, rename, import or export a profile")
            .disabled(model.diagnostics.isRecording || model.hasUnsavedMappings)
        }
        .sheet(isPresented: $renaming) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Rename profile").font(.headline)
                TextField("Name", text: $name).textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { renaming = false }.keyboardShortcut(.cancelAction)
                    Button("Rename") {
                        model.profiles.update(configuration: model.bridgeConfiguration, name: name)
                        if model.profiles.error == nil { renaming = false }
                    }.keyboardShortcut(.defaultAction)
                }
                if let error = model.profiles.error { Text(error).font(.caption).foregroundStyle(.red) }
            }.padding(24).frame(width: 340)
        }
        .alert("Delete \(model.profiles.selected.name)?", isPresented: $confirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: model.profiles.deleteSelected)
        } message: { Text("Other profiles will be kept. Export this profile first if you want a copy.") }
    }
}
