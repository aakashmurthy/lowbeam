import CryptoKit
import Foundation

/// BimmerLight pack encryption recovered from EdiabasKit 3.9:
/// AES-256-GCM with a hard-coded ASCII key, stored as
/// base64(nonce12 || tag16 || ciphertext).
enum PackCrypto {
    static let key = SymmetricKey(data: Data("D8645993BA8BE1550000000764876174".utf8))

    static func encrypt(_ plaintext: Data) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key)
        var combined = Data(sealed.nonce)
        combined.append(sealed.tag)
        combined.append(sealed.ciphertext)
        return combined.base64EncodedData()
    }

    static func decrypt(_ encoded: Data) throws -> Data {
        guard let raw = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters) else {
            throw PackCryptoError.invalidBase64
        }
        guard raw.count >= 28 else {
            throw PackCryptoError.truncated
        }
        let nonce = try AES.GCM.Nonce(data: raw.prefix(12))
        let tag = raw[12..<28]
        let ciphertext = raw.dropFirst(28)
        let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(box, using: key)
    }
}

enum PackCryptoError: LocalizedError {
    case invalidBase64
    case truncated

    var errorDescription: String? {
        switch self {
        case .invalidBase64: return "The file is not valid base64."
        case .truncated: return "The encrypted file is too short."
        }
    }
}
