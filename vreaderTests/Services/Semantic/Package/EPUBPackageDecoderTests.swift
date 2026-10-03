// Purpose: Real XML tree decoding, literal resource/ID identity and independent bounds.
import Foundation
import Testing
@testable import vreader

@Suite("EPUB package manifest and spine")
struct EPUBPackageDecoderTests {
    @Test(arguments: ["2.0", "3.0"])
    func orderedRepeatedAndAuxiliarySpine(_ version: String) async throws {
        let xml = EPUBPackageFixture.opf(items: EPUBPackageFixture.item(extra: "properties='nav scripted'"),
            refs: "<itemref idref='c' linear='no' properties='aux'/><itemref idref='c'/><itemref idref='c' linear='yes'/>", version: version)
        let p = try await EPUBPackageFixture.decode(xml)
        #expect(p.manifestItems == [.init(id: "c", path: "OPS/chapter.xhtml", mediaType: "application/xhtml+xml", properties: ["nav", "scripted"])])
        #expect(p.spine.map(\.occurrence) == [0, 1, 2] && p.spine.map(\.manifestIndex) == [0, 0, 0])
        #expect(p.spine.map(\.linear) == [false, true, true] && p.spine[0].properties == ["aux"])
    }
    @Test func literalIDsAndPropertyTokens() async throws {
        let items = EPUBPackageFixture.item("é", "a.xhtml", extra: "properties='é e&#x301;' ") + EPUBPackageFixture.item("e\u{301}", "b.xhtml")
        let p = try await EPUBPackageFixture.decode(EPUBPackageFixture.opf(items: items, refs: "<itemref idref='e&#x301;'/><itemref idref='é'/>"), paths: ["OPS/a.xhtml", "OPS/b.xhtml"])
        #expect(p.spine.map(\.manifestIndex) == [1, 0])
        #expect(p.manifestItems[0].properties.map { Array($0.utf8) } == [Array("é".utf8), Array("e\u{301}".utf8)])
    }
    @Test func prefixedContainerAndPackageAndIgnoredDocumentNodes() async throws {
        let c = "<!--pre--><?x y?><x:container xmlns:x='\(EPUBPackageFixture.containerNS)' version='1.0'><x:rootfiles><!--a--><x:rootfile full-path='OPS/book.opf' media-type='application/oebps-package+xml'/></x:rootfiles></x:container>"
        let doc = try await SemanticXMLParser.parse(Data(c.utf8))
        #expect(try EPUBContainerDecoder.decode(document: doc, catalog: EPUBPackageFixture.catalog()) == "OPS/book.opf")
        let p = EPUBPackageFixture.opf().replacingOccurrences(of: "xmlns=", with: "xmlns:o=")
            .replacingOccurrences(of: "<package", with: "<o:package").replacingOccurrences(of: "</package", with: "</o:package")
            .replacingOccurrences(of: "<manifest", with: "<o:manifest").replacingOccurrences(of: "</manifest", with: "</o:manifest")
            .replacingOccurrences(of: "<spine", with: "<o:spine").replacingOccurrences(of: "</spine", with: "</o:spine")
            .replacingOccurrences(of: "<item", with: "<o:item")
        #expect(try await EPUBPackageFixture.decode(p).spine.count == 1)
    }
    @Test(arguments: ["OPS/%E4%B8%AD.opf", "OPS/100%25done.opf"])
    func containerURLIsRootRelativeAndDecodedOnce(_ path: String) async throws {
        let expected = path.contains("%E4") ? "OPS/中.opf" : "OPS/100%done.opf"
        let d = try await SemanticXMLParser.parse(Data(EPUBPackageFixture.container(path).utf8))
        #expect(try EPUBContainerDecoder.decode(document: d, catalog: EPUBPackageFixture.catalog([expected])) == expected)
    }
    @Test(arguments: [
        ("version='1.0'", "version='2.0'"), ("version='1.0'", ""),
        (EPUBPackageFixture.containerNS, "urn:spoof"), ("<rootfiles>", "<wrapper><rootfiles>"),
        ("</rootfiles>", "</rootfiles><rootfiles/>"), ("application/oebps-package+xml", "text/xml"),
        ("full-path=", "xmlns:x='urn:x' x:full-path="), ("OPS/book.opf", "missing.opf"),
        ("OPS/book.opf", "OPS/book.opf/"), ("OPS/book.opf", "OPS/child/.."),
        ("<rootfiles>", "<rootfiles xml:base='x'>"), ("<rootfiles>", "<rootfiles><xi:include xmlns:xi='http://www.w3.org/2001/XInclude' href='x'/>"),
        ("</rootfiles>", "<rootfile full-path='OPS/book.opf' media-type='application/oebps-package+xml'/></rootfiles>")
    ])
    func containerRejectsInvalidStructures(_ old: String, _ new: String) async {
        await #expect(throws: (any Error).self) {
            let doc = try await SemanticXMLParser.parse(Data(EPUBPackageFixture.container().replacingOccurrences(of: old, with: new).utf8))
            return try EPUBContainerDecoder.decode(document: doc, catalog: EPUBPackageFixture.catalog(["OPS/book.opf", "OPS"]))
        }
    }
    @Test(arguments: [
        ("version='3.0'", "version='4.0'"), ("version='3.0'", ""),
        (EPUBPackageFixture.opfNS, "urn:spoof"), ("<manifest>", "<wrapper><manifest>"),
        ("</manifest>", "</manifest><manifest/>"), ("</spine>", "</spine><spine/>"),
        ("id='c'", "xmlns:x='urn:x' x:id='c'"), ("id='c'", "id=''"), ("id='c'", "id='a b'"),
        ("href='chapter.xhtml'", "href='missing.xhtml'"), ("href='chapter.xhtml'", "href='Chapter.xhtml'"),
        ("media-type='application/xhtml+xml'", "media-type='image/svg+xml'"),
        ("media-type='application/xhtml+xml'", "media-type='text/html; charset=UTF-8'"),
        ("media-type='application/xhtml+xml'", "media-type='text//html'"),
        ("<item id=", "<item fallback='' id="), ("<manifest>", "<manifest xml:base='sub/'>"),
        ("<itemref idref='c'/>", ""), ("<itemref idref='c'/>", "<itemref idref='x'/>"),
        ("<itemref idref='c'/>", "<itemref idref='c' linear='no'/>"),
        ("<itemref idref='c'/>", "<itemref idref='c' linear='true'/>"),
        ("<itemref idref='c'/>", "<itemref idref='c' properties='a a'/>"),
        ("<item id=", "<item properties='a a' id=")
    ])
    func packageRejectsInvalidStructures(_ old: String, _ new: String) async {
        await #expect(throws: (any Error).self) { try await EPUBPackageFixture.decode(EPUBPackageFixture.opf().replacingOccurrences(of: old, with: new)) }
    }
    @Test func duplicateIDsAndNormalizedPathsReject() async {
        await #expect(throws: EPUBSemanticPackageError.duplicateManifestID) {
            try await EPUBPackageFixture.decode(EPUBPackageFixture.opf(items: EPUBPackageFixture.item() + EPUBPackageFixture.item("c", "a.xhtml")), paths: ["OPS/chapter.xhtml", "OPS/a.xhtml"])
        }
        await #expect(throws: EPUBSemanticPackageError.duplicateResourcePath) {
            try await EPUBPackageFixture.decode(EPUBPackageFixture.opf(items: EPUBPackageFixture.item() + EPUBPackageFixture.item("b", "./chapter.xhtml")))
        }
    }
    @Test func fileLookupCannotUseCanonicalEquivalence() async {
        await #expect(throws: EPUBSemanticPackageError.missingResource) {
            try await EPUBPackageFixture.decode(EPUBPackageFixture.opf(items: EPUBPackageFixture.item("c", "e\u{301}.xhtml")), paths: ["OPS/é.xhtml"])
        }
    }
    @Test func assetsAndMediaCasingAndOpaqueMetadata() async throws {
        let xml = EPUBPackageFixture.opf(items: EPUBPackageFixture.item(media: "APPLICATION/XHTML+XML") + EPUBPackageFixture.item("image", "i.png", media: "image/png"))
            .replacingOccurrences(of: "<manifest>", with: "<metadata><meta property='rendition:layout'>pre-paginated</meta></metadata><manifest>")
        #expect(try await EPUBPackageFixture.decode(xml, paths: ["OPS/chapter.xhtml", "OPS/i.png"]).manifestItems.count == 2)
        await #expect(throws: EPUBSemanticPackageError.missingResource) { try await EPUBPackageFixture.decode(xml) }
    }
    @Test func propertyXMLWhitespaceIncludesAdjacentCRLFReferences() async throws {
        let p = try await EPUBPackageFixture.decode(EPUBPackageFixture.opf(items: EPUBPackageFixture.item(extra: "properties='a&#13;&#10;b'")))
        #expect(p.manifestItems[0].properties == ["a", "b"])
    }
    @Test func validNestedWrappersCannotReplaceDirectWrappers() async {
        let xml = EPUBPackageFixture.opf().replacingOccurrences(of: "<manifest>", with: "<wrapper><manifest>").replacingOccurrences(of: "</manifest>", with: "</manifest></wrapper>")
        await #expect(throws: EPUBSemanticPackageError.invalidPackage) { try await EPUBPackageFixture.decode(xml) }
        let c = EPUBPackageFixture.container().replacingOccurrences(of: "<rootfiles>", with: "<wrapper><rootfiles>").replacingOccurrences(of: "</rootfiles>", with: "</rootfiles></wrapper>")
        await #expect(throws: EPUBSemanticPackageError.invalidContainer) {
            try EPUBContainerDecoder.decode(document: await SemanticXMLParser.parse(Data(c.utf8)), catalog: EPUBPackageFixture.catalog())
        }
    }
    @Test(arguments: [1, 64])
    func trailingXMLWhitespaceDoesNotConsumePropertySlots(_ cap: Int) async throws {
        let tokens = (0..<cap).map { "p" + String($0) }
        let xml = EPUBPackageFixture.opf(items: EPUBPackageFixture.item(extra: "properties='" + tokens.joined(separator: " ") + "   '"))
        #expect(try await EPUBPackageFixture.decode(xml, limits: .init(propertiesPerItem: cap)).manifestItems[0].properties == tokens)
    }
    @Test func exactAndExceededIndependentBudgets() async throws {
        // Independently counted: packagePath12 + id1 + path17 + media21 = 51 UTF16 units.
        #expect(try await EPUBPackageFixture.decode(limits: .init(manifestItems: 1, spineEntries: 1, retainedUTF16: 51)).spine.count == 1)
        await #expect(throws: EPUBSemanticPackageError.metadataLimit) { try await EPUBPackageFixture.decode(limits: .init(retainedUTF16: 50)) }
        let twice = EPUBPackageFixture.opf(refs: "<itemref idref='c' properties='ab'/><itemref idref='c' properties='ab'/>")
        #expect(try await EPUBPackageFixture.decode(twice, limits: .init(retainedUTF16: 55)).spine.count == 2)
        await #expect(throws: EPUBSemanticPackageError.metadataLimit) { try await EPUBPackageFixture.decode(twice, limits: .init(retainedUTF16: 54)) }
        await #expect(throws: EPUBSemanticPackageError.metadataLimit) { try await EPUBPackageFixture.decode(twice, limits: .init(spineEntries: 1)) }
        let props = EPUBPackageFixture.opf(items: EPUBPackageFixture.item(extra: "properties='a b'"))
        #expect(try await EPUBPackageFixture.decode(props, limits: .init(propertiesPerItem: 2)).manifestItems[0].properties.count == 2)
        await #expect(throws: EPUBSemanticPackageError.metadataLimit) { try await EPUBPackageFixture.decode(props, limits: .init(propertiesPerItem: 1)) }
        let items = EPUBPackageFixture.opf(items: EPUBPackageFixture.item() + EPUBPackageFixture.item("b", "b.xhtml"))
        await #expect(throws: EPUBSemanticPackageError.metadataLimit) { try await EPUBPackageFixture.decode(items, paths: ["OPS/chapter.xhtml", "OPS/b.xhtml"], limits: .init(manifestItems: 1)) }
        // Catalog 22+12+17 =51 is independent of retained DTO payload.
        #expect(try await EPUBPackageFixture.decode(limits: .init(catalogUTF16: 51)).spine.count == 1)
        await #expect(throws: EPUBSemanticPackageError.metadataLimit) { try await EPUBPackageFixture.decode(limits: .init(catalogUTF16: 50)) }
    }
}
