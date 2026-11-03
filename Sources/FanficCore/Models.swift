import Foundation

public enum FileKind: String, Codable, Sendable, CaseIterable {
    case pdf
    case epub

    public init?(url: URL) {
        self.init(rawValue: url.pathExtension.lowercased())
    }

    public var label: String { rawValue.uppercased() }
}

/// One imported work. `library.json` → `works` (SPEC section 4).
public struct WorkRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID { workID }

    public let workID: UUID
    public var firstPageID: UUID
    public let kind: FileKind
    public let originalFileName: String
    /// Relative to the library folder, e.g. "Works/<work ID>.pdf".
    public var storedFile: String
    /// Relative to the library folder, e.g. "First Pages/<first-page ID>.pdf".
    public var firstPageFile: String
    /// "page 1", "page 2" or the EPUB document path that became the first page.
    public var firstPageSource: String
    public var title: String
    public var author: String?
    public let sha256: String
    public let importedAt: Date
    /// The relationship tags in the order they appear on the page.
    public var relationships: [String]
    /// The Fandom field's values (several for a crossover). Empty in version 1 libraries until they are re-read.
    public var fandoms: [String] = []
    /// The summary (SPEC section 5a); nil when none was found, and in version 1 and 2 libraries until they are re-read.
    /// Left out of library.json when nil.
    public var summary: String? = nil
}

extension WorkRecord {
    enum CodingKeys: String, CodingKey {
        case workID, firstPageID, kind, originalFileName, storedFile, firstPageFile, firstPageSource
        case title, author, sha256, importedAt, relationships, fandoms, summary
    }

    /// Reads version 1 and 2 entries too (they have no `fandoms` / `summary`).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        workID = try c.decode(UUID.self, forKey: .workID)
        firstPageID = try c.decode(UUID.self, forKey: .firstPageID)
        kind = try c.decode(FileKind.self, forKey: .kind)
        originalFileName = try c.decode(String.self, forKey: .originalFileName)
        storedFile = try c.decode(String.self, forKey: .storedFile)
        firstPageFile = try c.decode(String.self, forKey: .firstPageFile)
        firstPageSource = try c.decode(String.self, forKey: .firstPageSource)
        title = try c.decode(String.self, forKey: .title)
        author = try c.decodeIfPresent(String.self, forKey: .author)
        sha256 = try c.decode(String.self, forKey: .sha256)
        importedAt = try c.decode(Date.self, forKey: .importedAt)
        relationships = try c.decode([String].self, forKey: .relationships)
        fandoms = try c.decodeIfPresent([String].self, forKey: .fandoms) ?? []
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
    }
}

/// A work ID with its first-page ID, as listed in the index lists of `library.json`.
public struct WorkRef: Codable, Hashable, Sendable {
    public let workID: UUID
    public let firstPageID: UUID
}

/// `library.json` → `pairingIndex` entry.
public struct PairingIndexEntry: Codable, Hashable, Sendable {
    public let pairing: String
    public let works: [WorkRef]
}

/// `library.json` → `characterIndex` entry.
public struct CharacterIndexEntry: Codable, Hashable, Sendable {
    public let character: String
    public let works: [WorkRef]
}

/// `library.json` → `fandomIndex` entry.
public struct FandomIndexEntry: Codable, Hashable, Sendable {
    public let fandom: String
    public let works: [WorkRef]
}

/// The whole `library.json` file (version 3: version 2 plus `summary` per work).
public struct LibraryFile: Codable, Sendable {
    public static let currentVersion = 3

    public var version: Int
    public var works: [WorkRecord]
    /// Every pairing once, sorted alphabetically.
    public var pairings: [String]
    /// Every pairing with the work ID and first-page ID of each work that has it.
    public var pairingIndex: [PairingIndexEntry]
    /// Every person named in a relationship tag, once, sorted alphabetically.
    public var characters: [String]
    public var characterIndex: [CharacterIndexEntry]
    /// Every fandom once, sorted alphabetically.
    public var fandoms: [String]
    public var fandomIndex: [FandomIndexEntry]
}

/// The part of `library.json` needed to load it; works for version 1, 2 and 3 files.
struct LibraryHeader: Decodable {
    var version: Int
    var works: [WorkRecord]
}

/// How the sidebar lists are sorted (Settings).
public enum SidebarSort: String, CaseIterable, Sendable {
    case name
    case count
}

/// Shared by the pairing, character and fandom lists.
public protocol SidebarGroup {
    var display: String { get }
    var workIDs: [UUID] { get }
}

extension Array where Element: SidebarGroup {
    /// By name (A–Z, ignoring case and accents) or by number of fanfics (largest first, ties A–Z).
    public func sorted(by order: SidebarSort) -> [Element] {
        sorted { a, b in
            if order == .count, a.workIDs.count != b.workIDs.count { return a.workIDs.count > b.workIDs.count }
            return PairingGroup.alphabetical(a.display, b.display)
        }
    }
}

/// A character or a fandom in the sidebar: one name (most common spelling) with the works that have it.
public struct NameGroup: Identifiable, Hashable, Sendable, SidebarGroup {
    public var id: String { key }
    /// `NameMatcher.key` of the name: the same for spellings that differ only in case, accents or spacing.
    public let key: String
    public let display: String
    public let workIDs: [UUID]

    /// Every person named in a relationship tag (pairings, and friendships unless switched off), once.
    /// This is not the first page's separate "Characters:" field.
    public static func characters(in works: [WorkRecord], includeFriendships: Bool = true) -> [NameGroup] {
        collect(works) { work in
            work.relationships.flatMap { tag -> [String] in
                let r = Relationship.parsed(tag)
                switch r.kind {
                case .pairing: return r.members
                case .friendship: return includeFriendships ? r.members : []
                case .single: return []
                }
            }
        }
    }

    /// Every fandom once; a crossover counts in each of its fandoms.
    public static func fandoms(in works: [WorkRecord]) -> [NameGroup] {
        collect(works) { $0.fandoms }
    }

    private static let tidyMemo = Memo<String>()

    static func collect(_ works: [WorkRecord], names: (WorkRecord) -> [String]) -> [NameGroup] {
        var groups = GroupCollector()
        for work in works {
            for raw in names(work) {
                let name = tidyMemo.value(for: raw) { FieldReader.collapse($0) }
                let key = NameMatcher.key(name)
                guard !key.isEmpty else { continue }
                groups.add(key: key, spelling: name, kind: .single, work: work.workID)
            }
        }
        return groups.sortedEntries().map { NameGroup(key: $0.key, display: $0.display, workIDs: $0.entry.workIDs) }
    }
}

/// Collects tags or names per group key in one pass: the works that have them, and how often each spelling
/// is used (most groups have one spelling, so the spelling table is only made when a second one turns up).
struct GroupCollector {
    struct Entry {
        var spelling: String
        var count = 0
        var otherSpellings: [String: Int]?
        let kind: Relationship.Kind
        var workIDs: [UUID] = []

        mutating func add(_ s: String, work: UUID) {
            if s == spelling { count += 1 } else { otherSpellings = otherSpellings ?? [:]; otherSpellings![s, default: 0] += 1 }
            // All tags of one work come one after another, so checking the last entry is enough.
            if workIDs.last != work { workIDs.append(work) }
        }

        /// The spelling used most often; on a tie, the first A–Z.
        var display: String {
            guard let otherSpellings else { return spelling }
            var best = (spelling, count)
            for (s, c) in otherSpellings where c > best.1 || (c == best.1 && PairingGroup.alphabetical(s, best.0)) {
                best = (s, c)
            }
            return best.0
        }
    }

    private(set) var entries: [String: Entry] = [:]

    mutating func add(key: String, spelling: String, kind: Relationship.Kind, work: UUID) {
        entries[key, default: Entry(spelling: spelling, kind: kind)].add(spelling, work: work)
    }

    /// Entries sorted A–Z by display name (ignoring case and accents), each sort key worked out once.
    func sortedEntries() -> [(key: String, display: String, entry: Entry)] {
        typealias Item = (sortKey: String, key: String, display: String, entry: Entry)
        var items: [Item] = []
        items.reserveCapacity(entries.count)
        for (key, entry) in entries {
            let display = entry.display
            items.append((sortKey: NameMatcher.sortKey(display), key: key, display: display, entry: entry))
        }
        items.sort { (a: Item, b: Item) -> Bool in
            a.sortKey == b.sortKey ? a.display < b.display : a.sortKey < b.sortKey
        }
        return items.map { (key: $0.key, display: $0.display, entry: $0.entry) }
    }
}

/// A pairing as shown in the sidebar: "A/B" and "B/A" together, with the works that have it.
public struct PairingGroup: Identifiable, Hashable, Sendable, SidebarGroup {
    public var id: String { key }
    public let key: String
    public let display: String
    public let kind: Relationship.Kind
    public let workIDs: [UUID]

    /// Groups the relationships of `works` (SPEC sections 4 and 6), sorted alphabetically ignoring case and accents.
    public static func groups(for works: [WorkRecord], includeFriendships: Bool = true) -> [PairingGroup] {
        var groups = GroupCollector()
        for work in works {
            for tag in work.relationships {
                let r = Relationship.parsed(tag)
                if r.kind == .friendship && !includeFriendships { continue }
                groups.add(key: r.groupKey, spelling: tag, kind: r.kind, work: work.workID)
            }
        }
        return groups.sortedEntries().map {
            PairingGroup(key: $0.key, display: $0.display, kind: $0.entry.kind, workIDs: $0.entry.workIDs)
        }
    }

    /// A–Z ignoring case and accents; exact spelling breaks ties so the order is always the same.
    static func alphabetical(_ a: String, _ b: String) -> Bool {
        let ka = NameMatcher.sortKey(a), kb = NameMatcher.sortKey(b)
        return ka == kb ? a < b : ka < kb
    }
}

/// What happened to each file of one import (SPEC section 3).
public struct ImportReport: Sendable {
    public enum Outcome: String, Sendable, CaseIterable {
        case added
        case addedNoPairing
        case duplicate
        case unreadable
        case skipped

        public var heading: String {
            switch self {
            case .added: "Added"
            case .addedNoPairing: "Added, no pairing found"
            case .duplicate: "Already in library"
            case .unreadable: "Could not read"
            case .skipped: "Skipped (not a PDF or EPUB)"
            }
        }
    }

    public struct Item: Identifiable, Sendable {
        public let id = UUID()
        public let fileName: String
        public let outcome: Outcome
        public let detail: String?
        public let workID: UUID?
    }

    public var items: [Item] = []

    public init() {}

    public func items(_ outcome: Outcome) -> [Item] { items.filter { $0.outcome == outcome } }
    public var addedCount: Int { items(.added).count + items(.addedNoPairing).count }
}
