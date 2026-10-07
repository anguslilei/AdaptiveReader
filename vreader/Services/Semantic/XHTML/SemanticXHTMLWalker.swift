// Purpose: One-worker bounded traversal; flat preorder blocks with unique text ownership.
import Foundation

struct SemanticXHTMLWalker {
    private struct Draft {
        let id: SemanticID
        let role: SemanticBlockRole
        let anchor: SemanticLogicalAnchor
        let parent: Int?
        let headingLevel: Int?
        var runs: [SemanticXHTMLTextRun] = []
    }
    let document: SemanticXMLDocument
    let revision: SemanticRevision
    let resource: SemanticResourceIdentity
    let occurrence: Int
    let limits: SemanticXHTMLLimits
    let observation: SemanticXHTMLObservation?
    private var drafts: [Draft] = []
    private var runCount = 0
    private var textUnits = 0

    init(document: SemanticXMLDocument, revision: SemanticRevision, resource: SemanticResourceIdentity,
         occurrence: Int, limits: SemanticXHTMLLimits, observation: SemanticXHTMLObservation?) {
        self.document = document; self.revision = revision; self.resource = resource
        self.occurrence = occurrence; self.limits = limits; self.observation = observation
    }

    mutating func extract() throws -> [SemanticXHTMLBlock] {
        let root = document.nodes[document.rootIndex]
        guard case .element(let name) = root.kind, SemanticXHTMLPolicy.isXHTML(name, "html") else {
            throw SemanticXHTMLError.invalidDocument
        }
        var body: (index: Int, slot: Int)?
        var hasHead = false
        for (slot, index) in root.children.enumerated() {
            try Task.checkCancellation()
            switch document.nodes[index].kind {
            case .element(let child):
                if SemanticXHTMLPolicy.isXHTML(child, "head"), !hasHead, body == nil { hasHead = true }
                else if SemanticXHTMLPolicy.isXHTML(child, "body"), body == nil { body = (index, slot) }
                else { throw SemanticXHTMLError.invalidDocument }
            case .text(let text):
                guard SemanticXHTMLPolicy.isWhitespace(text) else { throw SemanticXHTMLError.invalidDocument }
            case .comment, .processingInstruction: break
            }
        }
        guard let body else { throw SemanticXHTMLError.invalidDocument }
        try walk(body.index, path: [body.slot], owner: nil)
        return try drafts.map { draft in
            try Task.checkCancellation()
            return SemanticXHTMLBlock(id: draft.id, role: draft.role, anchor: draft.anchor,
                parentIndex: draft.parent, headingLevel: draft.headingLevel, runs: draft.runs)
        }
    }

    private func anchor(_ path: [Int], range: SemanticUTF16Range? = nil) throws -> SemanticLogicalAnchor {
        try SemanticLogicalAnchor(resource: resource, spineOccurrence: occurrence,
                                  nodePath: SemanticNodePath(path), textRange: range)
    }

    private mutating func append(role: SemanticBlockRole, path: [Int], parent: Int?,
                                 heading: Int? = nil) throws -> Int {
        guard drafts.count < limits.blocks else { throw SemanticXHTMLError.blockLimit }
        let source = try anchor(path)
        let index = drafts.count
        let id = try SemanticID.block(revision: revision, anchor: source, role: role, ordinal: index)
        drafts.append(Draft(id: id, role: role, anchor: source, parent: parent, headingLevel: heading))
        return index
    }

    private mutating func text(_ value: String, path: [Int], owner: Int?) throws {
        if owner == nil && SemanticXHTMLPolicy.isWhitespace(value) { return }
        let count = value.utf16.count
        guard runCount < limits.runs else { throw SemanticXHTMLError.runLimit }
        guard count <= limits.outputUTF16 - textUnits else { throw SemanticXHTMLError.outputLimit }
        let destination: Int
        if let owner { destination = owner }
        else { destination = try append(role: .opaque, path: path, parent: nil) }
        let range = try SemanticUTF16Range(lowerBound: 0, upperBound: count)
        let source = try anchor(path, range: range)
        drafts[destination].runs.append(SemanticXHTMLTextRun(text: value, anchor: source))
        runCount += 1; textUnits += count
    }

    private mutating func walk(_ index: Int, path: [Int], owner: Int?) throws {
        try Task.checkCancellation()
        observation?.beforeNode(index)
        try Task.checkCancellation()
        let node = document.nodes[index]
        switch node.kind {
        case .text(let value): try text(value, path: path, owner: owner)
        case .comment, .processingInstruction: break
        case .element(let name):
            var childOwner = owner
            if let role = SemanticXHTMLPolicy.role(name) {
                let heading = role == .heading ? Int(name.localName.dropFirst()) : nil
                childOwner = try append(role: role, path: path, parent: owner, heading: heading)
                if role == .opaque { return }
            }
            for (slot, child) in node.children.enumerated() {
                try walk(child, path: path + [slot], owner: childOwner)
            }
        }
    }
}
