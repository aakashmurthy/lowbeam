import Combine
import Foundation

final class PackStore: ObservableObject {
    @Published private(set) var sgbds: [String] = []
    @Published private(set) var packs: [PackDoc] = []
    @Published private(set) var loadError: String?

    private(set) var mappings: [String: [ActionMapEntry]] = [:]
    private(set) var bundles: [String: BundleDoc] = [:]
    private(set) var ecuModulesByHex: [String: String] = [:]

    private var groupToSgbds: [String: [String]] = [:]

    init() {
        load()
    }

    func actions(for sgbd: String) -> [ActionMapEntry] {
        mappings[sgbd.uppercased()] ?? mappings[sgbd] ?? []
    }

    func bundle(for sgbd: String) -> BundleDoc? {
        bundles[sgbd.uppercased()]
    }

    func entry(sgbd: String, command: String) -> ActionMapEntry? {
        actions(for: sgbd).first(where: { $0.command == command })
    }

    func sgbd(forHex hex: String) -> String? {
        ecuModulesByHex[hex.uppercased()]
    }

    func placeholders(for sgbd: String, command: String) -> [String] {
        guard let entry = entry(sgbd: sgbd, command: command) else { return [] }
        return ScriptDefaults.placeholderNames(in: entry.args)
    }

    func encode(
        sgbd: String,
        action: ActionMapEntry,
        params: [String: String]
    ) throws -> [UInt8] {
        let bundle = bundle(for: sgbd) ?? BundleDoc(
            sgbd: sgbd.lowercased(),
            addr: "",
            jobs: [:],
            fns: [],
            enums: [:],
            lights: nil
        )
        return try Encoder.encode(
            bundle: bundle,
            function: action.function,
            args: action.args,
            params: params
        )
    }

    func resolve(
        command: String,
        groups: [String],
        modules: Set<String>,
        sgbdHint: String? = nil
    ) -> [RunTarget] {
        let normalizedGroups = groups.map { $0.uppercased() }.filter { !$0.isEmpty }
        let candidates: [String]

        if let hint = sgbdHint?.uppercased(), !hint.isEmpty {
            candidates = [hint]
        } else {
            if normalizedGroups.isEmpty {
                candidates = sgbds
            } else {
                var set = Set<String>()
                for group in normalizedGroups {
                    set.formUnion(groupToSgbds[group] ?? [])
                }
                candidates = Array(set)
            }
        }

        let filtered = candidates.filter { modules.contains($0.uppercased()) }
        let effective = filtered.isEmpty ? candidates : filtered

        var seen = Set<String>()
        var targets: [RunTarget] = []
        for sgbd in effective.sorted() {
            let matches = actions(for: sgbd).filter { entry in
                guard entry.command == command else { return false }
                guard !normalizedGroups.isEmpty else { return true }
                return normalizedGroups.contains(entry.group.uppercased())
            }
            guard let entry = matches.first else { continue }
            let key = "\(sgbd)|\(entry.command)|\(entry.group)|\(entry.function)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            targets.append(
                RunTarget(
                    sgbd: sgbd,
                    entry: entry,
                    bundle: bundle(for: sgbd) ?? BundleDoc(
                        sgbd: sgbd.lowercased(),
                        addr: "",
                        jobs: [:],
                        fns: [],
                        enums: [:],
                        lights: nil
                    )
                )
            )
        }
        return targets
    }

    private func load() {
        guard let root = Self.dataRoot() else {
            loadError = "The bundled data folder was not found."
            return
        }
        let fileManager = FileManager.default
        let mappingDirectory = root.appendingPathComponent("mappings")
        let udsDirectory = root.appendingPathComponent("uds")
        let packDirectory = root.appendingPathComponent("packs")

        do {
            let files = try fileManager.contentsOfDirectory(
                at: mappingDirectory,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

            var loadedMappings: [String: [ActionMapEntry]] = [:]
            for file in files {
                let sgbd = file.deletingPathExtension().lastPathComponent.uppercased()
                let data = try Data(contentsOf: file)
                loadedMappings[sgbd] = try JSONDecoder().decode([ActionMapEntry].self, from: data)
            }
            mappings = loadedMappings
            sgbds = loadedMappings.keys.sorted()

            var loadedBundles: [String: BundleDoc] = [:]
            for sgbd in sgbds {
                let file = udsDirectory.appendingPathComponent("\(sgbd).uds.json")
                guard fileManager.fileExists(atPath: file.path) else { continue }
                let data = try Data(contentsOf: file)
                loadedBundles[sgbd] = try JSONDecoder().decode(BundleDoc.self, from: data)
            }
            bundles = loadedBundles

            var groups: [String: Set<String>] = [:]
            for (sgbd, entries) in loadedMappings {
                for entry in entries where !entry.group.isEmpty {
                    groups[entry.group.uppercased(), default: []].insert(sgbd)
                }
            }
            groupToSgbds = groups.mapValues { $0.sorted() }

            let packFiles = try fileManager.contentsOfDirectory(
                at: packDirectory,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            packs = try packFiles.map { file in
                let data = try Data(contentsOf: file)
                return try JSONDecoder().decode(PackDoc.self, from: data)
            }

            let moduleFile = root
                .appendingPathComponent("information")
                .appendingPathComponent("ecu_modules.json")
            if fileManager.fileExists(atPath: moduleFile.path) {
                let modules = try JSONDecoder().decode(
                    [EcuModule].self,
                    from: Data(contentsOf: moduleFile)
                )
                var lookup: [String: String] = [:]
                for module in modules {
                    lookup[module.sgbdHex.uppercased()] = module.sgbd
                }
                ecuModulesByHex = lookup
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    static func dataRoot() -> URL? {
        if let url = Bundle.main.url(forResource: "data", withExtension: nil) {
            return url
        }
        guard let resources = Bundle.main.resourceURL else { return nil }
        let candidate = resources.appendingPathComponent("data", isDirectory: true)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
