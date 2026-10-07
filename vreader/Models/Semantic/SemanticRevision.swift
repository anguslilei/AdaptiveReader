// Purpose: Bind a semantic extraction policy version to exact original archive bytes.
struct SemanticRevision: Sendable, Codable, Hashable {
    let archiveSHA256: SemanticSHA256
    let extractorVersion: Int
    let schemaVersion: Int

    init(archiveSHA256: SemanticSHA256, extractorVersion: Int, schemaVersion: Int = 1) throws {
        guard schemaVersion == 1 else { throw SemanticModelError.unsupportedSchema }
        guard extractorVersion >= 1, extractorVersion <= Int(UInt32.max) else {
            throw SemanticModelError.invalidVersion
        }
        self.archiveSHA256 = archiveSHA256
        self.extractorVersion = extractorVersion
        self.schemaVersion = schemaVersion
    }

    private enum CodingKeys: String, CodingKey {
        case archiveSHA256, extractorVersion, schemaVersion
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(archiveSHA256: container.decode(SemanticSHA256.self, forKey: .archiveSHA256),
                      extractorVersion: container.decode(Int.self, forKey: .extractorVersion),
                      schemaVersion: container.decode(Int.self, forKey: .schemaVersion))
    }
}
