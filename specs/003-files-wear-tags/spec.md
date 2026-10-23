# Feature Specification: Files wear tags and comments

**Feature Branch**: `files-round`

**Created**: 2026-10-23

**Status**: Draft

**Input**: Description from the tabularium session: "Let files wear tags and comments, not only
folders."

## User Scenarios & Testing *(mandatory)*

Tabularium marks every item its record leaves out (an untracked item) with a grey `untracked`
tag: on a folder Tahoe tints it grey, on a file Finder shows a grey dot. Some of those items are
files, which punchr refused as not a folder.

### User Story 1 - Tag a file (Priority: P1)

**Acceptance Scenarios**:

1. **Given** a file, **When** a look holding only tags and a comment is struck on it, **Then**
   the file wears them, and Finder shows the tag's dot.
2. **Given** a file, **When** a look holding a stamp or an icon is struck on it, **Then** that
   file is reported as failed, `<path>: a file wears no stamp or icon`, nothing is written to
   it, the other items proceed, and the exit status is 1.
3. **Given** a file wearing a punch's tags and comment, **When** the punch is cleared, **Then**
   they go and everything else on the file stays.
4. **Given** a file, **When** it is read, **Then** it reports its tags and comment, with
   `stamp: null` and `icon: false`, and matches a look by those.

### Edge Cases

- A symbolic link is still refused and never followed.
- A Finder alias is a file: it wears the tags itself; its original is not touched.
- Anything that is neither a folder nor a regular file (a socket, a device) is refused.
- A file's own custom icon or Finder information is never read or written.

## Requirements *(mandatory)*

- **`folders-and-files`** (replaces `folders-only`): punchr MUST act on folders and regular
  files, and MUST NOT follow symbolic links.
- **`a-file-wears-no-stamp-or-icon`**: striking a look with a stamp or an icon on a file MUST
  fail for that file alone, writing nothing to it; `read` MUST report a file's stamp as `null`
  and its icon as `false`.
- **`the-json-keeps-its-keys`**: the JSON keeps `folders[]` and `path` for every item, file or
  folder.
- The comment on a file is written through Finder, as on a folder
  (`write-the-comment-through-finder`).

## Success Criteria *(mandatory)*

- **`file-strike-then-clear-restores`**: a file struck with tags and a comment and then cleared
  has every attribute byte for byte as before.
- **`grey-dot-seen`**: a file struck with a grey tag shows the grey dot in an open Finder window.
