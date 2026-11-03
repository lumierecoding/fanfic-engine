# Fanfic Engine — Specification

A small offline Mac app that helps find fanfictions by pairing. It imports EPUB and PDF files (for example AO3 downloads), keeps a copy of each work and of its first page, reads the pairings from the work's "Relationship:" field and lets you search for them.

## 1. Inputs

- `.pdf` and `.epub` files, added with **Add Files…** or by dragging files or folders onto the window. Folders are searched for PDFs and EPUBs, including subfolders.
- Other file types are ignored and listed as skipped.

## 2. Library folder

```
~/Library/Application Support/Fanfic Engine/
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
  "version": 3,
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
      "fandoms": ["Harry Potter - J. K. Rowling"],
      "summary": "Two former rivals, one snowed-in cottage."
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
- `works`: the list that matches each work ID with its first-page ID, plus its pairings in the order they appear on the page, its fandoms and its summary (section 5a; left out when the work has none).
- `pairings`: every pairing in the library once, sorted alphabetically (case and accents ignored).
- `pairingIndex`: every pairing with the work ID and first-page ID of each work that has it.
- `characters` / `characterIndex`: every person named in a relationship tag (pairings and friendships), once, with the works that have them. This is not the first page's separate `Characters:` field. Spellings that differ only in case, accents or spacing count as one; alternate names (`Tom Riddle` and `Tom Riddle | Voldemort`) stay separate.
- `fandoms` / `fandomIndex`: every value of the Fandom field, once, with the works that have it. A crossover counts in each of its fandoms.
- These lists always include friendship tags; the Settings switch only changes the sidebar.
- **Older files** are upgraded the first time the app opens them: every work is read again, IDs stay the same, and the file is saved as version 3. Version 1 (before characters and fandoms) gets `fandoms`, version 2 gets `summary` (section 5a). The old file is kept as `library-v1-backup.json` or `library-v2-backup.json`.
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

## 5a. Reading the summary

The summary the author wrote for the work is read once on import, stored in `library.json` and shown in the details column (`docs/ui-spec.md` change 7).

**Where it is.** In AO3 downloads the summary is not on the page with the tags. In AO3 EPUBs it is in the next text document: a paragraph `Summary` followed by a `blockquote` with the text, then usually `Notes`. In AO3 PDFs it follows the title and author. So the label is looked for on the page used for the first-page copy and on the two pages (PDF) or text documents (EPUB) after it.

1. **Label:** a line that is exactly `Summary` or `Summary:` (any case), or a line that starts with `Summary:` and goes on (that text is the start of the summary). The first label found is used.
2. **EPUB in AO3's layout:** if a `blockquote` comes right after the label, the summary is exactly that blockquote's text.
3. **Otherwise** (PDFs, EPUBs from other makers): the text after the label up to the next label — `Notes` or `Notes:`, `Chapter 1` (any number), `Chapter Text`, `Work Text`, `See the end of the work`, or any label from section 5 rule 2 — or up to the end of the document. A PDF summary that reaches the end of its page goes on with the next page, up to one of those labels.
4. **Tidying:** paragraphs are kept, with an empty line between them; line breaks inside a paragraph are kept (EPUB). PDF text has no paragraph marks (only the ends of the printed lines), so in a PDF the lines are joined with spaces into one paragraph; runs of spaces become one; HTML entities are decoded; italics, bold and links are dropped (the link text stays). Unlike section 5, the text is not split at commas and has no 150-character limit.
5. **Too long means it is not a summary.** AO3 allows at most 1,250 characters. A text longer than 1,500 characters is not taken as the summary, and the work has none. (Example: an EPUB from another site whose chapter starts with a line "Summary" and runs on for thousands of characters.)
6. **None found:** the work has no summary (`summary` is left out of its entry) and the details column says "No summary found". Typical for FicHub exports and files from other sites.

The PDF rule has only been tried on the test files: no real AO3 PDF has been checked yet (see the development plan, M5-01).

**`library.json` version 3.** Each work gets `"summary": "…"`; the key is left out when no summary was found. The first time the app opens a version 2 library, it reads every work once more, the same automatic re-read as the version 1 → 2 update: IDs, pairings, fandoms, first pages and files stay the same (their rules don't change), the summaries are added and the file is saved as version 3. Before that, the version 2 file is copied to `library-v2-backup.json` in the library folder. While the re-read runs (a few seconds for hundreds of fanfics), the progress wheel in the toolbar turns and Re-read Library is greyed out; the summaries appear as they are read.

The summary is not searched (section 6 is unchanged). The Windows/Linux alpha still writes version 2: it opens a version 3 library and ignores the summaries, but if it saves the library, the summaries are dropped, and the Mac app reads them again the next time it opens the library.

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
- **Re-read Library** reads every stored work again with the current rules. IDs stay the same; first-page copies, pairings, fandoms and summaries are replaced. (Used after the reading rules are improved.)

## 8. Limits

- Works fully offline: no network code, no third-party libraries, no account.
- Scanned PDFs without a text layer have no readable text and are reported as "could not read".
- The search field searches the Relationship field; fandoms are browsed through the sidebar; summaries are shown, not searched. The `Characters:` field and other tags are not used.
- macOS 27 or later, Apple Silicon.

## 9. Export with readable file names (planned, not built yet)

**Export…** copies fanfics from the library into a folder you choose and gives each copy a readable name: **fandom - pairing - title**. The copies are the stored files in `Works/`, byte for byte. Nothing in the library changes, and the original files you imported are never renamed, changed or moved.

What can be exported: one fanfic (right-click → Export…), or everything the works list shows (File → Export Shown Fanfics…: all works, one fandom, a search result), or everything under a fandom, character or pairing in the sidebar (right-click → Export N Fanfics…).

### 9.1 The name

`<fandoms> - <pairing> - <title>.<epub|pdf>`

A part that is empty is left out together with its ` - `. The examples are for a library that holds exactly the test files (the order of the names depends on the library, see 9.3).

| Test file | Exported as |
| --- | --- |
| The Quiet Winter (`Harry Potter - J. K. Rowling`; `Harry Potter/Draco Malfoy`) | `HP - Harry x Draco - The Quiet Winter.pdf` |
| Common Room Constellations (four relationships, the first is `Harry Potter/Draco Malfoy`) | `HP - Harry x Draco - Common Room Constellations.pdf` |
| Crossroads (Harry Potter + Percy Jackson; `Draco Malfoy/Percy Jackson`) | `HP & PJO - Draco x Percy - Crossroads.pdf` |
| Baker Street Ledger (`Sherlock (TV)`; `Sherlock Holmes/John Watson`) | `Sherlock - John x Sherlock - Baker Street Ledger.pdf` |
| Untamed Hearts (Mo Dao Zu Shi; `Lan Zhan \| Lan Wangji/Wei Ying \| Wei Wuxian`) | `MDZS - Wei Ying x Lan Zhan - Untamed Hearts.epub` |
| Lucky Charm (`Miraculous Ladybug`, not on the list) | `Miraculous Ladybug - Marinette x Chloé - Lucky Charm.pdf` |
| Field Notes (Criminal Minds, no relationship) | `Criminal Minds - Field Notes.pdf` |
| Starlight Over Grimmauld (no fandom field) | `Harry x Draco - Starlight Over Grimmauld.epub` |
| Westward Bound (no fields) | `Westward Bound.epub` |

### 9.2 Fandoms

1. Each fandom tag of the work gets a **short name**: your own short name from Settings if you set one, else the built-in list (9.7), else the tag's cleaned name:
   - in a tag with ` | ` parts (original script, romanised, English), the last part is used: `僕のヒーローアカデミア | Boku no Hero Academia | My Hero Academia` → `My Hero Academia`;
   - everything from the first ` - ` is cut (author, "All Media Types"): `IT - Stephen King` → `IT`;
   - parts in brackets are cut: `Criminal Minds (US TV)` → `Criminal Minds`; ` & Related Fandoms` is cut too;
   - `Original Work` → `Original`; `No Fandom` → left out.
2. Tags with the same short name count once: `Harry Potter - J. K. Rowling` and `Harry Potter (Movies)` are both just `HP`. This is how all Harry Potter fandoms are grouped under HP.
3. Tags ending in `RPF` are never put into a group; they keep their cleaned name (`Heartstopper (TV) RPF` → `Heartstopper RPF`).
4. Short names are sorted A–Z and joined with ` & `: `HP & PJO`. With more than two: the first two and `+N` (`HP & Marvel +1`), so a crossover always gets the same name.

### 9.3 Pairing

1. **Which relationship:** the first romantic one (`A/B`) on the first page. If there is none, the first friendship (`A & B`). If there is none either, the part is left out.
2. **Each name** is shortened:
   - alternate names: the part before ` | ` (`Tom Riddle | Voldemort` → `Tom Riddle`);
   - brackets are cut (`Castiel (Supernatural)` → `Castiel`);
   - original characters: `Original Male Character(s)` → `OMC`, `Original Female Character(s)` → `OFC`, any other `Original … Character(s)` → `OC`; `Reader` stays `Reader`;
   - a nickname in quotes is used: `James "Bucky" Barnes` → `Bucky`;
   - otherwise the fandom's **Names** setting (9.7): **first word** (the default; a leading `The` is skipped, so `The Doctor` → `Doctor`), **last word** (for fandoms whose tags put the family name first: `Uchiha Sasuke` → `Sasuke`), or **full name**. If a crossover's fandoms have different settings, full names are used.
3. If two names come out the same (`Harry Potter/Harry Styles`), those names are written in full. `OMC`, `OFC`, `OC` and `Reader` may repeat (`OMC x OMC`).
4. **Order.** The same people always come out in the same order, whatever order the tag has: `Harry Potter/Draco Malfoy` and `Draco Malfoy/Harry Potter` both become `Harry x Draco`, so these fics sit together in Finder. The person in more fanfics comes first (the number next to them in the Characters list, counting friendship tags too); if that is equal, the one in more relationship tags; if that is equal too, A–Z (ignoring case and accents). Because the order comes from the library, two libraries can order a pairing differently, and an order can change as the library grows.
5. The names are joined with ` x `, or ` & ` for a friendship. Poly: up to three names, then `+N` (`Hermione x Ginny x Pansy`).

### 9.4 Title

The work's title; if it has none, the original file name without its extension.

### 9.5 Characters that are not allowed in file names

So the names also work on Windows, in zip files and on e-readers: `:` → ` -`; `/` and `\` → `-`; `"` → `'`; `* ? < > |` and control characters are removed; runs of spaces become one; leading dots and trailing dots or spaces are removed. Names are stored in Unicode NFC form.

### 9.6 Length, extension, name clashes

- **Length:** at most 150 characters including the extension (macOS allows 255 per name, Windows allows 260 for the whole path, so this leaves room for the folder). If a name is longer, the title is shortened at a word boundary with `…`, then the pairing, then the fandoms.
- **Extension:** `.epub` or `.pdf` from the work's kind, not from the original file name.
- **Never overwrites.** If the folder already has a file with the same content, under any name, the fanfic is reported as "already in folder" and not copied again (so a fanfic exported earlier under a name in a different order is recognised). If the content differs, ` (2)`, ` (3)` … is added before the extension. The same applies to two fanfics in one export that get the same name.

### 9.7 Built-in short names (draft — the owner corrects this list before it is built)

A fandom tag belongs to a group if it, or one of its ` | ` parts, starts with one of the group's tag names as whole words (so `Thor` does not match `Thorne`). Names marked * may appear anywhere in the tag. Case and accents are ignored. The list is one data file that both the Mac app and the Windows/Linux version can read.

| Short name | Tags that belong | Names |
| --- | --- | --- |
| HP | Harry Potter · Fantastic Beasts · Hogwarts Legacy | first word |
| Twilight | Twilight · Midnight Sun - Stephenie Meyer · Life and Death - Stephenie Meyer · The Short Second Life of Bree Tanner | first word |
| ASOIAF | A Song of Ice and Fire · Game of Thrones · House of the Dragon · Fire & Blood · A Knight of the Seven Kingdoms | first word |
| LotR | The Lord of the Rings · Lord of the Rings · The Hobbit · The Silmarillion · *J. R. R. Tolkien | first word |
| Marvel | *Marvel · Avengers · The Avengers · Iron Man · Captain America · Thor · *Spider-Man · Deadpool · Doctor Strange · Guardians of the Galaxy · Venom · Black Panther · Black Widow · Ant-Man · Shang-Chi · Loki · WandaVision · The Falcon and the Winter Soldier · Hawkeye · Daredevil · Moon Knight · X-Men · Agents of S.H.I.E.L.D. | first word |
| DC | DC · DCU · Batman · Superman · Wonder Woman · Justice League · Teen Titans · Young Justice · Harley Quinn · Constantine | first word |
| SW | Star Wars | first word |
| Star Trek | Star Trek | first word |
| Doctor Who | Doctor Who · Torchwood | first word |
| SPN | Supernatural | first word |
| Sherlock | Sherlock · Sherlock Holmes | first word |
| Teen Wolf | Teen Wolf | first word |
| Good Omens | Good Omens | first word |
| OFMD | Our Flag Means Death | first word |
| Hannibal | Hannibal | first word |
| TVD | The Vampire Diaries · The Originals · Legacies | first word |
| BtVS | Buffy the Vampire Slayer · Angel: the Series | first word |
| Shadowhunters | Shadowhunters · The Mortal Instruments · The Shadowhunter Chronicles | first word |
| TWD | The Walking Dead · Fear the Walking Dead | first word |
| Stranger Things | Stranger Things | first word |
| Heartstopper | Heartstopper | first word |
| PJO | Percy Jackson · Heroes of Olympus · The Heroes of Olympus · *Rick Riordan | first word |
| ATLA | Avatar: The Last Airbender · Avatar: Legend of Korra | first word |
| Witcher | The Witcher · Wiedźmin | first word |
| DA | Dragon Age | first word |
| Mass Effect | Mass Effect | first word |
| Genshin | Genshin Impact | first word |
| AoT | Shingeki no Kyojin · Attack on Titan | first word |
| HxH | Hunter x Hunter | first word |
| Naruto | Naruto · Boruto | last word |
| BNHA | Boku no Hero Academia · My Hero Academia | last word |
| JJK | Jujutsu Kaisen | last word |
| Haikyuu | Haikyuu | last word |
| DN | Death Note | last word |
| One Piece | One Piece | last word |
| Bleach | Bleach | last word |
| BTS | Bangtan Boys · BTS | last word |
| MDZS | Mo Dao Zu Shi · The Untamed | full name |
| TGCF | Tian Guan Ci Fu · Heaven Official's Blessing | full name |
| SVSSS | Ren Zha Fanpai Zijiu Xitong · The Scum Villain's Self-Saving System | full name |
| Original | Original Work | first word |

Fandoms that are not on the list use their cleaned name (9.2). In Settings you can give any fandom in your library a different short name, or the short name of another fandom to group them, and change its Names setting.
