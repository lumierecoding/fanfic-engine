"""The outline shown while files are dragged over the window (ui-spec-desktop W10)."""

from __future__ import annotations

from PySide6.QtCore import QRectF, Qt
from PySide6.QtGui import QColor, QFont, QPainter, QPalette, QPen
from PySide6.QtWidgets import QWidget


class DropOverlay(QWidget):
    TEXT = "Drop PDFs or EPUBs to add them"

    def __init__(self, parent: QWidget):
        super().__init__(parent)
        self.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)
        self.hide()

    def cover_parent(self) -> None:
        self.setGeometry(self.parentWidget().rect())
        self.raise_()

    def paintEvent(self, event) -> None:
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        palette = self.palette()
        accent = palette.color(QPalette.ColorRole.Accent)
        painter.setPen(QPen(accent, 3))
        painter.drawRoundedRect(QRectF(self.rect()).adjusted(8 + 1.5, 8 + 1.5, -8 - 1.5, -8 - 1.5), 10, 10)

        font = QFont(self.font())
        font.setPointSizeF(font.pointSizeF() * 1.25)
        font.setBold(True)
        painter.setFont(font)
        metrics = painter.fontMetrics()
        width = metrics.horizontalAdvance(self.TEXT) + 32
        height = metrics.height() + 20
        label = QRectF((self.width() - width) / 2, (self.height() - height) / 2, width, height)
        background = QColor(palette.color(QPalette.ColorRole.Window))
        background.setAlpha(235)
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(background)
        painter.drawRoundedRect(label, height / 2, height / 2)
        painter.setPen(palette.color(QPalette.ColorRole.WindowText))
        painter.drawText(label, Qt.AlignmentFlag.AlignCenter, self.TEXT)
