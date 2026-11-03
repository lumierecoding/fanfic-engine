import Foundation
import PDFKit
import Testing
@testable import FanficCore

@Suite("Library: import, IDs, library.json")
@MainActor
struct LibraryTests {
    @Test("Every test file gives the expected result, title, author, first page and pairings")
    func importMatchesExpected() async throws {
        let (library, report, expected) = try await importedLibrary()
        for e in expected {
            let item = try #require(report.items.first { $0.fileName == e.file }, "\(e.file) missing from report")
            #expect(item.outcome.rawValue == e.outcome, "\(e.file): \(item.detail ?? "")")
            guard e.outcome == "added" || e.outcome == "addedNoPairing" else { continue }
            let work = try #require(item.workID.flatMap(library.work), "\(e.file)")
            #expect(work.kind.rawValue == e.kind, "\(e.file)")
            #expect(work.title == e.title, "\(e.file)")
            #expect(work.author == e.author, "\(e.file)")
            #expect(work.firstPageSource == e.firstPageSource, "\(e.file)")
            #expect(work.relationships == e.relationships, "\(e.file)")
            #expect(work.fandoms == e.fandoms, "\(e.file)")
            #expect(work.originalFileName == e.file)
        }
    }

    @Test("Each work and each first-page copy has its own ID; files are named by those IDs")
    func idsAndFiles() async throws {
        let (library, _, _) = try await importedLibrary()
        #expect(library.works.count == 11)
        let ids = library.works.map(\.workID) + library.works.map(\.firstPageID)
        #expect(Set(ids).count == ids.count)
        for work in library.works {
            #expect(work.storedFile == "Works/\(work.workID.uuidString).\(work.kind.rawValue)")
            #expect(work.firstPageFile == "First Pages/\(work.firstPageID.uuidString).pdf")
            let original = try Data(contentsOf: fixture(work.originalFileName))
            #expect(try Data(contentsOf: library.url(of: work.storedFile)) == original, "\(work.title)")
            let page = try #require(PDFDocument(url: library.url(of: work.firstPageFile)), "\(work.title)")
            #expect(page.pageCount == 1, "\(work.title)")
        }
        // Nothing left behind by unreadable files or the duplicate.
        #expect(files(in: library.worksFolder).count == 11)
        #expect(files(in: library.firstPagesFolder).count == 11)
    }

    @Test("library.json holds the works list, the sorted pairings list and the pairing → IDs list")
    func libraryFileLists() async throws {
        let (library, _, _) = try await importedLibrary()
        let file = try JSONDecoder.iso.decode(LibraryFile.self, from: Data(contentsOf: library.libraryFile))
        #expect(file.version == 3)
        #expect(file.works.map(\.workID) == library.works.map(\.workID))
        #expect(file.pairings.count == 16)
        #expect(file.characters.count == 25)
        #expect(file.characters == file.characters.sorted { PairingGroup.alphabetical($0, $1) })
        #expect(file.fandoms == ["Criminal Minds (US TV)", "Harry Potter - J. K. Rowling", "Miraculous Ladybug",
                                 "Percy Jackson and the Olympians - Rick Riordan", "Sherlock (TV)",
                                 "魔道祖师 - 墨香铜臭 | Mo Dao Zu Shi - Mo Xiang Tong Xiu"])
        let hpFandom = try #require(file.fandomIndex.first { $0.fandom == "Harry Potter - J. K. Rowling" })
        #expect(Set(hpFandom.works.compactMap { library.work($0.workID)?.title }) == ["The Quiet Winter", "Common Room Constellations", "Crossroads"])
        let harry = try #require(file.characterIndex.first { $0.character == "Harry Potter" })
        #expect(harry.works.count == 4)
        for ref in file.fandomIndex.flatMap(\.works) + file.characterIndex.flatMap(\.works) {
            #expect(library.work(ref.workID)?.firstPageID == ref.firstPageID)
        }
        #expect(file.pairings == file.pairings.sorted { PairingGroup.alphabetical($0, $1) })
        #expect(!file.pairings.contains("Draco Malfoy/Harry Potter"), "B/A is grouped under the more common A/B")

        let hpdm = try #require(file.pairingIndex.first { $0.pairing == "Harry Potter/Draco Malfoy" })
        let titles = Set(hpdm.works.compactMap { ref in library.works.first { $0.workID == ref.workID }?.title })
        #expect(titles == ["The Quiet Winter", "Common Room Constellations", "Starlight Over Grimmauld"])
        for entry in file.pairingIndex {
            for ref in entry.works {
                let work = try #require(library.work(ref.workID))
                #expect(work.firstPageID == ref.firstPageID)
            }
        }
        let raw = try String(contentsOf: library.libraryFile, encoding: .utf8)
        #expect(raw.contains("\"pairings\""))
        #expect(raw.contains("\"pairingIndex\""))
    }

    @Test("Library reloads unchanged after a restart")
    func reload() async throws {
        let (library, _, _) = try await importedLibrary()
        let reopened = Library(root: library.root)
        #expect(reopened.works == library.works)
        #expect(reopened.groups == library.groups)
        #expect(reopened.loadProblem == nil)
    }

    @Test("Importing the same file again is reported as already in library")
    func duplicateAgain() async throws {
        let (library, _, _) = try await importedLibrary()
        let report = await library.importFiles([fixture("Lucky Charm.pdf")])
        #expect(report.items.map(\.outcome) == [.duplicate])
        #expect(library.works.count == 11)
    }

    @Test("Folder import finds PDFs and EPUBs and skips other files")
    func folderImport() async throws {
        let library = Library(root: try temporaryLibraryFolder())
        let report = await library.importFiles([fixturesFolder])
        #expect(report.addedCount == 16)  // 11 + the 5 summary test files in the Summaries subfolder
        #expect(Set(report.items(.skipped).map(\.fileName)) == ["expected.json", "notes.txt"])
        #expect(report.items(.duplicate).map(\.fileName) == ["Zz Duplicate of The Quiet Winter.pdf"])
        #expect(report.items(.unreadable).count == 3)
    }

    @Test("Remove deletes both copies and the list entries")
    func remove() async throws {
        let (library, _, _) = try await importedLibrary()
        let work = try #require(library.works.first { $0.title == "Lucky Charm" })
        try library.remove(work.workID)
        #expect(library.work(work.workID) == nil)
        #expect(!FileManager.default.fileExists(atPath: library.url(of: work.storedFile).path))
        #expect(!FileManager.default.fileExists(atPath: library.url(of: work.firstPageFile).path))
        #expect(!library.groups.contains { $0.display.contains("Chloé") })
        #expect(Library(root: library.root).works.count == 10)
    }

    @Test("Re-read keeps IDs and restores pairings")
    func reread() async throws {
        let (library, _, _) = try await importedLibrary()
        let before = library.works
        let result = await library.rereadAll()
        #expect(result.failed.isEmpty)
        #expect(result.updated == 11)
        #expect(library.works == before)
    }

    @Test("A version 1 library is upgraded once: fandoms filled in, IDs unchanged, saved as version 3")
    func upgradeFromVersion1() async throws {
        let (library, _, _) = try await importedLibrary()
        let before = library.works
        // Turn the file into what version 1 of the app wrote: no fandoms, no character/fandom lists.
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: library.libraryFile)) as? [String: Any])
        json["version"] = 1
        for key in ["characters", "characterIndex", "fandoms", "fandomIndex"] { json.removeValue(forKey: key) }
        json["works"] = (json["works"] as? [[String: Any]])?.map { var w = $0; w.removeValue(forKey: "fandoms"); return w }
        try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]).write(to: library.libraryFile)

        let old = Library(root: library.root)
        #expect(old.needsUpgrade)
        #expect(old.works.allSatisfy { $0.fandoms.isEmpty })
        #expect(old.works.map(\.workID) == before.map(\.workID))

        await old.upgradeIfNeeded()
        #expect(!old.needsUpgrade)
        #expect(old.works == before)
        let file = try JSONDecoder.iso.decode(LibraryFile.self, from: Data(contentsOf: library.libraryFile))
        #expect(file.version == 3)
        #expect(file.fandoms.count == 6)
        #expect(!Library(root: library.root).needsUpgrade)
    }

    @Test("An unreadable library.json is kept aside, not overwritten")
    func brokenLibraryFile() throws {
        let root = try temporaryLibraryFolder()
        try Data("{ not json".utf8).write(to: root.appendingPathComponent("library.json"))
        let library = Library(root: root)
        #expect(library.works.isEmpty)
        #expect(library.loadProblem != nil)
        #expect(files(in: root).contains { $0.hasPrefix("library-unreadable-") })
    }
}

extension JSONDecoder {
    static var iso: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
