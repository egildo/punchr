# Research: The punch, with read, strike and clear for written looks

Measured on 2026-10-22, macOS 26.6.2, Command Line Tools with Swift 6.3.3, on scratch files in
the session's scratchpad. The Finder formats themselves were measured earlier and are recorded
in [the findings](../../notes/2026-10-22-findings.md); they are not repeated here.

## The punch file's format

- **Decision**: JSON5, read by Foundation's own decoder (`allowsJSON5`). One file per punch,
  `<name>.json5`; the punch's name is the file's name.
- **Rationale**: Swift has no YAML reader, and the constitution forbids a third-party
  dependency and a package manager without a plan that justifies them. JSON5 is the humane
  part of YAML that matters for a hand-written file (comments, unquoted keys, single quotes,
  trailing commas) and Foundation reads it natively. Measured: a punch with a comment, bare
  keys, single quotes and trailing commas decoded on the first try.
- **Alternatives considered**: YAML through the Yams package (needs SwiftPM and a dependency);
  a hand-written YAML-subset reader (code the constitution's Lean principle forbids, and a
  second dialect of YAML); property lists (native, but miserable to write by hand); KDL, as in
  consequitur (no Swift reader).
- **Consequence**: the findings' sketch (`mold: repository` at the top) loses its name key; the
  file name carries it.

## Where the program lives

- **Decision**: the host app's executable is the command-line tool. `Punchr.app/Contents/MacOS/Punchr`
  answers `read`, `strike` and `clear`; `build.sh` adds a `build/punchr` symbolic link to it,
  and the Homebrew formula will link it into `bin/`.
- **Rationale**: the app must exist anyway as the extension's parent and does nothing else. One
  binary less. The host app is not sandboxed, so it can write any folder the user can.
- **Alternatives considered**: a separate `punchr` executable beside the app (a second binary
  and a second build line for no gain).

## Arguments

- **Decision**: parse `CommandLine.arguments` by hand.
- **Rationale**: three verbs and two flags (`--force`, `--json`). Swift Argument Parser would be
  the first dependency and the first reason for SwiftPM.

## Rendering the custom icon

- **Decision**: load the picture with `NSImage` (PNG, JPEG or SVG), draw it at 128 and 512
  pixels, store both as PNG in an `icns` holding only `ic07` and `ic09`, wrapped in a resource
  fork with one `icns` resource, id -16455, as `experiments/lean-icon.ts` does.
- **Measured**: `NSImage` reads SVG natively (the stand-in logo loaded at 100 × 100 points).
  Rendered in full colour, the stand-in logo is 3,174 bytes at 128 px and 17,149 bytes at
  512 px: about 20 KB with the headers. Cutting colour depth by masking bits barely helps
  (12–14 KB at 512 px); the 5,251 bytes of the findings came from PNGs already reduced to a
  64-colour palette outside punchr.
- **Consequence for the spec**: `icon-costs-kilobytes` said under 10 KB. Reaching that needs a
  hand-written palette-PNG encoder (palette, transparency table, zlib wrapper, CRC: roughly 80
  lines). The plan takes full colour and amends the outcome to **under 25 KB**: the icon is
  shared by every folder on the volume, so 100 folders still cost about 20 KB in total, 65
  times less than the system's own call. The palette encoder is parked until a real logo shows
  it matters.
- **Alternatives considered**: the palette encoder (above); 128 and 256 px only (about 10 KB,
  but soft at Finder's largest sizes); passing a user's own pre-reduced PNG through unchanged
  (a second path for the same thing).

## Sharing one icon per volume

- **Decision**: within one `strike`, the first folder on each volume gets a real `Icon\r`; every
  other folder on the same volume (same device number) gets a hard link to it. A folder whose
  `Icon\r` already holds exactly the bytes punchr would write is left alone, and serves as the
  file the others in the same strike link to.
- **Rationale**: the findings measured hard links working for Finder; the device number is the
  standard test for "same volume".
- **Ceiling**: two separate strikes of the same look on one volume make two copies. A shared
  store at the volume's root would avoid that, at the cost of writing outside the folders
  struck; not worth it yet.

## Knowing which look a folder wears

- **Decision**: a folder matches look L of punch P when everything P owns on that folder is
  exactly what L puts there: the owned tags present are L's tags with L's colours; if P owns
  the stamp, the stamp is L's (or absent when L has none); if P owns the icon, the `Icon\r`
  resource fork is byte for byte what punchr renders for L (or absent when L has none).
- **Rationale**: no extra attribute is written to remember what was struck, so nothing beyond
  the look itself reaches tabularium's record. A folder dressed by hand exactly like a look
  matches it, which is the truth.
- **Risk**: if a macOS update changes how `NSImage` renders, old icons stop matching and the
  next strike rewrites them. Harmless.

## Leaving no trace after clear

- **Decision**: when clearing leaves a folder's Finder information all zeros, the attribute is
  removed; when it leaves no tags, the tag attribute is removed. Finder does the same.
- **Rationale**: `strike-then-clear-restores` asks for the folder byte for byte as it was.

## Writing the attributes

- **Decision**: Darwin's `getxattr`, `setxattr`, `removexattr` and `listxattr`, always with
  `XATTR_NOFOLLOW`; tags through `PropertyListSerialization` as a binary property list of
  `"name\nN"` strings, the colour number always written; the stamp as the JSON object Finder
  writes (`{"sym": …}` or `{"emoji": …}`) under `com.apple.icon.folder#S`.
- **Rationale**: all in the standard library; formats as measured in the findings.

## Checks

- **Decision**: an assert-based check program, `Sources/checks/main.swift`, compiled with the
  same core files and run by `./build.sh check`. It works only in a fresh temporary folder and
  deletes it after.
- **Measured**: the Command Line Tools carry Swift Testing but no `xctest`; using Swift Testing
  without SwiftPM means linking test frameworks by hand. An assert program needs nothing.

## Measured by eye in Finder

Both open points were settled on 2026-10-22, recorded in
[the note](../../notes/2026-10-22-finder-by-eye.md):

- A tag's colour and the folder's tint show from the tag attribute alone; the old label bits
  are not needed.
- Struck tags, stamps and icons appear in an open Finder window without restarting Finder and
  without any nudge from punchr.

The same look found a mistake: a stamp shows only with the custom-icon bit, which the first
build did not set. The stamp and the icon now share that bit (see the data model).
