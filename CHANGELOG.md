# Changelog

## 1.1.1 — 2026-11-04

- **Security fixes** (found with a Codex Security scan, 4 November 2026): a deliberately crafted EPUB could make the app use up its memory or freeze during import, and two crafted pairing tags could freeze the app when one of them was clicked in the sidebar. No ordinary fic triggers these, and no data could leak. Now parts of an EPUB larger than 16 MB are refused before they are unpacked, at most the first 50 documents of an EPUB are read, and text and pairings are read in time proportional to their length.
- Results for real files are unchanged: the old and new code gave the same pairings, fandoms, summaries, first pages and search results for a library of 809 AO3 EPUBs.
- Windows/Linux alpha **0.1.0a2**: the same fixes (there, a part of an EPUB is also read through a size-limited stream).

## 1.1 — 2026-11-03

- **Updates inside the app:** Fanfic Engine can check for a new version and install it itself (Fanfic Engine → Check for Updates…, or once a day if you allow it; it asks on the second start). Updates come only from this project's GitHub releases and are installed only if they are signed with the project's key. This is the app's only internet connection; importing, reading and searching stay offline. Updating from 1.0 to 1.1 is by hand, once.
- **Summaries:** the details column shows each fic's summary, as its author wrote it, above the first page. It is read once on import (in AO3 EPUBs from the section after the tags, in PDFs after the title); paragraphs are kept in EPUBs; you can select and copy it. Files without one show *No summary found*.
- On first start, a library from version 1.0 is read once more to add the summaries (a few seconds for hundreds of fanfics). IDs, pairings and fandoms stay the same; the previous `library.json` is kept as `library-v2-backup.json`. `library.json` is now version 3.
- Fixed: a thin line could run through the toolbar's **+** button when the details column was narrow.
- Fixed: the search field's text could keep the colour of the previous appearance (dark text in dark mode) after switching between light and dark mode.
- The Windows/Linux alpha is unchanged (no summaries yet).

## Windows and Linux 0.1.0a1 (alpha) — 2026-11-01

- First alpha of the Windows/Linux version (Python + Qt) in `desktop/`: the same reading rules, search, sidebar lists, Settings and library format as the Mac app, checked against the same test files.
- **Not tested on Windows or Linux** — developed and tested on macOS only. Install with `uv tool install` or `pipx` (see `desktop/README.md`).

## 1.0 — 2026-11-01

First version of **Fanfic Engine** (called *Fanfic Pairings* during development; a library from that development version is moved to the new folder automatically on first start).

- Download: `Fanfic-Engine-1.0.dmg` for macOS 15 or later, Apple Silicon and Intel (Intel built but not tested). Signed ad-hoc, not notarized: allow it once with "Open Anyway".

- Import EPUB and PDF files by drag and drop, Add Files…, the Dock icon or Finder's Open With; folders are searched, including subfolders.
- A copy of each work and of its first page (as a one-page PDF) in the library folder; an ID for every work and every first-page copy.
- Reads the Relationship and Fandom fields from the first page (AO3 layout: singular/plural labels, names broken across lines, poly pairings, friendship tags, crossovers, fields continued on the next page).
- `library.json` with the works and A–Z lists of pairings, characters and fandoms, each with work and first-page IDs.
- Search by pairing or name: order, spacing, case and accents don't matter; partial names at the start of a word.
- Sidebar with Fandoms (filter, search inside), Characters and Pairings; folded by default; click a name to open or fold.
- Settings: show/hide and sort the sidebar lists, include or leave out friendship tags, library location.
- Remove from Library, Re-read Library (IDs stay the same).
- Duplicate files (identical bytes) are not imported twice.
- Fast with big libraries (about 1 s to open and 0.03 s per search at 10,000 works).
- Fully offline: no network code, no third-party libraries.
