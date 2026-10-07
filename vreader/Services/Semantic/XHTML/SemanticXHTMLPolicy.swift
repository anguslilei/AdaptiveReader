// Purpose: Frozen v1 structural subset; unsupported subtrees remain source references.
enum SemanticXHTMLPolicy {
    static let version = 1
    static let namespace = "http://www.w3.org/1999/xhtml"
    static let transparent: Set<String> = [
        "body", "div", "section", "article", "main", "header", "footer", "nav", "aside",
        "span", "a", "em", "strong", "b", "i", "u", "s", "small", "sub", "sup", "code",
        "abbr", "cite", "q", "time", "mark", "bdi", "bdo", "ruby", "rt", "rp"
    ]
    static func isXHTML(_ name: SemanticXMLName, _ local: String) -> Bool {
        name.namespaceURI?.utf8.elementsEqual(namespace.utf8) == true &&
        name.localName.utf8.elementsEqual(local.utf8)
    }
    static func role(_ name: SemanticXMLName) -> SemanticBlockRole? {
        guard name.namespaceURI?.utf8.elementsEqual(namespace.utf8) == true else { return .opaque }
        switch name.localName {
        case "h1", "h2", "h3", "h4", "h5", "h6": return .heading
        case "p": return .paragraph
        case "figure": return .figure
        case "figcaption": return .caption
        case "blockquote": return .quote
        case "ul", "ol": return .list
        case "li": return .listItem
        default: return transparent.contains(name.localName) ? nil : .opaque
        }
    }
    static func isWhitespace(_ text: String) -> Bool {
        text.utf8.allSatisfy { $0 == 9 || $0 == 10 || $0 == 13 || $0 == 32 }
    }
}
