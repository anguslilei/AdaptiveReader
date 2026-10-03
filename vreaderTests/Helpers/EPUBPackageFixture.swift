// Purpose: Tiny deterministic real ZIP/XML integration fixtures (CI fixture exception).
import Foundation
@testable import vreader

enum EPUBPackageFixture {
    static let containerNS = "urn:oasis:names:tc:opendocument:xmlns:container"
    static let opfNS = "http://www.idpf.org/2007/opf"
    static func container(_ path: String = "OPS/book.opf") -> String {
        "<container version='1.0' xmlns='\(containerNS)'><rootfiles><rootfile full-path='\(path)' media-type='application/oebps-package+xml'/></rootfiles></container>"
    }
    static func item(_ id: String = "c", _ href: String = "chapter.xhtml",
                     media: String = "application/xhtml+xml", extra: String = "") -> String {
        "<item id='\(id)' href='\(href)' media-type='\(media)' \(extra)/>"
    }
    static func opf(items: String = item(), refs: String = "<itemref idref='c'/>",
                    version: String = "3.0", extra: String = "") -> String {
        "<package version='\(version)' xmlns='\(opfNS)' \(extra)><manifest>\(items)</manifest><spine>\(refs)</spine></package>"
    }
    static func catalog(_ paths: [String] = ["META-INF/container.xml", "OPS/book.opf", "OPS/chapter.xhtml"]) -> EPUBSemanticResourceCatalog {
        EPUBSemanticResourceCatalog(archiveSHA256: String(repeating: "a", count: 64), paths: paths)
    }
    static func decode(_ xml: String = opf(), path: String = "OPS/book.opf",
                       paths: [String]? = nil, limits: EPUBSemanticPackageLimits = .init()) async throws -> EPUBPackageParts {
        let doc = try await SemanticXMLParser.parse(Data(xml.utf8))
        return try EPUBPackageDecoder.decode(document: doc, packagePath: path,
            catalog: paths.map { catalog($0) } ?? catalog(), limits: limits)
    }
    static func archive(container: String = container(), opf: String = opf(),
                        packagePath: String = "OPS/book.opf",
                        assets: [EPUBSemanticZIPFixture.Member] = [.init(path: "OPS/chapter.xhtml")],
                        opfCRC: UInt32? = nil) -> EPUBSemanticZIPFixture {
        EPUBSemanticZIPFixture([.init(path: "META-INF/container.xml", bytes: Data(container.utf8)),
            .init(path: packagePath, bytes: Data(opf.utf8), crc: opfCRC)] + assets)
    }
    static func withArchive<T>(_ zip: EPUBSemanticZIPFixture,
                               _ body: (URL) async throws -> T) async throws -> T {
        let url = EPUBSemanticZIPFixture.temporaryURL()
        try zip.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try await body(url)
    }
}

// Observation only coordinates actual work and captures its real reader actor.
final class EPUBPackageProbe: @unchecked Sendable {
    enum Point: Sendable, Equatable { case worker, reader, stage(EPUBPackageStage), publication }
    private let point: Point
    private let lock = NSLock()
    private let arrived = DispatchSemaphore(value: 0), released = DispatchSemaphore(value: 0)
    private let forwarded = DispatchSemaphore(value: 0)
    private var retainedReader: EPUBSemanticResourceReader?
    private var timedOut = false, cancelled = false
    init(_ point: Point) { self.point = point }
    var reader: EPUBSemanticResourceReader? {
        lock.lock(); defer { lock.unlock() }; return retainedReader
    }
    var facts: (timedOut: Bool, cancelled: Bool) {
        lock.lock(); defer { lock.unlock() }; return (timedOut, cancelled)
    }
    func pause() {
        arrived.signal()
        let ok = released.wait(timeout: .now() + 5) == .success
        lock.lock(); timedOut = !ok; cancelled = Task.isCancelled; lock.unlock()
    }
    func wait() -> Bool { arrived.wait(timeout: .now() + 5) == .success }
    func release() { released.signal() }
    func waitForwarded() -> Bool { forwarded.wait(timeout: .now() + 5) == .success }
    var observation: EPUBPackageLoadObservation {
        EPUBPackageLoadObservation(workerStarted: { [self] in if point == .worker { pause() } },
            readerCreated: { [self] reader in
                lock.lock(); retainedReader = reader; lock.unlock()
                if point == .reader { pause() }
            }, beforeStage: { [self] stage in if point == .stage(stage) { pause() } },
            beforePublication: { [self] in if point == .publication { pause() } },
            cancellationForwarded: { [self] in forwarded.signal() })
    }
}
