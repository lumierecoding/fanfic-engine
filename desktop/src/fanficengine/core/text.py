"""Plain text from (X)HTML, name normalising and the labelled first-page fields (SPEC sections 5 and 6).

Same rules as the Mac app (Sources/FanficCore/HTMLText.swift, Relationships.swift, Search.swift).
"""

from __future__ import annotations

import html
import re
import unicodedata
from dataclasses import dataclass
from functools import lru_cache

# ---------------------------------------------------------------- HTML → text

# Each step gives the same result as the regular expression in its comment (`<[^>]*>` and so on), but finds the end
# of a match with one forward search: only the short, fixed-length start of a match is a regular expression. Letting
# the regex engine look for the end from every `<` again took time growing with the square of the length on crafted
# files (security scan, 4 November 2026). Same steps as HTMLText.swift.

# Start of `<(head|script|style|svg|template)\b.*?</\1\s*>` (across lines, any case): an invisible element.
_INVISIBLE_START = re.compile(r"<(head|script|style|svg|template)\b", re.I)
# Start of `<br\b[^>]*>`.
_LINE_BREAK_START = re.compile(r"<br\b", re.I)
# Start of `</?(p|div|…)\b[^>]*>`.
_BLOCK_TAG_START = re.compile(
    r"</?(p|div|h[1-6]|li|dt|dd|dl|ul|ol|tr|td|th|table|section|article|blockquote|header|footer|hr|pre|figure"
    r"|figcaption|nav|aside|main|body|html)\b",
    re.I,
)


def _comment_spans(s: str):
    """`<!--.*?-->` (across lines)."""
    position = 0
    while (start := s.find("<!--", position)) >= 0 and (end := s.find("-->", start + 4)) >= 0:
        position = end + 3
        yield start, position


def _element_spans(s: str, start_pattern: re.Pattern):
    """`start.*?</\\1\\s*>` (across lines, any case) for a start pattern `<(names)\\b`. All closing tags of a name
    are found once, so a start without a closing tag costs no new search."""
    position = 0
    closers: dict[str, list] = {}  # name → [closing tag ranges, index of the next one to look at]
    while (match := start_pattern.search(s, position)) is not None:
        name = match.group(1)
        key = name.casefold()
        if key not in closers:
            closer = re.compile("</" + re.escape(name) + r"\s*>", re.I)
            closers[key] = [[m.span() for m in closer.finditer(s)], 0]
        tags, index = closers[key]
        while index < len(tags) and tags[index][0] < match.end():
            index += 1
        closers[key][1] = index
        if index < len(tags):
            position = tags[index][1]
            yield match.start(), position
        else:
            position = match.start() + 1


def _tag_spans(s: str, start_pattern: re.Pattern | None = None):
    """`start[^>]*>` for a start pattern that begins with `<`, or `<[^>]*>` without one. Without a `>` after a
    start, no later start has one either, so the search stops there."""
    position = 0
    while True:
        if start_pattern is None:
            start = s.find("<", position)
            if start < 0:
                return
            after = start + 1
        else:
            match = start_pattern.search(s, position)
            if match is None:
                return
            start, after = match.start(), match.end()
        end = s.find(">", after)
        if end < 0:
            return
        position = end + 1
        yield start, position


def _replace(s: str, spans, template: str) -> str:
    parts: list[str] = []
    copied = 0
    for start, end in spans:
        parts.append(s[copied:start])
        parts.append(template)
        copied = end
    if not parts:
        return s
    parts.append(s[copied:])
    return "".join(parts)


def plain_text(markup: str) -> str:
    """Turns an (X)HTML document into plain text lines. Nothing is loaded from anywhere."""
    s = _replace(markup, _comment_spans(markup), "")
    s = _replace(s, _element_spans(s, _INVISIBLE_START), "")
    s = _replace(s, _tag_spans(s, _LINE_BREAK_START), "\n")
    s = _replace(s, _tag_spans(s, _BLOCK_TAG_START), "\n")
    s = _replace(s, _tag_spans(s), "")
    s = html.unescape(s)
    lines = (" ".join(line.split()) for line in s.splitlines())
    return "\n".join(line for line in lines if line)


def decode(data: bytes) -> str:
    """Text in UTF-16 (with byte order mark), UTF-8 or Windows-1252."""
    if data.startswith(b"\xff\xfe") or data.startswith(b"\xfe\xff"):
        return data.decode("utf-16", errors="replace")
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        pass
    try:
        return data.decode("cp1252")
    except UnicodeDecodeError:
        return data.decode("utf-8", errors="replace")


def has_visible_text(text: str) -> bool:
    return any(ch.isalnum() for ch in text)


def collapse(s: str) -> str:
    """All runs of spaces and line breaks become one space."""
    return " ".join(s.split())


# ---------------------------------------------------------------- names (SPEC section 6)


def _fold(s: str) -> str:
    decomposed = unicodedata.normalize("NFKD", s)
    return "".join(ch for ch in decomposed if not unicodedata.combining(ch)).casefold()


@lru_cache(maxsize=200_000)
def words(s: str) -> tuple[str, ...]:
    """Lower case, accents removed, split at every character that is not a letter or digit."""
    result: list[str] = []
    current: list[str] = []
    for ch in _fold(s):
        if ch.isalnum():
            current.append(ch)
        elif current:
            result.append("".join(current))
            current = []
    if current:
        result.append("".join(current))
    return tuple(result)


@lru_cache(maxsize=200_000)
def key(s: str) -> str:
    """The words joined without spaces: "Draco  Malfoy" and "dracomalfoy" both give "dracomalfoy"."""
    return "".join(words(s))


@lru_cache(maxsize=200_000)
def suffix_keys(member: str) -> tuple[str, ...]:
    """The member's words joined from each word onwards: "Lan Zhan | Lan Wangji" → lanzhanlanwangji, zhanlanwangji, …"""
    w = words(member)
    return tuple("".join(w[i:]) for i in range(len(w)))


@lru_cache(maxsize=200_000)
def sort_key(s: str) -> str:
    """For sorting A–Z ignoring case and accents."""
    return _fold(s)


def alphabetical_key(s: str) -> tuple[str, str]:
    """A–Z ignoring case and accents; the exact spelling breaks ties so the order is always the same."""
    return (sort_key(s), s)


def matches_key(query_key: str, member: str) -> bool:
    """True when the query (as a key) is the start of the member's words joined from some word onwards."""
    if not query_key:
        return False
    return any(suffix.startswith(query_key) for suffix in suffix_keys(member))


def matches(query: str, member: str) -> bool:
    """ "Draco", "malfoy", "draco malfoy" match "Draco Malfoy"; "Ron" does not match "Aaron Hotchner"."""
    return matches_key(key(query), member)


# ---------------------------------------------------------------- relationship tags


@dataclass(frozen=True)
class Relationship:
    """One entry of a Relationship field: "A/B" (pairing), "A & B" (friendship) or a single name."""

    text: str
    kind: str  # "pairing" | "friendship" | "single"
    members: tuple[str, ...]
    group_key: str  # the same for "A/B" and "B/A"


@lru_cache(maxsize=200_000)
def parse_relationship(tag: str) -> Relationship:
    if "/" in tag or "&" in tag:
        kind = "pairing" if "/" in tag else "friendship"
        parts = tuple(p.strip() for p in tag.split("/" if kind == "pairing" else "&") if p.strip())
        members = parts or (tag,)
    else:
        kind = "single"
        members = (tag,)
    group_key = kind + ":" + "|".join(sorted(key(m) for m in members))
    return Relationship(tag, kind, members, group_key)


# ---------------------------------------------------------------- labelled fields (SPEC section 5)

MAX_TAG_LENGTH = 150  # AO3 tags are at most 150 characters

_NEXT_LABEL = re.compile(
    r"\b(?:Relationships?|Fandoms?|Characters?|Additional\s+Tags|Freeform|Language|Series|Collections?|Stats"
    r"|Published|Updated|Completed|Words|Chapters|Summary|Notes|Rating|Archive\s+Warnings?|Categor(?:y|ies))\s*:",
    re.I,
)
RELATIONSHIP_LABEL = re.compile(r"\bRelationships?\s*:", re.I)
FANDOM_LABEL = re.compile(r"\bFandoms?\s*:", re.I)


def tags(field: str) -> list[str]:
    """Splits a field's text into tidied tags (split at commas, line breaks joined, repeats dropped).
    A piece longer than any tag means free text ran into the field: its first line is kept, then reading stops."""
    seen: set[str] = set()
    result: list[str] = []
    for raw in field.split(","):
        tag = collapse(raw)
        stop = False
        if len(tag) > MAX_TAG_LENGTH:
            tag = next((collapse(line) for line in raw.splitlines() if collapse(line)), "")
            stop = True
        tag = re.sub(r"\s*/\s*", "/", tag)
        tag = re.sub(r"\s*&\s*", " & ", tag)
        tag = tag.strip(" .;&/")
        if tag and len(tag) <= MAX_TAG_LENGTH and tag not in seen:
            seen.add(tag)
            result.append(tag)
        if stop:
            break
    return result


def field_values(label: re.Pattern[str], text: str, next_page: str | None = None) -> list[str] | None:
    """The field's values in page order; None when the label is not on the page, [] when the field is empty.
    The field ends at the next AO3 label or at the end of the page; then the next page is read too,
    but only if it ends the field."""
    start = label.search(text)
    if start is None:
        return None
    rest = text[start.end():]
    end = _NEXT_LABEL.search(rest)
    if end is not None:
        field = rest[: end.start()]
    elif next_page is not None and (next_end := _NEXT_LABEL.search(next_page)) is not None:
        field = rest + "\n" + next_page[: next_end.start()]
    else:
        field = rest
    return tags(field)


def has_relationship_field(text: str) -> bool:
    return RELATIONSHIP_LABEL.search(text) is not None


def relationships(text: str, next_page: str | None = None) -> list[str] | None:
    return field_values(RELATIONSHIP_LABEL, text, next_page)


def fandoms(text: str, next_page: str | None = None) -> list[str] | None:
    return field_values(FANDOM_LABEL, text, next_page)
