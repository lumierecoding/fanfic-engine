import Foundation
import Testing
@testable import FanficCore

/// The Additional Tags field, the tag list, library.json version 4 and "#" searches (SPEC section 5b).
@Suite("Tags (SPEC section 5b)")
struct TagTests {
    @Test("The field: both labels, line breaks inside a tag, end at the next label, repeats dropped, / and & kept")
    func reading() {
        let page = """
        Fandom:
        Harry Potter - J. K. Rowling
        Additional Tags:
        Fluff, Hurt / Comfort, Slow
        Burn, Fluff & Angst, fluff, Fluff
        Language:
        English
        """
        #expect(TagParser.tags(in: page) == ["Fluff", "Hurt/Comfort", "Slow Burn", "Fluff & Angst", "fluff"])
        #expect(TagParser.tags(in: "Freeform: Case Fic, Slow Burn\nStats: Words: 1,000") == ["Case Fic", "Slow Burn"])
        #expect(TagParser.tags(in: "additional tags : Snow") == ["Snow"])
        #expect(TagParser.tags(in: "Relationship: A/B\nCharacters: A, B") == nil)
        #expect(TagParser.tags(in: "Additional Tags:\nLanguage: English") == [])
        // The Relationship field still ends at the Additional Tags label.
        #expect(RelationshipParser.relationships(in: "Relationship: A/B\nAdditional Tags: Fluff") == ["A/B"])
    }

    @Test("A field that reaches the end of the page goes on with the next page; free text that ran in stops it")
    func continuationAndFreeText() {
        let next = "Lovers, Snow\nLanguage: English"
        #expect(TagParser.tags(in: "Additional Tags: Fluff, Enemies to", nextPage: next) == ["Fluff", "Enemies to Lovers", "Snow"])
        let long = String(repeating: "word ", count: 40)
        #expect(TagParser.tags(in: "Additional Tags: Fluff, Snow\n\(long)") == ["Fluff", "Snow"])
    }

    @Test("Tags come from the first page; if it has none, from the other checked pages")
    func otherCheckedPages() {
        let texts = ["Relationship: A/B", "Additional Tags: Found Family", "Additional Tags: Not Used"]
        #expect(WorkReader.additionalTags(in: texts, preferring: 0, checked: 3) == ["Found Family"])
        #expect(WorkReader.additionalTags(in: texts, preferring: 2, checked: 3) == ["Not Used"])
        #expect(WorkReader.additionalTags(in: ["Relationship: A/B"], preferring: 0, checked: 1) == [])
    }

    @Test("Tags are not characters: Hurt/Comfort is one tag, never a pairing")
    @MainActor
    func notCharacters() async throws {
        let (library, _, _) = try await importedLibrary()
        let characters = library.characterList().map(\.display)
        #expect(!characters.contains("Hurt") && !characters.contains("Comfort"))
        #expect(library.pairingList().allSatisfy { !$0.display.contains("Comfort") })
        #expect(library.tagList().contains { $0.display == "Hurt/Comfort" })
    }

    @Test("The tag list: every tag once with its works; spellings that differ only in case count as one")
    @MainActor
    func tagList() async throws {
        let (library, _, _) = try await importedLibrary()
        let list = library.tagList()
        #expect(list.map(\.display) == ["Canon Divergence", "Case Fic", "Crossover", "Demigods", "Eighth Year",
                                        "Enemies to Lovers", "Fluff", "Found Family", "Friendship", "Hurt/Comfort",
                                        "Mutual Pining", "Polyamory", "Slow Burn", "Snow"])
        #expect(list.allSatisfy { $0.workIDs.count == 1 })
        let works = [record(["Slow Burn", "Fluff"]), record(["slow  burn"]), record(["Slow Burn"])]
        let groups = NameGroup.tags(in: works)
        #expect(groups.map(\.display) == ["Fluff", "Slow Burn"])
        #expect(groups.first { $0.display == "Slow Burn" }?.workIDs.count == 3)
        #expect(groups.sorted(by: .count).first?.display == "Slow Burn")
    }

    @Test("library.json version 4: tags per work and the tags and tagIndex lists; they survive a reload")
    @MainActor
    func libraryFile() async throws {
        let (library, _, _) = try await importedLibrary()
        let file = try JSONDecoder.iso.decode(LibraryFile.self, from: Data(contentsOf: library.libraryFile))
        #expect(file.version == 4)
        #expect(file.tags == library.tagList().map(\.display))
        let fluff = try #require(file.tagIndex.first { $0.tag == "Fluff" })
        #expect(fluff.works.compactMap { library.work($0.workID)?.title } == ["The Quiet Winter"])
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: library.libraryFile)) as? [String: Any])
        let entries = try #require(json["works"] as? [[String: Any]])
        #expect(entries.allSatisfy { $0["tags"] is [String] })  // [] when a work has none
        let reloaded = Library(root: library.root)
        #expect(reloaded.works == library.works)
        #expect(!reloaded.needsUpgrade)
    }

    @Test("A version 3 library is read again once: tags added, everything else unchanged, backup kept")
    @MainActor
    func upgradeFromVersion3() async throws {
        let (library, _, _) = try await importedLibrary()
        let before = library.works
        // Turn the file into what version 3 wrote: no tags anywhere.
        var json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: library.libraryFile)) as? [String: Any])
        json["version"] = 3
        json["works"] = (json["works"] as? [[String: Any]])?.map { var w = $0; w.removeValue(forKey: "tags"); return w }
        json.removeValue(forKey: "tags")
        json.removeValue(forKey: "tagIndex")
        let version3 = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try version3.write(to: library.libraryFile)

        let old = Library(root: library.root)
        #expect(old.needsUpgrade)
        #expect(old.works.allSatisfy { $0.tags.isEmpty })
        await old.upgradeIfNeeded()
        #expect(!old.needsUpgrade)
        #expect(old.works == before)  // IDs, pairings, fandoms, summaries, files the same; tags back
        #expect(try Data(contentsOf: library.root.appendingPathComponent("library-v3-backup.json")) == version3)
        let file = try JSONDecoder.iso.decode(LibraryFile.self, from: Data(contentsOf: library.libraryFile))
        #expect(file.version == 4)
        #expect(!Library(root: library.root).needsUpgrade)
    }

    @Test("# searches tags with the word-start rule and highlights the matching tags; relationships are not searched")
    @MainActor
    func search() async throws {
        let (library, _, _) = try await importedLibrary()
        func titles(_ q: String) -> [String] { Search.run(q, in: library.works).map(\.work.title) }
        #expect(PairingQuery("#Slow Burn").mode == .tag("Slow Burn"))
        #expect(PairingQuery("  #  ").mode == .everything)
        #expect(PairingQuery("#hurt/comfort").mode == .tag("hurt/comfort"))
        #expect(titles("#burn") == ["Profiler's Notes"])
        #expect(titles("#slo") == ["Profiler's Notes"])
        #expect(titles("#low").isEmpty)
        #expect(titles("#hurt comfort") == ["The Quiet Winter"])
        #expect(titles("#HURT/COMFORT") == ["The Quiet Winter"])
        #expect(titles("#enemies to lovers") == ["Common Room Constellations"])
        #expect(titles("#Harry").isEmpty)  // a name in a relationship is not a tag
        #expect(titles("#").count == library.works.count)
        let hit = try #require(Search.run("#f", in: library.works).first { $0.work.title == "Field Notes" })
        #expect(hit.matchedTags == ["Friendship", "Found Family"])
        #expect(hit.matched.isEmpty)
        // A pairing search is unchanged and matches no tags.
        let pairing = try #require(Search.run("Harry/Draco", in: library.works).first)
        #expect(pairing.matchedTags.isEmpty && !pairing.matched.isEmpty)
    }

    @Test("The Search tags field narrows the list by the word-start rule and keeps its order")
    @MainActor
    func listFilter() async throws {
        let (library, _, _) = try await importedLibrary()
        let list = library.tagList()
        #expect(list.matching("").count == list.count)
        #expect(list.matching("  ").count == list.count)
        #expect(list.matching("burn").map(\.display) == ["Slow Burn"])
        #expect(list.matching("slow b").map(\.display) == ["Slow Burn"])
        #expect(list.matching("low").isEmpty)
        #expect(list.matching("fam").map(\.display) == ["Found Family"])
        #expect(list.matching("f").map(\.display) == ["Case Fic", "Fluff", "Found Family", "Friendship"])
        #expect(list.matching("hurt comfort").map(\.display) == ["Hurt/Comfort"])
        #expect(library.tagList(sort: .count).matching("f").count == 4)
        #expect(list.matching("zzz").isEmpty)
    }

    private func record(_ tags: [String]) -> WorkRecord {
        WorkRecord(workID: UUID(), firstPageID: UUID(), kind: .pdf, originalFileName: "x.pdf", storedFile: "Works/x.pdf",
                   firstPageFile: "First Pages/x.pdf", firstPageSource: "page 1", title: "x", author: nil, sha256: UUID().uuidString,
                   importedAt: Date(), relationships: [], tags: tags)
    }
}
