import Foundation
import Testing
@testable import FanficCore

/// The Filter page's rules (SPEC section 6, Filter): all of up to 5 tags, and leaving out pairings, fandoms,
/// characters and tags.
@Suite("Filter (SPEC section 6)")
struct FilterTests {
    @Test("Every chosen tag must be present; spellings that differ only in case or spacing count as one")
    func allTags() {
        let a = record("A", tags: ["Fluff", "Slow Burn"])
        let b = record("B", tags: ["Fluff"])
        let c = record("C", tags: ["slow  burn", "FLUFF", "Angst"])
        let d = record("D", tags: [])
        var filter = WorkFilter()
        #expect(filter.isEmpty)
        #expect(filter.apply(to: [a, b, c, d]).map(\.title) == ["A", "B", "C", "D"])
        let ok1 = filter.addTag(.init(.tag, name: "Fluff"))
        #expect(ok1)
        #expect(filter.apply(to: [a, b, c, d]).map(\.title) == ["A", "B", "C"])
        let ok2 = filter.addTag(.init(.tag, name: "Slow Burn"))
        #expect(ok2)
        #expect(filter.apply(to: [a, b, c, d]).map(\.title) == ["A", "C"])
        #expect(filter.chosenTags(in: c) == ["slow  burn", "FLUFF"])  // the work's own spellings, page order
        #expect(filter.chosenTags(in: d).isEmpty)
    }

    @Test("At most 5 tags; a tag that is chosen already is refused")
    func limit() {
        var filter = WorkFilter()
        for name in ["One", "Two", "Three", "Four", "Five"] { let ok = filter.addTag(.init(.tag, name: name)); #expect(ok) }
        #expect(!filter.canAddTag)
        let ok3 = filter.addTag(.init(.tag, name: "Six"))
        #expect(!ok3)
        #expect(filter.tags.map(\.display) == ["One", "Two", "Three", "Four", "Five"])
        filter.removeTag(key: NameMatcher.key("three"))
        #expect(filter.canAddTag)
        let ok4 = filter.addTag(.init(.tag, name: "ONE"))
        #expect(!ok4)
        let ok5 = filter.addTag(.init(.tag, name: "Six"))
        #expect(ok5)
        #expect(filter.tags.map(\.display) == ["One", "Two", "Four", "Five", "Six"])
        let ok6 = filter.addTag(.init(.tag, name: "  "))
        #expect(!ok6)
    }

    @Test("A tag is on one side only: choosing it on one takes it off the other")
    func oneSide() {
        var filter = WorkFilter()
        let fluff = WorkFilter.Entry(.tag, name: "Fluff")
        filter.addTag(fluff)
        let ok7 = filter.leaveOut(.tag, fluff)
        #expect(ok7)
        #expect(filter.tags.isEmpty && filter.leftOut(.tag) == [fluff])
        let ok8 = filter.leaveOut(.tag, fluff)
        #expect(!ok8)
        let ok9 = filter.addTag(fluff)
        #expect(ok9)
        #expect(filter.tags == [fluff] && filter.leftOut(.tag).isEmpty)
        filter.clear()
        #expect(filter.isEmpty)
    }

    @Test("Leaving out a sidebar entry hides exactly the fanfics counted beside it; a tag shows exactly its fanfics")
    @MainActor
    func sidebarCounts() async throws {
        let (library, _, _) = try await importedLibrary()
        let all = Set(library.works.map(\.workID))
        func check<G: SidebarGroup & Identifiable>(_ groups: [G], _ kind: WorkFilter.Kind, friendships: Bool = true)
            where G.ID == String {
            #expect(!groups.isEmpty)
            for group in groups {
                var filter = WorkFilter()
                filter.leaveOut(kind, .init(key: group.id, display: group.display))
                let shown = Set(filter.apply(to: library.works, includeFriendships: friendships).map(\.workID))
                #expect(shown == all.subtracting(group.workIDs), "\(kind) \(group.display)")
            }
        }
        check(library.pairingList(), .pairing)
        check(library.fandomList(), .fandom)
        check(library.characterList(), .character)
        check(library.characterList(includeFriendships: false), .character, friendships: false)
        check(library.tagList(), .tag)
        for group in library.tagList() {
            var filter = WorkFilter()
            filter.addTag(.init(key: group.key, display: group.display))
            #expect(Set(filter.apply(to: library.works).map(\.workID)) == Set(group.workIDs))
        }
    }

    @Test("A/B and B/A are one pairing; a crossover is hidden when one of its fandoms is left out")
    @MainActor
    func pairingsAndCrossovers() async throws {
        let (library, _, _) = try await importedLibrary()
        #expect(WorkFilter.Entry(.pairing, name: "Draco Malfoy / Harry Potter").key
                == WorkFilter.Entry(.pairing, name: "Harry Potter/Draco Malfoy").key)
        var filter = WorkFilter()
        filter.leaveOut(.pairing, .init(.pairing, name: "Draco Malfoy/Harry Potter"))
        let hidden = Set(library.works.map(\.title)).subtracting(filter.apply(to: library.works).map(\.title))
        #expect(hidden == ["The Quiet Winter", "Common Room Constellations", "Starlight Over Grimmauld"])
        filter.clear()
        filter.leaveOut(.fandom, .init(.fandom, name: "Percy Jackson and the Olympians - Rick Riordan"))
        let shown = filter.apply(to: library.works).map(\.title)  // Crossroads: Harry Potter × Percy Jackson
        #expect(!shown.contains("Crossroads") && shown.contains("The Quiet Winter") && shown.count == library.works.count - 1)
    }

    @Test("Characters: friendship tags count unless Settings leaves them out")
    func friendshipSetting() {
        let friends = record("Friends", relationships: ["Derek Morgan & Spencer Reid"])
        let pair = record("Pair", relationships: ["Aaron Hotchner/Spencer Reid"])
        var filter = WorkFilter()
        filter.leaveOut(.character, .init(.character, name: "Derek Morgan"))
        #expect(filter.apply(to: [friends, pair]).map(\.title) == ["Pair"])
        #expect(filter.apply(to: [friends, pair], includeFriendships: false).map(\.title) == ["Friends", "Pair"])
        filter.leaveOut(.character, .init(.character, name: "spencer  reid"))
        #expect(filter.apply(to: [friends, pair], includeFriendships: false).map(\.title) == ["Friends"])
    }

    @Test("Tags and left-out entries together")
    func together() {
        let a = record("A", tags: ["Fluff"], fandoms: ["Sherlock (TV)"])
        let b = record("B", tags: ["Fluff", "Angst"], fandoms: ["Good Omens (TV)"])
        let c = record("C", tags: ["Fluff"], fandoms: ["Good Omens (TV)"], relationships: ["Aziraphale/Crowley (Good Omens)"])
        var filter = WorkFilter()
        filter.addTag(.init(.tag, name: "Fluff"))
        filter.leaveOut(.fandom, .init(.fandom, name: "Sherlock (TV)"))
        filter.leaveOut(.tag, .init(.tag, name: "angst"))
        #expect(filter.apply(to: [a, b, c]).map(\.title) == ["C"])
        filter.leaveOut(.pairing, .init(.pairing, name: "Crowley (Good Omens)/Aziraphale"))
        #expect(filter.apply(to: [a, b, c]).isEmpty)
    }

    @Test("Suggestions: word-start rule, most fanfics first, chosen ones left out, at most 6, none while empty")
    func suggestions() {
        let works = [
            record("1", tags: ["Found Family", "Fluff"], relationships: ["Harry Potter/Draco Malfoy"]),
            record("2", tags: ["Fluff", "Family Drama"], relationships: ["Draco Malfoy/Harry Potter", "Draco Malfoy/Theo Nott"]),
            record("3", tags: ["Fluff", "Found Family", "Slow Burn"], relationships: ["Harry Potter & Ron Weasley"]),
        ]
        let tags = NameGroup.tags(in: works)
        func names(_ typed: String, _ chosen: Set<String> = [], limit: Int = 6) -> [String] {
            WorkFilter.suggestions(typed, in: tags, kind: .tag, excluding: chosen, limit: limit).map(\.display)
        }
        #expect(names("f") == ["Fluff", "Found Family", "Family Drama"])
        #expect(names("fam") == ["Found Family", "Family Drama"])
        #expect(names("burn") == ["Slow Burn"])
        #expect(names("low").isEmpty)
        #expect(names(" ").isEmpty)
        #expect(names("f", [NameMatcher.key("Fluff")]) == ["Found Family", "Family Drama"])
        #expect(names("f", limit: 2) == ["Fluff", "Found Family"])

        let pairings = PairingGroup.groups(for: works)
        func pairs(_ typed: String) -> [String] {
            WorkFilter.suggestions(typed, in: pairings, kind: .pairing, excluding: []).map(\.display)
        }
        #expect(pairs("harry/draco") == ["Draco Malfoy/Harry Potter"])  // one group for both spellings, 2 fanfics
        #expect(pairs("draco") == ["Draco Malfoy/Harry Potter", "Draco Malfoy/Theo Nott"])
        #expect(pairs("harry & ron") == ["Harry Potter & Ron Weasley"])
        #expect(pairs("ron/harry").isEmpty)
    }

    private func record(_ title: String, tags: [String] = [], fandoms: [String] = [], relationships: [String] = []) -> WorkRecord {
        WorkRecord(workID: UUID(), firstPageID: UUID(), kind: .pdf, originalFileName: "\(title).pdf", storedFile: "Works/x.pdf",
                   firstPageFile: "First Pages/x.pdf", firstPageSource: "page 1", title: title, author: nil,
                   sha256: UUID().uuidString, importedAt: Date(), relationships: relationships, fandoms: fandoms, tags: tags)
    }
}
