// Purpose: Explicit decode-once local URL subset; no Foundation URL normalization.
import Foundation
import Testing
@testable import vreader

@Suite("EPUB package local references")
struct EPUBPackageReferenceTests {
    @Test(arguments: [
        ("chapter.xhtml", "OPS/chapter.xhtml"), ("sub/a.xhtml", "OPS/sub/a.xhtml"),
        ("../a.xhtml", "a.xhtml"), ("./a.xhtml", "OPS/a.xhtml"),
        ("sub/../a.xhtml", "OPS/a.xhtml"), ("%2e%2e/a.xhtml", "a.xhtml"),
        ("中文 😀.xhtml", "OPS/中文 😀.xhtml"), ("%E4%B8%AD.xhtml", "OPS/中.xhtml"),
        ("e%CC%81.xhtml", "OPS/e\u{301}.xhtml"), ("שלום.xhtml", "OPS/שלום.xhtml"),
        ("100%25done.xhtml", "OPS/100%done.xhtml"), ("a b.xhtml", "OPS/a b.xhtml")
    ])
    func resolvesWithinArchive(_ href: String, _ expected: String) throws {
        let result = try EPUBPackageReference.resolve(href: href, packagePath: "OPS/book.opf")
        #expect(Array(result.utf8) == Array(expected.utf8))
    }
    @Test func rootAndLiteralBaseAreNotDecodedAgain() throws {
        #expect(try EPUBPackageReference.resolve(href: "a.xhtml", packagePath: "book.opf") == "a.xhtml")
        #expect(try EPUBPackageReference.resolve(href: "a.xhtml", packagePath: "100%done/book.opf") == "100%done/a.xhtml")
        #expect(try EPUBPackageReference.rootfilePath("%E4%B8%AD/book.opf") == "中/book.opf")
        #expect(try EPUBPackageReference.rootfilePath("100%25done/book.opf") == "100%done/book.opf")
    }
    @Test(arguments: ["", "/a", "//a", "http:a", "data:x", "file:a", "C:/a", "a:b",
        "a%3Ab", "a%3ab", "a\\b", "a?b", "a#b", " a", "a\t", "a\n", "a\u{7f}",
        "a%00b", "a%01b", "a%7fb", "a%2fb", "a%2Fb", "a%5cb", "a%3fb", "a%23b",
        "a%", "a%0", "a%GG", "a%FF", "a%C0%AF", "a%2520b", "../../a", "a//b", "a/",
        ".", "..", "child/..", "child/.", "%2e", "%2E%2e", "child/%2e%2e", "child/%2e"])
    func rejectsUnsupportedOrUnsafe(_ href: String) {
        #expect(throws: (any Error).self) {
            try EPUBPackageReference.resolve(href: href, packagePath: "OPS/book.opf")
        }
        // The same subset applies to rootfile URLs, relative to the archive root.
        #expect(throws: (any Error).self) { try EPUBPackageReference.rootfilePath(href) }
    }
    @Test func UnicodeAndCaseStayLiteral() throws {
        let a = try EPUBPackageReference.resolve(href: "é.xhtml", packagePath: "OPS/book.opf")
        let b = try EPUBPackageReference.resolve(href: "e\u{301}.xhtml", packagePath: "OPS/book.opf")
        #expect(Array(a.utf8) != Array(b.utf8))
        #expect(try EPUBPackageReference.resolve(href: "A.xhtml", packagePath: "OPS/book.opf") == "OPS/A.xhtml")
    }
}
