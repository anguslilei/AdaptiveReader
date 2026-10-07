// Purpose: Real ZIP/package/resource/XML composition, not stubbed bytes or metadata.
import Foundation
import Testing
@testable import vreader

@Suite("Semantic XHTML integration")
struct SemanticXHTMLIntegrationTests {
    @Test func pinnedPackageResourceAndEveryLogicalTextPath() async throws {
        let xml = XHTMLTest.document("<!--slot--><h1>Title</h1><blockquote><p>中<em>🙂</em>end</p></blockquote>")
        let archive = EPUBPackageFixture.archive(opf: EPUBPackageFixture.opf(refs:"<itemref idref='c'/><itemref idref='c'/>"),
            assets:[.init(path:"OPS/chapter.xhtml",bytes:Data(xml.utf8)),
                    .init(path:"OPS/unused.xhtml",bytes:Data("invalid XML".utf8),crc:0)])
        try await EPUBPackageFixture.withArchive(archive) { url in
            let package = try await EPUBSemanticPackageLoader.load(fileURL:url)
            let reader = try await EPUBSemanticResourceReader.open(fileURL:url,expectedArchiveSHA256:package.archiveSHA256)
            do {
                var results: [SemanticXHTMLSection] = []
                for entry in package.spine {
                    let resource = try await reader.read(path:package.manifestItems[entry.manifestIndex].path)
                    let s = try await SemanticXHTMLExtractor.extract(resource:resource,spineOccurrence:entry.occurrence)
                    #expect(s.revision.archiveSHA256.hex == package.archiveSHA256)
                    #expect(resource.archiveSHA256 == package.archiveSHA256)
                    #expect(s.resource.sha256.hex == resource.sha256)
                    let tree = try await SemanticXMLParser.parse(resource.bytes)
                    var paths = Set<SemanticNodePath>()
                    for block in s.blocks {
                        for run in block.runs {
                            var index = tree.rootIndex
                            for slot in run.anchor.nodePath.components { index = tree.nodes[index].children[slot] }
                            guard case .text(let original) = tree.nodes[index].kind else { Issue.record("run path not text"); continue }
                            #expect(original.utf8.elementsEqual(run.text.utf8))
                            #expect(run.anchor.textRange?.upperBound == original.utf16.count)
                            #expect(paths.insert(run.anchor.nodePath).inserted)
                        }
                    }
                    #expect(paths.count == 4)
                    results.append(s)
                }
                #expect(results[0].id != results[1].id)
                #expect(results[0].blocks[0].id != results[1].blocks[0].id)
                await reader.close()
            } catch { await reader.close(); throw error }
        }
    }

    @Test func replacementBetweenPackageAndReopenRejectsMixedRevision() async throws {
        let first = EPUBPackageFixture.archive(assets:[.init(path:"OPS/chapter.xhtml",bytes:Data(XHTMLTest.document("<p>first</p>").utf8))])
        try await EPUBPackageFixture.withArchive(first) { url in
            let p = try await EPUBSemanticPackageLoader.load(fileURL:url)
            try EPUBPackageFixture.archive(assets:[.init(path:"OPS/chapter.xhtml",bytes:Data(XHTMLTest.document("<p>other</p>").utf8))]).write(to:url)
            await #expect(throws: EPUBSemanticSourceError.integrityMismatch) {
                try await EPUBSemanticResourceReader.open(fileURL:url,expectedArchiveSHA256:p.archiveSHA256)
            }
        }
    }

    @Test func failedExtractionDoesNotPoisonIndependentRequest() async throws {
        await #expect(throws: SemanticXHTMLError.blockLimit) {
            try await XHTMLTest.extract("<p/><p/>",limits:.init(blocks:1))
        }
        let result = try await XHTMLTest.extract("<p>later</p>")
        #expect(result.blocks.first?.runs.first?.text == "later")
    }
}
