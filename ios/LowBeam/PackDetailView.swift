import SwiftUI

struct PackDetailView: View {
    let pack: ScriptPack

    @EnvironmentObject private var scripts: ScriptStore
    @Environment(\.dismiss) private var dismiss

    @State private var running: ScriptAction?
    @State private var showEditor = false
    @State private var exportURL: URL?
    @State private var exportError: String?

    private var groups: [(title: String, actions: [ScriptAction])] {
        var order: [String] = []
        var buckets: [String: [ScriptAction]] = [:]
        for action in pack.actions {
            let key = action.section?.isEmpty == false ? action.section! : "All"
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(action)
        }
        return order.map { ($0, buckets[$0] ?? []) }
    }

    var body: some View {
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.actions) { action in
                        actionRow(action)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(LBTheme.background.ignoresSafeArea())
        .navigationTitle(pack.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if pack.builtIn != true {
                        Button {
                            showEditor = true
                        } label: {
                            Label("Edit script", systemImage: "pencil")
                        }
                    }
                    Button {
                        _ = scripts.duplicate(pack)
                    } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    if pack.builtIn != true {
                        Button {
                            do {
                                exportURL = try scripts.exportURL(for: pack)
                            } catch {
                                exportError = error.localizedDescription
                            }
                        } label: {
                            Label("Export .bimmerlight", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(LBTheme.accent)
                }
            }
        }
        .fullScreenCover(item: $running) { action in
            RunnerView(pack: pack, action: action)
        }
        .sheet(isPresented: $showEditor) {
            ScriptEditorView(source: pack) { saved in
                scripts.save(saved)
            }
        }
        .sheet(item: Binding(
            get: { exportURL.map(ExportItem.init) },
            set: { if $0 == nil { exportURL = nil } }
        )) { item in
            ExportSheet(url: item.url)
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                LBIcon(name: pack.icon, color: LBTheme.color(pack.color), size: 24, padding: 13)
                VStack(alignment: .leading, spacing: 3) {
                    Text(pack.title)
                        .font(.title3.bold())
                    Text(pack.builtIn == true ? "Built-in show" : "Custom script")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LBTheme.muted)
                }
                Spacer()
            }

            Text(pack.description)
                .font(.subheadline)
                .foregroundStyle(LBTheme.muted)

            HStack(spacing: 8) {
                badge("\(pack.actions.count) actions", icon: "play.circle")
                badge("\(pack.actions.reduce(0) { $0 + $1.sequence.count }) steps", icon: "list.bullet")
            }

            if pack.builtIn == true {
                Text("Shows run on a parked car. Each action includes cleanup steps.")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.9))
            }
        }
        .padding(.vertical, 10)
    }

    private func actionRow(_ action: ScriptAction) -> some View {
        HStack(spacing: 12) {
            NavigationLink {
                ActionInspectorView(pack: pack, action: action) {
                    running = action
                }
            } label: {
                HStack(spacing: 12) {
                    LBIcon(
                        name: action.icon,
                        color: LBTheme.color(action.color),
                        size: 17,
                        padding: 10
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(action.sequence.count) steps\((action.repeatCount ?? 1) > 1 ? " · \(action.repeatCount!)×" : "")")
                            .font(.caption2)
                            .foregroundStyle(LBTheme.muted)
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                running = action
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
                    .background(LBTheme.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func badge(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(LBTheme.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(LBTheme.cardStrong)
            .clipShape(Capsule())
    }
}

struct ActionInspectorView: View {
    let pack: ScriptPack
    let action: ScriptAction
    let onPlay: () -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    LBIcon(name: action.icon, color: LBTheme.color(action.color), size: 22, padding: 12)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(action.title).font(.headline)
                        Text("\(action.sequence.count) steps · repeat \(action.repeatCount ?? 1)×")
                            .font(.caption)
                            .foregroundStyle(LBTheme.muted)
                    }
                }
                .padding(.vertical, 4)

                Button(action: onPlay) {
                    Label("Play this action", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(LBTheme.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Section("Sequence") {
                ForEach(Array(action.sequence.enumerated()), id: \.element.id) { index, step in
                    stepRow(index + 1, step)
                }
            }

            if let cleanup = action.disable, !cleanup.isEmpty {
                Section("Cleanup") {
                    ForEach(Array(cleanup.enumerated()), id: \.element.id) { index, step in
                        stepRow(index + 1, step)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(LBTheme.background.ignoresSafeArea())
        .navigationTitle(action.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stepRow(_ index: Int, _ step: ScriptStep) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(index).")
                    .font(.caption.monospaced())
                    .foregroundStyle(LBTheme.muted)
                Text(step.command)
                    .font(.subheadline.monospaced().weight(.semibold))
                Spacer()
                if let delay = step.delayMs, delay > 0 {
                    Text("\(delay) ms")
                        .font(.caption2)
                        .foregroundStyle(LBTheme.muted)
                }
            }
            if !step.group.isEmpty {
                Text(step.group.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(LBTheme.muted)
            }
            if let params = step.params, !params.isEmpty {
                Text(params.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "  "))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(LBTheme.muted)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ExportItem: Identifiable {
    let url: URL
    var id: String { url.path }
}

private struct ExportSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                LBIcon(name: "doc.badge.arrow.up", size: 28, padding: 16)
                Text("Encrypted .bimmerlight pack")
                    .font(.headline)
                Text(url.lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(LBTheme.muted)
                ShareLink(item: url) {
                    Text("Share file")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LBTheme.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(24)
            .background(LBTheme.background.ignoresSafeArea())
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
