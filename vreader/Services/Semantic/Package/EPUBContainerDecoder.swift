// Purpose: Compile-capable container contract before native behavioral RED.
enum EPUBContainerDecoder {
    static func decode(document: SemanticXMLDocument, catalog: EPUBSemanticResourceCatalog,
                       limits: EPUBSemanticPackageLimits = EPUBSemanticPackageLimits()) throws -> String {
        throw EPUBSemanticPackageError.unimplemented
    }
}
