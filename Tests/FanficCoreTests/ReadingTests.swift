import Foundation
import PDFKit
import Testing
@testable import FanficCore

@Suite("Reading files")
struct ReadingTests {
    @Test("ZIP reader: deflate and stored entries")
    func zipEntries() throws {
        for name in ["Untamed Hearts.epub", "Starlight Over Grimmauld.epub"] {
            let zip = try ZipArchive(data: Data(contentsOf: fixture(name)))
            let mimetype = String(decoding: try zip.contents(of: "mimetype"), as: UTF8.self)
            #expect(mimetype == "application/epub+zip", "\(name)")
            let container = String(decoding: try zip.contents(of: "META-INF/container.xml"), as: UTF8.self)
            #expect(container.hasPrefix("<?xml"), "\(name)")
            #expect(container.contains("OEBPS/content.opf"), "\(name)")
        }
    }

    @Test("ZIP reader rejects a file that is not a ZIP")
    func notAZip() {
        #expect(throws: ZipArchive.ZipError.self) { try ZipArchive(data: Data(contentsOf: fixture("Broken.epub"))) }
    }

    @Test("EPUB: title, author and reading order")
    func epubPackage() throws {
        let book = try EPUBBook(data: Data(contentsOf: fixture("Starlight Over Grimmauld.epub")))
        #expect(book.title == "Starlight Over Grimmauld")
        #expect(book.author == "example-author-9")
        #expect(book.spinePaths == ["OEBPS/cover.xhtml", "OEBPS/titlepage.xhtml", "OEBPS/preface.xhtml", "OEBPS/chapter1.xhtml"])
        #expect(try book.text(at: "OEBPS/cover.xhtml") == "")
    }

    @Test("HTML to text: tags, entities, whitespace")
    func htmlText() {
        let html = """
        <html><head><title>Ignore me</title><style>p{}</style></head><body>
        <dl><dt>Relationships:</dt><dd><a href="#">A&nbsp;/ B</a>,   <a>C &amp; D</a></dd></dl>
        <p>Chlo&#233; and Chlo&#xE9;<br/>next&hellip;</p><!-- hidden --></body></html>
        """
        #expect(HTMLText.plainText(from: html) == "Relationships:\nA / B, C & D\nChloé and Chloé\nnext…")
    }

    @Test("Relationship field: SPEC example with a line break inside a name")
    func specExample() {
        let page = """
        Relationships:
        Harry Potter/Draco Malfoy, Hermione Granger/Pansy
        Parkinson/Ginny Weasley, Harry Potter & Ron Weasley
        Characters:
        Harry Potter, Draco Malfoy
        """
        #expect(RelationshipParser.relationships(in: page) ==
            ["Harry Potter/Draco Malfoy", "Hermione Granger/Pansy Parkinson/Ginny Weasley", "Harry Potter & Ron Weasley"])
    }

    @Test("Relationship field: inline labels, odd spacing, singular label")
    func inlineAndSpacing() {
        #expect(RelationshipParser.relationships(in: "Fandom: X Relationships: A/B, C & D Characters: A, C") == ["A/B", "C & D"])
        #expect(RelationshipParser.relationships(in: "relationship :  Harry Potter / Draco Malfoy ,Ron Weasley&Hermione Granger\nCharacter: Harry")
            == ["Harry Potter/Draco Malfoy", "Ron Weasley & Hermione Granger"])
        #expect(RelationshipParser.relationships(in: "Category: M/M\nRelationship: A/B\nAdditional Tags: Hurt/Comfort") == ["A/B"])
    }

    @Test("Relationship field: missing, empty, too long, repeated")
    func edgeCases() {
        #expect(RelationshipParser.relationships(in: "Characters: Harry Potter") == nil)
        #expect(RelationshipParser.relationships(in: "Relationship:\nCharacters: Harry") == [])
        let long = String(repeating: "x", count: 151)
        #expect(RelationshipParser.relationships(in: "Relationships: A/B, \(long), A/B\nLanguage: English") == ["A/B"])
    }

    @Test("Relationship field: continues on the next page only when the next page ends it")
    func continuation() {
        let page = "Notes\nRelationships:\nSherlock Holmes/John Watson,"
        #expect(RelationshipParser.relationships(in: page, nextPage: "Mycroft Holmes/Greg Lestrade\nCharacters: Sherlock")
            == ["Sherlock Holmes/John Watson", "Mycroft Holmes/Greg Lestrade"])
        #expect(RelationshipParser.relationships(in: page, nextPage: "Chapter 1\nA long chapter, with commas, and prose.")
            == ["Sherlock Holmes/John Watson"])
    }

    @Test("Free text after a field: the first line is kept, the rest dropped")
    func freeTextAfterField() {
        let notes = (1...12).map { "Author's note line \($0): thank you for reading." }.joined(separator: "\n")
        #expect(FandomParser.fandoms(in: "Fandom:\nSherlock (TV)\n\(notes)\nRelationships:\nA/B") == ["Sherlock (TV)"])
        #expect(RelationshipParser.relationships(in: "Relationships:\nA/B, C/D\n\(notes)") == ["A/B", "C/D"])
    }

    @Test("Fandom field: singular, plural crossover, inline, missing")
    func fandomField() {
        #expect(FandomParser.fandoms(in: "Category:\nM/M\nFandom:\nHarry Potter - J. K. Rowling\nRelationship:\nA/B") == ["Harry Potter - J. K. Rowling"])
        #expect(FandomParser.fandoms(in: "Fandoms: Harry Potter - J. K. Rowling, Percy Jackson and the Olympians - Rick Riordan Relationships: A/B")
            == ["Harry Potter - J. K. Rowling", "Percy Jackson and the Olympians - Rick Riordan"])
        #expect(FandomParser.fandoms(in: "Rating: Explicit\nRelationships: A/B") == nil)
        #expect(RelationshipParser.relationships(in: "Fandom:\nMarvel Cinematic Universe\nRelationships:\nLoki/Tony Stark\nCharacters: Loki") == ["Loki/Tony Stark"])
    }

    @Test("Relationship kinds and A/B = B/A grouping key")
    func kinds() {
        #expect(Relationship("A/B/C").kind == .pairing)
        #expect(Relationship("A/B/C").members == ["A", "B", "C"])
        #expect(Relationship("A & B").kind == .friendship)
        #expect(Relationship("Original Character").kind == .single)
        #expect(Relationship("Harry Potter/Draco Malfoy").groupKey == Relationship("draco malfoy/HARRY POTTER").groupKey)
        #expect(Relationship("A/B").groupKey != Relationship("A & B").groupKey)
    }

    @Test("First-page copy of a PDF is one page with the original page's text")
    func pdfFirstPage() throws {
        let prepared = try WorkReader.read(fixture("Anthology.pdf"))
        let copy = try #require(PDFDocument(data: prepared.firstPagePDF))
        #expect(copy.pageCount == 1)
        #expect(copy.page(at: 0)?.string?.contains("Remus Lupin/Sirius Black") == true)
        #expect(prepared.firstPageSource == "page 2")
    }

    @Test("First-page copy of an EPUB is a one-page PDF with the page's text")
    func epubFirstPage() throws {
        let prepared = try WorkReader.read(fixture("Untamed Hearts.epub"))
        let copy = try #require(PDFDocument(data: prepared.firstPagePDF))
        #expect(copy.pageCount == 1)
        let text = copy.page(at: 0)?.string ?? ""
        #expect(text.contains("Relationships:"))
        #expect(text.contains("Lan Zhan | Lan Wangji/Wei Ying | Wei Wuxian"))
    }
}
