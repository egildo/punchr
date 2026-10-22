# Contract: the `punchr` command

```
punchr read <folder>... [--punch <punch>]...  what each folder wears, and which look of each known punch it matches
punchr strike <punch> <look> <folder>... [--force]   plan, then dress the folders in the look
punchr clear <punch> <folder>... [--force]     plan, then remove what the punch owns
```

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

## Exit status

| Status | Meaning |
|---|---|
| 0 | every folder read or written, or the plan stopped as above |
| 1 | at least one folder failed (and is named in the output) |
| 2 | wrong arguments, punch refused, look unknown, or a badge look given to `strike` |

## Terminal output

One line per folder, marked as the sibling tools mark them: `✓` done or nothing to do, `✗`
failed, `·` planned and not written. Plan lines show `+ tag client (grey)`, `− tag ahead`,
`+ stamp arrow.triangle.branch`, `+ icon`, `− icon`. Problems in a punch are listed one per
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
        "icon": true
      },
      "matches": { "client": "zente", "repository": null }
    },
    { "path": "notes.txt", "error": "not a folder" }
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
      "add": { "tags": [{ "name": "client", "colour": "grey" }], "stamp": null, "icon": true },
      "remove": { "tags": [], "stamp": null, "icon": false },
      "keep": { "tags": [], "stamp": null, "icon": false }
    }
  ]
}
```

`look` is absent for `clear`. `stamp` is `null` or `{ "sym": … }` / `{ "emoji": … }`. A refused
punch answers `{ "problems": [{ "at": "looks.zente.tags[1]", "problem": "…" }] }` with status 2.

## An example punch

```json5
// ~/.config/punchr/client.json5
{
  owns: { tags: ['client'], stamp: true, icon: true },
  looks: {
    zente: { tags: [{ client: 'grey' }], icon: 'logos/zente.svg' },
    acme:  { tags: [{ client: 'grey' }], stamp: { emoji: 'ACME' } },
    ahead: { badge: 'badges/ahead.svg' }, // drawn live, by a later feature
  },
}
```
