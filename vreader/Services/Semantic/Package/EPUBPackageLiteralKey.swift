// Purpose: Opaque IDs, paths and tokens retain literal UTF8 identity.
struct EPUBPackageLiteralKey: Hashable {
    let value: String
    init(_ value: String) { self.value = value }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.value.utf8.elementsEqual(rhs.value.utf8) }
    static func same(_ lhs: [String], _ rhs: [String]) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { $0.utf8.elementsEqual($1.utf8) }
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(value.utf8.count)
        for byte in value.utf8 { hasher.combine(byte) }
    }
}
