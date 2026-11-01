# Development

Fanfic Pairings is a Swift package with three targets:

| Target | What it is |
| --- | --- |
| `FanficCore` | Everything that isn't UI: ZIP/EPUB reading, PDF first pages, the Relationship and Fandom fields, IDs, the library folder and `library.json`, the pairing/character/fandom lists, search |
| `FanficPairings` | The SwiftUI Mac app (window, sidebar, details, Settings) |
| `FanficCoreTests` | Swift Testing tests for `FanficCore`, run against the files in `Fixtures/` |

There are no third-party dependencies and no network code. Please keep it that way (see [CONTRIBUTING](../CONTRIBUTING.md)).

## Build, test, install

```sh
# tests (about a second)
swift test

# debug build
swift build

# release build, sign ad-hoc, install to /Applications
./scripts/build-app.sh
```

`build-app.sh` builds in `~/Library/Developer/FanficPairings` (outside the source folder, which helps when the source lives in iCloud Drive), assembles `Fanfic Pairings.app` with `Resources/Info.plist` and the icon, signs it ad-hoc (`codesign -s -`, no certificate or Keychain needed) and copies it to `/Applications`. Pass `--scratch-path` to `swift test`/`swift build` if you want the same build folder.

## Project layout

```
Package.swift
Sources/FanficCore/        ZipArchive, EPUBBook, HTMLText, WorkReader (first pages), Relationships (field
                           reading), Search (name matching, queries), Models (records, lists), Library (store)
Sources/FanficPairings/    App, AppModel, ContentView, SidebarView, WorkListView, WorkDetailView,
                           PDFPreview, ImportSummaryView, SettingsView
Tests/FanficCoreTests/     Reading, Library and Search tests
Fixtures/                  AO3-style test files + expected.json (generated)
Resources/                 Info.plist, AppIcon.icns
scripts/                   build-app.sh, make-fixtures.swift, make-icon.swift, sync-repo.sh
SPEC.md                    the rules: what is read, how, what library.json contains, how search works
docs/                      user manual, this file, UI rules, screenshots
```

## The rules live in SPEC.md

[SPEC.md](../SPEC.md) describes exactly how files are read and searched. Code comments refer to its sections. If you change a rule, change SPEC.md and add or update a test.

The UI layout rules are in [docs/ui-spec.md](ui-spec.md) (numbered U1–U21). Describe visual changes there before changing the views.

## Test files

`Fixtures/` holds made-up AO3-style PDFs and EPUBs and `expected.json` with the expected result for each. They are generated, not downloaded:

```sh
swift scripts/make-fixtures.swift Fixtures
```

They cover singular and plural labels, names broken across lines, poly pairings, friendship tags, a crossover, a field that continues on the next page, a cover page without the field, an image-only EPUB cover, a FicHub-style export without fields, a duplicate, a scanned PDF without text and broken files. Stories, authors (`example-author-N`) and links (`example.org`) are invented; only fandom and character names are real.

When a real file is read wrongly, add a fixture that reproduces the layout (with invented text) and its expected result.

## Developer launch options

Normal use needs none of these; they exist for screenshots and testing:

```sh
open -n "/Applications/Fanfic Pairings.app" --args \
  -libraryPath /path/to/test/library   # use another library folder (never test on your real one)
  -importOnLaunch /path/to/files       # import into that library at start
  -appearance light|dark               # force an appearance
  -search "harry/draco"                # prefill the search field
  -sidebar "fandom:<name>"             # select a fandom (or "character:<name>", "pairing:<name>")
  -selectTitle "<title>"               # select a work
  -openSettings YES                    # open the Settings window
  -previewDrop YES                     # show the drag-and-drop outline
  -windowSize 1100x1000                # window size
  -ApplePersistenceIgnoreState YES     # ignore the saved window state
```

Sidebar and Settings preferences can be set the same way (`-fandomsExpanded YES`, `-sidebarSort count`, `-showCharacters NO`, `-includeFriendships NO`).

Note: forcing `-appearance light` while macOS is in dark mode leaves the search field's text white — an artefact of the override only.

## Performance notes

Names are normalised once and remembered (`Memo` in `Search.swift`), the sidebar lists are built once per library change and cached in `Library`, search results are cached per (search, selection, library revision) in `AppModel`, and a batch import saves `library.json` at most every 3 seconds. With 10,000 works: opening about 1 s, one search about 0.03 s, list rebuild after a change about 0.4 s. Opening the Pairings section with tens of thousands of distinct pairings is the slowest UI path, because SwiftUI builds every row.

## Releasing

`./scripts/build-app.sh` produces an ad-hoc signed app that runs on the Mac that built it. Distributing a ready-made download to other people would need a Developer ID certificate and notarization (a paid Apple Developer account); until then, users build from source.
