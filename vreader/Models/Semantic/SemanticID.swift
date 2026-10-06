// Purpose: RED compile-capable placeholder.
enum SemanticBlockRole: UInt8, Sendable, Codable, Hashable {
    case heading = 1, paragraph = 2, figure = 3, caption = 4
    case quote = 5, list = 6, listItem = 7, opaque = 8
}
struct SemanticID: Sendable, Codable, Hashable {
    let hex: String
    init(hex: String) throws { throw SemanticModelError.invalidDigest }
    private init(placeholder: Bool) { hex = String(repeating: "0", count: 64) }
    static func revision(_ revision: SemanticRevision) -> Self { Self(placeholder: true) }
    static func section(revision: SemanticRevision, resource: SemanticResourceIdentity,
                        spineOccurrence: Int) throws -> Self { throw SemanticModelError.invalidOccurrence }
    static func block(revision: SemanticRevision, anchor: SemanticLogicalAnchor,
                      role: SemanticBlockRole, ordinal: Int) throws -> Self { throw SemanticModelError.invalidOrdinal }
    static func canonicalRevisionBytes(_ revision: SemanticRevision) -> [UInt8] { [] }
    static func canonicalSectionBytes(revision: SemanticRevision, resource: SemanticResourceIdentity,
                                      spineOccurrence: Int) throws -> [UInt8] { throw SemanticModelError.invalidOccurrence }
    static func canonicalBlockBytes(revision: SemanticRevision, anchor: SemanticLogicalAnchor,
                                    role: SemanticBlockRole, ordinal: Int) throws -> [UInt8] { throw SemanticModelError.invalidOrdinal }
}
