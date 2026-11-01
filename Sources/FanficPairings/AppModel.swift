import AppKit
import FanficCore
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum SidebarItem: Hashable {
    case all
    case noPairing
    case fandom(String)     // NameGroup.key — a filter; the search field searches inside it
    case character(String)  // NameGroup.key — fills the search field
    case pairing(String)    // PairingGroup.key — fills the search field
}

struct ReportSheet: Identifiable {
    let id = UUID()
    var report: ImportReport
}

struct AppMessage: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

/// State of the one window, plus the actions behind buttons, menus, drag and drop and "Open With".
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let library: Library
    var searchText = ""
    var sidebarSelection: SidebarItem? = .all
    var selectedWorkID: UUID?
    var reportSheet: ReportSheet?
    var message: AppMessage?
    var workPendingRemoval: WorkRecord?
    /// Developer option `-previewDrop YES`: shows the drop highlight for screenshots.
    var previewDropHighlight = false
    private var importChain: Task<Void, Never>?
    /// The last search result, reused until the search, the sidebar selection or the library changes.
    @ObservationIgnored private var hitsCache: (search: String, selection: SidebarItem?, revision: Int, hits: [SearchHit])?

    init() {
        let defaults = UserDefaults.standard
        // Developer option `-libraryPath <folder>`: use another library folder (for tests and screenshots).
        let root = defaults.string(forKey: "libraryPath").map {
            URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true)
        } ?? Library.defaultRoot
        library = Library(root: root)
        if let problem = library.loadProblem {
            message = AppMessage(title: "The library file could not be read", text: problem)
        }
        if let search = defaults.string(forKey: "search") {
            searchText = search
            sidebarSelection = nil
        }
        // Developer option `-sidebar "fandom:<name>"`, `"character:<name>"` or `"pairing:<name>"` (screenshots).
        if let item = defaults.string(forKey: "sidebar"), let colon = item.firstIndex(of: ":") {
            let name = String(item[item.index(after: colon)...])
            switch item[..<colon] {
            case "fandom": sidebarSelection = .fandom(NameMatcher.key(name))
            case "character": sidebarSelection = .character(NameMatcher.key(name)); searchText = name
            case "pairing": sidebarSelection = .pairing(Relationship(name).groupKey); searchText = name
            default: break
            }
        }
        // Developer option `-importOnLaunch <file or folder>`: imports into this instance's library at start
        // (for screenshots and tests, so no system-wide "open" event can reach another running copy of the app).
        if let path = defaults.string(forKey: "importOnLaunch") {
            importFiles([URL(fileURLWithPath: (path as NSString).expandingTildeInPath)])
        }
        // A library written by version 1 gets its fandoms once; IDs stay the same.
        if library.needsUpgrade {
            Task { await library.upgradeIfNeeded() }
        }
        if let title = defaults.string(forKey: "selectTitle") {
            selectedWorkID = library.works.first { $0.title == title }?.workID
        }
        previewDropHighlight = defaults.bool(forKey: "previewDrop")
    }

    // MARK: What the window shows

    var hits: [SearchHit] {
        let search = searchText, selection = sidebarSelection, revision = library.revision
        if let cache = hitsCache, cache.search == search, cache.selection == selection, cache.revision == revision {
            return cache.hits
        }
        let hits: [SearchHit]
        switch selection {
        case .noPairing:
            hits = Search.run("", in: library.worksWithoutPairing)
        case .fandom(let key):
            hits = Search.run(search, in: library.works.filter { $0.fandoms.contains { NameMatcher.key($0) == key } })
        default:
            hits = Search.run(search, in: library.works)
        }
        hitsCache = (search, selection, revision, hits)
        return hits
    }

    /// The selected fandom's name, when a fandom is selected.
    var selectedFandomName: String? {
        guard case .fandom(let key) = sidebarSelection else { return nil }
        return library.fandomList().first { $0.key == key }?.display
    }

    private func pairingName(_ key: String) -> String? {
        library.groups.first { $0.key == key }?.display
    }

    private func characterName(_ key: String) -> String? {
        library.characterList().first { $0.key == key }?.display
    }

    var selectedWork: WorkRecord? { selectedWorkID.flatMap(library.work) }

    /// A pairing clicked in the sidebar goes into the search field.
    func sidebarChanged() {
        switch sidebarSelection {
        case .pairing(let key):
            if let name = pairingName(key) { searchText = name }
        case .character(let key):
            if let name = characterName(key) { searchText = name }
        case .all, .noPairing, .fandom:
            searchText = ""
        case nil:
            break
        }
    }

    /// Typing in the search field leaves the sidebar selection unless it still describes the search.
    /// A selected fandom stays selected: the search then runs inside it.
    func searchChanged() {
        switch sidebarSelection {
        case .pairing(let key): if pairingName(key) == searchText { return }
        case .character(let key): if characterName(key) == searchText { return }
        case .fandom: return
        default: break
        }
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            if sidebarSelection != .noPairing { sidebarSelection = .all }
        } else {
            sidebarSelection = nil
        }
    }

    // MARK: Import

    func addFilesWithPanel() {
        let panel = NSOpenPanel()
        panel.title = "Add Fanfics"
        panel.message = "Choose EPUB or PDF files, or folders that contain them."
        panel.prompt = "Add"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [.pdf, .epub]
        if panel.runModal() == .OK { importFiles(panel.urls) }
    }

    /// Imports run one after another; the summary sheet collects all of them until it is closed.
    func importFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let previous = importChain
        importChain = Task {
            await previous?.value
            let report = await library.importFiles(urls)
            if var sheet = reportSheet {
                sheet.report.items += report.items
                reportSheet = sheet
            } else {
                reportSheet = ReportSheet(report: report)
            }
            if selectedWorkID == nil {
                selectedWorkID = report.items.first { $0.outcome == .added || $0.outcome == .addedNoPairing }?.workID
            }
        }
    }

    // MARK: Work actions

    func open(_ work: WorkRecord) {
        NSWorkspace.shared.open(library.url(of: work.storedFile))
    }

    func openFirstPage(_ work: WorkRecord) {
        NSWorkspace.shared.open(library.url(of: work.firstPageFile))
    }

    func showInFinder(_ work: WorkRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([library.url(of: work.storedFile)])
    }

    func showLibraryInFinder() {
        NSWorkspace.shared.open(library.root)
    }

    func confirmRemoval(of work: WorkRecord) {
        workPendingRemoval = work
    }

    func remove(_ work: WorkRecord) {
        do {
            try library.remove(work.workID)
            if selectedWorkID == work.workID { selectedWorkID = nil }
        } catch {
            message = AppMessage(title: "“\(work.title)” could not be removed", text: error.localizedDescription)
        }
        if case .pairing(let key) = sidebarSelection, !library.groups.contains(where: { $0.key == key }) {
            sidebarSelection = .all
        }
    }

    func rereadLibrary() {
        Task {
            let result = await library.rereadAll()
            var text = "\(result.updated) of \(library.works.count) fanfics were read again. Their IDs did not change."
            if !result.failed.isEmpty { text += "\n\nProblems:\n" + result.failed.joined(separator: "\n") }
            message = AppMessage(title: "Library re-read", text: text)
        }
    }
}
