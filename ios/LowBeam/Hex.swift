import Foundation

enum Hex {
    /// Accepts `"2F 01 00"`, `"2f0100"`, `"0x2F 0x01"`, and mixed case.
    static func bytes(_ text: String) -> [UInt8]? {
        let tokens = text.split(whereSeparator: { $0.isWhitespace || $0 == "_" })
        if tokens.isEmpty { return [] }
        var result: [UInt8] = []
        for token in tokens {
            var digits = String(token)
            if digits.lowercased().hasPrefix("0x") {
                digits = String(digits.dropFirst(2))
            }
            if digits.isEmpty { continue }
            if digits.count % 2 == 1 { digits = "0" + digits }
            var index = digits.startIndex
            while index < digits.endIndex {
                let end = digits.index(index, offsetBy: 2)
                guard let byte = UInt8(digits[index..<end], radix: 16) else {
                    return nil
                }
                result.append(byte)
                index = end
            }
        }
        return result
    }

    static func string(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
