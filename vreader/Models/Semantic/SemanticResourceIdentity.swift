// Purpose: An already-resolved original archive resource, not a URL.
struct SemanticResourceIdentity: Sendable, Codable, Hashable {
    let path: SemanticArchivePath
    let sha256: SemanticSHA256
    init(path: SemanticArchivePath, sha256: SemanticSHA256) {
        self.path = path
        self.sha256 = sha256
    }
}
