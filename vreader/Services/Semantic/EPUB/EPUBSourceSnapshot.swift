// Purpose: One bounded immutable source revision; never reopens a live renderer path.
import Foundation
import CryptoKit
import Darwin
import OSLog

struct EPUBSourceSnapshot: Sendable {
    let bytes: Data
    let sha256: String

    static func load(fileURL: URL, expectedSHA256: String? = nil,
                     limits: EPUBSemanticLimits = EPUBSemanticLimits(),
                     checkCancellation: () throws -> Void = { try Task.checkCancellation() },
                     descriptorObserved: (Int32) -> Void = { _ in }) throws -> Self {
        try limits.validate(); try checkCancellation()
        guard fileURL.isFileURL else { throw EPUBSemanticSourceError.invalidSource }
        if let digest = expectedSHA256 {
            guard digest.utf8.count == 64,
                  digest.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
                throw EPUBSemanticSourceError.invalidDigest
            }
        }
        let fd = fileURL.path.withCString { Darwin.open($0, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC) }
        guard fd >= 0 else {
            throw errno == ELOOP ? EPUBSemanticSourceError.invalidSource : .ioFailure
        }
        defer {
            if Darwin.close(fd) != 0 {
                Logger(subsystem: "com.vreader.app", category: "SemanticSource").error("Source descriptor cleanup failed")
            }
        }
        let before = try stamp(fd)
        guard before.regular, before.size >= 0 else { throw EPUBSemanticSourceError.invalidSource }
        guard before.size <= Int64(limits.archiveBytes) else { throw EPUBSemanticSourceError.limitExceeded }
        descriptorObserved(fd)
        let file = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        var bytes = Data(), digest = SHA256()
        while true {
            try checkCancellation()
            let room = limits.archiveBytes - bytes.count
            let chunk: Data
            do { chunk = try file.read(upToCount: min(65536, room + 1)) ?? Data() }
            catch { throw EPUBSemanticSourceError.ioFailure }
            if chunk.isEmpty { break }
            guard chunk.count <= room else { throw EPUBSemanticSourceError.limitExceeded }
            bytes.append(chunk); digest.update(data: chunk)
        }
        try checkCancellation()
        guard try stamp(fd) == before, Int64(bytes.count) == before.size else {
            throw EPUBSemanticSourceError.sourceChanged
        }
        let sha = digest.finalize().map { String(format: "%02x", $0) }.joined()
        guard expectedSHA256 == nil || expectedSHA256 == sha else { throw EPUBSemanticSourceError.integrityMismatch }
        return Self(bytes: bytes, sha256: sha)
    }

    private struct Stamp: Equatable {
        let device: Int64, inode: UInt64, size: Int64
        let modifiedSeconds: Int64, modifiedNanoseconds: Int64
        let changedSeconds: Int64, changedNanoseconds: Int64
        let regular: Bool
    }
    private static func stamp(_ fd: Int32) throws -> Stamp {
        var s = stat()
        guard fstat(fd, &s) == 0 else { throw EPUBSemanticSourceError.ioFailure }
        return Stamp(device: Int64(s.st_dev), inode: UInt64(s.st_ino), size: Int64(s.st_size),
                     modifiedSeconds: Int64(s.st_mtimespec.tv_sec), modifiedNanoseconds: Int64(s.st_mtimespec.tv_nsec),
                     changedSeconds: Int64(s.st_ctimespec.tv_sec), changedNanoseconds: Int64(s.st_ctimespec.tv_nsec),
                     regular: (s.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG))
    }
}
