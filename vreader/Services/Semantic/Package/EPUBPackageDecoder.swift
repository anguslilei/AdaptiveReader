// Purpose: Compile-capable package contract before native behavioral RED.
enum EPUBPackageDecoder {
    static func decode(document: SemanticXMLDocument, packagePath: String,
                       catalog: EPUBSemanticResourceCatalog,
                       limits: EPUBSemanticPackageLimits = EPUBSemanticPackageLimits(),
                       observation: EPUBPackageLoadObservation? = nil) throws -> EPUBPackageParts {
        throw EPUBSemanticPackageError.unimplemented
    }
}
