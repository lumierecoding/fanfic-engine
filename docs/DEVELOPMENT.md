# Development

Fanfic Engine is a Swift package with three targets:

| Target | What it is |
| --- | --- |
| `FanficCore` | Everything that isn't UI: ZIP/EPUB reading, PDF first pages, the Relationship and Fandom fields, IDs, the library folder and `library.json`, the pairing/character/fandom lists, search |
| `FanficEngine` | The SwiftUI Mac app (window, sidebar, details, Settings) |
| `FanficCoreTests` | Swift Testing tests for `FanficCore`, run against the files in `Fixtures/` |

The only third-party dependency and the only network code is the updater, [Sparkle](https://sparkle-project.org) (one exact version in `Package.swift`; `Updater.swift`). Please keep it that way (see [CONTRIBUTING](../CONTRIBUTING.md)).

## Build, test, install

```sh
# tests (about a second)
swift test

# debug build
swift build

# release build, sign ad-hoc, install to /Applications
./scripts/build-app.sh
```

`build-app.sh` builds in `~/Library/Developer/FanficEngine` (outside the source folder, which helps when the source lives in iCloud Drive), assembles `Fanfic Engine.app` with `Resources/Info.plist` and the icon, signs it ad-hoc (`codesign -s -`, no certificate or Keychain needed) and copies it to `/Applications`. Pass `--scratch-path` to `swift test`/`swift build` if you want the same build folder.

## Project layout

```
Package.swift
Sources/FanficCore/        ZipArchive, EPUBBook, HTMLText, WorkReader (first pages), Relationships (field
                           reading), SummaryReader, Search (name matching, queries), Models (records, lists),
                           Library (store)
Sources/FanficEngine/      App, AppModel, ContentView, SidebarView, WorkListView, WorkDetailView,
                           PDFPreview, ImportSummaryView, SettingsView
Tests/FanficCoreTests/     Reading, Summary, Library, Search and library-folder-move tests
Fixtures/                  AO3-style test files + expected.json (generated); Summaries/ for the summary cases
Resources/                 Info.plist, AppIcon.icns
scripts/                   build-app.sh, make-release.sh, make-fixtures.swift, make-icon.swift, sync-repo.sh
SPEC.md                    the rules: what is read, how, what library.json contains, how search works
docs/                      user manual, this file, UI rules, screenshots
```

## The rules live in SPEC.md

[SPEC.md](../SPEC.md) describes exactly how files are read and searched. Code comments refer to its sections. If you change a rule, change SPEC.md and add or update a test.

The UI layout rules are in [docs/ui-spec.md](ui-spec.md) (numbered U1–U40). Describe visual changes there before changing the views.

## Test files

`Fixtures/` holds made-up AO3-style PDFs and EPUBs and `expected.json` with the expected result for each. They are generated, not downloaded:

```sh
swift scripts/make-fixtures.swift Fixtures
```

They cover singular and plural labels, names broken across lines, poly pairings, friendship tags, a crossover, a field that continues on the next page, a cover page without the field, an image-only EPUB cover, a FicHub-style export without fields, a duplicate, a scanned PDF without text and broken files. `Fixtures/Summaries/` (with its own `expected.json`) holds the summary cases: AO3's EPUB layout with and without Notes, a PDF summary that runs onto page 2, an inline `Summary:` line and a "Summary" chapter that is too long. Stories, authors (`example-author-N`) and links (`example.org`) are invented; only fandom and character names are real.

When a real file is read wrongly, add a fixture that reproduces the layout (with invented text) and its expected result.

## Developer launch options

Normal use needs none of these; they exist for screenshots and testing:

```sh
open -n "/Applications/Fanfic Engine.app" --args \
  -libraryPath /path/to/test/library   # use another library folder (never test on your real one)
  -appSupportPath /path/to/test/folder # rehearse the move from "Fanfic Pairings" (see below) in a test folder
  -importOnLaunch /path/to/files       # import into that library at start
  -appearance light|dark               # force an appearance
  -search "harry/draco"                # prefill the search field
  -sidebar "fandom:<name>"             # select a fandom (or "character:<name>", "pairing:<name>")
  -selectTitle "<title>"               # select a work
  -openSettings YES                    # open the Settings window
  -previewDrop YES                     # show the drag-and-drop outline
  -dumpMenus /path/menus.txt           # write the menu bar as text
  -showAppMenu YES                     # open the app menu (screenshots)
  -checkForUpdatesOnLaunch YES         # updater tests: Check for Updates at start
  -checkInBackgroundOnLaunch YES       # updater tests: a quiet check at start
  -installUpdatesImmediately YES       # updater tests: install a downloaded update at once and restart
  -windowSize 1100x1000                # window size
  -ApplePersistenceIgnoreState YES     # ignore the saved window state
```

Sidebar and Settings preferences can be set the same way (`-fandomsExpanded YES`, `-sidebarSort count`, `-showCharacters NO`, `-includeFriendships NO`).

The app was called **Fanfic Pairings** during development. On first start, Fanfic Engine moves a library from `~/Library/Application Support/Fanfic Pairings` to `…/Fanfic Engine` (only if the new folder doesn't exist yet, and only while the old app isn't running — otherwise it asks to quit it first) and copies the sidebar settings from the old bundle ID. To rehearse that on a copy, put a `Fanfic Pairings` folder into a test folder and start with `-appSupportPath <test folder>` (add `-ignoreOldApp YES` to skip the running-app check; it only works together with `-appSupportPath`).

Note: forcing `-appearance light` while macOS is in dark mode leaves the search field's text white — an artefact of the override only.

## Performance notes

Names are normalised once and remembered (`Memo` in `Search.swift`), the sidebar lists are built once per library change and cached in `Library`, search results are cached per (search, selection, library revision) in `AppModel`, and a batch import saves `library.json` at most every 3 seconds. With 10,000 works: opening about 1 s, one search about 0.03 s, list rebuild after a change about 0.4 s. Opening the Pairings section with tens of thousands of distinct pairings is the slowest UI path, because SwiftUI builds every row.

## Releasing

```sh
./scripts/make-release.sh
```

builds `Fanfic Engine.app` for Apple Silicon and Intel (`--arch arm64 --arch x86_64`) with `Sparkle.framework` inside, signs it ad-hoc and puts it with an Applications shortcut and *Read Me First.txt* into `~/Library/Developer/FanficEngine/dist/Fanfic-Engine-<version>.dmg`. It signs the disk image with the update key and writes `appcast.xml` (the update feed: version, download address, size, signature, and this version's list from `CHANGELOG.md` as the notes), plus `SHA256SUMS`. The version comes from `Resources/Info.plist`. It never touches `/Applications`.

Rules the updater adds:

- **Raise `CFBundleVersion`** in `Info.plist` with every release (with `CFBundleShortVersionString`): Sparkle compares it.
- **Every release carries its `appcast.xml`.** The app's feed is `https://github.com/lumierecoding/fanfic-engine/releases/latest/download/appcast.xml`, so the newest published release must have one, and its disk image must be the exact file that was signed. Drafts are never offered.
- **The update key** is a file outside the repository and iCloud (`~/Library/Developer/FanficEngine/keys/fanfic-engine-update.key`, or `FANFIC_UPDATE_KEY`), made once with `swift scripts/update-key.swift new <file>`; its public half is `SUPublicEDKey` in `Info.plist`. Keep a backup: without it, installed copies can't be updated in the app.

Attach the disk image, `appcast.xml`, `SHA256SUMS` and the Windows/Linux wheel to a GitHub release, with the tag `v<version>` (for example `v1.1.0`) that the feed's download address uses. The app is not notarized (that needs a Developer ID certificate from a paid Apple Developer account), so downloaded copies need the one-time "Open Anyway" step described in the README. The Intel half is built but can't be tested on macOS 27, which no longer runs Intel code.

## Windows and Linux version (`desktop/`)

A Python + Qt (PySide6) port, labelled alpha because it is only tested on macOS. `fanficengine.core` is a line-by-line port of `FanficCore` (same rules, same `library.json`), `fanficengine.ui` is the Qt window (rules W1–W14 in [ui-spec-desktop.md](ui-spec-desktop.md)). PDFs are read, copied and previewed with PDFium (pypdfium2); EPUB first pages are drawn with Qt's PDF writer.

```sh
cd desktop
uv run pytest                        # 32 tests on ../Fixtures, same expected results as the Swift tests
uv run fanfic-engine --library-path /tmp/test-library --import ../Fixtures
```

If the source lives in iCloud Drive, keep the environment elsewhere: `UV_PROJECT_ENVIRONMENT=~/Library/Developer/FanficEngine/desktop-venv PYTHONDONTWRITEBYTECODE=1 uv run pytest -p no:cacheprovider`.

When you change a reading or search rule, change it in both `Sources/FanficCore` and `desktop/src/fanficengine/core`, and run both test suites.

