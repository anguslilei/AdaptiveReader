// Purpose: Child SLOT indices from the logical XML root, not XPath/CFI/node IDs.
struct SemanticNodePath: Sendable, Codable, Hashable {
    let components: [Int]

    init(_ components: [Int]) throws {
        guard components.count <= 96,
              components.allSatisfy({ $0 >= 0 && $0 <= Int(UInt32.max) }) else {
            throw SemanticModelError.invalidNodePath
        }
        self.components = components
    }

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var slots: [Int] = []
        while !container.isAtEnd {
            guard slots.count < 96 else { throw SemanticModelError.invalidNodePath }
            let slot = try container.decode(Int.self)
            guard slot >= 0, slot <= Int(UInt32.max) else { throw SemanticModelError.invalidNodePath }
            slots.append(slot)
        }
        try self.init(slots)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for slot in components { try container.encode(slot) }
    }
}
