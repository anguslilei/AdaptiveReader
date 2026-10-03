// Purpose: Independent actor for bounded, original-byte semantic source resources.
import Foundation

actor EPUBSemanticResourceReader {
    static func open(fileURL: URL, expectedArchiveSHA256: String? = nil,
                     limits: EPUBSemanticLimits = EPUBSemanticLimits()) async throws -> EPUBSemanticResourceReader {
        throw EPUBSemanticSourceError.unimplemented
    }
    func read(path: String) throws -> EPUBSemanticResource {
        throw EPUBSemanticSourceError.unimplemented
    }
    func close() {}
}
