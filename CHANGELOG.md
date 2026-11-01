# Changelog

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
