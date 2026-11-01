"""Middle column (ui-spec-desktop W6, W9): the works that match, sorted by title."""

from __future__ import annotations

import html

from PySide6.QtCore import QAbstractListModel, QModelIndex, QRectF, QSize, Qt, Signal
from PySide6.QtGui import QAbstractTextDocumentLayout, QColor, QFont, QFontMetrics, QPalette, QTextDocument
from PySide6.QtWidgets import (
    QLabel, QListView, QMenu, QStackedWidget, QStyle, QStyledItemDelegate, QStyleOptionViewItem,
)

from ..core.search import SearchHit

HIT = Qt.ItemDataRole.UserRole
PAD_V, PAD_H, GAP = 6, 8, 3


class HitsModel(QAbstractListModel):
    def __init__(self):
        super().__init__()
        self.hits: list[SearchHit] = []

    def set_hits(self, hits: list[SearchHit]) -> None:
        self.beginResetModel()
        self.hits = hits
        self.endResetModel()

    def rowCount(self, parent=QModelIndex()) -> int:
        return 0 if parent.isValid() else len(self.hits)

    def data(self, index: QModelIndex, role=Qt.ItemDataRole.DisplayRole):
        if not index.isValid():
            return None
        hit = self.hits[index.row()]
        if role == Qt.ItemDataRole.DisplayRole:
            return hit.work.title
        if role == HIT:
            return hit
        return None


def _solid(color: QColor, background: QColor) -> QColor:
    """The colour as it looks on the background. System greys are often black or white with transparency, and
    rich text ignores the transparency, so it is blended here."""
    a = color.alphaF()
    if a >= 1:
        return color
    return QColor.fromRgbF(color.redF() * a + background.redF() * (1 - a), color.greenF() * a + background.greenF() * (1 - a),
                           color.blueF() * a + background.blueF() * (1 - a))


class HitDelegate(QStyledItemDelegate):
    """Bold title; one grey "KIND · author · fandom" line cut off with "…"; wrapped relationships with matches
    in the accent colour and bold (only bold while the row is selected)."""

    def _relationships_doc(self, hit: SearchHit, font: QFont, width: float, palette: QPalette, selected: bool,
                           group: QPalette.ColorGroup = QPalette.ColorGroup.Active) -> QTextDocument:
        background = palette.color(group, QPalette.ColorRole.Highlight if selected else QPalette.ColorRole.Base)
        secondary = _solid(palette.color(group, QPalette.ColorRole.HighlightedText if selected else QPalette.ColorRole.PlaceholderText), background)
        accent = _solid(palette.color(group, QPalette.ColorRole.HighlightedText if selected else QPalette.ColorRole.Accent), background)
        if hit.work.relationships:
            parts = []
            for tag in hit.work.relationships:
                if tag in hit.matched:
                    parts.append(f'<span style="color:{accent.name()}; font-weight:600">{html.escape(tag)}</span>')
                else:
                    parts.append(html.escape(tag))
            body = ", ".join(parts)
        else:
            body = "<i>No pairing found</i>"
        doc = QTextDocument()
        doc.setDocumentMargin(0)
        doc.setDefaultFont(font)
        doc.setHtml(f'<div style="color:{secondary.name()}">{body}</div>')  # Qt ignores a colour on <body>
        doc.setTextWidth(max(width, 50))
        return doc

    @staticmethod
    def _meta_line(hit: SearchHit) -> str:
        parts = [hit.work.kind.upper(), hit.work.author, ", ".join(hit.work.fandoms) if hit.work.fandoms else None]
        return " · ".join(p for p in parts if p)

    def sizeHint(self, option: QStyleOptionViewItem, index: QModelIndex) -> QSize:
        hit: SearchHit = index.data(HIT)
        width = option.rect.width() or 400
        title_font = QFont(option.font)
        title_font.setBold(True)
        doc = self._relationships_doc(hit, option.font, width - 2 * PAD_H, option.palette, False)
        height = PAD_V + QFontMetrics(title_font).height() + GAP + QFontMetrics(option.font).height() + GAP \
            + doc.size().height() + PAD_V
        return QSize(width, int(height) + 1)

    def paint(self, painter, option: QStyleOptionViewItem, index: QModelIndex) -> None:
        hit: SearchHit = index.data(HIT)
        opt = QStyleOptionViewItem(option)
        self.initStyleOption(opt, index)
        opt.text = ""
        style = opt.widget.style() if opt.widget else None
        if style:
            style.drawControl(QStyle.ControlElement.CE_ItemViewItem, opt, painter, opt.widget)
        selected = bool(option.state & QStyle.StateFlag.State_Selected)
        palette = option.palette
        # Colours of the active or inactive set, matching the selection background the style just drew.
        group = QPalette.ColorGroup.Active if option.state & QStyle.StateFlag.State_Active else QPalette.ColorGroup.Inactive
        text_color = palette.color(group, QPalette.ColorRole.HighlightedText if selected else QPalette.ColorRole.Text)
        secondary = palette.color(group, QPalette.ColorRole.HighlightedText if selected else QPalette.ColorRole.PlaceholderText)
        rect = option.rect.adjusted(PAD_H, PAD_V, -PAD_H, -PAD_V)

        painter.save()
        title_font = QFont(option.font)
        title_font.setBold(True)
        painter.setFont(title_font)
        painter.setPen(text_color)
        title_metrics = QFontMetrics(title_font)
        painter.drawText(rect.x(), rect.y() + title_metrics.ascent(),
                         title_metrics.elidedText(hit.work.title, Qt.TextElideMode.ElideRight, rect.width()))
        y = rect.y() + title_metrics.height() + GAP

        painter.setFont(option.font)
        painter.setPen(secondary)
        metrics = QFontMetrics(option.font)
        painter.drawText(rect.x(), y + metrics.ascent(),
                         metrics.elidedText(self._meta_line(hit), Qt.TextElideMode.ElideRight, rect.width()))
        y += metrics.height() + GAP

        doc = self._relationships_doc(hit, option.font, rect.width(), palette, selected, group)
        painter.translate(rect.x(), y)
        context = QAbstractTextDocumentLayout.PaintContext()
        context.clip = QRectF(0, 0, rect.width(), doc.size().height())
        doc.documentLayout().draw(painter, context)
        painter.restore()


class WorksList(QStackedWidget):
    work_selected = Signal(object)  # work ID or None
    action = Signal(str, str)  # ("open" | "firstPage" | "show" | "remove", work ID)

    def __init__(self, show_label: str):
        super().__init__()
        self._show_label = show_label
        self.model = HitsModel()
        self.view = QListView()
        self.view.setModel(self.model)
        self.view.setItemDelegate(HitDelegate(self.view))
        self.view.setVerticalScrollMode(QListView.ScrollMode.ScrollPerPixel)
        self.view.setResizeMode(QListView.ResizeMode.Adjust)
        self.view.setLayoutMode(QListView.LayoutMode.Batched)
        self.view.setBatchSize(200)
        self.view.setWordWrap(True)
        self.view.setFrameShape(QListView.Shape.NoFrame)
        self.view.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.view.customContextMenuRequested.connect(self._menu)
        self.view.selectionModel().currentChanged.connect(self._current_changed)
        self.empty = QLabel()
        self.empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.empty.setWordWrap(True)
        self.empty.setMargin(24)
        palette = self.empty.palette()
        palette.setColor(QPalette.ColorRole.WindowText, palette.color(QPalette.ColorRole.PlaceholderText))
        self.empty.setPalette(palette)
        self.addWidget(self.view)
        self.addWidget(self.empty)

    def set_hits(self, hits: list[SearchHit], empty_text: str, keep: str | None) -> None:
        self.model.set_hits(hits)
        if hits:
            self.setCurrentWidget(self.view)
            row = next((i for i, h in enumerate(hits) if h.work.work_id == keep), None)
            if row is not None:
                self.view.selectionModel().blockSignals(True)
                self.view.setCurrentIndex(self.model.index(row))
                self.view.selectionModel().blockSignals(False)
                self.view.scrollTo(self.model.index(row))
        else:
            self.empty.setText(empty_text)
            self.setCurrentWidget(self.empty)

    def _current_changed(self, current: QModelIndex, _previous: QModelIndex) -> None:
        hit = current.data(HIT) if current.isValid() else None
        self.work_selected.emit(hit.work.work_id if hit else None)

    def _menu(self, position) -> None:
        index = self.view.indexAt(position)
        if not index.isValid():
            return
        work_id = index.data(HIT).work.work_id
        menu = QMenu(self)
        for key, text in (("open", "Open Fanfic"), ("firstPage", "Open First Page"), ("show", self._show_label)):
            menu.addAction(text, lambda k=key: self.action.emit(k, work_id))
        menu.addSeparator()
        menu.addAction("Remove from Library…", lambda: self.action.emit("remove", work_id))
        menu.exec(self.view.viewport().mapToGlobal(position))
