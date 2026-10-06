// Purpose: Deterministic application-defined v1 IDs from explicit typed source bytes.
enum SemanticBlockRole: UInt8, Sendable, Codable, Hashable {
    case heading = 1, paragraph = 2, figure = 3, caption = 4
    case quote = 5, list = 6, listItem = 7, opaque = 8
}

struct SemanticID: Sendable, Codable, Hashable {
    private let digest: SemanticSHA256
    var hex: String { digest.hex }

    init(hex: String) throws { digest = try SemanticSHA256(hex: hex) }
    private init(bytes: [UInt8]) { digest = SemanticSHA256.hash(bytes) }

    static func revision(_ revision: SemanticRevision) -> Self {
        Self(bytes: canonicalRevisionBytes(revision))
    }

    static func section(revision: SemanticRevision, resource: SemanticResourceIdentity,
                        spineOccurrence: Int) throws -> Self {
        Self(bytes: try canonicalSectionBytes(revision: revision, resource: resource,
                                             spineOccurrence: spineOccurrence))
    }

    static func block(revision: SemanticRevision, anchor: SemanticLogicalAnchor,
                      role: SemanticBlockRole, ordinal: Int) throws -> Self {
        Self(bytes: try canonicalBlockBytes(revision: revision, anchor: anchor, role: role, ordinal: ordinal))
    }

    // Internal canonical-byte entry points are shared by factories and vector tests.
    static func canonicalRevisionBytes(_ revision: SemanticRevision) -> [UInt8] {
        common(revision, kind: 1)
    }

    static func canonicalSectionBytes(revision: SemanticRevision, resource: SemanticResourceIdentity,
                                      spineOccurrence: Int) throws -> [UInt8] {
        guard (0...4095).contains(spineOccurrence) else { throw SemanticModelError.invalidOccurrence }
        return common(revision, kind: 2) + source(resource, occurrence: spineOccurrence)
    }

    static func canonicalBlockBytes(revision: SemanticRevision, anchor: SemanticLogicalAnchor,
                                    role: SemanticBlockRole, ordinal: Int) throws -> [UInt8] {
        guard ordinal >= 0, ordinal <= Int(UInt32.max) else { throw SemanticModelError.invalidOrdinal }
        var bytes = common(revision, kind: 3) + source(anchor.resource, occurrence: anchor.spineOccurrence)
        bytes += u32(anchor.nodePath.components.count)
        for slot in anchor.nodePath.components { bytes += u32(slot) }
        if let range = anchor.textRange {
            bytes += [1] + u32(range.lowerBound) + u32(range.upperBound)
        } else {
            bytes.append(0)
        }
        bytes.append(role.rawValue)
        bytes += u32(ordinal)
        return bytes
    }

    private static func common(_ revision: SemanticRevision, kind: UInt8) -> [UInt8] {
        Array("vreader.semantic-id.v1".utf8) + [0, kind] + revision.archiveSHA256.bytes +
            u32(revision.schemaVersion) + u32(revision.extractorVersion)
    }

    private static func source(_ resource: SemanticResourceIdentity, occurrence: Int) -> [UInt8] {
        let path = Array(resource.path.value.utf8)
        return u32(path.count) + path + resource.sha256.bytes + u32(occurrence)
    }

    // Every caller's type/guard above bounds values before this conversion.
    private static func u32(_ value: Int) -> [UInt8] {
        let number = UInt32(value)
        return [UInt8(truncatingIfNeeded: number >> 24), UInt8(truncatingIfNeeded: number >> 16),
                UInt8(truncatingIfNeeded: number >> 8), UInt8(truncatingIfNeeded: number)]
    }

    init(from decoder: any Decoder) throws {
        try self.init(hex: decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}
