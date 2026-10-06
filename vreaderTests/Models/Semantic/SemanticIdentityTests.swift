// Purpose: Independent canonical byte/hash vectors and source identity separation.
import Foundation
import Testing
@testable import vreader

@Suite("Semantic identity canonical bytes")
struct SemanticIdentityTests {
    private func revision(_ digest: String = String(repeating: "0", count: 64),
                          _ version: Int = 1) throws -> SemanticRevision {
        try SemanticRevision(archiveSHA256: SemanticSHA256(hex: digest), extractorVersion: version)
    }
    private func resource(_ path: String = "OPS/a.xhtml",
                          _ digest: String = String(repeating: "1", count: 64)) throws -> SemanticResourceIdentity {
        try SemanticResourceIdentity(path: SemanticArchivePath(path), sha256: SemanticSHA256(hex: digest))
    }
    private func anchor(path: String = "OPS/a.xhtml", digest: String = String(repeating: "1", count: 64),
                        occurrence: Int = 0, node: [Int] = [1, 2],
                        range: SemanticUTF16Range? = nil) throws -> SemanticLogicalAnchor {
        try SemanticLogicalAnchor(resource: resource(path, digest), spineOccurrence: occurrence,
                                  nodePath: SemanticNodePath(node), textRange: range)
    }
    private func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }

    @Test func independentRevisionVector() throws {
        let r = try revision()
        #expect(SemanticID.revision(r).hex == "4d52d209a69dd9ee008b2699f8b4bfd9ac1f06b54ef8b5f8b9a0dcb7da0108b2")
        #expect(hex(SemanticID.canonicalRevisionBytes(r)) == "767265616465722e73656d616e7469632d69642e7631000100000000000000000000000000000000000000000000000000000000000000000000000100000001")
    }
    @Test func independentSectionVector() throws {
        let r = try revision(), source = try resource()
        #expect(try SemanticID.section(revision: r, resource: source, spineOccurrence: 0).hex == "74f8ce5e53bd152f74f55be330540ab55cde0cbfdae2c504faf80bddd64a13f6")
        #expect(hex(try SemanticID.canonicalSectionBytes(revision: r, resource: source, spineOccurrence: 0)) == "767265616465722e73656d616e7469632d69642e76310002000000000000000000000000000000000000000000000000000000000000000000000001000000010000000b4f50532f612e7868746d6c111111111111111111111111111111111111111111111111111111111111111100000000")
    }
    @Test func independentBlockVector() throws {
        let r = try revision()
        let a = try anchor(range: SemanticUTF16Range(lowerBound: 0, upperBound: 2))
        #expect(try SemanticID.block(revision: r, anchor: a, role: .paragraph, ordinal: 0).hex == "87222d58da8929d96d066a38b25f41ca493b7c0274848cd93d818879ef49fe66")
        #expect(hex(try SemanticID.canonicalBlockBytes(revision: r, anchor: a, role: .paragraph, ordinal: 0)) == "767265616465722e73656d616e7469632d69642e76310003000000000000000000000000000000000000000000000000000000000000000000000001000000010000000b4f50532f612e7868746d6c1111111111111111111111111111111111111111111111111111111111111111000000000000000200000001000000020100000000000000020200000000")
    }
    @Test func nilAndEmptyRangesAreDifferentTuples() throws {
        let r = try revision(), nilAnchor = try anchor()
        let empty = try anchor(range: SemanticUTF16Range(lowerBound: 0, upperBound: 0))
        #expect(try SemanticID.block(revision: r, anchor: nilAnchor, role: .paragraph, ordinal: 0).hex == "1609b9cf3790a9d0527670de7b66af0d966b3663921f1f7ee08e707c143fecb1")
        #expect(try SemanticID.block(revision: r, anchor: empty, role: .paragraph, ordinal: 0).hex == "ea4c0448cb66c0bc2d77d870023d34114dcaa0e919d54825c29ad324c1d02efc")
    }
    @Test func unicodeDelimiterAndNumericMaximumVector() throws {
        let a = try anchor(path: "OPS/章节😀/שלום%2F?#.xhtml", occurrence: 4095, node: [])
        #expect(try SemanticID.block(revision: revision(), anchor: a, role: .opaque,
                                    ordinal: Int(UInt32.max)).hex == "15f4650e2dc541b1b5af239838a5d86c8426cae346829178ba0e69fd9cbf04ba")
        #expect(SemanticID.revision(try revision(String(repeating: "0", count: 64), Int(UInt32.max))).hex == "a5f24296d3948e3bdf66f72d671dd163d3f29640e3a9aa013a2787e781876e3c")
        let maximum = try anchor(node: Array(repeating: Int(UInt32.max), count: 96),
                                 range: SemanticUTF16Range(lowerBound: 2 * 1024 * 1024, upperBound: 2 * 1024 * 1024))
        #expect(try SemanticID.block(revision: revision(), anchor: maximum, role: .paragraph, ordinal: 0).hex == "d064f78316854b24fc2485abdb35fb617138d5c8da58e74acef3a6fe79a603c9")
    }
    @Test func literalUnicodeNormalizationHasSeparateIdentity() throws {
        let r = try revision(), nfc = try resource("OPS/é.xhtml"), nfd = try resource("OPS/e\u{301}.xhtml")
        #expect(nfc != nfd)
        #expect(Set([nfc, nfd]).count == 2)
        #expect(try SemanticID.section(revision: r, resource: nfc, spineOccurrence: 0).hex == "4a49d4642f80577e4100357816b7bf79945d9eb57d112bd54063432b95f73fa3")
        #expect(try SemanticID.section(revision: r, resource: nfd, spineOccurrence: 0).hex == "6f5beb9db24c28d768bca0e2d1142cac896027f113ad8b05333fe5ac5a45c197")
    }
    @Test func everyTupleFieldSeparatesCanonicalIdentity() throws {
        let r = try revision()
        let range = try SemanticUTF16Range(lowerBound: 0, upperBound: 2)
        let a = try anchor(range: range)
        let original = try SemanticID.block(revision: r, anchor: a, role: .paragraph, ordinal: 0)
        let changes = [
            try SemanticID.block(revision: revision(String(repeating: "2", count: 64)), anchor: a, role: .paragraph, ordinal: 0),
            try SemanticID.block(revision: revision(String(repeating: "0", count: 64), 2), anchor: a, role: .paragraph, ordinal: 0),
            try SemanticID.block(revision: r, anchor: anchor(path: "OPS/b.xhtml", range: range), role: .paragraph, ordinal: 0),
            try SemanticID.block(revision: r, anchor: anchor(digest: String(repeating: "2", count: 64), range: range), role: .paragraph, ordinal: 0),
            try SemanticID.block(revision: r, anchor: anchor(occurrence: 1, range: range), role: .paragraph, ordinal: 0),
            try SemanticID.block(revision: r, anchor: anchor(node: [1, 3], range: range), role: .paragraph, ordinal: 0),
            try SemanticID.block(revision: r, anchor: anchor(range: SemanticUTF16Range(lowerBound: 1, upperBound: 2)), role: .paragraph, ordinal: 0),
            try SemanticID.block(revision: r, anchor: anchor(range: SemanticUTF16Range(lowerBound: 0, upperBound: 3)), role: .paragraph, ordinal: 0),
            try SemanticID.block(revision: r, anchor: a, role: .heading, ordinal: 0),
            try SemanticID.block(revision: r, anchor: a, role: .paragraph, ordinal: 1)
        ]
        #expect(!changes.contains(original))
        #expect(Set(changes).count == changes.count)
        #expect(Set([SemanticID.revision(r), try SemanticID.section(revision: r, resource: resource(), spineOccurrence: 0), original]).count == 3)
    }
    @Test func repeatableConcurrentFactories() async throws {
        let r = try revision(), a = try anchor()
        let expected = try SemanticID.block(revision: r, anchor: a, role: .paragraph, ordinal: 0)
        let results = try await withThrowingTaskGroup(of: SemanticID.self) { group in
            for _ in 0..<64 {
                group.addTask { try SemanticID.block(revision: r, anchor: a, role: .paragraph, ordinal: 0) }
            }
            var values: [SemanticID] = []
            for try await value in group { values.append(value) }
            return values
        }
        #expect(results.count == 64)
        #expect(results.allSatisfy { $0 == expected })
    }
    @Test(arguments: [-1, Int(UInt32.max) + 1, Int.max])
    func invalidOrdinalRejected(_ n: Int) throws {
        let r = try revision(), a = try anchor()
        #expect(throws: SemanticModelError.invalidOrdinal) {
            try SemanticID.block(revision: r, anchor: a, role: .paragraph, ordinal: n)
        }
    }
    @Test(arguments: [-1, 4096, Int.max])
    func invalidSectionOccurrenceRejected(_ n: Int) throws {
        let r = try revision(), source = try resource()
        #expect(throws: SemanticModelError.invalidOccurrence) {
            try SemanticID.section(revision: r, resource: source, spineOccurrence: n)
        }
    }
}
