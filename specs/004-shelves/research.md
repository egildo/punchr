# Research: Shelves

Measured on 2026-10-25, macOS 26.6.2, Command Line Tools with Swift 6.3.3. The first spike is in
[its note](../../notes/2026-10-25-shelf-spike.md); this file adds the second test and the
decisions. Everything registered for the tests was removed afterwards.

## One symbol per shelf (the first question)

- **The SDK**: neither `NSFileProviderDomain` nor `NSFileProviderManager` has any icon, image or
  symbol property. The sidebar symbol is the extension's `CFBundleSymbolName`.
- **The scratch test**: app A (one extension, symbol `person.2`) served two domains, Alpha and
  Beta; app B was made by copying app A, changing only its identifiers and its symbol (`star`)
  with `plutil`, and re-signing ad hoc, with no compiling. All three domains were accepted.
  Finder's sidebar showed:

  | Row | Symbol |
  |---|---|
  | ShelfA - Alpha | two people |
  | ShelfA - Beta | two people |
  | ShelfB | star |

- **Decision**: one small generated app per shelf, holding one shelf extension and serving one
  domain. Its symbol is the shelf's; its name is the shelf's, and a single domain shows the app's
  name alone, so the row reads exactly as the shelf is named.
- **Rationale**: the only way to give two rows two symbols is two extensions; a copy edited and
  re-signed at run time works, so punchr can make one per shelf from a template without the
  Command Line Tools on the user's machine.
- **Alternatives considered**: one extension serving every shelf (rows read "App - Shelf" and
  share one symbol, which the spec rules out); building each shelf's extension from source when it
  is set up (needs `swiftc` at run time; copying a signed template is enough).
- **Open, measured in the quickstart**: the bundle was named `Shelf B` and the row read `ShelfB`.
  Whether a name with spaces keeps them (from the bundle's file name, `CFBundleName` or
  `CFBundleDisplayName`) is checked on the first real shelf, `Clients` and a two-word one.

## Where shelves live

- **Decision**: each shelf's app is generated in `~/Library/Application Support/punchr/Shelves/`,
  named after the shelf, with identifiers derived from the punch and the shelf's key
  (`local.punchr.shelf.<punch>.<key>`, app group `group.local.punchr.shelf.<punch>.<key>`). The
  template app (a tiny host executable and the shelf extension) ships inside Punchr.app, in
  `Contents/Resources/Shelf.app`, built by `build.sh`.
- **Rationale**: outside Homebrew's Cellar, so `brew upgrade` does not move or delete them; the
  same key gives the same identifiers, so a shelf made again reuses its sandbox container.
- **Cost**: macOS keeps an empty sandbox container (32 KB) per shelf extension in
  `~/Library/Containers/` and does not let a shell delete it; removing a shelf leaves that shell.

## A shelf's list of links

- **Decision**: the list lives in the domain's `userInfo` (one newline-joined string of paths,
  the only shape accepted: plain strings, numbers, data and dates). `shelve` and `unshelve`
  update it by adding the domain again with the new `userInfo`, as Apple's header says, then
  signal the root enumerator. The extension's sync anchor carries the list itself, so
  `enumerateChanges` can report additions as updates and removals as deletions without any file.
- **Rationale**: no state file of punchr's own; the system keeps the list with the shelf, and
  `punchr shelves` reads it back from the domain.
- **Open, measured in the quickstart**: that adding an existing domain again keeps it enabled
  (`change-without-re-enabling`). Fallback: a links file in the shelf's app-group container,
  written by the host and read by the extension.

## Quiet writes

- **Decision**: the extension accepts what Finder writes onto its items and ignores it:
  `modifyItem` answers with the item unchanged and no error; `deleteItem` and `createItem`
  answer `NSFileProviderErrorExcludedFromSync`, so a drop onto a shelf stays out of it.
- **Rationale**: the spike's error mark came from refusing every modification.
- **Open, measured in the quickstart**: that no link shows a mark (`no-error-marks-seen`), and
  what Finder shows after a drop.

## Knowing whether a shelf is enabled

- **Decision**: after setting a shelf up, punchr reads the domain's `userEnabled` and, when it is
  false, says that Finder will ask once, in the shelf's row (`say-when-enabling-is-needed`).

## Surviving a rebuild or an upgrade

- **Measured in the spike**: replacing an extension's bundle in place made the system forget it;
  unregistering and registering again brought it back.
- **Decision**: `punchr shelves --refresh` regenerates every shelf's app from the current
  template: unregister, replace, re-sign, register, add the domain again with its `userInfo`.
  Homebrew's formula prints a caveat to run it after an upgrade.
- **Open, measured in the quickstart**: whether the domain and its enabled state survive the
  unregistering; if not, refresh tells the user to enable once more.

## Reusing what exists

- The host executable is a few dozen lines (add, remove, list a domain) and the extension is the
  spike's `Shelf.swift` with quiet writes and change enumeration; both are compiled by `build.sh`
  into the template, with no new dependency.
- Generating a shelf uses `/usr/bin/plutil`, `/usr/bin/codesign`, `lsregister` and
  `/usr/bin/pluginkit`, all on every Mac.
