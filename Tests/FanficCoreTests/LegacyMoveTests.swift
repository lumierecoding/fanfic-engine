import Foundation
import Testing
@testable import FanficCore

/// The one-time move of the library folder from the working title "Fanfic Pairings" to "Fanfic Engine".
@Suite("Library folder move")
struct LegacyMoveTests {
    private func folders() throws -> (base: URL, old: URL, new: URL) {
        let base = try temporaryLibraryFolder()
        return (base, base.appendingPathComponent("Fanfic Pairings"), base.appendingPathComponent("Fanfic Engine"))
    }

    @Test("Moves the whole library when only the old folder exists; it opens with the same works and IDs")
    @MainActor
    func movesOldFolder() async throws {
        let (base, old, new) = try folders()
        defer { try? FileManager.default.removeItem(at: base) }
        let library = Library(root: old)
        _ = await library.importFiles([fixture("Crossroads.pdf"), fixture("Starlight Over Grimmauld.epub")])
        let before = library.works.map { [$0.workID, $0.firstPageID] }
        #expect(before.count == 2)

        #expect(Library.moveLegacyLibrary(from: old, to: new) == .moved)
        #expect(!FileManager.default.fileExists(atPath: old.path))

        let moved = Library(root: new)
        #expect(moved.loadProblem == nil)
        #expect(moved.works.map { [$0.workID, $0.firstPageID] } == before)
        for work in moved.works {
            #expect(FileManager.default.fileExists(atPath: moved.url(of: work.storedFile).path))
            #expect(FileManager.default.fileExists(atPath: moved.url(of: work.firstPageFile).path))
        }
    }

    @Test("Never moves over an existing new folder and never deletes the old one")
    func keepsExistingNewFolder() throws {
        let (base, old, new) = try folders()
        defer { try? FileManager.default.removeItem(at: base) }
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: old.appendingPathComponent("library.json"))
        try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: new.appendingPathComponent("library.json"))

        #expect(Library.moveLegacyLibrary(from: old, to: new) == .notNeeded)
        #expect(try String(contentsOf: old.appendingPathComponent("library.json"), encoding: .utf8) == "old")
        #expect(try String(contentsOf: new.appendingPathComponent("library.json"), encoding: .utf8) == "new")
    }

    @Test("Does nothing when there is no old folder")
    func nothingToMove() throws {
        let (base, old, new) = try folders()
        defer { try? FileManager.default.removeItem(at: base) }
        #expect(Library.moveLegacyLibrary(from: old, to: new) == .notNeeded)
        #expect(!FileManager.default.fileExists(atPath: new.path))
    }
}
