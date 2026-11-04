import Foundation
import Testing
@testable import FanficCore

/// Crafted files from the security scan of 4 November 2026 (SPEC section 3): each must be refused or read quickly,
/// and the faster code must give exactly the same results as the code it replaced.
@Suite("Security")
struct SecurityTests {
    // MARK: Limits

    @Test("An EPUB part that claims to unpack to 4 GB is refused before anything is unpacked")
    func oversizedEntry() throws {
        // An empty deflate block (2 bytes) that claims 0xFFFF_FFFE bytes: the old code reserved 4 GB for it.
        let data = zipData([("mimetype", Data("application/epub+zip".utf8))],
                           crafted: ("META-INF/container.xml", method: 8, size: 0xFFFF_FFFE, raw: Data([0x03, 0x00])))
        let archive = try ZipArchive(data: data)
        #expect(throws: ZipArchive.ZipError.self) { try archive.contents(of: "META-INF/container.xml") }
        do {
            _ = try archive.contents(of: "META-INF/container.xml")
        } catch let error as ZipArchive.ZipError {
            #expect(error.localizedDescription == "META-INF/container.xml inside the EPUB is larger than 16 MB")
        }
        #expect(throws: (any Error).self) { try EPUBBook(data: data) }

        // Just over the limit is refused, the limit itself is not.
        let tooBig = zipData([], crafted: ("big.xhtml", method: 8, size: UInt32(ZipArchive.maxEntrySize + 1), raw: Data([0x03, 0x00])))
        #expect(throws: ZipArchive.ZipError.self) { try ZipArchive(data: tooBig).contents(of: "big.xhtml") }
        let stored = zipData([("ok.xhtml", Data(count: 1000))])
        #expect(try ZipArchive(data: stored).contents(of: "ok.xhtml").count == 1000)
    }

    @Test("At most 50 documents of an EPUB's reading order are read")
    func documentLimit() throws {
        let empty = "<html><body><img src=\"x.png\"/></body></html>"
        let text = "<html><body><p>Relationship: Harry Potter/Draco Malfoy</p></body></html>"
        let within = try WorkReader.readEPUB(epubData(Array(repeating: empty, count: 49) + [text]), fallbackTitle: "x")
        #expect(within.relationships == ["Harry Potter/Draco Malfoy"])
        #expect(throws: ReadError.self) {
            try WorkReader.readEPUB(epubData(Array(repeating: empty, count: 50) + [text]), fallbackTitle: "x")
        }
    }

    // MARK: Crafted files that used to freeze the app

    @Test("Crafted markup is read in a few seconds at most", arguments: [
        ("<", 400_000), ("<!--", 100_000), ("<head", 80_000), ("<HEAD", 80_000), ("<script", 50_000), ("<br", 130_000),
        ("<p", 200_000), ("</div", 80_000), ("<blockquote", 36_000), ("> ", 200_000), ("<head></head>", 30_000),
        ("x", 2_000_000), ("x ", 1_000_000), ("<br>", 500_000),
    ])
    func craftedMarkup(piece: String, count: Int) throws {
        // The flood ends the document: no `>` or closing tag after it, the worst case for the old regular expressions.
        let flood = String(repeating: piece, count: count)
        let doc = "<html><body><p>Relationship: Harry Potter/Draco Malfoy</p><p>Summary:</p><blockquote class=\"userstuff\">"
            + "<p>A summary.</p>" + flood
        var work: PreparedWork?
        let time = try seconds { work = try WorkReader.readEPUB(epubData([doc]), fallbackTitle: "x") }
        #expect(work?.relationships == ["Harry Potter/Draco Malfoy"])
        #expect(time < 5, "\(count) × \(piece): \(time) s")
    }

    @Test("Crafted pairing tags with many equal names are searched instantly")
    func craftedPairingTags() throws {
        let many = Array(repeating: "A", count: 14)
        let tagB = (many + ["B"]).joined(separator: "/"), tagC = (many + ["C"]).joined(separator: "/")
        let id = UUID()
        let work = WorkRecord(workID: id, firstPageID: UUID(), kind: .pdf, originalFileName: "x.pdf", storedFile: "", firstPageFile: "",
                              firstPageSource: "page 1", title: "x", author: nil, sha256: id.uuidString, importedAt: Date(),
                              relationships: [tagB, tagC])
        var hits: [SearchHit] = []
        let time = seconds { hits = Search.run(tagB, in: [work]) }
        #expect(hits.first?.matched == [tagB])
        #expect(time < 1, "\(time) s")
        // The longest tag AO3 allows (150 characters), all one name.
        let long = Array(repeating: "A", count: 74).joined(separator: "/") + "/B"
        #expect(seconds { _ = PairingQuery.assign(Array(repeating: "a", count: 75), to: long.split(separator: "/").map(String.init)) } < 1)
    }

    // MARK: Same results as before

    @Test("Plain text and paragraphs are the same as with the old regular expressions (all test files)")
    func sameTextForTestFiles() throws {
        let folders = [fixturesFolder, summaryFixturesFolder]
        var documents = 0
        for folder in folders {
            for name in files(in: folder) where name.hasSuffix(".epub") {
                guard let book = try? EPUBBook(data: Data(contentsOf: folder.appendingPathComponent(name))) else { continue }
                for path in book.spinePaths {
                    guard let html = try? book.html(at: path) else { continue }
                    #expect(HTMLText.plainText(from: html) == RegexHTMLText.plainText(from: html), "\(name) \(path)")
                    #expect(HTMLText.paragraphText(from: html) == RegexHTMLText.paragraphText(from: html), "\(name) \(path)")
                    documents += 1
                }
            }
        }
        #expect(documents >= 20, "\(documents) documents")
    }

    @Test("Plain text and paragraphs are the same as with the old regular expressions (5,000 random documents)")
    func sameTextForRandomMarkup() {
        let pieces = ["<", ">", "<!--", "-->", "<!-", "--", "-", "<head>", "</head>", "<HEAD ", "</head >", "</HeAd\n>", "<headx>",
                      "<script>", "</script>", "<style>", "</style >", "<svg", "</svg>", "<template>", "</Template >", "<br>",
                      "<br/>", "<BR ", "<brx>", "<p>", "</p>", "<p class=\"x\">", "<pre>", "<blockquote>", "</blockquote>",
                      "<h1>", "<h7>", "<b>", "</b>", "text", "Relationship: A/B", " ", "  ", "\n", "\t", "&amp;", "&lt;",
                      "&#233;", "é", "😀", "\u{E000}"]
        var random = SplitMix(seed: 20261104)
        for _ in 0..<5_000 {
            let length = Int.random(in: 0...40, using: &random)
            let doc = (0..<length).map { _ in pieces.randomElement(using: &random)! }.joined()
            #expect(HTMLText.plainText(from: doc) == RegexHTMLText.plainText(from: doc), "\(doc.debugDescription)")
            #expect(HTMLText.paragraphText(from: doc) == RegexHTMLText.paragraphText(from: doc), "\(doc.debugDescription)")
        }
    }

    @Test("Pairing matching gives the same answers as trying every order (20,000 random cases)")
    func sameMatching() {
        let members = ["Harry Potter", "Draco Malfoy", "Harry", "Hermione Granger", "Ron Weasley", "Draco", "H", "Harry Potter"]
        let queries = ["harry", "draco", "dra", "her", "ron", "h", "malfoy", "potter", "harry potter", "x"].map(NameMatcher.key)
        var random = SplitMix(seed: 42)
        var yes = 0
        for _ in 0..<20_000 {
            let k = (0..<Int.random(in: 1...4, using: &random)).map { _ in queries.randomElement(using: &random)! }
            let m = (0..<Int.random(in: 1...5, using: &random)).map { _ in members.randomElement(using: &random)! }
            let answer = PairingQuery.assign(k, to: m)
            #expect(answer == triedEveryOrder(k, m), "\(k) → \(m)")
            if answer { yes += 1 }
        }
        #expect(yes > 1_000)
    }
}

// MARK: - Helpers

/// The pairing matcher before the security scan: tries every order (correct, but factorial time).
private func triedEveryOrder(_ keys: [String], _ members: [String]) -> Bool {
    guard keys.count <= members.count else { return false }
    var used = [Bool](repeating: false, count: members.count)
    func place(_ i: Int) -> Bool {
        if i == keys.count { return true }
        for j in members.indices where !used[j] && NameMatcher.matches(queryKey: keys[i], member: members[j]) {
            used[j] = true
            if place(i + 1) { return true }
            used[j] = false
        }
        return false
    }
    return place(0)
}

/// `HTMLText` before the security scan, with whole regular expressions (same results, quadratic time on crafted files).
private enum RegexHTMLText {
    static let comments = try! NSRegularExpression(pattern: "<!--.*?-->", options: [.dotMatchesLineSeparators])
    static let invisible = try! NSRegularExpression(
        pattern: "<(head|script|style|svg|template)\\b.*?</\\1\\s*>", options: [.caseInsensitive, .dotMatchesLineSeparators])
    static let lineBreak = try! NSRegularExpression(pattern: "<br\\b[^>]*>", options: [.caseInsensitive])
    static let blockTag = try! NSRegularExpression(
        pattern: "</?(p|div|h[1-6]|li|dt|dd|dl|ul|ol|tr|td|th|table|section|article|blockquote|header|footer|hr|pre|figure|figcaption|nav|aside|main|body|html)\\b[^>]*>",
        options: [.caseInsensitive])
    static let anyTag = try! NSRegularExpression(pattern: "<[^>]*>", options: [.dotMatchesLineSeparators])

    static func stripped(_ html: String, lineBreak mark: String) -> String {
        var s = html
        s = replace(comments, in: s, with: "")
        s = replace(invisible, in: s, with: "")
        s = replace(lineBreak, in: s, with: mark)
        s = replace(blockTag, in: s, with: "\n")
        s = replace(anyTag, in: s, with: "")
        return HTMLText.decodeEntities(s)
    }

    static func plainText(from html: String) -> String {
        let lines = stripped(html, lineBreak: "\n").components(separatedBy: .newlines).map { line in
            line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    static func paragraphText(from html: String) -> String {
        let lineBreakMark = "\u{E000}"
        let paragraphs = stripped(html, lineBreak: lineBreakMark).components(separatedBy: .newlines).map { block in
            block.components(separatedBy: lineBreakMark)
                .map { $0.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ") }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
        return paragraphs.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    static func replace(_ regex: NSRegularExpression, in s: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length),
                                       withTemplate: NSRegularExpression.escapedTemplate(for: template))
    }
}

/// A repeatable random number generator, so a failing random case can be found again.
private struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private func seconds(_ body: () throws -> Void) rethrows -> Double {
    let start = ContinuousClock.now
    try body()
    let elapsed = ContinuousClock.now - start
    return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
}

/// A minimal ZIP file with stored entries (CRC left at 0: ZipArchive doesn't check it), plus optionally one crafted
/// entry with its own method, declared unpacked size and raw bytes.
private func zipData(_ entries: [(String, Data)], crafted: (name: String, method: UInt16, size: UInt32, raw: Data)? = nil) -> Data {
    var out = Data(), central = Data()
    func u16(_ v: UInt16, _ d: inout Data) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
    func u32(_ v: UInt32, _ d: inout Data) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
    let all = entries.map { (name: $0.0, method: UInt16(0), size: UInt32($0.1.count), raw: $0.1) } + (crafted.map { [$0] } ?? [])
    for entry in all {
        let offset = UInt32(out.count), name = Data(entry.name.utf8)
        u32(0x0403_4B50, &out); u16(20, &out); u16(0, &out); u16(entry.method, &out); u16(0, &out); u16(0, &out); u32(0, &out)
        u32(UInt32(entry.raw.count), &out); u32(entry.size, &out); u16(UInt16(name.count), &out); u16(0, &out)
        out += name; out += entry.raw
        u32(0x0201_4B50, &central); u16(20, &central); u16(20, &central); u16(0, &central); u16(entry.method, &central)
        u16(0, &central); u16(0, &central); u32(0, &central); u32(UInt32(entry.raw.count), &central); u32(entry.size, &central)
        u16(UInt16(name.count), &central); u16(0, &central); u16(0, &central); u16(0, &central); u16(0, &central)
        u32(0, &central); u32(offset, &central)
        central += name
    }
    let directoryOffset = UInt32(out.count)
    out += central
    u32(0x0605_4B50, &out); u16(0, &out); u16(0, &out); u16(UInt16(all.count), &out); u16(UInt16(all.count), &out)
    u32(UInt32(central.count), &out); u32(directoryOffset, &out); u16(0, &out)
    return out
}

/// An EPUB with the given (X)HTML documents in its reading order.
private func epubData(_ docs: [String]) -> Data {
    let container = """
        <?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles>\
        <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>
        """
    let manifest = docs.indices.map { "<item id=\"d\($0)\" href=\"d\($0).xhtml\" media-type=\"application/xhtml+xml\"/>" }.joined()
    let spine = docs.indices.map { "<itemref idref=\"d\($0)\"/>" }.joined()
    let package = """
        <?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0">\
        <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Crafted</dc:title></metadata>\
        <manifest>\(manifest)</manifest><spine>\(spine)</spine></package>
        """
    let entries = [("mimetype", Data("application/epub+zip".utf8)), ("META-INF/container.xml", Data(container.utf8)),
                   ("content.opf", Data(package.utf8))]
        + docs.enumerated().map { ("d\($0.offset).xhtml", Data($0.element.utf8)) }
    return zipData(entries)
}
