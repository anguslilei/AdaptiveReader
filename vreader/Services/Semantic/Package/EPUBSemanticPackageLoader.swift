// Purpose: Real source/XML composition in one worker, with explicit closure on every exit.
import Foundation

enum EPUBSemanticPackageLoader {
    static func load(fileURL: URL, expectedArchiveSHA256: String? = nil,
                     sourceLimits: EPUBSemanticLimits = .init(), xmlLimits: SemanticXMLLimits = .init(),
                     packageLimits: EPUBSemanticPackageLimits = .init(),
                     observation: EPUBPackageLoadObservation? = nil) async throws -> EPUBSemanticPackage {
        try Task.checkCancellation()
        try sourceLimits.validate(); try xmlLimits.validate(); try packageLimits.validate()
        let worker = Task.detached {
            observation?.workerStarted(); try Task.checkCancellation()
            let reader = try await EPUBSemanticResourceReader.open(fileURL: fileURL,
                expectedArchiveSHA256: expectedArchiveSHA256, limits: sourceLimits)
            do {
                observation?.readerCreated(reader); try Task.checkCancellation()
                let catalog = try await reader.catalog()
                let container = try await reader.read(path: "META-INF/container.xml")
                let containerDoc = try await SemanticXMLParser.parse(container.bytes, limits: xmlLimits)
                try verify(container, document: containerDoc, path: "META-INF/container.xml", catalog: catalog)
                let packagePath = try EPUBContainerDecoder.decode(document: containerDoc, catalog: catalog, limits: packageLimits)
                try EPUBPackageXMLAccess.stage(.containerDecoded, observation: observation)
                let package = try await reader.read(path: packagePath)
                let packageDoc = try await SemanticXMLParser.parse(package.bytes, limits: xmlLimits)
                try verify(package, document: packageDoc, path: packagePath, catalog: catalog)
                try EPUBPackageXMLAccess.stage(.opfDecoded, observation: observation)
                let parts = try EPUBPackageDecoder.decode(document: packageDoc, packagePath: packagePath,
                    catalog: catalog, limits: packageLimits, observation: observation)
                let result = EPUBSemanticPackage(archiveSHA256: catalog.archiveSHA256,
                    containerSHA256: container.sha256, packagePath: packagePath, packageSHA256: package.sha256,
                    manifestItems: parts.manifestItems, spine: parts.spine)
                await reader.close()
                try Task.checkCancellation()
                return result
            } catch { await reader.close(); throw error }
        }
        return try await withTaskCancellationHandler {
            let result = try await worker.value
            observation?.beforePublication()
            try Task.checkCancellation()
            return result
        } onCancel: { worker.cancel(); observation?.cancellationForwarded() }
    }
    private static func verify(_ resource: EPUBSemanticResource, document: SemanticXMLDocument,
                               path: String, catalog: EPUBSemanticResourceCatalog) throws {
        guard resource.path.utf8.elementsEqual(path.utf8),
              resource.archiveSHA256.utf8.elementsEqual(catalog.archiveSHA256.utf8),
              document.sourceSHA256.utf8.elementsEqual(resource.sha256.utf8) else {
            throw EPUBSemanticPackageError.inconsistentSource
        }
    }
}
