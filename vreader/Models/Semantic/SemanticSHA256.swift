// Purpose: RED compile-capable placeholder; replaced only after actual failing tests.
struct SemanticSHA256: Sendable, Codable, Hashable {
    let hex: String
    var bytes: [UInt8] { [] }
    init(hex: String) throws { throw SemanticModelError.invalidDigest }
}
