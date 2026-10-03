// Purpose: One-worker Foundation delegate; bounded drafts become immutable logical nodes.
import Foundation

final class SemanticXMLBuilder: NSObject, XMLParserDelegate {
    private struct Draft {
        let kind: SemanticXMLNodeKind
        let attributes: [String: String]
        let parent: Int?
        var children: [Int] = []
        var text = ""
    }
    private let startTags: [SemanticXMLStartTag]
    private var tagIndex = 0
    private let limits: SemanticXMLLimits
    private let check: @Sendable () throws -> Void
    private var drafts: [Draft] = []
    private var stack: [Int] = []
    private var pendingNamespaces: [String: String] = [:]
    private var units = 0
    private var root: Int?
    private(set) var failure: (any Error)?

    init(limits: SemanticXMLLimits, startTags: [SemanticXMLStartTag], check: @escaping @Sendable () throws -> Void) {
        self.limits = limits; self.startTags = startTags; self.check = check
    }

    func finish(digest: String) throws -> SemanticXMLDocument {
        if let failure { throw failure }
        try check()
        guard let root, stack.isEmpty, pendingNamespaces.isEmpty, tagIndex == startTags.count else { throw SemanticXMLError.invalidXML }
        let nodes = drafts.map { draft in
            let kind: SemanticXMLNodeKind
            if case .text = draft.kind { kind = .text(draft.text) } else { kind = draft.kind }
            return SemanticXMLNode(kind: kind, attributes: draft.attributes, parent: draft.parent, children: draft.children)
        }
        try check()
        return SemanticXMLDocument(rootIndex: root, nodes: nodes, sourceSHA256: digest)
    }

    private func event(_ parser: XMLParser, _ action: () throws -> Void) {
        guard failure == nil else { return }
        do { try check(); try action(); try check() }
        catch { stop(error, parser) }
    }
    private func stop(_ error: any Error, _ parser: XMLParser) {
        guard failure == nil else { return }
        failure = error; parser.abortParsing()
    }
    private func charge(_ strings: [String]) throws {
        for string in strings {
            let count = string.utf16.count
            guard count <= limits.textUTF16 - units else { throw SemanticXMLError.textLimit }
            units += count
        }
    }
    @discardableResult
    private func append(_ kind: SemanticXMLNodeKind, attributes: [String: String] = [:]) throws -> Int {
        guard drafts.count < limits.nodes else { throw SemanticXMLError.nodeLimit }
        let index = drafts.count
        let parent = stack.last
        drafts.append(Draft(kind: kind, attributes: attributes, parent: parent))
        if let parent { drafts[parent].children.append(index) }
        return index
    }

    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) {
        event(parser) {
            try SemanticXMLNamespace.validateDeclaration(prefix: prefix, uri: namespaceURI)
            let key = prefix.isEmpty ? "xmlns" : "xmlns:" + prefix
            guard pendingNamespaces[key] == nil else { throw SemanticXMLError.invalidXML }
            guard pendingNamespaces.count < limits.attributes else { throw SemanticXMLError.attributeLimit }
            try charge([key, namespaceURI]); pendingNamespaces[key] = namespaceURI
        }
    }
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) { event(parser) {} }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        event(parser) {
            guard stack.count < limits.depth else { throw SemanticXMLError.depthLimit }
            if stack.isEmpty && root != nil { throw SemanticXMLError.invalidXML }
            var attributes = pendingNamespaces
            for (key, value) in attributeDict {
                if let previous = attributes[key] {
                    guard SemanticXMLNamespace.literal(previous, value) else { throw SemanticXMLError.invalidXML }
                } else {
                    guard attributes.count < limits.attributes else { throw SemanticXMLError.attributeLimit }
                    try charge([key, value]); attributes[key] = value
                }
            }
            let uri = namespaceURI.flatMap { $0.isEmpty ? nil : $0 }
            let qualified = qName ?? elementName
            guard tagIndex < startTags.count else { throw SemanticXMLError.invalidXML }
            let original = startTags[tagIndex]
            guard SemanticXMLNamespace.literal(qualified, original.qualifiedName),
                  attributes.count == original.attributes.count,
                  original.attributes.allSatisfy({ key in attributes.keys.contains { SemanticXMLNamespace.literal(key, $0) } }) else {
                throw SemanticXMLError.invalidXML
            }
            tagIndex += 1
            try charge([elementName, uri ?? "", qualified])
            try SemanticXMLNamespace.validateElement(local: elementName, qualified: qualified, uri: uri,
                                                     attributes: attributes, ancestors: stack.map { drafts[$0].attributes })
            pendingNamespaces.removeAll(keepingCapacity: false)
            let name = SemanticXMLName(localName: elementName, namespaceURI: uri, qualifiedName: qualified)
            let index = try append(.element(name), attributes: attributes)
            if root == nil { root = index }
            stack.append(index)
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        event(parser) {
            guard !stack.isEmpty else { throw SemanticXMLError.invalidXML }
            stack.removeLast()
        }
    }

    private func addText(_ string: String) throws {
        guard !string.isEmpty else { return }
        guard let parent = stack.last else {
            guard string.allSatisfy({ $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" }) else {
                throw SemanticXMLError.invalidXML
            }
            return
        }
        try charge([string])
        if let last = drafts[parent].children.last, case .text = drafts[last].kind {
            drafts[last].text.append(string)
        } else {
            let index = try append(.text("")); drafts[index].text = string
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { event(parser) { try addText(string) } }
    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {
        event(parser) { try addText(whitespaceString) }
    }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        event(parser) {
            guard let string = String(data: CDATABlock, encoding: .utf8) else { throw SemanticXMLError.invalidXML }
            try addText(normalizeLineEnds(string))
        }
    }
    func parser(_ parser: XMLParser, foundComment comment: String) {
        event(parser) { try charge([comment]); try append(.comment(comment)) }
    }
    func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
        event(parser) { try charge([target, data ?? ""]); try append(.processingInstruction(target: target, data: data)) }
    }
    private func normalizeLineEnds(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) { stop(SemanticXMLError.invalidXML, parser) }
    func parser(_ parser: XMLParser, validationErrorOccurred validationError: any Error) { stop(SemanticXMLError.invalidXML, parser) }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? {
        // DTDs have already been rejected. An undeclared entity reference is malformed XML.
        stop(SemanticXMLError.invalidXML, parser); return nil
    }
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        stop(SemanticXMLError.forbiddenDTD, parser)
    }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
        stop(SemanticXMLError.forbiddenDTD, parser)
    }
    func parser(_ parser: XMLParser, foundElementDeclarationWithName elementName: String, model: String) {
        stop(SemanticXMLError.forbiddenDTD, parser)
    }
    func parser(_ parser: XMLParser, foundAttributeDeclarationWithName attributeName: String, forElement elementName: String,
                type: String?, defaultValue: String?) { stop(SemanticXMLError.forbiddenDTD, parser) }
    func parser(_ parser: XMLParser, foundNotationDeclarationWithName name: String, publicID: String?, systemID: String?) {
        stop(SemanticXMLError.forbiddenDTD, parser)
    }
    func parser(_ parser: XMLParser, foundUnparsedEntityDeclarationWithName name: String, publicID: String?,
                systemID: String?, notationName: String?) { stop(SemanticXMLError.forbiddenDTD, parser) }
}
