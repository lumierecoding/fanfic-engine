# Fanfic Pairings — User manual

Fanfic Pairings keeps a library of the fanfics you have downloaded and lets you find them by pairing, character and fandom. It works completely offline.

**Contents**

1. [Installing and opening the app](#1-installing-and-opening-the-app)
2. [Adding fanfics](#2-adding-fanfics)
3. [The window](#3-the-window)
4. [Searching](#4-searching)
5. [Browsing by fandom, character and pairing](#5-browsing-by-fandom-character-and-pairing)
6. [The details column](#6-the-details-column)
7. [Settings](#7-settings)
8. [Where your files are](#8-where-your-files-are)
9. [Duplicates](#9-duplicates)
10. [Removing works and re-reading the library](#10-removing-works-and-re-reading-the-library)
11. [Which files work best](#11-which-files-work-best)
12. [Big libraries](#12-big-libraries)
13. [Privacy](#13-privacy)
14. [Troubleshooting and questions](#14-troubleshooting-and-questions)
15. [Uninstalling](#15-uninstalling)
16. [Windows and Linux (alpha)](#16-windows-and-linux-alpha)

---

## 1. Installing and opening the app

Fanfic Pairings is built from its source code on your Mac (see the [README](../README.md#install)). After `./scripts/build-app.sh` it is in your **Applications** folder as *Fanfic Pairings*. Open it like any other app: from Applications, Launchpad, the Dock or Spotlight (⌘ Space, type "Fanfic").

The first time it opens, the library is empty and the middle of the window says *"Drop EPUB or PDF files here, or click Add Files…"*.

## 2. Adding fanfics

There are four ways to add fanfics. All of them accept single files, several files, or whole folders (subfolders included):

- **Drag** files or folders onto the window. A blue outline shows while you drag.
- Click **+** in the toolbar, or choose **File → Add Files…** (⌘O), and pick files or folders.
- **Drop** files onto the app's icon in the Dock.
- In Finder, right-click a file → **Open With → Fanfic Pairings**.

For each file the app:

1. checks whether exactly the same file is already in the library (see [Duplicates](#9-duplicates));
2. gives the work an ID, and its first-page copy another ID;
3. copies the file into the library, so it keeps working if you later move or delete the original;
4. saves a copy of the first page as a one-page PDF;
5. reads the **Relationship** and **Fandom** fields from that page, plus the title and author.

Your original file is never changed or moved.

When the import is done, a summary appears:

![The import summary](images/import-summary.png)

| Heading | Meaning |
| --- | --- |
| **Added** | Imported, with at least one pairing found |
| **Added, no pairing found** | Imported, but the first page has no Relationship field (for example a gen fic, or a file from a site that doesn't list relationships). It appears under **No Pairing Found** |
| **Already in library** | Exactly the same file was imported before; nothing is added |
| **Could not read** | Not a working PDF or EPUB, a password-protected PDF, or a scanned PDF without text. Nothing is kept |
| **Skipped** | Not a PDF or EPUB (only appears when you add folders) |

Click **OK** to close it.

## 3. The window

The window has three columns:

- **Sidebar (left)**: **All Works** and **No Pairing Found**, with counts, and below them three lists — **Fandoms**, **Characters** and **Pairings** — that start folded.
- **Works list (middle)**: every work that matches the current search or sidebar choice, sorted by title. Each row shows the title, the file type, the author, the fandom and the relationships. Relationships that match your search are highlighted.
- **Details (right)**: the selected work's first page, its fandom(s), relationships, file name and IDs, with buttons to open it.

The toolbar has **+** (add files), the **folder** button (show the library in Finder), the **gear** (Settings) and the **search field**. The line under the window title says how many fanfics are listed.

## 4. Searching

Type into the search field at the top right. The list updates as you type.

| You type | You get works with … |
| --- | --- |
| `Harry/Draco` | a pairing with both Harry and Draco, in either order |
| `Draco/Harry`, `harry / draco`, `HarryPotter/DracoMalfoy` | the same: order, spaces and upper/lower case don't matter |
| `Draco` | Draco in any relationship (pairing or friendship) |
| `Harry & Ron` | a friendship tag with both (`Harry Potter & Ron Weasley`) |
| `Pansy/Hermione` | also poly pairings such as `Hermione Granger/Pansy Parkinson/Ginny Weasley` |
| `chloe` | `Chloé` — accents don't matter |
| (empty) | everything |

**Parts of names** work when they are the start of a word: `Hotch/Reid` finds *Aaron Hotchner/Spencer Reid*, `Dupain` finds *Marinette Dupain-Cheng*. Letters in the middle of a word don't count, so `Ron` does not find *Aaron* or *Veronica*. Names with alternatives, like AO3's `Lan Zhan | Lan Wangji`, are found by either name.

A search with `/` only finds pairings (romantic tags); a search with `&` only finds friendship tags; a single name finds both.

The search looks at the **Relationship** field only. Fandoms are browsed through the sidebar (next section); the separate *Characters:* field and other tags on the first page are not used.

## 5. Browsing by fandom, character and pairing

The three lists in the sidebar start folded. **Click a list's name** (or the small arrow that appears when you point at it) to open or fold it. The app remembers which lists you left open.

- **Fandoms** — every fandom in your library once, with the number of fanfics. **Click a fandom** to see only its works; the search field then searches *inside* that fandom, and the line under the title shows the fandom's name. A crossover (a work with several fandoms) is listed under each of them. Click **All Works** to leave the fandom.
- **Characters** — everyone who appears in a pairing or friendship tag, once each. **Click a character** to search for them (their name goes into the search field). This list is made from the relationship tags, not from the first page's separate *Characters:* field. Different spellings of the same name (case, accents, spacing) count as one; alternative names such as `Tom Riddle` and `Tom Riddle | Voldemort` stay separate entries. Because a name search also finds names that *start* with it, clicking `Tom Riddle` also finds works tagged `Tom Riddle | Voldemort`.
- **Pairings** — every pairing once. `A/B` and `B/A` are one entry, shown in the spelling used most often. **Click a pairing** to search for it.

![A fandom selected, with a search inside it](images/fandom-search-dark.png)

## 6. The details column

Select a work in the middle column to see:

- its **first page** (the saved copy);
- **Fandom(s)**, **Relationships**, the original **file** name and which page was used as the first page;
- the **Work ID** and **First-page ID** (you can select and copy them).

Buttons:

- **Open Fanfic** — opens the library's copy in your default app for that file type (for example Books for EPUB, Preview for PDF);
- **Open First Page** — opens the first-page copy;
- **Show in Finder** — shows the library's copy of the file.

The same commands, plus **Remove from Library…**, are in the right-click menu of every work in the middle column.

## 7. Settings

Open Settings with the **gear** button or **Fanfic Pairings → Settings…** (⌘,).

![Settings](images/settings.png)

- **Sidebar** — show or hide **Fandoms**, **Characters** and **Pairings**, and sort these lists by **Name** (A–Z) or by **Number of fanfics** (largest first).
- **Relationships** — **Include friendship tags (A & B)**. When off, `A & B` tags are left out of the Pairings list, and people who only appear in friendship tags are left out of Characters. Searching is not affected.
- **Library** — where the library folder is, how many fanfics and first pages it holds, **Show in Finder** and **Re-read Library**.
- **Offline** — a reminder that the app never connects to the internet.

Settings are stored in the app's preferences on your Mac.

## 8. Where your files are

Click the **folder** button (or **File → Show Library in Finder**). The library folder is:

```
~/Library/Application Support/Fanfic Pairings/
├── Works/          a copy of each fanfic, named by its work ID
├── First Pages/    a copy of each first page (PDF), named by its first-page ID
└── library.json    the lists
```

`library.json` is a text file you can open in any text editor. It contains:

- **works** — every work with its work ID, first-page ID, original file name, title, author, relationships and fandoms;
- **pairings**, **characters**, **fandoms** — each name once, A–Z;
- **pairingIndex**, **characterIndex**, **fandomIndex** — each name with the work ID and first-page ID of every work that has it.

**Backups and moving to another Mac:** quit the app and copy the whole *Fanfic Pairings* folder. To restore it, put the folder back in the same place (`~/Library/Application Support/`) before opening the app. In Finder, use **Go → Go to Folder…** (⇧⌘G) and paste `~/Library/Application Support` to get there.

## 9. Duplicates

The app recognises a duplicate when the **file is exactly the same**, byte for byte, even if it was renamed. Such a file is not imported again; the summary lists it under *Already in library* with the title of the work it matches.

The same story in a *different* file is currently imported as a separate work — for example a fresh download after new chapters were posted, or the EPUB and the PDF of the same fic. If that happens, remove the copy you don't want (next section).

## 10. Removing works and re-reading the library

- **Remove a work**: right-click it in the middle column → **Remove from Library…** and confirm. The library's copy of the file, its first-page copy and its entries in `library.json` are deleted. Your original file is not touched.
- **Re-read Library** (**File** menu or Settings): reads every stored work again with the current rules — useful after an update of the app improves how files are read. IDs stay the same; first-page copies, pairings and fandoms are replaced.

## 11. Which files work best

- **AO3 downloads** (EPUB and PDF) work best: their first page lists *Fandom:*, *Relationship:* and *Characters:* in a fixed layout. Singular and plural labels (`Relationship:` / `Relationships:`), names broken over two lines, poly pairings, friendship tags and crossovers are all handled.
- **Other sites and tools** (for example FicHub exports) are imported, but if their first page has no Relationship or Fandom field, the work appears under *No Pairing Found* and in no fandom.
- **EPUB "first page"**: EPUBs have no fixed pages, so the first page is the first section with text (cover images are skipped). It is drawn as a simple one-page PDF from its text. If that section has no Relationship field, the next two are checked.
- **PDF first page**: page 1; if page 1 has no Relationship field, pages 2 and 3 are checked.
- **Scanned PDFs** (pictures of pages, no text) can't be read.

## 12. Big libraries

Measured with made-up libraries on an Apple Silicon Mac:

| Fanfics | Opening the app | One search | Sidebar lists after an import or removal |
| --- | --- | --- | --- |
| 1,000 | instant | instant | under 0.1 s |
| 10,000 | about 1 s | about 0.03 s | about 0.4 s |
| 25,000 | about 1–2 s | under 0.1 s | about 1 s |

During a big import the app saves its list at most every few seconds, so importing stays fast. The slowest thing is opening the **Pairings** list when it holds tens of thousands of *different* pairings (a few seconds for 45,000).

## 13. Privacy

- The app has no network code and cannot connect to the internet.
- It has no accounts, no analytics and no tracking.
- It reads only the files you give it and writes only into its library folder and its preferences.

## 14. Troubleshooting and questions

**A work shows "No pairing found" but it has a pairing.**
Its first page probably doesn't use the `Relationship:` label (common with non-AO3 files). Check the first-page copy with **Open First Page**. If it is an AO3 file and the pairing is clearly there, please [report it](https://github.com/lumierecoding/fanfic-pairings/issues) with the Relationship line from that page.

**A pairing is read wrongly.**
Same as above — report the Relationship line. After a fix, use **Re-read Library**; your IDs stay the same.

**"Could not read" for a PDF.**
The PDF is damaged, password-protected, or a scan without text.

**The same story appears twice.**
It was imported from two different files (see [Duplicates](#9-duplicates)); remove one.

**I don't see Fandoms, Characters or Pairings in the sidebar.**
They may be folded (click their names) or hidden in Settings.

**Reset the app's settings.**
Quit the app and run in Terminal: `defaults delete io.github.lumierecoding.fanficpairings`. Your library is not affected.

**The app says the library file could not be read.**
The app keeps the unreadable file as `library-unreadable-<date>.json` in the library folder and starts with an empty list; nothing is overwritten. Restore a backup of `library.json` if you have one.

## 15. Uninstalling

1. Quit the app and move **Fanfic Pairings** from Applications to the Trash.
2. To remove your library too, delete `~/Library/Application Support/Fanfic Pairings` (this deletes the copies of your fanfics and first pages, not your originals).
3. To remove its settings, run `defaults delete io.github.lumierecoding.fanficpairings` in Terminal.

## 16. Windows and Linux (alpha)

> **Alpha — not tested on Windows or Linux.** The Windows/Linux version is developed and tested on macOS only. Installation: [desktop/README.md](../desktop/README.md).

It works like the Mac app described above — same reading rules, search, sidebar lists, Settings and library folder — with these differences:

| Mac app | Windows / Linux version |
| --- | --- |
| Menus in the Mac menu bar | Menu bar inside the window: **File** (Add Files… Ctrl+O, Re-read Library, Show Library Folder, Settings… Ctrl+,, Quit Ctrl+Q) and **Help** (About) |
| Show in Finder | **Show in Explorer** (Windows), **Show in Folder** (Linux: opens the folder) |
| Number of fanfics under the window title | In the **status bar** at the bottom |
| — | A **notice bar** under the toolbar says it is an alpha; × hides it until the next start |
| Library in `~/Library/Application Support/Fanfic Pairings` | Windows `%APPDATA%\Fanfic Pairings`, Linux `~/.local/share/Fanfic Pairings` |
| Settings in the Mac app's preferences | Windows registry `HKEY_CURRENT_USER\Software\Fanfic Pairings`; Linux `~/.config/Fanfic Pairings/Fanfic Pairings.conf` |

Both versions write the same `library.json`, so a library folder can be moved between a Mac and a Windows or Linux computer. Don't open the same library folder in two apps at the same time.

![The Windows/Linux version with a fandom selected (shown running on macOS)](images/desktop-fandom-search-dark.png)

