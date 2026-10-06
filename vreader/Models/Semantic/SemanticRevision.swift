// Purpose: RED compile-capable placeholder.
struct SemanticRevision: Sendable, Codable, Hashable {
    let archiveSHA256: SemanticSHA256
    let extractorVersion: Int
    let schemaVersion: Int
    init(archiveSHA256: SemanticSHA256, extractorVersion: Int, schemaVersion: Int = 1) throws {
        throw SemanticModelError.invalidVersion
    }
}
