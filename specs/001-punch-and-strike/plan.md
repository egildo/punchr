# Implementation Plan: The punch, with read, strike and clear for written looks

**Branch**: `punch-and-strike-round` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-punch-and-strike/spec.md`

## Summary

A punch is a JSON5 file naming looks and what the punch owns. The host app's executable becomes
the `punchr` command, with `read`, `strike` and `clear`. It reads and writes a folder's tags,
stamp and custom icon straight through extended attributes, plans every write, asks at a
terminal, and shares one icon file per volume through hard links. Everything comes from the
standard library and the system frameworks; checks run as an assert program in a temporary
folder. See [research](research.md) for each decision.

## Technical Context

**Language/Version**: Swift 6.3, compiled with `swiftc` from the Command Line Tools.

**Primary Dependencies**: none beyond the system: Foundation (JSON5 decoding, property lists),
AppKit (`NSImage` to render the icon), ImageIO, Darwin (extended attributes, `lstat`, `link`,
`isatty`).

**Storage**: punch files in `~/.config/punchr/`; everything else lives on the folders.

**Testing**: an assert-based check program, `./build.sh check`, in a temporary folder.

**Target Platform**: macOS 26 (Tahoe) and later, Apple silicon and Intel alike (only Apple
silicon tested).

**Project Type**: command-line tool inside the app bundle that also hosts the Finder Sync
extension.

**Performance Goals**: reading 1,000 folders under 5 seconds (`read-a-thousand`).

**Constraints**: no third-party dependency, no package manager, no Xcode; nothing written that
the punch does not own; an icon under 25 KB per volume (`icon-costs-kilobytes`, amended by this
plan from 10 KB, see research).

**Scale/Scope**: tens to thousands of folders per call; a handful of punches.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Before research | After design |
|---|---|---|
| Blind to its callers | Pass: the spec names no caller's logic. | Pass: no git or tabularium in code; tabularium appears only in documents. |
| Moving state stays off disk | Pass: badge looks are refused by `strike`. | Pass: `badge-looks-are-not-struck`; no attribute records a state. |
| Touch only what the punch owns | Pass: `owns`, plan first, colour number written. | Pass: the plan is computed from owned parts only; the icon bit is set alone; no extra attribute is written to remember a look (research, "Knowing which look a folder wears"). |
| Finder's own doors | Pass: tags, stamp and icon formats are in the findings. | Pass: the two open points (a tag's colour without the old label bits, Finder refreshing on its own) were measured by eye and recorded in `notes/2026-10-22-finder-by-eye.md`. |
| Lean | Pass. | Pass: JSON5 through Foundation instead of a YAML package; arguments parsed by hand; the app's executable is the command; two icon sizes; one icon file per volume. The palette-PNG encoder that would bring the icon from about 20 KB to 5 KB is parked. |

No exception to record.

## Project Structure

### Documentation (this feature)

```text
specs/001-punch-and-strike/
├── spec.md
├── plan.md              # this file
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
├── finder/FinderSync.swift   # the extension, moved from Sources/; unchanged
├── app/main.swift            # the command: arguments, verbs, terminal and JSON output
├── core/
│   ├── Punch.swift           # reading and checking a punch file
│   ├── Dress.swift           # reading and writing tags, stamp, icon bit on one folder
│   ├── Icon.swift            # rendering the icns, the resource fork, Icon\r and its links
│   └── Plan.swift            # what strike and clear will change, and doing it
└── checks/main.swift         # the assert program, compiled with core/
build.sh                      # builds the app (core + app), the extension, `build/punchr`; `check` runs the checks
```

**Structure Decision**: one Swift module per binary, as now. `core/` is compiled into both the
app and the check program, so `app/main.swift` stays thin and everything worth checking is in
`core/`. The extension is moved into `finder/` so each binary has its own folder; its code does
not change in this round.

## Complexity Tracking

None.
