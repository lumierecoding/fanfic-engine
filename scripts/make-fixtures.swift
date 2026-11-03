#!/usr/bin/env swift
// Makes the AO3-style test files in Fixtures/ and Fixtures/expected.json.
// Everything is generated locally; nothing is downloaded. Stories, authors and links are made up
// (authors are "example-author-N", links point to example.org); only fandom and character names are real.
// Usage: swift scripts/make-fixtures.swift Fixtures

import AppKit
import CoreText
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    print("usage: swift scripts/make-fixtures.swift <output folder>")
    exit(1)
}
let out = URL(fileURLWithPath: arguments[1], isDirectory: true)
let fm = FileManager.default
try fm.createDirectory(at: out, withIntermediateDirectories: true)

// MARK: - Expected results (read by the tests and the end-to-end check)

struct Expected: Codable {
    var file: String
    var outcome: String            // added | addedNoPairing | duplicate | unreadable | skipped
    var kind: String?              // pdf | epub
    var title: String?
    var author: String?
    var firstPageSource: String?
    var relationships: [String]
    var fandoms: [String] = []
    var summary: String? = nil     // SPEC section 5a; left out when the file has none
}
var expected: [Expected] = []

// MARK: - PDF

struct Line {
    var text: String
    var bold = false
    var size: CGFloat = 11
}
func label(_ t: String) -> Line { Line(text: t, bold: true) }
func value(_ t: String) -> Line { Line(text: t) }
func heading(_ t: String) -> Line { Line(text: t, bold: true, size: 18) }

func writePDF(_ name: String, title: String?, author: String?, pages: [[Line]], drawTextless: Bool = false,
              into folder: URL = out) throws {
    let url = folder.appendingPathComponent(name)
    var box = CGRect(x: 0, y: 0, width: 595, height: 842)
    var info: [CFString: Any] = [kCGPDFContextCreator: "Fanfic Engine test files"]
    if let title { info[kCGPDFContextTitle] = title }
    if let author { info[kCGPDFContextAuthor] = author }
    guard let ctx = CGContext(url as CFURL, mediaBox: &box, info as CFDictionary) else {
        throw NSError(domain: "fixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot create \(name)"])
    }
    for page in pages {
        ctx.beginPDFPage(nil)
        if drawTextless {
            // A "scanned" page: only shapes, no text layer.
            ctx.setFillColor(gray: 0.85, alpha: 1)
            for i in 0..<20 {
                ctx.fill(CGRect(x: 60, y: 760 - CGFloat(i) * 32, width: 475, height: 12))
            }
        } else {
            let text = NSMutableAttributedString()
            for line in page {
                let font = line.bold ? NSFont.boldSystemFont(ofSize: line.size) : NSFont.systemFont(ofSize: line.size)
                text.append(NSAttributedString(string: line.text + "\n", attributes: [.font: font]))
            }
            let setter = CTFramesetterCreateWithAttributedString(text)
            let path = CGPath(rect: box.insetBy(dx: 60, dy: 60), transform: nil)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil)
            CTFrameDraw(frame, ctx)
        }
        ctx.endPDFPage()
    }
    ctx.closePDF()
}

func chapterPage(_ title: String) -> [Line] {
    [heading(title), value(""),
     value("Snow had settled on the windowsill by the time the kettle began to sing."),
     value("Nobody in the house said anything for a long while, and that was fine.")]
}

// 1. AO3 layout with each label on its own line, singular labels.
try writePDF("The Quiet Winter.pdf", title: "The Quiet Winter", author: "example-author-1", pages: [
    [heading("The Quiet Winter"),
     value("Posted originally on the Archive of Our Own at https://example.org/works/1."),
     label("Rating:"), value("Teen And Up Audiences"),
     label("Archive Warning:"), value("No Archive Warnings Apply"),
     label("Category:"), value("M/M"),
     label("Fandom:"), value("Harry Potter - J. K. Rowling"),
     label("Relationship:"), value("Harry Potter/Draco Malfoy"),
     label("Characters:"), value("Harry Potter, Draco Malfoy"),
     label("Additional Tags:"), value("Fluff, Hurt/Comfort, Snow"),
     label("Language:"), value("English"),
     label("Stats:"), value("Published: 2025-12-01 Words: 4,512 Chapters: 1/1"),
     value(""), heading("The Quiet Winter"), value("by example-author-1"), value(""),
     label("Summary"), value("Two former rivals, one snowed-in cottage.")],
    chapterPage("Chapter 1"),
])
expected.append(Expected(file: "The Quiet Winter.pdf", outcome: "added", kind: "pdf",
    title: "The Quiet Winter", author: "example-author-1", firstPageSource: "page 1",
    relationships: ["Harry Potter/Draco Malfoy"], fandoms: ["Harry Potter - J. K. Rowling"],
    summary: "Two former rivals, one snowed-in cottage."))

// 2. Inline "Label: value" layout, plural label, a friendship tag, "Aaron" (must not match "Ron").
try writePDF("Profilers Notes.pdf", title: "Profiler's Notes", author: "example-author-2", pages: [
    [heading("Profiler's Notes"),
     value("Rating: General Audiences"),
     value("Category: M/M, Gen"),
     value("Fandom: Criminal Minds (US TV)"),
     value("Relationships: Aaron Hotchner/Spencer Reid, Derek Morgan & Spencer Reid"),
     value("Characters: Aaron Hotchner, Spencer Reid, Derek Morgan"),
     value("Additional Tags: Case Fic, Slow Burn"),
     value("Language: English")],
    chapterPage("Chapter 1"),
])
expected.append(Expected(file: "Profilers Notes.pdf", outcome: "added", kind: "pdf",
    title: "Profiler's Notes", author: "example-author-2", firstPageSource: "page 1",
    relationships: ["Aaron Hotchner/Spencer Reid", "Derek Morgan & Spencer Reid"], fandoms: ["Criminal Minds (US TV)"]))

// 3. Plural labels, a line break inside a name, a poly pairing, a three-person friendship.
try writePDF("Common Room Constellations.pdf", title: "Common Room Constellations", author: "example-author-3", pages: [
    [heading("Common Room Constellations"),
     label("Rating:"), value("Mature"),
     label("Archive Warnings:"), value("No Archive Warnings Apply"),
     label("Categories:"), value("F/F, M/M, F/M"),
     label("Fandom:"), value("Harry Potter - J. K. Rowling"),
     label("Relationships:"),
     value("Harry Potter/Draco Malfoy, Hermione Granger/Pansy"),
     value("Parkinson/Ginny Weasley, Ron Weasley/Lavender Brown, Harry Potter & Ron Weasley &"),
     value("Hermione Granger"),
     label("Characters:"), value("Harry Potter, Draco Malfoy, Hermione Granger, Pansy Parkinson, Ginny Weasley"),
     label("Additional Tags:"), value("Eighth Year, Enemies to Lovers, Polyamory")],
    chapterPage("Chapter 1"),
])
expected.append(Expected(file: "Common Room Constellations.pdf", outcome: "added", kind: "pdf",
    title: "Common Room Constellations", author: "example-author-3", firstPageSource: "page 1",
    relationships: ["Harry Potter/Draco Malfoy", "Hermione Granger/Pansy Parkinson/Ginny Weasley",
                    "Ron Weasley/Lavender Brown", "Harry Potter & Ron Weasley & Hermione Granger"], fandoms: ["Harry Potter - J. K. Rowling"]))

// 4. Accents and hyphens.
try writePDF("Lucky Charm.pdf", title: "Lucky Charm", author: "example-author-4", pages: [
    [heading("Lucky Charm"),
     label("Fandom:"), value("Miraculous Ladybug"),
     label("Relationships:"), value("Marinette Dupain-Cheng/Chloé Bourgeois, Adrien Agreste/Marinette Dupain-Cheng"),
     label("Characters:"), value("Marinette Dupain-Cheng, Chloé Bourgeois, Adrien Agreste")],
])
expected.append(Expected(file: "Lucky Charm.pdf", outcome: "added", kind: "pdf",
    title: "Lucky Charm", author: "example-author-4", firstPageSource: "page 1",
    relationships: ["Marinette Dupain-Cheng/Chloé Bourgeois", "Adrien Agreste/Marinette Dupain-Cheng"], fandoms: ["Miraculous Ladybug"]))

// 5. Relationship field starts at the bottom of page 1 and continues on page 2.
var longPreface: [Line] = [heading("Baker Street Ledger"), label("Fandom:"), value("Sherlock (TV)")]
for i in 1...44 { longPreface.append(value("Author's note line \(i): thank you for reading.")) }
longPreface.append(label("Relationships:"))
longPreface.append(value("Sherlock Holmes/John Watson,"))
try writePDF("Baker Street Ledger.pdf", title: "Baker Street Ledger", author: "example-author-5", pages: [
    longPreface,
    [value("Mycroft Holmes/Greg Lestrade"),
     label("Characters:"), value("Sherlock Holmes, John Watson, Mycroft Holmes, Greg Lestrade"),
     value(""), heading("Chapter 1")],
])
expected.append(Expected(file: "Baker Street Ledger.pdf", outcome: "added", kind: "pdf",
    title: "Baker Street Ledger", author: "example-author-5", firstPageSource: "page 1",
    relationships: ["Sherlock Holmes/John Watson", "Mycroft Holmes/Greg Lestrade"], fandoms: ["Sherlock (TV)"]))

// 6. Page 1 is a cover with text but no field; the field is on page 2.
try writePDF("Anthology.pdf", title: "Winter Anthology", author: "example-author-6", pages: [
    [heading("Winter Anthology"), value("A collection of short works")],
    [heading("Winter Anthology"),
     label("Relationship:"), value("Remus Lupin/Sirius Black"),
     label("Characters:"), value("Remus Lupin, Sirius Black")],
    chapterPage("Part One"),
])
expected.append(Expected(file: "Anthology.pdf", outcome: "added", kind: "pdf",
    title: "Winter Anthology", author: "example-author-6", firstPageSource: "page 2",
    relationships: ["Remus Lupin/Sirius Black"]))

// 7. Gen fic: no Relationship field at all.
try writePDF("Field Notes.pdf", title: "Field Notes", author: "example-author-7", pages: [
    [heading("Field Notes"),
     label("Category:"), value("Gen"),
     label("Fandom:"), value("Criminal Minds (US TV)"),
     label("Characters:"), value("Spencer Reid, Penelope Garcia"),
     label("Additional Tags:"), value("Friendship, Found Family")],
])
expected.append(Expected(file: "Field Notes.pdf", outcome: "addedNoPairing", kind: "pdf",
    title: "Field Notes", author: "example-author-7", firstPageSource: "page 1", relationships: [], fandoms: ["Criminal Minds (US TV)"]))

// 8. A "scanned" PDF without text.
try writePDF("Scanned Without Text.pdf", title: nil, author: nil, pages: [[]], drawTextless: true)
expected.append(Expected(file: "Scanned Without Text.pdf", outcome: "unreadable", relationships: []))

// 9. Not a PDF at all.
try Data("This file only pretends to be a PDF.\n".utf8).write(to: out.appendingPathComponent("Not A Real PDF.pdf"))
expected.append(Expected(file: "Not A Real PDF.pdf", outcome: "unreadable", relationships: []))

// 9b. Crossover: plural "Fandoms:" with two fandoms.
try writePDF("Crossroads.pdf", title: "Crossroads", author: "example-author-10", pages: [
    [heading("Crossroads"),
     label("Rating:"), value("Teen And Up Audiences"),
     label("Category:"), value("M/M"),
     label("Fandoms:"), value("Harry Potter - J. K. Rowling, Percy Jackson and the Olympians - Rick Riordan"),
     label("Relationships:"), value("Draco Malfoy/Percy Jackson, Nico di Angelo & Harry Potter"),
     label("Characters:"), value("Draco Malfoy, Percy Jackson, Nico di Angelo, Harry Potter"),
     label("Additional Tags:"), value("Crossover, Demigods")],
])
expected.append(Expected(file: "Crossroads.pdf", outcome: "added", kind: "pdf",
    title: "Crossroads", author: "example-author-10", firstPageSource: "page 1",
    relationships: ["Draco Malfoy/Percy Jackson", "Nico di Angelo & Harry Potter"],
    fandoms: ["Harry Potter - J. K. Rowling", "Percy Jackson and the Olympians - Rick Riordan"]))

// MARK: - EPUB

func run(_ tool: String, _ args: [String], in dir: URL) throws {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = args
    p.currentDirectoryURL = dir
    try p.run()
    p.waitUntilExit()
    guard p.terminationStatus == 0 else {
        throw NSError(domain: "fixtures", code: 2, userInfo: [NSLocalizedDescriptionKey: "\(tool) \(args) failed"])
    }
}

func writeEPUB(_ name: String, title: String, author: String, docs: [(id: String, body: String)], storedOnly: Bool,
               folder: String = "OEBPS", into outFolder: URL = out) throws {
    let tmp = fm.temporaryDirectory.appendingPathComponent("fixture-" + UUID().uuidString, isDirectory: true)
    let oebps = tmp.appendingPathComponent(folder, isDirectory: true)
    let meta = tmp.appendingPathComponent("META-INF", isDirectory: true)
    try fm.createDirectory(at: oebps, withIntermediateDirectories: true)
    try fm.createDirectory(at: meta, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tmp) }

    try "application/epub+zip".write(to: tmp.appendingPathComponent("mimetype"), atomically: true, encoding: .ascii)
    try """
    <?xml version="1.0" encoding="UTF-8"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles>
        <rootfile full-path="\(folder)/content.opf" media-type="application/oebps-package+xml"/>
      </rootfiles>
    </container>
    """.write(to: meta.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

    let manifest = docs.map { "    <item id=\"\($0.id)\" href=\"\($0.id).xhtml\" media-type=\"application/xhtml+xml\"/>" }.joined(separator: "\n")
    let spine = docs.map { "    <itemref idref=\"\($0.id)\"/>" }.joined(separator: "\n")
    try """
    <?xml version="1.0" encoding="UTF-8"?>
    <package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="uid">
      <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
        <dc:title>\(title)</dc:title>
        <dc:creator opf:role="aut">\(author)</dc:creator>
        <dc:identifier id="uid">urn:uuid:\(UUID().uuidString)</dc:identifier>
        <dc:language>en</dc:language>
      </metadata>
      <manifest>
    \(manifest)
      </manifest>
      <spine>
    \(spine)
      </spine>
    </package>
    """.write(to: oebps.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

    for doc in docs {
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>\(title)</title><style>dt { font-weight: bold; }</style></head>
        <body>
        \(doc.body)
        </body>
        </html>
        """.write(to: oebps.appendingPathComponent("\(doc.id).xhtml"), atomically: true, encoding: .utf8)
    }

    let target = outFolder.appendingPathComponent(name)
    try? fm.removeItem(at: target)   // zip would otherwise add to an old archive
    try run("/usr/bin/zip", ["-X", "-q", "-0", target.path, "mimetype"], in: tmp)
    try run("/usr/bin/zip", ["-X", "-q", "-r", storedOnly ? "-0" : "-9", target.path, "META-INF", folder], in: tmp)
}

// 10. AO3-style EPUB preface (dl/dt/dd), alternate names with "|", HTML entities, deflate-compressed.
try writeEPUB("Untamed Hearts.epub", title: "Untamed Hearts", author: "example-author-8", docs: [
    (id: "preface", body: """
    <div class="meta">
    <h1>Untamed Hearts</h1>
    <p>Posted originally on the Archive of Our Own at https://example.org/works/2.</p>
    <dl class="tags">
    <dt>Rating:</dt><dd>Teen And Up Audiences</dd>
    <dt>Category:</dt><dd>M/M</dd>
    <dt>Fandom:</dt><dd>魔道祖师 - 墨香铜臭 | Mo Dao Zu Shi - Mo Xiang Tong Xiu</dd>
    <dt>Relationships:</dt><dd><a href="#">Lan Zhan | Lan Wangji/Wei Ying | Wei Wuxian</a>, <a href="#">Jiang Cheng &amp; Wei Ying | Wei Wuxian</a>,&nbsp;<a href="#">Nie Huaisang/Jiang Cheng</a></dd>
    <dt>Characters:</dt><dd><a href="#">Wei Ying | Wei Wuxian</a>, <a href="#">Lan Zhan | Lan Wangji</a></dd>
    <dt>Additional Tags:</dt><dd>Canon Divergence, Mutual Pining</dd>
    </dl>
    </div>
    """),
    (id: "chapter1", body: "<h2>Chapter 1</h2><p>The Cloud Recesses were quiet that morning.</p>"),
], storedOnly: false)
expected.append(Expected(file: "Untamed Hearts.epub", outcome: "added", kind: "epub",
    title: "Untamed Hearts", author: "example-author-8", firstPageSource: "OEBPS/preface.xhtml",
    relationships: ["Lan Zhan | Lan Wangji/Wei Ying | Wei Wuxian", "Jiang Cheng & Wei Ying | Wei Wuxian",
                    "Nie Huaisang/Jiang Cheng"], fandoms: ["魔道祖师 - 墨香铜臭 | Mo Dao Zu Shi - Mo Xiang Tong Xiu"]))

// 11. Image-only cover, then a title page with text but no field, then the preface. Stored (uncompressed) zip.
try writeEPUB("Starlight Over Grimmauld.epub", title: "Starlight Over Grimmauld", author: "example-author-9", docs: [
    (id: "cover", body: "<div><img src=\"cover.png\" alt=\"Cover\"/></div>"),
    (id: "titlepage", body: "<h1>Starlight Over Grimmauld</h1><p>by example-author-9</p>"),
    (id: "preface", body: """
    <p><b>Relationship:</b> Draco Malfoy/Harry Potter, Remus Lupin/Sirius Black</p>
    <p><b>Character:</b> Draco Malfoy, Harry Potter</p>
    <p><b>Language:</b> English</p>
    """),
    (id: "chapter1", body: "<h2>Chapter 1</h2><p>Grimmauld Place had never been this bright.</p>"),
], storedOnly: true)
expected.append(Expected(file: "Starlight Over Grimmauld.epub", outcome: "added", kind: "epub",
    title: "Starlight Over Grimmauld", author: "example-author-9", firstPageSource: "OEBPS/preface.xhtml",
    relationships: ["Draco Malfoy/Harry Potter", "Remus Lupin/Sirius Black"]))

// 11b. FicHub-style export from another site: an introduction page with no Fandom or Relationship field.
try writeEPUB("Westward Bound.epub", title: "Westward Bound", author: "example-author-11", docs: [
    (id: "introduction", body: """
    <h1>Westward Bound</h1>
    <p>By: example-author-11</p>
    <p>A wagon, a map with half the roads missing, and a very stubborn mule.</p>
    <p>Status: complete</p>
    <p>Published: 2024-05-01</p>
    <p>Updated: 2024-06-12</p>
    <p>Words: 5120</p>
    <p>Chapters: 2</p>
    <p>Original source:</p>
    <p>https://example.com/threads/12345</p>
    <p>Exported with the assistance of</p>
    <p>FicHub.net</p>
    """),
    (id: "chap_1", body: "<h2>Chapter 1</h2><p>The mule had opinions.</p>"),
    (id: "chap_2", body: "<h2>Chapter 2</h2><p>So did the river.</p>"),
], storedOnly: false, folder: "EPUB")
expected.append(Expected(file: "Westward Bound.epub", outcome: "addedNoPairing", kind: "epub",
    title: "Westward Bound", author: "example-author-11", firstPageSource: "EPUB/introduction.xhtml", relationships: []))

// 12. Not an EPUB.
try Data((0..<2048).map { UInt8(truncatingIfNeeded: $0 &* 37 &+ 11) }).write(to: out.appendingPathComponent("Broken.epub"))
expected.append(Expected(file: "Broken.epub", outcome: "unreadable", relationships: []))

// 13. Same bytes as file 1 under another name.
let dup = out.appendingPathComponent("Zz Duplicate of The Quiet Winter.pdf")
try? fm.removeItem(at: dup)
try fm.copyItem(at: out.appendingPathComponent("The Quiet Winter.pdf"), to: dup)
expected.append(Expected(file: "Zz Duplicate of The Quiet Winter.pdf", outcome: "duplicate", relationships: []))

// 14. Not a PDF or EPUB (only seen when a folder is imported).
try "Shopping list: tea, biscuits.\n".write(to: out.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
expected.append(Expected(file: "notes.txt", outcome: "skipped", relationships: []))

// MARK: - Summaries (SPEC section 5a): Summaries/ with its own expected.json

let summaries = out.appendingPathComponent("Summaries", isDirectory: true)
try fm.createDirectory(at: summaries, withIntermediateDirectories: true)
var summaryExpected: [Expected] = []

/// AO3's EPUB preface: the tags in the first document.
func ao3Tags(_ title: String, fandom: String, relationship: String, characters: String) -> String {
    """
    <div class="meta">
    <h1>\(title)</h1>
    <p>Posted originally on the Archive of Our Own at https://example.org/works/20.</p>
    <dl class="tags">
    <dt>Rating:</dt><dd>General Audiences</dd>
    <dt>Fandom:</dt><dd><a href="#">\(fandom)</a></dd>
    <dt>Relationship:</dt><dd><a href="#">\(relationship)</a></dd>
    <dt>Characters:</dt><dd>\(characters)</dd>
    <dt>Language:</dt><dd>English</dd>
    </dl>
    </div>
    """
}

// S1. AO3's EPUB layout: tags in document 1; in document 2 a "Summary" paragraph, a blockquote with two paragraphs
// (italics, a link, a line break, an entity), then "Notes" with its own blockquote.
try writeEPUB("Moonlit Library.epub", title: "Moonlit Library", author: "example-author-12", docs: [
    (id: "preface", body: ao3Tags("Moonlit Library", fandom: "Percy Jackson and the Olympians - Rick Riordan",
                                  relationship: "Nico di Angelo/Will Solace", characters: "Nico di Angelo, Will Solace")),
    (id: "summary", body: """
    <h1>Moonlit Library</h1>
    <div class="byline">by <a href="#">example-author-12</a></div>
    <p>Summary</p>
    <blockquote class="userstuff">
      <p>Will keeps falling asleep in the <em>one</em> library on Long Island that is open all night.</p>
      <p>Nico keeps not waking him up.<br/>It&#8217;s a <a href="https://example.org/tags/1">system</a> &amp; it works.</p>
    </blockquote>
    <p>Notes</p>
    <blockquote class="userstuff"><p>Written for a fluff exchange.</p></blockquote>
    """),
    (id: "chapter1", body: "<h2>Chapter 1</h2><p>The radiator clanked twice and gave up.</p>"),
], storedOnly: false, into: summaries)
summaryExpected.append(Expected(file: "Moonlit Library.epub", outcome: "added", kind: "epub",
    title: "Moonlit Library", author: "example-author-12", firstPageSource: "OEBPS/preface.xhtml",
    relationships: ["Nico di Angelo/Will Solace"], fandoms: ["Percy Jackson and the Olympians - Rick Riordan"],
    summary: "Will keeps falling asleep in the one library on Long Island that is open all night.\n\nNico keeps not waking him up.\nIt’s a system & it works."))

// S2. The same layout without Notes: the summary blockquote is the last thing in document 2.
try writeEPUB("Paper Lanterns.epub", title: "Paper Lanterns", author: "example-author-13", docs: [
    (id: "preface", body: ao3Tags("Paper Lanterns", fandom: "Avatar: The Last Airbender",
                                  relationship: "Katara/Zuko (Avatar)", characters: "Katara (Avatar), Zuko (Avatar)")),
    (id: "summary", body: """
    <h1>Paper Lanterns</h1>
    <div class="byline">by <a href="#">example-author-13</a></div>
    <p>Summary</p>
    <blockquote class="userstuff"><p>Two lanterns, one festival, and a promise neither of them meant to keep.</p></blockquote>
    """),
    (id: "chapter1", body: "<h2>Chapter 1</h2><p>The paper was thinner than she remembered.</p>"),
], storedOnly: true, into: summaries)
summaryExpected.append(Expected(file: "Paper Lanterns.epub", outcome: "added", kind: "epub",
    title: "Paper Lanterns", author: "example-author-13", firstPageSource: "OEBPS/preface.xhtml",
    relationships: ["Katara/Zuko (Avatar)"], fandoms: ["Avatar: The Last Airbender"],
    summary: "Two lanterns, one festival, and a promise neither of them meant to keep."))

// S3. PDF: the summary starts at the bottom of page 1 and goes on at the top of page 2, up to "Notes".
// PDF text has no paragraph marks (PDFKit drops empty lines), so the lines become one paragraph.
try writePDF("Harbour Lights.pdf", title: "Harbour Lights", author: "example-author-14", pages: [
    [heading("Harbour Lights"),
     value("Posted originally on the Archive of Our Own at https://example.org/works/21."),
     label("Rating:"), value("General Audiences"),
     label("Fandom:"), value("Good Omens (TV)"),
     label("Relationship:"), value("Aziraphale/Crowley (Good Omens)"),
     label("Characters:"), value("Aziraphale (Good Omens), Crowley (Good Omens)"),
     label("Language:"), value("English"),
     label("Stats:"), value("Published: 2025-11-20 Words: 3,050 Chapters: 1/1"),
     value(""), heading("Harbour Lights"), value("by example-author-14"), value(""),
     label("Summary"),
     value("A lighthouse keeper who has not spoken to anyone in years,"),
     value("and the demon who keeps rowing out to bring him tea."),
     value(""),
     value("Neither of them is very good at pretending")],
    [value("that it is about the tea."),
     value(""),
     label("Notes"), value("Written for a winter exchange.")],
    chapterPage("Chapter 1"),
], into: summaries)
summaryExpected.append(Expected(file: "Harbour Lights.pdf", outcome: "added", kind: "pdf",
    title: "Harbour Lights", author: "example-author-14", firstPageSource: "page 1",
    relationships: ["Aziraphale/Crowley (Good Omens)"], fandoms: ["Good Omens (TV)"],
    summary: "A lighthouse keeper who has not spoken to anyone in years, and the demon who keeps rowing out to bring him tea. Neither of them is very good at pretending that it is about the tea."))

// S4. Another maker's layout: "Summary:" with the text on the same line, in the document with the tags; ends at "Language:".
try writeEPUB("Dragon Post.epub", title: "Dragon Post", author: "example-author-15", docs: [
    (id: "titlepage", body: """
    <h1>Dragon Post</h1>
    <p><b>Fandom:</b> How to Train Your Dragon (Movies)</p>
    <p><b>Relationship:</b> Astrid Hofferson/Hiccup Horrendous Haddock III</p>
    <p><b>Summary:</b> A courier, a dragon and a very late letter.</p>
    <p><b>Language:</b> English</p>
    """),
    (id: "chapter1", body: "<h2>Chapter 1</h2><p>The letter was three weeks late and slightly singed.</p>"),
], storedOnly: false, into: summaries)
summaryExpected.append(Expected(file: "Dragon Post.epub", outcome: "added", kind: "epub",
    title: "Dragon Post", author: "example-author-15", firstPageSource: "OEBPS/titlepage.xhtml",
    relationships: ["Astrid Hofferson/Hiccup Horrendous Haddock III"], fandoms: ["How to Train Your Dragon (Movies)"],
    summary: "A courier, a dragon and a very late letter."))

// S5. An export from another site whose first chapter starts with a heading "Summary" and runs on for over
// 1,500 characters with no end label: not a summary (SPEC 5a rule 5).
let longChapter = (1...14).map { "<p>Paragraph \($0) of the first chapter. The road went on past the old mill and the river, and nobody on the cart said a word for a long time.</p>" }.joined(separator: "\n")
try writeEPUB("Long Road Home.epub", title: "Long Road Home", author: "example-author-16", docs: [
    (id: "introduction", body: """
    <h1>Long Road Home</h1>
    <p>By: example-author-16</p>
    <p>Status: complete</p>
    <p>Exported with the assistance of</p>
    <p>FicHub.net</p>
    """),
    (id: "chap_1", body: "<h2>Summary</h2>\n" + longChapter),
    (id: "chap_2", body: "<h2>Chapter 2</h2><p>The mill was gone.</p>"),
], storedOnly: false, folder: "EPUB", into: summaries)
summaryExpected.append(Expected(file: "Long Road Home.epub", outcome: "addedNoPairing", kind: "epub",
    title: "Long Road Home", author: "example-author-16", firstPageSource: "EPUB/introduction.xhtml",
    relationships: []))

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
try encoder.encode(expected).write(to: out.appendingPathComponent("expected.json"))
try encoder.encode(summaryExpected).write(to: summaries.appendingPathComponent("expected.json"))
print("Wrote \(expected.count) test files and expected.json to \(out.path), \(summaryExpected.count) to \(summaries.path)")
