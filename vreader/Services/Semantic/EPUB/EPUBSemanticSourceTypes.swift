// Purpose: Limits, verified-byte DTO and errors for the independent semantic source reader.
import Foundation

struct EPUBSemanticLimits: Sendable {
    let archiveBytes: Int
    let entries: Int
    let compressedBytes: Int
    let resourceBytes: Int
    let totalBytes: Int
    let ratio: Int

    init(archiveBytes: Int = 64 * 1024 * 1024, entries: Int = 4096,
         compressedBytes: Int = 8 * 1024 * 1024, resourceBytes: Int = 4 * 1024 * 1024,
         totalBytes: Int = 16 * 1024 * 1024, ratio: Int = 200) {
        self.archiveBytes = archiveBytes
        self.entries = entries
        self.compressedBytes = compressedBytes
        self.resourceBytes = resourceBytes
        self.totalBytes = totalBytes
        self.ratio = ratio
    }

    func validate() throws {
        let standard = EPUBSemanticLimits()
        let values = [archiveBytes, entries, compressedBytes, resourceBytes, totalBytes, ratio]
        let ceilings = [standard.archiveBytes, standard.entries, standard.compressedBytes,
                        standard.resourceBytes, standard.totalBytes, standard.ratio]
        guard zip(values, ceilings).allSatisfy({ pair in pair.0 > 0 && pair.0 <= pair.1 }) else {
            throw EPUBSemanticSourceError.invalidLimits
        }
    }
}

struct EPUBSemanticResource: Sendable {
    let path: String
    let bytes: Data
    let sha256: String
    let archiveSHA256: String
}

struct EPUBSemanticResourceCatalog: Sendable {
    let archiveSHA256: String
    let paths: [String]
}

enum EPUBSemanticSourceError: Error, Sendable, Equatable {
    case invalidLimits, invalidDigest, invalidArchive, unsafePath, duplicatePath
    case unsupportedEntry, limitExceeded, integrityMismatch, resourceNotFound
    case closed, sourceChanged, invalidSource, ioFailure
}
