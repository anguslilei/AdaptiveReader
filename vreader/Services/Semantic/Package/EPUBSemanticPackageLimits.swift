// Purpose: Independently lowerable package DTO and catalog-key ceilings.
struct EPUBSemanticPackageLimits: Sendable {
    let manifestItems: Int
    let spineEntries: Int
    let propertiesPerItem: Int
    let retainedUTF16: Int
    let catalogUTF16: Int
    init(manifestItems: Int = 4096, spineEntries: Int = 4096,
         propertiesPerItem: Int = 64, retainedUTF16: Int = 2 * 1024 * 1024,
         catalogUTF16: Int = 2 * 1024 * 1024) {
        self.manifestItems = manifestItems; self.spineEntries = spineEntries
        self.propertiesPerItem = propertiesPerItem
        self.retainedUTF16 = retainedUTF16; self.catalogUTF16 = catalogUTF16
    }
    func validate() throws {
        let d = EPUBSemanticPackageLimits()
        let values = [manifestItems, spineEntries, propertiesPerItem, retainedUTF16, catalogUTF16]
        let caps = [d.manifestItems, d.spineEntries, d.propertiesPerItem, d.retainedUTF16, d.catalogUTF16]
        guard zip(values, caps).allSatisfy({ $0.0 > 0 && $0.0 <= $0.1 }) else {
            throw EPUBSemanticPackageError.invalidLimits
        }
    }
}
