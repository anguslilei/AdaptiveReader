// Purpose: Preserve manifest order and every spine occurrence from original parsed OPF.
import Foundation

enum EPUBPackageDecoder {
    static func decode(document: SemanticXMLDocument, packagePath: String,
                       catalog: EPUBSemanticResourceCatalog, limits: EPUBSemanticPackageLimits = .init(),
                       observation: EPUBPackageLoadObservation? = nil) throws -> EPUBPackageParts {
        try limits.validate(); try EPUBPackageXMLAccess.preflight(document)
        let root = document.nodes[document.rootIndex], ns = EPUBPackageXMLAccess.opfNS
        guard EPUBPackageXMLAccess.matches(root, "package", ns),
              let version = EPUBPackageXMLAccess.attribute(root, "version"), ["2.0", "3.0"].contains(version) else {
            throw EPUBSemanticPackageError.invalidPackage
        }
        let children = EPUBPackageXMLAccess.elements(document, at: document.rootIndex)
        let manifests = children.filter { EPUBPackageXMLAccess.matches(document.nodes[$0], "manifest", ns) }
        let spines = children.filter { EPUBPackageXMLAccess.matches(document.nodes[$0], "spine", ns) }
        guard manifests.count == 1, spines.count == 1 else { throw EPUBSemanticPackageError.invalidPackage }
        let items = EPUBPackageXMLAccess.elements(document, at: manifests[0])
        let refs = EPUBPackageXMLAccess.elements(document, at: spines[0])
        guard !items.isEmpty, !refs.isEmpty else { throw EPUBSemanticPackageError.invalidPackage }
        guard items.count <= limits.manifestItems, refs.count <= limits.spineEntries else {
            throw EPUBSemanticPackageError.metadataLimit
        }
        let files = try EPUBPackageXMLAccess.files(catalog, limits: limits)
        var budget = EPUBPackageBudget(limits.retainedUTF16)
        try budget.charge(packagePath)
        var manifest = [EPUBSemanticManifestItem](), ids = [EPUBPackageLiteralKey: Int]()
        var paths = Set<EPUBPackageLiteralKey>()
        for (position, index) in items.enumerated() {
            try EPUBPackageXMLAccess.stage(.manifestItem(position), observation: observation)
            let item = document.nodes[index]
            guard EPUBPackageXMLAccess.matches(item, "item", ns) else { throw EPUBSemanticPackageError.invalidPackage }
            guard EPUBPackageXMLAccess.attribute(item, "fallback") == nil else { throw EPUBSemanticPackageError.unsupportedPackage }
            let id = try EPUBPackageXMLAccess.required(item, "id", error: .invalidPackage)
            try EPUBPackageXMLAccess.token(id, error: .invalidPackage)
            guard ids[.init(id)] == nil else { throw EPUBSemanticPackageError.duplicateManifestID }
            let href = try EPUBPackageXMLAccess.required(item, "href", error: .invalidPackage)
            let path = try EPUBPackageReference.resolve(href: href, packagePath: packagePath)
            guard files.contains(.init(path)) else { throw EPUBSemanticPackageError.missingResource }
            guard paths.insert(.init(path)).inserted else { throw EPUBSemanticPackageError.duplicateResourcePath }
            let media = try EPUBPackageXMLAccess.required(item, "media-type", error: .invalidPackage)
            guard EPUBPackageXMLAccess.validMediaType(media) else { throw EPUBSemanticPackageError.invalidPackage }
            try budget.charge(id); try budget.charge(path); try budget.charge(media)
            let properties = try EPUBPackageXMLAccess.properties(item, limits: limits, budget: &budget)
            ids[.init(id)] = manifest.count
            manifest.append(.init(id: id, path: path, mediaType: media, properties: properties))
        }
        var spine = [EPUBSemanticSpineEntry]()
        for (position, index) in refs.enumerated() {
            try EPUBPackageXMLAccess.stage(.spineEntry(position), observation: observation)
            let ref = document.nodes[index]
            guard EPUBPackageXMLAccess.matches(ref, "itemref", ns) else { throw EPUBSemanticPackageError.invalidSpine }
            let idref = try EPUBPackageXMLAccess.required(ref, "idref", error: .invalidSpine)
            try EPUBPackageXMLAccess.token(idref, error: .invalidSpine)
            guard let target = ids[.init(idref)] else { throw EPUBSemanticPackageError.invalidSpine }
            guard manifest[target].mediaType.lowercased() == "application/xhtml+xml" else {
                throw EPUBSemanticPackageError.unsupportedPackage
            }
            let linear: Bool
            switch EPUBPackageXMLAccess.attribute(ref, "linear") {
            case nil, "yes": linear = true
            case "no": linear = false
            default: throw EPUBSemanticPackageError.invalidSpine
            }
            let properties = try EPUBPackageXMLAccess.properties(ref, limits: limits, budget: &budget)
            spine.append(.init(occurrence: position, manifestIndex: target, linear: linear, properties: properties))
        }
        guard spine.contains(where: \.linear) else { throw EPUBSemanticPackageError.invalidSpine }
        try Task.checkCancellation()
        return EPUBPackageParts(manifestItems: manifest, spine: spine)
    }
}
