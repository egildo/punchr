# Implementation Plan: Shelves, sidebar rows of links

**Branch**: `shelves-round` | **Date**: 2026-10-25 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-shelves/spec.md`

## Summary

A punch declares shelves (a key, a row name, an SF Symbol). `punchr shelve` sets a shelf up the
first time by copying a template app out of Punchr.app into
`~/Library/Application Support/punchr/Shelves/`, giving it the shelf's identifiers, name and
symbol, signing it ad hoc and registering it; its File Provider extension serves one domain whose
items are symbolic links to the shelved folders and files. The list of links lives in the
domain's `userInfo`; `shelve` and `unshelve` change it and signal Finder. The second scratch test
settled that one symbol per row needs one extension per shelf, and that a copied, re-signed
template works. See [research](research.md).

## Technical Context

**Language/Version**: Swift 6.3 with the Command Line Tools; the extension and the shelf host are
compiled in Swift 5 mode, as the spike was.

**Primary Dependencies**: FileProvider and Foundation; at run time `/usr/bin/plutil`,
`/usr/bin/codesign`, `lsregister` and `/usr/bin/pluginkit`, all part of macOS. No new
third-party code.

**Storage**: the shelves' apps in `~/Library/Application Support/punchr/Shelves/`; each shelf's
links in its domain's `userInfo`, kept by the system. Nothing in the punch folder changes.

**Testing**: the assert checks for what needs no Finder; the quickstart, by eye with Egildo, for
the rows, the links and the enable step.

**Target Platform**: macOS 26 (Tahoe), as before.

**Project Type**: the command line, plus a template app (host and File Provider extension)
shipped inside Punchr.app.

**Performance Goals**: a change on a shelf seen in Finder within 5 seconds (`change-seen-quickly`).

**Constraints**: ad-hoc signing only; no Xcode; nothing written on the linked items; Egildo
enables each shelf once in Finder, and punchr never tries to bypass that.

**Scale/Scope**: a handful of shelves, tens of links each.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Before research | After design |
|---|---|---|
| Blind to its callers | Pass: shelves take paths; no caller's logic. | Pass. |
| Moving state stays live | Pass: a shelf writes nothing on what it links to, so no state reaches a record. | Pass: the links live in the system's domain record, not on folders. |
| Touch only what the punch owns | Pass: shelves own nothing on folders. | Pass: writes go only to the shelves' own apps and the system's File Provider records; `--tidy` removes only shelves no punch declares, after a plan. |
| Finder's own doors | Pass: File Provider is Apple's documented way to a sidebar row. | Pass: the symbol key, `userInfo`, `signalEnumerator`, `userEnabled` and the exclusion error are all in Apple's headers; the two spikes are in dated notes. |
| Lean | Needs care: a second extension type, and an app generated per shelf. | Pass with one exception, recorded below. Reused: the spike's extension, the system's tools for signing and registering; no state file of punchr's own. |

## Project Structure

### Documentation (this feature)

```text
specs/004-shelves/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/cli.md
├── checklists/requirements.md
└── tasks.md             # by /speckit-tasks
```

### Source Code (repository root)

```text
Sources/
├── shelf/
│   ├── Links.swift        # naming links (suffixes), the anchor that carries the list; compiled into the extension, the app and the checks
│   ├── Provider.swift     # the File Provider extension: items, enumeration, changes, quiet writes
│   └── host.swift         # the template app's executable: add, remove, list its one domain, report userEnabled
├── core/
│   └── Shelves.swift      # shelves in a punch, generating a shelf's app, the plan for shelve/unshelve/refresh/tidy
├── app/main.swift         # the shelve, unshelve and shelves verbs
└── checks/main.swift      # checks for what needs no Finder
Support/
├── Shelf-Info.plist, ShelfProvider-Info.plist, shelf.entitlements, shelf-provider.entitlements
build.sh                   # also builds the template into Punchr.app/Contents/Resources/Shelf.app
```

`experiments/shelf/` stays as the spike's record and is not built.

**Structure Decision**: the shelf code gets its own folder because it is two more binaries (host
and extension). `Links.swift` is the one file shared across binaries, so the naming and change
logic is checked once. The template travels inside Punchr.app, so Homebrew installs it with
everything else.

## Complexity Tracking

| Exception | Why needed | Simpler alternative rejected because |
|---|---|---|
| An app generated and signed at run time per shelf | The sidebar symbol belongs to the extension; two symbols need two extensions (research, scratch test). It also makes the row show the shelf's own name. | One extension for every shelf: the rows read "App - Shelf" and share one symbol, which the spec rules out (`one-row-per-shelf`, "one SF Symbol each"). |
