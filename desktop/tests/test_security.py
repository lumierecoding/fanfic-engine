"""Crafted files from the security scans of 4 and 13 November 2026 (SPEC section 3) — the same cases as
Tests/FanficCoreTests/SecurityTests.swift: each must be refused or read quickly, and the faster code must give exactly
the same results as the code it replaced."""

from __future__ import annotations

import html
import io
import random
import re
import struct
import time
import tracemalloc
import zipfile

import pytest

from conftest import FIXTURES
from fanficengine.core import reader, search, text as T
from fanficengine.core.models import WorkRecord
from fanficengine.core.reader import EPUBBook, ReadError, read_epub


def epub_data(docs: list[str], extra: dict[str, bytes] | None = None, *, manifest: str | None = None,
              spine: str | None = None) -> bytes:
    """An EPUB with the given (X)HTML documents (d0.xhtml, d1.xhtml, …) in its reading order, or with its own manifest
    and spine (the elements inside them)."""
    container = ('<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
                 '<rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>')
    if manifest is None:
        manifest = "".join(f'<item id="d{i}" href="d{i}.xhtml" media-type="application/xhtml+xml"/>' for i in range(len(docs)))
    if spine is None:
        spine = "".join(f'<itemref idref="d{i}"/>' for i in range(len(docs)))
    package = ('<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="2.0">'
               '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Crafted</dc:title></metadata>'
               f"<manifest>{manifest}</manifest><spine>{spine}</spine></package>")
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("mimetype", "application/epub+zip")
        extra = extra or {}
        if "META-INF/container.xml" not in extra:
            z.writestr("META-INF/container.xml", container)
        z.writestr("content.opf", package)
        for i, doc in enumerate(docs):
            z.writestr(f"d{i}.xhtml", doc)
        for name, data in extra.items():
            z.writestr(name, data)
    return buffer.getvalue()


# ---------------------------------------------------------------- limits


def test_oversized_part_is_refused():
    big = epub_data(["<p>Relationship: A/B</p>"], {"META-INF/container.xml": b"\0" * (reader.MAX_MEMBER_SIZE + 1)})
    with pytest.raises(ReadError, match="larger than 16 MB"):
        EPUBBook(big)


def test_part_that_unpacks_to_more_than_it_claims_stays_small():
    """A part that claims 1000 bytes but unpacks to 200 MB: ZipFile.read would unpack all of it first."""
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("mimetype", "application/epub+zip")
        z.writestr("META-INF/container.xml", b"\0" * (200 * 1024 * 1024))
    data = bytearray(buffer.getvalue())
    local = data.find(b"PK\x03\x04", data.find(b"META-INF/container.xml") - 40)
    struct.pack_into("<I", data, local + 22, 1000)
    central = data.rfind(b"PK\x01\x02")
    struct.pack_into("<I", data, central + 24, 1000)
    tracemalloc.start()
    try:
        with pytest.raises(ReadError):
            EPUBBook(bytes(data))
        peak = tracemalloc.get_traced_memory()[1]
    finally:
        tracemalloc.stop()
    assert peak < 64 * 1024 * 1024, f"{peak / 1e6:.0f} MB"


def test_repeated_long_spine_path_stays_small():
    """The scan of 13 November, larger: one manifest entry with a 60,000-byte path of many parts and its id 200,000 times
    in the spine. The old code resolved and kept every copy (about 12 GB) before the 50-document limit applied."""
    long_path = "/".join(["abcdefghi"] * 6_000) + ".xhtml"
    data = epub_data([], manifest=f'<item id="long" href="{long_path}"/>', spine='<itemref idref="long"/>' * 200_000)
    tracemalloc.start()
    try:
        start = time.perf_counter()
        book = EPUBBook(data)
        elapsed = time.perf_counter() - start
        peak = tracemalloc.get_traced_memory()[1]
    finally:
        tracemalloc.stop()
    assert book.spine_paths == [long_path] * reader.MAX_DOCUMENTS_TRIED
    assert peak < 256 * 1024 * 1024, f"{peak / 1e6:.0f} MB"
    assert elapsed < 30, f"{elapsed:.1f} s"
    with pytest.raises(ReadError):
        read_epub(data, "x")  # the document doesn't exist, so the work has no text


def test_overlong_spine_path_is_left_out():
    long = "a" * 70_000 + ".xhtml"
    data = epub_data(["<p>Relationship: Harry Potter/Draco Malfoy</p>"],
                     manifest=f'<item id="long" href="{long}"/><item id="d0" href="d0.xhtml"/>',
                     spine='<itemref idref="long"/><itemref idref="d0"/><itemref idref="long"/>')
    assert EPUBBook(data).spine_paths == ["d0.xhtml"]
    assert read_epub(data, "x").relationships == ["Harry Potter/Draco Malfoy"]


def test_spine_order_is_the_same_as_before():
    data = epub_data(["<p>a</p>", "<p>b</p>"], manifest='<item id="d0" href="d0.xhtml"/><item id="d1" href="sub/../d1.xhtml#top"/>',
                     spine='<itemref idref="d0"/><itemref idref="x"/><itemref idref="d0"/><itemref idref="d1"/>')
    assert EPUBBook(data).spine_paths == ["d0.xhtml", "d0.xhtml", "d1.xhtml"]
    many = "".join(f'<itemref idref="d{i % 2}"/>' for i in range(60))
    book = EPUBBook(epub_data(["<p>a</p>", "<p>b</p>"], spine=many))
    assert book.spine_paths == [f"d{i % 2}.xhtml" for i in range(50)]


def test_at_most_50_documents_are_read():
    empty = '<html><body><img src="x.png"/></body></html>'
    text = "<html><body><p>Relationship: Harry Potter/Draco Malfoy</p></body></html>"
    assert read_epub(epub_data([empty] * 49 + [text]), "x").relationships == ["Harry Potter/Draco Malfoy"]
    with pytest.raises(ReadError):
        read_epub(epub_data([empty] * 50 + [text]), "x")


# ---------------------------------------------------------------- crafted files that used to freeze the app


@pytest.mark.parametrize("piece,count", [
    ("<", 400_000), ("<!--", 100_000), ("<head", 80_000), ("<HEAD", 80_000), ("<script", 50_000), ("<br", 130_000),
    ("<p", 200_000), ("</div", 80_000), ("<blockquote", 36_000), ("> ", 200_000), ("<head></head>", 30_000),
    ("x", 2_000_000), ("x ", 1_000_000), ("<br>", 500_000),
])
def test_crafted_markup_is_read_quickly(piece, count):
    # The flood ends the document: no `>` or closing tag after it, the worst case for the old regular expressions.
    doc = ('<html><body><p>Relationship: Harry Potter/Draco Malfoy</p><p>Summary:</p><blockquote class="userstuff">'
           "<p>A summary.</p>" + piece * count)
    start = time.perf_counter()
    work = read_epub(epub_data([doc]), "x")
    elapsed = time.perf_counter() - start
    assert work.relationships == ["Harry Potter/Draco Malfoy"]
    assert elapsed < 5, f"{count} × {piece}: {elapsed:.1f} s"


def test_crafted_pairing_tags_are_searched_instantly():
    tag_b, tag_c = "/".join(["A"] * 14 + ["B"]), "/".join(["A"] * 14 + ["C"])
    work = WorkRecord("ID1", "P1", "pdf", "x.pdf", "", "", "page 1", "x", None, "sha1", "2026-11-04T00:00:00Z", [tag_b, tag_c])
    start = time.perf_counter()
    hits = search.run(tag_b, [work])
    assert time.perf_counter() - start < 1
    assert hits[0].matched == {tag_b}
    longest = ["A"] * 74 + ["B"]  # the longest tag AO3 allows (150 characters), all one name
    start = time.perf_counter()
    search.assign(["a"] * 75, tuple(longest))
    assert time.perf_counter() - start < 1


# ---------------------------------------------------------------- same results as before

_OLD_COMMENTS = re.compile(r"<!--.*?-->", re.S)
_OLD_INVISIBLE = re.compile(r"<(head|script|style|svg|template)\b.*?</\1\s*>", re.S | re.I)
_OLD_LINE_BREAK = re.compile(r"<br\b[^>]*>", re.I)
_OLD_BLOCK_TAG = re.compile(
    r"</?(p|div|h[1-6]|li|dt|dd|dl|ul|ol|tr|td|th|table|section|article|blockquote|header|footer|hr|pre|figure"
    r"|figcaption|nav|aside|main|body|html)\b[^>]*>",
    re.I,
)
_OLD_ANY_TAG = re.compile(r"<[^>]*>", re.S)


def old_plain_text(markup: str) -> str:
    """plain_text before the security scan, with whole regular expressions (quadratic time on crafted files)."""
    s = _OLD_COMMENTS.sub("", markup)
    s = _OLD_INVISIBLE.sub("", s)
    s = _OLD_LINE_BREAK.sub("\n", s)
    s = _OLD_BLOCK_TAG.sub("\n", s)
    s = _OLD_ANY_TAG.sub("", s)
    s = html.unescape(s)
    lines = (" ".join(line.split()) for line in s.splitlines())
    return "\n".join(line for line in lines if line)


def old_assign(keys: list[str], members: tuple[str, ...]) -> bool:
    """The pairing matcher before the security scan: tries every order (correct, but factorial time)."""
    if len(keys) > len(members):
        return False
    used = [False] * len(members)

    def place(i: int) -> bool:
        if i == len(keys):
            return True
        for j, member in enumerate(members):
            if not used[j] and T.matches_key(keys[i], member):
                used[j] = True
                if place(i + 1):
                    return True
                used[j] = False
        return False

    return place(0)


def test_same_text_for_test_files():
    documents = 0
    for path in sorted(FIXTURES.glob("**/*.epub")):
        try:
            book = EPUBBook(path.read_bytes())
        except ReadError:
            continue
        for spine_path in book.spine_paths:
            markup = T.decode(book._read(spine_path))
            assert T.plain_text(markup) == old_plain_text(markup), (path.name, spine_path)
            documents += 1
    assert documents >= 20


def test_same_text_for_random_markup():
    pieces = ["<", ">", "<!--", "-->", "<!-", "--", "-", "<head>", "</head>", "<HEAD ", "</head >", "</HeAd\n>", "<headx>",
              "<script>", "</script>", "<style>", "</style >", "<svg", "</svg>", "<template>", "</Template >", "<br>",
              "<br/>", "<BR ", "<brx>", "<p>", "</p>", '<p class="x">', "<pre>", "<blockquote>", "</blockquote>",
              "<h1>", "<h7>", "<b>", "</b>", "text", "Relationship: A/B", " ", "  ", "\n", "\t", "&amp;", "&lt;",
              "&#233;", "é", "😀", ""]
    rng = random.Random(20261104)
    for _ in range(5_000):
        doc = "".join(rng.choice(pieces) for _ in range(rng.randint(0, 40)))
        assert T.plain_text(doc) == old_plain_text(doc), repr(doc)


def test_same_matching_as_trying_every_order():
    members = ["Harry Potter", "Draco Malfoy", "Harry", "Hermione Granger", "Ron Weasley", "Draco", "H", "Harry Potter"]
    queries = [T.key(q) for q in ["harry", "draco", "dra", "her", "ron", "h", "malfoy", "potter", "harry potter", "x"]]
    rng = random.Random(42)
    yes = 0
    for _ in range(20_000):
        keys = [rng.choice(queries) for _ in range(rng.randint(1, 4))]
        tag = tuple(rng.choice(members) for _ in range(rng.randint(1, 5)))
        answer = search.assign(keys, tag)
        assert answer == old_assign(keys, tag), (keys, tag)
        yes += answer
    assert yes > 1_000
