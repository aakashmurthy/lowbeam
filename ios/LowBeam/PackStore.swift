import Combine
import Foundation

final class PackStore: ObservableObject {
    @Published private(set) var sgbds: [String] = []
    @Published private(set) var loadError: String?

    private(set) var mappings: [String: [ActionMapEntry]] = [:]
    private(set) var bundles: [String: BundleDoc] = [:]

    init() {
        load()
    }

    func actions(for sgbd: String) -> [ActionMapEntry] {
        mappings[sgbd] ?? []
    }

    func bundle(for sgbd: String) -> BundleDoc? {
        bundles[sgbd.uppercased()]
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

    private func load() {
        guard let root = Self.dataRoot() else {
            loadError = "The bundled data folder was not found."
            return
        }
        let fileManager = FileManager.default
        let mappingDirectory = root.appendingPathComponent("mappings")
        let udsDirectory = root.appendingPathComponent("uds")

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
        } catch {
            loadError = error.localizedDescription
        }
    }

    private static func dataRoot() -> URL? {
        if let url = Bundle.main.url(forResource: "data", withExtension: nil) {
            return url
        }
        guard let resources = Bundle.main.resourceURL else { return nil }
        let candidate = resources.appendingPathComponent("data", isDirectory: true)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
