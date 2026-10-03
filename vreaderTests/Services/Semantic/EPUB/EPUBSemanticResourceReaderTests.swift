// Purpose: Real archive-byte identity, extraction and actor-session integration contracts.
import Testing
import Foundation
import CryptoKit
@testable import vreader

@Suite("Semantic EPUB resources", .serialized)
struct EPUBSemanticResourceReaderTests {
    typealias ZIP = EPUBSemanticZIPFixture

    @Test func storedBytesAndIndependentDigests() async throws {
        let fixture = ZIP(), url = ZIP.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try fixture.write(to: url)
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
        let result = try await reader.read(path: "chapter.xhtml")
        #expect(result.bytes == Data("hello".utf8))
        #expect(result.sha256 == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        let digest = SHA256.hash(data: fixture.bytes).map { String(format: "%02x", $0) }.joined()
        #expect(result.archiveSHA256 == digest)
        await reader.close()
    }

    @Test(arguments: ["cb48cdc9c90700", "0300", "7bb277c1d3a57b3fcc9fd90400"])
    func deflatedRealBytes(_ hex: String) async throws {
        let text = hex == "0300" ? "" : (hex == "cb48cdc9c90700" ? "hello" : "你好🙂")
        var member = ZIP.Member(); member.bytes = Data(text.utf8)
        member.method = 8; member.compressed = ZIP.hex(hex)
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        try ZIP([member]).write(to: url)
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
        #expect(try await reader.read(path: member.path).bytes == member.bytes)
        await reader.close()
    }

    @Test func unicodeNamesAndEmptyStoredResource() async throws {
        var member = ZIP.Member(); member.path = "书/第一章.xhtml"; member.bytes = Data()
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        try ZIP([member]).write(to: url)
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
        #expect(try await reader.read(path: member.path).bytes.isEmpty)
        await reader.close()
    }

    @Test func snapshotSurvivesPathReplacementAndIndependentRevision() async throws {
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        try ZIP().write(to: url)
        let old = try await EPUBSemanticResourceReader.open(fileURL: url)
        let first = try await old.read(path: "chapter.xhtml")
        var changed = ZIP.Member(); changed.bytes = Data("world".utf8)
        try ZIP([changed]).bytes.write(to: url, options: .atomic)
        let newer = try await EPUBSemanticResourceReader.open(fileURL: url)
        let pinned = try await old.read(path: "chapter.xhtml")
        let next = try await newer.read(path: "chapter.xhtml")
        #expect(first.bytes == pinned.bytes)
        #expect(first.archiveSHA256 != next.archiveSHA256)
        #expect(next.bytes == changed.bytes)
        await old.close(); await newer.close()
    }

    @Test func expectedDigestAndCloseFailureLifecycle() async throws {
        let fixture = ZIP(), url = ZIP.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        try fixture.write(to: url)
        let sha = SHA256.hash(data: fixture.bytes).map { String(format: "%02x", $0) }.joined()
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url, expectedArchiveSHA256: sha)
        await reader.close(); await reader.close()
        await expectSemanticReadFailure(reader, path: "chapter.xhtml", error: .closed)
        await expectSemanticOpenFailure(fixture, error: .integrityMismatch, expectedSHA: String(repeating: "0", count: 64))
        await expectSemanticOpenFailure(fixture, error: .invalidDigest, expectedSHA: "bad")
    }

    @Test func failedReadClosesSession() async throws {
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        try ZIP().write(to: url)
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
        await expectSemanticReadFailure(reader, path: "missing", error: .resourceNotFound)
        await expectSemanticReadFailure(reader, path: "chapter.xhtml", error: .closed)
    }

    @Test func descriptorVariants() async throws {
        for descriptor in [ZIP.Descriptor.signed, .unsigned] {
            var member = ZIP.Member(); member.descriptor = descriptor
            let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
            try ZIP([member]).write(to: url)
            let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
            #expect(try await reader.read(path: member.path).bytes == member.bytes)
            await reader.close()
        }
    }

    @Test func unsignedDescriptorCRCEqualsMagicIsParsedWithoutGuessing() async throws {
        var member = ZIP.Member(); member.crc = 0x08074b50; member.descriptor = .unsigned
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        try ZIP([member]).write(to: url)
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
        // Grammar is accepted; actual payload CRC remains independently verified.
        await expectSemanticReadFailure(reader, path: member.path, error: .integrityMismatch)
    }
}

func expectSemanticOpenFailure(_ fixture: EPUBSemanticZIPFixture,
                               error: EPUBSemanticSourceError,
                               limits: EPUBSemanticLimits = EPUBSemanticLimits(),
                               expectedSHA: String? = nil) async {
    let url = EPUBSemanticZIPFixture.temporaryURL()
    defer { try? FileManager.default.removeItem(at: url) }
    do {
        try fixture.write(to: url)
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url,
                                                              expectedArchiveSHA256: expectedSHA, limits: limits)
        await reader.close(); Issue.record("Expected open rejection: \(error)")
    } catch let observed {
        #expect(observed as? EPUBSemanticSourceError == error)
    }
}

func expectSemanticReadFailure(_ reader: EPUBSemanticResourceReader, path: String,
                               error: EPUBSemanticSourceError) async {
    do { _ = try await reader.read(path: path); Issue.record("Expected read rejection: \(error)") }
    catch let observed { #expect(observed as? EPUBSemanticSourceError == error) }
}
