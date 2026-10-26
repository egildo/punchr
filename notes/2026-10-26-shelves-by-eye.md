# Shelves by eye: the first real shelves (2026-10-25 and 26)

Quickstart steps 1 and 2 of `specs/004-shelves`, with Egildo, macOS 26.6.2. Two shelves declared in
a scratch punch (`test.json5`): "Clients" (`person.2`) and "Old Work" (`archivebox`), set up by
`punchr shelve` itself.

## The rows

- Both appeared in the sidebar's top group, beside iCloud Drive and OneDrive, each with its own
  name and symbol. "Old Work" kept its space: the row takes the app's display name. The folder the
  system made for it under `~/Library/CloudStorage` dropped the space (`OldWork-OldWork`); nobody
  sees that folder.
- Each asked once to be enabled, in a banner inside its row, as the spike did.
- Replacing a shelf's app (unregister, delete, `shelve` again) kept the shelf enabled and kept its
  domain: a refresh after an upgrade will not ask again.

## Three faults, found and fixed in turn

1. **Blinking icons, a loop of ours.** The extension answered every "what changed?" with every
   link. The system rewrote the links, which counted as a change: about 430 re-indexings in 20
   seconds. Now only new, gone or renamed links are reported, and a check proves an unchanged
   shelf reports nothing.
2. **Blinking icons, the daemon's loop.** With that fixed, icons still flickered. The File Provider
   daemon follows each symbolic link and tries to read the folder behind it; its sandbox refuses,
   about eight times a second per link, wherever the folder is (`/private/tmp` and the `dev` volume
   both), and Spotlight re-indexes the shelf each time. Apple documents no way to keep a domain
   out of indexing. Links became **Finder aliases**: small files the daemon has no reason to go
   through. After the change: no refusals, no re-indexing.
3. **Blank icons.** The first aliases did not resolve ("the file couldn't be opened"). The raw
   bookmark data is not an alias file; Finder's writer puts its own header in front (the file is 8
   bytes shorter and starts `book…mark`). The shelf's app now writes each alias to a temporary file
   and reads the bytes back. Then the system still showed the old files: it keeps an item's
   contents until told its version changed. Each item's content version is now a fingerprint of
   its alias bytes, and the sync anchor carries one of all of them.

## Where it ended

The "Clients" shelf lists `zente` and `acme` as aliases, with folder icons and the alias arrow,
kind "Alias", no cloud badge, steady; both resolve to their scratch folders under
`build/shelf-scratch` on the `dev` volume. The root asks the system to keep its items downloaded,
which removed the cloud.

Egildo accepted the consequence of aliases: they follow a folder that is moved or renamed.

## Also found

The check for comments written through Finder sometimes failed: Finder writes its `.DS_Store` when
it gets round to it. The check now waits up to 5 seconds; six runs in a row passed.
