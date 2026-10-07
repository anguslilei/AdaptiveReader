// Purpose: Exact tiny CI inputs; real-book probes are separate local verification.
import Foundation
import CryptoKit
@testable import vreader

enum XHTMLTest {
    static let ns = "http://www.w3.org/1999/xhtml"
    static func document(_ body: String) -> String {
        "<html xmlns='\(ns)'><head/><body>\(body)</body></html>"
    }
    static func resource(_ xml: String, path: String = "OPS/chapter.xhtml",
                         digest: String? = nil, archive: String = String(repeating: "a", count: 64)) -> EPUBSemanticResource {
        let bytes = Data(xml.utf8)
        return EPUBSemanticResource(path: path, bytes: bytes,
            sha256: digest ?? SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(),
            archiveSHA256: archive)
    }
    static func extract(_ body: String, occurrence: Int = 0,
                        limits: SemanticXHTMLLimits = .init()) async throws -> SemanticXHTMLSection {
        try await SemanticXHTMLExtractor.extract(resource: resource(document(body)),
                                                 spineOccurrence: occurrence, limits: limits)
    }
}
