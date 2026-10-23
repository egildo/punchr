# punchr

**Dresses folders in Finder by the state another program names.**

Tabularium, or anything else, says a folder is *ahead*; a **punch** says what *ahead* looks like. punchr knows nothing about git or tabularium. One punch, two renderers: **badges**, drawn live by a Finder Sync extension, for looks that follow a state (ahead, behind, dirty, syncing), with nothing written to disk; and **written looks** (tags, stamps, custom icons, Finder comments) stored on the folder itself. Tags, stamps and icons are for looks that do not move; a comment may follow a state, because records such as tabularium's leave it out.

Named for type founding: a letter's punch is cut once in steel and struck into every matrix that casts it, as a punch here is written once and struck onto every folder that wears its looks.

## Status

Written looks work: `read`, `strike` and `clear`, checked on scratch folders and by eye in Finder; comments joined them in 0.2.0. Badges do not yet: the extension still draws one test badge on any folder named `lean-a` under your home, and the feed file that will drive it is not written. The first feature's spec, plan and tasks are in [specs/001-punch-and-strike](specs/001-punch-and-strike/spec.md); comments and `--live` are in [specs/002-live-comments](specs/002-live-comments/spec.md); what was measured is in the dated notes under [notes/](notes/).

## The punch

A punch is a JSON5 file (JSON with comments, bare keys, single quotes and trailing commas), kept in `~/.config/punchr/` and named by its file name. It says what it owns and what each look puts there:

```json5
// ~/.config/punchr/client.json5
{
  owns: { tags: ['client'], stamp: true, icon: true },
  looks: {
    zente: { tags: [{ client: 'grey' }], icon: 'logos/zente.svg' },
    acme:  { tags: [{ client: 'grey' }], stamp: { emoji: 'ACME' } },
  },
}
```

Tag colours are Finder's seven, or `none`: grey, green, purple, blue, yellow, red, orange. A stamp is an SF Symbol (`{ sym: 'arrow.triangle.branch' }`), or an emoji or short word (`{ emoji: '🦊' }`); icon fonts do not work. An icon is a PNG, JPEG or SVG, relative to the punch file. A punch touches only what it owns: other tags, attributes and stamps stay as they are.

A punch may also own the Finder comment, the text in Get Info and in a list view's Comments column, and a look may set it to fixed text:

```json5
// ~/.config/punchr/state.json5
{
  owns: { comment: true },
  looks: { ahead: { comment: 'AHEAD' }, behind: { comment: 'BEHIND' } }, // clear removes it
}
```

A punch that owns the comment owns it whole: a comment written by hand is replaced, and the plan marks it `(not this punch's)`. punchr sets the comment through Finder itself, so Finder shows it at once; Finder also keeps a copy in the parent folder's `.DS_Store`. The first time, macOS asks for permission to control Finder. If that is refused, each folder fails with a message pointing to System Settings → Privacy & Security → Automation, where it can be allowed later.

```
punchr read <folder>... [--punch <punch>]...                  what each folder wears, and which look it matches
punchr strike <punch> <look> <folder>... [--force] [--live]   dress the folders in a look
punchr clear <punch> <folder>... [--force] [--live]           remove what the punch owns
```

`--live` is a promise from the caller that the look follows a state: punchr then refuses, with status 2, a punch that owns tags, a stamp or an icon, so a moving state can only reach a comment.

`strike` and `clear` show their plan first. At a terminal they ask before writing; `--force` writes without asking; in a pipe or with `--json` they stop at the plan. A punch is a name in `~/.config/punchr/` or a path. A folder wears one look of each punch at a time. Folders on one volume struck together share one icon file of about 20 KB, through hard links.

A custom icon is a hidden `Icon\r` file inside the folder. In a git repository it shows up as untracked; add `Icon?` to your global gitignore.

## Build

Needs macOS 26 (Tahoe) and the Command Line Tools; no Xcode, no developer account.

```sh
./build.sh            # builds build/Punchr.app, ad-hoc signed, the extension sandboxed; build/punchr is the command
./build.sh check      # also runs the checks, in a temporary folder
./build.sh register   # also registers it with Launch Services and PlugInKit
```

The extension is needed only for badges. To try it, enable it (System Settings → General → Login Items & Extensions, or `pluginkit -e use -i local.punchr.findersync`) and restart Finder (`killall Finder`): Finder loads extensions only when it starts.

`experiments/lean-icon.ts` writes a hand-made 5 KB folder icon and hard-links it into several folders (Deno).

## Licence

MIT.
