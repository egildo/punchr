# Feature Specification: Finder comments, and the live guard

**Feature Branch**: `comments-round`

**Created**: 2026-10-23

**Status**: Draft

**Input**: Description from the tabularium session: "Add Finder comments to punchr as a written
look, and a `--live` flag."

## User Scenarios & Testing *(mandatory)*

Tabularium reads repository states that move (ahead, behind, dirty) and wants Finder to show
them before badges exist. Its record skips the Finder comment, so a comment can change every
day without churning the record; tags, stamps and icons are recorded and must not move. This
feature adds the comment as a part a look can hold, and a `--live` flag that lets a caller
promise, and punchr enforce, that a punch writes nothing but live parts.

### User Story 1 - Strike a comment (Priority: P1)

A punch `state` owns the comment and has looks `ahead` (`comment: 'AHEAD'`) and `behind`
(`comment: 'BEHIND'`). Tabularium runs `punchr strike state ahead <folders…>`: the plan shows
`+ comment AHEAD`, and after the strike the folders show AHEAD in the Comments column of a
Finder list view at once, without restarting Finder.

**Independent Test**: strike the look on a scratch folder and look at the Comments column.

**Acceptance Scenarios**:

1. **Given** a folder with no comment, **When** a look with `comment: 'AHEAD'` is struck,
   **Then** the plan lists `+ comment AHEAD`, and Finder's Comments column shows AHEAD.
2. **Given** a folder with a comment written by hand in Get Info, **When** a look of a punch
   that owns the comment is struck, **Then** the plan shows the hand-written comment going,
   marked as not this punch's, and the look's comment replaces it.
3. **Given** a folder wearing `ahead`, **When** `behind` is struck, **Then** BEHIND replaces
   AHEAD; **When** the punch is cleared, **Then** the comment is removed.
4. **Given** a folder wearing `ahead`, **When** `ahead` is struck again, **Then** nothing is
   planned and nothing written.

### User Story 2 - Read a comment (Priority: P2)

`punchr read` reports the comment a folder wears, and a folder matches a look only when its
comment is the look's (or it has none and the look has none), for a punch that owns the comment.

**Acceptance Scenarios**:

1. **Given** a folder struck with `ahead`, **When** it is read, **Then** it wears the comment
   AHEAD and matches `state` / `ahead`.
2. **Given** `--json`, **Then** `wears` has `"comment": "AHEAD"`, or `null` when there is none.

### User Story 3 - The live guard (Priority: P1)

Tabularium passes `--live` when a rule file reads moving states. A punch that owns tags, a stamp
or an icon is then refused before any folder is read, so a moving state can only reach a
comment.

**Acceptance Scenarios**:

1. **Given** a punch owning tags and the comment, **When** `strike` or `clear` runs with
   `--live`, **Then** it stops with status 2 and the problem `owns.tags: a live punch owns only
   comments`, one line for each part it owns besides the comment, and writes nothing.
2. **Given** a punch owning only the comment, **When** it runs with `--live`, **Then** it runs
   as without the flag.

### Edge Cases

- Finder is not allowed to be controlled by the app punchr runs in (Automation refused): each
  folder whose comment would change is reported as failed with a message naming the setting;
  the other parts of that folder already written stay, as for any failed write.
- Finder is not running: macOS starts it to answer.
- A comment with quotes, backslashes, line breaks or accents is written and read back as given;
  Finder stores accented letters decomposed, and punchr compares them as equal.
- An empty `comment: ''` in a look is refused: a look without a comment says "no comment".
- A folder on a volume Finder cannot write a `.DS_Store` on: not tested.

## Requirements *(mandatory)*

- **`punch-may-own-the-comment`**: A punch MAY declare `owns: { comment: true }`; a look MAY then
  hold `comment: '<text>'`, fixed, non-empty text. A look with a comment in a punch that does not
  own it is refused.
- **`own-the-comment-whole`**: A punch that owns the comment owns it whole: strike sets the
  look's comment or removes the one there, including one written by hand; clear removes it. The
  terminal plan marks a removed comment that no look of the punch writes.
- **`write-the-comment-through-finder`**: punchr MUST set and remove a comment through Finder's
  own scripting, so it lands in the folder's attribute and in the parent folder's `.DS_Store`
  and shows at once; removing it MUST leave no comment attribute behind.
- **`refuse-plainly-without-automation`**: When macOS refuses punchr control of Finder, the
  folder MUST be reported with a message that names the Automation setting.
- **`read-the-comment`**: `read` MUST report the comment, and matching MUST compare it for a
  punch that owns it.
- **`comment-in-the-json`**: Every `add`, `remove` and `keep` object, and `read`'s `wears`, MUST
  carry `"comment": "<text>"` or `null`, beside the existing keys, which stay as they are.
- **`live-owns-only-comments`**: With `--live`, `strike` and `clear` MUST refuse, with status 2,
  a punch that owns tags, a stamp or an icon, naming each (`owns.tags`, `owns.stamp`,
  `owns.icon`), before reading any folder. Badges will join comments as live parts later.

## Success Criteria *(mandatory)*

- **`comment-seen-at-once`**: a struck comment shows in an open Finder window's Comments column
  within 5 seconds, without restarting Finder.
- **`comment-strike-then-clear-restores`**: a folder struck with a comment and cleared has every
  attribute byte for byte as before.

## Assumptions

- The comment is the only live part for now; badges join later and need nothing from this
  feature.
- Writing through Finder also changes the parent folder's `.DS_Store`, Finder's own file; that
  is how Finder keeps comments, and outside what the punch owns on the folder.
- The first write makes macOS ask once whether the app punchr runs in may control Finder.
