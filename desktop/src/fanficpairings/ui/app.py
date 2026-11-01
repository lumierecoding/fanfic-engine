"""Start of the app: `fanfic-pairings` (or `python -m fanficpairings`).

Developer options exist for screenshots and testing; normal use needs none:

  --library-path DIR     use another library folder (never test on your real library)
  --import PATH          import a file or folder at start (repeatable)
  --search TEXT          prefill the search field
  --sidebar KIND:NAME    select a fandom, character or pairing ("fandom:Harry Potter - J. K. Rowling")
  --select-title TITLE   select a work
  --appearance light|dark
  --open-settings / --open-about / --preview-drop
  --window-size WxH
  --set KEY=VALUE        override a setting for this run (fandomsExpanded=true, sidebarSort=count, …)
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def _parse(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="fanfic-pairings", description="Sorts downloaded fanfiction by pairing (alpha).")
    parser.add_argument("--library-path", type=Path)
    parser.add_argument("--import", dest="imports", type=Path, action="append", default=[])
    parser.add_argument("--search")
    parser.add_argument("--sidebar")
    parser.add_argument("--select-title")
    parser.add_argument("--appearance", choices=["light", "dark"])
    parser.add_argument("--open-settings", action="store_true")
    parser.add_argument("--open-about", action="store_true")
    parser.add_argument("--preview-drop", action="store_true")
    parser.add_argument("--window-size")
    parser.add_argument("--set", dest="overrides", action="append", default=[])
    parser.add_argument("files", nargs="*", type=Path, help="files or folders to import (e.g. from 'Open with')")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse(sys.argv[1:] if argv is None else argv)

    from PySide6.QtCore import Qt
    from PySide6.QtWidgets import QApplication

    from ..core.library import Library
    from .main_window import MainWindow, StartOptions
    from .prefs import Prefs

    app = QApplication(sys.argv[:1])
    app.setApplicationName("Fanfic Pairings")
    app.setOrganizationName("Fanfic Pairings")
    if sys.platform.startswith("linux"):
        app.setStyle("Fusion")
    if args.appearance:
        app.styleHints().setColorScheme(Qt.ColorScheme.Dark if args.appearance == "dark" else Qt.ColorScheme.Light)

    overrides = dict(item.split("=", 1) for item in args.overrides if "=" in item)
    size = None
    if args.window_size and "x" in args.window_size:
        w, h = args.window_size.lower().split("x", 1)
        size = (int(w), int(h))
    options = StartOptions(
        imports=[*args.imports, *args.files], search=args.search, sidebar=args.sidebar, select_title=args.select_title,
        open_settings=args.open_settings, open_about=args.open_about, preview_drop=args.preview_drop, window_size=size,
    )
    window = MainWindow(Library(args.library_path), Prefs(overrides), options)
    window.show()
    return app.exec()
