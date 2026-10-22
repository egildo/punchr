---

description: "Tasks for the punch, with read, strike and clear for written looks"
---

# Tasks: The punch, with read, strike and clear for written looks

**Input**: Design documents from `specs/001-punch-and-strike/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/cli.md](contracts/cli.md), [quickstart.md](quickstart.md)

**Checks**: included. The constitution asks that every mechanism leave a check; they are assert
functions in `Sources/checks/main.swift`, each named after the requirement or outcome it proves,
and run by `./build.sh check` in a fresh temporary folder that is deleted after. A check never
touches a folder outside that temporary folder.

**Organization**: grouped by user story. Strike (US1) is the minimum worth having; read (US2)
and clear (US3) each add one verb on the same core.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: the user story the task belongs to (US1, US2, US3)

---

## Phase 1: Setup

**Purpose**: the new layout and the build, with nothing new yet.

- [x] T001 Move `Sources/FinderSync.swift` to `Sources/finder/FinderSync.swift` and `Sources/main.swift` to `Sources/app/main.swift` with `git mv`; create empty `Sources/core/` and `Sources/checks/`
- [x] T002 Update `build.sh`: compile the app from `Sources/core/*.swift Sources/app/main.swift` with `-framework Cocoa`, the extension from `Sources/finder/FinderSync.swift`; add `ln -sf Punchr.app/Contents/MacOS/Punchr build/punchr`; add `./build.sh check`, which compiles `Sources/core/*.swift Sources/checks/main.swift` into `build/checks` and runs it; keep `./build.sh register` as it is
- [x] T003 Write `Sources/checks/main.swift` with the skeleton every check uses: make a fresh folder under `FileManager.default.temporaryDirectory`, a `check(_ name: String, _ body: () throws -> Void)` that prints `✓ name` or `✗ name: reason` and counts failures, delete the folder at the end, exit 1 if any check failed
- [x] T004 Run `./build.sh` and `./build.sh check`; both succeed (no checks yet)

---

## Phase 2: Foundational

**Purpose**: reading a punch and reading and writing one folder's dress. Every story needs these.

**⚠️ No story starts before this phase is done.**

- [x] T005 [P] In `Sources/core/Punch.swift`, define `Colour` with the cases and numbers "`none` 0, `grey` 1, `green` 2, `purple` 3, `blue` 4, `yellow` 5, `red` 6, `orange` 7", `Tag` (name and colour), `Stamp` (`.sym(String)` or `.emoji(String)`), `Look` (name, tags in order, stamp, icon path, `isBadge`) and `Punch` (name, owned tags, `ownsStamp`, `ownsIcon`, looks)
- [x] T006 In `Sources/core/Punch.swift`, read a punch: decode the file with `JSONSerialization` and `.json5Allowed` (lists keep their order: `tags` is a list of one-key maps), take the name from the file name without `.json5`, resolve icon paths against the punch file's folder, and find a punch by name in `$XDG_CONFIG_HOME/punchr/` (default `~/.config/punchr/`) or by path when the argument contains `/` or ends in `.json5`
- [x] T007 In `Sources/core/Punch.swift`, check a punch and collect every problem with its path in the file (`looks.zente.tags[1]`): an unknown key anywhere; "a colour that is not one of the eight names"; "a look's tag not listed in `owns.tags`"; "a look with a stamp when `owns.stamp` is not `true`, or an icon when `owns.icon` is not `true`"; "a look with both a badge and any written part"; a written look with none of `tags`, `stamp`, `icon`; an icon picture that does not exist or that `NSImage` cannot load (`refuse-a-broken-punch`)
- [x] T008 [P] In `Sources/core/Dress.swift`, read and write extended attributes through Darwin `getxattr`, `setxattr`, `removexattr`, `listxattr`, always with `XATTR_NOFOLLOW`; a missing attribute reads as `nil`; errors carry the folder and `strerror`
- [x] T009 In `Sources/core/Dress.swift`, read a folder's dress: tags in order from `com.apple.metadata:_kMDItemUserTags` (binary property list of `"name\nN"` strings; a tag with no number reads as `none`), the stamp from `com.apple.icon.folder#S` (JSON `{"sym": …}` or `{"emoji": …}`), and the custom-icon bit (byte 8, `0x04`) of `com.apple.FinderInfo`; refuse anything that is not a folder by `lstat`, so links and aliases are never followed (`folders-only`)
- [x] T010 In `Sources/core/Dress.swift`, write tags (always with the colour number, `write-the-colour-number`; remove the attribute when no tag is left), write or remove the stamp, and set or clear the custom-icon bit alone, keeping the other 31 bytes of `com.apple.FinderInfo` and removing the attribute when all 32 bytes end up zero (`set-only-the-icon-bit`)
- [x] T011 [P] In `Sources/checks/main.swift`, check `refuse-a-broken-punch`: a punch with an unknown key, a bad colour, an unowned tag and a stamp it does not own is refused with four problems, each with its path
- [x] T012 [P] In `Sources/checks/main.swift`, check the dress round trip: write tags with colours, a stamp and the icon bit on a temporary folder, read them back equal; write Finder information with other bytes set beforehand, set and clear the icon bit, the other bytes are unchanged (`set-only-the-icon-bit`)
- [x] T013 Run `./build.sh check`: T011 and T012 pass

**Checkpoint**: punches are read and checked, one folder's dress is read and written.

---

## Phase 3: User Story 1 - Strike a look onto folders (Priority: P1) 🎯 MVP

**Goal**: `punchr strike <punch> <look> <folder>...` plans, asks or stops, and dresses the
folders, touching only what the punch owns.

**Independent Test**: on a scratch folder, strike a look with a tag, a stamp and an icon, see it
in Finder, and compare every attribute of the folder before and after.

- [x] T014 [P] [US1] In `Sources/core/Icon.swift`, render a picture with `NSImage` at 128 and 512 px into PNGs, build an `icns` holding only `ic07` and `ic09`, and wrap it in a resource fork with one `icns` resource, id -16455, laid out as in `experiments/lean-icon.ts`
- [x] T015 [US1] In `Sources/core/Icon.swift`, put an icon on a folder: create the empty `Icon\r` with the fork in `com.apple.ResourceFork` and the invisible bit (`0x40`) in byte 8 of its own Finder information, or hard-link it to an `Icon\r` already written in this run on the same volume (same `st_dev`), then set the folder's icon bit through `Dress.swift`; remove an icon by unlinking the folder's `Icon\r` and clearing the bit; read the fork of a folder's `Icon\r` for comparison
- [x] T016 [US1] In `Sources/core/Plan.swift`, compute the strike plan for one folder from its dress and look L of punch P, as `data-model.md` says: remove every owned tag L does not have or has with another colour; add L's missing tags at the end in L's order; if P owns the stamp, set L's or remove it; if P owns the icon, set L's (compare the existing fork with the rendered bytes) or remove it; everything else is left (`keep-unowned-tags`, `one-look-per-punch`); an empty plan writes nothing (`strike-twice-changes-nothing`)
- [x] T017 [US1] In `Sources/core/Plan.swift`, carry out a plan for a list of folders: render each look's icon once, write folder by folder, report a folder that fails and go on (`fail-per-folder`)
- [x] T018 [US1] In `Sources/app/main.swift`, parse the arguments by hand (`read`, `strike`, `clear`, `--force`, `--json`) and wire `strike`: refuse an unknown look or a badge look with status 2 (`badge-looks-are-not-struck`), print the plan (terminal lines as in `contracts/cli.md`, or the JSON document), then write with `--force`, ask `Strike? [y/N]` when standard input and output are a terminal (`isatty`), or stop at the plan otherwise (`ask-at-a-terminal`); exit 0, 1 when a folder failed, 2 for argument and punch errors
- [x] T019 [P] [US1] In `Sources/checks/main.swift`, check `nothing-unowned-changes` and `keep-unowned-tags`: a folder with two foreign tags, a foreign attribute and Finder information bytes set keeps all of them, the tags in their order, after a strike
- [x] T020 [P] [US1] In `Sources/checks/main.swift`, check `plan-matches-write` and `strike-twice-changes-nothing`: after a forced strike the dress equals what the plan predicted; a second plan is empty and writes no attribute (compare every attribute byte for byte)
- [x] T021 [P] [US1] In `Sources/checks/main.swift`, check `one-look-per-punch`: striking look `behind` on a folder wearing `ahead` of the same punch leaves only `behind`'s parts
- [x] T022 [P] [US1] In `Sources/checks/main.swift`, check `share-one-icon-per-volume` and `icon-costs-kilobytes`: twelve folders struck with `experiments/standin.svg` have `Icon\r` files with one inode and a link count of 12, and the fork is under 25 KB
- [x] T023 [P] [US1] In `Sources/checks/main.swift`, check `fail-per-folder` and `folders-only`: a file, a symbolic link to a folder and a folder without write permission among three good folders are reported, the good three are struck, and the run reports failure
- [x] T024 [US1] Run `./build.sh check`: every check so far passes

**Checkpoint**: strike works on its own; this is the minimum worth having.

---

## Phase 4: User Story 2 - Read what folders wear (Priority: P2)

**Goal**: `punchr read <folder>...` reports each folder's dress and, for every known punch, the
look it matches.

**Independent Test**: dress a scratch folder by hand in Finder, run `read`, compare with Finder.

- [ ] T025 [US2] In `Sources/core/Plan.swift`, decide which look of a punch a folder matches, as `research.md` says: everything the punch owns on the folder is exactly what the look puts there, with the icon compared by fork bytes; badge looks never match (`read-which-look-matches`)
- [ ] T026 [US2] In `Sources/app/main.swift`, wire `read`: load every `.json5` in the punch folder, report each folder's dress and matches as terminal lines or the JSON document of `contracts/cli.md`, folder by folder in the order given (`read-what-it-wears`, `read-answers-json`), writing nothing (`read-writes-nothing`)
- [ ] T027 [P] [US2] In `Sources/checks/main.swift`, check `read-which-look-matches` and `read-writes-nothing`: a folder struck with a look matches it; a folder dressed with the same tag in another colour matches nothing; reading changes no attribute
- [ ] T028 [P] [US2] In `Sources/checks/main.swift`, check `read-a-thousand`: reading 1,000 temporary folders takes under 5 seconds
- [ ] T029 [US2] Run `./build.sh check`: every check so far passes

**Checkpoint**: strike and read work on their own.

---

## Phase 5: User Story 3 - Clear a punch's looks (Priority: P3)

**Goal**: `punchr clear <punch> <folder>...` removes what the punch owns, with the same plan and
the same question as strike.

**Independent Test**: strike a look on a scratch folder that already wears other tags, clear the
punch, compare the folder with its state before the strike.

- [ ] T030 [US3] In `Sources/core/Plan.swift`, compute the clear plan: remove every tag the punch owns; remove the stamp if it owns the stamp; remove the icon if it owns the icon (unlinking only this folder's `Icon\r`, `clear-one-keeps-the-others`)
- [ ] T031 [US3] In `Sources/app/main.swift`, wire `clear` with the plan, the question `Clear? [y/N]`, `--force`, `--json` and the exit status of `contracts/cli.md`
- [ ] T032 [P] [US3] In `Sources/checks/main.swift`, check `strike-then-clear-restores`: a folder with a foreign tag and foreign attributes, struck with a look using a tag, a stamp and an icon, then cleared, is byte for byte what it was, with no `Icon\r` left
- [ ] T033 [P] [US3] In `Sources/checks/main.swift`, check `clear-one-keeps-the-others`: of three folders sharing one icon, clearing one leaves the other two with the icon and a link count of 2
- [ ] T034 [US3] Run `./build.sh check`: every check passes

**Checkpoint**: all three verbs work.

---

## Phase 6: Polish

- [ ] T035 Update `README.md`: what a punch is with the example from `contracts/cli.md`, the three verbs, `./build.sh check`, and the note to add `Icon?` to the global gitignore
- [ ] T036 With Egildo, run section 2 of `quickstart.md` in Finder (`seen-without-restart`, and whether a tag's colour shows without the label bits); write what is seen into `notes/2026-10-22-finder-by-eye.md` (or the day it happens); if the colour does not show, amend the spec and `Sources/core/Dress.swift` before the round lands
- [ ] T037 Gate: `./build.sh` and `./build.sh check` both clean; read the spec, plan, contract and code against each other before merging `punch-and-strike-round` into `main` with `--no-ff`

---

## Dependencies & Execution Order

- **Setup** (T001–T004) first; **Foundational** (T005–T013) next; it blocks every story.
- **US1** (T014–T024) needs only the foundation.
- **US2** (T025–T029) needs the foundation; its matching reuses the icon rendering of T014, so
  do it after T014.
- **US3** (T030–T034) needs US1's plan and icon code (T015–T017).
- **Polish** last; T036 needs Egildo.

Within a story: core code, then the command, then checks, then the run.

## Parallel Opportunities

- T005 and T008 (different files).
- T011 and T012 once T007 and T010 are done.
- T014 alongside T016 only if the plan's icon comparison is left to the end of T016.
- The check tasks marked [P] in each story are separate functions in one file; written by one
  person they go one after another, by several they merge cleanly.

### Example: US1

```text
T014 Icon.swift rendering    ┐
T016 Plan.swift strike plan  ┘ then T015, T017, T018, then T019–T023 together, then T024
```

## Implementation Strategy

1. Setup and foundation, with their checks passing.
2. US1, strike: stop and try it on a scratch folder. This is the MVP.
3. US2, read; US3, clear; each checked before the next.
4. Polish, the look in Finder with Egildo, the gate, the merge.
