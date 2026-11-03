import Foundation

/// Reads a work's summary (SPEC section 5a).
///
/// AO3 puts the summary after the tags: in EPUBs in the next text document, as a "Summary" paragraph followed by a
/// `blockquote`; in PDFs after the title and author. The caller looks at the first-page document and the two after
/// it and stops at the first one where a label is found (`.found` or `.none`).
public enum SummaryReader {
    /// AO3 allows 1,250 characters; anything longer than this is not taken as a summary (rule 5).
    public static let maxLength = 1_500

    public enum Result: Equatable, Sendable {
        /// No "Summary" label in this text: look at the next document.
        case noLabel
        /// A label was found, but there is no usable summary (empty or too long). Stop looking.
        case none
        case found(String)

        /// The summary, or nil when there is none.
        public var summary: String? {
            if case .found(let text) = self { return text }
            return nil
        }
    }

    // MARK: EPUB (HTML)

    /// A "Summary" element on its own, e.g. `<p>Summary</p>` or `<h2>Summary:</h2>`.
    private static let htmlLabel = try! NSRegularExpression(pattern: ">\\s*Summary\\s*:?\\s*<", options: [.caseInsensitive])
    /// Closing tags and spaces, then a `<blockquote …>` (checked right after the label).
    private static let blockquoteStart = try! NSRegularExpression(
        pattern: "(?:\\s|</[a-zA-Z0-9]+\\s*>)*<blockquote\\b[^>]*>", options: [.caseInsensitive])
    private static let blockquoteTag = try! NSRegularExpression(pattern: "<(/?)blockquote\\b[^>]*>", options: [.caseInsensitive])

    /// The summary in one EPUB document: AO3's blockquote if it follows the label (rule 2), otherwise the text after
    /// the label up to the next label (rule 3).
    public static func read(html: String) -> Result {
        let ns = html as NSString
        if let label = htmlLabel.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) {
            let afterLabel = label.range.location + label.range.length - 1  // the "<" after the label
            if let start = blockquoteStart.firstMatch(in: html, options: [.anchored],
                                                      range: NSRange(location: afterLabel, length: ns.length - afterLabel)) {
                let contentStart = start.range.location + start.range.length
                let contentEnd = matchingBlockquoteEnd(in: html, from: contentStart) ?? ns.length
                let inner = ns.substring(with: NSRange(location: contentStart, length: contentEnd - contentStart))
                return checked(HTMLText.paragraphText(from: inner))
            }
        }
        return read(text: HTMLText.paragraphText(from: html), joinLines: false)
    }

    /// Where the blockquote that starts before `from` ends (nested blockquotes are counted).
    private static func matchingBlockquoteEnd(in html: String, from: Int) -> Int? {
        let ns = html as NSString
        var depth = 1
        for tag in blockquoteTag.matches(in: html, range: NSRange(location: from, length: ns.length - from)) {
            depth += ns.substring(with: tag.range(at: 1)).isEmpty ? 1 : -1
            if depth == 0 { return tag.range.location }
        }
        return nil
    }

    // MARK: Text (PDF pages, and EPUBs without AO3's blockquote)

    /// A line that is only the label: "Summary" or "Summary:".
    private static let labelOnly = try! NSRegularExpression(pattern: "^Summary\\s*:?$", options: [.caseInsensitive])
    /// "Summary:" followed by the start of the summary on the same line.
    private static let labelInline = try! NSRegularExpression(pattern: "^Summary\\s*:\\s*(\\S.*)$", options: [.caseInsensitive])
    /// A line that ends the summary: AO3's next headings, or a field label from SPEC section 5 rule 2.
    private static let endLabel = try! NSRegularExpression(
        pattern: "^(?:Notes\\s*:?$|Chapter\\s+\\d+\\b|Chapter\\s+Text\\b|Work\\s+Text\\b|See\\s+the\\s+end\\s+of\\s+the\\s+work\\b|(?:Relationships?|Fandoms?|Characters?|Additional\\s+Tags|Freeform|Language|Series|Collections?|Stats|Published|Updated|Completed|Words|Chapters|Summary|Notes|Rating|Archive\\s+Warnings?|Categor(?:y|ies))\\s*:)",
        options: [.caseInsensitive])

    /// The summary in plain text. `nextPage` is read too when the summary reaches the end of `text` (PDF pages).
    /// `joinLines`: PDF text has no paragraph marks, so its lines are joined into one paragraph; otherwise empty
    /// lines separate paragraphs and other line breaks are kept.
    public static func read(text: String, nextPage: String? = nil, joinLines: Bool) -> Result {
        let lines = text.components(separatedBy: "\n").map(trimmed)
        guard let labelIndex = lines.firstIndex(where: { matches(labelOnly, $0) || matches(labelInline, $0) }) else {
            return .noLabel
        }
        var collected: [String] = []
        if let first = capture(labelInline, in: lines[labelIndex]) { collected.append(first) }

        var ended = false
        for line in lines[(labelIndex + 1)...] {
            if matches(endLabel, line) { ended = true; break }
            collected.append(line)
        }
        if !ended, let nextPage {
            for line in nextPage.components(separatedBy: "\n").map(trimmed) {
                if matches(endLabel, line) { break }
                collected.append(line)
            }
        }
        return checked(joinLines ? joined(collected) : paragraphs(collected))
    }

    // MARK: Tidying and the length rule

    private static func checked(_ summary: String) -> Result {
        if summary.isEmpty || summary.count > maxLength { return .none }
        return .found(summary)
    }

    /// Lines as they are; runs of empty lines become one paragraph break; no empty lines at either end.
    private static func paragraphs(_ lines: [String]) -> String {
        var result: [String] = []
        var pendingBreak = false
        for line in lines {
            if line.isEmpty {
                pendingBreak = !result.isEmpty
                continue
            }
            if pendingBreak { result.append("") }
            result.append(line)
            pendingBreak = false
        }
        return result.joined(separator: "\n")
    }

    /// All lines joined into one paragraph.
    private static func joined(_ lines: [String]) -> String {
        lines.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Spaces collapsed, nothing at either end.
    private static func trimmed(_ line: String) -> String {
        line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func matches(_ regex: NSRegularExpression, _ s: String) -> Bool {
        regex.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
    }

    private static func capture(_ regex: NSRegularExpression, in s: String) -> String? {
        guard let m = regex.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)),
              m.numberOfRanges > 1, m.range(at: 1).location != NSNotFound else { return nil }
        return (s as NSString).substring(with: m.range(at: 1))
    }
}
