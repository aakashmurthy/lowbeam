import Foundation

struct ScriptStep: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var command: String
    var group: [String] = []
    var params: [String: String]?
    var delayMs: Int?
    var sgbd: String?
    var function: String?
}

struct ScriptAction: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var icon: String
    var color: String
    var align: String?
    var section: String?
    var repeatCount: Int?
    var sequence: [ScriptStep]
    var disable: [ScriptStep]?
}

struct ScriptPack: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var description: String
    var icon: String
    var color: String
    var actions: [ScriptAction]
    var builtIn: Bool?
}

enum ScriptDefaults {
    static let placeholderPrefix = "param_"

    static func placeholderNames(in args: [String]) -> [String] {
        args.compactMap { argument in
            guard argument.hasPrefix("{"), argument.hasSuffix("}") else { return nil }
            return String(argument.dropFirst().dropLast())
        }
    }

    static func value(for name: String, on: Bool = true) -> String {
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

    static func params(for entry: ActionMapEntry) -> [String: String] {
        var result: [String: String] = [:]
        for name in placeholderNames(in: entry.args) {
            result[name] = value(for: name)
        }
        return result
    }

    static func step(from packStep: PackStep) -> ScriptStep {
        ScriptStep(
            command: packStep.command,
            group: packStep.group,
            params: packStep.params,
            delayMs: packStep.delayMs ?? 100,
            sgbd: nil,
            function: nil
        )
    }

    static func pack(from doc: PackDoc) -> ScriptPack {
        let actions = doc.actions.enumerated().map { index, action in
            ScriptAction(
                id: "builtin:\(doc.fileName):\(index)",
                title: action.title,
                icon: action.icon,
                color: action.color,
                align: action.align,
                section: action.section,
                repeatCount: action.repeatCount,
                sequence: action.sequence.map(step(from:)),
                disable: action.disable.map(step(from:))
            )
        }
        return ScriptPack(
            id: "builtin:\(doc.fileName)",
            title: doc.title,
            description: doc.description,
            icon: doc.icon,
            color: "systemBlue",
            actions: actions,
            builtIn: true
        )
    }
}

struct RunTarget {
    let sgbd: String
    let entry: ActionMapEntry
    let bundle: BundleDoc
}

extension ScriptAction {
    static func blank() -> ScriptAction {
        ScriptAction(
            title: "New action",
            icon: "lightbulb.led",
            color: "systemBlue",
            align: nil,
            section: nil,
            repeatCount: 1,
            sequence: [],
            disable: []
        )
    }
}

extension ScriptPack {
    static func blank() -> ScriptPack {
        ScriptPack(
            title: "",
            description: "",
            icon: "lightbulb.max.fill",
            color: "systemBlue",
            actions: [],
            builtIn: false
        )
    }
}
