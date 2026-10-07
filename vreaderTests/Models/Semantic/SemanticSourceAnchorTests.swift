// Purpose: Literal source paths, bounded logical coordinates and scalar-safe UTF16.
import Foundation
import Testing
@testable import vreader

@Suite("Semantic logical source anchors")
struct SemanticSourceAnchorTests {
    @Test(arguments: ["", String(repeating: "a", count: 63), String(repeating: "a", count: 65),
                      String(repeating: "A", count: 64), String(repeating: "g", count: 64),
                      String(repeating: "é", count: 64)])
    func digestRejectsNoncanonicalSpelling(_ value: String) {
        #expect(throws: SemanticModelError.invalidDigest) { try SemanticSHA256(hex: value) }
        #expect(throws: SemanticModelError.invalidDigest) { try SemanticID(hex: value) }
    }
    @Test func digestPayloadIsExactly32RawBytes() throws {
        let value = try SemanticSHA256(hex: String(repeating: "0123456789abcdef", count: 4))
        #expect(value.bytes == Array(repeating: [UInt8(1), 35, 69, 103, 137, 171, 205, 239], count: 4).flatMap { $0 })
    }
    @Test(arguments: ["", "/a", "a/", "a//b", ".", "..", "a/./b", "a/../b",
                      "a\\b", "a:b", "a\0b", "a\u{1f}b", "a\u{7f}b",
                      "/\u{301}a", "a//\u{301}b", "a/.. /../b"])
    func invalidPathsRejected(_ path: String) {
        #expect(throws: SemanticModelError.invalidPath) { try SemanticArchivePath(path) }
    }
    @Test(arguments: ["OPS/章节😀.xhtml", "OPS/שלום.xhtml", "a%2Fb%20c", "a?#b",
                      "a/.. /b", "a/\u{301}b", "a b", "A/a"])
    func alreadyResolvedFilenamesRetainLiteralBytes(_ path: String) throws {
        #expect(try SemanticArchivePath(path).value.utf8.elementsEqual(path.utf8))
    }
    @Test func pathByteCeilingAndLiteralEquality() throws {
        #expect(try SemanticArchivePath(String(repeating: "a", count: 8192)).value.utf8.count == 8192)
        #expect(throws: SemanticModelError.invalidPath) { try SemanticArchivePath(String(repeating: "a", count: 8193)) }
        #expect(throws: SemanticModelError.invalidPath) { try SemanticArchivePath(String(repeating: "😀", count: 2049)) }
        let a = try SemanticArchivePath("é"), b = try SemanticArchivePath("e\u{301}")
        #expect(a != b)
        #expect(Set([a, b]).count == 2)
        #expect(try SemanticArchivePath("a%2Fb") != SemanticArchivePath("a/b"))
    }
    @Test func boundedChildSlotsAndRoot() throws {
        #expect(try SemanticNodePath([]).components.isEmpty)
        #expect(try SemanticNodePath(Array(repeating: Int(UInt32.max), count: 96)).components.count == 96)
        for path in [[-1], [Int(UInt32.max) + 1], [Int.max], Array(repeating: 0, count: 97)] {
            #expect(throws: SemanticModelError.invalidNodePath) { try SemanticNodePath(path) }
        }
    }
    @Test(arguments: [(0, 0), (0, 2 * 1024 * 1024), (2 * 1024 * 1024, 2 * 1024 * 1024)])
    func rangeSyntaxAtBounds(_ lower: Int, _ upper: Int) throws {
        #expect(try SemanticUTF16Range(lowerBound: lower, upperBound: upper).upperBound == upper)
    }
    @Test(arguments: [(-1, 0), (2, 1), (0, 2 * 1024 * 1024 + 1), (0, Int.max)])
    func invalidRangeSyntax(_ lower: Int, _ upper: Int) {
        #expect(throws: SemanticModelError.invalidRange) { try SemanticUTF16Range(lowerBound: lower, upperBound: upper) }
    }
    @Test func surrogateSplitsRejectedButScalarBoundariesAllowed() throws {
        let text = "A😀e\u{301}👩\u{200d}💻中שלום\r\n"
        let count = text.utf16.count
        for boundary in 0...count {
            let range = try SemanticUTF16Range(lowerBound: boundary, upperBound: boundary)
            if [2, 6, 9].contains(boundary) {
                #expect(throws: SemanticModelError.invalidRange) { try range.validate(in: text) }
            } else {
                try range.validate(in: text)
            }
        }
        try SemanticUTF16Range(lowerBound: 3, upperBound: 5).validate(in: text)
        #expect(throws: SemanticModelError.invalidRange) { try SemanticUTF16Range(lowerBound: 2, upperBound: 3).validate(in: text) }
        #expect(throws: SemanticModelError.invalidRange) { try SemanticUTF16Range(lowerBound: 0, upperBound: 2).validate(in: text) }
        #expect(throws: SemanticModelError.invalidRange) { try SemanticUTF16Range(lowerBound: 0, upperBound: count + 1).validate(in: text) }
        try SemanticUTF16Range(lowerBound: 0, upperBound: 0).validate(in: "")
    }
    @Test func maximumTextRangeIsAccepted() throws {
        let n = 2 * 1024 * 1024
        try SemanticUTF16Range(lowerBound: 0, upperBound: n).validate(in: String(repeating: "x", count: n))
    }
    @Test func anchorsRemainLogicalSyntax() throws {
        let source = try SemanticResourceIdentity(path: SemanticArchivePath("OPS/a"), sha256: SemanticSHA256(hex: String(repeating: "0", count: 64)))
        for occurrence in [0, 4095] {
            let anchor = try SemanticLogicalAnchor(resource: source, spineOccurrence: occurrence, nodePath: SemanticNodePath([123]))
            #expect(anchor.coordinateSystem == .semanticXMLTreeV1)
            #expect(anchor.textRange == nil)
        }
        for occurrence in [-1, 4096, Int.max] {
            #expect(throws: SemanticModelError.invalidOccurrence) {
                try SemanticLogicalAnchor(resource: source, spineOccurrence: occurrence, nodePath: SemanticNodePath([]))
            }
        }
    }
    @Test(arguments: [0, -1, Int(UInt32.max) + 1, Int.max])
    func invalidExtractorVersion(_ n: Int) throws {
        let digest = try SemanticSHA256(hex: String(repeating: "0", count: 64))
        #expect(throws: SemanticModelError.invalidVersion) { try SemanticRevision(archiveSHA256: digest, extractorVersion: n) }
    }
    @Test(arguments: [0, 2, -1, Int.max])
    func unknownSchemaRejected(_ n: Int) throws {
        let digest = try SemanticSHA256(hex: String(repeating: "0", count: 64))
        #expect(throws: SemanticModelError.unsupportedSchema) { try SemanticRevision(archiveSHA256: digest, extractorVersion: 1, schemaVersion: n) }
    }
}
