// Purpose: Bound and validate original UTF8 before handing bytes to Foundation XML.
import Foundation

enum SemanticXMLPreflight {
    static func validate(_ data: Data, limits: SemanticXMLLimits,
                         check: @Sendable () throws -> Void) throws -> [SemanticXMLStartTag] {
        try check()
        guard data.count <= limits.inputBytes else { throw SemanticXMLError.inputLimit }
        guard String(data: data, encoding: .utf8) != nil, !data.contains(0) else {
            throw SemanticXMLError.unsupportedEncoding
        }
        try check()
        let bytes = Array(data)
        let start = bytes.starts(with: [0xEF, 0xBB, 0xBF]) ? 3 : 0
        if matches(bytes, Array("<?xml".utf8), at: start), start + 5 < bytes.count,
           [UInt8(9), 10, 13, 32].contains(bytes[start + 5]) {
            let cap = min(bytes.count, start + limits.declarationBytes)
            var end = start + 5
            while end + 1 < cap && !matches(bytes, [63, 62], at: end) { end += 1 }
            guard end + 1 < cap else { throw SemanticXMLError.inputLimit }
            let declaration = String(decoding: bytes[start..<end + 2], as: UTF8.self)
            guard try field("version", in: declaration) == "1.0" else { throw SemanticXMLError.invalidXML }
            if let encoding = try field("encoding", in: declaration), encoding.uppercased() != "UTF-8" {
                throw SemanticXMLError.unsupportedEncoding
            }
        }
        var i = start
        var tags: [SemanticXMLStartTag] = []
        var lexicalUnits = 0
        while i < bytes.count {
            if i % 4096 == 0 { try check() }
            guard bytes[i] == 60 else { i += 1; continue }
            if matches(bytes, Array("<!--".utf8), at: i) {
                i = try after(bytes, start: i + 4, end: Array("-->".utf8), check: check)
            } else if matches(bytes, Array("<![CDATA[".utf8), at: i) {
                i = try after(bytes, start: i + 9, end: Array("]]>".utf8), check: check)
            } else if matches(bytes, [60, 63], at: i) {
                i = try after(bytes, start: i + 2, end: [63, 62], check: check)
            } else if matches(bytes, Array("<!DOCTYPE".utf8), at: i) || matches(bytes, Array("<!ENTITY".utf8), at: i) {
                throw SemanticXMLError.forbiddenDTD
            } else if i + 1 < bytes.count && bytes[i + 1] != 47 && bytes[i + 1] != 33 {
                guard tags.count < limits.nodes else { throw SemanticXMLError.nodeLimit }
                tags.append(try SemanticXMLStartTags.read(bytes, at: &i, units: &lexicalUnits, limits: limits, check: check))
            } else {
                i += 1
                var quote: UInt8?
                while i < bytes.count {
                    if i % 4096 == 0 { try check() }
                    let byte = bytes[i]
                    if let current = quote { if byte == current { quote = nil } }
                    else if byte == 34 || byte == 39 { quote = byte }
                    else if byte == 62 { i += 1; break }
                    i += 1
                }
            }
        }
        try check()
        return tags
    }

    private static func field(_ key: String, in declaration: String) throws -> String? {
        let regex = try NSRegularExpression(pattern: "(?:^|\\s)" + key + "\\s*=\\s*(['\"])([^'\"]+)\\1")
        guard let match = regex.firstMatch(in: declaration, range: NSRange(declaration.startIndex..., in: declaration)),
              let range = Range(match.range(at: 2), in: declaration) else { return nil }
        return String(declaration[range])
    }

    private static func matches(_ bytes: [UInt8], _ literal: [UInt8], at index: Int) -> Bool {
        index >= 0 && index <= bytes.count && literal.count <= bytes.count - index &&
            bytes[index..<index + literal.count].elementsEqual(literal)
    }

    private static func after(_ bytes: [UInt8], start: Int, end: [UInt8],
                              check: @Sendable () throws -> Void) throws -> Int {
        var i = start
        while i < bytes.count {
            if i % 4096 == 0 { try check() }
            if matches(bytes, end, at: i) { return i + end.count }
            i += 1
        }
        throw SemanticXMLError.invalidXML
    }
}
