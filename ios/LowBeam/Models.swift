import Foundation

struct ActionMapEntry: Decodable, Identifiable {
    let sgbd: String
    let group: String
    let description: String
    let command: String
    let function: String
    let args: [String]

    var id: String { command + "|" + description }
}

struct BundleDoc: Decodable {
    let sgbd: String
    let addr: String
    let jobs: [String: String]
    let fns: [Fn]
    let enums: [String: [String: Int]]
    let lights: LightMap?

    var addressByte: UInt8 {
        // Bundle addresses are hexadecimal without a 0x prefix ("40", "D0").
        UInt8(addr, radix: 16) ?? UInt8(addr) ?? 0x40
    }

    func findFn(_ name: String, service: UInt8? = nil) -> Fn? {
        if let service {
            if let match = fns.first(where: { $0.n == name && $0.service == service }) {
                return match
            }
        }
        return fns.first(where: { $0.n == name })
    }
}

struct Fn: Decodable {
    let n: String
    let s: Int
    let id: String?
    let a: [ArgSpec]?

    var service: UInt8 { UInt8(truncatingIfNeeded: s) }
    var args: [ArgSpec] { a ?? [] }
    var ident: [UInt8] { Hex.bytes(id ?? "") ?? [] }
}

struct ArgSpec: Decodable {
    let name: String
    let width: Int
    let enumTable: String?
    let scale: [Double]?

    private struct ScaleSpec: Decodable {
        let e: String?
        let s: [Double]?
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        name = try container.decode(String.self)
        width = try container.decode(Int.self)

        var table: String?
        var scaling: [Double]?
        if !container.isAtEnd {
            if let text = try? container.decode(String.self) {
                table = text
            } else if let spec = try? container.decode(ScaleSpec.self) {
                table = spec.e
                scaling = spec.s
            }
        }
        enumTable = table
        scale = scaling
    }
}

struct LightMap: Decodable {
    let function: String
    let template: String
    let channels: [String: [LightBit]]
    let state: LightState?
    let fixed: [String: String]?

    var stateOn: [LightBit] { state?.on ?? [] }
    var stateOff: [LightBit] { state?.off ?? [] }
}

struct LightState: Decodable {
    let on: [LightBit]?
    let off: [LightBit]?
}

struct LightBit: Decodable {
    let offset: Int
    let mask: UInt8

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        offset = try container.decode(Int.self)
        let text = try container.decode(String.self)
        let digits = text.lowercased().hasPrefix("0x") ? String(text.dropFirst(2)) : text
        guard let value = UInt8(digits, radix: 16) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "invalid light mask \(text)"
            )
        }
        mask = value
    }
}

// MARK: - Built-in light show packs

struct PackDoc: Decodable, Identifiable {
    let title: String
    let description: String
    let sgbds: [String]
    let icon: String
    let group: Int
    let index: Int
    let columnCount: Int
    let fileName: String
    let flashable: Bool?
    let actions: [PackAction]

    var id: String { fileName }

    enum CodingKeys: String, CodingKey {
        case title, description, sgbds, icon, group, index
        case columnCount = "column_count"
        case fileName = "file_name"
        case flashable, actions
    }
}

struct PackAction: Decodable, Identifiable {
    let title: String
    let icon: String
    let color: String
    let align: String?
    let section: String?
    let repeatCount: Int?
    let sequence: [PackStep]
    let disable: [PackStep]

    var id: String { title + "|" + icon + "|" + (section ?? "") }

    enum CodingKeys: String, CodingKey {
        case title, icon, color, align, section, sequence, disable
        case repeatCount = "repeat_count"
    }
}

struct PackStep: Decodable {
    let command: String
    let group: [String]
    let params: [String: String]?
    let delayMs: Int?

    enum CodingKeys: String, CodingKey {
        case command, group, params
        case delayMs = "delay_ms"
    }
}

struct EcuModule: Decodable {
    let adrIndex: String
    let sgbdHex: String
    let sgbd: String
    let group: String
    let series: String

    enum CodingKeys: String, CodingKey {
        case adrIndex = "ADR_INDEX"
        case sgbdHex = "SGBD_HEX"
        case sgbd = "SGBD"
        case group = "GRUPPE"
        case series = "BAUREIHE"
    }
}

// MARK: - Vehicle + adapters

struct Vehicle: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var vin: String
    var chassis: String
    var series: String
    var modules: [String]
    var connectedAt: Date = Date()

    var moduleSummary: String {
        modules.count == 1 ? "1 module" : "\(modules.count) modules"
    }

    static let demo = Vehicle(
        name: "Demo F30",
        vin: "WBA3A5C50DF000001",
        chassis: "F30",
        series: "3' F30",
        modules: [
            "FEM_20", "REM_20", "KOMB01", "LCM",
            "FLE_L", "FLE_R", "LM_60", "LME38", "LSZ",
            "RLM2_1L", "RLM2_1R", "RLM2_2L", "RLM2_2R",
            "RLM_1L", "RLM_1R", "RLM_2L", "RLM_2R"
        ]
    )
}

enum AdapterKind: String, Codable, CaseIterable {
    case demo
    case enet
    case bluetooth

    var title: String {
        switch self {
        case .demo: return "Demo vehicle"
        case .enet: return "Wi-Fi / ENET"
        case .bluetooth: return "Bluetooth"
        }
    }
}

struct Adapter: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let kind: AdapterKind
    let recommended: Bool
}

enum AdapterCatalog {
    static let all: [Adapter] = [
        Adapter(
            id: "demo",
            name: "Demo vehicle",
            detail: "No hardware. Browse every module and test scripts offline.",
            symbol: "car.side.fill",
            kind: .demo,
            recommended: true
        ),
        Adapter(
            id: "enet",
            name: "ENET cable / Wi-Fi bridge",
            detail: "TCP connection to an ENET adapter or Wi-Fi bridge.",
            symbol: "cable.connector",
            kind: .enet,
            recommended: true
        ),
        Adapter(
            id: "unicarscan",
            name: "UniCarScan UCSI-3000 / 2100",
            detail: "Wi-Fi and Bluetooth. Use the ENET link for Wi-Fi.",
            symbol: "antenna.radiowaves.left.and.right",
            kind: .enet,
            recommended: true
        ),
        Adapter(
            id: "vlinker-wifi",
            name: "vLinker Wi-Fi",
            detail: "Connect over the adapter's Wi-Fi network.",
            symbol: "wifi",
            kind: .enet,
            recommended: true
        ),
        Adapter(
            id: "thor",
            name: "THOR",
            detail: "Wi-Fi adapter. Use the ENET link.",
            symbol: "wifi",
            kind: .enet,
            recommended: true
        ),
        Adapter(
            id: "obdlink",
            name: "OBDLink CX+ / MX+",
            detail: "Bluetooth adapter. Support is not included in this build.",
            symbol: "dot.radiowaves.left.and.right",
            kind: .bluetooth,
            recommended: false
        ),
        Adapter(
            id: "konnwei",
            name: "KONNWEI",
            detail: "Bluetooth adapter. Support is not included in this build.",
            symbol: "dot.radiowaves.left.and.right",
            kind: .bluetooth,
            recommended: false
        ),
        Adapter(
            id: "vlinker-bt",
            name: "vLinker Bluetooth",
            detail: "Bluetooth adapter. Support is not included in this build.",
            symbol: "dot.radiowaves.left.and.right",
            kind: .bluetooth,
            recommended: false
        ),
        Adapter(
            id: "vgate",
            name: "Vgate iCar",
            detail: "Bluetooth adapter. Support is not included in this build.",
            symbol: "dot.radiowaves.left.and.right",
            kind: .bluetooth,
            recommended: false
        ),
        Adapter(
            id: "veepeak",
            name: "Veepeak",
            detail: "Bluetooth adapter. Support is not included in this build.",
            symbol: "dot.radiowaves.left.and.right",
            kind: .bluetooth,
            recommended: false
        )
    ]

    static var recommended: [Adapter] { all.filter(\.recommended) }
    static var standard: [Adapter] { all.filter { !$0.recommended } }
}
