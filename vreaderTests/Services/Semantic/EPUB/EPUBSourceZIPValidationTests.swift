// Purpose: Corrupt/ambiguous ZIP grammar must fail before resource publication.
import Foundation
import Testing
@testable import vreader

@Suite("Semantic EPUB ZIP grammar")
struct EPUBSourceZIPValidationTests {
    typealias ZIP = EPUBSemanticZIPFixture

    @Test(arguments: ["../x", "/x", "C:/x", "a\\b", "a//b", "./x", "a/../x", "a\0b", ""])
    func unsafePaths(_ path: String) async {
        var m = ZIP.Member(); m.path = path
        await expectSemanticOpenFailure(ZIP([m]), error: .unsafePath)
    }

    @Test func duplicatesAndUnicodeEquivalentNames() async {
        await expectSemanticOpenFailure(ZIP([ZIP.Member(), ZIP.Member()]), error: .duplicatePath)
        var a = ZIP.Member(), b = a; a.path = "é"; b.path = "e\u{301}"
        await expectSemanticOpenFailure(ZIP([a,b]), error: .duplicatePath)
    }

    @Test(arguments: [UInt16(1), 0x40, 0x100, 0x2000, 0x10])
    func unsupportedFlags(_ flags: UInt16) async {
        var m = ZIP.Member(); m.flags |= flags
        await expectSemanticOpenFailure(ZIP([m]), error: .unsupportedEntry)
    }

    @Test func unsupportedMethodSymlinkAndUnflaggedUnicode() async {
        var m = ZIP.Member(); m.method = 99
        await expectSemanticOpenFailure(ZIP([m]), error: .unsupportedEntry)
        m = ZIP.Member(); m.attributes = 0xA1FF0000
        await expectSemanticOpenFailure(ZIP([m]), error: .unsupportedEntry)
        m = ZIP.Member(); m.flags = 0; m.path = "书.xhtml"
        await expectSemanticOpenFailure(ZIP([m]), error: .unsupportedEntry)
    }

    @Test(arguments: [UInt16(0x0001), 0x7075, 0x0008])
    func unsupportedExtraFields(_ id: UInt16) async {
        var m = ZIP.Member(); m.extra.add16(id); m.extra.add16(0)
        await expectSemanticOpenFailure(ZIP([m]), error: .unsupportedEntry)
    }

    @Test func malformedExtraAndDirectoryPayload() async {
        var m = ZIP.Member(); m.extra = Data([1,2,3])
        await expectSemanticOpenFailure(ZIP([m]), error: .invalidArchive)
        m = ZIP.Member(); m.path = "dir/"
        await expectSemanticOpenFailure(ZIP([m]), error: .invalidArchive)
    }

    @Test(arguments: [0, 1, 21, 30, 50])
    func truncation(_ length: Int) async {
        var f = ZIP(); f.bytes = Data(f.bytes.prefix(length))
        await expectSemanticOpenFailure(f, error: .invalidArchive)
    }

    @Test func eocdAccountingAndDiskMismatch() async {
        for offset in [4, 6, 8] {
            var f = ZIP(); f.bytes.set16(f.eocdOffset + offset, 1 + UInt16(offset == 8 ? 1 : 0))
            await expectSemanticOpenFailure(f, error: .invalidArchive)
        }
        for offset in [12,16] {
            var f = ZIP(); f.bytes.set32(f.eocdOffset + offset, 1)
            await expectSemanticOpenFailure(f, error: .invalidArchive)
        }
    }

    @Test func falseEOCDInsideComment() async throws {
        let fake = Data([0x50,0x4b,0x05,0x06]) + Data(repeating: 0, count: 30)
        let f = ZIP(comment: fake), url = ZIP.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }; try f.write(to: url)
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
        #expect(try await reader.read(path: "chapter.xhtml").bytes == Data("hello".utf8))
        await reader.close()
    }

    @Test(arguments: [6,8,14,18,22])
    func localMetadataMismatch(_ offset: Int) async {
        var f = ZIP(); f.bytes[f.localOffsets[0] + offset] ^= 1
        await expectSemanticOpenFailure(f, error: .invalidArchive)
    }

    @Test func localNameMismatchOverlapAndMissingDescriptor() async {
        var f = ZIP(); f.bytes[f.localOffsets[0] + 30] ^= 1
        await expectSemanticOpenFailure(f, error: .invalidArchive)
        var m = ZIP.Member(); m.path = "another.xhtml"; f = ZIP([ZIP.Member(),m])
        // Second central record points at the first local record, a forbidden overlapping span.
        f.bytes.set32(f.centralOffsets[1] + 42, 0)
        await expectSemanticOpenFailure(f, error: .invalidArchive)
        m = ZIP.Member(); m.flags |= 8
        await expectSemanticOpenFailure(ZIP([m]), error: .invalidArchive)
    }

    @Test func corruptDescriptor() async {
        var m = ZIP.Member(); m.descriptor = .signed
        var f = ZIP([m]); f.bytes[f.directoryOffset - 1] ^= 1
        await expectSemanticOpenFailure(f, error: .invalidArchive)
    }

    @Test func wrongStoredCRCClosesReader() async throws {
        var m = ZIP.Member(); m.crc = 1
        let f = ZIP([m]), url = ZIP.temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }; try f.write(to: url)
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
        await expectSemanticReadFailure(reader, path: m.path, error: .integrityMismatch)
        await expectSemanticReadFailure(reader, path: m.path, error: .closed)
    }
}
