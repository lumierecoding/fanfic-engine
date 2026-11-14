# Fanfic Engine — UI spec

## Change 17 (13 November 2026, the owner: "lets make the Veil one the standard please."; built along this spec): Veil as the standard aura

- **What changes:** the window's aura (change 16) shows **Veil** instead of Ridge, in light and dark: a soft arc of the appearance's ink colour across its ground colour (dark grey on light, a pale glow on dark), behind the same matte glass and grain. It drifts, stands still and pauses exactly as Ridge did.
- **Ridge** stays in the app as a developer option (`-aura ridge`); `-aura off` still shows the window background as before change 16. No Settings choice (the owner OK'd change 16 without one).
- **Stays the same:** everything else in change 16: the shaders, the glass, the motion rules, where the aura is drawn.
- **Files:** `Aura.swift` (the default), `docs/USER_MANUAL.md` §3, `docs/DEVELOPMENT.md`.

| # | Rule | How it is checked |
| --- | --- | --- |
| U98 | Without a developer option the window shows Veil, light and dark; `-aura ridge` shows Ridge; `-aura off` the background as before | Captures |
| U99 | Text on cards, panels and empty states stays readable over the Veil arc, light and dark; it drifts while the window is in front | Captures, zoomed; two captures 8 s apart |

---

## Change 16 (13 November 2026, the owner: "look at the fanfiction website and how it does its background. can you implement it in the app?"; built along this spec; OK'd as built by the owner 13 November): the website's aura behind the window

- **The website's background** (`Fanfiction Website/startseite`): a WebGL2 "aura" drawn in two passes, a soft colour field at a reduced resolution and then film grain. The start page shows it clear; every content page (`data-aura="matt"`, `aura.js`) puts it behind a layer of matte glass: blurred, each pixel scattered a little, tinted toward the ground colour, a faint milky haze and a fixed frost texture. Two variants: **Ridge** (default; an amber ridge under an ultramarine sky, a night picture that stays dark in the light theme) and **Veil** (a soft ink arc on the ground). It drifts slowly; the grain flickers 12 times a second; it stands still with reduced motion.
- **What changes:** the app's window background is that aura, as on the site's content pages (matte glass), ported to Metal with the site's formulas and colour tokens. It runs unbroken behind the sidebar, the works list (between the glass cards) and the details column; the toolbar, sidebar, cards and panels are glass over it.
  - **Ridge** in both appearances; in light appearance the matte glass is tinted toward the light ground (as on the site). Since change 17 the standard is Veil, and Ridge a developer option.
  - **Motion:** drifts slowly, 15 frames a second; stands still with Reduce Motion or Low Power Mode; pauses while the window is hidden or another app is in front, and goes on from where it stopped.
  - **No Metal:** the system's window colour, as before (the site keeps its page colour without WebGL2).
- **Not built (the owner OK'd it as built without them, 13 November):** a choice in Settings (Ridge / Veil / Off), the site's *Step* motion, the aura in the Settings window and sheets. `-aura veil|off` (developer option) shows the other variant or the old background.
- **Stays the same:** every control, text, layout and glass shape of changes 13–15; Settings, sheets and alerts keep the system's background.
- **Files:** `Aura.swift` (new), `ContentView.swift` (`auraWindowBackground`), `WorkListView.swift` and `SidebarView.swift` (lists without their own background while the aura is on).
- **Checked (13 November):** test copy, light and dark, Ridge and Veil, next to the site; still and moving; 10,000 works with an idle window. Then with 10,000 works and the window in front, the aura moving (two captures 10 s apart differ): scrolling the list by scroll-bar steps and opening Fandoms, 10 s each, app CPU 8.3 % on average with the aura and 6.4 % without (GPU 45.0 % and 43.3 %), about the same 2 points as with an idle window; a selected fanfic in the active window; the title over scrolled rows readable in light and dark; a live resize by the window corner from 1300 × 820 down to the smallest window (900 × 612 with the toolbar), drawn at the new size and still drifting; a large window (2400 × 1340). A first scrolling run with the window behind Claude's had the aura paused (the captures were identical) and was not counted. **Open:** the system's Reduce Motion and Low Power Mode (the owner's settings); macOS 15.

| # | Rule | How it is checked |
| --- | --- | --- |
| U92 | The aura fills the window behind the sidebar, the works list and the details column, unbroken across the columns; glass shapes show it through | Captures, light and dark |
| U93 | Colours, band and grain match the site's content pages side by side, light and dark | Captures next to `works-search.html` from a scratch copy |
| U94 | `-aura veil` shows the Veil variant; `-aura off` the window background as before | Captures |
| U95 | Drifts while the window is in front; stands still with Reduce Motion and Low Power Mode; pauses while hidden or in the background | Two captures 8 s apart; app CPU with `-reduceMotion YES`; occluded test copy |
| U96 | With 10,000 works and the window in front, the moving aura costs at most about 2 % of one core and adds no visible GPU load; nothing when still | `ps` and the GPU's utilisation over 20 s, aura off vs on |
| U97 | Text on cards, panels and empty states stays readable over the aura, also over the amber band; `-noGlass` shows frosted panels over it | Captures, zoomed |

---

## Change 15 (12 November 2026, the owner after change 14: "everywhere"; built along this spec; OK'd and installed 13 November): glass on everything

- **What changes:** after change 14 some places still had no glass of the app's own; now they do:
  - **Sidebar:** every row (All Works, No Pairing Found, Filter and every fandom, character, pairing and tag) on a glass pill as wide, tall and round as the sidebar's selection; the selected row keeps the system's selection.
  - **Details column:** the title, author and buttons on their own glass panel, above the summary, first page and details panels.
  - **Filter page:** the choices on a glass panel.
  - **Settings:** each group (Sidebar, Relationships, Library, Updates) on a glass panel with the same switches (compact, as before), picker, buttons (now glass buttons) and notes; the window is no longer the system's form.
  - **Import summary:** each result group on a glass panel, OK as a prominent glass button.
- **Stays the same:** what every control does, texts, the layout of the three columns, the toolbar, sheets and alerts (system).
- **Rule changed:** U19 (Settings: the system's form → glass panels with the same contents).
- **Files:** `Glass.swift` (`glassRowBackground`), `SidebarView.swift`, `WorkDetailView.swift`, `WorkListView.swift`, `SettingsView.swift`, `ImportSummaryView.swift`.

| # | Rule | How it is checked |
| --- | --- | --- |
| U87 | Sidebar rows on glass pills inside the whole row: 10 pt in from the sides like the selection, 4 pt between every two pills, one-line or two-line (fixed 13 November after the owner's report: pills sized from the text had 8 pt gaps between one-line rows and almost none beside two-line rows) | Captures with one- and two-line rows, light and dark |
| U88 | Details header (title, author, buttons) on a glass panel | Captures |
| U89 | Filter choices on a glass panel; the result list and the half-height limit (U69) unchanged | Captures |
| U90 | Settings groups on glass panels; compact switches; every setting works as before | Captures, light and dark |
| U91 | Import summary groups on glass panels, none cut off at the scroll view's edges; OK prominent | Capture after an import |

---

## Change 14 (12 November 2026, the owner after change 13: "I'm not happy. I wanted liquid glass elements everywhere, not just in the filter section..."; built along this spec; installed with change 15): glass on the content too

- **What changes:** change 13 kept glass on the controls only (Apple's guidance, U74). The owner wants glass everywhere, so the content gets it too:
  - **Works list:** every fanfic on its own glass card, as wide and as round as the system's selection; no separator lines; the selected fanfic keeps the system's blue selection; the cards light up under the pointer.
  - **Details column:** the summary, the first page (now with rounded corners) and the details grid each on a glass panel; the title, author and glass buttons stay above them.
  - **Empty states** ("Select a fanfic", "No fanfics found for …", "No fanfics yet", "Every fanfic has a pairing", "No fanfics match this filter") on a glass card in the middle of their column.
  - **Sidebar:** the Search tags field is a glass pill like the Filter page's fields.
- **Stays the same:** layouts, columns, text, the toolbar and sidebar (system glass), the Filter page, animations, Settings and sheets.
- **Rule replaced:** U74 ("content stays plain").
- **Files:** `Glass.swift` (`glassPanel`, `glassEmptyState`), `WorkListView.swift`, `WorkDetailView.swift`, `PDFPreview.swift`, `SidebarView.swift`.
- **Checked:** test copy, light and dark, demo library and 10,000 made-up works.

| # | Rule | How it is checked |
| --- | --- | --- |
| U82 | Works list: each fanfic on a glass card with the selection's width and corner radius; no separator lines; the selected fanfic in the system's blue | Captures, light and dark, a selected row |
| U83 | Details: summary, first page (rounded corners) and details grid on glass panels, as wide as the button row | Captures, also scrolled to the grid |
| U84 | Every empty state on a glass card in the middle of its column | Captures with no result and no selection |
| U85 | The sidebar's Search tags field is a glass pill | Capture with the Tags list open |
| U86 | With 10,000 works the glass cards keep scrolling, switching and searching smooth | Test copy on the 10,000-work library |

---

## Change 13 (12 November 2026, the owner's goal; advice from Fable 5.2; built along this spec; inspected and fixed in round 2; gallery OK'd by the owner on 12 November): the whole app in Liquid Glass

- **Owner request:** "make the whole app in liquid glass, with smooth transitions and animations."
- **Why the app looked old on macOS 27:** it is built with SwiftPM, which linked it without the SDK path, so the app said it was made with SDK 15.0 and macOS ran it in compatibility mode with the pre-glass look. Only the Filter page's own glass was glass.
- **What changes:**
  - **Build:** `build-app.sh` and `make-release.sh` give the linker the SDK, so the app carries the real SDK version, and stop with an error if it doesn't. On macOS 26 and later the system then draws its Liquid Glass by itself: the floating glass sidebar, toolbar buttons in a glass group, the glass search field, the new buttons, sheets, Settings, alerts and window corners.
  - **Title band:** the app's own band (change 4) and the hidden system band go; the system's glass toolbar and its scroll-edge effect take their place. The step at the sidebar divider and the line through the toolbar buttons (changes 4 and 6) were seen in compatibility mode only; checked again with the band gone.
  - **Toolbar:** the progress wheel during an import sits in its own toolbar item without the shared glass background, so the button group doesn't change size.
  - **Details column:** **Open Fanfic** is a prominent glass button, **Open First Page** and **Show in Finder** are glass buttons, all three in one glass group.
  - **Drop highlight:** the "Drop PDFs or EPUBs to add them" label sits on glass; the outline's corners follow the larger window corners.
  - **Filter page:** unchanged look; its glass helpers become shared by the whole app (`Glass.swift`).
  - **Content stays plain:** rows, titles, summaries, the details grid and the first-page picture are never glass, and there is no glass inside glass.
  - **Transitions and animations** (at most 0.35 s, no bounce; with *Reduce Motion* they become plain fades or nothing):
    - The details column cross-fades when another fanfic is selected; each fanfic opens at the top of its details; the first-page picture fades in when it is ready.
    - The works list cross-fades when the sidebar selection changes; typing in the search field updates it at once, without animation.
    - Sidebar lists open and fold smoothly.
    - Filter page: the suggestion panel fades and grows in from its field, "N of 5" rolls to the new number, suggestions light up under the pointer; capsules keep flowing (change 12).
    - The drop highlight fades in and out.
  - **macOS 15:** the same shapes in a frosted material and bordered buttons; the developer option `-noGlass YES` shows that look on a newer Mac.
  - **Thin scroll bars (changes 9 and 10):** in the new design the scroll views reach under the floating sidebar and the toolbar, so the fix found none of them by its left edge any more and the strips came back with *Always*; it now matches the right edge and takes the smallest scroll view that fits (U81).
- **Round 2 (owner, 12 November: "please inspect all UI details for inconsistencies or bugs and fix them"):** every screen captured in light and dark, also at the smallest window (900 × 560), with the sidebar hidden, with an empty library, with no results and with a search. Fixed:
  - In a narrow details column the glass buttons were cut short ("Open First P…", "Show in Find…"): they now go onto a second line (U72).
  - In a narrow works column the Filter heading broke onto two lines: Clear Filter then shows only its × symbol (U67).
  - Suggestions were cut in the middle in a narrow column: they now use up to two lines (U65).
  - A long capsule could stick out of a narrow column: its name is now shortened in the middle (U63, U64).
  - Checked and left as they are: the toolbar group sitting over the list/details divider (placed by the system), the drop label over an empty state (only while dragging, readable), no highlighted sidebar row during a search (as in 1.2).
- **Stays the same:** the three columns and their widths, every list, the search, the Filter page's rules, Settings' contents, the menus.
- **Rules replaced or changed:** U9 (system glass, and the app's own glass on controls only), U11 (corner radius), U22–U24 and U33 (the system's band instead of the app's), U47–U52 (checked again on the new look: still no scroll bar strips), U69 (the height of the Filter choices measured again on the new look).
- **Files:** `scripts/build-app.sh`, `scripts/make-release.sh`; Mac: `Glass.swift` (new), `ContentView.swift`, `TitleBand.swift` (removed: the check was clean), `OverlayScroller.swift`, `WorkDetailView.swift`, `WorkListView.swift`, `SidebarView.swift`, `FilterView.swift`, `PDFPreview.swift`, `FanficEngineApp.swift`.
- **Checked:** a test copy with its own bundle ID on a scratch demo library and on a scratch library of 10,000 made-up works (speed); real window captures, light and dark; *Reduce Motion*, *Reduce Transparency* and `-noGlass YES`.

| # | Rule | How it is checked |
| --- | --- | --- |
| U70 | The app carries the SDK version of the Xcode it was built with; the build stops with an error if it doesn't | `vtool -show-build` on the built app; the scripts' check |
| U71 | On macOS 26 and later the window shows the system's Liquid Glass: floating glass sidebar, toolbar buttons in a glass group, glass search field; no band drawn by the app; the title stays readable over scrolled rows; no step at the sidebar divider and no line through the toolbar buttons | Captures with the list scrolled and a narrow details column, light and dark |
| U72 | Details: Open Fanfic prominent glass, Open First Page and Show in Finder glass, one group, going onto a second line in a narrow column instead of being cut short; bordered buttons on macOS 15 | Captures, also with `-noGlass YES` |
| U73 | Drop highlight: label on glass, outline corners matching the window corners | Capture with `-previewDrop YES` |
| U74 | ~~Rows, text, the details grid and the first-page picture are plain; no glass inside glass~~ Replaced by change 14 (the owner wants glass on the content too) | Captures |
| U75 | Selecting another fanfic cross-fades the details (about 0.2 s) and shows them from the top; the first-page picture fades in | Seen in the test copy; Reduce Motion on: no movement |
| U76 | Changing the sidebar selection cross-fades the works list; typing a search updates it at once; with 10,000 works typing and scrolling stay smooth | Test copy on the 10,000-work library |
| U77 | Sidebar lists open and fold smoothly (about 0.25 s) | Seen in the test copy |
| U78 | Filter page: suggestion panel fades and grows in from its field; "N of 5" rolls; suggestions light up under the pointer; capsules flow as in change 12 | Seen in the test copy |
| U79 | *Reduce Motion*: no movement, only fades or nothing; *Reduce Transparency* and *Increase Contrast*: everything readable | The app's part with the developer option `-reduceMotion YES` (system setting untouched); the system settings themselves by the owner |
| U80 | macOS 15 look: frosted material and bordered buttons in the same places | Captures with `-noGlass YES` |
| U81 | With *Show scroll bars: Always* no scroll bar strip in sidebar, works list, details or Filter choices; the Filter choices take only their own height (at most half the column) | Captures with *Always* |

---

## Change 12 (12 November 2026, the owner's goal; built along this spec; Liquid Glass look added at the owner's request the same day; gallery OK'd by the owner on 12 November): the Filter page

Rules: `SPEC.md` section 6, **Filter**.

- **Owner request:** "new features for mac app: search for multiple (max 5) tags simultaneously. Exclude option for pairings, fandoms, characters and tags. Realise this with a dedicated filter page."
- **What changes:**
  - **Sidebar:** a third row in the first group, **Filter** (funnel symbol), under No Pairing Found. Its badge shows how many fanfics the filter lets through.
  - **Filter page:** selecting Filter turns the middle column into the filter page. The choices are at the top, with the matching fanfics in the usual list below them. The title band says "Filter · N fanfics", and the details column works as before.
    - **With all of these tags:** the chosen tags as small removable capsules, then an **Add tag…** field and "N of 5". With 5 tags the field is greyed out and says "5 tags at most".
    - **Leave out:** four rows, **Pairings**, **Fandoms**, **Characters** and **Tags**, each with its removable capsules and an **Add …** field. These capsules have a minus symbol, so they read as left out.
    - **Adding:** typing in an Add field shows up to 6 matching entries right under it, inside the page: name and number of fanfics, most fanfics first, by the word-start rule (SPEC section 6). Return adds the first entry, a click adds the one clicked, and Escape empties the field. Entries already chosen on that row are not offered. If nothing matches: "No tags match “…”" (pairings, fandoms, characters likewise).
    - **Clear Filter** button at the end of the choices; greyed out when nothing is chosen.
  - **Results:** rows as in All Works. The chosen tags a fanfic has go on its tag line (U57). With no match, "No fanfics match this filter" shows under the choices, which stay visible.
  - **Search field:** on the Filter page it searches inside the result, like a fandom. Typing doesn't leave the page.
- **Look (owner, 12 November, after the first gallery: "make the interface of the filter more modern and liquid glass please"):** the choices use macOS's Liquid Glass (macOS 26 and later; on macOS 15 the same shapes in a frosted material).
  - The two headings get a symbol: a tag for **With all of these tags**, a minus for **Leave out**.
  - Capsules are glass pills: a tag capsule is tinted in the accent colour, a left-out capsule is clear glass with a red minus symbol.
  - The Add fields are glass pills with a plus symbol instead of a boxed text field; the field with the keyboard gets an accent outline.
  - The suggestions sit on a rounded glass panel; the first one (what Return adds) is marked with an accent tint.
  - **Clear Filter** is a small glass button with an × symbol, and it moves with "N of 5" into the heading line ("With all of these tags  2 of 5 … Clear Filter"), so neither takes a line of its own and Clear Filter stays in sight when the choices scroll.
  - Adding or removing a capsule animates: the new capsule flows out of the field, a removed one melts away.
- **Stays the same:** All Works, No Pairing Found, the four lists, the search field and its Pairings | Tags scope, the details column, the toolbar, Settings, the window size and column widths.
- **Not in this change (possible later):** keeping the filter after the app is closed; "any of these tags" instead of "all"; choosing pairings, fandoms or characters that must be present (only tags for now); "Add to Filter" in the sidebar lists' right-click menu; the Windows/Linux alpha.
- **Files:** `Sources/FanficCore/Filter.swift` (the rules), `Tests/FanficCoreTests/FilterTests.swift`; Mac: `FilterView.swift` (new), `AppModel.swift`, `ContentView.swift`, `SidebarView.swift`, `WorkListView.swift`, `FanficEngineApp.swift` (developer options for pictures).
- **Checked:** a test copy with its own bundle ID (`build-app.sh --no-install`, opened with `-libraryPath` on a scratch demo library), never the installed app or the owner's library; light and dark. The first pictures were drawn by the test copy itself (developer option `-snapshotPath`), because this Mac has no Screen Recording permission for the tools; the Liquid Glass pictures are window captures made through the owner-approved control of the test copy, because glass is drawn by the system and a self-drawn picture can't show it.

| # | Rule | How it is checked |
| --- | --- | --- |
| U61 | Sidebar: **Filter** row with a funnel symbol directly under No Pairing Found in the first group, badge = number of fanfics the filter shows (all fanfics while nothing is chosen) | Screenshots with and without a filter |
| U62 | Selecting Filter shows the filter page in the middle column: the choices on top, a divider, then the result list; title band subtitle "Filter · N fanfic(s)"; details column unchanged | Screenshots, light and dark |
| U63 | **With all of these tags** row (heading with a tag symbol): accent-tinted glass capsules (tag symbol, name, × button with the label "Remove <name>"), then the Add tag… field; "N of 5" in the heading line; with 5 tags the field is disabled with "5 tags at most"; capsules wrap onto more lines instead of widening the column | Screenshots with 0, 2 and 5 tags; core test of the limit |
| U64 | **Leave out** group with four labelled rows (Pairings, Fandoms, Characters, Tags), labels right-aligned in one column, each row with clear glass capsules (red minus symbol, name, × button) and a glass Add field with a plus symbol ("Add pairing…", "Add fandom…", "Add character…", "Add tag…"); the field with the keyboard has an accent outline | Screenshot with entries in all four rows |
| U65 | Typing in an Add field shows up to 6 matching entries directly under that field on a rounded glass panel, inside the page (name and count, the first one accent-tinted, most fanfics first, word-start rule); Return adds the first, a click adds that one, Escape empties the field; already-chosen entries are not offered; no match: "No tags match “…”" (pairings, fandoms, characters likewise) | Screenshots with "fam", a pairing typed and "zzz"; core test of the ordering |
| U66 | Results as in All Works (U5, U6). The chosen tags a fanfic has are on its tag line, in the U57 colours, including on the selected row; no match: "No fanfics match this filter" under the choices, which stay visible | Screenshots, including a selected row and an empty result |
| U67 | **Clear Filter** (small glass button with an × symbol) at the right end of the first heading line removes everything; disabled when nothing is chosen | Screenshots before and after |
| U68 | On the Filter page the search field searches inside the result (like a fandom, U55), and typing keeps Filter selected | Screenshot with a search inside a filter |
| U69 | The choices take at most half the column's height and scroll inside when they need more, so the result list always shows; nothing in the other columns moves | Screenshot with many left-out entries in a 1100 × 700 window |

---

## Change 11 (9 November 2026, owner's "yes" to tags in the Mac app; built along this spec; gallery OK'd by the owner on 9 November): tags

Reading rules: `SPEC.md` section 5b.

- **Owner request:** "additionally to characters, fandoms, and relationships add a search and list for tags", then "yes" to a search inside the Tags list and "yes" to the Mac app.
- **What changes:**
  - **Sidebar:** a fourth list, **Tags**, after Pairings, folded at first like the others, with the number of fanfics per tag. When it is open, its first row is a **Search tags** field that narrows the list (start of a word: `burn` finds Slow Burn). Clicking a tag shows only its fanfics, like a fandom: the title band says "Slow Burn · 1 fanfic" and the search field searches inside it.
  - **Search field:** while it is active, macOS's scope bar offers **Pairings | Tags** under the toolbar; in Tags the prompt is "Search tags, e.g. Slow Burn". Typing `#` first searches tags in either scope (`#fluff`). Rows found by a tag get one more line: a tag symbol and the matching tags in the accent colour (bold, white when the row is selected, like U6).
  - **Details column:** a **Tags** row after Relationships: the tags as one comma-separated, wrapping, selectable line, or "No tags found".
  - **Settings:** **Show Tags** under Show Pairings.
  - **First start after the update:** the library is read once more to find the tags (progress wheel in the toolbar, Re-read Library greyed out, a few seconds); IDs and everything else stay; `library-v3-backup.json` is kept.
- **Stays the same:** the pairing search and its highlight, Characters, Fandoms, the toolbar buttons, the import summary, updates, the window layout and column widths.
- **Files:** `Sources/FanficCore` (TagParser, tags in the library file, `#` search), the tests and `Fixtures/expected.json`; Mac: `AppModel.swift`, `ContentView.swift`, `SidebarView.swift`, `WorkListView.swift`, `WorkDetailView.swift`, `SettingsView.swift`.
- **Checked:** a test copy (`build-app.sh --no-install`, opened with `-libraryPath` on a copy of the demo library), never the installed app or the owner's library; light and dark.

| # | Rule | How it is checked |
| --- | --- | --- |
| U53 | Sidebar shows **Tags** after Pairings, folded at the first start, opening by its arrow or by clicking its name (U21), remembered; rows like the other lists (name, count badge) | Screenshots folded and open, light and dark |
| U54 | The open Tags list starts with a **Search tags** row (magnifying glass, prompt "Search tags", clear button while it has text) that narrows the list by the word-start rule; "No tags match “…”" when none | Screenshots with "fam" and "zzz"; core test |
| U55 | Clicking a tag shows only its fanfics; title band subtitle "<tag> · N fanfic(s)"; the search then stays inside the tag | Screenshot |
| U56 | The active search field shows a **Pairings / Tags** scope bar; Tags prompt "Search tags, e.g. Slow Burn"; `#` at the start searches tags in either scope | Screenshots |
| U57 | Tag results: an extra callout line with a tag symbol and only the matching tags, semibold accent colour; on the selected row semibold in the row's own text colour (white on the blue selection), like U6. Fixes U6 too: in 1.1.3 on macOS 27 the matching relationships of the selected row were blue on the blue selection | Screenshots, a selected row in the active window, pairing and tag search |
| U58 | Details: **Tags** row after Relationships, label right-aligned like the others, value one comma-separated wrapping line, selectable; "No tags found" italic secondary | Screenshots with and without tags |
| U59 | Settings: **Show Tags** toggle directly under Show Pairings | Screenshot |
| U60 | A version 3 library is read once on the first start (progress wheel), tags added, IDs unchanged, `library-v3-backup.json` kept; nothing else in the window moves; light and dark | The demo copy upgraded by the test copy; before/after pictures |

---

## Change 10 (4 November 2026, asked by the owner after change 9: "now do the same to the other scroll bar"; built, shipped in 1.1.3): no scroll bar strips in the works list and details

- **Owner request:** after 1.1.2 removed the sidebar's strip, the same for the other scroll bars. With a mouse connected, the works list has the same grey strip at its right edge, and so does the details column when a fic is selected and its summary and first page are taller than the column.
- **What changes:** the works list and the details column get the same thin scroll bar as the sidebar (change 9): it floats over the column and appears while scrolling, whatever the system setting. No strips anywhere in the main window. The rows and the details use the full column width, as they already do with a trackpad.
- **Stays the same:** with a trackpad only, the window looks exactly as before. Scrolling with a mouse wheel or trackpad, and dragging a scroll bar while it shows, still work. The import summary sheet and the Settings window keep the system's scroll bars.
- **Files:** `WorkListView.swift`, `WorkDetailView.swift` (the same `OverlayScroller` as the sidebar).
- **Checked:** before/after pictures with permanent and thin scroll bars, light and dark, with a fic selected; switching the setting while open.

| # | Rule | How it is checked |
| --- | --- | --- |
| U50 | With permanent scroll bars set, the works list and the details column have no scroll bar strip or line at their right edges | Screenshots and pixel checks, light and dark, a fic selected |
| U51 | Both columns look exactly as they do with thin scroll bars; with thin scroll bars the whole window is pixel-identical to before | Pixel comparisons |
| U52 | The style holds after the setting changes while the window is open, also after selecting another fic | Setting switched while open (test copy's own setting and the system's announcement) |

---

## Change 9 (4 November 2026, bug fix; OK'd and built, shipped in 1.1.2): no scroll bar strip in the sidebar

- **Owner report** (their Mac, 1.1.1, dark mode, with a mouse): a grey strip with a line runs down the sidebar's right edge, right next to the counts (809, 227).
- **Cause:** with a mouse connected, macOS's setting *Show scroll bars: Automatically based on mouse or trackpad* (and *Always*) gives every scrolling area a permanent scroll bar in its own track. In the sidebar that track is a strip of its own between the counts and the divider. Every picture so far was taken with the thin scroll bars that only appear while scrolling (trackpad style), so the strip was never seen.
- **What changes:** the sidebar's scroll bar is always the thin kind that floats over the sidebar and appears while scrolling, whatever the system setting: no strip, no line. The rows and counts use the full sidebar width, as they already do with a trackpad.
- **Stays the same:** the works list and the details column keep the system's scroll bars (a permanent one with a mouse); with a trackpad only, the whole window looks exactly as before. Scrolling the sidebar with a mouse wheel or trackpad, and dragging its scroll bar while it shows, still work.
- **If macOS doesn't allow it:** if the sidebar keeps getting the permanent scroll bar back (it can switch styles on its own when a mouse is plugged in or out), the fallback is to hide the sidebar's scroll bar completely; scrolling with the wheel or trackpad still works. The gallery will say which one was built.
- **Files:** `SidebarView.swift` and `OverlayScroller.swift` (finds the sidebar list's scroll view and sets its style again after each system change).
- **Checked:** before/after pictures with permanent scroll bars (as on the owner's Mac) and with thin ones, light and dark; plugging a mouse in or out is simulated by switching the setting while the window is open.

| # | Rule | How it is checked |
| --- | --- | --- |
| U47 | With permanent scroll bars set (mouse connected or *Always*), the sidebar has no scroll bar strip or line at its right edge; its scroll bar floats over the sidebar while scrolling | Screenshots and a pixel check of the sidebar's right edge, light and dark |
| U48 | The counts stay right-aligned at the same place as with thin scroll bars; the sidebar still scrolls with wheel and trackpad | Before/after pictures; scrolling a long Characters list in a test copy |
| U49 | Nothing else changes: the works list and details keep the system's scroll bars, and with thin scroll bars the window is pixel-identical to before; the style holds after the setting changes while the window is open | Before/after pixel comparison; setting switched while open |

---

## Change 8 (3 November 2026, OK'd and built): updates inside the app

Owner: an update feature that installs new versions inside the app (Sparkle), asking first before checking automatically. The rules are in `SPEC.md` section 10. This part covers what you see.

### What changes visually

- **App menu (Fanfic Engine):** a new item **Check for Updates…** directly after **About Fanfic Engine**, where Mac apps usually have it.
- **Settings:** the **Offline** group (“never connects to the internet”) becomes **Updates**:
  - a switch **Check for updates automatically** (off until you say yes to the question below);
  - a line **Last checked:** with the date and time, or *Never*;
  - a button **Check Now**;
  - under it, in grey: “Fanfic Engine only connects to GitHub to look for a new version: when you click Check Now or Check for Updates, or once a day if automatic checks are on. Your fanfics and your library never leave this Mac.”
- **Sparkle's own windows** (the standard ones, with the app's icon and name; not drawn by this app):
  - on the **second start**, once: *Check for updates automatically?* with **Check Automatically** and **Don't Check**, and Sparkle's box *Automatically download and install updates* (off);
  - **A new version is available** with the version, the short notes and **Install Update** and **Skip This Version** (closing the window means later; this Sparkle version has no Remind Me Later button);
  - a download progress window, then **Install and Relaunch**;
  - **You're up to date** when you check and there is nothing new;
  - an error message if an update can't be downloaded or isn't correctly signed.

### Stays the same

The main window (sidebar, works list, details with the summary), the toolbar, the File menu, the import summary, the other Settings groups, the library and everything else.

### Not in this change (possible later)

- Updates for the Windows/Linux alpha.
- Showing “what's new” inside the app after an update.

### Files

- `Package.swift` (Sparkle, one exact version, at least 2.6.4); new `Updater.swift` (Sparkle's standard updater controller and the menu item); `FanficEngineApp.swift` (menu); `SettingsView.swift` (Updates group); `Resources/Info.plist` (`SUFeedURL`, `SUPublicEDKey`).
- `scripts/build-app.sh` and `scripts/make-release.sh` (put Sparkle into the app and sign it; sign the disk image with the update key; write `appcast.xml` for the release); a small script that makes the key once and signs files with it; Sparkle's licence in the app and the repository.
- After the gallery OK: `SPEC.md` (sections 8 and 10), `README.md` (the offline and privacy wording, download), `USER_MANUAL.md` (Settings, Privacy, a new Updates section), `CHANGELOG.md` (1.1), `docs/DEVELOPMENT.md` (Releasing), `CLAUDE.md` (the no-network rule).

### Layout rules for change 8

| # | Rule | How it is checked |
| --- | --- | --- |
| U41 | App menu: **Check for Updates…** directly after **About Fanfic Engine**; it works with or without an open window | Screenshot of the open menu; a check started from the menu |
| U42 | Settings: an **Updates** group where **Offline** was, with the switch, the *Last checked* line, **Check Now** and the grey note; the other groups unchanged | Screenshot compared with before, light and dark |
| U43 | Sparkle's windows are its standard windows with the app's icon and name, readable in light and dark | Screenshots of the question, update available, progress, up to date |
| U44 | No check before the answer: the question comes on the second start; **Don't Check** leaves the switch off and no automatic check happens | Test copy: first start, second start, network log of the test |
| U45 | The update window's notes come only from `appcast.xml`; nothing else is loaded | Test feed; the test's network log |
| U46 | The main window and the other menus don't change | Before/after pictures |

---

## Change 7 (3 November 2026, OK'd and built): the summary in the details column

Owner: "I want the summary of each fic on the details pane on the right". The reading rules are in `SPEC.md` section 5a. This part covers what you see.

### What changes visually

- **Details column (right), one new block, "Summary",** between the button row (Open Fanfic, Open First Page, Show in Finder) and the first-page picture:
  - the heading "Summary" in the same font and grey (secondary) colour as the labels under the picture (Fandom, Relationships, File …);
  - under it the summary in the normal body font and colour, using the column's full width (the same 16 pt margins as now) and wrapping; paragraphs 7 pt apart (planned 6 pt; the gap is an empty line in a tiny font so the summary stays one selectable text, and its height only goes in steps of 5 or 7 pt); the text can be selected and copied, like the other details;
  - the whole summary is shown (AO3 allows at most 1,250 characters); the column scrolls as it does now;
  - a fanfic without a summary shows "No summary found" in italic grey under the heading, like "No fandom found".
- **The first time the new version opens your library** (version 2), it reads every fanfic once more to find the summaries: the small progress wheel in the toolbar turns, as during Re-read Library, and the summaries appear as they are read (a few seconds for hundreds of fanfics).

### Stays the same

The window, toolbar, sidebar, works list and its rows; the title, author and buttons at the top of the details column; the first-page picture and the details below it (they move down by the height of the Summary block); the import summary; Settings; the library folder, IDs and first-page copies.

This build also contains the toolbar fix of change 6, which is waiting for your check on macOS 27.0.1.

### Not in this change (possible later)

- Searching inside summaries.
- Folding long summaries (the first few lines and a "More" button).
- The summary in the works list rows.
- The summary in the Windows/Linux version.
- Export (change 5) waits for its own OK and doesn't depend on this change.

### Files

- Core: new `SummaryReader.swift` (the rules of `SPEC.md` 5a); `WorkReader.swift` (looks on the first page and the next two pages or documents), `EPUBBook.swift` (a document's HTML, for the blockquote), `HTMLText.swift` (keeps paragraph breaks for summaries), `Models.swift` (`summary`, version 3), `Library.swift` (stores it; update from version 2 with the backup copy).
- App: `WorkDetailView.swift`.
- Test files: `scripts/make-fixtures.swift` and `Fixtures/expected.json` (a `summary` for each file). New files: an EPUB in AO3's layout (tags in the first document; summary blockquote with two paragraphs in the second, then Notes), the same without Notes, a PDF whose summary runs onto page 2, an inline `Summary:` line, a "Summary" chapter longer than 1,500 characters, and a file without a summary. Tests in `ReadingTests.swift` and `LibraryTests.swift` (the version 2 → 3 update keeps IDs and every other field).
- After the gallery OK: `SPEC.md`, `USER_MANUAL.md`, `README.md`, `CHANGELOG.md`.

### Layout rules for change 7

| # | Rule | How it is checked |
| --- | --- | --- |
| U35 | The Summary block sits between the button row and the first-page picture, 14 pt from each (the column's spacing now); its left edge lines up with the title and the buttons | Screenshot, pixel check |
| U36 | Heading "Summary" in the font and secondary colour of the details labels; the text in the body font and primary colour, wrapped to the column width, never cut off or shortened; paragraphs 7 pt apart (planned 6; see above) | Screenshots with a one-line, a two-paragraph and a 1,250-character summary; light and dark; narrow and wide details column |
| U37 | No summary: "No summary found" under the heading, italic and secondary, the same as "No fandom found" | Screenshot of a file without a summary |
| U38 | The summary text can be selected and copied (⌘C) | Screenshot with a selection; the copied text checked |
| U39 | Nothing else in the window changes; only the picture and the details below it move down by the block's height | Before/after pictures of all three columns, light and dark |
| U40 | Only standard macOS text styles and system colours (U9) | Screenshots in light and dark |

---

## Change 6 (2 November 2026, bug fix; shipped with change 7 in 1.1): toolbar line and search text

- **Owner report** (Mac Studio, macOS 27.0.1, dark mode): the typed search text is dark on the dark toolbar (it should be white), and a thin vertical line runs through the **+** button.
- **Cause of the line:** since change 4, the works list and the details column each drew their own band, so the divider between them ran up through the toolbar (the "known difference" in change 4). When the details column is narrow, the toolbar buttons sit over that divider. Seen here on macOS 27.2 too, with a narrow details column. Before change 4, macOS's band ran unbroken across both columns.
- **Cause of the dark text:** the toolbar search field draws its text once, in the colour of the moment, and does not redraw it when the window switches between light and dark. All its views report the new look; only the drawn text is stale. Reproduced here on macOS 27.2: a window that switches from dark to light while open keeps white text on the light field. Not caused by the app-drawn band (macOS's own band shows the same).
- **What changes:**
  - The app draws **one** band across the works list and the details column, from the sidebar divider to the window's right edge, so the divider between list and details stops at the band's bottom line again (as before change 4). Height, colour, bottom line and the sidebar corner (U22–U24) stay as they are. Still on macOS 27 and later.
  - When the window opens and after every light/dark change, the app sets the search field's text again, which makes the field draw it in the current colour. The search itself does not change; while someone is typing, the field is left alone.
- **Stays the same:** everything else, including the buttons, the search field and their places.
- **Files:** `ContentView.swift`, `TitleBand.swift`, new `SearchFieldAppearance.swift`.
- **Checked:** on macOS 27.2 here (U22–U24, U33, U34), light and dark; on macOS 27.0.1 by the owner with a test build.

| # | Rule | How it is checked |
| --- | --- | --- |
| U33 | No vertical line in the band: the list/details divider stops at the band's bottom line, also when the toolbar buttons sit above it | Screenshot and pixel check with a narrow details column, light and dark |
| U34 | The typed search text is white in dark mode and black in light mode, also after the window switches between them while open | Screenshot after a dark → light switch while open (27.2, test copy); owner on macOS 27.0.1 with the test build |

---

## Change 5 (2 November 2026, waiting for the owner's OK): export with readable file names

The naming rules and the draft list of short names are in `SPEC.md` section 9. This part covers what you see.

### What changes visually

- **File menu:** a new item **Export Shown Fanfics…** (⇧⌘E) after Add Files…. It exports what the works list shows right now (all works, one fandom, a search result, No Pairing Found). Greyed out when the list is empty.
- **Right-click a fanfic:** a new item **Export…** after Show in Finder, above a separator and Remove from Library.
- **Right-click a fandom, character or pairing in the sidebar:** a new menu with one item, **Export N Fanfics…** (N = the number next to it). Clicking the row works as before.
- **Choosing the folder:** the standard macOS folder panel with **New Folder**. Its button says **Export** and its message says "Export 12 fanfics with readable names into this folder." It opens in the folder used last time.
- **Export summary (new sheet):** looks like the import summary: counts for **Exported**, **Already in folder** and **Could not copy**, the new file names under each heading, and the buttons **Show in Finder** and **OK** (default).
- **Settings, new group "File names"** between Relationships and Library:
  - an example line, e.g. "HP - Harry x Draco - The Quiet Winter.pdf", for the selected fanfic (or the first one in the library);
  - a button **Fandom Short Names…**, which opens a sheet with a table of the fandoms in the library: **Fandom** (the full tag, as in the sidebar), **Short name** (editable; type the same short name as another fandom to group them), **Names** (pop-up: First word, Last word, Full name), **Fanfics** (count). A search field above the table, **Restore Built-in Names** and **Done** below it. Changes show in the example line at once.

### What changes on disk

- Nothing in the library. An export writes only into the folder you chose, and never overwrites a file there.
- Your own short names are stored in the app's preferences on this Mac, like the other settings. No network code is added.

### Files

- Core: new `FileNames.swift` (the naming rules), new data file `FandomShortNames.json` (the built-in list), `Package.swift` (resource).
- App: `AppModel.swift` (export), `FanficEngineApp.swift` (menu item), `WorkListView.swift` and `SidebarView.swift` (right-click menus), new `ExportSummaryView.swift`, `SettingsView.swift`, new `ShortNamesView.swift`.
- Tests: a table test with every example in `SPEC.md` 9.1 plus the hard cases (alternate names, `(Supernatural)`, OMC/OFC, nicknames in quotes, family name first, same first names, `:` and `?` in titles, too-long titles, name clashes, re-export into the same folder).
- `SPEC.md`, `USER_MANUAL.md`, `README.md` (feature list; the Privacy section says the app writes only to its library folder, so it gets "and into folders you export to"), `CHANGELOG.md`, the gallery.

### Stays the same

The window, toolbar, sidebar, works list and details look exactly as before; import, search, IDs, the library folder and `library.json`; left-clicks everywhere.

### Not in this change (possible later)

- Grouping the sidebar's Fandoms list by short name (HP once instead of every Harry Potter tag).
- Dragging a fanfic from the list into Finder to save it with its readable name.
- Export in the Windows/Linux version.

### Layout rules for change 5

| # | Rule | How it is checked |
| --- | --- | --- |
| U25 | File menu: Export Shown Fanfics… (⇧⌘E) directly after Add Files…; greyed out when the works list is empty | Screenshot of the open menu, with and without works |
| U26 | Fanfic right-click menu: Open Fanfic, Open First Page, Show in Finder, Export…, separator, Remove from Library | Screenshot of the open menu |
| U27 | Sidebar right-click on a fandom, character or pairing: one item "Export N Fanfics…" with the row's count; left-click unchanged | Screenshot; click test |
| U28 | Folder panel: standard panel, New Folder, button "Export", message with the number of fanfics | Screenshot |
| U29 | Export summary: same layout, fonts and spacing as the import summary; three counts, names listed under their heading; Show in Finder and OK (default) | Screenshot next to the import summary, light and dark |
| U30 | Settings: "File names" group between Relationships and Library with the example line and the Fandom Short Names… button; the rest of Settings unchanged | Screenshot compared with change 2, light and dark |
| U31 | Short-names sheet: standard table with the four columns, search field, Restore Built-in Names and Done; a short-name edit updates the example line at once | Screenshots before and after an edit |
| U32 | Only standard macOS controls, system colours and materials (U9) | Screenshots in light and dark |

---

## Change 4 (1 November 2026): title band drawn by the app (owner: "try app drawn band")

- **Why:** on macOS 27.2 the grey band behind the window title and toolbar, and its bottom line, start 2 pt left of the sidebar divider, so the lines don't meet (a bare three-column window has the same step, so macOS draws it). Hiding macOS's band alone is not enough: scrolled works then run under the title.
- **What changes:** macOS's band is hidden and the app draws its own band at the top of the works list and the details columns: the same height as before (from the window top to the bottom of the toolbar), the same look as the macOS band in light and dark, a 1-px separator line at its bottom. It starts exactly at the sidebar divider and covers works that are scrolled under it.
- **What stays the same:** the title, subtitle, buttons and search field and their places; the sidebar (its colour goes up to the window top as before); column widths; everything else.
- **Files:** `ContentView.swift`, new `TitleBand.swift`.
- **How (as built):** each column draws macOS's own title-bar material (`NSVisualEffectView`, `.titlebar`) from the window top to the toolbar's bottom edge, plus macOS's bottom line (one strong pixel, on Retina a faint second one). Only on macOS 27 and later, where the step was seen; earlier systems keep their own band.
- **Known difference:** the divider between the works list and the details column now also runs up to the window top (macOS draws it above the columns, so the band can't cover it), like in Mail.

| # | Rule | How it is checked |
| --- | --- | --- |
| U22 | The vertical divider between sidebar and works list runs straight from the window top to the bottom; band and band line start at the divider, no step | Pixel check of the corner, light and dark |
| U23 | Band height and colour match the old macOS band (±1 pt, same colour within a few levels), separator line at its bottom across the list and details columns | Before/after pictures, pixel check |
| U24 | Works scrolled up are hidden behind the band: the title and subtitle stay readable | Screenshot with the list scrolled, light and dark |

---

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
- **Settings window (new):** the standard macOS Settings window, opened by the gear button or ⌘, (Fanfic Engine menu → Settings…). One page with four groups:
  1. **Sidebar:** Show Pairings / Show Characters / Show Fandoms (on/off, all on by default); "Sort lists by": Name or Number of fanfics (default Name).
  2. **Relationships:** "Include friendship tags (A & B)" (default on). When off, `A & B` tags are left out of the Pairings list, and people who only appear in them are left out of Characters. Searching is not affected.
  3. **Library:** where the library folder is (selectable path), **Show in Finder**, **Re-read Library**, and the counts ("3 fanfics · 3 first pages").
  4. **Offline:** the note "Fanfic Engine works entirely on this Mac. It never connects to the internet."
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
- App: `AppModel.swift`, `ContentView.swift`, `SidebarView.swift`, `WorkListView.swift`, `WorkDetailView.swift`, `FanficEngineApp.swift`, new `SettingsView.swift`.
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

`Sources/FanficEngine/` — `FanficEngineApp.swift`, `ContentView.swift`, `SidebarView.swift`, `WorkListView.swift`, `WorkDetailView.swift`, `PDFPreview.swift`, `ImportSummaryView.swift`.

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
