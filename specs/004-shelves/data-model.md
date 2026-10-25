# Data model: Shelves

## In the punch

A punch may declare shelves beside its looks. A shelf owns nothing on any folder, so `owns` does
not mention shelves.

```json5
{
  owns: { tags: ['client'] },
  looks: { zente: { tags: [{ client: 'grey' }] } },
  shelves: {
    clients: { name: 'Clients', symbol: 'person.2' },
  },
}
```

| Field | Rule |
|---|---|
| key (`clients`) | lowercase letters, digits and hyphens; with the punch's name it makes the shelf's identifiers, so it is never renamed in place |
| `name` | the row's name in the sidebar; 1 to 40 characters, no `/` |
| `symbol` | an SF Symbol name; letters, digits and dots; not checked against Apple's catalogue |

A punch with only shelves (no looks) is valid. Validation joins `refuse-a-broken-punch`: an
unknown key under a shelf, a missing name or symbol, or a key in the wrong form is a problem with
its path (`shelves.clients.symbol`).

## The shelf on this Mac

| Part | Where |
|---|---|
| its app | `~/Library/Application Support/punchr/Shelves/<name>.app` |
| identifiers | app `local.punchr.shelf.<punch>.<key>`, extension `….provider`, app group `group.local.punchr.shelf.<punch>.<key>` |
| its domain | identifier `<punch>.<key>`, display name = `name` |
| its links | the domain's `userInfo["links"]`: absolute paths, newline-joined, in the order shelved |
| its folder | `~/Library/CloudStorage/<name>…`, made and removed by the system |

## A link

The item's path as given, made absolute. Its name in the shelf is the item's last path
component; when two links share a name, the second and later get ` 2`, ` 3`, … in shelving order.
A link whose target is missing stays; `punchr shelves` reports `missing`.

## States of a shelf

```
declared ──shelve──▶ set up (not enabled) ──Enable in Finder──▶ shown
   ▲                        │                                    │
   └──── shelves --tidy ◀───┴───────── no longer declared ◀──────┘
```

`shelve` on a declared shelf that is not set up yet generates its app, registers it and adds the
domain; later `shelve` and `unshelve` only change the links. `--tidy` removes shelves no punch
declares any more.
