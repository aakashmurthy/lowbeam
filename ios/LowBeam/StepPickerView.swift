import SwiftUI

struct StepPickerView: View {
    @EnvironmentObject private var store: PackStore
    @Environment(\.dismiss) private var dismiss

    let onPick: (String, ActionMapEntry) -> Void

    @State private var search = ""

    private struct Candidate: Identifiable {
        let id: String
        let sgbd: String
        let entry: ActionMapEntry
    }

    private var candidates: [Candidate] {
        var result: [Candidate] = []
        for sgbd in store.sgbds {
            for (index, entry) in store.actions(for: sgbd).enumerated() {
                result.append(
                    Candidate(
                        id: "\(sgbd)#\(index)",
                        sgbd: sgbd,
                        entry: entry
                    )
                )
            }
        }
        return result
    }

    private var filtered: [Candidate] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return candidates }
        return candidates.filter { candidate in
            candidate.entry.command.localizedCaseInsensitiveContains(query)
                || candidate.entry.description.localizedCaseInsensitiveContains(query)
                || candidate.entry.group.localizedCaseInsensitiveContains(query)
                || candidate.entry.function.localizedCaseInsensitiveContains(query)
                || candidate.sgbd.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { candidate in
                Button {
                    onPick(candidate.sgbd, candidate.entry)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text(candidate.sgbd)
                                .font(.caption2.monospaced().weight(.bold))
                                .foregroundStyle(LBTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LBTheme.accentSoft)
                                .clipShape(Capsule())
                            Text(candidate.entry.command)
                                .font(.subheadline.monospaced().weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        Text(candidate.entry.description)
                            .font(.caption)
                            .foregroundStyle(LBTheme.muted)
                            .lineLimit(2)
                        Text("\(candidate.entry.group) · \(candidate.entry.function)")
                            .font(.caption2)
                            .foregroundStyle(LBTheme.muted.opacity(0.75))
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(LBTheme.background.ignoresSafeArea())
            .searchable(text: $search, prompt: "Search 1,554 actions")
            .navigationTitle("Add step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(LBTheme.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(filtered.count)")
                        .font(.caption.monospaced())
                        .foregroundStyle(LBTheme.muted)
                }
            }
        }
    }
}
