// Purpose: Compile-capable real-source loader contract before native behavioral RED.
import Foundation

enum EPUBSemanticPackageLoader {
    static func load(fileURL: URL, expectedArchiveSHA256: String? = nil,
                     sourceLimits: EPUBSemanticLimits = EPUBSemanticLimits(),
                     xmlLimits: SemanticXMLLimits = SemanticXMLLimits(),
                     packageLimits: EPUBSemanticPackageLimits = EPUBSemanticPackageLimits(),
                     observation: EPUBPackageLoadObservation? = nil) async throws -> EPUBSemanticPackage {
        try Task.checkCancellation()
        throw EPUBSemanticPackageError.unimplemented
    }
}
