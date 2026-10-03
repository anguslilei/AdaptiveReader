// Purpose: Bounded classic-ZIP byte reads and explicit path/extra-field validation.
import Foundation

struct EPUBSourceZIPBytes {
    let data: Data
    func range(_ offset: Int, _ count: Int) throws -> Range<Int> {
        guard offset >= 0, count >= 0, offset <= data.count, count <= data.count - offset else {
            throw EPUBSemanticSourceError.invalidArchive
        }
        return offset..<(offset + count)
    }
    func u16(_ offset: Int) throws -> UInt16 {
        _ = try range(offset, 2)
        return UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }
    func u32(_ offset: Int) throws -> UInt32 {
        UInt32(try u16(offset)) | UInt32(try u16(offset + 2)) << 16
    }
    func validateExtra(_ range: Range<Int>) throws {
        var offset = range.lowerBound
        while offset < range.upperBound {
            try Task.checkCancellation()
            guard range.upperBound - offset >= 4 else { throw EPUBSemanticSourceError.invalidArchive }
            let id = try u16(offset), size = Int(try u16(offset + 2))
            guard size <= range.upperBound - offset - 4 else { throw EPUBSemanticSourceError.invalidArchive }
            guard ![UInt16(0x0001), 0x7075, 0x0008].contains(id) else {
                throw EPUBSemanticSourceError.unsupportedEntry
            }
            offset += 4 + size
        }
    }
    static func validatePath(_ path: String) throws {
        let candidate = path.hasSuffix("/") ? String(path.dropLast()) : path
        let components = candidate.split(separator: "/", omittingEmptySubsequences: false)
        guard !candidate.isEmpty, !path.contains("\\"), !path.contains("\0"),
              !path.hasPrefix("/"), !components[0].contains(":"),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw EPUBSemanticSourceError.unsafePath
        }
    }
}
