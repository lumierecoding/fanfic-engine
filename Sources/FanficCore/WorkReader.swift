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

/// Reads a PDF or EPUB: hash, title, author, first page copy and relationships (SPEC section 3).
public enum WorkReader {
    /// How many pages (PDF) or text documents (EPUB) are checked for the Relationship field.
    static let pagesChecked = 3

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
            author: nonEmpty(attributes[PDFDocumentAttribute.authorAttribute] as? String))
    }

    // MARK: EPUB

    static func readEPUB(_ data: Data, fallbackTitle: String) throws -> PreparedWork {
        let book = try EPUBBook(data: data)

        // Text documents in reading order; image-only pages are skipped.
        var documents: [(path: String, text: String)] = []
        for path in book.spinePaths {
            guard let text = try? book.text(at: path), hasVisibleText(text) else { continue }
            documents.append((path, text))
            if documents.count > pagesChecked { break }
        }
        guard !documents.isEmpty else { throw ReadError.noText }

        let chosen = documents.prefix(pagesChecked).firstIndex { RelationshipParser.hasField($0.text) } ?? 0
        let next = chosen + 1 < documents.count ? documents[chosen + 1].text : nil
        let text = documents[chosen].text
        let tags = RelationshipParser.relationships(in: text, nextPage: next)
        let fandoms = fandoms(in: documents.map(\.text), preferring: chosen, checked: min(pagesChecked, documents.count))

        return PreparedWork(
            kind: .epub, sha256: sha256(data), fileData: data,
            firstPagePDF: TextPage.pdf(from: text),
            firstPageSource: documents[chosen].path, firstPageText: text,
            hasRelationshipField: tags != nil, relationships: tags ?? [], fandoms: fandoms,
            title: nonEmpty(book.title) ?? fallbackTitle, author: nonEmpty(book.author))
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
    public static func pdf(from text: String) -> Data {
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
