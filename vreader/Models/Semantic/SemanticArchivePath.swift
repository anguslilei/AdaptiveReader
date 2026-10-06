// Purpose: Already-resolved archive filename identity; never URL-decode/normalize.
struct SemanticArchivePath: Sendable, Codable, Hashable {
    let value: String

    init(_ value: String) throws {
        let utf8 = value.utf8
        guard (1...8192).contains(utf8.count),
              utf8.first != 47,
              !utf8.contains(where: { $0 < 32 || $0 == 127 || $0 == 58 || $0 == 92 }) else {
            throw SemanticModelError.invalidPath
        }
        // ASCII slash is a separator even when a combining scalar follows it.
        let parts = Array(utf8).split(separator: 47, omittingEmptySubsequences: false)
        guard parts.allSatisfy({ !$0.isEmpty && !$0.elementsEqual([46]) && !$0.elementsEqual([46, 46]) }) else {
            throw SemanticModelError.invalidPath
        }
        self.value = value
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.value.utf8.elementsEqual(rhs.value.utf8)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value.utf8.count)
        for byte in value.utf8 { hasher.combine(byte) }
    }

    init(from decoder: any Decoder) throws {
        try self.init(decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
