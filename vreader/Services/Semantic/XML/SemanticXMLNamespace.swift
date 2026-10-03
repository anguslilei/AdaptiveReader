// Purpose: Foundation may accept namespace errors; validate own-tree qualified names explicitly.
import Foundation

enum SemanticXMLNamespace {
    static let xmlURI = "http://www.w3.org/XML/1998/namespace"
    static let xmlnsURI = "http://www.w3.org/2000/xmlns/"
    private struct AttributeKey: Hashable {
        let uri: String?
        let local: String
        static func == (lhs: Self, rhs: Self) -> Bool {
            SemanticXMLNamespace.literal(lhs.local, rhs.local) && SemanticXMLNamespace.optionalLiteral(lhs.uri, rhs.uri)
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(uri != nil)
            if let uri { hasher.combine(uri.utf8.count); for byte in uri.utf8 { hasher.combine(byte) } }
            hasher.combine(local.utf8.count); for byte in local.utf8 { hasher.combine(byte) }
        }
    }
    static func literal(_ a: String, _ b: String) -> Bool { a.utf8.elementsEqual(b.utf8) }
    private static func optionalLiteral(_ a: String?, _ b: String?) -> Bool {
        switch (a, b) {
        case (.none, .none): return true
        case let (.some(a), .some(b)): return literal(a, b)
        default: return false
        }
    }

    static func validateDeclaration(prefix: String, uri: String) throws {
        guard prefix != "xmlns", !prefix.contains(":"), uri != xmlnsURI else { throw SemanticXMLError.invalidXML }
        if prefix == "xml" {
            guard uri == xmlURI else { throw SemanticXMLError.invalidXML }
        } else {
            guard uri != xmlURI, prefix.isEmpty || !uri.isEmpty else { throw SemanticXMLError.invalidXML }
        }
    }

    static func validateElement(local: String, qualified: String, uri: String?,
                                attributes: [String: String], ancestors: [[String: String]]) throws {
        let parts = try name(qualified)
        let resolved = namespace(parts.prefix ?? "", attributes: attributes, ancestors: ancestors)
        guard parts.prefix != "xmlns", literal(local, parts.local), optionalLiteral(resolved, uri) else { throw SemanticXMLError.invalidXML }
        if parts.prefix != nil && resolved == nil { throw SemanticXMLError.invalidXML }
        var keys = Set<AttributeKey>()
        for key in attributes.keys {
            if key == "xmlns" || key.hasPrefix("xmlns:") { continue }
            let attribute = try name(key)
            let attributeURI: String?
            if let prefix = attribute.prefix {
                guard let value = namespace(prefix, attributes: attributes, ancestors: ancestors) else {
                    throw SemanticXMLError.invalidXML
                }
                attributeURI = value
            } else { attributeURI = nil } // Default namespaces never apply to attributes.
            guard keys.insert(AttributeKey(uri: attributeURI, local: attribute.local)).inserted else {
                throw SemanticXMLError.invalidXML
            }
        }
    }

    private static func name(_ qualified: String) throws -> (prefix: String?, local: String) {
        let parts = qualified.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), parts.allSatisfy({ !$0.isEmpty }) else { throw SemanticXMLError.invalidXML }
        return parts.count == 1 ? (nil, String(parts[0])) : (String(parts[0]), String(parts[1]))
    }
    private static func namespace(_ prefix: String, attributes: [String: String],
                                  ancestors: [[String: String]]) -> String? {
        if prefix == "xml" { return xmlURI }
        let key = prefix.isEmpty ? "xmlns" : "xmlns:" + prefix
        if let value = attributes.first(where: { literal($0.key, key) })?.value { return value.isEmpty ? nil : value }
        for parent in ancestors.reversed() {
            if let value = parent.first(where: { literal($0.key, key) })?.value { return value.isEmpty ? nil : value }
        }
        return nil
    }
}
