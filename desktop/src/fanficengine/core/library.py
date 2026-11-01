"""The library folder: Works/, First Pages/ and library.json (SPEC sections 2–4 and 7).

Same folder layout and the same library.json (version 2) as the Mac app, so both can read each other's libraries.
"""

from __future__ import annotations

import json
import os
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

from . import reader
from .models import (
    Group, ImportReport, ReportItem, WorkRecord, character_groups, fandom_groups, pairing_groups, sorted_groups,
)

CURRENT_VERSION = 2
SAVE_INTERVAL = 3.0  # seconds between saves during a batch import (and always at the end)


def default_root() -> Path:
    """Windows %APPDATA%\\Fanfic Engine, Linux ~/.local/share/Fanfic Engine, macOS the Mac app's folder."""
    if sys.platform == "win32":
        base = Path(os.environ.get("APPDATA") or Path.home() / "AppData" / "Roaming")
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
    return base / "Fanfic Engine"


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _write_atomic(path: Path, data: bytes) -> None:
    temporary = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        temporary.write_bytes(data)
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


class Library:
    def __init__(self, root: Path | str | None = None):
        self.root = Path(root) if root is not None else default_root()
        self.works: list[WorkRecord] = []
        self.revision = 0
        self.load_problem: str | None = None
        self.needs_upgrade = False
        self._by_id: dict[str, int] = {}
        self._by_sha: dict[str, int] = {}
        self._lists: dict[tuple, list[Group]] = {}
        self.load()

    # ------------------------------------------------------------ paths and lookups

    @property
    def works_folder(self) -> Path:
        return self.root / "Works"

    @property
    def first_pages_folder(self) -> Path:
        return self.root / "First Pages"

    @property
    def library_file(self) -> Path:
        return self.root / "library.json"

    def path(self, relative: str) -> Path:
        return self.root.joinpath(*relative.split("/"))

    def work(self, work_id: str) -> WorkRecord | None:
        index = self._by_id.get(work_id)
        return self.works[index] if index is not None and index < len(self.works) else None

    @property
    def works_without_pairing(self) -> list[WorkRecord]:
        return [w for w in self.works if not w.relationships]

    # ------------------------------------------------------------ sidebar lists (built once per change)

    def pairing_list(self, include_friendships: bool = True, sort: str = "name") -> list[Group]:
        cache_key = ("pairings", include_friendships, sort)
        if cache_key not in self._lists:
            base = pairing_groups(self.works, include_friendships) if sort == "name" else \
                sorted_groups(self.pairing_list(include_friendships), sort)
            self._lists[cache_key] = base
        return self._lists[cache_key]

    def character_list(self, include_friendships: bool = True, sort: str = "name") -> list[Group]:
        cache_key = ("characters", include_friendships, sort)
        if cache_key not in self._lists:
            base = character_groups(self.works, include_friendships) if sort == "name" else \
                sorted_groups(self.character_list(include_friendships), sort)
            self._lists[cache_key] = base
        return self._lists[cache_key]

    def fandom_list(self, sort: str = "name") -> list[Group]:
        cache_key = ("fandoms", sort)
        if cache_key not in self._lists:
            self._lists[cache_key] = fandom_groups(self.works) if sort == "name" else sorted_groups(self.fandom_list(), sort)
        return self._lists[cache_key]

    def _works_changed(self) -> None:
        self._by_id = {w.work_id: i for i, w in enumerate(self.works)}
        self._by_sha = {}
        for i, w in enumerate(self.works):
            self._by_sha.setdefault(w.sha256, i)
        self._lists_changed()

    def _lists_changed(self) -> None:
        self._lists.clear()
        self.revision += 1

    # ------------------------------------------------------------ loading and saving

    def load(self) -> None:
        self.works_folder.mkdir(parents=True, exist_ok=True)
        self.first_pages_folder.mkdir(parents=True, exist_ok=True)
        self.works = []
        if self.library_file.exists():
            try:
                content = json.loads(self.library_file.read_text(encoding="utf-8"))
                self.works = [WorkRecord.from_json(w) for w in content["works"]]
                self.needs_upgrade = int(content.get("version", 1)) < CURRENT_VERSION and bool(self.works)
            except (OSError, ValueError, KeyError, TypeError) as error:
                stamp = datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
                aside = self.root / f"library-unreadable-{stamp}.json"
                try:
                    os.replace(self.library_file, aside)
                except OSError:
                    pass
                self.load_problem = f"library.json could not be read and was kept as {aside.name}. {error}"
                self.works = []
        self._works_changed()

    def save(self) -> None:
        """Writes library.json (version 2) in one atomic write. The lists always include friendship tags."""
        def refs(ids):
            return [{"firstPageID": self.work(i).first_page_id, "workID": i} for i in ids if self.work(i)]
        pairings, characters, fandoms = self.pairing_list(), self.character_list(), self.fandom_list()
        content = {
            "version": CURRENT_VERSION,
            "works": [w.to_json() for w in self.works],
            "pairings": [g.display for g in pairings],
            "pairingIndex": [{"pairing": g.display, "works": refs(g.work_ids)} for g in pairings],
            "characters": [g.display for g in characters],
            "characterIndex": [{"character": g.display, "works": refs(g.work_ids)} for g in characters],
            "fandoms": [g.display for g in fandoms],
            "fandomIndex": [{"fandom": g.display, "works": refs(g.work_ids)} for g in fandoms],
        }
        _write_atomic(self.library_file, json.dumps(content, sort_keys=True, indent=2, ensure_ascii=False).encode("utf-8"))

    def upgrade_if_needed(self) -> None:
        """Re-reads a version 1 library once so every work gets its fandoms. IDs do not change."""
        if self.needs_upgrade:
            _, failed = self.reread_all()
            if not failed:
                self.needs_upgrade = False

    # ------------------------------------------------------------ import

    @staticmethod
    def expand(paths: list[Path]) -> tuple[list[Path], list[Path]]:
        """PDF/EPUB files and skipped files; folders are searched (subfolders too, hidden files left out), sorted by name."""
        files: list[Path] = []
        skipped: list[Path] = []

        def classify(p: Path) -> None:
            (files if p.suffix.lower() in (".pdf", ".epub") else skipped).append(p)

        for path in map(Path, paths):
            if path.is_dir():
                found = [p for p in path.rglob("*") if p.is_file()
                         and not any(part.startswith(".") for part in p.relative_to(path).parts)]
                for p in sorted(found, key=lambda p: str(p).casefold()):
                    classify(p)
            elif path.is_file():
                classify(path)
            else:
                skipped.append(path)
        return files, skipped

    def is_duplicate(self, sha: str) -> WorkRecord | None:
        index = self._by_sha.get(sha)
        return self.works[index] if index is not None and index < len(self.works) else None

    def add_prepared(self, prepared: reader.PreparedWork, original_file_name: str) -> WorkRecord:
        """Gives the work its two IDs and writes both copies; library.json is written by `flush`."""
        work_id, first_page_id = str(uuid.uuid4()).upper(), str(uuid.uuid4()).upper()
        record = WorkRecord(
            work_id=work_id, first_page_id=first_page_id, kind=prepared.kind, original_file_name=original_file_name,
            stored_file=f"Works/{work_id}.{prepared.kind}", first_page_file=f"First Pages/{first_page_id}.pdf",
            first_page_source=prepared.first_page_source, title=prepared.title, author=prepared.author,
            sha256=prepared.sha256, imported_at=_now(), relationships=prepared.relationships, fandoms=prepared.fandoms,
        )
        work_path, page_path = self.path(record.stored_file), self.path(record.first_page_file)
        try:
            _write_atomic(work_path, prepared.file_data)
            _write_atomic(page_path, prepared.first_page_pdf)
        except OSError:
            for p in (work_path, page_path):
                p.unlink(missing_ok=True)
            raise
        self.works.append(record)
        self._by_id[record.work_id] = len(self.works) - 1
        self._by_sha.setdefault(record.sha256, len(self.works) - 1)
        return record

    def flush(self, pending: list[tuple[WorkRecord, ReportItem]], report: ImportReport) -> None:
        """Saves library.json for the works added since the last save; on failure takes them out again."""
        if not pending:
            return
        self._lists_changed()
        try:
            self.save()
            report.items.extend(item for _, item in pending)
        except OSError as error:
            ids = {record.work_id for record, _ in pending}
            self.works = [w for w in self.works if w.work_id not in ids]
            self._works_changed()
            for record, item in pending:
                self.path(record.stored_file).unlink(missing_ok=True)
                self.path(record.first_page_file).unlink(missing_ok=True)
                report.items.append(ReportItem(item.file_name, "unreadable", f"could not be saved: {error}"))
        pending.clear()

    def import_files(self, paths: list[Path], read: Callable[[Path], reader.PreparedWork] = reader.read,
                     progress: Callable[[int, int], None] | None = None) -> ImportReport:
        report = ImportReport()
        files, skipped = self.expand(paths)
        report.items.extend(ReportItem(p.name, "skipped") for p in skipped)
        pending: list[tuple[WorkRecord, ReportItem]] = []
        last_save = time.monotonic()
        for done, path in enumerate(files):
            if progress:
                progress(done, len(files))
            try:
                prepared = read(path)
            except (reader.ReadError, OSError) as error:
                report.items.append(ReportItem(path.name, "unreadable", str(error)))
                continue
            existing = self.is_duplicate(prepared.sha256)
            if existing is not None:
                report.items.append(ReportItem(path.name, "duplicate", existing.title, existing.work_id))
                continue
            try:
                record = self.add_prepared(prepared, path.name)
            except OSError as error:
                report.items.append(ReportItem(path.name, "unreadable", f"could not be saved: {error}"))
                continue
            outcome = "added" if record.relationships else "addedNoPairing"
            pending.append((record, ReportItem(path.name, outcome, None, record.work_id)))
            if time.monotonic() - last_save > SAVE_INTERVAL:
                self.flush(pending, report)
                last_save = time.monotonic()
        self.flush(pending, report)
        return report

    # ------------------------------------------------------------ remove and re-read

    def remove(self, work_id: str) -> None:
        """Deletes the work's copy, its first-page copy and its entries in library.json."""
        index = self._by_id.get(work_id)
        if index is None:
            return
        record = self.works.pop(index)
        self._works_changed()
        try:
            self.save()
        except OSError:
            self.works.insert(index, record)
            self._works_changed()
            raise
        self.path(record.stored_file).unlink(missing_ok=True)
        self.path(record.first_page_file).unlink(missing_ok=True)

    def reread_all(self, read: Callable[[Path], reader.PreparedWork] = reader.read) -> tuple[int, list[str]]:
        """Reads every stored work again; IDs stay, first pages, pairings and fandoms are replaced."""
        updated, failed = 0, []
        for record in list(self.works):
            try:
                self.apply_reread(record.work_id, read(self.path(record.stored_file)))
                updated += 1
            except (reader.ReadError, OSError) as error:
                failed.append(f"{record.title}: {error}")
        failed.extend(self.finish_changes())
        return updated, failed

    def apply_reread(self, work_id: str, prepared: reader.PreparedWork) -> None:
        """Replaces one work's first-page copy, pairings and fandoms (call `finish_changes` afterwards)."""
        record = self.work(work_id)
        if record is None:
            return
        _write_atomic(self.path(record.first_page_file), prepared.first_page_pdf)
        record.relationships = prepared.relationships
        record.fandoms = prepared.fandoms
        record.first_page_source = prepared.first_page_source

    def finish_changes(self) -> list[str]:
        """Rebuilds the lists and saves library.json; returns problems (empty when saved)."""
        self._works_changed()
        try:
            self.save()
            return []
        except OSError as error:
            return [f"library.json: {error}"]
