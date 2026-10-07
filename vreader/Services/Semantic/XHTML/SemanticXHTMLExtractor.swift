// Purpose: Bound one original resource, isolate work and publish only a complete section.
import Foundation

enum SemanticXHTMLExtractor {
    static func extract(resource: EPUBSemanticResource, spineOccurrence: Int,
                        limits: SemanticXHTMLLimits = .init(),
                        observation: SemanticXHTMLObservation? = nil) async throws -> SemanticXHTMLSection {
        try Task.checkCancellation()
        try limits.validate()
        let worker = Task.detached {
            observation?.workerStarted()
            try Task.checkCancellation()
            let revision = try SemanticRevision(archiveSHA256: SemanticSHA256(hex: resource.archiveSHA256),
                                                extractorVersion: SemanticXHTMLPolicy.version)
            let identity = try SemanticResourceIdentity(path: SemanticArchivePath(resource.path),
                                                       sha256: SemanticSHA256(hex: resource.sha256))
            let sectionID = try SemanticID.section(revision: revision, resource: identity,
                                                   spineOccurrence: spineOccurrence)
            let document = try await SemanticXMLParser.parse(resource.bytes, limits: limits.xml)
            guard document.sourceSHA256.utf8.elementsEqual(resource.sha256.utf8) else {
                throw SemanticXHTMLError.inconsistentSource
            }
            var walker = SemanticXHTMLWalker(document: document, revision: revision, resource: identity,
                                              occurrence: spineOccurrence, limits: limits, observation: observation)
            let blocks = try walker.extract()
            try Task.checkCancellation()
            return SemanticXHTMLSection(revision: revision, resource: identity, occurrence: spineOccurrence,
                                        id: sectionID, blocks: blocks)
        }
        return try await withTaskCancellationHandler {
            let result = try await worker.value
            observation?.beforePublication()
            try Task.checkCancellation()
            return result
        } onCancel: {
            worker.cancel()
            observation?.cancellationForwarded()
        }
    }
}
