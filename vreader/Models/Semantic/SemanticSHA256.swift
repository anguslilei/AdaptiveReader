// Purpose: Validated lowercase SHA256 spelling and raw-byte payload.
import CryptoKit
import Foundation

struct SemanticSHA256: Sendable, Codable, Hashable {
    let hex: String

    init(hex: String) throws {
        let bytes = hex.utf8
        guard bytes.count == 64,
              bytes.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw SemanticModelError.invalidDigest
        }
        self.hex = hex
    }

    var bytes: [UInt8] {
        let ascii = Array(hex.utf8)
        func nibble(_ byte: UInt8) -> UInt8 { byte <= 57 ? byte - 48 : byte - 87 }
        return stride(from: 0, to: 64, by: 2).map { nibble(ascii[$0]) * 16 + nibble(ascii[$0 + 1]) }
    }

    // Only a platform-typed digest can bypass parsing a supplied String.
    private init(digest: SHA256.Digest) {
        hex = digest.map { String(format: "%02x", $0) }.joined()
    }

    static func hash(_ bytes: [UInt8]) -> Self {
        Self(digest: SHA256.hash(data: Data(bytes)))
    }

    init(from decoder: any Decoder) throws {
        try self.init(hex: decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}
