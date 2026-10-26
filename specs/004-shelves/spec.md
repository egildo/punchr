# Feature Specification: Shelves, sidebar rows of links

**Feature Branch**: `shelves-round`

**Created**: 2026-10-25

**Status**: Draft

**Input**: User description: "Shelves: sidebar rows of links, one SF Symbol each, declared in
the punch"

## User Scenarios & Testing *(mandatory)*

Finder's sidebar has no supported way to add rows or change their icons, but a File Provider
domain gets its own row, with its own SF Symbol, beside iCloud Drive and OneDrive. The spike of
2026-10-25 (`notes/2026-10-25-shelf-spike.md`) showed that punchr can make such a row with an
ad-hoc signed extension, and that a row holding only links opens the real folders and copies
nothing. A **shelf** is such a row: a name, one SF Symbol, and links to folders and files that
stay where they are.

### User Story 1 - A shelf in the sidebar (Priority: P1)

Egildo declares a shelf named "Clients", with the symbol `person.2`, in his `client` punch, and
puts three client folders on it with `punchr shelve`. Finder's sidebar gains a row "Clients" with that symbol; inside
it are three links, and opening one opens the real folder on `/Volumes/Projects`.

**Why this priority**: the row with its own symbol is the whole improvement; links inside it make
it useful.

**Independent Test**: declare a shelf with a symbol in a scratch punch, put one scratch folder
on it, and see the row and the link in Finder.

**Acceptance Scenarios**:

1. **Given** a punch declaring a shelf "Clients" with symbol `person.2` and one folder on it,
   **When** the shelf is set up for the first time, **Then** the sidebar shows a row "Clients"
   with that symbol, and punchr says that Finder will ask once to enable it.
2. **Given** the shelf is enabled, **When** Egildo opens it, **Then** it lists one link per
   folder or file on it, under the item's own name, and opening a link opens the real item.
3. **Given** a shelf showing its links, **When** Finder shows them, **Then** no link carries a
   sync error mark.
4. **Given** two shelves declared in punches, **When** both are set up, **Then** the sidebar
   shows two rows, each with its own name and symbol.

---

### User Story 2 - Change what is on a shelf (Priority: P2)

A project ends; `punchr unshelve` takes its folder off the "Clients" shelf, and `shelve` puts a
new one on. The shelf's row
stays where it is, and its links change.

**Why this priority**: a shelf whose contents cannot change is a one-off.

**Independent Test**: put a scratch folder on a shelf, take it off, put another on, and watch
the open shelf in Finder.

**Acceptance Scenarios**:

1. **Given** a shelf with links, **When** an item is added or removed, **Then** the open shelf
   in Finder shows the change without restarting Finder and without enabling the shelf again.
2. **Given** an item already on a shelf, **When** it is added again, **Then** nothing changes.
3. **Given** a shelf, **When** its contents are read, **Then** punchr lists each link with its
   target and whether the target still exists.

---

### User Story 3 - Take a shelf away (Priority: P3)

When a shelf is no longer declared, its row leaves the sidebar, and nothing it linked to is
touched.

**Independent Test**: set up a shelf on scratch folders, remove it, and check that the row and
its folder under `~/Library/CloudStorage` are gone and the scratch folders are unchanged.

**Acceptance Scenarios**:

1. **Given** a shelf, **When** it is taken away, **Then** its row leaves the sidebar and every
   linked folder and file is byte for byte as before.

---

### Edge Cases

- A linked folder or file is moved or renamed: each link is a Finder alias, so Finder follows it
  where an alias can (Egildo, 2026-10-26: "aliases may follow moved folders, that's fine"). An
  item that is deleted leaves a link that opens nothing, and `punchr shelves` reports it missing.
- A linked item sits on a volume that is not mounted: the link opens nothing until the volume
  returns, as any alias does.
- Someone drags a file onto a shelf or renames a link in Finder: the shelf refuses the change
  quietly and keeps its links; nothing is written to the linked items.
- Two links on one shelf would have the same name (two folders called `docs`): each still gets
  its own row inside the shelf, with a distinguishing suffix.
- An SF Symbol name that does not exist: punchr cannot check it; Finder draws a blank or a
  generic symbol. The punch documentation says to pick names from Apple's SF Symbols app.
- The app is rebuilt or upgraded by Homebrew (which moves it to a new folder): the shelves must
  survive, or punchr must restore them with one command, without asking Egildo to enable them
  again if the system allows that.
- The shelf has never been enabled: Finder shows its banner; punchr's own output says so.

## Requirements *(mandatory)*

### Functional Requirements

**Declaring**

- **`punch-declares-shelves`**: A punch MUST be able to declare shelves, each with a name shown
  in the sidebar and one SF Symbol name.
- **`a-shelf-owns-no-attributes`**: Declaring, filling or removing a shelf MUST write nothing on
  the folders and files it links to.
- **`how-items-reach-a-shelf`**: Callers MUST be able to put folders and files on a shelf and
  take them off with commands, as `strike` and `clear` do for looks: `shelve` puts items on a
  shelf, `unshelve` takes them off, each showing its plan first. The punch declares the shelf;
  its list of items lives with the shelf, not in the punch file (Egildo, 2026-10-25).

**Showing**

- **`one-row-per-shelf`**: Each set-up shelf MUST appear as its own sidebar row with its own
  name and symbol.
- **`links-not-copies`**: A shelf MUST hold only links to the real items, each a Finder alias; it
  MUST NOT copy, move or sync their contents.
- **`no-error-marks`**: Finder MUST show the links without sync error marks; changes Finder
  tries to make inside a shelf are refused quietly or ignored.
- **`say-when-enabling-is-needed`**: When a shelf is set up and not yet enabled, punchr MUST say
  that Finder will ask once to enable it, and where.

**Changing and reading**

- **`change-without-re-enabling`**: Adding or removing items MUST update the shelf in an open
  Finder window without enabling it again.
- **`read-a-shelf`**: punchr MUST list a shelf's links with their targets and whether each
  target exists, also as JSON.
- **`shelves-survive-a-rebuild`**: After a rebuild or a Homebrew upgrade, shelves MUST come back
  with their items, at most by one punchr command.
- **`take-a-shelf-away`**: Removing a shelf MUST remove its row and its folder under
  `~/Library/CloudStorage`, and nothing else.

### Key Entities

- **Shelf**: declared in a punch (a name for the sidebar row, one SF Symbol); its list of items
  is kept with the shelf and changed by `shelve` and `unshelve`.
- **Link**: an item on a shelf, shown by Finder as an alias; its name in the shelf and the path
  of the real folder or file it points to. A link to something missing is still a link.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **`row-with-its-symbol`**: A declared shelf appears in Finder's sidebar with its own name and
  symbol, after a single enable click the first time.
- **`opens-the-real-folder`**: Opening a link opens the real folder, in one click from the
  sidebar row.
- **`nothing-touched`**: After setting up, filling, emptying and removing a shelf, every linked
  folder and file is byte for byte as before.
- **`change-seen-quickly`**: An item added to or removed from a shelf appears or disappears in
  an open Finder window within 5 seconds.
- **`no-error-marks-seen`**: No link on a shelf shows a sync error mark in Finder.

## Assumptions

- The shelf lives in Punchr.app beside the Finder Sync extension; one app, two extensions.
- Ad-hoc signing and the Command Line Tools are enough, as the spike showed; the sidebar symbol is
  a standard SF Symbol named in the extension's settings, with no custom artwork.
- Finder asks once per shelf to enable it, and that click is Egildo's; punchr never tries to
  bypass it.
- The row's place in the sidebar (beside iCloud Drive and OneDrive) is Finder's choice and
  cannot be moved by punchr.
- Settled by the plan's research: the symbol belongs to an extension, never to a shelf, so each
  shelf gets its own small app, generated from a template and signed ad hoc; a lone shelf in its
  own app is shown under the app's name, so the row reads exactly as the shelf is named, spaces
  kept ("Old Work").
- Shelves are independent of looks and badges: a shelf writes nothing on what it links to, so
  the constitution's live/written distinction does not apply to it.
