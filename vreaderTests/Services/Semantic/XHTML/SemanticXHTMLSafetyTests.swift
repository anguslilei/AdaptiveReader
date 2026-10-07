// Purpose: Fail-closed budgets, malformed inputs and actual worker cancellation.
import Foundation
import Testing
@testable import vreader

@Suite("Semantic XHTML safety", .serialized)
struct SemanticXHTMLSafetyTests {
    @Test(arguments: ["", "<html/>", "<html xmlns='http://www.w3.org/1999/xhtml'/>",
        "<html xmlns='http://www.w3.org/1999/xhtml'><body/><body/></html>",
        "<html xmlns='http://www.w3.org/1999/xhtml'><body/><head/></html>",
        "<html xmlns='http://www.w3.org/1999/xhtml'><head/><head/><body/></html>",
        "<html xmlns='http://www.w3.org/1999/xhtml'>text<body/></html>",
        "<html xmlns='http://www.w3.org/1999/xhtml'><other/><body/></html>",
        "<!DOCTYPE html [<!ENTITY evil SYSTEM 'file:///etc/passwd'>]><html/>",
        "<?xml version='1.0' encoding='ISO-8859-1'?><html/>",
        "<html xmlns='http://www.w3.org/1999/xhtml'><body>&unknown;</body></html>",
        "<html xmlns='http://www.w3.org/1999/xhtml'><body><p></body></html>"])
    func invalidDocumentsFail(_ xml: String) async {
        await #expect(throws: (any Error).self) {
            try await SemanticXHTMLExtractor.extract(resource: XHTMLTest.resource(xml), spineOccurrence: 0)
        }
    }

    @Test func semanticInclusiveLimits() async throws {
        let s = try await XHTMLTest.extract("<p>A<em>🙂</em></p><p>B</p>", limits: .init(blocks:2,runs:3,outputUTF16:4))
        #expect(s.blocks.count == 2)
        await #expect(throws: SemanticXHTMLError.blockLimit) {
            try await XHTMLTest.extract("<p/><p/>", limits: .init(blocks:1))
        }
        await #expect(throws: SemanticXHTMLError.runLimit) {
            try await XHTMLTest.extract("<p>A<em>B</em></p>", limits: .init(runs:1))
        }
        await #expect(throws: SemanticXHTMLError.outputLimit) {
            try await XHTMLTest.extract("<p>🙂</p>", limits: .init(outputUTF16:1))
        }
    }

    @Test(arguments: [0,-1,Int.max]) func invalidLimits(_ n: Int) async {
        for limits in [SemanticXHTMLLimits(blocks:n), .init(runs:n), .init(outputUTF16:n)] {
            await #expect(throws: SemanticXHTMLError.invalidLimits) { try await XHTMLTest.extract("", limits:limits) }
        }
        await #expect(throws: SemanticXMLError.invalidLimits) {
            try await XHTMLTest.extract("", limits: .init(xml:.init(depth:n)))
        }
    }

    @Test func xmlBudgetsAreEnforcedIndependently() async throws {
        let bytes = XHTMLTest.document("").utf8.count
        _ = try await XHTMLTest.extract("", limits:.init(xml:.init(inputBytes:bytes)))
        await #expect(throws: SemanticXMLError.inputLimit) { try await XHTMLTest.extract("", limits:.init(xml:.init(inputBytes:bytes-1))) }
        _ = try await XHTMLTest.extract("", limits:.init(xml:.init(nodes:3,depth:2,attributes:1)))
        await #expect(throws: SemanticXMLError.nodeLimit) { try await XHTMLTest.extract("<p/>",limits:.init(xml:.init(nodes:3))) }
        await #expect(throws: SemanticXMLError.depthLimit) { try await XHTMLTest.extract("<p/>",limits:.init(xml:.init(depth:2))) }
        await #expect(throws: SemanticXMLError.attributeLimit) { try await XHTMLTest.extract("<p a='1' b='2'/>",limits:.init(xml:.init(attributes:1))) }
        await #expect(throws: SemanticXMLError.textLimit) { try await XHTMLTest.extract("<p>A</p>",limits:.init(xml:.init(textUTF16:1))) }
    }

    @Test func sourceIdentityRejectsInvalidAndMismatchedInputs() async {
        let xml = XHTMLTest.document("<p>A</p>")
        await #expect(throws: SemanticXHTMLError.inconsistentSource) {
            try await SemanticXHTMLExtractor.extract(resource: XHTMLTest.resource(xml,digest:String(repeating:"0",count:64)),spineOccurrence:0)
        }
        for r in [XHTMLTest.resource(xml,digest:"bad"),XHTMLTest.resource(xml,path:"../bad"),XHTMLTest.resource(xml,archive:"BAD")] {
            await #expect(throws: (any Error).self) { try await SemanticXHTMLExtractor.extract(resource:r,spineOccurrence:0) }
        }
        for n in [-1,4096,Int.max] {
            await #expect(throws: SemanticModelError.invalidOccurrence) {
                try await XHTMLTest.extract("",occurrence:n)
            }
        }
    }

    @Test func cancellationBeforeEntry() async {
        let probe = SemanticXMLProbe()
        let task = Task { probe.block(); return try await XHTMLTest.extract("<p>A</p>") }
        #expect(probe.waitUntilBlocked()); task.cancel(); probe.signalRelease()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!probe.result().timedOut)
    }

    @Test(arguments: [0,1,2]) func cancellationAtWorkerTraversalAndPublication(_ stage: Int) async {
        let probe = SemanticXMLProbe()
        let observation = SemanticXHTMLObservation(
            workerStarted: { if stage == 0 { probe.block(recordCancellation:true) } },
            beforeNode: { _ in if stage == 1 { probe.onThirdEvent() } },
            beforePublication: { if stage == 2 { probe.block() } },
            cancellationForwarded: { probe.markForwarded() })
        let task = Task { try await SemanticXHTMLExtractor.extract(
            resource: XHTMLTest.resource(XHTMLTest.document("<p>A<em>B</em></p>")),
            spineOccurrence:0,observation:observation) }
        #expect(probe.waitUntilBlocked()); task.cancel()
        #expect(probe.waitUntilForwarded()); probe.signalRelease()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(!probe.result().timedOut)
        if stage != 2 { #expect(probe.result().childCancelled) }
    }

    @Test func independentConcurrentCalls() async throws {
        let expected = try await XHTMLTest.extract("<p>same🙂</p>")
        try await withThrowingTaskGroup(of:SemanticXHTMLSection.self) { group in
            for _ in 0..<16 { group.addTask { try await XHTMLTest.extract("<p>same🙂</p>") } }
            for try await result in group { #expect(result == expected) }
        }
    }
}
