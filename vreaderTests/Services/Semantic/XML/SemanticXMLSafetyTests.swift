// Purpose: Strict XML/encoding/security rejection and actual retained-data limits.
import Foundation
import Testing
@testable import vreader

func expectXMLError(_ bytes: Data, _ expected: SemanticXMLError,
                    limits: SemanticXMLLimits = SemanticXMLLimits()) async {
    do { _ = try await SemanticXMLParser.parse(bytes, limits: limits); Issue.record("accepted forbidden XML") }
    catch { #expect(error as? SemanticXMLError == expected) }
}

@Suite("Semantic XML safety and budgets")
struct SemanticXMLSafetyTests {
    @Test(arguments: ["", "<r>", "<a/><b/>", "<r a='1' a='2'/>", "<x:r/>", "<r x:a='1'/>", "<x:y:r/>", "<r x:y:a='1'/>",
                      "<r xmlns:x='urn:u' xmlns:y='urn:u' x:a='1' y:a='2'/>",
                      "<r xmlns:xml='urn:wrong'/>", "<r xmlns:xmlns='urn:x'/>", "<r xmlns:x=''/>",
                      "<r xmlns='http://www.w3.org/XML/1998/namespace'/>",
                      "<r>&nbsp;</r>", "<r>&unknown;</r>", "<r>&#0;</r>", "<!--bad--comment--><r/>"])
    func malformedNeverPublishesPartialTree(_ xml: String) async {
        await expectXMLError(Data(xml.utf8), .invalidXML)
    }

    @Test(arguments: ["<!DOCTYPE r><r/>", "<!DOCTYPE r SYSTEM 'file:///tmp/secret'><r/>",
                      "<!DOCTYPE r SYSTEM 'https://example.invalid/dtd'><r/>",
                      "<!DOCTYPE r [<!ENTITY x 'boom'>]><r>&x;</r>",
                      "<!DOCTYPE r [<!ENTITY % x SYSTEM 'file:///tmp/secret'>%x;]><r/>",
                      "<!ENTITY x 'boom'><r/>"])
    func declarationsRejectedBeforeEntityProcessing(_ xml: String) async {
        await expectXMLError(Data(xml.utf8), .forbiddenDTD)
    }

    @Test(arguments: ["<r><!--<!DOCTYPE r>--></r>", "<r><![CDATA[<!DOCTYPE r>]]></r>",
                      "<?p <!DOCTYPE r>?><r/>", "<r a='&lt;!DOCTYPE r>'/>",
                      "<?xml-stylesheet encoding='latin1'?><r/>"])
    func inertDeclarationTextIsNotADeclaration(_ xml: String) async throws {
        _ = try await SemanticXMLParser.parse(Data(xml.utf8))
    }

    @Test(arguments: [Data([0xFF, 0xFE, 0x3C, 0]), Data([0xC0, 0xAF]), Data("<r>\0</r>".utf8),
                      Data("<?xml version='1.0' encoding='ISO-8859-1'?><r/>".utf8)])
    func unsupportedEncodingNeverGuesses(_ bytes: Data) async {
        await expectXMLError(bytes, .unsupportedEncoding)
    }

    @Test func XML11AndHugeDeclarationsAreRejected() async {
        await expectXMLError(Data("<?xml version='1.1'?><r/>".utf8), .invalidXML)
        await expectXMLError(Data(("<?xml version='1.0' " + String(repeating: " ", count: 1024) + "?><r/>").utf8), .inputLimit)
    }

    @Test(arguments: [0, -1, Int.max])
    func invalidConfigurations(_ n: Int) async {
        let limits = [SemanticXMLLimits(inputBytes: n), SemanticXMLLimits(nodes: n), SemanticXMLLimits(depth: n),
                      SemanticXMLLimits(attributes: n), SemanticXMLLimits(textUTF16: n), SemanticXMLLimits(declarationBytes: n)]
        for value in limits { await expectXMLError(Data("<r/>".utf8), .invalidLimits, limits: value) }
    }

    @Test func aboveHardCeilings() async {
        let limits = [SemanticXMLLimits(inputBytes: 4 * 1024 * 1024 + 1), SemanticXMLLimits(nodes: 50001),
                      SemanticXMLLimits(depth: 97), SemanticXMLLimits(attributes: 129),
                      SemanticXMLLimits(textUTF16: 2 * 1024 * 1024 + 1), SemanticXMLLimits(declarationBytes: 1025)]
        for value in limits { await expectXMLError(Data("<r/>".utf8), .invalidLimits, limits: value) }
    }

    @Test func exactAndOverInputNodeAndDepthCaps() async throws {
        _ = try await SemanticXMLParser.parse(Data("<r/>".utf8), limits: SemanticXMLLimits(inputBytes: 4, nodes: 1, depth: 1))
        await expectXMLError(Data("<r/> ".utf8), .inputLimit, limits: SemanticXMLLimits(inputBytes: 4))
        await expectXMLError(Data("<r>a</r>".utf8), .nodeLimit, limits: SemanticXMLLimits(nodes: 1))
        _ = try await SemanticXMLParser.parse(Data("<r><c/></r>".utf8), limits: SemanticXMLLimits(nodes: 2, depth: 2))
        await expectXMLError(Data("<r><c/></r>".utf8), .depthLimit, limits: SemanticXMLLimits(depth: 1))
    }

    @Test func exactAndOverAttributesIncludingNamespaceDeclarations() async throws {
        let xml = Data("<r xmlns='urn:u' xmlns:x='urn:v' x:a='b'/>".utf8)
        _ = try await SemanticXMLParser.parse(xml, limits: SemanticXMLLimits(attributes: 3))
        await expectXMLError(xml, .attributeLimit, limits: SemanticXMLLimits(attributes: 2))
        await expectXMLError(Data("<r xmlns='urn:u' xmlns:x='urn:v'/>".utf8), .attributeLimit, limits: SemanticXMLLimits(attributes: 1))
        _ = try await SemanticXMLParser.parse(Data("<r a='b'/>".utf8), limits: SemanticXMLLimits(attributes: 1))
    }

    @Test func UTF16BudgetCoversAllRetainedFieldsExactlyOnce() async throws {
        _ = try await SemanticXMLParser.parse(Data("<r>😀</r>".utf8), limits: SemanticXMLLimits(textUTF16: 4))
        await expectXMLError(Data("<r>😀</r>".utf8), .textLimit, limits: SemanticXMLLimits(textUTF16: 3))
        _ = try await SemanticXMLParser.parse(Data("<r a='b'/>".utf8), limits: SemanticXMLLimits(textUTF16: 4))
        await expectXMLError(Data("<r a='b'/>".utf8), .textLimit, limits: SemanticXMLLimits(textUTF16: 3))
        // xmlns key5 + value5 + root local1/URI5/qualified1 =17.
        _ = try await SemanticXMLParser.parse(Data("<r xmlns='urn:u'/>".utf8), limits: SemanticXMLLimits(textUTF16: 17))
        await expectXMLError(Data("<r xmlns='urn:u'/>".utf8), .textLimit, limits: SemanticXMLLimits(textUTF16: 16))
        await expectXMLError(Data("<r><!--abc--></r>".utf8), .textLimit, limits: SemanticXMLLimits(textUTF16: 4))
        await expectXMLError(Data("<r><?p abc?></r>".utf8), .textLimit, limits: SemanticXMLLimits(textUTF16: 4))
    }

    @Test func fragmentedTextAndDocumentCommentsCannotBypassLimits() async {
        await expectXMLError(Data("<r>a&amp;<![CDATA[b]]></r>".utf8), .textLimit, limits: SemanticXMLLimits(textUTF16: 4))
        await expectXMLError(Data("<!--a--><r/><!--b-->".utf8), .nodeLimit, limits: SemanticXMLLimits(nodes: 2))
    }
}
