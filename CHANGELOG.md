# Changelog

## 1.3 — 2026-11-14

- **Filter page:** click **Filter** in the sidebar to combine up to **5 tags** (a fic is shown only when it has all of them) and to **leave out** pairings, fandoms, characters and tags you don't want to see. Type the start of a word in an *Add…* field and pick a match; each choice becomes a capsule you can remove. The search field searches inside the result, and **Clear Filter** removes every choice. The filter doesn't change your library.
- **A new look:** the window uses macOS's Liquid Glass. The sidebar's rows, the works and the filter's choices sit on glass, and behind them a soft arc of shade drifts slowly under frosted glass while the app is in front. It stands still with *Reduce Motion* or in Low Power Mode. On macOS 15, where Liquid Glass doesn't exist, the app uses frosted materials instead.
- **Security fixes** (found with a Codex Security scan, 13 November 2026): a deliberately crafted EPUB could fill the memory or slow an import down, and the update feed was not signed. Now only the part of an EPUB's reading order that is read is kept, the summary is found in time proportional to the document's length, the update feed is signed with the project's key, and release notes are never loaded from anywhere else. Results for real files are unchanged (checked on a library of 729 AO3 EPUBs).
- `library.json` stays version 4: nothing is read again on the first start.
- Windows/Linux alpha **0.1.0a3**: the same EPUB fix. It doesn't have the Filter page or the new look.

## 1.2 — 2026-11-09

- **Tags:** Fanfic Engine now also reads each fic's *Additional Tags* (AO3's tropes, moods and content notes, such as Fluff, Slow Burn or Hurt/Comfort). The sidebar has a fourth list, **Tags**, with a **Search tags** field at its top to find a tag quickly among thousands; click a tag to see its fics.
- **Search by tag:** while you type in the search field, choose **Tags** in the bar under the toolbar, or start with `#` (`#slow burn`). Fics found by a tag show their matching tags in an extra line. The details column has a **Tags** row, and Settings has **Show Tags**.
- On first start, the library is read once more to find the tags (about 7 seconds for 800 fanfics). IDs, pairings, fandoms, summaries and first pages stay the same; the previous `library.json` is kept as `library-v3-backup.json`. `library.json` is now version 4.
- Fixed: in the selected row of the works list, the highlighted pairing was blue on the blue selection and hard to read. It is now bold white, and so are matching tags.
- The Windows/Linux alpha is unchanged (0.1.0a2) and doesn't read tags yet. If it saves a library made by 1.2, the tags are dropped until the Mac app reads the library again.

## 1.1.3 — 2026-11-04

- Fixed: with a mouse connected, the works list and the details column also had a grey scroll bar strip at their right edges. They now use the same thin scroll bar as the sidebar, which appears while scrolling. With a trackpad only, nothing changes.
- The Windows/Linux alpha is unchanged (0.1.0a2).

## 1.1.2 — 2026-11-04

- Fixed: with a mouse connected (or *Show scroll bars: Always*), a grey scroll bar strip with a line ran down the sidebar's right edge, next to the counts. The sidebar now always uses the thin scroll bar that appears while scrolling; the works list and details keep the system's scroll bars.
- The Windows/Linux alpha is unchanged (0.1.0a2).

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
