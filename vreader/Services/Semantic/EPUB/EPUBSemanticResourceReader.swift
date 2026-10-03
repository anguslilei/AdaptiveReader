// Purpose: Independent actor owning a bounded immutable source revision and read budget.
import Foundation
import CryptoKit

actor EPUBSemanticResourceReader {
    private var snapshot: EPUBSourceSnapshot?
    private var index: [String: EPUBSourceZIPEntry]
    private let limits: EPUBSemanticLimits
    private var totalBytes = 0

    private init(snapshot: EPUBSourceSnapshot, index: EPUBSourceZIPIndex, limits: EPUBSemanticLimits) {
        self.snapshot = snapshot; self.index = index.entries; self.limits = limits
    }

    static func open(fileURL: URL, expectedArchiveSHA256: String? = nil,
                     limits: EPUBSemanticLimits = EPUBSemanticLimits(),
                     observation: EPUBSourceLoadObservation? = nil) async throws -> EPUBSemanticResourceReader {
        try Task.checkCancellation()
        let worker = Task.detached {
            let snapshot = try EPUBSourceSnapshot.load(fileURL: fileURL,
                                                      expectedSHA256: expectedArchiveSHA256, limits: limits,
                                                      descriptorObserved: { observation?.opened($0) },
                                                      descriptorClosed: { observation?.closed($0, $1) })
            let index = try EPUBSourceZIPIndex(snapshot: snapshot.bytes, limits: limits)
            try Task.checkCancellation()
            return EPUBSemanticResourceReader(snapshot: snapshot, index: index, limits: limits)
        }
        return try await withTaskCancellationHandler {
            let reader = try await worker.value
            observation?.beforePublication(reader)
            do { try Task.checkCancellation(); return reader }
            catch { await reader.close(); throw error }
        } onCancel: { worker.cancel() }
    }

    func read(path: String) throws -> EPUBSemanticResource {
        guard let snapshot else { throw EPUBSemanticSourceError.closed }
        do {
            try Task.checkCancellation()
            try EPUBSourceZIPBytes.validatePath(path)
            guard let entry = index[path], !entry.path.hasSuffix("/") else {
                throw EPUBSemanticSourceError.resourceNotFound
            }
            let bytes = try EPUBSourceInflater.extract(entry, from: snapshot.bytes,
                                                       limits: limits, remaining: limits.totalBytes - totalBytes)
            let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
            try Task.checkCancellation()
            totalBytes += bytes.count
            return EPUBSemanticResource(path: entry.path, bytes: bytes, sha256: digest,
                                        archiveSHA256: snapshot.sha256)
        } catch {
            close(); throw error
        }
    }
    func close() { snapshot = nil; index.removeAll(keepingCapacity: false) }
}
