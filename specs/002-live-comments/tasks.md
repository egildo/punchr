---

description: "Tasks for Finder comments and the live guard"
---

# Tasks: Finder comments, and the live guard

**Input**: [spec.md](spec.md), [plan.md](plan.md)

**Checks**: assert functions in `Sources/checks/main.swift`, named after what they prove, run by
`./build.sh check` in a temporary folder. The comment checks send Apple events to Finder for
folders inside that temporary folder only.

## Phase 1: Comments

- [ ] T001 Measure the comment on a scratch folder (set, clear, accents, a comment written to the attribute alone) and write `notes/2026-10-23-comments.md`
- [ ] T002 In `Sources/core/Punch.swift`, read `owns.comment` and a look's `comment`; refuse an empty comment and a comment the punch does not own (`punch-may-own-the-comment`)
- [ ] T003 In `Sources/core/Dress.swift`, read the comment into the dress, and write it through Finder with the refusal message (`write-the-comment-through-finder`, `refuse-plainly-without-automation`, `read-the-comment`)
- [ ] T004 In `Sources/core/Plan.swift`, plan, carry out and match the comment (`own-the-comment-whole`)
- [ ] T005 In `Sources/app/main.swift`, plan lines `+ comment`, `− comment`, the hand-written mark, `read`'s line, and `comment` in every parts object and in `wears` (`comment-in-the-json`)
- [ ] T006 Checks: the client punch owns the comment and `zente` holds one, so strike, strike twice, one look per punch, read and strike-then-clear cover it; a hand-written comment is replaced; quotes, line breaks and accents round-trip (`comment-strike-then-clear-restores`)

## Phase 2: The live guard

- [ ] T007 In `Sources/core/Punch.swift`, the live problems of a punch; in `Sources/app/main.swift`, `--live` on `strike` and `clear` (`live-owns-only-comments`)
- [ ] T008 Check: a punch owning tags, stamp, icon and comment has three live problems, a comments-only punch none; the command exits 2 with the JSON problems

## Phase 3: Polish

- [ ] T009 By eye: a struck comment in an open Finder window's Comments column (`comment-seen-at-once`); add it to the note
- [ ] T010 README, the CLI contract, version 0.2.0 in both `Info.plist` files
- [ ] T011 Gate: `./build.sh` and `./build.sh check` clean; merge `comments-round` with `--no-ff`
