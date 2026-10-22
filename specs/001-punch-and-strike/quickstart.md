# Quickstart: proving the punch, read, strike and clear

Everything here runs in a scratch folder. Nothing touches a real project, and nothing needs the
Finder extension registered or Finder restarted.

## 1. The checks

```sh
./build.sh check
```

Builds the app and the check program, then runs the checks in a fresh temporary folder and
deletes it. Expected: one `✓` line per check, exit status 0. They cover:

- a broken punch is refused with every problem named, and no folder changes
  (`refuse-a-broken-punch`);
- strike then clear leaves a folder byte for byte as it was (`strike-then-clear-restores`);
- a folder with foreign tags, a foreign stamp and foreign attributes keeps all of them through
  strike and clear of a punch that owns none of them (`nothing-unowned-changes`,
  `keep-unowned-tags`);
- the Finder information keeps every byte but the icon bit (`set-only-the-icon-bit`);
- a forced write ends exactly where the plan said (`plan-matches-write`);
- a second strike plans nothing and writes nothing (`strike-twice-changes-nothing`);
- twelve folders struck with one icon share one inode, and clearing one leaves the others
  (`share-one-icon-per-volume`, `clear-one-keeps-the-others`, `icon-costs-kilobytes`);
- reading 1,000 folders takes under 5 seconds (`read-a-thousand`);
- a file, a symbolic link and an unwritable folder are reported and skipped, the others proceed,
  exit status 1 (`fail-per-folder`, `folders-only`).

## 2. By eye, in Finder (with Egildo)

These two are what the checks cannot see. Make a scratch folder, put a punch beside it, open
the folder in a Finder window, and leave the window open.

```sh
mkdir -p /tmp/punchr-eye/a /tmp/punchr-eye/b
cp experiments/standin.svg /tmp/punchr-eye/
cat > /tmp/punchr-eye/eye.json5 <<'EOF'
{
  owns: { tags: ['eye'], stamp: true, icon: true },
  looks: {
    tagged:  { tags: [{ eye: 'orange' }], stamp: { sym: 'arrow.triangle.branch' } },
    pictured: { icon: 'standin.svg' },
  },
}
EOF
open /tmp/punchr-eye
build/punchr strike /tmp/punchr-eye/eye.json5 tagged /tmp/punchr-eye/a --force
build/punchr strike /tmp/punchr-eye/eye.json5 pictured /tmp/punchr-eye/b --force
```

Expected, within 5 seconds and without restarting Finder (`seen-without-restart`):

- `a` shows an orange tag and is tinted orange, with the branch symbol embossed on it. If the
  tag shows but without its colour, Finder needs the label bits too (see research).
- `b` shows the stand-in logo as its icon.

Then:

```sh
build/punchr read /tmp/punchr-eye/a /tmp/punchr-eye/b --punch /tmp/punchr-eye/eye.json5
build/punchr clear /tmp/punchr-eye/eye.json5 /tmp/punchr-eye/a /tmp/punchr-eye/b --force
```

Expected: `read` reports `eye` / `tagged` for `a` and `eye` / `pictured` for `b`; after `clear`
both folders are plain again in the open window.

What is seen goes into a dated note under `notes/`.
