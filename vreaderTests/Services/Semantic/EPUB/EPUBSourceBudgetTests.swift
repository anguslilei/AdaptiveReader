// Purpose: Actual decompression ceilings, cancellation and source-descriptor cleanup.
import Foundation
import Testing
import Darwin
@testable import vreader

@Suite("Semantic EPUB budgets and cancellation", .serialized)
struct EPUBSourceBudgetTests {
    typealias ZIP = EPUBSemanticZIPFixture

    @Test func invalidHardLimits() async {
        for limits in [EPUBSemanticLimits(archiveBytes: 0), EPUBSemanticLimits(entries: -1),
                       EPUBSemanticLimits(compressedBytes: Int.max), EPUBSemanticLimits(ratio: 201)] {
            await expectSemanticOpenFailure(ZIP(), error: .invalidLimits, limits: limits)
        }
    }

    @Test func declaredArchiveEntryResourceAndRatioLimits() async {
        for limits in [EPUBSemanticLimits(archiveBytes: 30), EPUBSemanticLimits(resourceBytes: 4),
                       EPUBSemanticLimits(compressedBytes: 4)] {
            await expectSemanticOpenFailure(ZIP(), error: .limitExceeded, limits: limits)
        }
        var second = ZIP.Member(); second.path = "second"
        await expectSemanticOpenFailure(ZIP([ZIP.Member(),second]), error: .limitExceeded,
                                        limits: EPUBSemanticLimits(entries: 1))
        var bomb = ZIP.Member(); bomb.method = 8; bomb.bytes = Data(repeating: 120, count: 10000)
        bomb.compressed = ZIP.hex("edc1010d000000c2a0da8f6f0e37a0000000000000000000e0df00")
        await expectSemanticOpenFailure(ZIP([bomb]), error: .limitExceeded)
    }

    @Test func dishonestActualOutputLimitAndSize() async throws {
        var m = ZIP.Member(); m.method = 8; m.bytes = Data(repeating: 120, count: 10000)
        m.compressed = ZIP.hex("edc1010d000000c2a0da8f6f0e37a0000000000000000000e0df00")
        m.declaredBytes = 1
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        try ZIP([m]).write(to: url)
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url,
                                                              limits: EPUBSemanticLimits(resourceBytes: 32))
        await expectSemanticReadFailure(reader, path: m.path, error: .limitExceeded)
        let reader2 = try await EPUBSemanticResourceReader.open(fileURL: url)
        await expectSemanticReadFailure(reader2, path: m.path, error: .limitExceeded) // actual ratio
        m.bytes = Data("hello".utf8); m.compressed = ZIP.hex("cb48cdc9c90700")
        try ZIP([m]).write(to: url)
        let reader3 = try await EPUBSemanticResourceReader.open(fileURL: url)
        await expectSemanticReadFailure(reader3, path: m.path, error: .integrityMismatch)
    }

    @Test func repeatedReadsChargeAggregateAndFailureCloses() async throws {
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        try ZIP().write(to: url)
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url,
                                                              limits: EPUBSemanticLimits(totalBytes: 9))
        #expect(try await reader.read(path: "chapter.xhtml").bytes.count == 5)
        await expectSemanticReadFailure(reader, path: "chapter.xhtml", error: .limitExceeded)
        await expectSemanticReadFailure(reader, path: "chapter.xhtml", error: .closed)
    }

    @Test func truncatedCorruptAndTrailingDeflate() async throws {
        for packed in [ZIP.hex("cb48"), Data([255,255]), ZIP.hex("cb48cdc9c9070000")] {
            var m = ZIP.Member(); m.method = 8; m.compressed = packed
            let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
            try ZIP([m]).write(to: url)
            let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
            await expectSemanticReadFailure(reader, path: m.path, error: .integrityMismatch)
        }
    }

    @Test func cancelledOpenAndReadNeverPublish() async throws {
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        try ZIP().write(to: url)
        let openTask = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
                await reader.close(); Issue.record("Cancelled open published reader")
            } catch { #expect(error is CancellationError) }
        }
        await openTask.value
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
        let readTask = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do { _ = try await reader.read(path: "chapter.xhtml"); Issue.record("Cancelled read published bytes") }
            catch { #expect(error is CancellationError) }
        }
        await readTask.value
        await expectSemanticReadFailure(reader, path: "chapter.xhtml", error: .closed)
    }

    @Test func midSnapshotCancellationClosesActualDescriptor() throws {
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        var m = ZIP.Member(); m.bytes = Data(repeating: 1, count: 100000)
        try ZIP([m]).write(to: url)
        var checks = 0, closeCount = 0, observedFD: Int32 = -1, closedFD: Int32 = -1, closeStatus: Int32 = -1
        do {
            _ = try EPUBSourceSnapshot.load(fileURL: url, checkCancellation: {
                checks += 1; if checks == 3 { throw CancellationError() }
            }, descriptorObserved: { observedFD = $0 }, descriptorClosed: {
                closedFD = $0; closeStatus = $1; closeCount += 1
            })
            Issue.record("Expected snapshot cancellation")
        } catch { #expect(error is CancellationError) }
        #expect(observedFD >= 0)
        #expect(closedFD == observedFD && closeCount == 1 && closeStatus == 0)
    }

    @Test func nonregularAndFinalSymlinkSourcesRejected() async throws {
        let target = ZIP.temporaryURL(), link = ZIP.temporaryURL(), fifo = ZIP.temporaryURL()
        defer {
            for u in [target,link,fifo] { try? FileManager.default.removeItem(at: u) }
        }
        try ZIP().write(to: target)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(mkfifo(fifo.path, 0o600) == 0)
        for url in [link, fifo, FileManager.default.temporaryDirectory] {
            do {
                let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
                await reader.close(); Issue.record("Nonregular source accepted")
            } catch { #expect(error as? EPUBSemanticSourceError == .invalidSource) }
        }
    }

    @Test func fileURLNULMustNotSelectAnExistingPrefix() async throws {
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        try ZIP().write(to: url)
        let encoded = try #require(URL(string: url.absoluteString + "%00suffix"))
        for evil in [URL(fileURLWithPath: url.path + "\0suffix"), encoded] {
            do {
                let reader = try await EPUBSemanticResourceReader.open(fileURL: evil)
                await reader.close(); Issue.record("NUL prefix path accepted")
            } catch { #expect(error as? EPUBSemanticSourceError == .invalidSource) }
        }
    }

    @Test func percentEncodedSourcePathsAreDecodedOnce() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reader space-%00-中-" + UUID().uuidString + ".zip")
        defer { try? FileManager.default.removeItem(at: url) }
        try ZIP().write(to: url)
        let reader = try await EPUBSemanticResourceReader.open(fileURL: url)
        #expect(try await reader.read(path: "chapter.xhtml").bytes == Data("hello".utf8))
        await reader.close()
    }

    @Test func changedDuringSnapshotReadIsRejected() throws {
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        let fixture = ZIP(); try fixture.write(to: url)
        var mutationFailed = false
        do {
            _ = try EPUBSourceSnapshot.load(fileURL: url, descriptorObserved: { _ in
                do { try (fixture.bytes + Data([0])).write(to: url) }
                catch { mutationFailed = true }
            })
            Issue.record("Changed source accepted")
        } catch { #expect(error as? EPUBSemanticSourceError == .sourceChanged) }
        #expect(!mutationFailed)
    }

    @Test(arguments: [EPUBSourceWorkerProbe.Stage.open, .publication])
    func cancellationAfterWorkerStarts(_ stage: EPUBSourceWorkerProbe.Stage) async throws {
        let url = ZIP.temporaryURL(); defer { try? FileManager.default.removeItem(at: url) }
        try ZIP().write(to: url)
        let probe = EPUBSourceWorkerProbe(stage: stage)
        let task = Task { try await EPUBSemanticResourceReader.open(fileURL: url, observation: probe.observation) }
        let started = await Task.detached { probe.waitForStart() }.value
        #expect(started)
        task.cancel(); probe.resume()
        do {
            let reader = try await task.value
            await reader.close(); Issue.record("Cancelled factory published a reader")
        } catch { #expect(error is CancellationError) }
        let facts = probe.facts
        #expect(!facts.timedOut && facts.fd >= 0 && facts.closeCount == 1)
        #expect(facts.closedFD == facts.fd && facts.closeStatus == 0)
        if stage == .open { #expect(facts.workerCancelled) }
        if let reader = facts.reader {
            await expectSemanticReadFailure(reader, path: "chapter.xhtml", error: .closed)
        } else { #expect(stage == .open) }
    }

}
