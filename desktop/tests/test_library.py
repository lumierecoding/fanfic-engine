"""Library: import, IDs, library.json — the same cases as Tests/FanficCoreTests/LibraryTests.swift."""

from __future__ import annotations

import hashlib
import json

import pypdfium2 as pdfium

from conftest import FIXTURES, fixture
from fanficengine.core.library import Library
from fanficengine.core.text import alphabetical_key


def files(folder):
    return sorted(p.name for p in folder.iterdir() if not p.name.startswith("."))


def test_every_test_file_gives_the_expected_result(imported, expected):
    library, report = imported
    for e in expected:
        item = next((i for i in report.items if i.file_name == e["file"]), None)
        assert item is not None, e["file"]
        assert item.outcome == e["outcome"], (e["file"], item.detail)
        if e["outcome"] not in ("added", "addedNoPairing"):
            continue
        work = library.work(item.work_id)
        assert work.kind == e["kind"], e["file"]
        assert work.title == e["title"], e["file"]
        assert work.author == e["author"], e["file"]
        assert work.first_page_source == e["firstPageSource"], e["file"]
        assert work.relationships == e["relationships"], e["file"]
        assert work.fandoms == e["fandoms"], e["file"]
        assert work.original_file_name == e["file"]


def test_ids_and_files(imported):
    library, _ = imported
    assert len(library.works) == 11
    ids = [w.work_id for w in library.works] + [w.first_page_id for w in library.works]
    assert len(set(ids)) == len(ids)
    for work in library.works:
        assert work.stored_file == f"Works/{work.work_id}.{work.kind}"
        assert work.first_page_file == f"First Pages/{work.first_page_id}.pdf"
        assert library.path(work.stored_file).read_bytes() == fixture(work.original_file_name).read_bytes()
        document = pdfium.PdfDocument(library.path(work.first_page_file).read_bytes())
        assert len(document) == 1, work.title
        document.close()
    assert len(files(library.works_folder)) == 11
    assert len(files(library.first_pages_folder)) == 11


def test_library_json_lists(imported):
    library, _ = imported
    content = json.loads(library.library_file.read_text(encoding="utf-8"))
    assert content["version"] == 2
    assert [w["workID"] for w in content["works"]] == [w.work_id for w in library.works]
    assert len(content["pairings"]) == 16
    assert content["pairings"] == sorted(content["pairings"], key=alphabetical_key)
    assert "Draco Malfoy/Harry Potter" not in content["pairings"]
    assert len(content["characters"]) == 25
    assert content["fandoms"] == ["Criminal Minds (US TV)", "Harry Potter - J. K. Rowling", "Miraculous Ladybug",
                                  "Percy Jackson and the Olympians - Rick Riordan", "Sherlock (TV)",
                                  "魔道祖师 - 墨香铜臭 | Mo Dao Zu Shi - Mo Xiang Tong Xiu"]
    hpdm = next(e for e in content["pairingIndex"] if e["pairing"] == "Harry Potter/Draco Malfoy")
    assert {library.work(r["workID"]).title for r in hpdm["works"]} == {"The Quiet Winter", "Common Room Constellations", "Starlight Over Grimmauld"}
    hp = next(e for e in content["fandomIndex"] if e["fandom"] == "Harry Potter - J. K. Rowling")
    assert {library.work(r["workID"]).title for r in hp["works"]} == {"The Quiet Winter", "Common Room Constellations", "Crossroads"}
    harry = next(e for e in content["characterIndex"] if e["character"] == "Harry Potter")
    assert len(harry["works"]) == 4
    for index in ("pairingIndex", "characterIndex", "fandomIndex"):
        for entry in content[index]:
            for ref in entry["works"]:
                assert library.work(ref["workID"]).first_page_id == ref["firstPageID"]


def test_reload_unchanged(imported):
    library, _ = imported
    reopened = Library(library.root)
    assert reopened.works == library.works
    assert reopened.pairing_list() == library.pairing_list()
    assert reopened.load_problem is None


def test_same_file_again_is_duplicate(imported):
    library, _ = imported
    report = library.import_files([fixture("Lucky Charm.pdf")])
    assert [i.outcome for i in report.items] == ["duplicate"]
    assert len(library.works) == 11


def test_folder_import(tmp_path):
    library = Library(tmp_path / "library")
    report = library.import_files([FIXTURES])
    assert report.added_count == 11
    assert {i.file_name for i in report.of("skipped")} == {"expected.json", "notes.txt"}
    assert [i.file_name for i in report.of("duplicate")] == ["Zz Duplicate of The Quiet Winter.pdf"]
    assert len(report.of("unreadable")) == 3


def test_remove(imported):
    library, _ = imported
    work = next(w for w in library.works if w.title == "Lucky Charm")
    library.remove(work.work_id)
    assert library.work(work.work_id) is None
    assert not library.path(work.stored_file).exists()
    assert not library.path(work.first_page_file).exists()
    assert not any("Chloé" in g.display for g in library.pairing_list())
    assert len(Library(library.root).works) == 10


def test_reread_keeps_ids(imported):
    library, _ = imported
    before = [(w.work_id, w.first_page_id, list(w.relationships), list(w.fandoms)) for w in library.works]
    updated, failed = library.reread_all()
    assert failed == []
    assert updated == 11
    assert [(w.work_id, w.first_page_id, w.relationships, w.fandoms) for w in library.works] == before


def test_upgrade_from_version_1(imported):
    library, _ = imported
    before = [(w.work_id, w.fandoms) for w in library.works]
    content = json.loads(library.library_file.read_text(encoding="utf-8"))
    content["version"] = 1
    for k in ("characters", "characterIndex", "fandoms", "fandomIndex"):
        content.pop(k)
    for w in content["works"]:
        w.pop("fandoms")
    library.library_file.write_text(json.dumps(content), encoding="utf-8")

    old = Library(library.root)
    assert old.needs_upgrade
    assert all(not w.fandoms for w in old.works)
    old.upgrade_if_needed()
    assert not old.needs_upgrade
    assert [(w.work_id, w.fandoms) for w in old.works] == before
    assert json.loads(library.library_file.read_text(encoding="utf-8"))["version"] == 2


def test_unreadable_library_json_kept_aside(tmp_path):
    root = tmp_path / "library"
    root.mkdir()
    (root / "library.json").write_text("{ not json", encoding="utf-8")
    library = Library(root)
    assert library.works == []
    assert library.load_problem is not None
    assert any(name.startswith("library-unreadable-") for name in files(root))


def test_reads_a_library_written_by_the_mac_app(tmp_path, imported):
    """The Mac app writes `"key" : value` and leaves out a missing author; both apps must read each other's file."""
    library, _ = imported
    content = json.loads(library.library_file.read_text(encoding="utf-8"))
    mac_style = json.dumps(content, indent=2, sort_keys=True, ensure_ascii=False).replace('": ', '" : ')
    library.library_file.write_text(mac_style, encoding="utf-8")
    assert Library(library.root).works == library.works
    assert hashlib.sha256(library.library_file.read_bytes()).hexdigest()  # file still there
