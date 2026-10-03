// Purpose: Strict single-disk classic ZIP index, separate from the legacy renderer reader.
// Format reference: PKWARE APPNOTE 6.3.10, sections 4.3/4.4.
import Foundation

struct EPUBSourceZIPEntry: Sendable {
    let path: String
    let method: UInt16
    let crc: UInt32
    let size: Int
    let compressedRange: Range<Int>
    let localRange: Range<Int>
}

struct EPUBSourceZIPIndex: Sendable {
    let entries: [String: EPUBSourceZIPEntry]

    init(snapshot: Data, limits: EPUBSemanticLimits) throws {
        let b = EPUBSourceZIPBytes(data: snapshot)
        let end = try Self.findEOCD(b)
        let count = Int(try b.u16(end + 10))
        let directorySize = Int(try b.u32(end + 12))
        let directory = Int(try b.u32(end + 16))
        guard try b.u16(end + 4) == 0, try b.u16(end + 6) == 0,
              try b.u16(end + 8) == UInt16(count), count != 0xffff,
              directory != Int(UInt32.max), directorySize != Int(UInt32.max),
              directory <= end, directorySize == end - directory else {
            throw EPUBSemanticSourceError.invalidArchive
        }
        guard count <= limits.entries else { throw EPUBSemanticSourceError.limitExceeded }
        var index = [String: EPUBSourceZIPEntry](), offset = directory
        var spans = [Range<Int>]()
        for _ in 0..<count {
            try Task.checkCancellation()
            guard offset <= end, end - offset >= 46, try b.u32(offset) == 0x02014b50 else {
                throw EPUBSemanticSourceError.invalidArchive
            }
            let nameLength = Int(try b.u16(offset + 28))
            let extraLength = Int(try b.u16(offset + 30))
            let commentLength = Int(try b.u16(offset + 32))
            let recordSize = 46 + nameLength + extraLength + commentLength
            guard recordSize <= end - offset, try b.u16(offset + 34) == 0 else {
                throw EPUBSemanticSourceError.invalidArchive
            }
            let entry = try Self.parseEntry(b, central: offset, directory: directory, limits: limits)
            guard index[entry.path] == nil else { throw EPUBSemanticSourceError.duplicatePath }
            index[entry.path] = entry; spans.append(entry.localRange)
            offset += recordSize
        }
        guard offset == end else { throw EPUBSemanticSourceError.invalidArchive }
        var previousEnd = 0
        for span in spans.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            try Task.checkCancellation()
            guard span.lowerBound >= previousEnd else { throw EPUBSemanticSourceError.invalidArchive }
            previousEnd = span.upperBound
        }
        entries = index
    }

    private static func findEOCD(_ b: EPUBSourceZIPBytes) throws -> Int {
        guard b.data.count >= 22 else { throw EPUBSemanticSourceError.invalidArchive }
        let first = max(0, b.data.count - 65535 - 22)
        for offset in stride(from: b.data.count - 22, through: first, by: -1) {
            if offset % 4096 == 0 { try Task.checkCancellation() }
            if try b.u32(offset) == 0x06054b50,
               Int(try b.u16(offset + 20)) == b.data.count - offset - 22 { return offset }
        }
        throw EPUBSemanticSourceError.invalidArchive
    }

    private static func parseEntry(_ b: EPUBSourceZIPBytes, central c: Int, directory: Int,
                                   limits: EPUBSemanticLimits) throws -> EPUBSourceZIPEntry {
        let version = try b.u16(c + 6), flags = try b.u16(c + 8), method = try b.u16(c + 10)
        let crc = try b.u32(c + 16), packed = Int(try b.u32(c + 20)), size = Int(try b.u32(c + 24))
        let nameLength = Int(try b.u16(c + 28)), extraLength = Int(try b.u16(c + 30))
        let local = Int(try b.u32(c + 42)), attributes = try b.u32(c + 38)
        guard (method == 0 || method == 8), (version == 10 || version == 20),
              method != 8 || version == 20,
              flags & ~(method == 0 ? UInt16(0x0808) : UInt16(0x080e)) == 0,
              (attributes >> 16) & 0xf000 != 0xa000 else { throw EPUBSemanticSourceError.unsupportedEntry }
        guard packed <= limits.compressedBytes, size <= limits.resourceBytes,
              size <= max(1, packed) * limits.ratio else { throw EPUBSemanticSourceError.limitExceeded }
        let name = b.data.subdata(in: try b.range(c + 46, nameLength))
        guard flags & 0x0800 != 0 || name.allSatisfy({ $0 < 128 }) else {
            throw EPUBSemanticSourceError.unsupportedEntry
        }
        guard let path = String(data: name, encoding: .utf8) else { throw EPUBSemanticSourceError.unsafePath }
        try EPUBSourceZIPBytes.validatePath(path)
        try b.validateExtra(b.range(c + 46 + nameLength, extraLength))
        if path.hasSuffix("/") {
            guard method == 0, packed == 0, size == 0, crc == 0 else { throw EPUBSemanticSourceError.invalidArchive }
        }
        guard method != 0 || packed == size else { throw EPUBSemanticSourceError.invalidArchive }
        guard local <= directory, directory - local >= 30,
              try b.u32(local) == 0x04034b50, try b.u16(local + 4) == version,
              try b.u16(local + 6) == flags, try b.u16(local + 8) == method else {
            throw EPUBSemanticSourceError.invalidArchive
        }
        let localNameLength = Int(try b.u16(local + 26)), localExtraLength = Int(try b.u16(local + 28))
        let headerSize = 30 + localNameLength + localExtraLength
        guard headerSize <= directory - local,
              b.data.subdata(in: try b.range(local + 30, localNameLength)) == name else {
            throw EPUBSemanticSourceError.invalidArchive
        }
        try b.validateExtra(b.range(local + 30 + localNameLength, localExtraLength))
        for (offset, value) in [(14, crc), (18, UInt32(packed)), (22, UInt32(size))] {
            let observed = try b.u32(local + offset)
            guard observed == value || (flags & 8 != 0 && observed == 0) else {
                throw EPUBSemanticSourceError.invalidArchive
            }
        }
        let start = local + headerSize
        guard packed <= directory - start else { throw EPUBSemanticSourceError.invalidArchive }
        let dataEnd = start + packed
        let descriptor = flags & 8 == 0 ? 0 : try descriptorSize(b, at: dataEnd, before: directory,
                                                               crc: crc, packed: packed, size: size)
        return EPUBSourceZIPEntry(path: path, method: method, crc: crc, size: size,
                                  compressedRange: start..<dataEnd, localRange: local..<(dataEnd + descriptor))
    }

    private static func descriptorSize(_ b: EPUBSourceZIPBytes, at offset: Int, before end: Int,
                                       crc: UInt32, packed: Int, size: Int) throws -> Int {
        func matches(_ start: Int) throws -> Bool {
            guard start <= end, end - start >= 12 else { return false }
            return try b.u32(start) == crc && b.u32(start + 4) == UInt32(packed)
                && b.u32(start + 8) == UInt32(size)
        }
        if try matches(offset) { return 12 }
        if end - offset >= 16, try b.u32(offset) == 0x08074b50, try matches(offset + 4) { return 16 }
        throw EPUBSemanticSourceError.invalidArchive
    }
}
