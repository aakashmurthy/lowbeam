import SwiftUI

struct ScriptEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let onSave: (ScriptPack) -> Void
    private let editing: Bool

    @State private var pack: ScriptPack
    @State private var showActionEditor = false
    @State private var actionDraft = ScriptAction.blank()
    @State private var editingActionIndex: Int?
    @State private var validationMessage: String?

    private let iconChoices = [
        "lightbulb.max.fill", "lightbulb.led", "headlight.high.beam.fill",
        "headlight.low.beam.fill", "sparkles", "bolt.fill", "waveform",
        "music.note", "flag.checkered", "eye.fill", "camera.flash",
        "circle.hexagongrid.fill",
    ]

    private let colorChoices = [
        "systemBlue", "systemCyan", "systemTeal", "systemMint",
        "systemGreen", "systemYellow", "systemOrange", "systemRed",
        "systemPink", "systemPurple", "systemIndigo",
    ]

    init(source: ScriptPack?, onSave: @escaping (ScriptPack) -> Void) {
        self.onSave = onSave
        self.editing = source != nil
        _pack = State(initialValue: source ?? .blank())
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                actionsSection
                cleanupNote
            }
            .scrollContentBackground(.hidden)
            .background(LBTheme.background.ignoresSafeArea())
            .navigationTitle(editing ? "Edit script" : "New script")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(LBTheme.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(pack.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showActionEditor) {
                ActionEditorView(action: actionDraft) { updated in
                    commit(updated)
                }
            }
            .alert("Check the script", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK", role: .cancel) { validationMessage = nil }
            } message: {
                Text(validationMessage ?? "")
            }
        }
    }

    private var detailsSection: some View {
        Section("Pack") {
            TextField("Title", text: $pack.title)
                .textInputAutocapitalization(.words)
            TextField("Description", text: $pack.description, axis: .vertical)
                .lineLimit(2...4)

            VStack(alignment: .leading, spacing: 10) {
                Text("Icon")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LBTheme.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(iconChoices, id: \.self) { name in
                            Button {
                                pack.icon = name
                            } label: {
                                LBIcon(
                                    name: name,
                                    color: pack.icon == name ? LBTheme.accent : LBTheme.muted,
                                    size: 16,
                                    padding: 9
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(
                                            pack.icon == name ? LBTheme.accent : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Accent color")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LBTheme.muted)
                HStack(spacing: 10) {
                    ForEach(colorChoices, id: \.self) { name in
                        Button {
                            pack.color = name
                        } label: {
                            Circle()
                                .fill(LBTheme.color(name))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: pack.color == name ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var actionsSection: some View {
        Section {
            ForEach(Array(pack.actions.enumerated()), id: \.element.id) { index, action in
                Button {
                    actionDraft = action
                    editingActionIndex = index
                    showActionEditor = true
                } label: {
                    HStack(spacing: 12) {
                        LBIcon(
                            name: action.icon,
                            color: LBTheme.color(action.color),
                            size: 15,
                            padding: 9
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(action.sequence.count) steps · \(action.section ?? "All")")
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
            .onDelete { offsets in
                pack.actions.remove(atOffsets: offsets)
            }

            Button {
                actionDraft = .blank()
                editingActionIndex = nil
                showActionEditor = true
            } label: {
                Label("Add action", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(LBTheme.accent)
            }
        } header: {
            Text("Actions")
        } footer: {
            Text("Each action is a series of packets sent in order. Add a delay between steps to control timing.")
        }
    }

    private var cleanupNote: some View {
        Section {
            Text("Cleanup steps are stored per action and are sent when the show stops or finishes. Add them in the action editor.")
                .font(.caption)
                .foregroundStyle(LBTheme.muted)
        }
    }

    private func commit(_ action: ScriptAction) {
        if let index = editingActionIndex, pack.actions.indices.contains(index) {
            pack.actions[index] = action
        } else {
            pack.actions.append(action)
        }
        editingActionIndex = nil
        actionDraft = .blank()
    }

    private func save() {
        let title = pack.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            validationMessage = "Give the script a title."
            return
        }
        guard !pack.actions.isEmpty else {
            validationMessage = "Add at least one action before saving."
            return
        }

        var saved = pack
        saved.title = title
        saved.description = pack.description.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.builtIn = false
        onSave(saved)
        dismiss()
    }
}
