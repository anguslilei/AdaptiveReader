// Purpose: Select exactly one root-relative package URL from the actual container tree.
import Foundation

enum EPUBContainerDecoder {
    static func decode(document: SemanticXMLDocument, catalog: EPUBSemanticResourceCatalog,
                       limits: EPUBSemanticPackageLimits = .init()) throws -> String {
        try limits.validate(); try EPUBPackageXMLAccess.preflight(document)
        let root = document.nodes[document.rootIndex], ns = EPUBPackageXMLAccess.containerNS
        guard EPUBPackageXMLAccess.matches(root, "container", ns),
              EPUBPackageXMLAccess.attribute(root, "version") == "1.0" else {
            throw EPUBSemanticPackageError.invalidContainer
        }
        let wrappers = EPUBPackageXMLAccess.elements(document, at: document.rootIndex)
        guard wrappers.count == 1, EPUBPackageXMLAccess.matches(document.nodes[wrappers[0]], "rootfiles", ns) else {
            throw EPUBSemanticPackageError.invalidContainer
        }
        let roots = EPUBPackageXMLAccess.elements(document, at: wrappers[0])
        guard roots.count == 1, EPUBPackageXMLAccess.matches(document.nodes[roots[0]], "rootfile", ns) else {
            throw EPUBSemanticPackageError.invalidContainer
        }
        let selected = document.nodes[roots[0]]
        guard EPUBPackageXMLAccess.attribute(selected, "media-type") == "application/oebps-package+xml" else {
            throw EPUBSemanticPackageError.invalidContainer
        }
        let reference = try EPUBPackageXMLAccess.required(selected, "full-path", error: .invalidContainer)
        let path = try EPUBPackageReference.rootfilePath(reference)
        let files = try EPUBPackageXMLAccess.files(catalog, limits: limits)
        guard files.contains(.init(path)) else { throw EPUBSemanticPackageError.missingResource }
        try Task.checkCancellation()
        return path
    }
}
