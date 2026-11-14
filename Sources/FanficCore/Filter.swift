import Foundation

/// The choices of the Filter page (SPEC section 6, Filter): up to 5 tags that a fanfic must all have, and pairings,
/// fandoms, characters and tags it must not have. Kept in memory only; `library.json` doesn't change.
public struct WorkFilter: Sendable, Equatable {
    public static let maxTags = 5

    /// The four sidebar lists an entry can be left out from.
    public enum Kind: String, Sendable, CaseIterable, Identifiable {
        case pairing, fandom, character, tag
        public var id: String { rawValue }
    }

    /// One chosen entry: its group key (as in `PairingGroup.key` or `NameGroup.key`) and the name shown.
    public struct Entry: Sendable, Hashable, Identifiable {
        public var id: String { key }
        public let key: String
        public let display: String

        public init(key: String, display: String) {
            self.key = key
            self.display = display
        }

        /// The entry for a name typed or passed in: the same key its sidebar list gives it (`A/B` = `B/A`).
        public init(_ kind: Kind, name: String) {
            let tidy = FieldReader.collapse(name)
            self.init(key: kind == .pairing ? Relationship.parsed(tidy).groupKey : NameMatcher.key(tidy), display: tidy)
        }
    }

    /// The tags a fanfic must all have, in the order they were chosen.
    public private(set) var tags: [Entry] = []
    private var leftOut: [Kind: [Entry]] = [:]

    public init() {}

    /// Nothing chosen: every fanfic passes.
    public var isEmpty: Bool { tags.isEmpty && leftOut.values.allSatisfy(\.isEmpty) }

    public var canAddTag: Bool { tags.count < Self.maxTags }

    /// The entries left out from one list, in the order they were chosen.
    public func leftOut(_ kind: Kind) -> [Entry] { leftOut[kind] ?? [] }

    /// The keys already chosen on one row of the page (the tags row is `nil`).
    public func chosenKeys(leftOut kind: Kind?) -> Set<String> {
        Set((kind.map(leftOut) ?? tags).map(\.key))
    }

    /// Adds a tag that must be present. Refused when 5 are chosen or the tag is chosen already;
    /// a tag that was left out is taken off that row (rule 3).
    @discardableResult
    public mutating func addTag(_ entry: Entry) -> Bool {
        guard !entry.key.isEmpty, canAddTag, !tags.contains(where: { $0.key == entry.key }) else { return false }
        tags.append(entry)
        removeLeftOut(.tag, key: entry.key)
        return true
    }

    /// Leaves an entry out. Refused when it is left out already; a tag that had to be present is taken off that row.
    @discardableResult
    public mutating func leaveOut(_ kind: Kind, _ entry: Entry) -> Bool {
        guard !entry.key.isEmpty, !leftOut(kind).contains(where: { $0.key == entry.key }) else { return false }
        leftOut[kind, default: []].append(entry)
        if kind == .tag { removeTag(key: entry.key) }
        return true
    }

    public mutating func removeTag(key: String) {
        tags.removeAll { $0.key == key }
    }

    public mutating func removeLeftOut(_ kind: Kind, key: String) {
        leftOut[kind]?.removeAll { $0.key == key }
    }

    public mutating func clear() {
        tags = []
        leftOut = [:]
    }

    // MARK: Which fanfics pass

    /// True when the work has every chosen tag and none of the left-out entries. Leaving out an entry hides exactly
    /// the works its sidebar list counts beside it: characters come from pairings, and from friendship tags unless
    /// `includeFriendships` is off (as in the Characters list).
    public func matches(_ work: WorkRecord, includeFriendships: Bool = true) -> Bool {
        if !tags.isEmpty || !leftOut(.tag).isEmpty {
            let keys = Set(work.tags.map(NameMatcher.key))
            if !tags.allSatisfy({ keys.contains($0.key) }) { return false }
            if leftOut(.tag).contains(where: { keys.contains($0.key) }) { return false }
        }
        let fandoms = leftOut(.fandom)
        if !fandoms.isEmpty, work.fandoms.contains(where: { f in fandoms.contains { $0.key == NameMatcher.key(f) } }) {
            return false
        }
        let pairings = leftOut(.pairing)
        if !pairings.isEmpty,
           work.relationships.contains(where: { r in pairings.contains { $0.key == Relationship.parsed(r).groupKey } }) {
            return false
        }
        let characters = leftOut(.character)
        if !characters.isEmpty {
            for tag in work.relationships {
                let r = Relationship.parsed(tag)
                guard r.kind == .pairing || (r.kind == .friendship && includeFriendships) else { continue }
                if r.members.contains(where: { m in characters.contains { $0.key == NameMatcher.key(m) } }) { return false }
            }
        }
        return true
    }

    /// The works that pass, in the order given.
    public func apply(to works: [WorkRecord], includeFriendships: Bool = true) -> [WorkRecord] {
        isEmpty ? works : works.filter { matches($0, includeFriendships: includeFriendships) }
    }

    /// The work's own spellings of the chosen tags, in page order (shown on its tag line).
    public func chosenTags(in work: WorkRecord) -> [String] {
        guard !tags.isEmpty else { return [] }
        let keys = Set(tags.map(\.key))
        return work.tags.filter { keys.contains(NameMatcher.key($0)) }
    }

    // MARK: Adding

    /// What an Add field offers while text is typed: the list's entries that match by the word-start rule (SPEC
    /// section 6; for pairings the same rules as the search field, so `harry/draco` works too), without the ones
    /// already chosen on that row, most fanfics first (ties A–Z), at most `limit`. Nothing while the field is empty.
    public static func suggestions<Group: SidebarGroup & Identifiable>(
        _ typed: String, in groups: [Group], kind: Kind, excluding chosen: Set<String>, limit: Int = 6
    ) -> [Group] where Group.ID == String {
        let text = typed.trimmingCharacters(in: .whitespaces)
        guard !NameMatcher.key(text).isEmpty else { return [] }
        let found: [Group]
        if kind == .pairing {
            let query = PairingQuery(text)
            found = groups.filter { query.matches(Relationship.parsed($0.display)) }
        } else {
            found = groups.matching(text)
        }
        return Array(found.filter { !chosen.contains($0.id) }.sorted(by: .count).prefix(limit))
    }
}
