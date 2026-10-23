# Implementation Plan: Files wear tags and comments

**Branch**: `files-round` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)

## Summary

`requireFolder` becomes `isFolder`: it answers whether the item is a folder or a regular file,
and refuses anything else, links first. The dress of a file reads only tags and comment. The
strike plan fails a file when the look has a stamp or an icon, before anything is written; for
a file the stamp and icon parts are skipped in strike and clear. Nothing else changes: tags and
the comment are written the same way on a file.

## Decisions

- **Refused before writing.** The check is in the plan, so a refused file gets an error and no
  write, exactly as an unreadable folder does (`fail-per-folder`).
- **Owned but absent is fine.** A punch that owns the stamp or icon may still strike a look
  without them on a file: there is nothing of either to remove.
- **Error wording.** A link: `a link: links are not followed`; neither a folder nor a regular
  file: `not a folder or a file`.
- **Names in code.** `FolderError`, `readDress` and the JSON's `folders` keep their names; the
  contract says an entry can be a file.

## Constitution Check

| Principle | Check |
|---|---|
| Blind to its callers | Pass: any caller can hand punchr a file. |
| Moving state stays live | Pass: a file wears the same parts as a folder, under the same `--live` guard. |
| Touch only what the punch owns | Pass: a file's Finder information and resource fork are never touched. |
| Finder's own doors | Pass: tags in the same attribute, the comment through Finder; measured in `notes/2026-10-23-files.md`. |
| Lean | Pass: one function changed, two guards added. |

The constitution names no folders-only rule (that was the first feature's `folders-only`
requirement, replaced here), so it is not amended.

## Complexity Tracking

None.
