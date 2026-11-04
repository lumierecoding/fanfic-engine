"""Queries and search (SPEC section 6). Same rules as Sources/FanficCore/Search.swift."""

from __future__ import annotations

from dataclasses import dataclass, field

from .models import WorkRecord
from .text import Relationship, key, matches_key, parse_relationship, sort_key


class PairingQuery:
    """A search typed by the user: "A/B", "B / A", "A & B", "A", or empty."""

    def __init__(self, raw: str):
        text = raw.strip()

        def names(separator: str) -> list[str]:
            return [n.strip() for n in text.split(separator) if key(n.strip())]

        if "/" in text:
            n = names("/")
            self.mode, self.names = ("pairing", n) if n else ("everything", [])
        elif "&" in text:
            n = names("&")
            self.mode, self.names = ("friendship", n) if n else ("everything", [])
        elif not key(text):
            self.mode, self.names = "everything", []
        else:
            self.mode, self.names = "name", [text]
        self.keys = [key(n) for n in self.names]

    @property
    def is_everything(self) -> bool:
        return self.mode == "everything"

    def matches(self, r: Relationship) -> bool:
        if self.mode == "pairing":
            return r.kind == "pairing" and assign(self.keys, r.members)
        if self.mode == "friendship":
            return r.kind == "friendship" and assign(self.keys, r.members)
        if self.mode == "name":
            return any(matches_key(self.keys[0], m) for m in r.members)
        return False


def assign(keys: list[str], members: tuple[str, ...]) -> bool:
    """Each query name must match a different member, in any order. Found as a matching between names and members
    (augmenting paths), at most names² × members steps. Trying every order instead took 14! steps for a crafted tag
    with 14 equal names (security scan, 4 November 2026). Same as Search.swift."""
    if len(keys) > len(members):
        return False
    fits = [[matches_key(k, m) for m in members] for k in keys]
    owner: list[int | None] = [None] * len(members)  # which name each member is given to

    def give(i: int, visited: list[bool]) -> bool:
        """Gives name i a member, moving names that already have one to another member if needed."""
        for j in range(len(members)):
            if fits[i][j] and not visited[j]:
                visited[j] = True
                if owner[j] is None or give(owner[j], visited):
                    owner[j] = i
                    return True
        return False

    return all(give(i, [False] * len(members)) for i in range(len(keys)))


@dataclass
class SearchHit:
    work: WorkRecord
    matched: set[str] = field(default_factory=set)  # the work's tags that matched (empty for an empty query)


def run(query: str, works: list[WorkRecord]) -> list[SearchHit]:
    """Works whose relationships match the query, sorted by title then author. An empty query lists every work."""
    q = PairingQuery(query)
    hits: list[SearchHit] = []
    for work in works:
        if q.is_everything:
            hits.append(SearchHit(work))
            continue
        matched = {tag for tag in work.relationships if q.matches(parse_relationship(tag))}
        if matched:
            hits.append(SearchHit(work, matched))
    hits.sort(key=lambda h: (sort_key(h.work.title), sort_key(h.work.author or "")))
    return hits
