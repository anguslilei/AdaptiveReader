// Purpose: Original lexical names detect attributes/declarations Foundation silently drops.
import Foundation

struct SemanticXMLStartTag {
    let qualifiedName: String
    let attributes: [String]
}

enum SemanticXMLStartTags {
    private static func whitespace(_ byte: UInt8) -> Bool { [UInt8(9), 10, 13, 32].contains(byte) }

    static func read(_ bytes: [UInt8], at index: inout Int, units: inout Int, limits: SemanticXMLLimits,
                     check: @Sendable () throws -> Void) throws -> SemanticXMLStartTag {
        index += 1 // '<'
        let element = try name(bytes, at: &index, units: &units, limits: limits, check: check)
        var attributes: [String] = []
        while index < bytes.count {
            try skipWhitespace(bytes, at: &index, check: check)
            guard index < bytes.count else { break }
            if bytes[index] == 62 { index += 1; return SemanticXMLStartTag(qualifiedName: element, attributes: attributes) }
            if bytes[index] == 47 {
                guard index + 1 < bytes.count, bytes[index + 1] == 62 else { throw SemanticXMLError.invalidXML }
                index += 2; return SemanticXMLStartTag(qualifiedName: element, attributes: attributes)
            }
            guard attributes.count < limits.attributes else { throw SemanticXMLError.attributeLimit }
            let attribute = try name(bytes, at: &index, units: &units, limits: limits, check: check)
            try skipWhitespace(bytes, at: &index, check: check)
            guard index < bytes.count, bytes[index] == 61 else { throw SemanticXMLError.invalidXML }
            index += 1
            try skipWhitespace(bytes, at: &index, check: check)
            guard index < bytes.count, bytes[index] == 34 || bytes[index] == 39 else { throw SemanticXMLError.invalidXML }
            let quote = bytes[index]; index += 1
            while index < bytes.count && bytes[index] != quote {
                if index % 4096 == 0 { try check() }
                guard bytes[index] != 60 else { throw SemanticXMLError.invalidXML }
                index += 1
            }
            guard index < bytes.count else { throw SemanticXMLError.invalidXML }
            index += 1; attributes.append(attribute)
        }
        throw SemanticXMLError.invalidXML
    }
    private static func skipWhitespace(_ bytes: [UInt8], at index: inout Int,
                                       check: @Sendable () throws -> Void) throws {
        while index < bytes.count && whitespace(bytes[index]) {
            if index % 4096 == 0 { try check() }; index += 1
        }
    }
    private static func name(_ bytes: [UInt8], at index: inout Int, units: inout Int,
                             limits: SemanticXMLLimits, check: @Sendable () throws -> Void) throws -> String {
        let start = index
        while index < bytes.count && !whitespace(bytes[index]) && ![UInt8(47), 62, 61].contains(bytes[index]) {
            if index % 4096 == 0 { try check() }; index += 1
        }
        guard index > start else { throw SemanticXMLError.invalidXML }
        let string = String(decoding: bytes[start..<index], as: UTF8.self)
        let count = string.utf16.count
        guard count <= limits.textUTF16 - units else { throw SemanticXMLError.textLimit }
        units += count
        return string
    }
}
