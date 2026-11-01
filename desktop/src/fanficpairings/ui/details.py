"""Right column (ui-spec-desktop W8): buttons, the first-page picture and the work's details with both IDs."""

from __future__ import annotations

import pypdfium2 as pdfium
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QFontDatabase, QImage, QPalette, QPixmap
from PySide6.QtWidgets import (
    QGridLayout, QHBoxLayout, QLabel, QPushButton, QScrollArea, QSizePolicy, QStackedWidget, QVBoxLayout, QWidget,
)

from ..core.library import Library
from ..core.models import WorkRecord

MARGIN = 16


def _render_first_page(path) -> QImage | None:
    try:
        document = pdfium.PdfDocument(str(path))
    except (pdfium.PdfiumError, OSError):
        return None
    try:
        page = document[0]
        width, height = page.get_size()
        bitmap = page.render(scale=1600 / max(width, height), rev_byteorder=True)  # RGB
        image = QImage(bytes(bitmap.buffer), bitmap.width, bitmap.height, bitmap.stride, QImage.Format.Format_RGB888)
        return image.copy()
    finally:
        document.close()


class _Preview(QLabel):
    """The whole first page, as wide as the column."""

    def __init__(self):
        super().__init__()
        self._pixmap: QPixmap | None = None
        self.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Fixed)
        self.setAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignTop)
        self.setStyleSheet("border: 1px solid palette(mid);")

    def set_image(self, image: QImage | None) -> None:
        self._pixmap = QPixmap.fromImage(image) if image is not None else None
        self._scale()

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        self._scale()

    def _scale(self) -> None:
        if self._pixmap is None:
            self.clear()
            self.setFixedHeight(300)
            return
        width = max(self.width(), 100)
        scaled = self._pixmap.scaledToWidth(width - 2, Qt.TransformationMode.SmoothTransformation)
        self.setFixedHeight(scaled.height() + 2)
        self.setPixmap(scaled)


class Details(QStackedWidget):
    action = Signal(str, str)  # ("open" | "firstPage" | "show", work ID)

    def __init__(self, library: Library, show_label: str):
        super().__init__()
        self._library = library
        self._work_id: str | None = None
        self._image_cache: dict[str, QImage | None] = {}

        self.placeholder = QLabel("Select a fanfic")
        self.placeholder.setAlignment(Qt.AlignmentFlag.AlignCenter)
        palette = self.placeholder.palette()
        palette.setColor(QPalette.ColorRole.WindowText, palette.color(QPalette.ColorRole.PlaceholderText))
        self.placeholder.setPalette(palette)

        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(MARGIN, MARGIN, MARGIN, MARGIN)
        layout.setSpacing(10)
        self.title = QLabel()
        font = self.title.font()
        font.setPointSizeF(font.pointSizeF() * 1.45)
        font.setBold(True)
        self.title.setFont(font)
        self.title.setWordWrap(True)
        self.title.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        self.author = self._secondary(QLabel())
        layout.addWidget(self.title)
        layout.addWidget(self.author)

        buttons = QHBoxLayout()
        for key, text in (("open", "Open Fanfic"), ("firstPage", "Open First Page"), ("show", show_label)):
            button = QPushButton(text)
            button.clicked.connect(lambda _=False, k=key: self._work_id and self.action.emit(k, self._work_id))
            buttons.addWidget(button)
        buttons.addStretch(1)
        layout.addLayout(buttons)

        self.preview = _Preview()
        layout.addWidget(self.preview)

        self.grid = QGridLayout()
        self.grid.setHorizontalSpacing(12)
        self.grid.setVerticalSpacing(8)
        self.grid.setColumnStretch(1, 1)
        layout.addLayout(self.grid)
        layout.addStretch(1)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setWidget(content)
        self.addWidget(self.placeholder)
        self.addWidget(scroll)

    @staticmethod
    def _secondary(label: QLabel) -> QLabel:
        palette = label.palette()
        palette.setColor(QPalette.ColorRole.WindowText, palette.color(QPalette.ColorRole.PlaceholderText))
        label.setPalette(palette)
        return label

    def _row(self, row: int, name: str, value: str, mono: bool = False, italic: bool = False) -> None:
        label = self._secondary(QLabel(name))
        label.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignTop)
        text = QLabel(value)
        text.setWordWrap(True)
        text.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        if mono:
            text.setFont(QFontDatabase.systemFont(QFontDatabase.SystemFont.FixedFont))
        if italic:
            font = text.font()
            font.setItalic(True)
            text.setFont(font)
            self._secondary(text)
        self.grid.addWidget(label, row, 0)
        self.grid.addWidget(text, row, 1)

    def forget(self) -> None:
        self._image_cache.clear()

    def show_work(self, work: WorkRecord | None) -> None:
        self._work_id = work.work_id if work else None
        if work is None:
            self.setCurrentWidget(self.placeholder)
            return
        self.title.setText(work.title)
        self.author.setText(f"by {work.author}" if work.author else "")
        self.author.setVisible(bool(work.author))
        if work.first_page_id not in self._image_cache:
            self._image_cache[work.first_page_id] = _render_first_page(self._library.path(work.first_page_file))
        self.preview.set_image(self._image_cache[work.first_page_id])

        while self.grid.count():
            item = self.grid.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        rows = [
            ("Fandoms" if len(work.fandoms) > 1 else "Fandom", "\n".join(work.fandoms) or "No fandom found", False, not work.fandoms),
            ("Relationships", "\n".join(work.relationships) or "No pairing found", False, not work.relationships),
            ("File", work.original_file_name, False, False),
            ("First page", work.first_page_source, False, False),
            ("Work ID", work.work_id, True, False),
            ("First-page ID", work.first_page_id, True, False),
        ]
        for i, (name, value, mono, italic) in enumerate(rows):
            self._row(i, name, value, mono, italic)
        self.setCurrentIndex(1)
