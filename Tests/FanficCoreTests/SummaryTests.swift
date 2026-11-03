import Foundation
import Testing
@testable import FanficCore

@Suite("Summaries (SPEC section 5a)")
struct SummaryTests {
    @Test("Every test file gives its expected summary")
    func testFiles() throws {
        for folder in [fixturesFolder, summaryFixturesFolder] {
            for e in try loadExpected(in: folder) where e.outcome == "added" || e.outcome == "addedNoPairing" {
                let prepared = try WorkReader.read(folder.appendingPathComponent(e.file))
                #expect(prepared.summary == e.summary, "\(e.file)")
                // The summary files are also read like any other file.
                #expect(prepared.relationships == e.relationships, "\(e.file)")
                #expect(prepared.fandoms == e.fandoms, "\(e.file)")
                #expect(prepared.firstPageSource == e.firstPageSource, "\(e.file)")
            }
        }
    }

    // MARK: Rule 2: AO3's blockquote

    @Test("AO3 layout: the blockquote after the label, paragraphs and line breaks kept, formatting dropped")
    func ao3Blockquote() {
        let html = """
        <h1>Title</h1><p>Summary</p>
        <blockquote class="userstuff"><p>One <i>two</i>   three.</p><p>&nbsp;</p><p>Four<br/>five &amp; <a href="x">six</a>.</p></blockquote>
        <p>Notes</p><blockquote class="userstuff"><p>Not the summary.</p></blockquote>
        """
        #expect(SummaryReader.read(html: html) == .found("One two three.\n\nFour\nfive & six."))
    }

    @Test("A blockquote inside the summary blockquote doesn't end it")
    func nestedBlockquote() {
        let html = "<p>Summary:</p>\n<div></div><blockquote><p>A</p><blockquote><p>quoted</p></blockquote><p>B</p></blockquote><p>Notes</p>"
        // "<div></div>" is not only closing tags, so this is the text rule (3): up to "Notes".
        #expect(SummaryReader.read(html: html) == .found("A\n\nquoted\n\nB"))
        let direct = "<p>Summary:</p>\n</div> <blockquote><p>A</p><blockquote><p>quoted</p></blockquote><p>B</p></blockquote><p>Notes</p><p>C</p>"
        #expect(SummaryReader.read(html: direct) == .found("A\n\nquoted\n\nB"))
    }

    // MARK: Rule 3: text up to the next label

    @Test("Without a blockquote: the text up to the next label")
    func textUpToLabel() {
        #expect(SummaryReader.read(html: "<h2>Summary</h2><p>Short.</p><p>Second.</p><h2>Notes</h2><p>x</p>") == .found("Short.\n\nSecond."))
        #expect(SummaryReader.read(html: "<p><b>Summary:</b> Inline text.</p><p><b>Language:</b> English</p>") == .found("Inline text."))
        for end in ["Chapter 1", "Chapter 12: The End", "Chapter Text", "Work Text:", "See the end of the work for more notes",
                    "Words: 1,200", "Notes:", "Relationships: A/B"] {
            #expect(SummaryReader.read(text: "Summary\nThe text.\n\(end)\nmore", joinLines: false) == .found("The text."), "\(end)")
        }
    }

    @Test("Up to the end of the document when no label follows")
    func endOfDocument() {
        #expect(SummaryReader.read(html: "<p>Summary:</p><p>Last thing in the file.</p>") == .found("Last thing in the file."))
    }

    @Test("Only a line that is the label counts: 'Summary of events' is no label")
    func notALabel() {
        #expect(SummaryReader.read(text: "Summary of events\nThe text.", joinLines: false) == .noLabel)
        #expect(SummaryReader.read(html: "<p>A summary: of sorts</p>") == .noLabel)
        #expect(SummaryReader.read(text: "SUMMARY:\nShouting.", joinLines: false) == .found("Shouting."))
    }

    @Test("PDF: lines joined into one paragraph, the next page read when the summary reaches the end of its page")
    func pdfPages() {
        let page1 = "Title\nSummary\nFirst line of the\nsummary"
        let page2 = "goes on here.\nNotes\nThanks."
        #expect(SummaryReader.read(text: page1, nextPage: page2, joinLines: true) == .found("First line of the summary goes on here."))
        // Ends on page 1: page 2 is not read.
        #expect(SummaryReader.read(text: "Summary\nDone.\nNotes", nextPage: "Other", joinLines: true) == .found("Done."))
    }

    // MARK: Rules 5 and 6

    @Test("Longer than 1,500 characters is not a summary; 1,500 is")
    func lengthLimit() {
        let ok = String(repeating: "a", count: 1_500)
        #expect(SummaryReader.read(text: "Summary\n\(ok)", joinLines: false) == .found(ok))
        #expect(SummaryReader.read(text: "Summary\n\(ok)a", joinLines: false) == .none)
    }

    @Test("A label with nothing after it gives no summary and stops the search")
    func emptySummary() {
        #expect(SummaryReader.read(text: "Summary\nNotes\nx", joinLines: false) == .none)
        #expect(SummaryReader.read(html: "<p>Summary</p><blockquote> <p>&nbsp;</p> </blockquote>") == .none)
    }

    // MARK: Library

    @Test("Summaries are stored, reloaded, and left out of library.json when there is none")
    @MainActor
    func stored() async throws {
        let library = Library(root: try temporaryLibraryFolder())
        let expected = try loadExpected(in: summaryFixturesFolder)
        _ = await library.importFiles(expected.map { summaryFixturesFolder.appendingPathComponent($0.file) })
        let reloaded = Library(root: library.root)
        for e in expected {
            let work = try #require(reloaded.works.first { $0.title == e.title }, "\(e.file)")
            #expect(work.summary == e.summary, "\(e.file)")
        }
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: library.libraryFile)) as? [String: Any])
        let entries = try #require(json["works"] as? [[String: Any]])
        #expect(entries.filter { $0["summary"] != nil }.count == 4)
        #expect(entries.first { $0["title"] as? String == "Long Road Home" }?.keys.contains("summary") == false)
    }

    @Test("A version 2 library is read again once: summaries added, everything else unchanged, backup kept")
    @MainActor
    func upgradeFromVersion2() async throws {
        let library = Library(root: try temporaryLibraryFolder())
        let files = try loadExpected().map { fixture($0.file) }
            + loadExpected(in: summaryFixturesFolder).map { summaryFixturesFolder.appendingPathComponent($0.file) }
        _ = await library.importFiles(files)
        let before = library.works
        #expect(before.contains { $0.summary != nil })

        // Turn the file into what version 2 wrote: no summaries.
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: library.libraryFile)) as? [String: Any])
        json["version"] = 2
        json["works"] = (json["works"] as? [[String: Any]])?.map { var w = $0; w.removeValue(forKey: "summary"); return w }
        let version2 = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try version2.write(to: library.libraryFile)

        let old = Library(root: library.root)
        #expect(old.needsUpgrade)
        #expect(old.works.allSatisfy { $0.summary == nil })
        await old.upgradeIfNeeded()
        #expect(!old.needsUpgrade)
        #expect(old.works == before)  // IDs, pairings, fandoms, files the same; summaries back

        let backup = library.root.appendingPathComponent("library-v2-backup.json")
        #expect(try Data(contentsOf: backup) == version2)
        let file = try JSONDecoder.iso.decode(LibraryFile.self, from: Data(contentsOf: library.libraryFile))
        #expect(file.version == 3)
        #expect(!Library(root: library.root).needsUpgrade)
    }

    @Test("An existing backup is never overwritten")
    @MainActor
    func backupKept() async throws {
        let (library, _, _) = try await importedLibrary()
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: library.libraryFile)) as? [String: Any])
        json["version"] = 2
        try JSONSerialization.data(withJSONObject: json).write(to: library.libraryFile)
        let backup = library.root.appendingPathComponent("library-v2-backup.json")
        try Data("earlier backup".utf8).write(to: backup)

        let old = Library(root: library.root)
        await old.upgradeIfNeeded()
        #expect(!old.needsUpgrade)
        #expect(try Data(contentsOf: backup) == Data("earlier backup".utf8))
    }
}
