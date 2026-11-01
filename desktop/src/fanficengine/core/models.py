"""Records, the pairing/character/fandom lists and the import report (SPEC sections 3, 4 and 6).

Same rules and the same library.json fields as Sources/FanficCore/Models.swift.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable

from .text import alphabetical_key, collapse, key, parse_relationship


@dataclass
class WorkRecord:
    """One imported work: library.json → works."""

    work_id: str  # upper-case UUID
    first_page_id: str
    kind: str  # "pdf" | "epub"
    original_file_name: str
    stored_file: str  # "Works/<work ID>.pdf", relative to the library folder, always with "/"
    first_page_file: str  # "First Pages/<first-page ID>.pdf"
    first_page_source: str  # "page 1" or the EPUB document path
    title: str
    author: str | None
    sha256: str
    imported_at: str  # ISO 8601, whole seconds, UTC: "2026-11-01T17:00:00Z"
    relationships: list[str]
    fandoms: list[str] = field(default_factory=list)

    _KEYS = {
        "work_id": "workID", "first_page_id": "firstPageID", "kind": "kind",
        "original_file_name": "originalFileName", "stored_file": "storedFile", "first_page_file": "firstPageFile",
        "first_page_source": "firstPageSource", "title": "title", "author": "author", "sha256": "sha256",
        "imported_at": "importedAt", "relationships": "relationships", "fandoms": "fandoms",
    }

    def to_json(self) -> dict:
        d = {json_key: getattr(self, name) for name, json_key in self._KEYS.items()}
        if self.author is None:
            del d["author"]  # the Mac app leaves the key out when there is no author
        return d

    @classmethod
    def from_json(cls, d: dict) -> "WorkRecord":
        """Reads version 1 entries too (they have no fandoms)."""
        values = {name: d.get(json_key) for name, json_key in cls._KEYS.items()}
        values["fandoms"] = list(values["fandoms"] or [])
        values["relationships"] = list(values["relationships"] or [])
        missing = [n for n in ("work_id", "first_page_id", "kind", "stored_file", "first_page_file", "sha256") if not values[n]]
        if missing:
            raise ValueError(f"work entry without {', '.join(missing)}")
        return cls(**values)


# ---------------------------------------------------------------- sidebar lists


@dataclass
class _Entry:
    spelling: str
    kind: str
    count: int = 0
    other_spellings: dict[str, int] | None = None
    work_ids: list[str] = field(default_factory=list)

    def add(self, spelling: str, work_id: str) -> None:
        if spelling == self.spelling:
            self.count += 1
        else:
            self.other_spellings = self.other_spellings or {}
            self.other_spellings[spelling] = self.other_spellings.get(spelling, 0) + 1
        if not self.work_ids or self.work_ids[-1] != work_id:  # a work's tags come one after another
            self.work_ids.append(work_id)

    @property
    def display(self) -> str:
        """The spelling used most often; on a tie, the first A–Z."""
        candidates = [(self.spelling, self.count), *(self.other_spellings or {}).items()]
        return min(candidates, key=lambda c: (-c[1], alphabetical_key(c[0])))[0]


@dataclass(frozen=True)
class Group:
    """A pairing, character or fandom in the sidebar: one name with the works that have it."""

    key: str
    display: str
    work_ids: tuple[str, ...]
    kind: str = "single"


def _collect(items: Iterable[tuple[str, str, str, str]]) -> list[Group]:
    """items: (group key, spelling, kind, work ID) → groups sorted A–Z by display name."""
    entries: dict[str, _Entry] = {}
    for group_key, spelling, kind, work_id in items:
        entry = entries.get(group_key)
        if entry is None:
            entry = entries[group_key] = _Entry(spelling, kind)
        entry.add(spelling, work_id)
    groups = [Group(k, e.display, tuple(e.work_ids), e.kind) for k, e in entries.items()]
    groups.sort(key=lambda g: alphabetical_key(g.display))
    return groups


def pairing_groups(works: list[WorkRecord], include_friendships: bool = True) -> list[Group]:
    """All relationship tags; "A/B" and "B/A" are one group."""
    def items():
        for work in works:
            for tag in work.relationships:
                r = parse_relationship(tag)
                if r.kind == "friendship" and not include_friendships:
                    continue
                yield r.group_key, tag, r.kind, work.work_id
    return _collect(items())


def character_groups(works: list[WorkRecord], include_friendships: bool = True) -> list[Group]:
    """Every person named in a relationship tag, once (not the first page's separate "Characters:" field)."""
    def items():
        for work in works:
            for tag in work.relationships:
                r = parse_relationship(tag)
                if r.kind == "pairing" or (r.kind == "friendship" and include_friendships):
                    for member in r.members:
                        name = collapse(member)
                        if key(name):
                            yield key(name), name, "single", work.work_id
    return _collect(items())


def fandom_groups(works: list[WorkRecord]) -> list[Group]:
    """Every fandom once; a crossover counts in each of its fandoms."""
    def items():
        for work in works:
            for fandom in work.fandoms:
                name = collapse(fandom)
                if key(name):
                    yield key(name), name, "single", work.work_id
    return _collect(items())


def sorted_groups(groups: list[Group], order: str) -> list[Group]:
    """order "name": A–Z; "count": most fanfics first, ties A–Z."""
    if order == "count":
        return sorted(groups, key=lambda g: (-len(g.work_ids), alphabetical_key(g.display)))
    return sorted(groups, key=lambda g: alphabetical_key(g.display))


# ---------------------------------------------------------------- import report

OUTCOMES = ("added", "addedNoPairing", "duplicate", "unreadable", "skipped")
OUTCOME_HEADINGS = {
    "added": "Added",
    "addedNoPairing": "Added, no pairing found",
    "duplicate": "Already in library",
    "unreadable": "Could not read",
    "skipped": "Skipped (not a PDF or EPUB)",
}


@dataclass
class ReportItem:
    file_name: str
    outcome: str
    detail: str | None = None
    work_id: str | None = None


@dataclass
class ImportReport:
    items: list[ReportItem] = field(default_factory=list)

    def of(self, outcome: str) -> list[ReportItem]:
        return [i for i in self.items if i.outcome == outcome]

    @property
    def added_count(self) -> int:
        return len(self.of("added")) + len(self.of("addedNoPairing"))
