import Foundation

/// Turns an (X)HTML document into plain text lines. Deliberately simple and offline:
/// nothing is loaded, no WebKit, safe on any thread.
///
/// Each step gives the same result as the regular expression in its comment (`<[^>]*>` and so on), but finds the end
/// of a match with one forward search: only the short, fixed-length start of a match (like `<br` and a word boundary)
/// is a regular expression. Letting the regex engine look for the end from every `<` again took time growing with the
/// square of the length on crafted files: 7.6 seconds for 40 KB, hours for a few MB (security scan, 4 November 2026).
public enum HTMLText {
    /// Start of `<(head|script|style|svg|template)\b.*?</\1\s*>`: an invisible element with everything inside it.
    private static let invisibleStart = try! NSRegularExpression(
        pattern: "<(head|script|style|svg|template)\\b", options: [.caseInsensitive])
    /// Start of `<br\b[^>]*>`.
    private static let lineBreakStart = try! NSRegularExpression(pattern: "<br\\b", options: [.caseInsensitive])
    /// Start of `</?(p|div|…)\b[^>]*>`.
    private static let blockTagStart = try! NSRegularExpression(
        pattern: "</?(p|div|h[1-6]|li|dt|dd|dl|ul|ol|tr|td|th|table|section|article|blockquote|header|footer|hr|pre|figure|figcaption|nav|aside|main|body|html)\\b",
        options: [.caseInsensitive])
    private static let entity = try! NSRegularExpression(pattern: "&(#[xX][0-9a-fA-F]{1,6}|#[0-9]{1,7}|[a-zA-Z][a-zA-Z0-9]{1,10});")

    public static func plainText(from html: String) -> String {
        let s = stripped(html, lineBreak: "\n")
        let lines = s.components(separatedBy: .newlines).map { line in
            line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Text with its paragraphs kept, for summaries (SPEC 5a rule 4): an empty line between block elements
    /// (paragraphs, headings, list items …), a line break for `<br>`, runs of spaces as one space.
    public static func paragraphText(from html: String) -> String {
        let lineBreakMark = "\u{E000}"  // a private-use character that never occurs in fic text
        let s = stripped(html, lineBreak: lineBreakMark)
        let paragraphs = s.components(separatedBy: .newlines).map { block in
            block.components(separatedBy: lineBreakMark)
                .map { $0.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ") }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
        return paragraphs.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    /// Comments and invisible elements removed, `<br>` replaced by `lineBreak`, block tags by a new line, all other
    /// tags removed, entities decoded.
    private static func stripped(_ html: String, lineBreak: String) -> String {
        var markup = Markup(html)
        markup.replace(markup.commentSpans(), with: "")
        markup.replace(markup.elementSpans(startingWith: invisibleStart), with: "")
        markup.replace(markup.tagSpans(startingWith: lineBreakStart), with: lineBreak)
        markup.replace(markup.tagSpans(startingWith: blockTagStart), with: "\n")
        markup.replace(markup.tagSpans(), with: "")
        return decodeEntities(markup.string)
    }

    /// A document as UTF-16 code units (the offsets `NSRegularExpression` uses). Each `…Spans` function returns the
    /// ranges its regular expression would replace, in order and without overlaps, in time proportional to the length.
    struct Markup {
        private(set) var units: [UInt16]
        private static let lessThan = UInt16(UInt8(ascii: "<")), greaterThan = UInt16(UInt8(ascii: ">"))
        private static let commentOpen = Array("<!--".utf16), commentClose = Array("-->".utf16)

        init(_ s: String) { units = Array(s.utf16) }

        var string: String { String(decoding: units, as: UTF16.self) }

        mutating func replace(_ spans: [Range<Int>], with template: String) {
            guard !spans.isEmpty else { return }
            let replacement = Array(template.utf16)
            var result: [UInt16] = []
            result.reserveCapacity(units.count)
            var copied = 0
            for span in spans {
                result += units[copied..<span.lowerBound]
                result += replacement
                copied = span.upperBound
            }
            result += units[copied...]
            units = result
        }

        /// `<!--.*?-->` (across lines).
        func commentSpans() -> [Range<Int>] {
            var spans: [Range<Int>] = []
            var position = 0
            while let start = find(Self.commentOpen, from: position),
                  let end = find(Self.commentClose, from: start + Self.commentOpen.count) {
                position = end + Self.commentClose.count
                spans.append(start..<position)
            }
            return spans
        }

        /// `<[^>]*>`. Without a `>` after a `<`, no later `<` has one either, so the search stops there.
        func tagSpans() -> [Range<Int>] {
            var spans: [Range<Int>] = []
            var position = 0
            while let start = find([Self.lessThan], from: position), let end = find([Self.greaterThan], from: start + 1) {
                position = end + 1
                spans.append(start..<position)
            }
            return spans
        }

        /// `start[^>]*>` for a start pattern that begins with `<` (so two starts never overlap).
        func tagSpans(startingWith start: NSRegularExpression) -> [Range<Int>] {
            var spans: [Range<Int>] = []
            var position = 0
            for match in matches(of: start) where match.range.location >= position {
                guard let end = find([Self.greaterThan], from: NSMaxRange(match.range)) else { break }
                position = end + 1
                spans.append(match.range.location..<position)
            }
            return spans
        }

        /// `start.*?</\1\s*>` (across lines, any case) for a start pattern `<(names)\b`. All closing tags of a name
        /// are found once, so a start without a closing tag costs no new search.
        func elementSpans(startingWith start: NSRegularExpression) -> [Range<Int>] {
            var spans: [Range<Int>] = []
            var position = 0
            var closers: [String: (tags: [NSRange], next: Int)] = [:]
            for match in matches(of: start) where match.range.location >= position {
                let name = string(in: match.range(at: 1))
                let key = name.lowercased()
                if closers[key] == nil {
                    let closer = try! NSRegularExpression(
                        pattern: "</" + NSRegularExpression.escapedPattern(for: name) + "\\s*>", options: [.caseInsensitive])
                    closers[key] = (matches(of: closer).map(\.range), 0)
                }
                let from = NSMaxRange(match.range)
                let tags = closers[key]!.tags
                var next = closers[key]!.next
                while next < tags.count, tags[next].location < from { next += 1 }
                closers[key]!.next = next
                guard next < tags.count else { continue }
                position = NSMaxRange(tags[next])
                spans.append(match.range.location..<position)
            }
            return spans
        }

        /// Where `needle` next occurs at or after `from`.
        private func find(_ needle: [UInt16], from: Int) -> Int? {
            guard let first = needle.first else { return nil }
            var i = max(from, 0)
            let last = units.count - needle.count
            while i <= last {
                if units[i] == first {
                    var k = 1
                    while k < needle.count, units[i + k] == needle[k] { k += 1 }
                    if k == needle.count { return i }
                }
                i += 1
            }
            return nil
        }

        private func matches(of regex: NSRegularExpression) -> [NSTextCheckingResult] {
            guard !units.isEmpty else { return [] }
            let text = units.withUnsafeBufferPointer { NSString(characters: $0.baseAddress!, length: $0.count) }
            return regex.matches(in: text as String, range: NSRange(location: 0, length: text.length))
        }

        private func string(in range: NSRange) -> String {
            String(decoding: units[range.location..<NSMaxRange(range)], as: UTF16.self)
        }
    }

    /// Text in a common legacy or Unicode encoding.
    public static func decode(_ data: Data) -> String {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16) ?? ""
        }
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        return String(data: data, encoding: .windowsCP1252) ?? String(decoding: data, as: UTF8.self)
    }

    static func decodeEntities(_ s: String) -> String {
        let ns = s as NSString
        let matches = entity.matches(in: s, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return s }
        var result = ""
        var last = 0
        for m in matches {
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let name = ns.substring(with: m.range(at: 1))
            result += character(for: name) ?? ns.substring(with: m.range)
            last = m.range.location + m.range.length
        }
        result += ns.substring(from: last)
        return result
    }

    private static func character(for name: String) -> String? {
        if name.hasPrefix("#x") || name.hasPrefix("#X") {
            return UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        if name.hasPrefix("#") {
            return UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
        }
        return named[name]
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "ndash": "–", "mdash": "—", "hellip": "…", "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
        "laquo": "«", "raquo": "»", "middot": "·", "bull": "•", "times": "×", "copy": "©", "reg": "®", "trade": "™",
        "aacute": "á", "agrave": "à", "acirc": "â", "auml": "ä", "atilde": "ã", "aring": "å", "aelig": "æ",
        "eacute": "é", "egrave": "è", "ecirc": "ê", "euml": "ë",
        "iacute": "í", "igrave": "ì", "icirc": "î", "iuml": "ï",
        "oacute": "ó", "ograve": "ò", "ocirc": "ô", "ouml": "ö", "otilde": "õ", "oslash": "ø",
        "uacute": "ú", "ugrave": "ù", "ucirc": "û", "uuml": "ü", "yacute": "ý", "yuml": "ÿ",
        "ntilde": "ñ", "ccedil": "ç", "szlig": "ß",
        "Aacute": "Á", "Agrave": "À", "Acirc": "Â", "Auml": "Ä", "Aring": "Å", "Eacute": "É", "Egrave": "È",
        "Iacute": "Í", "Oacute": "Ó", "Ouml": "Ö", "Oslash": "Ø", "Uacute": "Ú", "Uuml": "Ü", "Ntilde": "Ñ", "Ccedil": "Ç",
    ]
}
