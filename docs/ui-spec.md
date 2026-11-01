# Fanfic Pairings — UI spec

## Change 3 (1 November 2026): click a section name to open or fold it

- **What changes:** clicking the name of the Fandoms, Characters or Pairings section opens it if folded and folds it if open, the same as the arrow that appears on hover. The whole header line is clickable.
- **What stays the same:** how the sidebar looks (no new arrows, colours or sizes), the remembered open/closed state, everything else.
- **Files:** `SidebarView.swift`.

| # | Rule | How it is checked |
| --- | --- | --- |
| U21 | Clicking a section name toggles it open/folded; the header looks exactly as before | Screenshot compared with change 2; the click itself tested by hand |

---

## Change 2 (1 November 2026): Settings, Characters, Fandoms

### What changes visually

- **Toolbar:** a new **Settings** button (gear icon) to the right of the folder button, left of the search field.
- **Settings window (new):** the standard macOS Settings window, opened by the gear button or ⌘, (Fanfic Pairings menu → Settings…). One page with four groups:
  1. **Sidebar:** Show Pairings / Show Characters / Show Fandoms (on/off, all on by default); "Sort lists by": Name or Number of fanfics (default Name).
  2. **Relationships:** "Include friendship tags (A & B)" (default on). When off, `A & B` tags are left out of the Pairings list, and people who only appear in them are left out of Characters. Searching is not affected.
  3. **Library:** where the library folder is (selectable path), **Show in Finder**, **Re-read Library**, and the counts ("3 fanfics · 3 first pages").
  4. **Offline:** the note "Fanfic Pairings works entirely on this Mac. It never connects to the internet."
- **Sidebar, two new sections:** order is Library (All Works, No Pairing Found) → **Fandoms** → **Characters** → Pairings. Fandoms, Characters and Pairings start **folded**; each opens and closes with the standard disclosure arrow, and the app remembers which are open. The Library group at the top always stays open.
  - **Characters** = every person who appears in a **Relationship** tag (pairings `A/B` and friendships `A & B`), each listed once with the number of fanfics. This is **not** the separate `Characters:` field of the first page. Names are grouped ignoring case, accents and spacing. Alternate names stay separate entries: `Tom Riddle` and `Tom Riddle | Voldemort` are two entries, because merging them would be guessing.
  - **Fandoms** = every value of the first page's `Fandom:`/`Fandoms:` field, each listed once with the number of fanfics. Crossovers (`Fandoms: A, B`) count in both, and clicking either fandom lists them. The full tag is shown, e.g. "Harry Potter - J. K. Rowling". Files without the field (for example FicHub exports from other sites) have no fandom and appear only under All Works.
- **Clicking a character** puts the name into the search field, the same as clicking a pairing does now. Because a name search also matches names that start with it, clicking `Tom Riddle` also finds works tagged `Tom Riddle | Voldemort`, so the result count can be higher than the number next to the name. (Alternative: make character clicks an exact filter like fandoms.)
- **Clicking a fandom** filters the works list to that fandom: the search field is cleared, the subtitle reads "Marvel Cinematic Universe · 1 fanfic", and typing in the search field then searches only inside that fandom while the fandom stays selected. Clicking All Works, a pairing or a character leaves the fandom.
- **Works list row:** the second line becomes "EPUB · author · fandom" (one line, cut off at the end if too long).
- **Detail column:** a new **Fandom** row above Relationships.

### What changes on disk

- `library.json` becomes **version 2**: each work gets `fandoms`, and new top-level lists `characters`, `characterIndex`, `fandoms` and `fandomIndex` (sorted, each entry with the work IDs and first-page IDs, like `pairingIndex`).
- The first time the updated app opens a version 1 library, it re-reads all works once to fill in the fandoms. **IDs do not change**; first-page copies are rewritten with the same content.
- Settings are stored in the app's preferences on this Mac (UserDefaults). Nothing new goes online: no network code is added.

### Files

- Core: `Relationships.swift` (shared field reader for Relationship and Fandom), `WorkReader.swift`, `Models.swift`, `Library.swift`.
- App: `AppModel.swift`, `ContentView.swift`, `SidebarView.swift`, `WorkListView.swift`, `WorkDetailView.swift`, `FanficPairingsApp.swift`, new `SettingsView.swift`.
- Tests and test files: a crossover PDF (`Fandoms:` with two values), a FicHub-style EPUB (`introduction.xhtml`, no fields), tests for character and fandom grouping and for the version 1 → 2 update keeping IDs.
- `SPEC.md`, `README.md`, the gallery.

### Stays the same

Three-column layout, window size and column widths (U1–U2), colours and materials (U9), how pairings are read and searched, import, first-page copies, IDs, the Pairings section's look and click behaviour.

### Layout rules for change 2

| # | Rule | How it is checked |
| --- | --- | --- |
| U12 | Sidebar order: Library → Fandoms → Characters → Pairings; Fandoms, Characters and Pairings folded on first launch; open/closed state survives a restart; Library always open | Screenshot; restart |
| U13 | Character and fandom rows look like pairing rows: body text up to 2 lines, count right-aligned in secondary colour | Screenshot |
| U14 | Character click fills the search field with the name; the character row stays highlighted while the field shows that name | Screenshot |
| U15 | Fandom click: search field empty, fandom row highlighted, only that fandom's works listed, subtitle "<fandom> · N fanfic(s)"; typing keeps the fandom highlighted and searches inside it | Screenshots |
| U16 | Work row second line "KIND · author · fandom", one line, truncated at the end | Screenshot |
| U17 | Detail grid has a Fandom row above Relationships | Screenshot |
| U18 | Gear button between the folder button and the search field, same style as the other toolbar buttons | Screenshot |
| U19 | Settings window: standard macOS Settings window, about 480 pt wide, grouped form with the four groups above, in that order | Screenshot, light and dark |
| U20 | Hiding a section in Settings removes it from the sidebar at once; sort by Number of fanfics puts the largest counts first (ties A–Z) | Screenshots |

---

## Change 1 (1 November 2026): first version

New app, so there are no "before" pictures. The window uses standard macOS controls only; nothing custom-drawn except the drop highlight.

## What each screen shows

- **Main window, three columns** (standard macOS split view, like Mail or Notes):
  1. **Sidebar (left): pairings.** "All Works" with a count, "No Pairing Found" with a count, then a "Pairings" section: every pairing in alphabetical order, each with the number of works on the right. Clicking a pairing puts it into the search field.
  2. **Works list (middle).** One row per work: title (bold), author, a small PDF/EPUB label, and the work's relationships, with the ones that match the search shown in the accent colour. Sorted by title.
  3. **Detail (right).** The first-page copy shown as a page preview, then title, author, original file name, relationships, work ID and first-page ID (selectable text), and buttons **Open Fanfic**, **Open First Page**, **Show in Finder**.
- **Toolbar:** search field ("Search pairing, e.g. Harry/Draco"), **Add Files…** (plus icon), **Show Library in Finder** (folder icon).
- **Drag and drop:** dropping files or folders anywhere on the window imports them. While dragging, the window shows an accent-coloured outline and "Drop PDFs or EPUBs to add them".
- **Import summary sheet:** after an import, a sheet with counts (Added, No pairing found, Already in library, Could not read, Skipped), the file names under each heading, and an **OK** button.
- **Empty states:** no works yet → the middle column shows "Drop EPUB or PDF files here, or click Add Files…". No match → "No fanfics found for "<query>"". No work selected → the detail column shows "Select a fanfic".
- **Menus:** right-click on a work → Open Fanfic, Open First Page, Show in Finder, Remove from Library. File menu → Add Files… (⌘O), Re-read Library, Show Library in Finder.

## Files

`Sources/FanficPairings/` — `FanficPairingsApp.swift`, `ContentView.swift`, `SidebarView.swift`, `WorkListView.swift`, `WorkDetailView.swift`, `PDFPreview.swift`, `ImportSummaryView.swift`.

## Layout rules

| # | Rule | How it is checked |
| --- | --- | --- |
| U1 | Window opens at 1100 × 700 pt, minimum 900 × 560 pt | Window size in screenshot at 1× |
| U2 | Sidebar width 200–320 pt, default 240 pt; works list at least 320 pt; detail at least 340 pt | Column edges in screenshot |
| U3 | Sidebar is a standard source list; pairing counts right-aligned in secondary text colour | Screenshot |
| U4 | Search field sits in the toolbar, trailing edge; Add Files… and Show Library buttons to its left | Screenshot |
| U5 | Work row: title in body semibold; author, PDF/EPUB label and relationships in secondary text; row padding 6 pt top and bottom; relationships wrap, never cut off | Screenshot |
| U6 | Matching relationships drawn in the accent colour, others in secondary colour | Screenshot with a search |
| U7 | First-page preview fills the detail column's width minus 16 pt padding on each side, at least 300 pt tall, page shown whole | Screenshot |
| U8 | IDs in monospaced text, selectable | Screenshot and select test |
| U9 | Light and dark mode follow the system; only system colours and system materials (no custom glass, no custom backgrounds) | Screenshot in both modes |
| U10 | Empty-state texts centred horizontally and vertically in their column | Screenshot |
| U11 | Drop highlight: 3 pt accent-colour rounded outline (corner radius 10 pt) inset 8 pt from the window content edges | Screenshot while dragging (if it can be captured) |

## Stays the same

Nothing exists yet. Future visual changes go through this file first.
