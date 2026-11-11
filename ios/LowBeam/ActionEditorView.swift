import SwiftUI

struct ActionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let onSave: (ScriptAction) -> Void

    @State private var action: ScriptAction
    @State private var showPicker = false
    @State private var addingCleanup = false
    @State private var showStepEditor = false
    @State private var stepDraft: ScriptStep?
    @State private var editingSequenceIndex: Int?
    @State private var editingCleanupIndex: Int?
    @State private var validationMessage: String?

    private let colorChoices = [
        "systemBlue", "systemCyan", "systemTeal", "systemMint",
        "systemGreen", "systemYellow", "systemOrange", "systemRed",
        "systemPink", "systemPurple", "systemIndigo",
    ]

    private let sectionChoices = [
        "Front", "Rear", "Both Sides", "Interior", "Exterior",
        "Indicators", "Welcome & Goodbye", "Driving", "Show", "All",
    ]

    init(action: ScriptAction, onSave: @escaping (ScriptAction) -> Void) {
        self.onSave = onSave
        _action = State(initialValue: action)
    }

    var body: some View {
        NavigationStack {
            Form {
                details
                sequenceSection
                cleanupSection
            }
            .scrollContentBackground(.hidden)
            .background(LBTheme.background.ignoresSafeArea())
            .navigationTitle("Edit action")
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
            .sheet(isPresented: $showPicker) {
                StepPickerView { sgbd, entry in
                    addStep(sgbd: sgbd, entry: entry)
                }
            }
            .sheet(isPresented: $showStepEditor) {
                if let draft = stepDraft {
                    StepEditorView(step: draft) { updated in
                        commitStep(updated)
                    }
                }
            }
            .alert("Check the action", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) { validationMessage = nil }
            } message: {
                Text(validationMessage ?? "")
            }
        }
    }

    private var details: some View {
        Section("Action") {
            TextField("Title", text: $action.title)
                .textInputAutocapitalization(.words)

            HStack {
                Text("Icon")
                Spacer()
                TextField("SF Symbol", text: $action.icon)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.subheadline.monospaced())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LBTheme.muted)
                HStack(spacing: 9) {
                    ForEach(colorChoices, id: \.self) { name in
                        Button {
                            action.color = name
                        } label: {
                            Circle()
                                .fill(LBTheme.color(name))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: action.color == name ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Picker("Section", selection: Binding(
                get: { action.section ?? "All" },
                set: { action.section = $0 == "All" ? nil : $0 }
            )) {
                ForEach(sectionChoices, id: \.self) { Text($0).tag($0) }
            }

            Stepper(value: Binding(
                get: { action.repeatCount ?? 1 },
                set: { action.repeatCount = $0 }
            ), in: 1...50) {
                Text("Repeat \(action.repeatCount ?? 1)×")
            }
        }
    }

    private var sequenceSection: some View {
        Section {
            ForEach(Array(action.sequence.enumerated()), id: \.element.id) { index, step in
                stepRow(step) {
                    editingSequenceIndex = index
                    editingCleanupIndex = nil
                    stepDraft = step
                    showStepEditor = true
                }
            }
            .onDelete { offsets in
                action.sequence.remove(atOffsets: offsets)
            }

            Button {
                addingCleanup = false
                showPicker = true
            } label: {
                Label("Add step", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LBTheme.accent)
            }
        } header: {
            Text("Sequence")
        } footer: {
            Text("Steps are sent in order. Use a delay when a module needs time between packets.")
        }
    }

    private var cleanupSection: some View {
        Section {
            ForEach(Array((action.disable ?? []).enumerated()), id: \.element.id) { index, step in
                stepRow(step) {
                    editingCleanupIndex = index
                    editingSequenceIndex = nil
                    stepDraft = step
                    showStepEditor = true
                }
            }
            .onDelete { offsets in
                var cleanup = action.disable ?? []
                cleanup.remove(atOffsets: offsets)
                action.disable = cleanup
            }

            Button {
                addingCleanup = true
                showPicker = true
            } label: {
                Label("Add cleanup step", systemImage: "arrow.uturn.backward.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Cleanup")
        } footer: {
            Text("Cleanup runs after the sequence finishes or when the show is stopped.")
        }
    }

    private func stepRow(_ step: ScriptStep, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.command)
                        .font(.subheadline.monospaced().weight(.semibold))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        if let sgbd = step.sgbd, !sgbd.isEmpty {
                            Text(sgbd)
                                .foregroundStyle(LBTheme.accent)
                        }
                        if !step.group.isEmpty {
                            Text(step.group.joined(separator: " · "))
                        }
                        if let delay = step.delayMs, delay > 0 {
                            Text("\(delay) ms")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(LBTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LBTheme.muted)
            }
        }
        .buttonStyle(.plain)
    }

    private func addStep(sgbd: String, entry: ActionMapEntry) {
        let step = ScriptStep(
            command: entry.command,
            group: entry.group.isEmpty ? [] : [entry.group],
            params: ScriptDefaults.params(for: entry),
            delayMs: 100,
            sgbd: sgbd.uppercased(),
            function: entry.function
        )
        if addingCleanup {
            action.disable = (action.disable ?? []) + [step]
        } else {
            action.sequence.append(step)
        }
        showPicker = false
    }

    private func commitStep(_ updated: ScriptStep) {
        if let index = editingSequenceIndex, action.sequence.indices.contains(index) {
            action.sequence[index] = updated
        } else if let index = editingCleanupIndex,
                  var cleanup = action.disable,
                  cleanup.indices.contains(index) {
            cleanup[index] = updated
            action.disable = cleanup
        }
        editingSequenceIndex = nil
        editingCleanupIndex = nil
        stepDraft = nil
        showStepEditor = false
    }

    private func save() {
        let title = action.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            validationMessage = "Give the action a title."
            return
        }
        guard !action.sequence.isEmpty else {
            validationMessage = "Add at least one step to the action."
            return
        }
        var saved = action
        saved.title = title
        saved.repeatCount = max(1, action.repeatCount ?? 1)
        onSave(saved)
        dismiss()
    }
}
