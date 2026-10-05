// Purpose: Immutable source-pinned package/order values; no chapter or layout claim.
import Foundation

struct EPUBSemanticManifestItem: Sendable, Equatable {
    let id: String
    let path: String
    let mediaType: String
    let properties: [String]
    static func == (lhs: Self, rhs: Self) -> Bool {
        EPUBPackageLiteralKey(lhs.id) == EPUBPackageLiteralKey(rhs.id) &&
        EPUBPackageLiteralKey(lhs.path) == EPUBPackageLiteralKey(rhs.path) &&
        EPUBPackageLiteralKey(lhs.mediaType) == EPUBPackageLiteralKey(rhs.mediaType) &&
        EPUBPackageLiteralKey.same(lhs.properties, rhs.properties)
    }
}

struct EPUBSemanticSpineEntry: Sendable, Equatable {
    let occurrence: Int
    let manifestIndex: Int
    let linear: Bool
    let properties: [String]
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.occurrence == rhs.occurrence && lhs.manifestIndex == rhs.manifestIndex &&
        lhs.linear == rhs.linear && EPUBPackageLiteralKey.same(lhs.properties, rhs.properties)
    }
}

struct EPUBPackageParts: Sendable, Equatable {
    let manifestItems: [EPUBSemanticManifestItem]
    let spine: [EPUBSemanticSpineEntry]
}

struct EPUBSemanticPackage: Sendable, Equatable {
    let archiveSHA256: String
    let containerSHA256: String
    let packagePath: String
    let packageSHA256: String
    let manifestItems: [EPUBSemanticManifestItem]
    let spine: [EPUBSemanticSpineEntry]
    static func == (lhs: Self, rhs: Self) -> Bool {
        EPUBPackageLiteralKey(lhs.archiveSHA256) == EPUBPackageLiteralKey(rhs.archiveSHA256) &&
        EPUBPackageLiteralKey(lhs.containerSHA256) == EPUBPackageLiteralKey(rhs.containerSHA256) &&
        EPUBPackageLiteralKey(lhs.packagePath) == EPUBPackageLiteralKey(rhs.packagePath) &&
        EPUBPackageLiteralKey(lhs.packageSHA256) == EPUBPackageLiteralKey(rhs.packageSHA256) &&
        lhs.manifestItems == rhs.manifestItems && lhs.spine == rhs.spine
    }
}

enum EPUBSemanticPackageError: Error, Sendable, Equatable {
    case invalidLimits, invalidContainer, invalidPackage, unsupportedPackage
    case unsupportedReference, unsafePath, missingResource, duplicateManifestID
    case duplicateResourcePath, invalidSpine, metadataLimit, inconsistentSource
}

enum EPUBPackageStage: Sendable, Equatable {
    case containerDecoded, opfDecoded, manifestItem(Int), spineEntry(Int)
}

struct EPUBPackageLoadObservation: Sendable {
    let workerStarted: @Sendable () -> Void
    let readerCreated: @Sendable (EPUBSemanticResourceReader) -> Void
    let beforeStage: @Sendable (EPUBPackageStage) -> Void
    let beforePublication: @Sendable () -> Void
    let cancellationForwarded: @Sendable () -> Void
    init(workerStarted: @escaping @Sendable () -> Void = {},
         readerCreated: @escaping @Sendable (EPUBSemanticResourceReader) -> Void = { _ in },
         beforeStage: @escaping @Sendable (EPUBPackageStage) -> Void = { _ in },
         beforePublication: @escaping @Sendable () -> Void = {},
         cancellationForwarded: @escaping @Sendable () -> Void = {}) {
        self.workerStarted = workerStarted; self.readerCreated = readerCreated
        self.beforeStage = beforeStage; self.beforePublication = beforePublication
        self.cancellationForwarded = cancellationForwarded
    }
}
