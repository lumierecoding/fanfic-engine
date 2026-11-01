"""Draws plain text onto one A4 PDF page with Qt (the EPUB first-page copy).

The first line is the heading unless it is a "Label: value" line; labels are bold. Text that does not fit is cut off,
because this is the first page only. The HTML is built here from escaped text, so nothing can be loaded from anywhere.
"""

from __future__ import annotations

import html
import os
import re
import threading

_LABEL = re.compile(r"^([^\W\d_](?:[^\W\d_]| ){0,30}:)(.*)$")  # letters and spaces, then ":" (as in the Mac app)
_app_lock = threading.Lock()
_app = None


def _ensure_gui_application() -> None:
    """Qt needs an application object for fonts. The window creates one; tests and scripts get an offscreen one."""
    global _app
    from PySide6.QtGui import QGuiApplication

    with _app_lock:
        if QGuiApplication.instance() is None:
            os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
            _app = QGuiApplication([])


def _markup(text: str) -> str:
    parts = []
    for index, line in enumerate(text.split("\n")):
        match = _LABEL.match(line)
        if index == 0 and match is None:
            parts.append(f'<p style="font-size:17pt; font-weight:bold; margin:0 0 4pt 0">{html.escape(line)}</p>')
        elif match is not None:
            parts.append(f'<p style="margin:0"><b>{html.escape(match.group(1))}</b>{html.escape(match.group(2))}</p>')
        else:
            parts.append(f'<p style="margin:0">{html.escape(line)}</p>')
    return "".join(parts)


def pdf_from_text(text: str) -> bytes:
    _ensure_gui_application()
    from PySide6.QtCore import QBuffer, QByteArray, QIODevice, QMarginsF, QRectF
    from PySide6.QtGui import QFont, QPageLayout, QPageSize, QPainter, QPdfWriter, QTextDocument

    data = QByteArray()
    buffer = QBuffer(data)
    buffer.open(QIODevice.OpenModeFlag.WriteOnly)
    writer = QPdfWriter(buffer)
    writer.setResolution(72)  # 1 unit = 1 point
    writer.setPageLayout(QPageLayout(QPageSize(QPageSize.PageSizeId.A4), QPageLayout.Orientation.Portrait,
                                     QMarginsF(56, 56, 56, 56), QPageLayout.Unit.Point))
    writer.setCreator("Fanfic Pairings")

    document = QTextDocument()
    document.setDocumentMargin(0)
    font = QFont()
    font.setPointSizeF(11)
    document.setDefaultFont(font)
    document.setHtml(_markup(text))

    painter = QPainter(writer)
    area = writer.pageLayout().paintRect(QPageLayout.Unit.Point)
    document.setTextWidth(area.width())
    document.drawContents(painter, QRectF(0, 0, area.width(), area.height()))
    painter.end()
    buffer.close()
    return bytes(data.data())
