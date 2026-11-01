"""Import summary, Settings and About (ui-spec-desktop W11, W13)."""

from __future__ import annotations

import sys
from typing import Callable

from PySide6.QtCore import Qt
from PySide6.QtGui import QPalette
from PySide6.QtWidgets import (
    QCheckBox, QComboBox, QDialog, QDialogButtonBox, QFormLayout, QGroupBox, QHBoxLayout, QLabel, QMessageBox,
    QPushButton, QScrollArea, QVBoxLayout, QWidget,
)

from .. import __version__
from ..core.library import Library
from ..core.models import OUTCOME_HEADINGS, OUTCOMES, ImportReport
from .prefs import Prefs

ALPHA_NOTE = "Alpha — not tested on Windows or Linux."


def _secondary(label: QLabel) -> QLabel:
    """Grey (secondary) text in the system's placeholder colour."""
    palette = label.palette()
    palette.setColor(QPalette.ColorRole.WindowText, palette.color(QPalette.ColorRole.PlaceholderText))
    label.setPalette(palette)
    return label


class ImportSummaryDialog(QDialog):
    def __init__(self, report: ImportReport, parent: QWidget | None = None):
        super().__init__(parent)
        self.setWindowTitle("Import finished")
        self.setMinimumWidth(460)
        layout = QVBoxLayout(self)
        count = report.added_count
        heading = QLabel("1 fanfic added" if count == 1 else f"{count} fanfics added")
        font = heading.font()
        font.setPointSizeF(font.pointSizeF() * 1.4)
        font.setBold(True)
        heading.setFont(font)
        layout.addWidget(heading)

        content = QWidget()
        inner = QVBoxLayout(content)
        inner.setContentsMargins(0, 0, 0, 0)
        for outcome in OUTCOMES:
            items = report.of(outcome)
            if not items:
                continue
            title = QLabel(f"{OUTCOME_HEADINGS[outcome]} ({len(items)})")
            bold = title.font()
            bold.setBold(True)
            title.setFont(bold)
            inner.addWidget(title)
            for item in items:
                inner.addWidget(QLabel(item.file_name))
                if item.detail:
                    detail = f"same file as “{item.detail}”" if outcome == "duplicate" else item.detail
                    inner.addWidget(_secondary(QLabel(detail)))
            inner.addSpacing(8)
        inner.addStretch(1)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setWidget(content)
        scroll.setMinimumHeight(min(380, content.sizeHint().height() + 8))
        scroll.setMaximumHeight(380)
        layout.addWidget(scroll)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok)
        buttons.accepted.connect(self.accept)
        layout.addWidget(buttons)


class SettingsDialog(QDialog):
    """The same four groups as the Mac app's Settings window."""

    def __init__(self, prefs: Prefs, library: Library, on_change: Callable[[], None],
                 show_folder: Callable[[], None], reread: Callable[[], None], parent: QWidget | None = None):
        super().__init__(parent)
        self.setWindowTitle("Settings")
        self.setFixedWidth(480)
        self._prefs, self._on_change = prefs, on_change
        layout = QVBoxLayout(self)

        sidebar = QGroupBox("Sidebar")
        form = QFormLayout(sidebar)
        for key, text in (("showFandoms", "Show Fandoms"), ("showCharacters", "Show Characters"), ("showPairings", "Show Pairings")):
            box = QCheckBox(text)
            box.setChecked(prefs.get(key))
            box.toggled.connect(lambda checked, k=key: self._set(k, checked))
            form.addRow(box)
        sort = QComboBox()
        sort.addItem("Name", "name")
        sort.addItem("Number of fanfics", "count")
        sort.setCurrentIndex(0 if prefs.get("sidebarSort") == "name" else 1)
        sort.currentIndexChanged.connect(lambda _: self._set("sidebarSort", sort.currentData()))
        form.addRow("Sort lists by", sort)
        layout.addWidget(sidebar)

        relationships = QGroupBox("Relationships")
        rel_layout = QVBoxLayout(relationships)
        friendships = QCheckBox("Include friendship tags (A && B)")  # "&&" shows one "&" in Qt
        friendships.setChecked(prefs.get("includeFriendships"))
        friendships.toggled.connect(lambda checked: self._set("includeFriendships", checked))
        rel_layout.addWidget(friendships)
        note = _secondary(QLabel("When off, A & B tags are left out of Pairings, and people who only appear in them "
                                 "are left out of Characters. Searching is not affected."))
        note.setWordWrap(True)
        rel_layout.addWidget(note)
        layout.addWidget(relationships)

        lib = QGroupBox("Library")
        lib_form = QFormLayout(lib)
        folder = QLabel(str(library.root))
        folder.setWordWrap(True)
        folder.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        lib_form.addRow("Folder", folder)
        works = len(library.works)
        pages = len(list(library.first_pages_folder.glob("*.pdf")))
        lib_form.addRow("Contents", QLabel(f"{works} {'fanfic' if works == 1 else 'fanfics'} · "
                                            f"{pages} {'first page' if pages == 1 else 'first pages'}"))
        row = QHBoxLayout()
        row.addStretch(1)
        show = QPushButton(show_folder_label())
        show.setAutoDefault(False)
        show.clicked.connect(show_folder)
        again = QPushButton("Re-read Library")
        again.setAutoDefault(False)
        again.setEnabled(works > 0)
        again.clicked.connect(reread)
        row.addWidget(show)
        row.addWidget(again)
        lib_form.addRow(row)
        layout.addWidget(lib)

        offline = QGroupBox("Offline")
        off_layout = QVBoxLayout(offline)
        off_text = QLabel("Fanfic Engine works entirely on this computer. It never connects to the internet.")
        off_text.setWordWrap(True)
        off_layout.addWidget(off_text)
        layout.addWidget(offline)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Close)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def _set(self, key: str, value) -> None:
        self._prefs.set(key, value)
        self._on_change()


def show_folder_label() -> str:
    if sys.platform == "win32":
        return "Show in Explorer"
    if sys.platform == "darwin":
        return "Show in Finder"
    return "Show in Folder"


def show_about(parent: QWidget) -> None:
    box = QMessageBox(parent)
    box.setWindowTitle("About Fanfic Engine")
    box.setText(f"Fanfic Engine {__version__}")  # macOS shows this line bold; the rest is regular text
    box.setInformativeText(
        f"<p><b>{ALPHA_NOTE}</b> This version is developed and tested on macOS only.</p>"
        "<p>Sorts your downloaded fanfiction by pairing, character and fandom. Works entirely offline: "
        "it never connects to the internet.</p>"
        "<p>MIT License. Uses Qt for Python (PySide6, LGPL-3.0) and PDFium via pypdfium2 (Apache-2.0 / BSD-3-Clause).</p>"
        "<p>Not affiliated with the Archive of Our Own or the Organization for Transformative Works.</p>"
    )
    box.exec()
