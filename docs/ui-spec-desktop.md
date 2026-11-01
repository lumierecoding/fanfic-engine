# Fanfic Engine for Windows and Linux (Alpha) — UI spec

OK'd 1 November 2026, with the alpha notice bar.

Cross-platform version in Python + Qt (PySide6), in `desktop/`. It behaves like the Mac app (same reading rules, search, lists, library folder and `library.json`) and copies its layout, with the differences Windows and Linux need. It also runs on macOS, which is where it is tested; it is **not tested on Windows or Linux** and says so.

## What it looks like

- **Window title:** "Fanfic Engine (Alpha)". Opens at 1100 × 700, minimum 900 × 560. Light or dark follows the system. Qt's standard style for each system (Windows 11 style on Windows, Fusion on Linux), only system colours.
- **Menu bar** (inside the window on Windows and Linux; the normal menu bar on macOS):
  - **File:** Add Files… (Ctrl+O), Re-read Library, Show Library Folder, Settings… (Ctrl+,), Quit (Ctrl+Q)
  - **Help:** About Fanfic Engine — version, "Alpha — not tested on Windows or Linux", "works offline", the licence and the third-party licences (Qt/PySide6 LGPL, PDFium/pypdfium2).
- **Toolbar:** on the left **Add Files** (plus icon), **Library Folder** (folder icon), **Settings** (gear icon); on the right the **search field** with the placeholder "Search pairing, e.g. Harry/Draco" and a clear button.
- **Three columns** with draggable dividers:
  1. **Sidebar:** "All Works" and "No Pairing Found" with counts, then the headings **Fandoms**, **Characters**, **Pairings** — folded at first; clicking a heading (or its arrow) opens or folds it, and the app remembers which are open. Each entry shows the name and, right-aligned in grey, the number of fanfics.
  2. **Works list:** title (bold), a grey line "EPUB · author · fandom" (one line, cut off with "…"), and the relationships in grey with the matching ones in the accent colour and bold. Sorted by title.
  3. **Details:** title, "by author", buttons **Open Fanfic**, **Open First Page**, **Show in Explorer** (Windows) / **Show in Folder** (Linux) / **Show in Finder** (macOS), the first-page picture (whole page, as wide as the column), then Fandom(s), Relationships, File, First page, Work ID and First-page ID (IDs in a monospaced font, selectable).
- **Alpha notice bar** under the toolbar, full width: "Alpha — not tested on Windows or Linux. Please report problems on the project's GitHub page." with a close button (×) on the right; closing hides it until the next start. System colours only.
- **Status bar** at the bottom: "11 fanfics", or "Harry Potter - J. K. Rowling · 3 fanfics" while a fandom is selected. (The Mac app shows this under the title.)
- **Empty states**, centred in their column: "Drop EPUB or PDF files here, or click Add Files…", "No fanfics found for “…”", "Select a fanfic".
- **Drag and drop** of files or folders anywhere on the window: an accent-coloured outline and "Drop PDFs or EPUBs to add them" while dragging.
- **Import summary** dialog after an import: the same headings and file lists as on the Mac, with an OK button.
- **Settings** dialog with the same four groups as on the Mac: Sidebar (show Fandoms / Characters / Pairings, sort by Name or Number of fanfics), Relationships (include friendship tags), Library (folder, contents, Show Folder, Re-read Library), Offline (the note).
- **Right-click** on a work: Open Fanfic, Open First Page, Show in Explorer/Folder, Remove from Library… (with a confirmation).
- **Library folder:** Windows `%APPDATA%\Fanfic Engine`, Linux `~/.local/share/Fanfic Engine` (or `$XDG_DATA_HOME`), macOS the same folder as the Mac app.

## Layout rules

| # | Rule | How it is checked (on this Mac) |
| --- | --- | --- |
| W1 | Title "Fanfic Engine (Alpha)"; 1100 × 700 at first start, minimum 900 × 560 | Screenshot, window size |
| W2 | Columns at first start: sidebar 240 (200–320), works list 420 (at least 320), details the rest (at least 340) | Screenshot |
| W3 | Toolbar: Add Files, Library Folder, Settings on the left; search field on the right with the placeholder | Screenshot |
| W4 | Sidebar order All Works, No Pairing Found, Fandoms, Characters, Pairings; the three lists folded at first; a click on a heading toggles it; state remembered | Screenshots; restart |
| W5 | Sidebar counts right-aligned in grey | Screenshot |
| W6 | Work row: bold title, one grey "KIND · author · fandom" line cut off with "…", wrapped relationships with matches in the accent colour and bold | Screenshot with a search |
| W7 | Character and pairing clicks fill the search field; a fandom click filters and keeps the search inside it; status bar shows the fandom and count | Screenshots |
| W8 | Details: buttons, whole first page as wide as the column (16 px margin), the detail rows, monospaced selectable IDs | Screenshot |
| W9 | Empty states centred | Screenshots |
| W10 | Drag outline: 3 px accent, corner radius 10, inset 8 px, with the label | Screenshot (preview option) |
| W11 | Import summary and Settings dialogs with the same content as on the Mac | Screenshots |
| W12 | Light and dark follow the system; only system colours | Screenshots in both |
| W13 | "Alpha — not tested on Windows or Linux" in the title and in About | Screenshot |
| W14 | Notice bar under the toolbar with the alpha text and a close button; closed until the next start after clicking it | Screenshot |

## Files

`desktop/src/fanficengine/ui/`: `app.py` (start, menus), `main_window.py`, `sidebar.py`, `works_list.py`, `details.py`, `dialogs.py` (import summary, settings, about), `drop_overlay.py`.

## Stays the same

The Mac app is not changed. Reading rules, search, lists and `library.json` are the same as in `SPEC.md`.
