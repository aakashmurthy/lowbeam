import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var connection: ConnectionManager
    @EnvironmentObject private var store: PackStore
    @EnvironmentObject private var scripts: ScriptStore

    @AppStorage("hasOnboarded") private var hasOnboarded = true
    @State private var showClearConfirmation = false

    private let repository = URL(string: "https://github.com/aakashmurthy/lowbeam")!

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
    }

    var body: some View {
        NavigationStack {
            List {
                connectionSection
                librarySection
                aboutSection
                safetySection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(LBTheme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete all custom scripts?", isPresented: $showClearConfirmation) {
                Button("Delete", role: .destructive) {
                    scripts.clearCustom()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Built-in shows are not affected. This cannot be undone.")
            }
        }
    }

    private var connectionSection: some View {
        Section {
            HStack {
                LBIcon(name: connection.adapter.symbol, size: 15, padding: 9)
                VStack(alignment: .leading, spacing: 2) {
                    Text(connection.adapter.name)
                        .font(.subheadline.weight(.semibold))
                    Text(connection.isConnected ? "Connected" : "Not connected")
                        .font(.caption)
                        .foregroundStyle(connection.isConnected ? .green : LBTheme.muted)
                }
            }

            LabeledContent("Default host") {
                TextField("192.168.0.10", text: $connection.host)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.subheadline.monospaced())
            }

            LabeledContent("Default port") {
                TextField("6801", text: $connection.port)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                    .font(.subheadline.monospaced())
            }
        } header: {
            Text("Connection")
        } footer: {
            Text("ENET uses a TCP link to a Wi-Fi adapter or cable. The default address is 192.168.0.10:6801.")
        }
    }

    private var librarySection: some View {
        Section {
            LabeledContent("Modules", value: "\(store.sgbds.count)")
            LabeledContent("Built-in shows", value: "\(scripts.builtIns.count)")
            LabeledContent("Custom scripts", value: "\(scripts.custom.count)")

            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Text("Delete all custom scripts")
            }
            .disabled(scripts.custom.isEmpty)
        } header: {
            Text("Library")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Pack data", value: "BimmerLight 3.9")
            Link(destination: repository) {
                Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            Button {
                hasOnboarded = false
            } label: {
                Text("Show welcome on next launch")
            }
        } header: {
            Text("About")
        } footer: {
            Text("LowBeam is an independent open-source project. It is not affiliated with BimmerLight, BMW, MINI, or Rolls-Royce.")
        }
    }

    private var safetySection: some View {
        Section {
            Text("Use light shows only on a parked vehicle, away from public roads. Commands are temporary; cleanup steps return the modules to their normal state. Unplug the adapter when it is not in use.")
                .font(.caption)
                .foregroundStyle(LBTheme.muted)
        } header: {
            Text("Safety")
        }
    }
}
