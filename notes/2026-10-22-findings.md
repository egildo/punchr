# punchr: findings before the first commit (2026-10-22)

Gathered in a tabularium session, tested on scratch folders only, macOS 26.6.2 (Tahoe), Apple silicon, Command Line Tools with Swift 6.3.3, no Xcode, no signing certificate.

## What punchr is

A small macOS tool that dresses folders in Finder according to a state another program names. Tabularium, or anything else, says "this folder is *ahead*"; a **mold** file says what *ahead* looks like. punchr knows nothing about git or tabularium.

Vocabulary so far: the **mold** maps named **looks** to visuals; a **stamp** is the symbol, emoji or word on a folder; a **badge** is the live overlay. The name follows type founding: the punch is struck into the matrix (the mold) that casts the letter.

Two renderers, one mold:

- **Badges** for looks that follow a state (ahead, behind, dirty, syncing): drawn live by a Finder Sync extension, nothing written to disk, so a record such as tabularium's never churns.
- **Written looks** for looks that do not move (a client's logo, a project's code name): attributes on the folder itself, so they survive copies and tabularium's record carries them.

A first sketch of the mold, not settled:

```yaml
mold: repository
owns: [tabularium, ahead, behind, dirty]   # tags this mold may add or remove
looks:
  safe:   { tags: [{ tabularium: grey }],  stamp: { sym: arrow.triangle.branch } }
  ahead:  { badge: badges/ahead.svg }
  zente:  { icon: logos/zente.svg }
```

Verbs sketched: `read <folder>…` (what it wears, which look it matches, JSON out), `write <mold> <look> <folder>…` (plan first, `--force` to write, touches only what the mold owns), `clear <mold> <folder>…`. Open: one look per folder or several combined in order, CSS-like (tags add up; for stamp and icon the last wins).

## Written looks: what Finder offers

All measured on this Mac.

| Look | Where it lives | Size | Notes |
|---|---|---|---|
| Tags | `com.apple.metadata:_kMDItemUserTags`, binary plist of `"name\nN"` strings | small | Seven colours only: 0 none, 1 grey, 2 green, 3 purple, 4 blue, 5 yellow, 6 red, 7 orange. On Tahoe a coloured tag also tints the folder (Finder setting "Tint folder based on tags"). Finder mirrors the tag colour into the old label bits of `com.apple.FinderInfo` (byte 9, bits 1–3). |
| Folder colour (Customize Folder…) | just a tag | small | The menu offers only the seven colours. Choosing Giallo wrote the tag `Giallo` with **no colour number**: it is yellow only because Giallo is in this user's tag list. Write the number explicitly. |
| Stamp (Tahoe only) | `com.apple.icon.folder#S` = `{"sym":"<SF Symbol>"}` or `{"emoji":"<text>"}`, plus the custom-icon bit `0x04` in byte 8 of the folder's `com.apple.FinderInfo` | about 25 bytes | Without the bit the folder stays plain. Works: public and private SF Symbols (`apple.logo`), colour emoji (kept in colour), system-font characters (⎇), short words ("ZENTE"). Does not work: installed icon fonts (a Material Symbols glyph showed as a "?" box). Embossed in the folder's own colour; follows tint and dark mode; not shown in the Dock or on aliases; plain folder on older macOS. `#S` keeps it through iCloud sync. |
| Custom icon (any picture) | file: `com.apple.ResourceFork` on the file; folder: a hidden empty file `Icon\r` inside, carrying the fork, with the invisible bit `0x40` in its FinderInfo byte 8, and `0x04` on the folder | see below | Replaces the folder shape; fixed picture, no tint. |
| Finder comment | `com.apple.metadata:kMDItemFinderComment`, also copied into `.DS_Store` | small | Shown in list view's Comments column and Get Info. |

**Custom icons, cheaply.** `NSWorkspace.setIcon` renders every size and wrote a 1.3 MB fork (389 KB even from a 128 px source). Writing the icon by hand (`experiments/lean-icon.ts`): an `icns` with only `ic07` (128 px) and `ic09` (512 px) as 64-colour PNGs, wrapped in a resource fork holding one `icns` resource with id -16455, came to **5,251 bytes**. Finder drew it. Several folders can share one copy: `Icon\r` in every folder after the first is a **hard link** to the first (attributes belong to the inode), so 136 folders cost 5 KB once. Hard links stay on one volume; a copy elsewhere carries its own 5 KB.

Costs of the `Icon\r` file inside a git repository: git sees it as untracked (add `Icon?` to the global gitignore), and tabularium's record does not look inside a repository, so the tool must reapply it. The scratch script overwrites the whole FinderInfo; the real tool must change only its bit.

Folder window options (view style, background, icon positions) live in `.DS_Store`, not in attributes; prior art is `dmgbuild`. Left out.

## Badges: the Finder Sync extension

The test in `Sources/` worked: a 35-line extension, built with `swiftc`, **ad-hoc signed and sandboxed**, drew an orange badge on `lean-a`. No Xcode, no developer account.

- Weight: 164 KB on disk for the app (the extension binary 81 KB); 7 MB of memory, 0% CPU at rest.
- Build: `-parse-as-library`, link with `-e _NSExtensionMain`, frameworks FinderSync and Cocoa; the extension's principal class is `<module>.FinderSync`; its package type is `XPC!`; the only entitlement is `com.apple.security.app-sandbox`. Sign the extension first, then the app. See `build.sh`.
- Registration: `pluginkit -a` alone did nothing; it took after `lsregister -f -R` on the app. Then the user enables it (System Settings → General → Login Items & Extensions, or `pluginkit -e use -i <id>`).
- **Finder loads extensions only when it starts.** After enabling or rebuilding, restart Finder (`killall Finder`), or the extension idles and is never asked.
- Logging: `NSLog` lines are redacted; use `os.Logger` with `privacy: .public`. zsh has a builtin called `log`, so call `/usr/bin/log show --predicate 'subsystem == "local.punchr"'`.
- One badge per item; one extension per folder (the first to start wins; Apple has no arbiter). OneDrive's extension is installed here but watches only its own folder.
- The App Intents errors (`com.apple.linkd.autoShortcut`, code 4097) in the extension's log are harmless.
- Not tested yet: pushing a new badge when the state changes (`setBadgeIdentifier` at any time), the feed file, context menus.
- This Mac has no MDM or configuration profile. The Tahoe reports of extensions that never load were security software (Microsoft Defender) denying extension points.

## Prior art: Liferay Nativity (archived 2024, LGPL, Java client)

A cross-platform library for overlay icons and context menus (Finder, Explorer, Nautilus); clients send JSON over a socket. What to borrow:

1. Finder asks, the tool answers (`getIconForFile(path)`); add what Nativity lacks on macOS, a push on change.
2. Icons registered by id at run time (`registerIconWithId(path, label, id)`): a look's name is the badge id.
3. A filter folder (`setFilterFolder`): only declared roots are watched.
4. Context menus by callback (`getContextMenuItems(paths)` → items with `onSelection(paths)`): the mold could declare menu items as commands run with the paths; the sandboxed extension cannot run them, the host app must.
5. Separate modules: control, badges, menus; punchr adds written looks.
6. Language-agnostic by design. Simpler for punchr: a JSON feed file (path → look) the extension watches, readable through one read-only sandbox exception; no client library, no live connection, survives restarts.

Its warnings: one Finder Sync per folder; the sandbox exception would likely be rejected by the App Store (irrelevant: no App Store); the pre-Yosemite Finder injection broke on every Finder update (stay on Finder Sync); Windows' 15-overlay limit (a reason to stay Mac-only).

Other prior art: TortoiseGit and TortoiseSVN overlays; Starship's git prompt (`⇡` ahead, `⇣` behind) for state-to-symbol mapping; LittleGit (2015) and FinderGitBadge (git-only, fixed); SyncExtensionTest (reads a badge from each file's attributes); Grimace (sets Tahoe stamps).

## Installing it

1. **Homebrew formula that builds from source** (the pick): `brew install egildo/apps/punchr` compiles with the user's own `swiftc` (Homebrew already requires the Command Line Tools). A locally built app is never quarantined, so ad-hoc signing suffices.
2. Cask with a prebuilt app: quarantined; the user must click "Open Anyway"; untested whether a quarantined extension loads.
3. Developer ID and notarisation ($99 a year): the proper route for downloads, worth it only with users beyond Egildo.
4. Mac App Store: no.

Whatever the route, a `punchr setup` verb registers and enables the extension and, after asking, restarts Finder.

## Brief for naming and logo (kept for the record; the name is now punchr)

Logo constraints: readable at 16 px (the tool's product is badges, so the logo can be one), plus an app icon. Directions: a punch and its counter, a seal, a stamp on a folder. The sibling tools are named in Latin (tabularium, consequitur).

## In this folder

- `Sources/FinderSync.swift`, `Sources/main.swift`: the test extension and its empty host app (bundle ids `local.punchr`, `local.punchr.findersync`; it watches the user's home and badges any folder named `lean-a`).
- `Support/`: the two `Info.plist` files and the extension's entitlements.
- `build.sh`: builds `build/Punchr.app`; `./build.sh register` also registers it.
- `experiments/lean-icon.ts`: writes a hand-made icon and hard-links it into folders (Deno). `experiments/standin.svg`: the stand-in git-like logo.

Remote to be: Codeberg (egildo). Not created.
