import Foundation

@MainActor
final class ScriptStore: ObservableObject {
    @Published private(set) var builtIns: [ScriptPack] = []
    @Published private(set) var custom: [ScriptPack] = []
    @Published private(set) var loadError: String?

    private let storageURL: URL?

    init() {
        storageURL = Self.storageURL()
        loadBuiltIns()
        loadCustom()
    }

    var all: [ScriptPack] { builtIns + custom }

    func pack(id: String) -> ScriptPack? {
        all.first(where: { $0.id == id })
    }

    func save(_ pack: ScriptPack) {
        var copy = pack
        copy.builtIn = false
        if let index = custom.firstIndex(where: { $0.id == copy.id }) {
            custom[index] = copy
        } else {
            custom.append(copy)
        }
        persist()
    }

    func delete(_ pack: ScriptPack) {
        custom.removeAll(where: { $0.id == pack.id })
        persist()
    }

    func duplicate(_ pack: ScriptPack) -> ScriptPack {
        var copy = pack
        copy.id = UUID().uuidString
        copy.title = pack.title + " Copy"
        copy.builtIn = false
        copy.actions = pack.actions.map { action in
            var newAction = action
            newAction.id = UUID().uuidString
            newAction.sequence = action.sequence.map { step in
                var newStep = step
                newStep.id = UUID().uuidString
                return newStep
            }
            newAction.disable = action.disable?.map { step in
                var newStep = step
                newStep.id = UUID().uuidString
                return newStep
            }
            return newAction
        }
        custom.append(copy)
        persist()
        return copy
    }

    func clearCustom() {
        custom = []
        persist()
    }

    func importPack(from url: URL) throws -> ScriptPack {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        let encoded = try Data(contentsOf: url)
        let plaintext: Data
        if looksLikeJSON(encoded) {
            plaintext = encoded
        } else {
            plaintext = try PackCrypto.decrypt(encoded)
        }

        let decoder = JSONDecoder()
        var pack: ScriptPack
        if let decoded = try? decoder.decode(ScriptPack.self, from: plaintext) {
            pack = decoded
        } else {
            let doc = try decoder.decode(PackDoc.self, from: plaintext)
            pack = ScriptDefaults.pack(from: doc)
        }

        pack.id = UUID().uuidString
        pack.builtIn = false
        pack.actions = pack.actions.map { action in
            var newAction = action
            newAction.id = UUID().uuidString
            return newAction
        }
        custom.append(pack)
        persist()
        return pack
    }

    func exportURL(for pack: ScriptPack) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let plaintext = try encoder.encode(pack)
        let encrypted = try PackCrypto.encrypt(plaintext)

        let name = Self.safeFileName(pack.title)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LowBeamExports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).bimmerlight")
        try encrypted.write(to: url, options: .atomic)
        return url
    }

    private func loadBuiltIns() {
        guard let root = PackStore.dataRoot() else {
            loadError = "The bundled data folder was not found."
            return
        }
        let directory = root.appendingPathComponent("packs", isDirectory: true)
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
            .filter { $0.pathExtension == "json" }
            let docs = try files.map { file -> PackDoc in
                let data = try Data(contentsOf: file)
                return try JSONDecoder().decode(PackDoc.self, from: data)
            }
            .sorted { $0.index < $1.index }
            builtIns = docs.map(ScriptDefaults.pack)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func loadCustom() {
        guard let storageURL, FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: storageURL)
            custom = try JSONDecoder().decode([ScriptPack].self, from: data)
        } catch {
            loadError = "Could not load your scripts: \(error.localizedDescription)"
        }
    }

    private func persist() {
        guard let storageURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(custom)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            loadError = "Could not save your scripts: \(error.localizedDescription)"
        }
    }

    private func looksLikeJSON(_ data: Data) -> Bool {
        guard let index = data.firstIndex(where: { !$0.isWhitespace }) else { return false }
        let first = data[index]
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }

    private static func storageURL() -> URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let directory = base.appendingPathComponent("LowBeam", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory.appendingPathComponent("scripts.json")
        } catch {
            return nil
        }
    }

    private static func safeFileName(_ title: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let cleaned = title.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let name = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "LowBeam Script" : name
    }
}
