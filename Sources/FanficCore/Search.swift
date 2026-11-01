import Foundation
import Synchronization

/// A small thread-safe memo table. Names repeat across a library (the same character in hundreds of tags),
/// so normalising each distinct string once instead of on every comparison is what keeps big libraries fast.
final class Memo<Value: Sendable>: Sendable {
    private let table = Mutex<[String: Value]>([:])
    private let limit: Int

    init(limit: Int = 200_000) { self.limit = limit }

    func value(for key: String, compute: (String) -> Value) -> Value {
        if let hit = table.withLock({ $0[key] }) { return hit }
        let value = compute(key)
        table.withLock { t in
            if t.count >= limit { t.removeAll(keepingCapacity: true) }
            t[key] = value
        }
        return value
    }
}

/// Name comparison rules (SPEC section 6).
public enum NameMatcher {
    private static let wordMemo = Memo<[String]>()
    private static let keyMemo = Memo<String>()
    private static let suffixMemo = Memo<[String]>()
    private static let sortMemo = Memo<String>()

    /// Lower case, accents removed, split at every character that is not a letter or digit.
    public static func words(_ s: String) -> [String] {
        wordMemo.value(for: s) { s in
            let folded = s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil).lowercased()
            var words: [String] = []
            var current = ""
            for ch in folded {
                if ch.isLetter || ch.isNumber {
                    current.append(ch)
                } else if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
            }
            if !current.isEmpty { words.append(current) }
            return words
        }
    }

    /// The words joined without spaces: "Draco  Malfoy" and "dracomalfoy" both give "dracomalfoy".
    public static func key(_ s: String) -> String {
        keyMemo.value(for: s) { words($0).joined() }
    }

    /// The member's words joined from each word onwards: "Lan Zhan | Lan Wangji" →
    /// ["lanzhanlanwangji", "zhanlanwangji", "lanwangji", "wangji"].
    static func suffixKeys(_ member: String) -> [String] {
        suffixMemo.value(for: member) { member in
            let w = words(member)
            return w.indices.map { w[$0...].joined() }
        }
    }

    /// For sorting A–Z ignoring case and accents.
    static func sortKey(_ s: String) -> String {
        sortMemo.value(for: s) { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
    }

    /// True when the query name (spaces removed) is the start of the member's words joined from some word onwards.
    /// "Draco", "malfoy", "draco malfoy" match "Draco Malfoy"; "Ron" does not match "Aaron Hotchner".
    public static func matches(query: String, member: String) -> Bool {
        matches(queryKey: key(query), member: member)
    }

    /// Same as `matches(query:member:)` with the query already turned into a key.
    static func matches(queryKey q: String, member: String) -> Bool {
        guard !q.isEmpty else { return false }
        return suffixKeys(member).contains { $0.hasPrefix(q) }
    }
}

/// A search typed by the user: "A/B", "B / A", "A & B", "A", or empty.
public struct PairingQuery: Sendable, Equatable {
    public enum Mode: Sendable, Equatable {
        case everything
        case pairing([String])
        case friendship([String])
        case name(String)
    }

    public let mode: Mode
    /// The names of the query as keys, worked out once per search instead of once per comparison.
    private let keys: [String]

    public init(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        func names(_ separator: Character) -> [String] {
            text.split(separator: separator)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !NameMatcher.key($0).isEmpty }
        }
        if text.contains("/") {
            let n = names("/")
            mode = n.isEmpty ? .everything : .pairing(n)
        } else if text.contains("&") {
            let n = names("&")
            mode = n.isEmpty ? .everything : .friendship(n)
        } else if NameMatcher.key(text).isEmpty {
            mode = .everything
        } else {
            mode = .name(text)
        }
        switch mode {
        case .everything: keys = []
        case .pairing(let n), .friendship(let n): keys = n.map(NameMatcher.key)
        case .name(let n): keys = [NameMatcher.key(n)]
        }
    }

    public var isEverything: Bool { mode == .everything }

    /// Whether one relationship matches. (An empty query matches no single relationship;
    /// it lists every work instead, see `Search.run`.)
    public func matches(_ r: Relationship) -> Bool {
        switch mode {
        case .everything:
            return false
        case .pairing:
            return r.kind == .pairing && Self.assign(keys, to: r.members)
        case .friendship:
            return r.kind == .friendship && Self.assign(keys, to: r.members)
        case .name:
            return r.members.contains { NameMatcher.matches(queryKey: keys[0], member: $0) }
        }
    }

    /// Each query name must match a different member, in any order.
    static func assign(_ keys: [String], to members: [String]) -> Bool {
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
}

public struct SearchHit: Identifiable, Hashable, Sendable {
    public var id: UUID { work.workID }
    public let work: WorkRecord
    /// The work's relationship tags that matched the query (empty for an empty query).
    public let matched: Set<String>

    public init(work: WorkRecord, matched: Set<String>) {
        self.work = work
        self.matched = matched
    }
}

public enum Search {
    /// Works whose relationships match the query, sorted by title then author. An empty query lists every work.
    public static func run(_ query: String, in works: [WorkRecord]) -> [SearchHit] {
        let q = PairingQuery(query)
        var hits: [SearchHit] = []
        for work in works {
            if q.isEverything {
                hits.append(SearchHit(work: work, matched: []))
                continue
            }
            let matched = work.relationships.filter { q.matches(Relationship.parsed($0)) }
            if !matched.isEmpty { hits.append(SearchHit(work: work, matched: Set(matched))) }
        }
        return hits.sorted { a, b in
            let ta = NameMatcher.sortKey(a.work.title), tb = NameMatcher.sortKey(b.work.title)
            if ta != tb { return ta < tb }
            return NameMatcher.sortKey(a.work.author ?? "") < NameMatcher.sortKey(b.work.author ?? "")
        }
    }
}
