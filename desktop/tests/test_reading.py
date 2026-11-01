"""Reading files: the same cases as Tests/FanficCoreTests/ReadingTests.swift."""

from __future__ import annotations

import pypdfium2 as pdfium
import pytest

from conftest import fixture
from fanficengine.core import reader, text as T


def pdf_text(data: bytes) -> tuple[int, str]:
    document = pdfium.PdfDocument(data)
    try:
        textpage = document[0].get_textpage()
        return len(document), textpage.get_text_bounded()
    finally:
        document.close()


def test_epub_deflate_and_stored_entries():
    for name in ["Untamed Hearts.epub", "Starlight Over Grimmauld.epub"]:
        book = reader.EPUBBook(fixture(name).read_bytes())
        assert book.spine_paths, name


def test_not_a_zip():
    with pytest.raises(reader.ReadError):
        reader.EPUBBook(fixture("Broken.epub").read_bytes())


def test_epub_title_author_reading_order():
    book = reader.EPUBBook(fixture("Starlight Over Grimmauld.epub").read_bytes())
    assert book.title == "Starlight Over Grimmauld"
    assert book.author == "example-author-9"
    assert book.spine_paths == ["OEBPS/cover.xhtml", "OEBPS/titlepage.xhtml", "OEBPS/preface.xhtml", "OEBPS/chapter1.xhtml"]
    assert book.text("OEBPS/cover.xhtml") == ""


def test_html_to_text():
    markup = """
    <html><head><title>Ignore me</title><style>p{}</style></head><body>
    <dl><dt>Relationships:</dt><dd><a href="#">A&nbsp;/ B</a>,   <a>C &amp; D</a></dd></dl>
    <p>Chlo&#233; and Chlo&#xE9;<br/>next&hellip;</p><!-- hidden --></body></html>
    """
    assert T.plain_text(markup) == "Relationships:\nA / B, C & D\nChloé and Chloé\nnext…"


def test_spec_example_line_break_inside_name():
    page = "Relationships:\nHarry Potter/Draco Malfoy, Hermione Granger/Pansy\nParkinson/Ginny Weasley, Harry Potter & Ron Weasley\nCharacters:\nHarry Potter, Draco Malfoy"
    assert T.relationships(page) == ["Harry Potter/Draco Malfoy", "Hermione Granger/Pansy Parkinson/Ginny Weasley", "Harry Potter & Ron Weasley"]


def test_inline_labels_spacing_singular():
    assert T.relationships("Fandom: X Relationships: A/B, C & D Characters: A, C") == ["A/B", "C & D"]
    assert T.relationships("relationship :  Harry Potter / Draco Malfoy ,Ron Weasley&Hermione Granger\nCharacter: Harry") == \
        ["Harry Potter/Draco Malfoy", "Ron Weasley & Hermione Granger"]
    assert T.relationships("Category: M/M\nRelationship: A/B\nAdditional Tags: Hurt/Comfort") == ["A/B"]


def test_missing_empty_long_repeated():
    assert T.relationships("Characters: Harry Potter") is None
    assert T.relationships("Relationship:\nCharacters: Harry") == []
    long = "x" * 151
    assert T.relationships(f"Relationships: A/B, {long}, A/B\nLanguage: English") == ["A/B"]


def test_continuation_only_when_next_page_ends_field():
    page = "Notes\nRelationships:\nSherlock Holmes/John Watson,"
    assert T.relationships(page, "Mycroft Holmes/Greg Lestrade\nCharacters: Sherlock") == ["Sherlock Holmes/John Watson", "Mycroft Holmes/Greg Lestrade"]
    assert T.relationships(page, "Chapter 1\nA long chapter, with commas, and prose.") == ["Sherlock Holmes/John Watson"]


def test_free_text_after_field():
    notes = "\n".join(f"Author's note line {i}: thank you for reading." for i in range(1, 13))
    assert T.fandoms(f"Fandom:\nSherlock (TV)\n{notes}\nRelationships:\nA/B") == ["Sherlock (TV)"]
    assert T.relationships(f"Relationships:\nA/B, C/D\n{notes}") == ["A/B", "C/D"]


def test_fandom_field():
    assert T.fandoms("Category:\nM/M\nFandom:\nHarry Potter - J. K. Rowling\nRelationship:\nA/B") == ["Harry Potter - J. K. Rowling"]
    assert T.fandoms("Fandoms: Harry Potter - J. K. Rowling, Percy Jackson and the Olympians - Rick Riordan Relationships: A/B") == \
        ["Harry Potter - J. K. Rowling", "Percy Jackson and the Olympians - Rick Riordan"]
    assert T.fandoms("Rating: Explicit\nRelationships: A/B") is None
    assert T.relationships("Fandom:\nMarvel Cinematic Universe\nRelationships:\nLoki/Tony Stark\nCharacters: Loki") == ["Loki/Tony Stark"]


def test_relationship_kinds_and_group_key():
    assert T.parse_relationship("A/B/C").kind == "pairing"
    assert T.parse_relationship("A/B/C").members == ("A", "B", "C")
    assert T.parse_relationship("A & B").kind == "friendship"
    assert T.parse_relationship("Original Character").kind == "single"
    assert T.parse_relationship("Harry Potter/Draco Malfoy").group_key == T.parse_relationship("draco malfoy/HARRY POTTER").group_key
    assert T.parse_relationship("A/B").group_key != T.parse_relationship("A & B").group_key


def test_pdf_first_page_copy():
    prepared = reader.read(fixture("Anthology.pdf"))
    pages, content = pdf_text(prepared.first_page_pdf)
    assert pages == 1
    assert "Remus Lupin/Sirius Black" in content
    assert prepared.first_page_source == "page 2"


def test_epub_first_page_copy():
    prepared = reader.read(fixture("Untamed Hearts.epub"))
    pages, content = pdf_text(prepared.first_page_pdf)
    assert pages == 1
    assert "Relationships:" in content
    assert "Lan Zhan | Lan Wangji/Wei Ying | Wei Wuxian" in content
