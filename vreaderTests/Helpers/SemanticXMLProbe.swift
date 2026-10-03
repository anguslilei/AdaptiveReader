// Purpose: Bounded synchronization of real parser work; no synthetic parse result.
import Foundation

final class SemanticXMLProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let arrived = DispatchSemaphore(value: 0)
    private let release = DispatchSemaphore(value: 0)
    private let forwarded = DispatchSemaphore(value: 0)
    private var timedOut = false
    private var childCancelled = false
    private var eventCount = 0

    func block(recordCancellation: Bool = false) {
        arrived.signal()
        let ok = release.wait(timeout: .now() + 5) == .success
        lock.lock(); timedOut = timedOut || !ok
        if recordCancellation { childCancelled = Task.isCancelled }
        lock.unlock()
    }
    func onThirdEvent() {
        lock.lock(); eventCount += 1; let blockNow = eventCount == 3; lock.unlock()
        if blockNow { block(recordCancellation: true) }
    }
    func waitUntilBlocked() -> Bool { arrived.wait(timeout: .now() + 5) == .success }
    func signalRelease() { release.signal() }
    func markForwarded() { forwarded.signal() }
    func waitUntilForwarded() -> Bool { forwarded.wait(timeout: .now() + 5) == .success }
    func result() -> (timedOut: Bool, childCancelled: Bool) {
        lock.lock(); defer { lock.unlock() }; return (timedOut, childCancelled)
    }
}
