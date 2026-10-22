# Feature Specification: The punch, with read, strike and clear for written looks

**Feature Branch**: `punch-and-strike-round`

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description: "The punch file with read, strike and clear for written looks"

## User Scenarios & Testing *(mandatory)*

The user is anyone, or any program, that wants folders to show what they are: Egildo by hand,
tabularium from a script. They write a **punch** once: a file that names a set of **looks** and
says what each looks like in Finder. Then they strike a look onto folders, read back what
folders wear, and clear a punch's looks away. This feature covers **written looks** only, the
ones stored on the folder itself: tags with their colours, a stamp, a custom icon. Badges, the
live looks, are a later feature.

### User Story 1 - Strike a look onto folders (Priority: P1)

The user has a punch named `client` with a look `zente` (a custom icon from the client's logo
and a grey tag `client`). They run `punchr strike client zente` on twelve project folders.
punchr shows a plan, folder by folder: what it will add, what it will remove, what is already
in place. At a terminal it asks before writing; with `--force` it writes without asking. The
folders then wear the logo and the tag in Finder, and nothing else about them has changed.

**Why this priority**: striking is the reason the tool exists. Without it there is nothing to
read or clear.

**Independent Test**: on a scratch folder, write a punch with one look, strike it, and see the
look in Finder; compare every attribute of the folder before and after.

**Acceptance Scenarios**:

1. **Given** a folder wearing nothing, **When** the user strikes a look with a tag, a stamp
   and no icon, **Then** the plan lists the tag and the stamp as additions, and after the strike
   Finder shows the tag's colour and the stamp.
2. **Given** a folder that already wears a tag the punch does not own, **When** the user strikes
   a look, **Then** that tag is still there, in its place, after the strike.
3. **Given** a folder already wearing the look, **When** the user strikes it again, **Then** the
   plan says nothing is to change and nothing is written.
4. **Given** the user's output goes to a pipe or `--json` is passed, **When** the user strikes
   without `--force`, **Then** punchr prints the plan and writes nothing.
5. **Given** twelve folders on one volume and a look with a custom icon, **When** the user
   strikes it on all twelve, **Then** the icon's bytes are on disk once, shared by every folder.
6. **Given** a folder wearing the punch's look `ahead`, **When** the user strikes the same
   punch's look `behind`, **Then** the plan replaces what `ahead` put there with what `behind`
   needs: a folder wears one look of a punch at a time. Combining looks takes two punches that
   own different things.

---

### User Story 2 - Read what folders wear (Priority: P2)

The user, or tabularium, runs `punchr read` on folders. For each folder punchr reports what it
wears (its tags with colours, its stamp, whether it has a custom icon) and, for each punch it
knows, which look the folder matches, if any. `--json` gives the same answer for a program.

**Why this priority**: it lets a caller check before striking and after, and lets the user see
what a folder carries without opening Get Info. Strike's plan rests on the same reading.

**Independent Test**: dress a scratch folder by hand in Finder (a tag, a stamp), run `read`, and
compare with what Finder shows.

**Acceptance Scenarios**:

1. **Given** a folder dressed by hand in Finder with a yellow tag, **When** the user reads it,
   **Then** punchr reports the tag and its colour, and that it matches no look.
2. **Given** a folder struck with the look `zente`, **When** the user reads it, **Then** punchr
   reports that it matches `client` / `zente`.
3. **Given** `--json`, **When** the user reads several folders, **Then** the output is one JSON
   document a program can parse, one entry per folder, in the order given.

---

### User Story 3 - Clear a punch's looks (Priority: P3)

The project for a client is over. The user runs `punchr clear client` on its folders. punchr
removes what the punch `client` owns and leaves everything else, with the same plan and the
same confirmation as strike.

**Why this priority**: looks must be removable without hunting for attributes by hand, but a
user can live a while without it.

**Independent Test**: strike a look on a scratch folder that already wears other tags, clear the
punch, and compare the folder with its state before the strike.

**Acceptance Scenarios**:

1. **Given** a folder that wore tag `red-team` before a look was struck on it, **When** the user
   clears the punch, **Then** the folder wears `red-team` and nothing of the punch.
2. **Given** a folder struck with a custom icon shared with other folders, **When** the user
   clears one folder, **Then** that folder loses the icon and the others keep theirs.
3. **Given** a folder that wears nothing the punch owns, **When** the user clears it, **Then** the
   plan says nothing is to change and nothing is written.

---

### Edge Cases

- The punch file has a mistake (an unknown key, a colour that does not exist, a look that uses
  something the punch does not own): punchr names the problem and where it is, and changes no
  folder.
- The look named does not exist in the punch, or is a badge look: punchr says so and changes
  no folder.
- A path is a file, a symbolic link or an alias rather than a folder: punchr reports it as not a
  folder and leaves it alone; the other folders proceed.
- A folder cannot be written (permissions, a locked folder, a read-only volume) or lives on a
  volume that keeps no extended attributes (FAT, exFAT, some network shares): that folder is
  reported as failed, the others proceed, and the exit status says something failed.
- The icon picture is missing or cannot be read: punchr refuses the strike before writing
  anything.
- Folders on two volumes share one icon look: each volume gets one copy, shared by its folders.
- A stamp names a character from an installed icon font: Finder shows a "?" box. punchr does
  not try to detect this; the punch documentation says which kinds of stamp work.
- The folder is inside a git repository and gets a custom icon: the hidden icon file shows up as
  untracked in git. punchr does not change any gitignore; the README says to add `Icon?` to the
  global one.
- Finder is showing the folder while it is struck: the new look appears without restarting
  Finder.

## Requirements *(mandatory)*

### Functional Requirements

**The punch**

- **`punch-names-its-looks`**: A punch MUST have a name and a set of looks, each look named and
  made of any of: tags, each with one of Finder's seven colours or none; a stamp (an SF Symbol
  name, an emoji or a short word); a custom icon from a picture file.
- **`punch-declares-what-it-owns`**: A punch MUST list what it owns: the tags it may add or
  remove, and whether it owns the folder's stamp and its custom icon. Owning is a declaration:
  a punch that owns the stamp may replace or remove any stamp, including one set by hand, and
  the plan shows it before it goes.
- **`one-look-per-punch`**: A folder MUST wear at most one look of each punch; striking a look
  MUST replace whatever the punch's other looks put there.
- **`refuse-a-broken-punch`**: punchr MUST check the whole punch before touching any folder and
  refuse it, naming each problem and its place in the file, when a look uses something the punch
  does not own, a colour is not one of the seven, or a key is unknown.
- **`badge-looks-are-not-struck`**: A punch MAY also declare badge looks; read, strike and clear
  MUST ignore them, and striking one MUST be refused with a message that it is drawn live.
- **`find-punches-by-name`**: punchr MUST find a punch by name in the user's punch folder, or
  take a path to a punch file.

**Read**

- **`read-what-it-wears`**: `read` MUST report, for each folder given, its tags with colours, its
  stamp and whether it has a custom icon.
- **`read-which-look-matches`**: `read` MUST report, for each known punch, the look the folder
  matches, or none.
- **`read-answers-json`**: `read`, `strike` and `clear` MUST answer `--json` with one document a
  program can parse, folder by folder, in the order given.
- **`read-writes-nothing`**: `read` MUST NOT change anything on disk.

**Strike and clear**

- **`plan-before-writing`**: `strike` and `clear` MUST show, for each folder, what they will add,
  remove and leave, before writing anything.
- **`ask-at-a-terminal`**: At a terminal, `strike` and `clear` MUST ask yes or no before writing,
  unless `--force` is given; with `--json` or when output is a pipe, they MUST stop at the plan
  unless `--force` is given.
- **`plan-is-what-happens`**: What a forced write changes MUST be exactly what its plan listed.
- **`keep-unowned-tags`**: `strike` and `clear` MUST leave every tag the punch does not own on
  the folder, in its order.
- **`write-the-colour-number`**: Every tag punchr writes MUST carry its colour explicitly, never
  relying on the user's own tag list.
- **`set-only-the-icon-bit`**: punchr MUST set and clear the folder's custom-icon flag alone,
  leaving every other part of the folder's Finder information as it found it.
- **`strike-twice-changes-nothing`**: Striking a look on a folder that already wears it MUST
  plan no change and write nothing; the same for clearing a folder that wears nothing the punch
  owns.
- **`share-one-icon-per-volume`**: When a strike gives several folders on one volume the same
  icon, the icon's bytes MUST be stored once on that volume and shared.
- **`clear-one-keeps-the-others`**: Clearing a folder's shared icon MUST NOT affect the other
  folders sharing it.
- **`fail-per-folder`**: A folder that cannot be read or written MUST be reported and skipped;
  the other folders proceed; the exit status MUST be non-zero when any folder failed.
- **`folders-only`**: punchr MUST act only on folders, and MUST NOT follow symbolic links or
  aliases.

### Key Entities

- **Punch**: a named file, written once by the user. Holds its looks and what it owns. Several
  punches can exist; each dresses folders independently within what it owns, and a folder wears
  at most one look of each.
- **Look**: a named way of dressing a folder, inside one punch. Written looks are made of tags,
  a stamp and a custom icon; badge looks are drawn live and belong to a later feature.
- **Dress**: what a folder wears right now, as read from the folder: tags with colours, stamp,
  custom icon. Read reports it; strike and clear change the owned part of it.
- **Plan**: for each folder, the additions, removals and things left as they are, computed from
  the dress and the punch before anything is written.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **`nothing-unowned-changes`**: After a strike and after a clear, every attribute of the folder
  that the punch does not own is byte for byte what it was before.
- **`strike-then-clear-restores`**: A folder that wore nothing the punch owns, struck and then
  cleared, is byte for byte what it was before the strike.
- **`icon-costs-kilobytes`**: A hundred folders on one volume wearing one icon look built from a
  flat logo cost under 25 KB of disk for the icon, in total (amended from 10 KB by the plan:
  see research, "Rendering the custom icon").
- **`seen-without-restart`**: A struck look appears in an open Finder window within 5 seconds,
  without restarting Finder.
- **`read-a-thousand`**: Reading 1,000 folders takes under 5 seconds.
- **`plan-matches-write`**: In every test, the folders' state after a forced write equals the
  plan's prediction.

## Assumptions

- Mac only, macOS 26 (Tahoe) and later; stamps need Tahoe. Folders on older systems seen through
  sync show a plain folder.
- The user's punch folder is `~/.config/punchr/`, beside tabularium's `~/.config/tabularium/`; a
  name on the command line means the punch file of that name there.
- The punch file format (likely YAML, as sketched in the findings) is settled in the plan, not
  here.
- Finder comments are out of scope: where they are stored was measured, but writing one that
  Finder shows was not.
- Folder window options (view style, background, icon positions) are out of scope.
- punchr knows nothing of git or tabularium; tabularium calls punchr like any other program.
- Writing a look onto a folder changes its attributes, which tabularium's record carries; that
  is the point of a written look.
- Testing happens on scratch folders only, as the constitution asks.
