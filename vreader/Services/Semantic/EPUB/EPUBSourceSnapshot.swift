// Purpose: One bounded immutable source revision, independently loaded from disk.
import Foundation

struct EPUBSourceSnapshot: Sendable {
    let bytes: Data
    let sha256: String
    static func load(fileURL: URL, expectedSHA256: String? = nil,
                     limits: EPUBSemanticLimits = EPUBSemanticLimits(),
                     checkCancellation: () throws -> Void = { try Task.checkCancellation() },
                     descriptorObserved: (Int32) -> Void = { _ in }) throws -> Self {
        throw EPUBSemanticSourceError.unimplemented
    }
}
