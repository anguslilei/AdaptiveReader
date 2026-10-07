// Purpose: Bounded logical text offsets, checked against UTF16 scalar boundaries.
struct SemanticUTF16Range: Sendable, Codable, Hashable {
    let lowerBound: Int
    let upperBound: Int

    init(lowerBound: Int, upperBound: Int) throws {
        guard lowerBound >= 0, upperBound >= lowerBound, upperBound <= 2 * 1024 * 1024 else {
            throw SemanticModelError.invalidRange
        }
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    func validate(in text: String) throws {
        let units = text.utf16
        // Check only the bounded prefix needed by the range, without copying text.
        guard let upper = units.index(units.startIndex, offsetBy: upperBound, limitedBy: units.endIndex) else {
            throw SemanticModelError.invalidRange
        }
        let lower = units.index(units.startIndex, offsetBy: lowerBound)
        for index in [lower, upper] where index != units.startIndex && index != units.endIndex {
            let previous = units[units.index(before: index)]
            let next = units[index]
            guard !((0xD800...0xDBFF).contains(previous) && (0xDC00...0xDFFF).contains(next)) else {
                throw SemanticModelError.invalidRange
            }
        }
    }

    private enum CodingKeys: String, CodingKey { case lowerBound, upperBound }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(lowerBound: container.decode(Int.self, forKey: .lowerBound),
                      upperBound: container.decode(Int.self, forKey: .upperBound))
    }
}
