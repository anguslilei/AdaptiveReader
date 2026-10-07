// Purpose: Decoding cannot bypass the same invariants as explicit construction.
import Foundation
import Testing
@testable import vreader

@Suite("Semantic model validated decoding")
struct SemanticModelCodableTests {
    private func roundTrip<T: Codable & Hashable>(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        #expect(decoded == value)
        #expect(Set([value, decoded]).count == 1)
    }
    private func reject<T: Decodable>(_ type: T.Type, _ json: String) {
        #expect(throws: (any Error).self) { try JSONDecoder().decode(type, from: Data(json.utf8)) }
    }
    @Test func allModelsRoundTripWithLiteralUnicode() throws {
        let digest = try SemanticSHA256(hex: String(repeating: "a", count: 64))
        let path = try SemanticArchivePath("OPS/e\u{301}😀%2F?#.xhtml")
        let revision = try SemanticRevision(archiveSHA256: digest, extractorVersion: Int(UInt32.max))
        let resource = SemanticResourceIdentity(path: path, sha256: digest)
        let range = try SemanticUTF16Range(lowerBound: 0, upperBound: 2)
        let node = try SemanticNodePath([0, Int(UInt32.max)])
        let anchor = try SemanticLogicalAnchor(resource: resource, spineOccurrence: 4095, nodePath: node, textRange: range)
        try roundTrip(digest); try roundTrip(path); try roundTrip(revision); try roundTrip(resource)
        try roundTrip(range); try roundTrip(node); try roundTrip(anchor)
        try roundTrip(SemanticID.revision(revision))
        try roundTrip(SemanticID.block(revision: revision, anchor: anchor, role: .paragraph, ordinal: 0))
        let decoded = try JSONDecoder().decode(SemanticArchivePath.self, from: JSONEncoder().encode(path))
        #expect(decoded.value.utf8.elementsEqual(path.value.utf8))
        try roundTrip(SemanticNodePath([]))
        try roundTrip(SemanticLogicalAnchor(resource: resource, spineOccurrence: 0, nodePath: SemanticNodePath([])))
    }
    @Test(arguments: ["null", "12", "{}", "\"\"", "\"" + String(repeating: "A", count: 64) + "\"", "\"" + String(repeating: "g", count: 64) + "\""])
    func malformedDigestAndIDCannotDecode(_ json: String) {
        reject(SemanticSHA256.self, json); reject(SemanticID.self, json)
    }
    @Test(arguments: ["null", "42", "{}", "\"\"", "\"/a\"", "\"a//b\"", "\"a/../b\""])
    func malformedPathsCannotDecode(_ json: String) { reject(SemanticArchivePath.self, json) }
    @Test func invalidAndMissingRevisionFieldsRejected() {
        let sha = String(repeating: "0", count: 64)
        for fields in ["\"extractorVersion\":0,\"schemaVersion\":1",
                       "\"extractorVersion\":4294967296,\"schemaVersion\":1",
                       "\"extractorVersion\":1,\"schemaVersion\":2",
                       "\"extractorVersion\":1,\"schemaVersion\":null",
                       "\"extractorVersion\":\"1\",\"schemaVersion\":1",
                       "\"extractorVersion\":1"] {
            reject(SemanticRevision.self, "{\"archiveSHA256\":\"\(sha)\",\(fields)}")
        }
        reject(SemanticRevision.self, "{}")
        reject(SemanticRevision.self, "{\"archiveSHA256\":null,\"extractorVersion\":1,\"schemaVersion\":1}")
        reject(SemanticResourceIdentity.self, "{\"path\":\"/bad\",\"sha256\":\"\(sha)\"}")
        reject(SemanticResourceIdentity.self, "{\"path\":\"a\",\"sha256\":\"BAD\"}")
        reject(SemanticResourceIdentity.self, "{}")
    }
    @Test(arguments: ["{}", "null", "{\"lowerBound\":-1,\"upperBound\":0}",
                      "{\"lowerBound\":3,\"upperBound\":2}", "{\"lowerBound\":0,\"upperBound\":2097153}",
                      "{\"lowerBound\":0,\"upperBound\":9223372036854775808}",
                      "{\"lowerBound\":null,\"upperBound\":1}", "{\"lowerBound\":0,\"upperBound\":\"1\"}"])
    func rangeDecodeRunsValidation(_ json: String) { reject(SemanticUTF16Range.self, json) }
    @Test func boundedNodeDecoderRejectsInvalidSlotsAndLength() throws {
        for json in ["null", "{}", "[-1]", "[4294967296]", "[9223372036854775808]", "[null]", "[\"1\"]"] {
            reject(SemanticNodePath.self, json)
        }
        reject(SemanticNodePath.self, "[" + Array(repeating: "0", count: 97).joined(separator: ",") + "]")
        let maximum = Data(("[" + Array(repeating: "4294967295", count: 96).joined(separator: ",") + "]").utf8)
        #expect(try JSONDecoder().decode(SemanticNodePath.self, from: maximum).components.count == 96)
    }
    @Test func anchorDecodeAndDerivedCoordinateSystem() throws {
        let source = "\"resource\":{\"path\":\"a\",\"sha256\":\"" + String(repeating: "0", count: 64) + "\"}"
        for fields in ["\"spineOccurrence\":-1,\"nodePath\":[]", "\"spineOccurrence\":4096,\"nodePath\":[]",
                       "\"spineOccurrence\":0,\"nodePath\":[-1]", "\"spineOccurrence\":0,\"nodePath\":null",
                       "\"spineOccurrence\":0", "\"nodePath\":[]",
                       "\"spineOccurrence\":0,\"nodePath\":[],\"textRange\":{\"lowerBound\":2,\"upperBound\":1}"] {
            reject(SemanticLogicalAnchor.self, "{\(source),\(fields)}")
        }
        let data = Data("{\(source),\"spineOccurrence\":0,\"nodePath\":[],\"coordinateSystem\":\"CFI-exact\"}".utf8)
        let anchor = try JSONDecoder().decode(SemanticLogicalAnchor.self, from: data)
        #expect(anchor.coordinateSystem == .semanticXMLTreeV1)
        let encoded = String(decoding: try JSONEncoder().encode(anchor), as: UTF8.self)
        #expect(!encoded.contains("coordinateSystem"))
    }
    @Test func frozenRolesAndUnknownTags() throws {
        let roles: [SemanticBlockRole] = [.heading, .paragraph, .figure, .caption, .quote, .list, .listItem, .opaque]
        for (index, role) in roles.enumerated() {
            #expect(role.rawValue == UInt8(index + 1))
            #expect(String(decoding: try JSONEncoder().encode(role), as: UTF8.self) == String(index + 1))
            try roundTrip(role)
        }
        for json in ["0", "9", "256", "-1", "\"paragraph\"", "null"] { reject(SemanticBlockRole.self, json) }
    }
    @Test func validLookingIDIsOnlyValidatedSpelling() throws {
        // Decoding does not claim the ID was derived from any source tuple.
        let id = try SemanticID(hex: String(repeating: "f", count: 64))
        try roundTrip(id)
    }
}
