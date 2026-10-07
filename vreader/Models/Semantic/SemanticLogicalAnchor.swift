// Purpose: Logical syntax only; a future resolver must establish existence/provenance.
enum SemanticAnchorCoordinateSystem: String, Sendable, Codable, Hashable {
    case semanticXMLTreeV1
}

struct SemanticLogicalAnchor: Sendable, Codable, Hashable {
    let resource: SemanticResourceIdentity
    let spineOccurrence: Int
    let nodePath: SemanticNodePath
    let textRange: SemanticUTF16Range?

    var coordinateSystem: SemanticAnchorCoordinateSystem { .semanticXMLTreeV1 }

    init(resource: SemanticResourceIdentity, spineOccurrence: Int,
         nodePath: SemanticNodePath, textRange: SemanticUTF16Range? = nil) throws {
        guard (0...4095).contains(spineOccurrence) else { throw SemanticModelError.invalidOccurrence }
        self.resource = resource
        self.spineOccurrence = spineOccurrence
        self.nodePath = nodePath
        self.textRange = textRange
    }

    private enum CodingKeys: String, CodingKey {
        case resource, spineOccurrence, nodePath, textRange
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(resource: container.decode(SemanticResourceIdentity.self, forKey: .resource),
                      spineOccurrence: container.decode(Int.self, forKey: .spineOccurrence),
                      nodePath: container.decode(SemanticNodePath.self, forKey: .nodePath),
                      textRange: container.decodeIfPresent(SemanticUTF16Range.self, forKey: .textRange))
    }
}
