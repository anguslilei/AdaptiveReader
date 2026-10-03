// Purpose: Native logical-tree fidelity through the real parser API.
import Foundation
import Testing
@testable import vreader

@Suite("Semantic XML logical structure")
struct SemanticXMLParserTests {
    private func parse(_ xml: String) async throws -> SemanticXMLDocument {
        try await SemanticXMLParser.parse(Data(xml.utf8))
    }

    @Test func emptyElementAndIndependentDigest() async throws {
        let d = try await parse("<r/>")
        #expect(d.rootIndex == 0 && d.nodes.count == 1)
        #expect(d.nodes[0].kind == .element(SemanticXMLName(localName: "r", namespaceURI: nil, qualifiedName: "r")))
        #expect(d.nodes[0].parent == nil && d.nodes[0].children.isEmpty)
        #expect(d.sourceSHA256 == "5382511e672645156e2889ebc21c72a0e59377fcbe774abaa703e0a42b3d2006")
    }

    @Test func mixedContentKeepsOrderedParentChildTail() async throws {
        let d = try await parse("<p>before<b>bold</b>after</p>")
        #expect(d.nodes[0].children == [1, 2, 4])
        #expect(d.nodes[1].kind == .text("before"))
        #expect(d.nodes[2].children == [3] && d.nodes[3].kind == .text("bold"))
        #expect(d.nodes[4].kind == .text("after"))
        #expect(d.nodes[3].parent == 2 && d.nodes[4].parent == 0)
    }

    @Test func namespacesAttributesAndRebindingRetainDeclarations() async throws {
        let d = try await parse("<r xmlns='urn:u' xmlns:x='urn:v' x:a='1' xml:lang='zh'><x:c xmlns:x='urn:w'/><plain xmlns=''/></r>")
        let root = d.nodes[d.rootIndex]
        #expect(root.kind == .element(SemanticXMLName(localName: "r", namespaceURI: "urn:u", qualifiedName: "r")))
        #expect(root.attributes == ["xmlns": "urn:u", "xmlns:x": "urn:v", "x:a": "1", "xml:lang": "zh"])
        #expect(d.nodes[1].kind == .element(SemanticXMLName(localName: "c", namespaceURI: "urn:w", qualifiedName: "x:c")))
        #expect(d.nodes[1].attributes == ["xmlns:x": "urn:w"])
        #expect(d.nodes[2].kind == .element(SemanticXMLName(localName: "plain", namespaceURI: nil, qualifiedName: "plain")))
        #expect(d.nodes[2].attributes == ["xmlns": ""])
    }

    @Test func attributeOnlyNamespaceAndInheritedPrefix() async throws {
        let d = try await parse("<x:r xmlns:x='urn:u' xmlns:y='urn:v' y:k='a'><x:c y:k='b'/></x:r>")
        #expect(d.nodes[0].attributes == ["xmlns:x": "urn:u", "xmlns:y": "urn:v", "y:k": "a"])
        #expect(d.nodes[1].attributes == ["y:k": "b"])
        #expect(d.nodes[1].kind == .element(SemanticXMLName(localName: "c", namespaceURI: "urn:u", qualifiedName: "x:c")))
    }

    @Test func textAndCDATAAndEntitiesCoalesceExactlyOnce() async throws {
        let d = try await parse("<r>a&amp;<![CDATA[<b>]]>&amp;lt;&#x1F600;</r>")
        #expect(d.nodes.count == 2 && d.nodes[0].children == [1])
        #expect(d.nodes[1].kind == .text("a&<b>&lt;😀"))
    }

    @Test func commentAndPISplitTextAndPreserveDocumentNodes() async throws {
        let d = try await parse("<!--pre--><?before x?><r>a<!--c-->b<?inside d?>c</r><!--post-->")
        #expect(d.rootIndex == 2 && d.nodes.count == 9)
        #expect(d.nodes[0].kind == .comment("pre"))
        #expect(d.nodes[1].kind == .processingInstruction(target: "before", data: "x"))
        #expect(d.nodes[2].children == [3, 4, 5, 6, 7])
        #expect(d.nodes[3].kind == .text("a") && d.nodes[5].kind == .text("b") && d.nodes[7].kind == .text("c"))
        #expect(d.nodes[4].kind == .comment("c"))
        #expect(d.nodes[6].kind == .processingInstruction(target: "inside", data: "d"))
        #expect(d.nodes[8].parent == nil && d.nodes[8].kind == .comment("post"))
    }

    @Test(arguments: ["中文标点。", "👩‍💻😀", "e\u{301}", "שלום العربية"])
    func unicodeIsNotSilentlyNormalized(_ text: String) async throws {
        let d = try await parse("<r>" + text + "</r>")
        guard case .text(let actual) = d.nodes[1].kind else { Issue.record("missing text"); return }
        #expect(Array(actual.utf16) == Array(text.utf16))
    }

    @Test func XMLLineEndsAndAttributesNormalizeWithoutSemanticFolding() async throws {
        let d = try await parse("<r a='x\r\ny&#x9;z'>a\r\nb\rc<![CDATA[d\r\ne\rf]]></r>")
        #expect(d.nodes[0].attributes["a"] == "x y\tz")
        #expect(d.nodes[1].kind == .text("a\nb\ncd\ne\nf"))
    }

    @Test func UTF8BOMAndDeclarationRetainRawDigestIdentity() async throws {
        let s = "<?xml version='1.0' encoding='utf-8'?><r>中</r>"
        let a = try await parse(s)
        let b = try await SemanticXMLParser.parse(Data([0xEF, 0xBB, 0xBF]) + Data(s.utf8))
        #expect(a.nodes == b.nodes && a.sourceSHA256 != b.sourceSHA256)
    }

    @Test func opaqueStructuresAndScriptsAreRetainedForLaterPolicy() async throws {
        let d = try await parse("<r><script>source()</script><style>x{}</style><table/><m:math xmlns:m='urn:m'/></r>")
        #expect(d.nodes[0].children.count == 4)
        #expect(d.nodes[2].kind == .text("source()"))
        #expect(d.nodes[4].kind == .text("x{}"))
    }

    @Test func independentConcurrentParsesAreDeterministic() async throws {
        async let a = parse("<r><c>中</c></r>")
        async let b = parse("<r><c>中</c></r>")
        let pair = try await (a, b)
        #expect(pair.0 == pair.1)
    }

    @Test func manyFragments() async throws {
        let d = try await parse("<r>" + String(repeating: "a&amp;", count: 4096) + "</r>")
        #expect(d.nodes.count == 2 && d.nodes[1].kind == .text(String(repeating: "a&", count: 4096)))
    }
    @Test func UnicodeNamesAndLiteralNamespaceURIsRemainDistinct() async throws {
        let a = try await parse("<书 属性='中'><节/></书>")
        #expect(a.nodes[0].attributes == ["属性": "中"])
        #expect(a.nodes[1].kind == .element(SemanticXMLName(localName: "节", namespaceURI: nil, qualifiedName: "节")))
        let d = try await parse("<r xmlns:x='urn:é' xmlns:y='urn:e\u{301}' x:a='1' y:a='2'/>")
        #expect(d.nodes[0].attributes["x:a"] == "1" && d.nodes[0].attributes["y:a"] == "2")
        let uri = try #require(d.nodes[0].attributes["xmlns:y"])
        #expect(Array(uri.utf8) == Array("urn:e\u{301}".utf8))
    }
}
