// Purpose: Actual detached parser cancellation and publication rejection.
import Foundation
import Testing
@testable import vreader

@Suite("Semantic XML cancellation", .serialized)
struct SemanticXMLCancellationTests {
    private func requireCancellation(_ task: Task<SemanticXMLDocument, any Error>) async {
        do { _ = try await task.value; Issue.record("cancelled parser published a document") }
        catch { #expect(error is CancellationError) }
    }

    @Test func cancelledBeforeParse() async {
        let probe = SemanticXMLProbe()
        let task = Task {
            probe.block()
            return try await SemanticXMLParser.parse(Data("<r/>".utf8))
        }
        #expect(probe.waitUntilBlocked())
        task.cancel(); probe.signalRelease()
        await requireCancellation(task)
        #expect(!probe.result().timedOut)
    }

    @Test func cancellationForwardsAfterActualWorkerStart() async {
        let probe = SemanticXMLProbe()
        let observation = SemanticXMLParseObservation(workerStarted: { probe.block(recordCancellation: true) },
                                                      cancellationForwarded: { probe.markForwarded() })
        let task = Task { try await SemanticXMLParser.parse(Data("<r/>".utf8), observation: observation) }
        #expect(probe.waitUntilBlocked())
        task.cancel(); #expect(probe.waitUntilForwarded()); probe.signalRelease()
        await requireCancellation(task)
        #expect(probe.result().childCancelled && !probe.result().timedOut)
    }

    @Test func cancellationDuringRealParserCallbacks() async {
        let probe = SemanticXMLProbe()
        let observation = SemanticXMLParseObservation(beforeEvent: { probe.onThirdEvent() },
                                                      cancellationForwarded: { probe.markForwarded() })
        let task = Task { try await SemanticXMLParser.parse(Data("<r><c>actual</c></r>".utf8), observation: observation) }
        #expect(probe.waitUntilBlocked())
        task.cancel(); #expect(probe.waitUntilForwarded()); probe.signalRelease()
        await requireCancellation(task)
        #expect(probe.result().childCancelled && !probe.result().timedOut)
    }

    @Test func cancelledBeforePublicationWithholdsCompletedTree() async {
        let probe = SemanticXMLProbe()
        let observation = SemanticXMLParseObservation(beforePublication: { probe.block() })
        let task = Task { try await SemanticXMLParser.parse(Data("<r>completed</r>".utf8), observation: observation) }
        #expect(probe.waitUntilBlocked())
        task.cancel(); probe.signalRelease()
        await requireCancellation(task)
        #expect(!probe.result().timedOut)
    }
}
