// Purpose: RED compile-capable placeholder; no existence/precision claim.
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
        throw SemanticModelError.invalidOccurrence
    }
}
