"""Left column (ui-spec-desktop W4, W5): All Works, No Pairing Found, then Fandoms, Characters and Pairings.

The three lists start folded; clicking a heading opens or folds it, and the open/closed state is remembered.
A list's entries are only created when it is opened, so huge lists cost nothing while folded.
"""

from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QPalette
from PySide6.QtWidgets import QAbstractItemView, QHeaderView, QTreeWidget, QTreeWidgetItem

from ..core.library import Library
from .prefs import Prefs

KIND, KEY = Qt.ItemDataRole.UserRole, Qt.ItemDataRole.UserRole + 1
SECTIONS = (  # kind, heading, show-setting, expanded-setting
    ("fandom", "Fandoms", "showFandoms", "fandomsExpanded"),
    ("character", "Characters", "showCharacters", "charactersExpanded"),
    ("pairing", "Pairings", "showPairings", "pairingsExpanded"),
)


class Sidebar(QTreeWidget):
    selection_changed = Signal(object)  # (kind, key): ("all", None), ("noPairing", None), ("fandom", key), …

    def __init__(self, library: Library, prefs: Prefs):
        super().__init__()
        self._library, self._prefs = library, prefs
        self._filled: set[str] = set()
        self._selection: tuple[str, str | None] | None = ("all", None)
        self.setColumnCount(2)
        self.setHeaderHidden(True)
        self.header().setStretchLastSection(False)
        self.header().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.header().setSectionResizeMode(1, QHeaderView.ResizeMode.ResizeToContents)
        self.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.setTextElideMode(Qt.TextElideMode.ElideRight)
        self.setIndentation(14)
        self.setUniformRowHeights(True)
        self.setFrameShape(QTreeWidget.Shape.NoFrame)
        self.itemClicked.connect(self._clicked)
        self.itemExpanded.connect(self._expanded)
        self.itemCollapsed.connect(self._collapsed)
        self.rebuild()

    # ------------------------------------------------------------ building

    def _count_item(self, item: QTreeWidgetItem, count: int) -> None:
        item.setText(1, str(count))
        item.setTextAlignment(1, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        item.setForeground(1, self.palette().color(QPalette.ColorRole.PlaceholderText))

    def rebuild(self) -> None:
        """Rebuilds everything (after the library or the settings changed), keeping open lists open."""
        self.blockSignals(True)
        self.clear()
        self._filled.clear()
        library = self._library
        for kind, text, count in (("all", "All Works", len(library.works)),
                                  ("noPairing", "No Pairing Found", len(library.works_without_pairing))):
            item = QTreeWidgetItem(self, [text])
            item.setData(0, KIND, kind)
            self._count_item(item, count)
        for kind, heading, show_key, expanded_key in SECTIONS:
            if not self._prefs.get(show_key):
                continue
            section = QTreeWidgetItem(self, [heading])
            section.setData(0, KIND, "section:" + kind)
            font = section.font(0)
            font.setBold(True)
            font.setPointSizeF(font.pointSizeF() * 0.92)
            section.setFont(0, font)
            section.setForeground(0, self.palette().color(QPalette.ColorRole.PlaceholderText))
            section.setFlags(Qt.ItemFlag.ItemIsEnabled)
            section.setChildIndicatorPolicy(QTreeWidgetItem.ChildIndicatorPolicy.ShowIndicator)
            section.setToolTip(0, f"Click to open or fold {heading}")
            if self._prefs.get(expanded_key):
                self._fill(section)
                section.setExpanded(True)
        self.blockSignals(False)
        self.show_selection(self._selection)

    def _groups(self, kind: str):
        sort, friends = self._prefs.get("sidebarSort"), self._prefs.get("includeFriendships")
        if kind == "fandom":
            return self._library.fandom_list(sort)
        if kind == "character":
            return self._library.character_list(friends, sort)
        return self._library.pairing_list(friends, sort)

    def _fill(self, section: QTreeWidgetItem) -> None:
        kind = section.data(0, KIND).split(":", 1)[1]
        if kind in self._filled:
            return
        self._filled.add(kind)
        children = []
        for group in self._groups(kind):
            child = QTreeWidgetItem([group.display])
            child.setData(0, KIND, kind)
            child.setData(0, KEY, group.key)
            child.setToolTip(0, group.display)
            self._count_item(child, len(group.work_ids))
            children.append(child)
        section.addChildren(children)

    # ------------------------------------------------------------ clicks

    def _section_of(self, kind: str):
        return next((self.topLevelItem(i) for i in range(self.topLevelItemCount())
                     if self.topLevelItem(i).data(0, KIND) == "section:" + kind), None)

    def _clicked(self, item: QTreeWidgetItem, column: int) -> None:
        kind = item.data(0, KIND)
        if kind.startswith("section:"):
            item.setExpanded(not item.isExpanded())  # a click on the heading opens or folds the list
            self.show_selection(self._selection)
            return
        self._selection = (kind, item.data(0, KEY))
        self.selection_changed.emit(self._selection)

    def _expanded(self, item: QTreeWidgetItem) -> None:
        kind = item.data(0, KIND)
        if kind.startswith("section:"):
            self._fill(item)
            self._prefs.set(dict((k, e) for k, _, _, e in SECTIONS)[kind.split(":", 1)[1]], True)
            self.show_selection(self._selection)

    def _collapsed(self, item: QTreeWidgetItem) -> None:
        kind = item.data(0, KIND)
        if kind.startswith("section:"):
            self._prefs.set(dict((k, e) for k, _, _, e in SECTIONS)[kind.split(":", 1)[1]], False)

    def show_selection(self, selection: tuple[str, str | None] | None) -> None:
        """Highlights the entry for `selection` (or nothing) without emitting a change."""
        self._selection = selection
        self.blockSignals(True)
        self.clearSelection()
        if selection is not None:
            kind, key = selection
            if kind in ("all", "noPairing"):
                target = next((self.topLevelItem(i) for i in range(self.topLevelItemCount())
                               if self.topLevelItem(i).data(0, KIND) == kind), None)
            else:
                section = self._section_of(kind)
                target = None
                if section is not None and section.isExpanded():
                    target = next((section.child(i) for i in range(section.childCount())
                                   if section.child(i).data(0, KEY) == key), None)
            if target is not None:
                target.setSelected(True)
                self.setCurrentItem(target)
        self.blockSignals(False)

    def display_name(self, kind: str, key: str) -> str | None:
        return next((g.display for g in self._groups(kind) if g.key == key), None)
