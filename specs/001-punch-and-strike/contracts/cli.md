# Contract: the `punchr` command

```
punchr read <item>... [--punch <punch>]...  what each item wears, and which look of each known punch it matches
punchr strike <punch> <look> <item>... [--force] [--live]   plan, then dress the items in the look
punchr clear <punch> <item>... [--force] [--live]     plan, then remove what the punch owns
```

An item is a folder or, since 0.3.0, a regular file. A file wears tags and a comment only: a look
with a stamp or an icon struck on a file fails for that file with `<path>: a file wears no stamp
or icon`, status 1, and nothing is written to it; `read` gives a file `stamp: null` and
`icon: false`. A symbolic link is refused (`a link: links are not followed`), as is anything
else that is neither (`not a folder or a file`). The JSON keeps the key `folders` and `path` for
every item, file or folder.

Every verb also takes `--json`. `<punch>` is a name, looked up as `<name>.json5` in the punch
folder, or a path (it contains `/` or ends in `.json5`). "Known punches", for `read`, are the
`.json5` files in the punch folder, or, when `--punch` is given (once or more), only those
punches; a punch given with `--punch` that is refused stops `read` with status 2, while a broken
punch in the punch folder is reported on standard error and left out.

## Writing, asking, stopping

| Situation | `strike` and `clear` |
|---|---|
| `--force` | print the plan, write it |
| a terminal, no `--force` | print the plan, ask `Strike? [y/N]` (or `Clear?`), write only on `y` |
| a pipe or `--json`, no `--force` | print the plan, write nothing |

Nothing is ever written when the punch is refused or the look is unknown or a badge look.

## `--live`

The caller's promise that the look follows a state. With it, `strike` and `clear` refuse a punch
that owns tags, a stamp or an icon, before reading any folder: status 2, one problem for each
(`owns.tags`, `owns.stamp`, `owns.icon`), each `a live punch owns only comments`. A punch that
owns only the comment runs as without the flag. `read` takes no `--live`.

## Exit status

| Status | Meaning |
|---|---|
| 0 | every folder read or written, or the plan stopped as above |
| 1 | at least one folder failed (and is named in the output) |
| 2 | wrong arguments, punch refused (also under `--live`), look unknown, or a badge look given to `strike` |

## Terminal output

One line per folder, marked as the sibling tools mark them: `✓` done or nothing to do, `✗`
failed, `·` planned and not written. Plan lines show `+ tag client (grey)`, `− tag ahead`,
`+ stamp sym arrow.triangle.branch`, `+ icon`, `− icon`, `+ comment AHEAD`, `− comment AHEAD`;
a removed comment that no look of the punch writes reads `− comment <text> (not this punch's)`.
`read` shows `comment <text>`. Problems in a punch are listed one per
line with their path in the file, then the command stops.

## JSON output

`read --json`:

```json
{
  "folders": [
    {
      "path": "Projects/zente",
      "wears": {
        "tags": [{ "name": "client", "colour": "grey" }],
        "stamp": null,
        "icon": true,
        "comment": "AHEAD"
      },
      "matches": { "client": "zente", "repository": null }
    },
    { "path": "Projects/latest", "error": "Projects/latest: a link: links are not followed" }
  ]
}
```

`strike --json` and `clear --json`:

```json
{
  "punch": "client",
  "look": "zente",
  "written": false,
  "folders": [
    {
      "path": "Projects/zente",
      "add": { "tags": [{ "name": "client", "colour": "grey" }], "stamp": null, "icon": true, "comment": null },
      "remove": { "tags": [], "stamp": null, "icon": false, "comment": "my own note" },
      "keep": { "tags": [], "stamp": null, "icon": false, "comment": null }
    }
  ]
}
```

A file refused for a stamp or icon look appears as
`{ "path": "notes.txt", "error": "notes.txt: a file wears no stamp or icon" }`.

`look` is absent for `clear`. `stamp` is `null` or `{ "sym": … }` / `{ "emoji": … }`. `comment`
is the text or `null`; it was added in 0.2.0, beside keys that did not change. A refused
punch answers `{ "problems": [{ "at": "looks.zente.tags[1]", "problem": "…" }] }` with status 2;
under `--live`, `{ "problems": [{ "at": "owns.tags", "problem": "a live punch owns only comments" }] }`.

## An example punch

```json5
// ~/.config/punchr/client.json5
{
  owns: { tags: ['client'], stamp: true, icon: true, comment: true },
  looks: {
    zente: { tags: [{ client: 'grey' }], icon: 'logos/zente.svg' },
    acme:  { tags: [{ client: 'grey' }], stamp: { emoji: 'ACME' }, comment: 'ACME, since 2024' },
    ahead: { badge: 'badges/ahead.svg' }, // drawn live, by a later feature
  },
}
```
