// Purpose: Immediate expanded names, bounded literal lookup and retained DTO accounting.
import Foundation

enum EPUBPackageXMLAccess {
    static let containerNS = "urn:oasis:names:tc:opendocument:xmlns:container"
    static let opfNS = "http://www.idpf.org/2007/opf"
    static func matches(_ node: SemanticXMLNode, _ name: String, _ namespace: String) -> Bool {
        guard case .element(let n) = node.kind, let uri = n.namespaceURI else { return false }
        return n.localName.utf8.elementsEqual(name.utf8) && uri.utf8.elementsEqual(namespace.utf8)
    }
    static func elements(_ document: SemanticXMLDocument, at index: Int) -> [Int] {
        document.nodes[index].children.filter { if case .element = document.nodes[$0].kind { return true }; return false }
    }
    static func attribute(_ node: SemanticXMLNode, _ name: String) -> String? {
        node.attributes.first(where: { $0.key.utf8.elementsEqual(name.utf8) })?.value
    }
    static func required(_ node: SemanticXMLNode, _ name: String,
                         error: EPUBSemanticPackageError) throws -> String {
        guard let value = attribute(node, name), !value.isEmpty else { throw error }
        return value
    }
    static func preflight(_ document: SemanticXMLDocument) throws {
        for node in document.nodes {
            try Task.checkCancellation()
            if attribute(node, "xml:base") != nil { throw EPUBSemanticPackageError.unsupportedPackage }
            if case .element(let name) = node.kind,
               name.namespaceURI?.utf8.elementsEqual("http://www.w3.org/2001/XInclude".utf8) == true {
                throw EPUBSemanticPackageError.unsupportedPackage
            }
        }
    }
    static func files(_ catalog: EPUBSemanticResourceCatalog,
                      limits: EPUBSemanticPackageLimits) throws -> Set<EPUBPackageLiteralKey> {
        var units = 0
        // Validate the independent payload ceiling BEFORE allocating the lookup map.
        for path in catalog.paths {
            try Task.checkCancellation()
            guard path.utf16.count <= limits.catalogUTF16 - units else { throw EPUBSemanticPackageError.metadataLimit }
            units += path.utf16.count
        }
        var result = Set<EPUBPackageLiteralKey>()
        for path in catalog.paths {
            try Task.checkCancellation()
            try EPUBSourceZIPBytes.validatePath(path)
            guard !path.hasSuffix("/"), result.insert(.init(path)).inserted else {
                throw EPUBSemanticPackageError.inconsistentSource
            }
        }
        return result
    }
    static func whitespace(_ c: Character) -> Bool { c == " " || c == "\t" || c == "\n" || c == "\r" }
    static func token(_ value: String, error: EPUBSemanticPackageError) throws {
        guard !value.isEmpty, !value.utf8.contains(where: { $0 <= 32 || $0 == 127 }) else { throw error }
    }
    static func properties(_ node: SemanticXMLNode, limits: EPUBSemanticPackageLimits,
                           budget: inout EPUBPackageBudget) throws -> [String] {
        guard let raw = attribute(node, "properties") else { return [] }
        let parts = raw.split(maxSplits: limits.propertiesPerItem, whereSeparator: whitespace)
        guard parts.count <= limits.propertiesPerItem else { throw EPUBSemanticPackageError.metadataLimit }
        var seen = Set<EPUBPackageLiteralKey>(), result = [String]()
        for part in parts {
            try Task.checkCancellation()
            let value = String(part)
            try token(value, error: .invalidPackage)
            guard seen.insert(.init(value)).inserted else { throw EPUBSemanticPackageError.invalidPackage }
            try budget.charge(value); result.append(value)
        }
        return result
    }
    static func validMediaType(_ value: String) -> Bool {
        let parts = value.utf8.split(separator: 47, omittingEmptySubsequences: false)
        let punctuation = Array("!#$%&'*+-.^_`|~".utf8)
        return parts.count == 2 && parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || punctuation.contains($0) }
        }
    }
    static func stage(_ stage: EPUBPackageStage, observation: EPUBPackageLoadObservation?) throws {
        try Task.checkCancellation(); observation?.beforeStage(stage); try Task.checkCancellation()
    }
}

struct EPUBPackageBudget {
    private let ceiling: Int
    private var used = 0
    init(_ ceiling: Int) { self.ceiling = ceiling }
    mutating func charge(_ value: String) throws {
        let size = value.utf16.count
        guard size <= ceiling - used else { throw EPUBSemanticPackageError.metadataLimit }
        used += size
    }
}
