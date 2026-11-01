import Foundation
import Testing
@testable import FanficCore

@Suite("Search")
struct SearchTests {
    @Test("Name matching: case, accents, spaces, punctuation, word starts")
    func names() {
        let yes: [(String, String)] = [
            ("Draco Malfoy", "Draco Malfoy"), ("draco malfoy", "Draco Malfoy"), ("DracoMalfoy", "Draco Malfoy"),
            ("draco   malfoy", "Draco Malfoy"), ("Draco", "Draco Malfoy"), ("dra", "Draco Malfoy"), ("Malfoy", "Draco Malfoy"),
            ("chloe", "Chloé Bourgeois"), ("dupain cheng", "Marinette Dupain-Cheng"), ("dupaincheng", "Marinette Dupain-Cheng"),
            ("wei wuxian", "Wei Ying | Wei Wuxian"), ("lanwangji", "Lan Zhan | Lan Wangji"),
        ]
        for (query, member) in yes {
            #expect(NameMatcher.matches(query: query, member: member), "\(query) should match \(member)")
        }
        let no: [(String, String)] = [
            ("Ron", "Aaron Hotchner"), ("ron", "Veronica Mars"), ("aco", "Draco Malfoy"), ("alfoy", "Draco Malfoy"),
            ("", "Draco Malfoy"), ("Draco Malfoyy", "Draco Malfoy"),
        ]
        for (query, member) in no {
            #expect(!NameMatcher.matches(query: query, member: member), "\(query) should not match \(member)")
        }
    }

    @Test("Query forms")
    func queryForms() {
        #expect(PairingQuery("Harry/Draco").mode == .pairing(["Harry", "Draco"]))
        #expect(PairingQuery("  Harry  /  Draco ").mode == .pairing(["Harry", "Draco"]))
        #expect(PairingQuery("Harry & Ron").mode == .friendship(["Harry", "Ron"]))
        #expect(PairingQuery("Harry").mode == .name("Harry"))
        #expect(PairingQuery("   ").mode == .everything)
        #expect(PairingQuery("/").mode == .everything)
    }

    @Test("Search table on the imported test files (SPEC section 6)")
    @MainActor
    func searchTable() async throws {
        let (library, _, _) = try await importedLibrary()
        let hpdm = ["Common Room Constellations", "Starlight Over Grimmauld", "The Quiet Winter"]
        let withCrossover = ["Common Room Constellations", "Crossroads", "Starlight Over Grimmauld", "The Quiet Winter"]
        let table: [(String, [String])] = [
            ("Harry Potter/Draco Malfoy", hpdm),
            ("Draco Malfoy/Harry Potter", hpdm),
            ("draco malfoy / harry potter", hpdm),
            ("Harry Potter / Draco Malfoy", hpdm),
            ("HarryPotter/DracoMalfoy", hpdm),
            ("harry/draco", hpdm),
            ("Draco", withCrossover),
            ("Harry", withCrossover),
            ("Percy Jackson/Draco", ["Crossroads"]),
            ("Nico & Harry", ["Crossroads"]),
            ("Harry/Nico", []),
            ("Ron", ["Common Room Constellations"]),
            ("Aaron", ["Profiler's Notes"]),
            ("Hotch/Reid", ["Profiler's Notes"]),
            ("Spencer Reid & Derek Morgan", ["Profiler's Notes"]),
            ("Spencer Reid/Derek Morgan", []),
            ("Pansy/Hermione", ["Common Room Constellations"]),
            ("Ginny/Pansy/Hermione", ["Common Room Constellations"]),
            ("Harry/Ron", []),
            ("Harry & Ron", ["Common Room Constellations"]),
            ("chloe/marinette", ["Lucky Charm"]),
            ("Dupain Cheng", ["Lucky Charm"]),
            ("Wei Wuxian/Lan Wangji", ["Untamed Hearts"]),
            ("wangji / wuxian", ["Untamed Hearts"]),
            ("Lan Zhan/Wei Ying", ["Untamed Hearts"]),
            ("Jiang Cheng", ["Untamed Hearts"]),
            ("Sirius/Remus", ["Starlight Over Grimmauld", "Winter Anthology"]),
            ("Mycroft/Lestrade", ["Baker Street Ledger"]),
            ("Watson/", ["Baker Street Ledger"]),
            ("aco", []),
            ("Gandalf", []),
        ]
        for (query, titles) in table {
            #expect(Search.run(query, in: library.works).map(\.work.title) == titles, "query: \(query)")
        }
        #expect(Search.run("", in: library.works).count == 11)
    }

    @Test("Matched relationships are reported for highlighting")
    @MainActor
    func matchedTags() async throws {
        let (library, _, _) = try await importedLibrary()
        let hit = try #require(Search.run("harry/draco", in: library.works).first { $0.work.title == "Common Room Constellations" })
        #expect(hit.matched == ["Harry Potter/Draco Malfoy"])
        let nameHit = try #require(Search.run("Ron", in: library.works).first)
        #expect(nameHit.matched == ["Ron Weasley/Lavender Brown", "Harry Potter & Ron Weasley & Hermione Granger"])
    }

    @Test("Characters: people in relationship tags, once each; friendship switch")
    @MainActor
    func characters() async throws {
        let (library, _, _) = try await importedLibrary()
        let all = NameGroup.characters(in: library.works)
        #expect(all.count == 25)
        #expect(all.first { $0.display == "Harry Potter" }?.workIDs.count == 4)
        #expect(all.contains { $0.display == "Derek Morgan" })
        let pairingsOnly = NameGroup.characters(in: library.works, includeFriendships: false)
        #expect(pairingsOnly.count == 23)
        #expect(!pairingsOnly.contains { $0.display == "Derek Morgan" })
        #expect(pairingsOnly.first { $0.display == "Harry Potter" }?.workIDs.count == 3)
    }

    @Test("Characters: spelling variants merge, alternate names stay separate")
    func characterSpellings() {
        func work(_ tags: [String]) -> WorkRecord {
            let id = UUID()
            return WorkRecord(workID: id, firstPageID: UUID(), kind: .pdf, originalFileName: "x.pdf", storedFile: "", firstPageFile: "",
                              firstPageSource: "page 1", title: "x", author: nil, sha256: id.uuidString, importedAt: Date(), relationships: tags)
        }
        let works = [work(["Harry Potter/Tom Riddle", "Harry Potter/Tom Riddle | Voldemort"]), work(["harry potter/Tom  Riddle"])]
        let names = NameGroup.characters(in: works)
        #expect(names.map(\.display) == ["Harry Potter", "Tom Riddle", "Tom Riddle | Voldemort"])
        #expect(names.first { $0.display == "Harry Potter" }?.workIDs.count == 2)
        #expect(names.first { $0.display == "Tom Riddle" }?.workIDs.count == 2)
    }

    @Test("Fandoms: once each, crossovers count in every fandom; sorting by count")
    @MainActor
    func fandoms() async throws {
        let (library, _, _) = try await importedLibrary()
        let fandoms = NameGroup.fandoms(in: library.works)
        #expect(fandoms.count == 6)
        let hp = try #require(fandoms.first { $0.display == "Harry Potter - J. K. Rowling" })
        let titles = Set(hp.workIDs.compactMap { library.work($0)?.title })
        #expect(titles == ["The Quiet Winter", "Common Room Constellations", "Crossroads"])
        #expect(fandoms.first { $0.display.hasPrefix("Percy Jackson") }?.workIDs.count == 1)
        let byCount = fandoms.sorted(by: .count).map(\.display)
        #expect(byCount.prefix(2) == ["Harry Potter - J. K. Rowling", "Criminal Minds (US TV)"])
        #expect(byCount[2] == "Miraculous Ladybug", "ties A–Z")
    }

    @Test("Pairing list: A/B and B/A are one entry with the more common spelling and all works")
    @MainActor
    func grouping() async throws {
        let (library, _, _) = try await importedLibrary()
        let group = try #require(library.groups.first { $0.display == "Harry Potter/Draco Malfoy" })
        #expect(group.workIDs.count == 3)
        #expect(library.groups.count == 16)
        #expect(PairingGroup.groups(for: library.works, includeFriendships: false).count == 12)
        #expect(!library.groups.contains { $0.display == "Draco Malfoy/Harry Potter" })
        let remus = try #require(library.groups.first { $0.display == "Remus Lupin/Sirius Black" })
        #expect(remus.workIDs.count == 2)
    }
}
