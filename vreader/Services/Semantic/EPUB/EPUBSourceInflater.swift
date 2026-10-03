// Purpose: Bounded raw-DEFLATE/stored extraction with exact stream/length/CRC checks.
import Foundation
import zlib

struct EPUBSourceInflater {
    static func extract(_ entry: EPUBSourceZIPEntry, from snapshot: Data,
                        limits: EPUBSemanticLimits, remaining: Int) throws -> Data {
        try Task.checkCancellation()
        let packed = snapshot.subdata(in: entry.compressedRange)
        let ceiling = min(limits.resourceBytes, min(remaining, max(1, packed.count) * limits.ratio))
        var output = Data()
        if entry.method == 0 {
            var offset = 0
            while offset < packed.count {
                try Task.checkCancellation()
                let count = min(32768, packed.count - offset)
                guard count <= ceiling - output.count else { throw EPUBSemanticSourceError.limitExceeded }
                output.append(packed[offset..<(offset + count)]); offset += count
            }
        } else {
            var stream = z_stream()
            guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION,
                                Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                throw EPUBSemanticSourceError.integrityMismatch
            }
            defer { inflateEnd(&stream) }
            try packed.withUnsafeBytes { input in
                stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(packed.count)
                var scratch = [UInt8](repeating: 0, count: 32768)
                while true {
                    try Task.checkCancellation()
                    let previousInput = stream.avail_in
                    let capacity = min(scratch.count, ceiling - output.count + 1)
                    let status = scratch.withUnsafeMutableBufferPointer { buffer in
                        stream.next_out = buffer.baseAddress; stream.avail_out = uInt(capacity)
                        return inflate(&stream, Z_NO_FLUSH)
                    }
                    let produced = capacity - Int(stream.avail_out)
                    guard produced <= ceiling - output.count else { throw EPUBSemanticSourceError.limitExceeded }
                    output.append(contentsOf: scratch.prefix(produced))
                    if status == Z_STREAM_END {
                        guard stream.avail_in == 0 else { throw EPUBSemanticSourceError.integrityMismatch }
                        break
                    }
                    guard status == Z_OK, produced > 0 || stream.avail_in < previousInput else {
                        throw EPUBSemanticSourceError.integrityMismatch
                    }
                }
            }
        }
        try Task.checkCancellation()
        guard output.count == entry.size else { throw EPUBSemanticSourceError.integrityMismatch }
        let crc = output.withUnsafeBytes {
            UInt32(crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(output.count)))
        }
        guard crc == entry.crc else { throw EPUBSemanticSourceError.integrityMismatch }
        return output
    }
}
