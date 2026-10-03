// Purpose: Isolated original-byte XML work, cancellation forwarding and immutable publication.
import Foundation
import CryptoKit

enum SemanticXMLParser {
    static func parse(_ bytes: Data, limits: SemanticXMLLimits = SemanticXMLLimits(),
                      observation: SemanticXMLParseObservation? = nil) async throws -> SemanticXMLDocument {
        try Task.checkCancellation()
        try limits.validate()
        let worker = Task.detached {
            observation?.workerStarted()
            try Task.checkCancellation()
            return try parseBlocking(bytes, limits: limits, observation: observation)
        }
        return try await withTaskCancellationHandler {
            let document = try await worker.value
            observation?.beforePublication()
            try Task.checkCancellation()
            return document
        } onCancel: {
            worker.cancel()
            observation?.cancellationForwarded()
        }
    }

    static func parseBlocking(_ bytes: Data, limits: SemanticXMLLimits,
                              observation: SemanticXMLParseObservation? = nil) throws -> SemanticXMLDocument {
        try limits.validate()
        let startTags = try SemanticXMLPreflight.validate(bytes, limits: limits, check: { try Task.checkCancellation() })
        let builder = SemanticXMLBuilder(limits: limits, startTags: startTags, check: {
            try Task.checkCancellation()
            try observation?.beforeEvent()
            try Task.checkCancellation()
        })
        let parser = XMLParser(data: bytes)
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = builder
        let success = parser.parse()
        if let failure = builder.failure { throw failure }
        guard success && parser.parserError == nil else { throw SemanticXMLError.invalidXML }
        try Task.checkCancellation()
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        try Task.checkCancellation()
        return try builder.finish(digest: digest)
    }
}
