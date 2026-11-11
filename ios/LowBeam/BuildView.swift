import SwiftUI

struct BuildView: View {
    @EnvironmentObject private var scripts: ScriptStore

    @State private var showCreate = false
    @State private var editingPack: ScriptPack?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Compose your own light script")
                            .font(.title3.bold())
                        Text("Pick packets from the 1,554-action database, set delays, and order steps. Scripts are stored on this device and can be exported as encrypted .bimmerlight files.")
                            .font(.subheadline)
                            .foregroundStyle(LBTheme.muted)
                        Button {
                            showCreate = true
                        } label: {
                            Label("New script", systemImage: "plus")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(LBTheme.accent)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }

                Section("Your scripts") {
                    if scripts.custom.isEmpty {
                        Text("No custom scripts yet. Create one above or duplicate a built-in show from the Scripts tab.")
                            .font(.subheadline)
                            .foregroundStyle(LBTheme.muted)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(scripts.custom) { pack in
                            Button {
                                editingPack = pack
                            } label: {
                                HStack(spacing: 12) {
                                    LBIcon(
                                        name: pack.icon,
                                        color: LBTheme.color(pack.color),
                                        size: 15,
                                        padding: 9
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pack.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text("\(pack.actions.count) actions")
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
                            for index in offsets {
                                scripts.delete(scripts.custom[index])
                            }
                        }
                    }
                }

                Section("How steps work") {
                    explain("Each step is one Ediabas/UDS request built from an action mapping.")
                    explain("The runner resolves the step against the detected modules, encodes the payload, and frames it for the adapter.")
                    explain("Cleanup steps run when the script stops or finishes.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(LBTheme.background.ignoresSafeArea())
            .navigationTitle("Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(LBTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                ScriptEditorView(source: nil) { pack in
                    scripts.save(pack)
                }
            }
            .sheet(item: $editingPack) { pack in
                ScriptEditorView(source: pack) { updated in
                    scripts.save(updated)
                }
            }
        }
    }

    private func explain(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(LBTheme.accent.opacity(0.7))
                .frame(width: 5, height: 5)
                .padding(.top, 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(LBTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
