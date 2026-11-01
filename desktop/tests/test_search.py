"""Search and lists — the same cases as Tests/FanficCoreTests/SearchTests.swift."""

from __future__ import annotations

from fanficengine.core import search, text as T
from fanficengine.core.models import WorkRecord, character_groups, fandom_groups, pairing_groups, sorted_groups


def test_name_matching():
    yes = [("Draco Malfoy", "Draco Malfoy"), ("draco malfoy", "Draco Malfoy"), ("DracoMalfoy", "Draco Malfoy"),
           ("draco   malfoy", "Draco Malfoy"), ("Draco", "Draco Malfoy"), ("dra", "Draco Malfoy"), ("Malfoy", "Draco Malfoy"),
           ("chloe", "Chloé Bourgeois"), ("dupain cheng", "Marinette Dupain-Cheng"), ("dupaincheng", "Marinette Dupain-Cheng"),
           ("wei wuxian", "Wei Ying | Wei Wuxian"), ("lanwangji", "Lan Zhan | Lan Wangji")]
    for query, member in yes:
        assert T.matches(query, member), (query, member)
    no = [("Ron", "Aaron Hotchner"), ("ron", "Veronica Mars"), ("aco", "Draco Malfoy"), ("alfoy", "Draco Malfoy"),
          ("", "Draco Malfoy"), ("Draco Malfoyy", "Draco Malfoy")]
    for query, member in no:
        assert not T.matches(query, member), (query, member)


def test_query_forms():
    assert (search.PairingQuery("Harry/Draco").mode, search.PairingQuery("Harry/Draco").names) == ("pairing", ["Harry", "Draco"])
    assert search.PairingQuery("  Harry  /  Draco ").names == ["Harry", "Draco"]
    assert search.PairingQuery("Harry & Ron").mode == "friendship"
    assert search.PairingQuery("Harry").mode == "name"
    assert search.PairingQuery("   ").mode == "everything"
    assert search.PairingQuery("/").mode == "everything"


def test_search_table(imported):
    library, _ = imported
    hpdm = ["Common Room Constellations", "Starlight Over Grimmauld", "The Quiet Winter"]
    with_crossover = ["Common Room Constellations", "Crossroads", "Starlight Over Grimmauld", "The Quiet Winter"]
    table = [
        ("Harry Potter/Draco Malfoy", hpdm), ("Draco Malfoy/Harry Potter", hpdm), ("draco malfoy / harry potter", hpdm),
        ("Harry Potter / Draco Malfoy", hpdm), ("HarryPotter/DracoMalfoy", hpdm), ("harry/draco", hpdm),
        ("Draco", with_crossover), ("Harry", with_crossover), ("Percy Jackson/Draco", ["Crossroads"]),
        ("Nico & Harry", ["Crossroads"]), ("Harry/Nico", []), ("Ron", ["Common Room Constellations"]),
        ("Aaron", ["Profiler's Notes"]), ("Hotch/Reid", ["Profiler's Notes"]), ("Spencer Reid & Derek Morgan", ["Profiler's Notes"]),
        ("Spencer Reid/Derek Morgan", []), ("Pansy/Hermione", ["Common Room Constellations"]),
        ("Ginny/Pansy/Hermione", ["Common Room Constellations"]), ("Harry/Ron", []), ("Harry & Ron", ["Common Room Constellations"]),
        ("chloe/marinette", ["Lucky Charm"]), ("Dupain Cheng", ["Lucky Charm"]), ("Wei Wuxian/Lan Wangji", ["Untamed Hearts"]),
        ("wangji / wuxian", ["Untamed Hearts"]), ("Lan Zhan/Wei Ying", ["Untamed Hearts"]), ("Jiang Cheng", ["Untamed Hearts"]),
        ("Sirius/Remus", ["Starlight Over Grimmauld", "Winter Anthology"]), ("Mycroft/Lestrade", ["Baker Street Ledger"]),
        ("Watson/", ["Baker Street Ledger"]), ("aco", []), ("Gandalf", []),
    ]
    for query, titles in table:
        assert [h.work.title for h in search.run(query, library.works)] == titles, query
    assert len(search.run("", library.works)) == 11


def test_matched_tags(imported):
    library, _ = imported
    hit = next(h for h in search.run("harry/draco", library.works) if h.work.title == "Common Room Constellations")
    assert hit.matched == {"Harry Potter/Draco Malfoy"}
    assert search.run("Ron", library.works)[0].matched == {"Ron Weasley/Lavender Brown", "Harry Potter & Ron Weasley & Hermione Granger"}


def test_characters(imported):
    library, _ = imported
    everyone = character_groups(library.works)
    assert len(everyone) == 25
    assert len(next(g for g in everyone if g.display == "Harry Potter").work_ids) == 4
    pairings_only = character_groups(library.works, include_friendships=False)
    assert len(pairings_only) == 23
    assert not any(g.display == "Derek Morgan" for g in pairings_only)
    assert len(next(g for g in pairings_only if g.display == "Harry Potter").work_ids) == 3


def test_character_spellings():
    def work(i, tags):
        return WorkRecord(f"ID{i}", f"P{i}", "pdf", "x.pdf", "", "", "page 1", "x", None, f"sha{i}", "2026-11-01T00:00:00Z", tags)
    works = [work(1, ["Harry Potter/Tom Riddle", "Harry Potter/Tom Riddle | Voldemort"]), work(2, ["harry potter/Tom  Riddle"])]
    names = character_groups(works)
    assert [g.display for g in names] == ["Harry Potter", "Tom Riddle", "Tom Riddle | Voldemort"]
    assert len(next(g for g in names if g.display == "Harry Potter").work_ids) == 2
    assert len(next(g for g in names if g.display == "Tom Riddle").work_ids) == 2


def test_fandoms_and_sorting(imported):
    library, _ = imported
    fandoms = fandom_groups(library.works)
    assert len(fandoms) == 6
    hp = next(g for g in fandoms if g.display == "Harry Potter - J. K. Rowling")
    assert {library.work(i).title for i in hp.work_ids} == {"The Quiet Winter", "Common Room Constellations", "Crossroads"}
    by_count = [g.display for g in sorted_groups(fandoms, "count")]
    assert by_count[:2] == ["Harry Potter - J. K. Rowling", "Criminal Minds (US TV)"]
    assert by_count[2] == "Miraculous Ladybug"


def test_pairing_groups(imported):
    library, _ = imported
    groups = pairing_groups(library.works)
    assert len(next(g for g in groups if g.display == "Harry Potter/Draco Malfoy").work_ids) == 3
    assert len(groups) == 16
    assert len(pairing_groups(library.works, include_friendships=False)) == 12
    assert not any(g.display == "Draco Malfoy/Harry Potter" for g in groups)
    assert len(next(g for g in groups if g.display == "Remus Lupin/Sirius Black").work_ids) == 2
