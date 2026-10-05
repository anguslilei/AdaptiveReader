// Purpose: Explicit bounded local URL subset, strict UTF8 decode once and root containment.
import Foundation

enum EPUBPackageReference {
    static func rootfilePath(_ reference: String) throws -> String {
        try resolve(reference, base: [])
    }
    static func resolve(href: String, packagePath: String) throws -> String {
        try EPUBSourceZIPBytes.validatePath(packagePath)
        guard !packagePath.hasSuffix("/") else { throw EPUBSemanticPackageError.unsafePath }
        let parts = components(packagePath)
        guard parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw EPUBSemanticPackageError.unsafePath
        }
        return try resolve(href, base: Array(parts.dropLast()))
    }
    private static func components(_ path: String) -> [String] {
        // ASCII slash is a delimiter even when the next scalar joins its grapheme.
        path.utf8.split(separator: 47, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
    }
    private static func hex(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: return byte - 48
        case 65...70: return byte - 55
        case 97...102: return byte - 87
        default: return nil
        }
    }
    private static func decode(_ reference: String) throws -> String {
        let bytes = Array(reference.utf8)
        guard !bytes.isEmpty, ![UInt8(9), 10, 13, 32].contains(bytes[0]),
              ![UInt8(9), 10, 13, 32].contains(bytes[bytes.count - 1]) else {
            throw EPUBSemanticPackageError.unsupportedReference
        }
        var decoded = [UInt8](), i = 0
        while i < bytes.count {
            try Task.checkCancellation()
            let byte = bytes[i]
            if byte == 37 {
                guard bytes.count - i >= 3, let a = hex(bytes[i + 1]), let b = hex(bytes[i + 2]) else {
                    throw EPUBSemanticPackageError.unsupportedReference
                }
                let value = a * 16 + b
                guard ![UInt8(0), 47, 92, 63, 35].contains(value) else {
                    throw EPUBSemanticPackageError.unsupportedReference
                }
                decoded.append(value); i += 3
            } else { decoded.append(byte); i += 1 }
        }
        guard let result = String(bytes: decoded, encoding: .utf8),
              !decoded.contains(where: { $0 < 32 || $0 == 127 || [UInt8(58), 92, 63, 35].contains($0) }),
              !decoded.isEmpty, ![UInt8(9), 10, 13, 32].contains(decoded[0]),
              ![UInt8(9), 10, 13, 32].contains(decoded[decoded.count - 1]) else {
            throw EPUBSemanticPackageError.unsupportedReference
        }
        if decoded.count >= 3 {
            for n in 0..<(decoded.count - 2) where decoded[n] == 37 {
                if hex(decoded[n + 1]) != nil && hex(decoded[n + 2]) != nil {
                    throw EPUBSemanticPackageError.unsupportedReference
                }
            }
        }
        return result
    }
    private static func resolve(_ reference: String, base: [String]) throws -> String {
        let decoded = try decode(reference)
        let parts = components(decoded)
        guard !parts.contains(where: \.isEmpty), let last = parts.last, last != ".", last != ".." else {
            throw EPUBSemanticPackageError.unsafePath
        }
        var path = base
        for part in parts {
            try Task.checkCancellation()
            if part == "." { continue }
            if part == ".." {
                guard !path.isEmpty else { throw EPUBSemanticPackageError.unsafePath }
                path.removeLast()
            } else { path.append(String(part)) }
        }
        let result = path.joined(separator: "/")
        try EPUBSourceZIPBytes.validatePath(result)
        return result
    }
}
