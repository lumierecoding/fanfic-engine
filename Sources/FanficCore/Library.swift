import Foundation
import Observation

/// The library folder: Works/, First Pages/ and library.json (SPEC sections 2–4 and 7).
///
/// Big libraries: the sidebar lists are built once per change and remembered (`pairingList`, `characterList`,
/// `fandomList`), works are found by ID and by file fingerprint through lookup tables, and a batch import
/// saves library.json at most every few seconds instead of after every file.
@MainActor
@Observable
public final class Library {
    public let root: URL
    public private(set) var works: [WorkRecord] = []
    /// Goes up by one whenever `works` changes, so views and caches know when to recompute.
    public private(set) var revision = 0
    /// Set when library.json existed but could not be read (it is kept aside, never overwritten).
    public private(set) var loadProblem: String?
    /// True when library.json is an older version (1: no fandoms, 2: no summaries) that still has to be read again
    /// once; see `upgradeIfNeeded()`.
    public private(set) var needsUpgrade = false
    /// The version of library.json as it was loaded (nil when there was none).
    @ObservationIgnored private var loadedVersion: Int?
    public private(set) var isBusy = false

    @ObservationIgnored private var indexByID: [UUID: Int] = [:]
    @ObservationIgnored private var indexBySHA: [String: Int] = [:]
    @ObservationIgnored private var pairingLists: [String: [PairingGroup]] = [:]
    @ObservationIgnored private var nameLists: [String: [NameGroup]] = [:]

    /// During a batch import, library.json is saved at most this often (and always at the end).
    static let saveInterval: Duration = .seconds(3)

    nonisolated public static var defaultRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fanfic Engine", isDirectory: true)
    }

    /// The library folder of the app's working title "Fanfic Pairings" (before the first release).
    nonisolated public static var legacyRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fanfic Pairings", isDirectory: true)
    }

    public enum FolderMove: Equatable, Sendable {
        case moved
        case notNeeded
        case failed(String)
    }

    /// Moves a library from the old folder to the new one, once: only when the old folder exists and the new one
    /// doesn't. The folder is moved (renamed) as a whole, never copied, merged or deleted; the paths inside
    /// library.json are relative, so nothing in it changes.
    nonisolated public static func moveLegacyLibrary(from old: URL = legacyRoot, to new: URL = defaultRoot) -> FolderMove {
        let fm = FileManager.default
        guard fm.fileExists(atPath: old.path), !fm.fileExists(atPath: new.path) else { return .notNeeded }
        do {
            try fm.moveItem(at: old, to: new)
            return .moved
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    public var worksFolder: URL { root.appendingPathComponent("Works", isDirectory: true) }
    public var firstPagesFolder: URL { root.appendingPathComponent("First Pages", isDirectory: true) }
    public var libraryFile: URL { root.appendingPathComponent("library.json") }

    public init(root: URL = Library.defaultRoot) {
        self.root = root
        load()
    }

    public func url(of relativePath: String) -> URL { root.appendingPathComponent(relativePath) }

    public func work(_ id: UUID) -> WorkRecord? {
        guard let i = indexByID[id], i < works.count else { return nil }
        return works[i]
    }

    public var worksWithoutPairing: [WorkRecord] { works.filter { $0.relationships.isEmpty } }

    // MARK: Sidebar lists (built once per change)

    /// All pairings, A–Z, friendships included (what library.json lists).
    public var groups: [PairingGroup] { pairingList() }

    public func pairingList(includeFriendships: Bool = true, sort: SidebarSort = .name) -> [PairingGroup] {
        let key = "\(includeFriendships)-\(sort.rawValue)"
        _ = revision  // views that call this are redrawn when the works change
        if let cached = pairingLists[key] { return cached }
        let list = sort == .name
            ? PairingGroup.groups(for: works, includeFriendships: includeFriendships)
            : pairingList(includeFriendships: includeFriendships, sort: .name).sorted(by: .count)
        pairingLists[key] = list
        return list
    }

    public func characterList(includeFriendships: Bool = true, sort: SidebarSort = .name) -> [NameGroup] {
        let key = "characters-\(includeFriendships)-\(sort.rawValue)"
        _ = revision
        if let cached = nameLists[key] { return cached }
        let list = sort == .name
            ? NameGroup.characters(in: works, includeFriendships: includeFriendships)
            : characterList(includeFriendships: includeFriendships, sort: .name).sorted(by: .count)
        nameLists[key] = list
        return list
    }

    public func fandomList(sort: SidebarSort = .name) -> [NameGroup] {
        let key = "fandoms-\(sort.rawValue)"
        _ = revision
        if let cached = nameLists[key] { return cached }
        let list = sort == .name ? NameGroup.fandoms(in: works) : fandomList(sort: .name).sorted(by: .count)
        nameLists[key] = list
        return list
    }

    /// Call after any change to `works`: rebuilds the lookup tables and forgets the lists.
    private func worksChanged() {
        indexByID = Dictionary(works.enumerated().map { ($1.workID, $0) }, uniquingKeysWith: { first, _ in first })
        indexBySHA = Dictionary(works.enumerated().map { ($1.sha256, $0) }, uniquingKeysWith: { first, _ in first })
        pairingLists.removeAll()
        nameLists.removeAll()
        revision += 1
    }

    /// Adds one work during an import. The lists and `revision` are refreshed by `listsChanged()` when the batch
    /// is saved, so a big import does not rebuild every list after every file.
    private func append(_ record: WorkRecord) {
        works.append(record)
        indexByID[record.workID] = works.count - 1
        indexBySHA[record.sha256] = works.count - 1
    }

    private func listsChanged() {
        pairingLists.removeAll()
        nameLists.removeAll()
        revision += 1
    }

    // MARK: Loading and saving

    func load() {
        let fm = FileManager.default
        try? fm.createDirectory(at: worksFolder, withIntermediateDirectories: true)
        try? fm.createDirectory(at: firstPagesFolder, withIntermediateDirectories: true)
        defer { worksChanged() }
        guard fm.fileExists(atPath: libraryFile.path) else {
            works = []
            return
        }
        do {
            let file = try Self.decoder.decode(LibraryHeader.self, from: Data(contentsOf: libraryFile))
            works = file.works
            loadedVersion = file.version
            needsUpgrade = file.version < LibraryFile.currentVersion && !file.works.isEmpty
        } catch {
            // Keep the unreadable file aside instead of overwriting it.
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let aside = root.appendingPathComponent("library-unreadable-\(stamp).json")
            try? fm.moveItem(at: libraryFile, to: aside)
            loadProblem = "library.json could not be read and was kept as \(aside.lastPathComponent). \(error.localizedDescription)"
            works = []
        }
    }

    /// Writes library.json (version 3) in one atomic write, with the lists of SPEC section 4.
    /// The lists always include friendship tags; the Settings switch only changes the sidebar.
    func save() throws {
        let groups = pairingList()
        let characters = characterList()
        let fandoms = fandomList()
        func refs(_ ids: [UUID]) -> [WorkRef] {
            ids.compactMap { id in work(id).map { WorkRef(workID: id, firstPageID: $0.firstPageID) } }
        }
        let file = LibraryFile(
            version: LibraryFile.currentVersion,
            works: works,
            pairings: groups.map(\.display),
            pairingIndex: groups.map { PairingIndexEntry(pairing: $0.display, works: refs($0.workIDs)) },
            characters: characters.map(\.display),
            characterIndex: characters.map { CharacterIndexEntry(character: $0.display, works: refs($0.workIDs)) },
            fandoms: fandoms.map(\.display),
            fandomIndex: fandoms.map { FandomIndexEntry(fandom: $0.display, works: refs($0.workIDs)) })
        try Self.encoder.encode(file).write(to: libraryFile, options: .atomic)
    }

    /// The copy of the old library.json kept before an upgrade, e.g. `library-v2-backup.json` (SPEC 5a).
    public var upgradeBackupFile: URL? {
        loadedVersion.map { root.appendingPathComponent("library-v\($0)-backup.json") }
    }

    /// Re-reads an older library once so every work gets its fandoms (version 1) and summary (version 2).
    /// IDs do not change. The old library.json is copied to `library-v<N>-backup.json` first (an existing backup is
    /// kept); if that copy can't be made, nothing is changed.
    public func upgradeIfNeeded() async {
        guard needsUpgrade, let backup = upgradeBackupFile else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: backup.path) {
            do { try fm.copyItem(at: libraryFile, to: backup) } catch { return }
        }
        let result = await rereadAll()
        if result.failed.isEmpty { needsUpgrade = false }
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]  // same key order every time
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: Import

    /// Imports files and folders (folders are searched, including subfolders). Files are read off the main thread.
    /// library.json is saved at most every `saveInterval` and at the end; if a save fails, the works added since
    /// the last save are taken out again and reported as "could not be saved".
    public func importFiles(_ urls: [URL]) async -> ImportReport {
        isBusy = true
        defer { isBusy = false }
        var report = ImportReport()
        var pending: [(record: WorkRecord, item: ImportReport.Item)] = []
        var lastSave = ContinuousClock.now

        func flush() {
            guard !pending.isEmpty else { return }
            listsChanged()
            do {
                try save()
                report.items += pending.map(\.item)
            } catch {
                let ids = Set(pending.map(\.record.workID))
                works.removeAll { ids.contains($0.workID) }
                worksChanged()
                for entry in pending {
                    try? FileManager.default.removeItem(at: url(of: entry.record.storedFile))
                    try? FileManager.default.removeItem(at: url(of: entry.record.firstPageFile))
                    report.items.append(.init(fileName: entry.item.fileName, outcome: .unreadable,
                                              detail: "could not be saved: \(Self.describe(error))", workID: nil))
                }
            }
            pending.removeAll()
            lastSave = .now
        }

        let (files, skipped) = Self.expand(urls)
        for url in skipped {
            report.items.append(.init(fileName: url.lastPathComponent, outcome: .skipped, detail: nil, workID: nil))
        }
        for url in files {
            let name = url.lastPathComponent
            let prepared: PreparedWork
            do {
                prepared = try await Task.detached(priority: .userInitiated) { try WorkReader.read(url) }.value
            } catch {
                report.items.append(.init(fileName: name, outcome: .unreadable, detail: Self.describe(error), workID: nil))
                continue
            }
            if let i = indexBySHA[prepared.sha256], i < works.count {
                report.items.append(.init(fileName: name, outcome: .duplicate, detail: works[i].title, workID: works[i].workID))
                continue
            }
            do {
                let record = try writeCopies(prepared, originalFileName: name)
                append(record)
                pending.append((record, .init(fileName: name, outcome: record.relationships.isEmpty ? .addedNoPairing : .added,
                                              detail: nil, workID: record.workID)))
            } catch {
                report.items.append(.init(fileName: name, outcome: .unreadable,
                                          detail: "could not be saved: \(Self.describe(error))", workID: nil))
            }
            if ContinuousClock.now - lastSave > Self.saveInterval { flush() }
        }
        flush()
        return report
    }

    /// Gives the work its two IDs and writes both copies. Removes what it wrote if a step fails.
    private func writeCopies(_ prepared: PreparedWork, originalFileName: String) throws -> WorkRecord {
        let workID = UUID()
        let firstPageID = UUID()
        let record = WorkRecord(
            workID: workID, firstPageID: firstPageID, kind: prepared.kind,
            originalFileName: originalFileName,
            storedFile: "Works/\(workID.uuidString).\(prepared.kind.rawValue)",
            firstPageFile: "First Pages/\(firstPageID.uuidString).pdf",
            firstPageSource: prepared.firstPageSource,
            title: prepared.title, author: prepared.author, sha256: prepared.sha256,
            importedAt: Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down)),  // library.json keeps whole seconds
            relationships: prepared.relationships, fandoms: prepared.fandoms, summary: prepared.summary)
        let workURL = url(of: record.storedFile)
        let pageURL = url(of: record.firstPageFile)
        do {
            try prepared.fileData.write(to: workURL, options: .atomic)
            try prepared.firstPagePDF.write(to: pageURL, options: .atomic)
            return record
        } catch {
            try? FileManager.default.removeItem(at: workURL)
            try? FileManager.default.removeItem(at: pageURL)
            throw error
        }
    }

    /// Splits dropped/opened items into PDF/EPUB files and skipped files. Folder contents are sorted by name.
    static func expand(_ urls: [URL]) -> (files: [URL], skipped: [URL]) {
        var files: [URL] = []
        var skipped: [URL] = []
        let fm = FileManager.default
        func classify(_ url: URL) {
            if FileKind(url: url) != nil { files.append(url) } else { skipped.append(url) }
        }
        for url in urls {
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { skipped.append(url); continue }
            guard isDirectory.boolValue else { classify(url); continue }
            let found = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey],
                                      options: [.skipsHiddenFiles, .skipsPackageDescendants])?
                .compactMap { $0 as? URL }
                .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
                ?? []
            found.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }.forEach(classify)
        }
        return (files, skipped)
    }

    // MARK: Remove and re-read

    /// Deletes the work's copy, its first-page copy and its entries in library.json.
    public func remove(_ workID: UUID) throws {
        guard let index = indexByID[workID], index < works.count else { return }
        let record = works.remove(at: index)
        worksChanged()
        do {
            try save()
        } catch {
            works.insert(record, at: index)
            worksChanged()
            throw error
        }
        try? FileManager.default.removeItem(at: url(of: record.storedFile))
        try? FileManager.default.removeItem(at: url(of: record.firstPageFile))
    }

    /// Reads every stored work again with the current rules. IDs stay; first pages, pairings, fandoms and summaries
    /// are replaced.
    public func rereadAll() async -> (updated: Int, failed: [String]) {
        isBusy = true
        defer { isBusy = false }
        var updated = 0
        var failed: [String] = []
        for record in works {
            let storedURL = url(of: record.storedFile)
            do {
                let prepared = try await Task.detached(priority: .userInitiated) { try WorkReader.read(storedURL) }.value
                try prepared.firstPagePDF.write(to: url(of: record.firstPageFile), options: .atomic)
                guard let i = indexByID[record.workID], i < works.count else { continue }
                works[i].relationships = prepared.relationships
                works[i].fandoms = prepared.fandoms
                works[i].summary = prepared.summary
                works[i].firstPageSource = prepared.firstPageSource
                updated += 1
            } catch {
                failed.append("\(record.title): \(Self.describe(error))")
            }
        }
        worksChanged()
        do { try save() } catch { failed.append("library.json: \(Self.describe(error))") }
        return (updated, failed)
    }

    static func describe(_ error: Error) -> String { error.localizedDescription }
}
