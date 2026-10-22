# punchr Constitution

This document governs how punchr is engineered. What punchr is and what it is for is
[the README](../../README.md); what has been measured about Finder is in the dated notes under
[`notes/`](../../notes/). Neither is restated here.

## Core Principles

### Blind to its callers

punchr is told which look a folder wears; it never works out why. The state belongs to the
program that names it, the visuals to the punch.

**Forbids:** knowledge of git, tabularium or any other caller in punchr's code (their names
appear only in examples, tests and documents); a look whose meaning lives in code rather than
in a punch; a special case for one caller.

**Why:** tabularium is the first caller, not the only one. A tool that knows nothing about its
callers can serve any of them.

### Moving state stays off disk

A look that follows a state (ahead, behind, dirty, syncing) is a badge, drawn live by the
Finder Sync extension. Only a look that does not move is written onto the folder.

**Forbids:** writing a changing state as an attribute, tag, stamp or icon; a badge that needs a
file inside the folder it badges.

**Why:** a written state churns every record that carries the folder's attributes,
tabularium's first of all, and lies as soon as it is copied away from the state it described.

### Touch only what the punch owns

A write changes only what its punch declares it owns: the tags it names, the one bit it needs,
the `Icon\r` file it put there. Every write shows its plan first and changes nothing until it
is forced.

**Forbids:** replacing a whole attribute to change one bit of it (the custom-icon bit in
`com.apple.FinderInfo` is set and cleared alone); removing or recolouring a tag the punch does
not own; a write without a plan; a write that relies on the user's own tag list for a colour
instead of writing the colour number.

**Why:** the folders are the user's, and other tools (Finder itself, tabularium, sync clients)
write the same attributes. A plan first, as in the sibling tools, makes every write reviewable.

### Finder's own doors

punchr dresses folders only through what macOS offers for it: the Finder Sync extension and the
attributes and files Finder reads, in the formats measured and written down in a dated note.

**Forbids:** code injected into Finder; private frameworks; a format no dated note records as
measured on a real Mac; a second Finder Sync extension for the same folders.

**Why:** injection into Finder broke on every Finder update (Liferay Nativity's lesson), and
Finder lets only one extension serve a folder. A measured format can be checked again when
macOS changes.

### Lean

The least code, the least weight. Code exists because a spec asks for it.

**Forbids:** an abstraction with one implementation; an option for a value that never varies;
a third-party dependency for what a few lines of Swift or a system tool does; an Xcode
project; writing a picture at every size when two sizes draw (a hand-made icon is 5 KB where
the system's call writes 1.3 MB); a second copy of an icon where a hard link on the same volume
does.

**Why:** punchr runs inside Finder's life on every folder it watches. What it costs in memory,
disk and attention is paid on every window the user opens.

## Technology constraints

- **Language:** Swift, compiled with `swiftc` from the Command Line Tools. No Xcode, no
  package manager until a plan justifies one.
- **Platform:** macOS 26 (Tahoe) and later, Mac only. Stamps need Tahoe; older systems show a
  plain folder.
- **Signing:** ad-hoc. The extension is sandboxed with the app-sandbox entitlement only; any
  further sandbox exception is named and justified in the plan that adds it.
- **Build:** `./build.sh`, and nothing else.
- **Install:** a Homebrew formula that builds from source, so the app is never quarantined.
- **Logging:** `os.Logger`, subsystem `local.punchr`, values marked `privacy: .public`.

## Development workflow

- **Documents move first.** A round states its purpose, amends the spec, then makes the code
  agree, on one branch named `<topic>-round`, merged into `main` with a merge commit.
- **Checked by name.** Every plan's Constitution Check names each principle here, with a pass
  or a justified exception.
- **Requirements are named, not numbered.** Two to four kebab-case words naming the obligation
  (`set-only-the-icon-bit`), chosen once and kept; never `FR-016`.
- **Every mechanism leaves a check.** Non-trivial logic ships with the smallest check that fails
  when it breaks. Checks run on scratch folders only.
- **The real Finder by consent.** Registering or enabling the extension, restarting Finder, or
  writing onto a folder outside a scratch area happens only on Egildo's yes, each time.
- **Findings are dated.** What a round measures goes into `notes/YYYY-MM-DD-<topic>.md`.
- **Gate:** `./build.sh` builds clean before a branch lands.

## Governance

Precedence, highest first: this constitution, then specs, plans and tasks. None is overridden
by anything below it or by convenience.

Amending this constitution is its own act, on its own branch, with its reason recorded. It
never happens as a side effect of other work. Versions follow semantic versioning: MAJOR for
removing or redefining a principle, MINOR for adding a principle or section or materially
widening one, PATCH for wording. Exceptions to a principle are recorded in the plan's
Complexity Tracking with the simpler alternative and why it fails.

**Version**: 1.0.0 | **Ratified**: 2026-10-22 | **Last Amended**: 2026-10-22
