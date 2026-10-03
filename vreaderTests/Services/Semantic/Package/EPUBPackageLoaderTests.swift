// Purpose: Real stored/deflated ZIP + real XML parsing, snapshot lifecycle and cancellation.
import Foundation
import CryptoKit
import Testing
@testable import vreader

@Suite("EPUB package source lifecycle", .serialized)
struct EPUBPackageLoaderTests {
    @Test func originalDigestsAndClosedReaderAfterSuccess() async throws {
        let zip = EPUBPackageFixture.archive(), probe = EPUBPackageProbe(.worker)
        // Capture a real actor without blocking the worker in this success case.
        let observation = EPUBPackageLoadObservation(readerCreated: probe.observation.readerCreated)
        try await EPUBPackageFixture.withArchive(zip) { url in
            let p = try await EPUBSemanticPackageLoader.load(fileURL: url, observation: observation)
            #expect(p.archiveSHA256 == SHA256.hash(data: zip.bytes).map { String(format: "%02x", $0) }.joined())
            #expect(p.containerSHA256 == "57f451e86d081cb82edbf7bc60e2a23cf64cb04808b33652071fe9297b29d75b")
            #expect(p.packageSHA256 == "e5790a7af90ec4b308d87ac31c1d829f1527601100107b911f37a4fe4de92549")
            #expect(p.packagePath == "OPS/book.opf" && p.spine.count == 1)
            let reader = try #require(probe.reader)
            await #expect(throws: EPUBSemanticSourceError.closed) { try await reader.catalog() }
            await #expect(throws: EPUBSemanticSourceError.closed) { try await reader.read(path: "OPS/chapter.xhtml") }
        }
    }
    @Test func catalogIsFileOnlySortedAndDoesNotConsumeReadBudget() async throws {
        let zip = EPUBSemanticZIPFixture([.init(path: "z", bytes: Data("abc".utf8)),
            .init(path: "dir/", bytes: Data()), .init(path: "a", bytes: Data())])
        try await EPUBPackageFixture.withArchive(zip) { url in
            let r = try await EPUBSemanticResourceReader.open(fileURL: url, limits: .init(totalBytes: 3))
            let c = try await r.catalog()
            #expect(c.paths == ["a", "z"] && c.archiveSHA256.count == 64)
            #expect(try await r.catalog().paths == c.paths)
            #expect(try await r.read(path: "z").bytes == Data("abc".utf8))
            #expect(try await r.catalog().paths == c.paths)
            await #expect(throws: EPUBSemanticSourceError.limitExceeded) { try await r.read(path: "z") }
            await #expect(throws: EPUBSemanticSourceError.closed) { try await r.catalog() }
        }
    }
    @Test func cancelledCatalogClosesActualReader() async throws {
        try await EPUBPackageFixture.withArchive(EPUBSemanticZIPFixture()) { url in
            let r = try await EPUBSemanticResourceReader.open(fileURL: url)
            let gate = EPUBPackageProbe(.worker)
            let task = Task.detached { gate.pause(); return try await r.catalog() }
            let started = await Task.detached { gate.wait() }.value
            #expect(started); task.cancel(); gate.release()
            await #expect(throws: CancellationError.self) { try await task.value }
            await #expect(throws: EPUBSemanticSourceError.closed) { try await r.catalog() }
        }
    }
    @Test func assetsAreCheckedWithoutInflatingOrClaimingTheirIntegrity() async throws {
        let asset = EPUBSemanticZIPFixture.Member(path: "OPS/chapter.xhtml", bytes: Data("chapter".utf8), crc: 1)
        let zip = EPUBPackageFixture.archive(assets: [asset])
        let budget = EPUBPackageFixture.container().utf8.count + EPUBPackageFixture.opf().utf8.count
        try await EPUBPackageFixture.withArchive(zip) { url in
            #expect(try await EPUBSemanticPackageLoader.load(fileURL: url, sourceLimits: .init(totalBytes: budget)).spine.count == 1)
            let r = try await EPUBSemanticResourceReader.open(fileURL: url)
            await #expect(throws: EPUBSemanticSourceError.integrityMismatch) { try await r.read(path: "OPS/chapter.xhtml") }
        }
    }
    @Test func metadataCRCFailurePropagatesAndClosesReader() async throws {
        let probe = EPUBPackageProbe(.worker)
        try await EPUBPackageFixture.withArchive(EPUBPackageFixture.archive(opfCRC: 1)) { url in
            await #expect(throws: EPUBSemanticSourceError.integrityMismatch) {
                try await EPUBSemanticPackageLoader.load(fileURL: url, observation: .init(readerCreated: probe.observation.readerCreated))
            }
            let reader = try #require(probe.reader)
            await #expect(throws: EPUBSemanticSourceError.closed) { try await reader.catalog() }
        }
    }
    @Test func XMLFailureAndPackageFailurePropagateAndCloseReader() async throws {
        for (xml, expected) in [("<!DOCTYPE package><package/>", "xml"), ("<package/>", "package")] {
            let probe = EPUBPackageProbe(.worker)
            try await EPUBPackageFixture.withArchive(EPUBPackageFixture.archive(opf: xml)) { url in
                do {
                    _ = try await EPUBSemanticPackageLoader.load(fileURL: url, observation: .init(readerCreated: probe.observation.readerCreated))
                    Issue.record("accepted invalid \(expected)")
                } catch {
                    if expected == "xml" { #expect(error as? SemanticXMLError == .forbiddenDTD) }
                    else { #expect(error as? EPUBSemanticPackageError == .invalidPackage) }
                }
                let r = try #require(probe.reader)
                await #expect(throws: EPUBSemanticSourceError.closed) { try await r.catalog() }
            }
        }
    }
    @Test(arguments: [EPUBPackageProbe.Point.worker, .reader, .stage(.containerDecoded),
        .stage(.opfDecoded), .stage(.manifestItem(0)), .stage(.spineEntry(0)), .publication])
    func cancellationWithholdsPackageAndClosesReader(_ point: EPUBPackageProbe.Point) async throws {
        try await EPUBPackageFixture.withArchive(EPUBPackageFixture.archive()) { url in
            let probe = EPUBPackageProbe(point)
            let task = Task.detached { try await EPUBSemanticPackageLoader.load(fileURL: url, observation: probe.observation) }
            let started = await Task.detached { probe.wait() }.value
            #expect(started); task.cancel()
            let forwarded = await Task.detached { probe.waitForwarded() }.value
            #expect(forwarded); probe.release()
            await #expect(throws: CancellationError.self) { try await task.value }
            #expect(!probe.facts.timedOut && probe.facts.cancelled)
            if let r = probe.reader {
                await #expect(throws: EPUBSemanticSourceError.closed) { try await r.catalog() }
                await #expect(throws: EPUBSemanticSourceError.closed) { try await r.read(path: "OPS/book.opf") }
            } else { #expect(point == .worker) }
        }
    }
    @Test func cancellationBeforeOpenAndInvalidLimitsBeforeIO() async {
        let url = EPUBSemanticZIPFixture.temporaryURL()
        let gate = EPUBPackageProbe(.worker)
        let task = Task.detached { gate.pause(); return try await EPUBSemanticPackageLoader.load(fileURL: url) }
        let started = await Task.detached { gate.wait() }.value
        #expect(started); task.cancel(); gate.release()
        await #expect(throws: CancellationError.self) { try await task.value }
        for n in [0, -1, Int.max, 4097] {
            await #expect(throws: EPUBSemanticPackageError.invalidLimits) { try await EPUBSemanticPackageLoader.load(fileURL: url, packageLimits: .init(manifestItems: n)) }
            await #expect(throws: EPUBSemanticPackageError.invalidLimits) { try await EPUBSemanticPackageLoader.load(fileURL: url, packageLimits: .init(spineEntries: n)) }
        }
        for limits in [EPUBSemanticPackageLimits(propertiesPerItem: 65), .init(retainedUTF16: 2097153), .init(catalogUTF16: 2097153)] {
            await #expect(throws: EPUBSemanticPackageError.invalidLimits) { try await EPUBSemanticPackageLoader.load(fileURL: url, packageLimits: limits) }
        }
        await #expect(throws: EPUBSemanticSourceError.invalidLimits) { try await EPUBSemanticPackageLoader.load(fileURL: url, sourceLimits: .init(entries: 0)) }
        await #expect(throws: SemanticXMLError.invalidLimits) { try await EPUBSemanticPackageLoader.load(fileURL: url, xmlLimits: .init(inputBytes: 0)) }
    }
    @Test func independentConcurrentLoads() async throws {
        try await EPUBPackageFixture.withArchive(EPUBPackageFixture.archive()) { url in
            async let a = EPUBSemanticPackageLoader.load(fileURL: url)
            async let b = EPUBSemanticPackageLoader.load(fileURL: url)
            let pair = try await (a, b)
            #expect(pair.0 == pair.1)
        }
    }
    @Test func snapshotSurvivesPathReplacementAndExpectedRevisionRejectsNextOpen() async throws {
        let original = EPUBPackageFixture.archive()
        try await EPUBPackageFixture.withArchive(original) { url in
            let observation = EPUBPackageLoadObservation(readerCreated: { _ in
                try? EPUBPackageFixture.archive(opf: "<changed/>").write(to: url)
            })
            let p = try await EPUBSemanticPackageLoader.load(fileURL: url, observation: observation)
            #expect(p.spine.count == 1 && p.packageSHA256 == "e5790a7af90ec4b308d87ac31c1d829f1527601100107b911f37a4fe4de92549")
            await #expect(throws: EPUBSemanticSourceError.sourceChanged) { try await EPUBSemanticPackageLoader.load(fileURL: url, expectedArchiveSHA256: p.archiveSHA256) }
        }
    }
    @Test func deflatedMetadataUsesSameRealSubsystems() async throws {
        let c = Data(EPUBPackageFixture.container().utf8), p = Data(EPUBPackageFixture.opf().utf8)
        let zip = EPUBSemanticZIPFixture([
            .init(path: "META-INF/container.xml", bytes: c, compressed: EPUBSemanticZIPFixture.hex("4d8e310ec2301004bfe2ee0a94185a2bce1740e20517e70216f69d655f10fc9e8822d06db13bb34310568c4cd53ca9b628ece1d41fc1bc72e2e661adec045b6c8e3153731a9c14e259c29a89d57d6b6e87c03854115d62a2f68b665953ea0aeaddc3f972b593c8a397b280c93447ecf45dc80396926240dd3e58a1a9b46d111e78a3c326013b0ef60f6d77e5f801"), method: 8),
            .init(path: "OPS/book.opf", bytes: p, compressed: EPUBSemanticZIPFixture.hex("45ce410ac3201005d0abb89b45a986765128ea5d2419e3d068063334e9ed6b9a407703fff3fe580efd2b8ca8de58179a8b83bbee406d792a8b8324c24f63d675d53470d4731dcdadeb1e66e608cadb1c0a455cc45b12cc8a06073da85431b6230516ac7a4b92275019070a57f9303a08cc13f541da9ef9c5976daf186fcd5f5c980a1e70f39a7da8b0b7cecc9ccffb2f"), method: 8),
            .init(path: "OPS/chapter.xhtml")])
        try await EPUBPackageFixture.withArchive(zip) { url in
            let result = try await EPUBSemanticPackageLoader.load(fileURL: url)
            #expect(result.packageSHA256 == "e5790a7af90ec4b308d87ac31c1d829f1527601100107b911f37a4fe4de92549" && result.spine.count == 1)
        }
    }
}
