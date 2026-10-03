// Purpose: Exact classic ZIP fixtures and corruption mutations for semantic source contracts.
import Foundation
import zlib

struct EPUBSemanticZIPFixture {
    enum Descriptor: Equatable, Sendable { case none, signed, unsigned }
    struct Member {
        var path = "chapter.xhtml"
        var bytes = Data("hello".utf8)
        var compressed: Data? = nil
        var method: UInt16 = 0
        var flags: UInt16 = 0x0800
        var declaredBytes: UInt32? = nil
        var crc: UInt32? = nil
        var descriptor: Descriptor = .none
        var attributes: UInt32 = 0
        var extra = Data()
    }
    var bytes: Data
    let localOffsets: [Int]
    let centralOffsets: [Int]
    let directoryOffset: Int
    let eocdOffset: Int

    init(_ members: [Member] = [Member()], comment: Data = Data()) {
        var data = Data(), locals = [Int](), centrals = [Int]()
        for member in members {
            let name = Data(member.path.utf8), packed = member.compressed ?? member.bytes
            let crc = member.crc ?? Self.crc(member.bytes)
            let size = member.declaredBytes ?? UInt32(member.bytes.count)
            let flags = member.flags | (member.descriptor == .none ? 0 : 8)
            locals.append(data.count)
            data.add32(0x04034b50); data.add16(20); data.add16(flags)
            data.add16(member.method); data.add16(0); data.add16(0)
            data.add32(flags & 8 == 0 ? crc : 0)
            data.add32(flags & 8 == 0 ? UInt32(packed.count) : 0)
            data.add32(flags & 8 == 0 ? size : 0)
            data.add16(UInt16(name.count)); data.add16(UInt16(member.extra.count))
            data.append(name); data.append(member.extra); data.append(packed)
            if member.descriptor != .none {
                if member.descriptor == .signed { data.add32(0x08074b50) }
                data.add32(crc); data.add32(UInt32(packed.count)); data.add32(size)
            }
        }
        let directoryOffset = data.count
        for (i, member) in members.enumerated() {
            let name = Data(member.path.utf8), packed = member.compressed ?? member.bytes
            centrals.append(data.count)
            data.add32(0x02014b50); data.add16(0x0314); data.add16(20)
            data.add16(member.flags | (member.descriptor == .none ? 0 : 8))
            data.add16(member.method); data.add16(0); data.add16(0)
            data.add32(member.crc ?? Self.crc(member.bytes))
            data.add32(UInt32(packed.count)); data.add32(member.declaredBytes ?? UInt32(member.bytes.count))
            data.add16(UInt16(name.count)); data.add16(UInt16(member.extra.count))
            data.add16(0); data.add16(0); data.add16(0); data.add32(member.attributes)
            data.add32(UInt32(locals[i])); data.append(name); data.append(member.extra)
        }
        let eocd = data.count
        data.add32(0x06054b50); data.add16(0); data.add16(0)
        data.add16(UInt16(members.count)); data.add16(UInt16(members.count))
        data.add32(UInt32(eocd - directoryOffset)); data.add32(UInt32(directoryOffset))
        data.add16(UInt16(comment.count)); data.append(comment)
        bytes = data; localOffsets = locals; centralOffsets = centrals
        self.directoryOffset = directoryOffset; eocdOffset = eocd
    }

    static func crc(_ bytes: Data) -> UInt32 {
        bytes.withUnsafeBytes { raw in
            UInt32(crc32(0, raw.bindMemory(to: UInt8.self).baseAddress, uInt(bytes.count)))
        }
    }
    static func hex(_ value: String) -> Data {
        var bytes = Data(), i = value.startIndex
        while i < value.endIndex {
            let end = value.index(i, offsetBy: 2)
            bytes.append(UInt8(value[i..<end], radix: 16)!); i = end
        }
        return bytes
    }
    static func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".epub")
    }
    func write(to url: URL) throws { try bytes.write(to: url) }
}

extension Data {
    mutating func add16(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value)); append(UInt8(truncatingIfNeeded: value >> 8))
    }
    mutating func add32(_ value: UInt32) {
        add16(UInt16(truncatingIfNeeded: value)); add16(UInt16(truncatingIfNeeded: value >> 16))
    }
    mutating func set16(_ offset: Int, _ value: UInt16) {
        var d = Data(); d.add16(value); replaceSubrange(offset..<(offset + 2), with: d)
    }
    mutating func set32(_ offset: Int, _ value: UInt32) {
        var d = Data(); d.add32(value); replaceSubrange(offset..<(offset + 4), with: d)
    }
}
