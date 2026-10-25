# Quickstart: proving shelves

Shelves live in Finder's sidebar, so most of the proof is by eye, with Egildo, on scratch folders
only. Setting a shelf up registers an extension with the system and adds a sidebar row: per the
working rules, ask Egildo before each run. Everything is removed at the end.

## 1. The checks

```sh
./build.sh check
```

The checks cover what needs no Finder: reading shelves from a punch and refusing a broken one
(`punch-declares-shelves`), naming links and their suffixes, the sync anchor that carries the list
and the changes it reports, and that shelving writes nothing on the linked items
(`a-shelf-owns-no-attributes`, `nothing-touched`).

## 2. By eye, in Finder

Scratch folders and a scratch punch, two shelves, one with a two-word name:

```sh
S=$(mktemp -d)/shelves && mkdir -p $S/zente $S/acme $S/old
printf "{ shelves: { clients: { name: 'Clients', symbol: 'person.2' }, old: { name: 'Old Work', symbol: 'archivebox' } } }" > $S/test.json5
build/punchr shelve $S/test.json5 clients $S/zente $S/acme --force
build/punchr shelve $S/test.json5 old $S/old --force
build/punchr shelves
```

Expected:

1. Two rows: "Clients" with two people, "Old Work" with an archive box (and the space kept;
   research, "One symbol per shelf"). Each asks once to be enabled (`row-with-its-symbol`,
   `say-when-enabling-is-needed`).
2. After enabling, "Clients" lists `zente` and `acme`; one click on a link opens the scratch
   folder (`opens-the-real-folder`). No link carries a cloud with an exclamation mark
   (`no-error-marks-seen`).
3. With "Clients" open:

   ```sh
   build/punchr unshelve $S/test.json5 clients $S/acme --force
   build/punchr shelve $S/test.json5 clients $S/old --force
   ```

   `acme` goes and `old` appears within 5 seconds, with no new enable banner
   (`change-seen-quickly`, `change-without-re-enabling`).
4. Drag a file onto "Clients": it does not stay; the shelf's links are unchanged.
5. `build/punchr shelves --refresh --force`: both rows come back with their links; note whether
   Finder asks to enable them again.
6. Take the shelves away: remove `shelves` from the scratch punch, then
   `build/punchr shelves --tidy --force`. Both rows leave the sidebar, their folders leave
   `~/Library/CloudStorage`, and the scratch folders are byte for byte as before
   (`nothing-touched`).

What is seen goes into a dated note; any "open" point in research that turns out otherwise
changes the spec before the round lands.
