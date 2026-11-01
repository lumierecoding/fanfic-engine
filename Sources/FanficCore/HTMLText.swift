import Foundation

/// Turns an (X)HTML document into plain text lines. Deliberately simple and offline:
/// nothing is loaded, no WebKit, safe on any thread.
public enum HTMLText {
    private static let comments = try! NSRegularExpression(pattern: "<!--.*?-->", options: [.dotMatchesLineSeparators])
    private static let invisible = try! NSRegularExpression(
        pattern: "<(head|script|style|svg|template)\\b.*?</\\1\\s*>", options: [.caseInsensitive, .dotMatchesLineSeparators])
    private static let lineBreak = try! NSRegularExpression(pattern: "<br\\b[^>]*>", options: [.caseInsensitive])
    private static let blockTag = try! NSRegularExpression(
        pattern: "</?(p|div|h[1-6]|li|dt|dd|dl|ul|ol|tr|td|th|table|section|article|blockquote|header|footer|hr|pre|figure|figcaption|nav|aside|main|body|html)\\b[^>]*>",
        options: [.caseInsensitive])
    private static let anyTag = try! NSRegularExpression(pattern: "<[^>]*>", options: [.dotMatchesLineSeparators])
    private static let entity = try! NSRegularExpression(pattern: "&(#[xX][0-9a-fA-F]{1,6}|#[0-9]{1,7}|[a-zA-Z][a-zA-Z0-9]{1,10});")

    public static func plainText(from html: String) -> String {
        var s = html
        s = replace(comments, in: s, with: "")
        s = replace(invisible, in: s, with: "")
        s = replace(lineBreak, in: s, with: "\n")
        s = replace(blockTag, in: s, with: "\n")
        s = replace(anyTag, in: s, with: "")
        s = decodeEntities(s)
        let lines = s.components(separatedBy: .newlines).map { line in
            line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
        }
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
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

    private static func replace(_ regex: NSRegularExpression, in s: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: template)
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
