// Purpose: RED compile-capable placeholder.
struct SemanticNodePath: Sendable, Codable, Hashable {
    let components: [Int]
    init(_ components: [Int]) throws { throw SemanticModelError.invalidNodePath }
}
