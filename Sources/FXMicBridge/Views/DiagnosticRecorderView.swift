import FXMicCore
import SwiftUI

struct DiagnosticRecorderView: View {
    let model: BridgeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Guided hardware check", systemImage: "record.circle").font(.headline)
                Spacer()
                if model.diagnostics.isRecording {
                    Text("Step \(model.diagnostics.stepNumber) of \(model.diagnostics.stepCount)")
                        .font(.system(.caption, design: .monospaced))
                }
            }
            Text("Save a report to send back: input levels, frequencies, button-test labels, and events. No audio or transcript is saved.")
                .font(.callout).foregroundStyle(.secondary)
            if !model.diagnostics.isRecording {
                Picker("Check", selection: Binding(get: { model.diagnostics.selectedCheck },
                                                  set: { model.diagnostics.selectedCheck = $0 })) {
                    ForEach(DiagnosticCheck.allCases) { Text($0.title).tag($0) }
                }.disabled(model.diagnostics.isSaving)
                Text(model.diagnostics.selectedCheck == .fxButton
                     ? "Orange check: keep the trigger RELEASED throughout. Six separate orange presses, handling comparisons and one sample-play check. About three minutes. Keyboard output stays off."
                     : "The short check tests the handle; the full check adds sample and FX controls.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Identify controls by function: effect preset, sample selector, and sample play (bottom-right). The selector chooses a slot; sample play emits its sound. Button colors vary between guides.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Setup notes: adapter, factory/custom samples, preset LEDs…", text: Binding(
                get: { model.diagnostics.notes }, set: { model.diagnostics.notes = String($0.prefix(8000)) }), axis: .vertical)
                .lineLimit(2...3).textFieldStyle(.roundedBorder)
                .disabled(model.diagnostics.isSaving || (!model.diagnostics.isRecording && model.diagnostics.completionMessage != nil))
            if model.diagnostics.isRecording, let step = model.diagnostics.step {
                VStack(alignment: .leading, spacing: 10) {
                    Text(step.title).font(.title3.weight(.semibold))
                    if model.diagnostics.phase == "measuring" {
                        Text(step.instruction).font(.headline).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(model.diagnostics.phase == "ready" ? "1. BEFORE STARTING" : "KEEP THIS POSITION DURING THE COUNTDOWN")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(step.preparation ?? step.instruction).fixedSize(horizontal: false, vertical: true)
                        if model.diagnostics.phase == "ready" {
                            Text("2. WHEN MEASURING APPEARS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(step.instruction).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Wait for MEASURING before speaking or pressing a sample/effect button.")
                                .font(.callout.weight(.medium))
                        }
                    }
                    HStack {
                        if model.diagnostics.phase == "ready" {
                            Button("Ready — Start Countdown") { model.diagnostics.beginStep() }.buttonStyle(.borderedProminent)
                            Button("Skip Step") { model.diagnostics.skipStep() }
                            Text("3 s countdown → \(Int(step.duration)) s measurement").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Label(model.diagnostics.phase == "countdown" ? "Get ready · \(model.diagnostics.secondsRemaining)" : "MEASURING · \(model.diagnostics.secondsRemaining) s",
                                  systemImage: model.diagnostics.phase == "countdown" ? "timer" : "record.circle.fill")
                                .font(.headline).foregroundStyle(model.diagnostics.phase == "countdown" ? Color.orange : Color.accentColor)
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                        Spacer()
                    }
                    HStack {
                        Text("\(model.diagnostics.measurementCount) meter frames · \(model.diagnostics.probeMeasurementCount) fine windows · auto-save every 10 s · 5 min limit")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Stop & Save") { model.diagnostics.finish(reason: "Stopped by user; partial report") }
                    }
                }
                .padding(12).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                if model.diagnostics.selectedCheck == .fxButton {
                    DisclosureGroup("Optional: FX lights after each press / mistakes") {
                        Text("You can fill these in between steps. Record none, FX1, FX2, or any missed/double press. Do not press extra buttons to check.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(1...6, id: \.self) { index in
                            let id = "fx_press_\(index)"
                            HStack {
                                Text("Press \(index)").frame(width: 55, alignment: .leading)
                                TextField("FX lights / observation", text: Binding(
                                    get: { model.diagnostics.stepObservations[id] ?? "" },
                                    set: { model.diagnostics.setObservation($0, stepID: id) }))
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                }
            } else {
                HStack {
                    Button("Start Guided Check", action: model.startDiagnostic)
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.isRunning || model.diagnostics.isSaving || model.diagnostics.errorMessage != nil)
                    if model.diagnostics.isSaving { ProgressView().controlSize(.small); Text("Saving report…").font(.caption) }
                    if model.diagnostics.savedURL != nil, !model.diagnostics.isSaving {
                        Button("Show Report in Finder") { model.diagnostics.revealSavedFile() }
                    }
                    if model.diagnostics.completionMessage != nil, !model.diagnostics.isSaving {
                        Button("Save Report Again") { model.diagnostics.saveAgain() }
                    }
                }
                if let completion = model.diagnostics.completionMessage {
                    Text("\(completion) · \(model.diagnostics.measurementCount) meter frames · \(model.diagnostics.probeMeasurementCount) fine windows")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let url = model.diagnostics.savedURL, !model.diagnostics.isSaving {
                    Text("Send back \(url.lastPathComponent). Nothing is uploaded automatically.")
                        .font(.caption).textSelection(.enabled)
                }
                if !model.isRunning { Text("Select an input and start monitoring first.").font(.caption).foregroundStyle(.secondary) }
            }
            if let error = model.diagnostics.errorMessage { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
        }
    }
}
