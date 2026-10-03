// Purpose: Lowerable finite configuration, validated at the parse boundary.
struct SemanticXMLLimits: Sendable {
    let inputBytes: Int
    let nodes: Int
    let depth: Int
    let attributes: Int
    let textUTF16: Int
    let declarationBytes: Int

    init(inputBytes: Int = 4 * 1024 * 1024, nodes: Int = 50000, depth: Int = 96,
         attributes: Int = 128, textUTF16: Int = 2 * 1024 * 1024, declarationBytes: Int = 1024) {
        self.inputBytes = inputBytes; self.nodes = nodes; self.depth = depth
        self.attributes = attributes; self.textUTF16 = textUTF16; self.declarationBytes = declarationBytes
    }
}
