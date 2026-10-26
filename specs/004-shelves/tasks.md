---

description: "Tasks for shelves, sidebar rows of links"
---

# Tasks: Shelves, sidebar rows of links

**Input**: Design documents from `specs/004-shelves/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md),
[data-model.md](data-model.md), [contracts/cli.md](contracts/cli.md), [quickstart.md](quickstart.md)

**Checks**: included, as the constitution asks. Assert functions in `Sources/checks/main.swift`,
each named after what it proves, run by `./build.sh check` in a temporary folder. Anything that
registers an extension or adds a domain is not a check: it is the quickstart, run with Egildo,
on scratch folders, after asking him (working rules).

**Organization**: grouped by user story. US1 (a shelf in the sidebar) is the minimum worth
having; US2 changes what is on it; US3 takes it away.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1, US2, US3

---

## Phase 1: Setup

**Purpose**: the template app builds inside Punchr.app, with nothing registered.

- [x] T001 Create `Support/Shelf-Info.plist` (app: `CFBundleIdentifier` `local.punchr.shelf.template`, `CFBundleExecutable` `Shelf`, `CFBundleName` `Shelf`, `CFBundlePackageType` `APPL`, `LSUIElement` true, `LSMinimumSystemVersion` 26.0) and `Support/ShelfProvider-Info.plist` (extension: `CFBundleIdentifier` `local.punchr.shelf.template.provider`, `CFBundleExecutable` `ShelfProvider`, package type `XPC!`, `CFBundleIcons.CFBundlePrimaryIcon.CFBundleSymbolName` `books.vertical`, `NSExtension` with point `com.apple.fileprovider-nonui`, principal class `ShelfProvider.Provider`, `NSExtensionFileProviderDocumentGroup` `group.local.punchr.shelf.template`, `NSExtensionFileProviderSupportsEnumeration` true), copied in form from `experiments/shelf/App-Info.plist` and `Ext-Info.plist`
- [x] T002 [P] Create `Support/shelf.entitlements` (app group `group.local.punchr.shelf.template`) and `Support/shelf-provider.entitlements` (app sandbox and the same app group), as in `experiments/shelf/`
- [x] T003 Update `build.sh`: compile `Sources/shelf/main.swift Sources/shelf/Links.swift` with `-swift-version 5 -framework FileProvider` into `Punchr.app/Contents/Resources/Shelf.app/Contents/MacOS/Shelf`, and `Sources/shelf/Provider.swift Sources/shelf/Links.swift` with `-swift-version 5 -parse-as-library -framework FileProvider -Xlinker -e -Xlinker _NSExtensionMain` into `…/Shelf.app/Contents/PlugIns/ShelfProvider.appex/Contents/MacOS/ShelfProvider`; copy the two plists in; sign the extension, the template app, then Punchr.app, all ad hoc; add `Sources/shelf/Links.swift` to the app and checks compiles; never register the template
- [x] T004 Create stubs `Sources/shelf/Links.swift`, `Sources/shelf/Provider.swift`, `Sources/shelf/main.swift`, `Sources/core/Shelves.swift`, so that `./build.sh` and `./build.sh check` pass with no new behaviour

---

## Phase 2: Foundational

**Purpose**: shelves in the punch, and the logic shared by the extension and the command. Every
story needs these.

**⚠️ No story starts before this phase is done.**

- [x] T005 In `Sources/core/Punch.swift`, accept a top-level `shelves` key: a map from key to `{ name, symbol }`; add `shelves: [String: ShelfDecl]` to `Punch`; a punch with only shelves and no looks is valid; problems, each with its path (`shelves.clients.symbol`): an unknown key under a shelf, a missing `name` or `symbol`, a key not matching "lowercase letters, digits and hyphens", a name not "1 to 40 characters, no `/`", a symbol not "letters, digits and dots" (`punch-declares-shelves`)
- [x] T006 [P] In `Sources/shelf/Links.swift`, the link list: parse and write the `userInfo["links"]` string ("absolute paths, newline-joined, in the order shelved"); name each link by its last path component, giving the second and later of the same name " 2", " 3" in shelving order; an item identifier per link that stays the same while the link stays on the shelf; the sync anchor as the list's bytes, and the difference between two anchors as links added and links removed
- [x] T007 [P] In `Sources/checks/main.swift`, check `punch-declares-shelves`: a punch with a valid shelf reads; a punch with each of the five shelf problems is refused with that many problems at the right paths; a punch with only shelves reads
- [x] T008 [P] In `Sources/checks/main.swift`, check the link list: names and suffixes for `/a/docs`, `/b/docs`, `/c/x`; identifiers stable when a link before them is removed; the difference between anchors reports exactly the added and removed links
- [x] T009 Run `./build.sh check`: every check passes, the old ones too

**Checkpoint**: shelves are read from punches; links are named and diffed.

---

## Phase 3: User Story 1 - A shelf in the sidebar (Priority: P1) 🎯 MVP

**Goal**: `punchr shelve` sets a shelf up the first time and puts links on it; Finder shows a row
with the shelf's name and symbol, and the links open the real items.

**Independent Test**: quickstart section 2, steps 1 and 2.

- [x] T010 [US1] In `Sources/shelf/Provider.swift`, the File Provider extension, from `experiments/shelf/Shelf.swift`: the root item, one item per link (first a `.symbolicLink`; after the by-eye test a Finder alias file, research "What a link is"), names from `Links.swift`, enumeration of the root, `enumerateChanges` from the anchor difference (removals as deletions, additions as updates), `currentSyncAnchor` from the current list; log the link count with `os.Logger`, subsystem `local.punchr`, category `shelf`
- [x] T011 [US1] In `Sources/shelf/Provider.swift`, quiet writes (`no-error-marks`): `modifyItem` answers with the item unchanged and no error; `createItem` and `deleteItem` answer `NSFileProviderErrorExcludedFromSync`; `fetchContents` stays refused (links have no contents)
- [x] T012 [P] [US1] In `Sources/shelf/main.swift`, the template app's executable: `add <id> <name> <links-file>` adds or re-adds its domain with `userInfo["links"]` read from the file, then signals the root enumerator; `remove <id>`; `status <id>` prints the domain's display name, `userEnabled` and links as JSON; each waits on the main run loop, as the spike's host did, and exits 1 with the error on stderr
- [x] T013 [US1] In `Sources/core/Shelves.swift`, generate a shelf's app: copy `Punchr.app/Contents/Resources/Shelf.app` to `~/Library/Application Support/punchr/Shelves/<name>.app`; with `/usr/bin/plutil` set app `local.punchr.shelf.<punch>.<key>`, `CFBundleName` and `CFBundleDisplayName` to the shelf's name, extension `….provider`, its symbol, and app group `group.local.punchr.shelf.<punch>.<key>` in both plists; write both entitlements with that group; sign extension then app ad hoc with `/usr/bin/codesign`; register with `lsregister -f -R` and `pluginkit -a`; a failure at any step is reported for that shelf, status 1
- [x] T014 [US1] In `Sources/core/Shelves.swift`, the plan for `shelve`: whether the shelf must be set up first, each item `+` added, `=` already on the shelf, a renamed link shown as `as "Acme 2"`; an item that does not exist is shelved and reported; carrying it out generates the app when needed and calls its host `add`
- [x] T015 [US1] In `Sources/app/main.swift`, wire `shelve <punch> <shelf> <item>... [--force] [--json]` with the plan lines, the question `Shelve? [y/N]`, the stop at the plan in a pipe or with `--json`, and the exit status of `contracts/cli.md`; status 2 for a shelf the punch does not declare; after writing, read `userEnabled` through the host's `status` and, when false, print `Finder: click Enable in the "<name>" row once.` (`say-when-enabling-is-needed`)
- [x] T016 [P] [US1] In `Sources/checks/main.swift`, check `a-shelf-owns-no-attributes`: planning a shelve of three temporary folders reads and writes nothing on them (every attribute byte for byte, nothing created inside); the generated plists from T013, written into a temporary folder without signing or registering, carry the shelf's identifiers, name, symbol and group
- [x] T017 [US1] Run `./build.sh check`; then, with Egildo's yes, quickstart section 2, steps 1 and 2; record what is seen in `notes/YYYY-MM-DD-shelves-by-eye.md`, including whether a two-word name keeps its space

**Checkpoint**: a shelf appears in the sidebar with its own name and symbol and opens its links.

---

## Phase 4: User Story 2 - Change what is on a shelf (Priority: P2)

**Goal**: `unshelve` takes items off, `shelve` adds more, and an open Finder window follows
without enabling again; `punchr shelves` lists every shelf and its links.

**Independent Test**: quickstart section 2, step 3, and `punchr shelves`.

- [ ] T018 [US2] In `Sources/core/Shelves.swift`, the plan for `unshelve` (`−` for each item on the shelf, nothing for an item not on it) and carrying it out through the host's `add` with the shorter list
- [ ] T019 [US2] In `Sources/core/Shelves.swift`, list shelves: every app under `~/Library/Application Support/punchr/Shelves/`, its host's `status`, whether a punch in the punch folder still declares it, and for each link whether its target exists (`read-a-shelf`)
- [ ] T020 [US2] In `Sources/app/main.swift`, wire `unshelve` (question `Unshelve? [y/N]`) and `shelves` (terminal lines and JSON as in `contracts/cli.md`)
- [ ] T021 [P] [US2] In `Sources/checks/main.swift`, check the `shelve` and `unshelve` plans on a shelf whose list is given: adding an item already on it plans nothing; removing an item not on it plans nothing; a missing target is reported `missing` by the listing
- [ ] T022 [US2] Run `./build.sh check`; then, with Egildo, quickstart section 2, steps 3 and 4; if adding the domain again asks to enable it again (`change-without-re-enabling`), switch to the fallback in research (a links file in the app group, read by the extension) before going on

**Checkpoint**: a shelf's contents change in place.

---

## Phase 5: User Story 3 - Take a shelf away (Priority: P3)

**Goal**: `punchr shelves --tidy` removes shelves no punch declares; `--refresh` rebuilds them
after an upgrade.

**Independent Test**: quickstart section 2, steps 5 and 6.

- [ ] T023 [US3] In `Sources/core/Shelves.swift`, `--tidy`: for each shelf not declared, plan `− <name>`; carrying it out calls the host's `remove`, then `pluginkit -r`, `lsregister -u`, and deletes the shelf's app; the system removes its folder under `~/Library/CloudStorage` (`take-a-shelf-away`); say that macOS keeps an empty 32 KB container in `~/Library/Containers/` that Finder can bin
- [ ] T024 [US3] In `Sources/core/Shelves.swift`, `--refresh`: for each shelf, read its links through `status`, then unregister, regenerate from the current template (T013), register, and `add` again with the same links (`shelves-survive-a-rebuild`)
- [ ] T025 [US3] In `Sources/app/main.swift`, wire `shelves --tidy` and `shelves --refresh` with their plans and questions (`Tidy? [y/N]`, `Refresh? [y/N]`)
- [ ] T026 [US3] With Egildo, quickstart section 2, steps 5 and 6; record whether a refresh asks to enable again, and check that the scratch folders are byte for byte as before (`nothing-touched`)

**Checkpoint**: shelves come and go cleanly.

---

## Phase 6: Polish

- [ ] T027 Update `README.md`: shelves in the punch, the three commands, the enable click, where shelves live, the container left behind, and running `punchr shelves --refresh` after `brew upgrade`
- [ ] T028 [P] Add a `caveats` line about `punchr shelves --refresh` to the formula in `~/Privata/dev/homebrew-apps/Formula/punchr.rb` at the next release; do not push the tap without Egildo's yes
- [ ] T029 Cross-read spec, plan, research, contract and code; amend the spec where the quickstart found otherwise; gate: `./build.sh` and `./build.sh check`; merge `shelves-round` into `main` with `--no-ff`

---

## Dependencies & Execution Order

- **Setup** (T001–T004) first; **Foundational** (T005–T009) blocks every story.
- **US1** (T010–T017) needs the foundation. Within it: T010 and T011 (extension) and T012 (host)
  before T013 (generation), then T014, T015; T016 alongside; T017 last.
- **US2** (T018–T022) needs US1's generated shelf and host.
- **US3** (T023–T026) needs US1's generation (T013) and US2's listing (T019).
- **Polish** last; T028 waits for a release.

## Parallel Opportunities

- T001 and T002; T006 alongside T005.
- T007 and T008 once T005 and T006 are done.
- T012 (host) alongside T010–T011 (extension): different files.
- Check tasks marked [P] are separate functions in one file.

### Example: US1

```text
T010, T011 Provider.swift   ┐
T012 main.swift             ┘ then T013, T014, T015, with T016 alongside, then T017 with Egildo
```

## Implementation Strategy

1. Setup and foundation, checks passing.
2. US1: one shelf in the sidebar, by eye with Egildo. This is the MVP.
3. US2: changing a shelf, with the re-enable question settled by eye.
4. US3: refresh and tidy.
5. Polish, cross-read, gate, merge.
