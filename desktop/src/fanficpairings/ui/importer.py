"""Reads files in a background thread; the window applies the results on the main thread.

Reading (PDF text, unzipping, drawing first pages) happens off the main thread so the window stays responsive;
only the main thread changes the library.
"""

from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QObject, QThread, Signal, Slot

from ..core import reader


class _Worker(QObject):
    file_read = Signal(object, object, object, object)  # tag, path, PreparedWork or None, error text or None
    finished = Signal()

    def __init__(self, jobs: list[tuple[object, Path]]):
        super().__init__()
        self._jobs = jobs
        self._stop = False

    @Slot()
    def run(self) -> None:
        for tag, path in self._jobs:
            if self._stop:
                break
            try:
                self.file_read.emit(tag, path, reader.read(path), None)
            except (reader.ReadError, OSError) as error:
                self.file_read.emit(tag, path, None, str(error))
            except Exception as error:  # a damaged file must never stop the whole import
                self.file_read.emit(tag, path, None, f"could not be read ({type(error).__name__})")
        self.finished.emit()

    def stop(self) -> None:
        self._stop = True


class BackgroundReader(QObject):
    """Runs one batch of reads; emits `file_read` per file and `finished` at the end."""

    file_read = Signal(object, object, object, object)
    finished = Signal()

    def __init__(self, jobs: list[tuple[object, Path]], parent: QObject | None = None):
        super().__init__(parent)
        self._thread = QThread()
        self._worker = _Worker(jobs)
        self._worker.moveToThread(self._thread)
        self._thread.started.connect(self._worker.run)
        self._worker.file_read.connect(self.file_read)
        self._worker.finished.connect(self._done)

    def start(self) -> None:
        self._thread.start()

    def _done(self) -> None:
        self._thread.quit()
        self._thread.wait()
        self.finished.emit()

    def stop(self) -> None:
        self._worker.stop()
        self._thread.quit()
        self._thread.wait()
