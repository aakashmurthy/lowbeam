import SwiftUI

struct StepEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let step: ScriptStep
    private let onSave: (ScriptStep) -> Void

    @State private var groupText: String
    @State private var delayText: String
    @State private var paramRows: [ParamRow]

    private struct ParamRow: Identifiable {
        let id = UUID()
        var key: String
        var value: String
    }

    init(step: ScriptStep, onSave: @escaping (ScriptStep) -> Void) {
        self.step = step
        self.onSave = onSave
        _groupText = State(initialValue: step.group.joined(separator: ", "))
        _delayText = State(initialValue: String(step.delayMs ?? 0))
        _paramRows = State(
            initialValue: (step.params ?? [:])
                .sorted { $0.key < $1.key }
                .map { ParamRow(key: $0.key, value: $0.value) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Step") {
                    LabeledContent("Command") {
                        Text(step.command)
                            .font(.subheadline.monospaced())
                    }
                    LabeledContent("Module", value: step.sgbd ?? "Auto")
                    LabeledContent("Function", value: step.function ?? "From mapping")
                }

                Section {
                    TextField("Groups", text: $groupText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Groups")
                } footer: {
                    Text("Comma-separated group names, for example FRM, LCM, KOMBI. Leave empty to try every module.")
                }

                Section {
                    TextField("Milliseconds", text: $delayText)
                        .keyboardType(.numberPad)
                        .font(.subheadline.monospaced())
                } header: {
                    Text("Delay before sending")
                } footer: {
                    Text("0 sends the step immediately. Use 100–500 ms for module feedback.")
                }

                Section {
                    ForEach($paramRows) { $row in
                        HStack(spacing: 8) {
                            TextField("Name", text: $row.key)
                                .font(.caption.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Divider()
                            TextField("Value", text: $row.value)
                                .font(.caption.monospaced())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    .onDelete { offsets in
                        paramRows.remove(atOffsets: offsets)
                    }

                    Button {
                        paramRows.append(ParamRow(key: "", value: ""))
                    } label: {
                        Label("Add parameter", systemImage: "plus.circle")
                            .font(.subheadline)
                            .foregroundStyle(LBTheme.accent)
                    }
                } header: {
                    Text("Parameters")
                } footer: {
                    Text("Values are passed to the encoder exactly as written. Hex bytes may use 0x.. notation.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(LBTheme.background.ignoresSafeArea())
            .navigationTitle("Edit step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(LBTheme.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let groups = groupText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var params: [String: String] = [:]
        for row in paramRows {
            let key = row.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            params[key] = row.value
        }

        let delay = Int(delayText.trimmingCharacters(in: .whitespacesAndNewlines))

        onSave(
            ScriptStep(
                id: step.id,
                command: step.command,
                group: groups,
                params: params.isEmpty ? nil : params,
                delayMs: delay,
                sgbd: step.sgbd,
                function: step.function
            )
        )
        dismiss()
    }
}
