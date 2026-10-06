// Purpose: RED compile-capable placeholder.
struct SemanticUTF16Range: Sendable, Codable, Hashable {
    let lowerBound: Int
    let upperBound: Int
    init(lowerBound: Int, upperBound: Int) throws { throw SemanticModelError.invalidRange }
    func validate(in text: String) throws { throw SemanticModelError.invalidRange }
}
