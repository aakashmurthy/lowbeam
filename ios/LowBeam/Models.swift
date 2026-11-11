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
