import Foundation

struct EncodeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }

    init(_ message: String) {
        self.message = message
    }
}

/// Swift port of `lowbeam/encode.py` and `lowbeam/uds.py`.
enum Encoder {
    static let routineSubfn: [String: UInt8] = ["STR": 0x01, "STPR": 0x02, "RRR": 0x03]
    static let ioControl: [String: UInt8] = ["RCTECU": 0x00, "RTD": 0x01, "FCS": 0x02, "STA": 0x03]
    static let diagSession: [String: UInt8] = [
        "DEFAULT": 0x01,
        "ECUPM": 0x02,
        "ECUEXTDIAG": 0x03,
        "ECUSSDS": 0x04,
        "ECUADS": 0x05,
        "SUPPLIER": 0x60,
    ]
    static let truthy: Set<String> = ["1", "on", "ein", "true", "yes", "an"]

    static func encode(
        bundle: BundleDoc,
        function: String,
        args: [String] = [],
        params: [String: String] = [:]
    ) throws -> [UInt8] {
        let values = try args.map { try substitute($0, params: params) }

        if let special = try special(bundle: bundle, function: function, args: values) {
            return special
        }

        if let lights = bundle.lights, function == lights.function {
            guard let template = Hex.bytes(lights.template) else {
                throw EncodeError("invalid light template for \(bundle.sgbd)")
            }
            if values.isEmpty {
                var frame = template
                for bit in lights.stateOff {
                    guard bit.offset < frame.count else {
                        throw EncodeError("state offset \(bit.offset) outside template")
                    }
                    frame[bit.offset] |= bit.mask
                }
                return frame
            }
            let channel = values[0]
            guard lights.channels[channel] != nil else {
                throw EncodeError("\(bundle.sgbd) has no light channel \(channel)")
            }
            let on = values.count > 1 ? isTruthy(values[1]) : true
            return try lightFrame(lights, channel: channel, on: on)
        }

        guard let job = bundle.jobs[function] else {
            guard let fn = bundle.findFn(function) else {
                throw EncodeError("unknown function \(function) for \(bundle.sgbd)")
            }
            let base = [fn.service] + fn.ident
            let body = try encodeArgs(values, fn.args, bundle: bundle)
            return replaceTail(base, body)
        }

        guard let base = Hex.bytes(job) else {
            throw EncodeError("invalid job base for \(function)")
        }

        if values.first == "ARG" {
            guard values.count >= 2 else {
                throw EncodeError("ARG dispatch without a function name")
            }
            let target = values[1]
            guard let fn = bundle.findFn(target, service: base.first) else {
                throw EncodeError("unknown ARG target \(target) for \(bundle.sgbd)")
            }
            var rest = Array(values.dropFirst(2))
            var prefix = base

            if base.first == 0x31 {
                guard let sub = rest.first else {
                    throw EncodeError("STEUERN_ROUTINE needs a routine subfunction")
                }
                let subfn: UInt8
                if let named = routineSubfn[sub] {
                    subfn = named
                } else {
                    subfn = UInt8(try integer(sub))
                }
                rest = Array(rest.dropFirst())
                prefix = [base[0], subfn] + fn.ident
                if rest.isEmpty { return prefix }
            } else if base.first == 0x2F {
                guard let control = rest.first else {
                    throw EncodeError("STEUERN_IO needs an IO control parameter")
                }
                let io: UInt8
                if let named = ioControl[control] {
                    io = named
                } else {
                    io = UInt8(try integer(control))
                }
                rest = Array(rest.dropFirst())
                prefix = base + fn.ident + [io]
                if rest.isEmpty { return prefix }
            } else if !fn.ident.isEmpty {
                prefix += fn.ident
            }

            let body = try encodeArgs(rest, fn.args, bundle: bundle)
            return replaceTail(prefix, body)
        }

        if let fn = bundle.findFn(function, service: base.first) {
            var prefix = base
            if !fn.ident.isEmpty && base.count <= 1 {
                prefix += fn.ident
            }
            let body = try encodeArgs(values, fn.args, bundle: bundle)
            return replaceTail(prefix, body)
        }

        let body = try values.flatMap { try rawBytes($0, bundle: bundle) }
        return replaceTail(base, body)
    }

    static func lightFrame(_ lights: LightMap, channel: String, on: Bool) throws -> [UInt8] {
        guard let bits = lights.channels[channel] else {
            throw EncodeError("unknown light channel \(channel)")
        }
        guard var frame = Hex.bytes(lights.template) else {
            throw EncodeError("invalid light template")
        }
        for bit in bits {
            guard bit.offset < frame.count else {
                throw EncodeError("channel \(channel) offset \(bit.offset) outside template")
            }
            frame[bit.offset] |= bit.mask
        }
        for bit in (on ? lights.stateOn : lights.stateOff) {
            guard bit.offset < frame.count else {
                throw EncodeError("state offset \(bit.offset) outside template")
            }
            frame[bit.offset] |= bit.mask
        }
        return frame
    }

    static func frame(payload: [UInt8], dest: UInt8 = 0x40, source: UInt8 = 0xF1) throws -> [UInt8] {
        guard payload.count < 0x80 else {
            throw EncodeError("payload too long for an Ediabas frame")
        }
        var frame = [UInt8(0x80 | payload.count), dest, source] + payload
        let checksum = frame.reduce(0) { ($0 + Int($1)) & 0xFF }
        frame.append(UInt8(checksum))
        return frame
    }

    static func hex(_ bytes: [UInt8]) -> String { Hex.string(bytes) }

    // MARK: - Argument handling

    private static func substitute(_ value: String, params: [String: String]) throws -> String {
        guard value.hasPrefix("{"), value.hasSuffix("}") else { return value }
        let name = String(value.dropFirst().dropLast())
        guard let resolved = params[name] else {
            throw EncodeError("missing parameter \(name)")
        }
        return resolved
    }

    private static func isTruthy(_ value: String) -> Bool {
        truthy.contains(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static func integer(_ value: String, enumTable: [String: Int]? = nil) throws -> Int {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let enumTable = enumTable, let number = enumTable[text] { return number }
        switch text.lowercased() {
        case "ein", "on", "an", "true": return 1
        case "aus", "off", "false": return 0
        default: break
        }
        if text.lowercased().hasPrefix("0x"),
           let number = Int(text.dropFirst(2), radix: 16) {
            return number
        }
        if let number = Int(text) { return number }
        throw EncodeError("cannot convert \(value) to an integer")
    }

    private static func encodeValue(_ value: String, spec: ArgSpec, bundle: BundleDoc) throws -> [UInt8] {
        let table = spec.enumTable.flatMap { bundle.enums[$0] }
        let number = try integer(value, enumTable: table)
        if number < 0 {
            throw EncodeError("\(spec.name) is negative")
        }
        if spec.width <= 8 {
            if spec.width < 8 && number >= (1 << (8 * spec.width)) {
                throw EncodeError("\(spec.name)=\(number) does not fit in \(spec.width) byte(s)")
            }
            return bigEndian(number, width: spec.width)
        }
        if number == 0 {
            return [UInt8](repeating: 0, count: spec.width)
        }
        return bigEndian(number, width: spec.width)
    }

    private static func bigEndian(_ number: Int, width: Int) -> [UInt8] {
        var output = [UInt8](repeating: 0, count: width)
        let value = UInt64(number)
        let count = min(width, 8)
        for index in 0..<count {
            output[width - 1 - index] = UInt8((value >> (8 * index)) & 0xFF)
        }
        return output
    }

    private static func encodeArgs(
        _ values: [String],
        _ specs: [ArgSpec],
        bundle: BundleDoc
    ) throws -> [UInt8] {
        if let first = values.first, specs.contains(where: { $0.name == first }) {
            let byName = Dictionary(uniqueKeysWithValues: specs.map { ($0.name, $0) })
            var positions: [String: Int] = [:]
            var offset = 0
            for spec in specs {
                positions[spec.name] = offset
                offset += spec.width
            }
            var body = [UInt8](repeating: 0, count: offset)
            var index = 0
            while index + 1 < values.count {
                let name = values[index]
                guard let spec = byName[name] else {
                    throw EncodeError("unknown argument \(name)")
                }
                let encoded = try encodeValue(values[index + 1], spec: spec, bundle: bundle)
                let start = positions[name]!
                body.replaceSubrange(start..<(start + spec.width), with: encoded)
                index += 2
            }
            return body
        }

        guard values.count == specs.count else {
            throw EncodeError("expected \(specs.count) argument(s), got \(values.count)")
        }
        return try zip(values, specs).flatMap { pair in
            try encodeValue(pair.0, spec: pair.1, bundle: bundle)
        }
    }

    private static func rawBytes(_ value: String, bundle: BundleDoc) throws -> [UInt8] {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = text.lowercased()
        if ["ein", "on", "an", "true"].contains(lowered) { return [0x01] }
        if ["aus", "off", "false"].contains(lowered) { return [0x00] }
        for table in bundle.enums.values {
            if let byte = table[text] { return [UInt8(truncatingIfNeeded: byte)] }
        }
        var digits = lowered.hasPrefix("0x") ? String(text.dropFirst(2)) : text
        if !digits.isEmpty, digits.allSatisfy({ "0123456789abcdefABCDEF".contains($0) }) {
            if digits.count % 2 == 1 { digits = "0" + digits }
            if let bytes = Hex.bytes(digits) { return bytes }
        }
        throw EncodeError("cannot encode raw argument \(value)")
    }

    private static func replaceTail(_ base: [UInt8], _ body: [UInt8]) -> [UInt8] {
        if !body.isEmpty, base.count >= body.count,
           base.suffix(body.count).allSatisfy({ $0 == 0 }) {
            return Array(base.prefix(base.count - body.count)) + body
        }
        return base + body
    }

    private static func special(
        bundle: BundleDoc,
        function: String,
        args: [String]
    ) throws -> [UInt8]? {
        if function == "DIAGNOSE_MODE" {
            let first = args.first ?? "DEFAULT"
            let session: UInt8
            if let named = diagSession[first] {
                session = named
            } else {
                session = UInt8(try integer(first))
            }
            return [0x10, session]
        }
        if function == "DIAGNOSE_AUFRECHT" {
            if let job = bundle.jobs["DIAGNOSE_AUFRECHT"], let bytes = Hex.bytes(job) {
                return bytes
            }
            return [0x3E, 0x01]
        }
        if function == "DIAGNOSE_ENDE" {
            if let lights = bundle.lights,
               let fixed = lights.fixed?["DIAGNOSE_ENDE"],
               let bytes = Hex.bytes(fixed) {
                return bytes
            }
            if let job = bundle.jobs["DIAGNOSE_ENDE"], let bytes = Hex.bytes(job) {
                return bytes
            }
            return [0x10, 0x01]
        }
        if function == "COMMUNICATION_CONTROL" {
            return [0x28] + (try args.flatMap { try rawBytes($0, bundle: bundle) })
        }
        if function == "IO_RETURN_CONTROL" {
            return [0x2F] + (try args.flatMap { try rawBytes($0, bundle: bundle) })
        }
        if function == "RAW_UDS" {
            return try args.flatMap { try rawBytes($0, bundle: bundle) }
        }
        return nil
    }
}
