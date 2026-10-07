// Purpose: Independent, lowerable semantic budgets in addition to XML input budgets.
struct SemanticXHTMLLimits: Sendable {
    let xml: SemanticXMLLimits
    let blocks: Int
    let runs: Int
    let outputUTF16: Int
    init(xml: SemanticXMLLimits = .init(), blocks: Int = 4096,
         runs: Int = 16384, outputUTF16: Int = 2 * 1024 * 1024) {
        self.xml = xml; self.blocks = blocks; self.runs = runs; self.outputUTF16 = outputUTF16
    }
}
