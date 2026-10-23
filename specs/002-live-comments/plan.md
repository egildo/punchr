# Implementation Plan: Finder comments, and the live guard

**Branch**: `comments-round` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)

## Summary

The comment becomes a fourth part beside tags, stamp and icon: owned with `owns.comment`, held
by a look as `comment`, read from its attribute, written through Finder with `NSAppleScript`.
`--live` checks the punch's ownership before anything else. The command's contract is
[001's](../001-punch-and-strike/contracts/cli.md), amended in place.

## Technical Context

As in [001's plan](../001-punch-and-strike/plan.md), plus `NSAppleScript` (Foundation) for the
one Apple event to Finder. No new dependency, no new file.

## Decisions

- **Reading.** From `com.apple.metadata:kMDItemFinderComment`, a binary property list holding
  one string; an empty string reads as no comment. Finder shows the copy in `.DS_Store`, which
  agrees with the attribute whenever Finder wrote it; a comment written to the attribute alone
  reads here but does not show in Finder until Finder rewrites `.DS_Store`. Reading `.DS_Store`
  is left out: it would mean parsing Finder's private format for a disagreement only another
  tool can cause.
- **Writing.** `tell application "Finder" to set comment of (POSIX file "<path>" as alias) to
  "<text>"`, through `NSAppleScript` in punchr's own process (no `osascript` process per
  folder). Path and text go into the script as AppleScript string literals, with `\` and `"`
  escaped. Removing sets the comment to empty, then removes the attribute, because Finder leaves
  an empty string behind (measured, `notes/2026-10-23-comments.md`).
- **Comparing.** Finder stores accented letters decomposed; Swift compares strings by canonical
  equivalence, so a look's `é` matches Finder's `e` + accent and a second strike changes
  nothing.
- **Refusal.** Error -1743 (`errAEEventNotPermitted`) becomes "macOS does not let punchr control
  Finder: allow it in System Settings → Privacy & Security → Automation"; any other Finder error
  is passed on with its number.
- **The live guard.** A function in `Punch.swift` lists one problem for each of `owns.tags` (when
  not empty), `owns.stamp`, `owns.icon`: "a live punch owns only comments". `main.swift` calls
  it after loading the punch for `strike` and `clear` under `--live`, and stops with status 2
  and the problems, as for a refused punch. `read` takes no `--live`: it writes nothing.
- **Marking a hand-written comment.** The terminal line reads `− comment <text> (not this
  punch's)` when no look of the punch writes that text. JSON is unchanged by this: `remove`
  carries the text.

## Constitution Check

| Principle | Check |
|---|---|
| Blind to its callers | Pass: `--live` is a promise any caller can make; no caller is named in code. |
| Moving state stays live | Pass: the comment is a live part (constitution 2.0.0); `--live` refuses anything else. |
| Touch only what the punch owns | Pass: the comment is owned whole, declared in `owns`, shown in the plan; Finder's `.DS_Store` in the parent changes as Finder's own bookkeeping of that comment. |
| Finder's own doors | Pass: written through Finder's scripting; formats measured in `notes/2026-10-23-comments.md`. |
| Lean | Pass: one function to read, one to write, one for the guard; no new file or dependency. |

## Complexity Tracking

None.
