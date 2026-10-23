---

description: "Tasks for files wearing tags and comments"
---

# Tasks: Files wear tags and comments

**Input**: [spec.md](spec.md), [plan.md](plan.md)

- [x] T001 In `Sources/core/Dress.swift`, `isFolder` in place of `requireFolder`; a file's dress is tags and comment (`folders-and-files`)
- [x] T002 In `Sources/core/Plan.swift`, fail a file struck with a stamp or icon look; skip stamp and icon for files in strike and clear (`a-file-wears-no-stamp-or-icon`)
- [x] T003 Checks: the folders-only check now strikes the file and refuses the link; a file struck with tags and a comment then cleared is restored; a stamp look on a file fails and writes nothing; the command's error line and JSON
- [x] T004 By eye: a grey-tagged file shows the grey dot (`grey-dot-seen`); write `notes/2026-10-23-files.md`
- [x] T005 README, the CLI contract, version 0.3.0; amend `folders-only` in the first spec to point here
- [x] T006 Gate: `./build.sh` and `./build.sh check` clean; merge `files-round` with `--no-ff`
