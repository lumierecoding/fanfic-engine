import Foundation

/// One entry of a work's Relationship field, e.g. "Harry Potter/Draco Malfoy" or "Harry Potter & Ron Weasley".
public struct Relationship: Hashable, Sendable {
    public enum Kind: String, Sendable, Codable {
        case pairing      // A/B, A/B/C
        case friendship   // A & B
        case single       // neither / nor &
    }

    public let text: String
    public let kind: Kind
    public let members: [String]
    /// Same key for "A/B" and "B/A" (and any spelling differences in case, accents or spacing).
    public let groupKey: String

    public init(_ tag: String) {
        text = tag
        let kind: Kind
        var members = [tag]
        if tag.contains("/") || tag.contains("&") {
            kind = tag.contains("/") ? .pairing : .friendship
            let parts = tag.split(separator: kind == .pairing ? "/" : "&")
                .map(Self.trimmed)
                .filter { !$0.isEmpty }
            if !parts.isEmpty { members = parts }
        } else {
            kind = .single
        }
        self.kind = kind
        self.members = members
        groupKey = kind.rawValue + ":" + members.map(NameMatcher.key).sorted().joined(separator: "|")
    }

    /// Spaces removed from both ends (plain Swift, faster than Foundation's trimming for many tags).
    private static func trimmed(_ part: Substring) -> String {
        var sub = part
        while let first = sub.first, first.isWhitespace { sub.removeFirst() }
        while let last = sub.last, last.isWhitespace { sub.removeLast() }
        return String(sub)
    }

    private static let memo = Memo<Relationship>()

    /// The parsed tag, worked out once per distinct tag text and then remembered.
    public static func parsed(_ tag: String) -> Relationship {
        memo.value(for: tag) { Relationship($0) }
    }
}

/// Reads one labelled field ("Relationship:", "Fandom:" …) from the text of a first page (SPEC section 5).
/// The field ends at the next AO3 label or at the end of the page; then the next page is read too,
/// but only if it ends the field.
public enum FieldReader {
    /// AO3 tags are at most 150 characters; anything longer is not a tag.
    public static let maxTagLength = 150

    /// Every AO3 label that can follow a field on a first page.
    private static let nextLabel = try! NSRegularExpression(
        pattern: "\\b(?:Relationships?|Fandoms?|Characters?|Additional\\s+Tags|Freeform|Language|Series|Collections?|Stats|Published|Updated|Completed|Words|Chapters|Summary|Notes|Rating|Archive\\s+Warnings?|Categor(?:y|ies))\\s*:",
        options: [.caseInsensitive])
    private static let spacedSlash = try! NSRegularExpression(pattern: "\\s*/\\s*")
    private static let spacedAmpersand = try! NSRegularExpression(pattern: "\\s*&\\s*")

    public static func has(_ label: NSRegularExpression, in text: String) -> Bool {
        label.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    /// The field's values in page order; nil when the label is not on the page, [] when the field is empty.
    public static func values(_ label: NSRegularExpression, in text: String, nextPage: String? = nil) -> [String]? {
        let ns = text as NSString
        guard let start = label.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let rest = ns.substring(from: start.range.location + start.range.length)

        let field: String
        if let end = endOfField(in: rest) {
            field = String(rest[..<end])
        } else if let nextPage, let end = endOfField(in: nextPage) {
            field = rest + "\n" + String(nextPage[..<end])
        } else {
            field = rest
        }
        return tags(in: field)
    }

    /// Splits a field's text into tidied tags (split at commas, line breaks joined, repeats dropped).
    /// A piece longer than any tag means free text ran into the field: its first line is kept if that
    /// is a tag, and reading stops there.
    public static func tags(in field: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for rawPart in field.split(separator: ",") {
            var tag = collapse(String(rawPart))
            var stop = false
            if tag.count > maxTagLength {
                tag = rawPart.split(whereSeparator: \.isNewline).map { collapse(String($0)) }.first { !$0.isEmpty } ?? ""
                stop = true
            }
            tag = replace(spacedSlash, in: tag, with: "/")
            tag = replace(spacedAmpersand, in: tag, with: " & ")
            tag = tag.trimmingCharacters(in: CharacterSet(charactersIn: " .;&/"))
            if !tag.isEmpty, tag.count <= maxTagLength, !seen.contains(tag) {
                seen.insert(tag)
                result.append(tag)
            }
            if stop { break }
        }
        return result
    }

    /// All runs of spaces and line breaks become one space.
    static func collapse(_ s: String) -> String {
        s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func endOfField(in s: String) -> String.Index? {
        guard let m = nextLabel.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)),
              let range = Range(m.range, in: s) else { return nil }
        return range.lowerBound
    }

    private static func replace(_ regex: NSRegularExpression, in s: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: template)
    }
}

/// The Relationship field (SPEC section 5).
public enum RelationshipParser {
    public static let maxTagLength = FieldReader.maxTagLength
    static let label = try! NSRegularExpression(pattern: "\\bRelationships?\\s*:", options: [.caseInsensitive])

    public static func hasField(_ text: String) -> Bool { FieldReader.has(label, in: text) }

    /// The relationship tags on the page, in page order.
    /// Returns nil when the page has no Relationship label, [] when the field is empty.
    public static func relationships(in text: String, nextPage: String? = nil) -> [String]? {
        FieldReader.values(label, in: text, nextPage: nextPage)
    }

    public static func tags(in field: String) -> [String] { FieldReader.tags(in: field) }
}

/// The Fandom field (SPEC section 5): "Fandom:" or "Fandoms:", split at commas. Crossovers list several.
public enum FandomParser {
    static let label = try! NSRegularExpression(pattern: "\\bFandoms?\\s*:", options: [.caseInsensitive])

    public static func hasField(_ text: String) -> Bool { FieldReader.has(label, in: text) }

    /// The fandom tags on the page; nil when the page has no Fandom label.
    public static func fandoms(in text: String, nextPage: String? = nil) -> [String]? {
        FieldReader.values(label, in: text, nextPage: nextPage)
    }
}
