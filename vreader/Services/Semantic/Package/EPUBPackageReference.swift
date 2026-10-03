// Purpose: Compile-capable contract stub before native behavioral RED.
enum EPUBPackageReference {
    static func rootfilePath(_ reference: String) throws -> String {
        throw EPUBSemanticPackageError.unimplemented
    }
    static func resolve(href: String, packagePath: String) throws -> String {
        throw EPUBSemanticPackageError.unimplemented
    }
}
