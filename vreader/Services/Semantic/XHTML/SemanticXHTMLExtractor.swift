// Purpose: Compiling RED seam; behavior is implemented after executing failing tests.
import Foundation

enum SemanticXHTMLExtractor {
    static func extract(resource: EPUBSemanticResource, spineOccurrence: Int,
                        limits: SemanticXHTMLLimits = .init(),
                        observation: SemanticXHTMLObservation? = nil) async throws -> SemanticXHTMLSection {
        throw SemanticXHTMLError.invalidDocument
    }
}
