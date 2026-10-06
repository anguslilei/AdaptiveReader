// Purpose: RED compile-capable placeholder.
struct SemanticArchivePath: Sendable, Codable, Hashable {
    let value: String
    init(_ value: String) throws { throw SemanticModelError.invalidPath }
}
