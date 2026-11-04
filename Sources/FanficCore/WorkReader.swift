import CoreText
import CryptoKit
import Foundation
import PDFKit

/// Everything read from one file before it is stored. Safe to pass between threads.
public struct PreparedWork: Sendable {
    public let kind: FileKind
    public let sha256: String
    public let fileData: Data
    /// The first-page copy as a one-page PDF.
    public let firstPagePDF: Data
    public let firstPageSource: String
    /// Plain text of the first page (what the pairings were read from).
    public let firstPageText: String
    public let hasRelationshipField: Bool
    public let relationships: [String]
    /// Values of the Fandom field (several for a crossover); empty when the page has none.
    public let fandoms: [String]
    public let title: String
    public let author: String?
    /// The work's summary (SPEC section 5a); nil when none was found.
    public let summary: String?
}

public enum ReadError: LocalizedError {
    case notSupported
    case notAPDF
    case locked
    case noText
    case cannotCopyPage

    public var errorDescription: String? {
        switch self {
        case .notSupported: "not a PDF or EPUB"
        case .notAPDF: "not a readable PDF"
        case .locked: "the PDF is password-protected"
        case .noText: "no text on the first pages (scanned or image-only?)"
        case .cannotCopyPage: "the first page could not be copied"
        }
    }
}

/// Reads a PDF or EPUB: hash, title, author, first page copy, relationships, fandoms and summary (SPEC sections 3, 5, 5a).
public enum WorkReader {
    /// How many pages (PDF) or text documents (EPUB) are checked for the Relationship field.
    static let pagesChecked = 3
    /// The summary is looked for on the first-page page or document and this many after it (SPEC 5a).
    static let summaryPagesAfterFirst = 2
    /// At most this many documents from the start of an EPUB's reading order are read (SPEC section 3), so a crafted
    /// reading order with thousands of empty or huge documents can't keep an import busy.
    public static let maxDocumentsTried = 50

    public static func read(_ url: URL) throws -> PreparedWork {
        guard let kind = FileKind(url: url) else { throw ReadError.notSupported }
        let data = try Data(contentsOf: url)
        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        switch kind {
        case .pdf: return try readPDF(data, fallbackTitle: fallbackTitle)
        case .epub: return try readEPUB(data, fallbackTitle: fallbackTitle)
        }
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: PDF

    static func readPDF(_ data: Data, fallbackTitle: String) throws -> PreparedWork {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else { throw ReadError.notAPDF }
        if document.isLocked { throw ReadError.locked }

        // One page more than checked, for a field that runs onto the next page.
        let texts = (0..<min(pagesChecked + 1, document.pageCount)).map { document.page(at: $0)?.string ?? "" }
        let checked = Array(texts.prefix(pagesChecked))
        guard checked.contains(where: hasVisibleText) else { throw ReadError.noText }

        let chosen = checked.firstIndex(where: RelationshipParser.hasField) ?? 0
        let next = chosen + 1 < texts.count ? texts[chosen + 1] : nil
        let tags = RelationshipParser.relationships(in: texts[chosen], nextPage: next)
        let fandoms = fandoms(in: texts, preferring: chosen, checked: checked.count)

        guard let page = document.page(at: chosen)?.copy() as? PDFPage else { throw ReadError.cannotCopyPage }
        let single = PDFDocument()
        single.insert(page, at: 0)
        guard let pageData = single.dataRepresentation() else { throw ReadError.cannotCopyPage }

        let attributes = document.documentAttributes ?? [:]
        return PreparedWork(
            kind: .pdf, sha256: sha256(data), fileData: data, firstPagePDF: pageData,
            firstPageSource: "page \(chosen + 1)", firstPageText: texts[chosen],
            hasRelationshipField: tags != nil, relationships: tags ?? [], fandoms: fandoms,
            title: nonEmpty(attributes[PDFDocumentAttribute.titleAttribute] as? String) ?? fallbackTitle,
            author: nonEmpty(attributes[PDFDocumentAttribute.authorAttribute] as? String),
            summary: pdfSummary(document, firstPage: chosen))
    }

    /// The summary on the first-page page or one of the two after it; a summary that reaches the end of its page
    /// goes on with the next page. PDF text has no paragraph marks, so its lines become one paragraph.
    static func pdfSummary(_ document: PDFDocument, firstPage chosen: Int) -> String? {
        func text(_ index: Int) -> String? { index < document.pageCount ? (document.page(at: index)?.string ?? "") : nil }
        for index in chosen...(chosen + summaryPagesAfterFirst) {
            guard let page = text(index) else { break }
            let result = SummaryReader.read(text: page, nextPage: text(index + 1), joinLines: true)
            if result != .noLabel { return result.summary }
        }
        return nil
    }

    // MARK: EPUB

    static func readEPUB(_ data: Data, fallbackTitle: String) throws -> PreparedWork {
        let book = try EPUBBook(data: data)

        // Text documents in reading order; image-only pages are skipped. Read one by one, only as far as needed.
        var documents: [(path: String, html: String, text: String)] = []
        var nextSpineIndex = 0
        func loadNextDocument() -> Bool {
            while nextSpineIndex < min(book.spinePaths.count, maxDocumentsTried) {
                let path = book.spinePaths[nextSpineIndex]
                nextSpineIndex += 1
                guard let html = try? book.html(at: path) else { continue }
                let text = HTMLText.plainText(from: html)
                guard hasVisibleText(text) else { continue }
                documents.append((path, html, text))
                return true
            }
            return false
        }
        while documents.count <= pagesChecked, loadNextDocument() {}
        guard !documents.isEmpty else { throw ReadError.noText }

        let chosen = documents.prefix(pagesChecked).firstIndex { RelationshipParser.hasField($0.text) } ?? 0
        let next = chosen + 1 < documents.count ? documents[chosen + 1].text : nil
        let text = documents[chosen].text
        let tags = RelationshipParser.relationships(in: text, nextPage: next)
        let fandoms = fandoms(in: documents.map(\.text), preferring: chosen, checked: min(pagesChecked, documents.count))

        // The summary: in AO3 EPUBs it is in the document after the tags (SPEC 5a).
        var summary: String?
        for index in chosen...(chosen + summaryPagesAfterFirst) {
            while documents.count <= index, loadNextDocument() {}
            guard index < documents.count else { break }
            let result = SummaryReader.read(html: documents[index].html)
            if result != .noLabel {
                summary = result.summary
                break
            }
        }

        return PreparedWork(
            kind: .epub, sha256: sha256(data), fileData: data,
            firstPagePDF: TextPage.pdf(from: text),
            firstPageSource: documents[chosen].path, firstPageText: text,
            hasRelationshipField: tags != nil, relationships: tags ?? [], fandoms: fandoms,
            title: nonEmpty(book.title) ?? fallbackTitle, author: nonEmpty(book.author), summary: summary)
    }

    /// The Fandom field from the chosen first page; if that page has none, from the other checked pages.
    static func fandoms(in texts: [String], preferring chosen: Int, checked: Int) -> [String] {
        let order = [chosen] + (0..<checked).filter { $0 != chosen }
        for index in order {
            let next = index + 1 < texts.count ? texts[index + 1] : nil
            if let values = FandomParser.fandoms(in: texts[index], nextPage: next) { return values }
        }
        return []
    }

    static func hasVisibleText(_ text: String) -> Bool {
        text.contains { $0.isLetter || $0.isNumber }
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }
}

/// Draws plain text onto one A4 PDF page with CoreText (no WebKit, nothing loaded from anywhere).
/// The first line is the heading; "Label:" at the start of a line is bold. Text that does not fit is cut off,
/// because this is the first page only.
public enum TextPage {
    /// Only the start of the text is laid out: far more than fits on the page (about 10,000 of the narrowest
    /// characters), so the page looks the same, but a crafted document with megabytes on one line isn't laid out whole.
    public static let maxCharacters = 50_000

    public static func pdf(from text: String) -> Data {
        let text = String(text.prefix(maxCharacters))
        let output = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: output as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }

        let regular = CTFontCreateUIFontForLanguage(.system, 11, nil) ?? CTFontCreateWithName("Helvetica" as CFString, 11, nil)
        let bold = CTFontCreateCopyWithSymbolicTraits(regular, 11, nil, .traitBold, .traitBold) ?? regular
        let heading = CTFontCreateCopyWithSymbolicTraits(regular, 17, nil, .traitBold, .traitBold) ?? bold
        let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
        let label = try? NSRegularExpression(pattern: "^[\\p{L}][\\p{L} ]{0,30}:")

        let body = NSMutableAttributedString()
        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            let labelMatch = label?.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length))
            // The first line is the heading, unless it is a "Label: value" line.
            let isHeading = index == 0 && labelMatch == nil
            let piece = NSMutableAttributedString(string: line + "\n", attributes: [fontKey: isHeading ? heading : regular])
            if let labelMatch { piece.addAttribute(fontKey, value: bold, range: labelMatch.range) }
            body.append(piece)
        }

        context.beginPDFPage(nil)
        let setter = CTFramesetterCreateWithAttributedString(body)
        let path = CGPath(rect: box.insetBy(dx: 56, dy: 56), transform: nil)
        CTFrameDraw(CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), path, nil), context)
        context.endPDFPage()
        context.closePDF()
        return output as Data
    }
}
