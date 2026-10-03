// Purpose: Compile-capable behavioral RED API; implementation follows executed RED.
import Foundation

enum SemanticXMLParser {
    static func parse(_ bytes: Data, limits: SemanticXMLLimits = SemanticXMLLimits(),
                      observation: SemanticXMLParseObservation? = nil) async throws -> SemanticXMLDocument {
        throw SemanticXMLError.unimplemented
    }
}
