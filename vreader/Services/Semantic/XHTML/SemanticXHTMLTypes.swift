// Purpose: Disposable logical-source semantics, never rendered text or exact navigation.
import Foundation

struct SemanticXHTMLSection: Sendable, Equatable {
    let revision: SemanticRevision
    let resource: SemanticResourceIdentity
    let occurrence: Int
    let id: SemanticID
    let blocks: [SemanticXHTMLBlock]
}

struct SemanticXHTMLBlock: Sendable, Equatable {
    let id: SemanticID
    let role: SemanticBlockRole
    let anchor: SemanticLogicalAnchor
    let parentIndex: Int?
    let headingLevel: Int?
    let runs: [SemanticXHTMLTextRun]
}

struct SemanticXHTMLTextRun: Sendable, Equatable {
    let text: String
    let anchor: SemanticLogicalAnchor
}

enum SemanticXHTMLError: Error, Sendable, Equatable {
    case invalidLimits, inconsistentSource, invalidDocument, blockLimit, runLimit, outputLimit
}

struct SemanticXHTMLObservation: Sendable {
    let workerStarted: @Sendable () -> Void
    let beforeNode: @Sendable (Int) -> Void
    let beforePublication: @Sendable () -> Void
    let cancellationForwarded: @Sendable () -> Void
    init(workerStarted: @escaping @Sendable () -> Void = {},
         beforeNode: @escaping @Sendable (Int) -> Void = { _ in },
         beforePublication: @escaping @Sendable () -> Void = {},
         cancellationForwarded: @escaping @Sendable () -> Void = {}) {
        self.workerStarted = workerStarted; self.beforeNode = beforeNode
        self.beforePublication = beforePublication; self.cancellationForwarded = cancellationForwarded
    }
}
