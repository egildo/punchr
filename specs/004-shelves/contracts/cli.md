# Contract: shelves in the `punchr` command

Added beside `read`, `strike` and `clear` (see [the first contract](../../001-punch-and-strike/contracts/cli.md)),
with the same conventions: a punch is a name or a path, every verb takes `--json`, and a command
that changes anything shows its plan first.

```
punchr shelve <punch> <shelf> <item>... [--force]     put folders and files on a shelf; sets the shelf up the first time
punchr unshelve <punch> <shelf> <item>... [--force]   take them off
punchr shelves [--refresh | --tidy] [--force]         list every shelf and its links; --refresh rebuilds them after an upgrade; --tidy removes shelves no punch declares
```

`<shelf>` is the shelf's key in the punch (`clients`), not its row name.

## Writing, asking, stopping

As for `strike` and `clear`: `--force` writes; at a terminal punchr asks `Shelve? [y/N]`,
`Unshelve? [y/N]`, `Refresh? [y/N]` or `Tidy? [y/N]`; in a pipe or with `--json` it stops at the
plan. Plain `punchr shelves` only reads.

## Plan lines

```
· Clients (person.2)        + set up: Finder will ask once to enable it, in its row
    + /Volumes/Projects/Zente
    + /Volumes/Projects/Acme as "Acme 2"
    = /Volumes/Projects/Old         already on the shelf
    − /Volumes/Projects/Done
```

After writing, `✓ Clients` or `✗ Clients: <reason>`. A shelf set up but not enabled adds the line
`  Finder: click Enable in the "Clients" row once.`

## `shelve --json`

```json
{
  "punch": "client", "shelf": "clients", "name": "Clients", "symbol": "person.2",
  "setUp": true, "written": false, "enabled": null,
  "links": [
    { "name": "Zente", "target": "/Volumes/Projects/Zente", "new": true, "exists": true },
    { "name": "Zente 2", "target": "/Volumes/Old/Zente", "new": true, "exists": false }
  ]
}
```

`links` is the whole shelf after the change, in shelving order; `new` marks what this call adds;
`removed` lists the targets this call takes off (`unshelve --json` answers in the same shape).
`enabled` is `null` until the shelf is set up. A failure adds `"error"`. Unshelving from a shelf
that was never set up changes nothing.

## `punchr shelves`

```
Clients (person.2)   client/clients   enabled
    Zente → /Volumes/Projects/Zente
    Acme  → /Volumes/Projects/Acme     missing
Archive (archivebox)   old/archive    not enabled yet
```

`--json`:

```json
{
  "shelves": [
    {
      "punch": "client", "shelf": "clients", "name": "Clients", "symbol": "person.2",
      "enabled": true, "declared": true,
      "links": [
        { "name": "Zente", "target": "/Volumes/Projects/Zente", "exists": true },
        { "name": "Acme", "target": "/Volumes/Projects/Acme", "exists": false }
      ]
    }
  ]
}
```

A shelf set up on this Mac but no longer declared shows `"declared": false`; `--tidy` removes
exactly those. A shelf's app records the punch file it was made from, so a punch given by path is
found again. A shelf the listing cannot read adds `"error"` (for instance one made before shelves
recorded their punch, which must be set up again) and makes the status 1. With no shelves at all,
the terminal says `no shelves`.

## `--refresh` and `--tidy`

Plan lines, then the question, as above:

```
· Clients (person.2)   client/clients   ↻ 2 links
· Archive (archivebox)   old/archive   − no longer declared
```

`--refresh` takes every shelf it can read, rebuilds its app from the current template under the
name and symbol its punch declares now (or as recorded, if the punch is gone) and gives it its
links again; the shelf stays enabled. `--tidy` takes only the shelves no punch declares, removes
their domain (the row and its folder go with it) and their app, then says that macOS keeps an
empty 32 KB container per removed shelf. A shelf the listing cannot read is reported and left
alone. `--json`:

```json
{ "action": "tidy", "written": true,
  "shelves": [ { "punch": "old", "shelf": "archive", "name": "Archive", "done": true, "error": null } ] }
```

## Exit status

| Status | Meaning |
|---|---|
| 0 | done, or stopped at the plan |
| 1 | a shelf could not be set up, changed or removed (named in the output); an item that does not exist is shelved anyway and reported |
| 2 | wrong arguments, punch refused, shelf not declared in the punch |

## In the punch

```json5
shelves: {
  clients: { name: 'Clients', symbol: 'person.2' },
}
```

See [the data model](../data-model.md) for the rules.
