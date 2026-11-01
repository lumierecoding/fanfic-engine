# Fanfic Pairings — Specification

A small offline Mac app that helps find fanfictions by pairing. It imports EPUB and PDF files (for example AO3 downloads), keeps a copy of each work and of its first page, reads the pairings from the work's "Relationship:" field and lets you search for them.

## 1. Inputs

- `.pdf` and `.epub` files, added with **Add Files…** or by dragging files or folders onto the window. Folders are searched for PDFs and EPUBs, including subfolders.
- Other file types are ignored and listed as skipped.

## 2. Library folder

```
~/Library/Application Support/Fanfic Pairings/
├── Works/          <work ID>.pdf | <work ID>.epub      (copy of the original file)
├── First Pages/    <first-page ID>.pdf                  (copy of the first page)
└── library.json                                         (the lists, see 4)
```

- The **Show Library in Finder** button opens this folder.
- The original file is never changed or moved.

## 3. What happens on import

1. **Duplicate check.** The SHA-256 of the file's bytes is compared with the library. Same content → not imported again, reported as "already in library".
2. **IDs.** The work gets a new UUID (work ID); its first-page copy gets another new UUID (first-page ID).
3. **First page.**
   - **PDF:** page 1 is saved as its own one-page PDF.
   - **EPUB:** EPUBs have no fixed pages, so the "first page" is the first document in the reading order (spine) that has visible text. Image-only pages (covers, Calibre title images) are skipped. It is rendered as a one-page A4 PDF.
   - **Fallback:** if that page has no Relationship field, the next two pages (PDF) or text documents (EPUB) are checked. If one of them has the field, that page becomes the first-page copy. The work entry records which page was used (`firstPageSource`, e.g. `page 1` or `OEBPS/preface.xhtml`).
4. **Pairings and fandoms.** Read from the text of the chosen page (section 5). If that page has no Fandom field, the other checked pages are tried for it.
5. **Title and author.** PDF document info or EPUB `dc:title` / `dc:creator`; if missing, the file name.
6. **Saving.** The original is copied to `Works/`, the first page to `First Pages/`, and `library.json` is rewritten in one atomic write. If any step fails, the files written for this work are removed again and the work is reported as "could not read".

Results are reported per import:

| Result | Meaning |
| --- | --- |
| Added | Imported with at least one pairing |
| Added, no pairing found | Imported, but the page has no Relationship field or it is empty. The work is listed under **No Pairing Found** |
| Already in library | Same file content imported before |
| Could not read | Not a valid PDF/EPUB, no text on the first pages, or a file error. Nothing is kept |
| Skipped | Not a PDF or EPUB |

## 4. `library.json`

```json
{
  "version": 2,
  "works": [
    {
      "workID": "6F1C…",
      "firstPageID": "A93E…",
      "kind": "pdf",
      "originalFileName": "The Quiet Winter.pdf",
      "storedFile": "Works/6F1C….pdf",
      "firstPageFile": "First Pages/A93E….pdf",
      "firstPageSource": "page 1",
      "title": "The Quiet Winter",
      "author": "example-author-1",
      "sha256": "…",
      "importedAt": "2026-11-01T17:00:00Z",
      "relationships": ["Harry Potter/Draco Malfoy", "Harry Potter & Ron Weasley"],
      "fandoms": ["Harry Potter - J. K. Rowling"]
    }
  ],
  "pairings": ["Aaron Hotchner/Spencer Reid", "Harry Potter & Ron Weasley", "Harry Potter/Draco Malfoy"],
  "pairingIndex": [
    {
      "pairing": "Harry Potter/Draco Malfoy",
      "works": [ { "workID": "6F1C…", "firstPageID": "A93E…" } ]
    }
  ],
  "characters": ["Draco Malfoy", "Harry Potter", "Ron Weasley"],
  "characterIndex": [ { "character": "Harry Potter", "works": [ { "workID": "6F1C…", "firstPageID": "A93E…" } ] } ],
  "fandoms": ["Harry Potter - J. K. Rowling"],
  "fandomIndex": [ { "fandom": "Harry Potter - J. K. Rowling", "works": [ { "workID": "6F1C…", "firstPageID": "A93E…" } ] } ]
}
```

- Keys are written in alphabetical order, so the file looks the same every time.
- `works`: the list that matches each work ID with its first-page ID, plus its pairings in the order they appear on the page.
- `pairings`: every pairing in the library once, sorted alphabetically (case and accents ignored).
- `pairingIndex`: every pairing with the work ID and first-page ID of each work that has it.
- `characters` / `characterIndex`: every person named in a relationship tag (pairings and friendships), once, with the works that have them. This is not the first page's separate `Characters:` field. Spellings that differ only in case, accents or spacing count as one; alternate names (`Tom Riddle` and `Tom Riddle | Voldemort`) stay separate.
- `fandoms` / `fandomIndex`: every value of the Fandom field, once, with the works that have it. A crossover counts in each of its fandoms.
- These lists always include friendship tags; the Settings switch only changes the sidebar.
- **Version 1 files** (written before characters and fandoms existed) are upgraded the first time the app opens them: every work is read again to fill in `fandoms`, IDs stay the same, and the file is saved as version 2.
- `pairings` and `pairingIndex` are rebuilt from `works` on every save. `A/B` and `B/A` count as one pairing; the spelling used most often is shown (on a tie, the first alphabetically).

## 5. Reading the Relationship and Fandom fields

1. Find the first `Relationship:` or `Relationships:` label (any case, spaces allowed before the colon).
2. The field ends at the next label: `Relationship(s):`, `Fandom(s):`, `Character(s):`, `Additional Tags:`, `Language:`, `Series:`, `Collection(s):`, `Stats:`, `Published:`, `Words:`, `Summary:`, `Notes:`, `Rating:`, `Archive Warning(s):`, `Categor(y|ies):`, or at the end of the page. If the field reaches the end of the page, the next page's text is read too (for reading only).
3. All line breaks and runs of spaces become one space.
4. The text is split at commas (AO3 tags cannot contain commas). Each part is trimmed; spaces around `/` and `&` are tidied to `A/B` and `A & B`. A part longer than 150 characters (the AO3 tag limit) means free text ran into the field: only its first line is kept, and reading stops.
5. Each part is one relationship:
   - contains `/` → **pairing** (romantic), members split at `/` (`A/B/C` is a poly pairing with three members);
   - contains `&` → **friendship**, members split at `&`;
   - otherwise → kept as a single name.

Example (PDF text with a line break inside a name):

```
Relationships:
Harry Potter/Draco Malfoy, Hermione Granger/Pansy
Parkinson/Ginny Weasley, Harry Potter & Ron Weasley
Characters:
Harry Potter, Draco Malfoy
```

→ `Harry Potter/Draco Malfoy`, `Hermione Granger/Pansy Parkinson/Ginny Weasley`, `Harry Potter & Ron Weasley`.

The **Fandom field** (`Fandom:` or `Fandoms:`) is read with the same rules 1–4; each part is one fandom. `Fandoms: Harry Potter - J. K. Rowling, Percy Jackson and the Olympians - Rick Riordan` → two fandoms. Files without the field (for example FicHub exports from other sites) have no fandom.

## 6. Search

**Normalising** (applied to the query and to the stored names): lower case, accents removed (`Chloé` → `chloe`), every character that is not a letter or digit counts as a space. A name becomes a list of words, e.g. `Lan Zhan | Lan Wangji` → `lan zhan lan wangji`.

**A name in the query matches a member** when the query name, with its spaces removed, is the start of the member's words joined together from some word onwards. So for `Draco Malfoy`:

| Query name | Matches? | Why |
| --- | --- | --- |
| `Draco Malfoy`, `draco malfoy`, `DracoMalfoy`, `draco  malfoy` | yes | same words |
| `Draco`, `dra`, `Malfoy` | yes | start of a word |
| `aco`, `alfoy` | no | not at a word start |

and `Ron` does not match `Aaron Hotchner` or `Veronica`.

**Queries:**

| Query | Finds works with … |
| --- | --- |
| `Text1/Text2` (any spaces around `/`) | a pairing that has a member matching Text1 and another member matching Text2, in either order. Poly pairings count (`A/B/C` is found by `A/B`). Friendship tags do not count |
| `Text2/Text1` | the same as `Text1/Text2` |
| `Text1 & Text2` | a friendship tag with both |
| `Text1` (no `/` or `&`) | any relationship (pairing or friendship) with a member matching Text1 |
| empty | every work |

Results are sorted by title. In each result the relationships that matched are highlighted.

**Sidebar** (order: All Works and No Pairing Found, then Fandoms, Characters, Pairings; the three lists start folded):
- clicking a **pairing** or a **character** puts it into the search field (so a character click also finds names that start with it, e.g. `Tom Riddle` finds `Tom Riddle | Voldemort` too);
- clicking a **fandom** shows only that fandom's works; the search field then searches inside it.

**Settings** (⌘, or the gear button; stored in the app's preferences on this Mac): show or hide Fandoms, Characters and Pairings; sort them by name or by number of fanfics (largest first, ties A–Z); include or leave out friendship tags (`A & B`) in Pairings and Characters; the library folder with Show in Finder and Re-read Library.

## 7. Removing and re-reading

- **Remove from Library** deletes the work's copy in `Works/`, its first-page copy and its entries in `library.json`.
- **Re-read Library** reads every stored work again with the current rules. IDs stay the same; first-page copies, pairings and fandoms are replaced. (Used after the reading rules are improved.)

## 8. Limits

- Works fully offline: no network code, no third-party libraries, no account.
- Scanned PDFs without a text layer have no readable text and are reported as "could not read".
- The search field searches the Relationship field; fandoms are browsed through the sidebar. The `Characters:` field and other tags are not used.
- macOS 27 or later, Apple Silicon.
