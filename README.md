# punchr

**Dresses folders in Finder by the state another program names.**

Tabularium, or anything else, says a folder is *ahead*; a **punch** says what *ahead* looks like. punchr knows nothing about git or tabularium. One punch, two renderers: **badges**, drawn live by a Finder Sync extension, for looks that follow a state (ahead, behind, dirty, syncing), with nothing written to disk; and **written looks** (tags, stamps, custom icons) stored on the folder itself, for looks that do not move.

Named for type founding: a letter's punch is cut once in steel and struck into every matrix that casts it, as a punch here is written once and struck onto every folder that wears its looks.

## Status

A prototype. The extension draws one test badge on any folder named `lean-a` under your home. The punch, the verbs and the feed file are not written yet. What was measured so far is in [notes/2026-10-22-findings.md](notes/2026-10-22-findings.md).

## Build

Needs macOS 26 (Tahoe) and the Command Line Tools; no Xcode, no developer account.

```sh
./build.sh            # builds build/Punchr.app, ad-hoc signed, the extension sandboxed
./build.sh register   # also registers it with Launch Services and PlugInKit
```

Then enable the extension (System Settings → General → Login Items & Extensions, or `pluginkit -e use -i local.punchr.findersync`) and restart Finder (`killall Finder`): Finder loads extensions only when it starts.

`experiments/lean-icon.ts` writes a hand-made 5 KB folder icon and hard-links it into several folders (Deno).

## Licence

MIT.
