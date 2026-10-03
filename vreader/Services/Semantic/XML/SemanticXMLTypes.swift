// Purpose: Immutable logical XML tree; not a browser DOM, CFI or byte-offset map.
import Foundation

struct SemanticXMLName: Sendable, Equatable {
    let localName: String
    let namespaceURI: String?
    let qualifiedName: String
}

enum SemanticXMLNodeKind: Sendable, Equatable {
    case element(SemanticXMLName)
    case text(String)
    case comment(String)
    case processingInstruction(target: String, data: String?)
}

struct SemanticXMLNode: Sendable, Equatable {
    let kind: SemanticXMLNodeKind
    let attributes: [String: String]
    let parent: Int?
    let children: [Int]
}

struct SemanticXMLDocument: Sendable, Equatable {
    let rootIndex: Int
    let nodes: [SemanticXMLNode]
    let sourceSHA256: String
}

enum SemanticXMLError: Error, Sendable, Equatable {
    case invalidLimits, inputLimit, nodeLimit, depthLimit, attributeLimit, textLimit
    case unsupportedEncoding, forbiddenDTD, invalidXML, unimplemented
}

struct SemanticXMLParseObservation: Sendable {
    let workerStarted: @Sendable () -> Void
    let beforeEvent: @Sendable () throws -> Void
    let beforePublication: @Sendable () -> Void
    let cancellationForwarded: @Sendable () -> Void

    init(workerStarted: @escaping @Sendable () -> Void = {},
         beforeEvent: @escaping @Sendable () throws -> Void = {},
         beforePublication: @escaping @Sendable () -> Void = {},
         cancellationForwarded: @escaping @Sendable () -> Void = {}) {
        self.workerStarted = workerStarted; self.beforeEvent = beforeEvent
        self.beforePublication = beforePublication; self.cancellationForwarded = cancellationForwarded
    }
}
