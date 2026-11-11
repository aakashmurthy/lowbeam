import SwiftUI

struct ContentView: View {
    @ObservedObject var store: PackStore

    var body: some View {
        NavigationStack {
            Group {
                if let error = store.loadError {
                    ContentUnavailableView("Could not load packs", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if store.sgbds.isEmpty {
                    ProgressView("Loading packs")
                } else {
                    List(store.sgbds, id: \.self) { sgbd in
                        NavigationLink {
                            ActionListView(store: store, sgbd: sgbd)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sgbd).font(.headline)
                                Text("\(store.actions(for: sgbd).count) actions")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("LowBeam")
        }
    }
}

struct ActionListView: View {
    @ObservedObject var store: PackStore
    let sgbd: String

    @State private var search = ""

    private var actions: [ActionMapEntry] {
        let all = store.actions(for: sgbd)
        guard !search.isEmpty else { return all }
        return all.filter {
            $0.description.localizedCaseInsensitiveContains(search)
                || $0.command.localizedCaseInsensitiveContains(search)
                || $0.function.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        List(actions) { action in
            NavigationLink {
                ActionDetailView(store: store, sgbd: sgbd, action: action)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.description.isEmpty ? action.command : action.description)
                        .font(.body)
                    Text(action.function)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .searchable(text: $search, prompt: "Filter actions")
        .navigationTitle(sgbd)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ActionDetailView: View {
    @ObservedObject var store: PackStore
    let sgbd: String
    let action: ActionMapEntry

    @State private var on = true

    private var placeholders: [String] {
        action.args.compactMap { argument in
            guard argument.hasPrefix("{"), argument.hasSuffix("}") else { return nil }
            return String(argument.dropFirst().dropLast())
        }
    }

    private var params: [String: String] {
        var result: [String: String] = [:]
        for name in placeholders {
            result[name] = defaultValue(for: name)
        }
        return result
    }

    private var result: Result<[UInt8], Error> {
        do {
            return .success(try store.encode(sgbd: sgbd, action: action, params: params))
        } catch {
            return .failure(error)
        }
    }

    var body: some View {
        List {
            Section("Action") {
                LabeledContent("Function", value: action.function)
                if !action.group.isEmpty {
                    LabeledContent("Group", value: action.group)
                }
                if !action.args.isEmpty {
                    Text(action.args.joined(separator: ", "))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            if placeholders.contains("param_aktion") || placeholders.contains("param_aktion_einaus") {
                Section("Parameters") {
                    Toggle("On", isOn: $on)
                }
            }

            Section("Request") {
                switch result {
                case .success(let payload):
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Payload").font(.caption).foregroundStyle(.secondary)
                        Text(Encoder.hex(payload))
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        if let frame = try? Encoder.frame(payload: payload) {
                            Text("Ediabas frame").font(.caption).foregroundStyle(.secondary)
                            Text(Encoder.hex(frame))
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                case .failure(let error):
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                }
            }

            Section("Notes") {
                Text("Payloads are encoded offline from the bundled packs. Nothing is sent to a vehicle or server.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(action.description.isEmpty ? action.command : action.description)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func defaultValue(for name: String) -> String {
        switch name {
        case "param_aktion":
            return on ? "1" : "0"
        case "param_aktion_einaus":
            return on ? "ein" : "aus"
        case "param_steuern_io":
            return "STA"
        case "param_steuern_routine":
            return "STR"
        case "param_lhm2_pwm":
            return "250"
        case "param_zeit", "param_lhm_zeit", "param_lhm_pwm", "param_rlm_strom_ausgang_wert":
            return "100"
        default:
            return "1"
        }
    }
}
