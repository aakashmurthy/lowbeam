import SwiftUI
import UniformTypeIdentifiers

struct ScriptsView: View {
    @EnvironmentObject private var scripts: ScriptStore
    @EnvironmentObject private var connection: ConnectionManager

    @State private var showCreate = false
    @State private var showImport = false
    @State private var importError: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LBHeader(
                        title: "Light scripts",
                        subtitle: "Play a show or open a script to inspect every step."
                    )

                    statusBanner

                    section(
                        title: "Built-in shows",
                        subtitle: "\(scripts.builtIns.count) ready-to-play packs",
                        packs: scripts.builtIns
                    )

                    section(
                        title: "Your scripts",
                        subtitle: scripts.custom.isEmpty
                            ? "Build a pack from any action in the database."
                            : "\(scripts.custom.count) custom pack(s)",
                        packs: scripts.custom
                    )

                    if scripts.custom.isEmpty {
                        Button {
                            showCreate = true
                        } label: {
                            Label("Build your first script", systemImage: "plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(LBTheme.cardStrong)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(LBTheme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .background(LBTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showImport = true
                        } label: {
                            Label("Import pack", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            showCreate = true
                        } label: {
                            Label("New script", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(LBTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                ScriptEditorView(source: nil) { pack in
                    scripts.save(pack)
                }
            }
            .fileImporter(
                isPresented: $showImport,
                allowedContentTypes: [
                    UTType(filenameExtension: "bimmerlight") ?? .data,
                    .json,
                ],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }
                    _ = try scripts.importPack(from: url)
                } catch {
                    importError = error.localizedDescription
                }
            }
            .alert("Import failed", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private var statusBanner: some View {
        HStack(spacing: 12) {
            LBIcon(
                name: connection.isConnected ? "checkmark.circle.fill" : "wifi.slash",
                color: connection.isConnected ? .green : .orange,
                size: 16,
                padding: 10
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.isConnected ? "\(connection.vehicle?.name ?? "Vehicle") connected" : "Offline preview")
                    .font(.subheadline.weight(.semibold))
                Text(connection.isConnected
                     ? "Scripts are sent over \(connection.mode.title)."
                     : "Every payload is built locally. Connect from Garage to send it to a car.")
                    .font(.caption)
                    .foregroundStyle(LBTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .lbCard(padding: 13)
    }

    private func section(title: String, subtitle: String, packs: [ScriptPack]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(LBTheme.muted)
            }

            if packs.isEmpty {
                LBEmptyState(
                    icon: "square.stack.3d.up",
                    title: "Nothing here yet",
                    message: "Create a script and it will appear in this list."
                )
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(packs) { pack in
                        NavigationLink {
                            PackDetailView(pack: pack)
                        } label: {
                            PackCard(pack: pack)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct PackCard: View {
    let pack: ScriptPack

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                LBIcon(name: pack.icon, color: LBTheme.color(pack.color), size: 18, padding: 10)
                Spacer()
                if pack.builtIn == true {
                    Text("SHOW")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(LBTheme.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(LBTheme.cardStrong)
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(pack.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(pack.description)
                    .font(.caption2)
                    .foregroundStyle(LBTheme.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 4) {
                Image(systemName: "play.circle.fill")
                Text("\(pack.actions.count)")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(LBTheme.accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LBTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LBTheme.stroke, lineWidth: 1)
        )
    }
}
