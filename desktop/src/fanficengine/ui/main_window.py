"""The main window (docs/ui-spec-desktop.md): menus, toolbar with search, alpha notice bar, three columns, status bar."""

from __future__ import annotations

import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

from PySide6.QtCore import QTimer, QUrl, Qt
from PySide6.QtGui import QAction, QDesktopServices, QIcon, QKeySequence, QPalette
from PySide6.QtWidgets import (
    QFileDialog, QFrame, QHBoxLayout, QLabel, QLineEdit, QMainWindow, QMessageBox, QSizePolicy, QSplitter, QToolBar,
    QToolButton, QVBoxLayout, QWidget,
)

from ..core import search
from ..core.library import SAVE_INTERVAL, Library
from ..core.models import ImportReport, ReportItem
from ..core.text import key as name_key
from .details import Details
from .dialogs import ALPHA_NOTE, ImportSummaryDialog, SettingsDialog, show_about, show_folder_label
from .drop_overlay import DropOverlay
from .importer import BackgroundReader
from .prefs import Prefs
from .sidebar import Sidebar
from .works_list import WorksList


@dataclass
class StartOptions:
    """Developer options (for screenshots and testing); normal use needs none."""

    imports: list[Path] = field(default_factory=list)
    search: str | None = None
    sidebar: str | None = None  # "fandom:<name>" | "character:<name>" | "pairing:<name>"
    select_title: str | None = None
    open_settings: bool = False
    open_about: bool = False
    preview_drop: bool = False
    window_size: tuple[int, int] | None = None


def reveal(path: Path) -> None:
    """Shows the file in Explorer / Finder, or opens its folder on Linux."""
    if sys.platform == "win32":
        subprocess.Popen(f'explorer /select,"{path}"')
    elif sys.platform == "darwin":
        subprocess.Popen(["open", "-R", str(path)])
    else:
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(path.parent)))


def _gear_icon(color) -> QIcon:
    """A gear: the icon theme's own if it has one (Linux), otherwise the ⚙ character drawn in the text colour."""
    for name in ("preferences-system", "emblem-system", "configure", "settings"):
        icon = QIcon.fromTheme(name)
        if not icon.isNull():
            return icon
    from PySide6.QtGui import QFont, QPainter, QPixmap
    pixmap = QPixmap(64, 64)
    pixmap.fill(Qt.GlobalColor.transparent)
    painter = QPainter(pixmap)
    font = QFont()
    font.setPixelSize(52)
    painter.setFont(font)
    painter.setPen(color)
    painter.drawText(pixmap.rect(), Qt.AlignmentFlag.AlignCenter, "\u2699")
    painter.end()
    return QIcon(pixmap)


def _icon(theme: QIcon.ThemeIcon, *names: str) -> QIcon:
    icon = QIcon.fromTheme(theme)
    for name in names:
        if not icon.isNull():
            break
        icon = QIcon.fromTheme(name)
    return icon


class MainWindow(QMainWindow):
    def __init__(self, library: Library, prefs: Prefs, options: StartOptions):
        super().__init__()
        self.library, self.prefs, self.options = library, prefs, options
        self.search_text = ""
        self.selection: tuple[str, str | None] | None = ("all", None)
        self.selected_work_id: str | None = None
        self._hits_cache: tuple | None = None
        self._sidebar_revision = -1
        self._reader: BackgroundReader | None = None
        self._queue: list[list[Path]] = []

        self.setWindowTitle("Fanfic Engine (Alpha)")
        self.resize(*(options.window_size or (1100, 700)))
        self.setMinimumSize(900, 560)
        self.setAcceptDrops(True)
        self.show_label = show_folder_label()

        self._build_menus()
        self._build_toolbar()

        central = QWidget()
        column = QVBoxLayout(central)
        column.setContentsMargins(0, 0, 0, 0)
        column.setSpacing(0)
        column.addWidget(self._build_alpha_bar())

        self.sidebar = Sidebar(library, prefs)
        self.sidebar.setMinimumWidth(200)
        self.sidebar.setMaximumWidth(320)
        self.works = WorksList(self.show_label)
        self.works.setMinimumWidth(320)
        self.details = Details(library, self.show_label)
        self.details.setMinimumWidth(340)
        self.splitter = QSplitter(Qt.Orientation.Horizontal)
        for widget in (self.sidebar, self.works, self.details):
            self.splitter.addWidget(widget)
        for i in range(3):
            self.splitter.setCollapsible(i, False)
        self.splitter.setStretchFactor(2, 1)
        self.splitter.setSizes([240, 420, max(self.width() - 660, 340)])
        column.addWidget(self.splitter, 1)
        self.setCentralWidget(central)
        self.overlay = DropOverlay(central)

        self.status = QLabel()
        self.status.setContentsMargins(8, 0, 0, 0)
        self.statusBar().addWidget(self.status, 1)
        self.statusBar().setSizeGripEnabled(False)

        self.sidebar.selection_changed.connect(self._sidebar_selected)
        self.works.work_selected.connect(self._work_selected)
        self.works.action.connect(self._work_action)
        self.details.action.connect(self._work_action)

        self._apply_start_options()
        self.refresh()
        QTimer.singleShot(0, self._after_show)

    # ------------------------------------------------------------ building

    def _build_menus(self) -> None:
        file_menu = self.menuBar().addMenu("&File")
        add = QAction("Add Files…", self, shortcut=QKeySequence(QKeySequence.StandardKey.Open), triggered=self.add_files)
        file_menu.addAction(add)
        self.reread_action = QAction("Re-read Library", self, triggered=self.reread_library)
        file_menu.addAction(self.reread_action)
        file_menu.addAction(QAction("Show Library Folder", self, triggered=self.show_library_folder))
        settings = QAction("Settings…", self, shortcut=QKeySequence("Ctrl+,"), triggered=self.open_settings)
        settings.setMenuRole(QAction.MenuRole.PreferencesRole)
        file_menu.addAction(settings)
        file_menu.addSeparator()
        quit_action = QAction("Quit", self, shortcut=QKeySequence(QKeySequence.StandardKey.Quit), triggered=self.close)
        quit_action.setMenuRole(QAction.MenuRole.QuitRole)
        file_menu.addAction(quit_action)
        help_menu = self.menuBar().addMenu("&Help")
        about = QAction("About Fanfic Engine", self, triggered=lambda: show_about(self))
        about.setMenuRole(QAction.MenuRole.AboutRole)
        help_menu.addAction(about)

    def _build_toolbar(self) -> None:
        bar = QToolBar("Main")
        bar.setMovable(False)
        bar.setFloatable(False)
        bar.setToolButtonStyle(Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        bar.addAction(QAction(_icon(QIcon.ThemeIcon.ListAdd, "list-add"), "Add Files", self, triggered=self.add_files))
        bar.addAction(QAction(_icon(QIcon.ThemeIcon.FolderOpen, "folder-open", "folder"), "Library Folder", self,
                              triggered=self.show_library_folder))
        bar.addAction(QAction(_gear_icon(self.palette().color(QPalette.ColorRole.ButtonText)), "Settings",
                              self, triggered=self.open_settings))
        spacer = QWidget()
        spacer.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
        bar.addWidget(spacer)
        self.search_field = QLineEdit()
        self.search_field.setPlaceholderText("Search pairing, e.g. Harry/Draco")
        self.search_field.setClearButtonEnabled(True)
        self.search_field.setFixedWidth(320)
        self.search_field.textChanged.connect(self._search_changed)
        bar.addWidget(self.search_field)
        self.addToolBar(bar)

    def _build_alpha_bar(self) -> QFrame:
        self.alpha_bar = QFrame()
        self.alpha_bar.setObjectName("alphaBar")
        self.alpha_bar.setAutoFillBackground(True)
        self.alpha_bar.setBackgroundRole(QPalette.ColorRole.Base)  # with Text: readable in light and dark mode
        self.alpha_bar.setFrameShape(QFrame.Shape.StyledPanel)
        row = QHBoxLayout(self.alpha_bar)
        row.setContentsMargins(12, 6, 6, 6)
        text = QLabel(f"<b>{ALPHA_NOTE}</b> Please report problems on the project's GitHub page.")
        text.setForegroundRole(QPalette.ColorRole.Text)
        row.addWidget(text, 1)
        close = QToolButton()
        close.setText("×")
        close.setToolTip("Hide until the next start")
        close.setAutoRaise(True)
        close.clicked.connect(self.alpha_bar.hide)
        row.addWidget(close)
        return self.alpha_bar

    # ------------------------------------------------------------ start options

    def _apply_start_options(self) -> None:
        o = self.options
        if o.search is not None:
            self.search_text = o.search
            self.selection = None
        if o.sidebar and ":" in o.sidebar:
            kind, name = o.sidebar.split(":", 1)
            if kind == "fandom":
                self.selection = ("fandom", name_key(name))
            elif kind == "character":
                self.selection, self.search_text = ("character", name_key(name)), name
            elif kind == "pairing":
                from ..core.text import parse_relationship
                self.selection, self.search_text = ("pairing", parse_relationship(name).group_key), name
        if o.select_title:
            self.selected_work_id = next((w.work_id for w in self.library.works if w.title == o.select_title), None)
        self.search_field.blockSignals(True)
        self.search_field.setText(self.search_text)
        self.search_field.blockSignals(False)

    def _after_show(self) -> None:
        if self.library.load_problem:
            QMessageBox.warning(self, "The library file could not be read", self.library.load_problem)
        if self.library.needs_upgrade:
            self.reread_library(silent=True)
        if self.options.imports:
            self.import_paths(self.options.imports)
        if self.options.preview_drop:
            self.overlay.cover_parent()
            self.overlay.show()
        if self.options.open_settings:
            QTimer.singleShot(300, self.open_settings)
        if self.options.open_about:
            QTimer.singleShot(300, lambda: show_about(self))

    # ------------------------------------------------------------ what is shown

    def hits(self) -> list[search.SearchHit]:
        cache_key = (self.search_text, self.selection, self.library.revision)
        if self._hits_cache and self._hits_cache[0] == cache_key:
            return self._hits_cache[1]
        kind = self.selection[0] if self.selection else None
        if kind == "noPairing":
            hits = search.run("", self.library.works_without_pairing)
        elif kind == "fandom":
            fandom_key = self.selection[1]
            hits = search.run(self.search_text, [w for w in self.library.works if any(name_key(f) == fandom_key for f in w.fandoms)])
        else:
            hits = search.run(self.search_text, self.library.works)
        self._hits_cache = (cache_key, hits)
        return hits

    def refresh(self) -> None:
        if self._sidebar_revision != self.library.revision:
            self._sidebar_revision = self.library.revision
            self.sidebar.rebuild()
        self.sidebar.show_selection(self.selection)
        hits = self.hits()
        if not self.library.works:
            empty = "Drop EPUB or PDF files here, or click Add Files…"
        elif self.selection and self.selection[0] == "noPairing":
            empty = "Every fanfic has a pairing"
        else:
            empty = f"No fanfics found for “{self.search_text}”"
        self.works.set_hits(hits, empty, self.selected_work_id)
        self.details.show_work(self.library.work(self.selected_work_id) if self.selected_work_id else None)
        self.reread_action.setEnabled(bool(self.library.works) and self._reader is None)
        if self._reader is None:
            self._update_status()

    def _update_status(self, busy: str | None = None) -> None:
        if busy:
            self.status.setText(busy)
            return
        count = len(self.hits())
        text = "1 fanfic" if count == 1 else f"{count} fanfics"
        if self.selection and self.selection[0] == "fandom":
            name = self.sidebar.display_name("fandom", self.selection[1])
            if name:
                text = f"{name} · {text}"
        self.status.setText(text)

    # ------------------------------------------------------------ sidebar and search

    def _sidebar_selected(self, selection: tuple[str, str | None]) -> None:
        self.selection = selection
        kind, sel_key = selection
        if kind in ("pairing", "character"):
            self.search_text = self.sidebar.display_name(kind, sel_key) or ""
        else:
            self.search_text = ""
        self.search_field.blockSignals(True)
        self.search_field.setText(self.search_text)
        self.search_field.blockSignals(False)
        self.refresh()

    def _search_changed(self, text: str) -> None:
        self.search_text = text
        kind = self.selection[0] if self.selection else None
        if kind in ("pairing", "character") and self.sidebar.display_name(kind, self.selection[1]) == text:
            pass
        elif kind == "fandom":
            pass  # search inside the selected fandom
        elif not text.strip():
            if kind != "noPairing":
                self.selection = ("all", None)
        else:
            self.selection = None
        self.refresh()

    def _work_selected(self, work_id: str | None) -> None:
        self.selected_work_id = work_id
        self.details.show_work(self.library.work(work_id) if work_id else None)

    # ------------------------------------------------------------ work actions

    def _work_action(self, action: str, work_id: str) -> None:
        work = self.library.work(work_id)
        if work is None:
            return
        if action == "open":
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(self.library.path(work.stored_file))))
        elif action == "firstPage":
            QDesktopServices.openUrl(QUrl.fromLocalFile(str(self.library.path(work.first_page_file))))
        elif action == "show":
            reveal(self.library.path(work.stored_file))
        elif action == "remove":
            answer = QMessageBox.question(
                self, "Remove from Library",
                f"Remove “{work.title}” from the library?\n\nIts copy and its first-page copy are deleted from the "
                "library folder. Your original file is not touched.",
                QMessageBox.StandardButton.Cancel | QMessageBox.StandardButton.Yes, QMessageBox.StandardButton.Cancel)
            if answer == QMessageBox.StandardButton.Yes:
                try:
                    self.library.remove(work_id)
                except OSError as error:
                    QMessageBox.warning(self, f"“{work.title}” could not be removed", str(error))
                if self.selected_work_id == work_id:
                    self.selected_work_id = None
                self.refresh()

    def show_library_folder(self) -> None:
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(self.library.root)))

    def open_settings(self) -> None:
        def changed():
            self._sidebar_revision = -1
            self.refresh()
        SettingsDialog(self.prefs, self.library, changed, self.show_library_folder, self.reread_library, self).exec()

    # ------------------------------------------------------------ import

    def add_files(self) -> None:
        dialog = QFileDialog(self, "Add Fanfics")
        dialog.setFileMode(QFileDialog.FileMode.ExistingFiles)
        dialog.setNameFilters(["Fanfics (*.epub *.pdf)", "All files (*)"])
        if dialog.exec():
            self.import_paths([Path(p) for p in dialog.selectedFiles()])

    def import_paths(self, paths: list[Path]) -> None:
        if self._reader is not None:
            self._queue.append(paths)
            return
        files, skipped = Library.expand(paths)
        self._report = ImportReport([ReportItem(p.name, "skipped") for p in skipped])
        self._pending: list = []
        self._last_save = time.monotonic()
        self._total, self._done = len(files), 0
        self._reader = BackgroundReader([(None, p) for p in files], self)
        self._reader.file_read.connect(self._import_file_read)
        self._reader.finished.connect(self._import_finished)
        self._update_status(f"Importing 0 of {self._total}…")
        self._reader.start()

    def _import_file_read(self, _tag, path: Path, prepared, error: str | None) -> None:
        self._done += 1
        self._update_status(f"Importing {self._done} of {self._total}…")
        if prepared is None:
            self._report.items.append(ReportItem(path.name, "unreadable", error))
            return
        existing = self.library.is_duplicate(prepared.sha256)
        if existing is not None:
            self._report.items.append(ReportItem(path.name, "duplicate", existing.title, existing.work_id))
            return
        try:
            record = self.library.add_prepared(prepared, path.name)
        except OSError as error:
            self._report.items.append(ReportItem(path.name, "unreadable", f"could not be saved: {error}"))
            return
        outcome = "added" if record.relationships else "addedNoPairing"
        self._pending.append((record, ReportItem(path.name, outcome, None, record.work_id)))
        if time.monotonic() - self._last_save > SAVE_INTERVAL:
            self.library.flush(self._pending, self._report)
            self._last_save = time.monotonic()
            self.refresh()

    def _import_finished(self) -> None:
        self.library.flush(self._pending, self._report)
        self._reader = None
        if self.selected_work_id is None:
            self.selected_work_id = next((i.work_id for i in self._report.items if i.outcome in ("added", "addedNoPairing")), None)
        self.refresh()
        ImportSummaryDialog(self._report, self).open()
        if self._queue:
            self.import_paths(self._queue.pop(0))

    # ------------------------------------------------------------ re-read

    def reread_library(self, silent: bool = False) -> None:
        if self._reader is not None or not self.library.works:
            return
        jobs = [(w.work_id, self.library.path(w.stored_file)) for w in self.library.works]
        self._reread = {"updated": 0, "failed": [], "silent": silent, "total": len(jobs)}
        self._reader = BackgroundReader(jobs, self)
        self._reader.file_read.connect(self._reread_file_read)
        self._reader.finished.connect(self._reread_finished)
        self._update_status("Reading the library again…")
        self.reread_action.setEnabled(False)
        self._reader.start()

    def _reread_file_read(self, work_id: str, path: Path, prepared, error: str | None) -> None:
        work = self.library.work(work_id)
        if prepared is None or work is None:
            self._reread["failed"].append(f"{work.title if work else path.name}: {error}")
            return
        try:
            self.library.apply_reread(work_id, prepared)
            self._reread["updated"] += 1
        except OSError as error:
            self._reread["failed"].append(f"{work.title}: {error}")

    def _reread_finished(self) -> None:
        self._reread["failed"].extend(self.library.finish_changes())
        if not self._reread["failed"]:
            self.library.needs_upgrade = False
        self._reader = None
        self.details.forget()
        self.refresh()
        info = self._reread
        if not info["silent"]:
            text = f"{info['updated']} of {info['total']} fanfics were read again. Their IDs did not change."
            if info["failed"]:
                text += "\n\nProblems:\n" + "\n".join(info["failed"])
            QMessageBox.information(self, "Library re-read", text)

    # ------------------------------------------------------------ drag and drop

    def dragEnterEvent(self, event) -> None:
        if event.mimeData().hasUrls() and any(u.isLocalFile() for u in event.mimeData().urls()):
            event.acceptProposedAction()
            self.overlay.cover_parent()
            self.overlay.show()

    def dragLeaveEvent(self, event) -> None:
        if not self.options.preview_drop:
            self.overlay.hide()

    def dropEvent(self, event) -> None:
        self.overlay.hide()
        paths = [Path(u.toLocalFile()) for u in event.mimeData().urls() if u.isLocalFile()]
        if paths:
            event.acceptProposedAction()
            self.import_paths(paths)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        if self.overlay.isVisible():
            self.overlay.cover_parent()

    def closeEvent(self, event) -> None:
        if self._reader is not None:
            self._reader.stop()
            if hasattr(self, "_pending"):
                self.library.flush(self._pending, self._report)
        super().closeEvent(event)
