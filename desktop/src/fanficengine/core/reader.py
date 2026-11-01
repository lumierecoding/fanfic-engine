"""Reads one PDF or EPUB: fingerprint, title, author, first-page copy, relationships and fandoms (SPEC section 3).

Same rules as Sources/FanficCore/WorkReader.swift and EPUBBook.swift. PDFs are read with PDFium (pypdfium2);
EPUB first pages are drawn from their text with Qt's PDF writer. Nothing is loaded from the internet.
"""

from __future__ import annotations

import hashlib
import io
import posixpath
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote

import pypdfium2 as pdfium

from . import text as T

PAGES_CHECKED = 3  # pages (PDF) or text documents (EPUB) checked for the Relationship field


class ReadError(Exception):
    """A file that cannot be imported; the message is shown in the import summary."""


@dataclass
class PreparedWork:
    kind: str
    sha256: str
    file_data: bytes
    first_page_pdf: bytes
    first_page_source: str
    first_page_text: str
    has_relationship_field: bool
    relationships: list[str]
    fandoms: list[str]
    title: str
    author: str | None


def read(path: Path) -> PreparedWork:
    kind = path.suffix.lower().lstrip(".")
    if kind not in ("pdf", "epub"):
        raise ReadError("not a PDF or EPUB")
    data = path.read_bytes()
    fallback_title = path.stem
    return read_pdf(data, fallback_title) if kind == "pdf" else read_epub(data, fallback_title)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _non_empty(s: str | None) -> str | None:
    s = (s or "").strip()
    return s or None


def _fandoms(texts: list[str], chosen: int, checked: int) -> list[str]:
    """The Fandom field from the chosen first page; if it has none, from the other checked pages."""
    for index in [chosen, *[i for i in range(checked) if i != chosen]]:
        nxt = texts[index + 1] if index + 1 < len(texts) else None
        values = T.fandoms(texts[index], nxt)
        if values is not None:
            return values
    return []


# ---------------------------------------------------------------- PDF


def _page_text(document: pdfium.PdfDocument, index: int) -> str:
    textpage = document[index].get_textpage()
    try:
        raw = textpage.get_text_bounded()
    finally:
        textpage.close()
    return "\n".join(line.rstrip() for line in raw.replace("\r\n", "\n").replace("\r", "\n").split("\n"))


def read_pdf(data: bytes, fallback_title: str) -> PreparedWork:
    try:
        document = pdfium.PdfDocument(data)
    except pdfium.PdfiumError as error:
        if "password" in str(error).lower():
            raise ReadError("the PDF is password-protected") from error
        raise ReadError("not a readable PDF") from error
    try:
        if len(document) == 0:
            raise ReadError("not a readable PDF")
        texts = [_page_text(document, i) for i in range(min(PAGES_CHECKED + 1, len(document)))]
        checked = texts[:PAGES_CHECKED]
        if not any(T.has_visible_text(t) for t in checked):
            raise ReadError("no text on the first pages (scanned or image-only?)")

        chosen = next((i for i, t in enumerate(checked) if T.has_relationship_field(t)), 0)
        nxt = texts[chosen + 1] if chosen + 1 < len(texts) else None
        tags = T.relationships(texts[chosen], nxt)

        single = pdfium.PdfDocument.new()
        try:
            single.import_pages(document, [chosen])
            buffer = io.BytesIO()
            single.save(buffer)
        finally:
            single.close()

        meta = document.get_metadata_dict()
        return PreparedWork(
            kind="pdf", sha256=sha256(data), file_data=data, first_page_pdf=buffer.getvalue(),
            first_page_source=f"page {chosen + 1}", first_page_text=texts[chosen],
            has_relationship_field=tags is not None, relationships=tags or [],
            fandoms=_fandoms(texts, chosen, len(checked)),
            title=_non_empty(meta.get("Title")) or fallback_title, author=_non_empty(meta.get("Author")),
        )
    finally:
        document.close()


# ---------------------------------------------------------------- EPUB


def _local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1].rsplit(":", 1)[-1]


def _resolve(base: str, href: str) -> str:
    href = unquote(href.split("#", 1)[0])
    parts = [p for p in base.split("/") if p]
    for component in href.split("/"):
        if component == "..":
            if parts:
                parts.pop()
        elif component and component != ".":
            parts.append(component)
    return "/".join(parts)


class EPUBBook:
    """An EPUB's title, author and reading order, from container.xml and the OPF package file."""

    def __init__(self, data: bytes):
        try:
            self._zip = zipfile.ZipFile(io.BytesIO(data))
        except zipfile.BadZipFile as error:
            raise ReadError("not a ZIP/EPUB file") from error
        self._names = {name.lower(): name for name in self._zip.namelist()}
        try:
            container = ET.fromstring(self._read("META-INF/container.xml"))
            opf_path = next((e.get("full-path") for e in container.iter() if _local(e.tag) == "rootfile" and e.get("full-path")), None)
            if not opf_path:
                raise ReadError("the EPUB has no package (OPF) file")
            package = ET.fromstring(self._read(opf_path))
        except ET.ParseError as error:
            raise ReadError("the EPUB's package file could not be read") from error

        self.title: str | None = None
        self.author: str | None = None
        manifest: dict[str, str] = {}
        spine: list[str] = []
        for element in package.iter():
            name = _local(element.tag)
            if name == "title" and self.title is None:
                self.title = _non_empty("".join(element.itertext()))
            elif name == "creator" and self.author is None:
                self.author = _non_empty("".join(element.itertext()))
            elif name == "item" and element.get("id") and element.get("href"):
                manifest[element.get("id")] = element.get("href")
            elif name == "itemref" and element.get("idref"):
                spine.append(element.get("idref"))
        base = posixpath.dirname(opf_path)
        self.spine_paths = [_resolve(base, manifest[idref]) for idref in spine if idref in manifest]
        if not self.spine_paths:
            raise ReadError("the EPUB has no pages in its reading order")

    def _read(self, name: str) -> bytes:
        actual = name if name in self._zip.namelist() else self._names.get(name.lower())
        if actual is None:
            raise ReadError(f"{name} is missing inside the EPUB")
        try:
            return self._zip.read(actual)
        except (zipfile.BadZipFile, OSError, NotImplementedError) as error:
            raise ReadError("the EPUB file is damaged") from error

    def text(self, path: str) -> str:
        return T.plain_text(T.decode(self._read(path)))


def read_epub(data: bytes, fallback_title: str) -> PreparedWork:
    from .textpage import pdf_from_text

    book = EPUBBook(data)
    documents: list[tuple[str, str]] = []  # text documents in reading order; image-only pages skipped
    for path in book.spine_paths:
        try:
            content = book.text(path)
        except ReadError:
            continue
        if T.has_visible_text(content):
            documents.append((path, content))
            if len(documents) > PAGES_CHECKED:
                break
    if not documents:
        raise ReadError("no text on the first pages (scanned or image-only?)")

    texts = [t for _, t in documents]
    chosen = next((i for i, t in enumerate(texts[:PAGES_CHECKED]) if T.has_relationship_field(t)), 0)
    nxt = texts[chosen + 1] if chosen + 1 < len(texts) else None
    tags = T.relationships(texts[chosen], nxt)
    return PreparedWork(
        kind="epub", sha256=sha256(data), file_data=data, first_page_pdf=pdf_from_text(texts[chosen]),
        first_page_source=documents[chosen][0], first_page_text=texts[chosen],
        has_relationship_field=tags is not None, relationships=tags or [],
        fandoms=_fandoms(texts, chosen, min(PAGES_CHECKED, len(texts))),
        title=book.title or fallback_title, author=book.author,
    )
