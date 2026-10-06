// Purpose: Domain validation failures.
enum SemanticModelError: Error, Sendable, Equatable {
    case invalidDigest, unsupportedSchema, invalidVersion, invalidPath
    case invalidOccurrence, invalidNodePath, invalidRange, invalidOrdinal
}
