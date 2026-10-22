# punchr

Swift, built with the Command Line Tools only (`./build.sh`, no Xcode). Read `README.md`, then the dated notes under `notes/`.

## Working rules

- Test badges and written looks on scratch folders only. Registering the extension, enabling it and restarting Finder touch the real Finder: ask Egildo first, each time.
- Gate before a merge: `./build.sh` builds clean.
- Rounds go on a branch named `<topic>-round`, merged into `main` with a merge commit (`--no-ff`), the branch deleted after.
- Commit messages end with the model's `Co-Authored-By: Claude … <noreply@anthropic.com>` line.
- Findings go in dated notes, `notes/YYYY-MM-DD-<topic>.md`.
- Logs: `os.Logger`, subsystem `local.punchr`, values marked `privacy: .public`. Read them with `/usr/bin/log show --predicate 'subsystem == "local.punchr"'` (zsh's builtin `log` is something else).
- Name things, not identifiers, in anything Egildo reads.
