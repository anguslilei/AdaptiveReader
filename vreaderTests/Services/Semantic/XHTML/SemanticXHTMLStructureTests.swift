// Purpose: Frozen logical XHTML policy, source order/ownership and deterministic IDs.
import Foundation
import Testing
@testable import vreader

@Suite("Semantic XHTML structure")
struct SemanticXHTMLStructureTests {
    @Test func emptyBodyAndEmptyBlocks() async throws {
        let empty = try await XHTMLTest.extract("")
        #expect(empty.blocks.isEmpty)
        #expect(empty.revision.extractorVersion == 1)
        let section = try await XHTMLTest.extract("<p/><figure/><ul><li/></ul>")
        #expect(section.blocks.map(\.role) == [.paragraph, .figure, .list, .listItem])
        #expect(section.blocks.map(\.parentIndex) == [nil, nil, nil, 2])
    }

    @Test func headingsAndInlineLogicalText() async throws {
        let body = (1...6).map { "<h\($0)>Title\($0)</h\($0)>" }.joined()
            + "<p>A<strong>B</strong><a href='https://example.invalid'>C</a></p>"
        let s = try await XHTMLTest.extract(body)
        #expect(s.blocks.count == 7)
        #expect(s.blocks.prefix(6).map(\.headingLevel) == [1,2,3,4,5,6])
        #expect(s.blocks.last?.runs.map(\.text) == ["A", "B", "C"])
        #expect(s.blocks.last?.role == .paragraph)
    }

    @Test func nestedContainersHaveNearestEmittedParent() async throws {
        let s = try await XHTMLTest.extract("<blockquote><ul><li>one<figure><figcaption>cap</figcaption></figure></li></ul></blockquote>")
        #expect(s.blocks.map(\.role) == [.quote, .list, .listItem, .figure, .caption])
        #expect(s.blocks.map(\.parentIndex) == [nil,0,1,2,3])
        #expect(s.blocks.map { $0.runs.map(\.text) } == [[],[],["one"],[],["cap"]])
    }

    @Test func mixedContentKeepsOwnershipWithoutDoubleCounting() async throws {
        let s = try await XHTMLTest.extract("<p>A<img src='missing'/>B<h2>H<p>P</p>Z</h2>C</p>")
        #expect(s.blocks.map(\.role) == [.paragraph,.opaque,.heading,.paragraph])
        #expect(s.blocks.map(\.parentIndex) == [nil,0,0,2])
        #expect(s.blocks.map { $0.runs.map(\.text) } == [["A","B","C"],[],["H","Z"],["P"]])
        let paths = s.blocks.flatMap(\.runs).map { $0.anchor.nodePath }
        #expect(Set(paths).count == paths.count)
    }

    @Test func retainedChildSlotsCountCommentsPIAndWhitespace() async throws {
        let s = try await XHTMLTest.extract(" \n<!--c--><?pi x?><p>A<em>B</em>C</p>")
        #expect(s.blocks.count == 1)
        #expect(s.blocks[0].anchor.nodePath.components == [1,3])
        #expect(s.blocks[0].runs.map { $0.anchor.nodePath.components } == [[1,3,0],[1,3,1,0],[1,3,2]])
        #expect(s.blocks[0].anchor.textRange == nil)
    }

    @Test func unsupportedSubtreesAreOpaqueWithoutDescendantLeakage() async throws {
        let tags = ["table","pre","script","style","template","iframe","object","unknown"]
        let body = tags.map { "<\($0)><p>not flattened</p></\($0)>" }.joined()
            + "<svg xmlns='http://www.w3.org/2000/svg'><text>vector</text></svg>"
            + "<math xmlns='http://www.w3.org/1998/Math/MathML'><mi>x</mi></math><br/><img/><hr/>"
        let s = try await XHTMLTest.extract(body)
        #expect(s.blocks.count == 13)
        #expect(s.blocks.allSatisfy { $0.role == .opaque && $0.runs.isEmpty })
    }

    @Test func transparentFallbackAndWhitespace() async throws {
        let s = try await XHTMLTest.extract(" \t<div>free<span>text</span> </div><p> \t</p>&#160;")
        #expect(s.blocks.map(\.role) == [.opaque,.opaque,.paragraph,.opaque])
        #expect(s.blocks.map { $0.runs.map(\.text) } == [["free"],["text"],[" \t"],["\u{a0}"]])
        #expect(s.blocks.allSatisfy { $0.parentIndex == nil })
    }

    @Test func unicodeEntitiesCDATAAndNewlinePreserveLogicalScalars() async throws {
        let s = try await XHTMLTest.extract("<p>中文🙂e\u{301}👩‍👩‍👧‍👦 العربية\r\n&amp;&#xA0;<![CDATA[<x>]]></p>")
        let run = try #require(s.blocks.first?.runs.first)
        let expected = "中文🙂e\u{301}👩‍👩‍👧‍👦 العربية\n&\u{a0}<x>"
        #expect(run.text.utf8.elementsEqual(expected.utf8))
        #expect(run.anchor.textRange?.lowerBound == 0)
        #expect(run.anchor.textRange?.upperBound == expected.utf16.count)
        try run.anchor.textRange?.validate(in: run.text)
    }

    @Test func prefixedNamespaceAndCaseSensitiveUnknownTags() async throws {
        let xml = "<x:html xmlns:x='\(XHTMLTest.ns)'><x:body><x:p>A</x:p><x:P>B</x:P><p xmlns='wrong'>C</p></x:body></x:html>"
        let s = try await SemanticXHTMLExtractor.extract(resource: XHTMLTest.resource(xml), spineOccurrence: 0)
        #expect(s.blocks.map(\.role) == [.paragraph,.opaque,.opaque])
        #expect(s.blocks[0].runs.first?.text == "A")
    }

    @Test func deterministicIDsBindSourceOccurrenceAndArchive() async throws {
        let a = try await XHTMLTest.extract("<p>same</p><p>same</p>")
        let again = try await XHTMLTest.extract("<p>same</p><p>same</p>")
        let repeated = try await XHTMLTest.extract("<p>same</p><p>same</p>", occurrence: 1)
        #expect(a == again)
        #expect(a.id != repeated.id)
        #expect(a.blocks[0].id != a.blocks[1].id)
        #expect(a.blocks[0].id != repeated.blocks[0].id)
        #expect(a.id == (try SemanticID.section(revision: a.revision, resource: a.resource, spineOccurrence: 0)))
        for (ordinal, block) in a.blocks.enumerated() {
            #expect(block.id == (try SemanticID.block(revision: a.revision, anchor: block.anchor, role: block.role, ordinal: ordinal)))
        }
        let r = XHTMLTest.resource(XHTMLTest.document("<p>same</p><p>same</p>"), archive: String(repeating: "b",count:64))
        let changed = try await SemanticXHTMLExtractor.extract(resource: r, spineOccurrence: 0)
        #expect(a.id != changed.id)
    }
}
