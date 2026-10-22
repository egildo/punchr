# Data model: The punch, with read, strike and clear for written looks

## Punch

A JSON5 file, `<name>.json5`, in the punch folder (`$XDG_CONFIG_HOME/punchr/`, by default
`~/.config/punchr/`) or anywhere given by path. The name is the file's name without `.json5`.

| Field | Shape | Rule |
|---|---|---|
| `owns.tags` | list of tag names | the tags this punch may add or remove |
| `owns.stamp` | `true` / `false` (default `false`) | whether this punch may set, replace or remove the stamp |
| `owns.icon` | `true` / `false` (default `false`) | whether this punch may set, replace or remove the custom icon |
| `looks` | map of look name to look | at least one look |

Validation (`refuse-a-broken-punch`), all problems reported together, each with its path in the
file (`looks.zente.tags[1]`):

- an unknown key anywhere;
- a colour that is not one of the eight names below;
- a look's tag not listed in `owns.tags`;
- a look with a stamp when `owns.stamp` is not `true`, or an icon when `owns.icon` is not `true`;
- a look with both a badge and any written part;
- an icon picture that does not exist or cannot be loaded (checked before any folder is touched).

## Look

| Field | Shape |
|---|---|
| `tags` | list of one-key maps, `{ name: colour }`, in the order they are added |
| `stamp` | `{ sym: '<SF Symbol name>' }` or `{ emoji: '<emoji or short word>' }` |
| `icon` | path to a PNG, JPEG or SVG, relative to the punch file |
| `badge` | path to a picture; marks a badge look, ignored by this feature |

A written look has at least one of `tags`, `stamp`, `icon`.

**Colours**, as Finder numbers them: `none` 0, `grey` 1, `green` 2, `purple` 3, `blue` 4,
`yellow` 5, `red` 6, `orange` 7.

## Dress

What a folder wears, read from its attributes; nothing else is consulted.

| Part | Read from |
|---|---|
| tags, in order, each with its colour | `com.apple.metadata:_kMDItemUserTags` (a tag with no number reads as `none`) |
| stamp | `com.apple.icon.folder#S` |
| custom icon | the custom-icon bit (byte 8, `0x04`) of `com.apple.FinderInfo`, and the resource fork of the folder's `Icon\r` |

## Plan

One entry per folder given, in order:

| Field | Meaning |
|---|---|
| `path` | the folder as given |
| `add` | tags (with colour), stamp, icon to be written |
| `remove` | tags, stamp, icon to be removed |
| `keep` | what the punch owns and is already right |
| `error` | why the folder cannot be read or written; the folder is skipped |

**Strike** of look L of punch P on a folder: remove every tag P owns that L does not have, or
has with another colour; add L's tags not present, at the end, in L's order; if P owns the
stamp, set L's stamp or remove the stamp when L has none; the same for the icon. Unowned tags
stay where they are (`keep-unowned-tags`).

**Clear** of P: remove every tag P owns; remove the stamp if P owns it; remove the icon if P
owns it.

An empty `add` and `remove` means nothing is written (`strike-twice-changes-nothing`).

## Icon file

`Icon\r` inside the folder: an empty file whose resource fork holds the `icns`, with the
invisible bit (`0x40`) in byte 8 of its own Finder information. Folders on one volume in one
strike share one inode (hard links). Clearing a folder unlinks its `Icon\r` and clears its
custom-icon bit; the other links keep the bytes.
