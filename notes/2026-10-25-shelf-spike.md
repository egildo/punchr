# A sidebar row of links: the File Provider spike (2026-10-25)

Question: can punchr put its own row in the Finder sidebar, as OneDrive does, with a standard SF
Symbol, without Xcode or a paid developer account? Answer: yes. The spike's code is in
`experiments/shelf/`; everything it registered was removed afterwards.

## What was built

A host app and a File Provider extension (`com.apple.fileprovider-nonui`, a replicated
extension), compiled with `swiftc -swift-version 5` from the Command Line Tools and ad-hoc
signed, like the Finder Sync extension. The extension is sandboxed with one app group,
`group.local.punchr.shelf`; the host carries the same group. The domain holds no files, only
symbolic links: each item is `.symbolicLink` with a `symlinkTargetPath`. The host passes the
targets in the domain's `userInfo`, which accepts only plain values (strings, numbers, data,
dates): a Swift array raised an exception, so the targets travel as one newline-joined string.
Every write from the system (create, modify, delete, fetch contents) is refused.

The sidebar symbol is one key in the extension's `Info.plist`:
`CFBundleIcons → CFBundlePrimaryIcon → CFBundleSymbolName = books.vertical`. No asset catalog.

## What happened

- **Ad-hoc signing is accepted.** `fileproviderd` registered the extension, created its app-group
  container, and started the domain. No team ID, no provisioning profile.
- **A rebuild drops the extension.** Replacing the bundle in place made `fileproviderd`
  unregister the old extension and ignore the new one (`-2001`, underlying `-2014`, "no launchable
  extension"). Unregistering (`pluginkit -r`, `lsregister -u`) and registering again fixed it.
- **The user must enable it.** The new domain stayed disabled (`-2011`, "sync is not enabled")
  until Egildo clicked Enable on the banner Finder shows inside the row.
- **The row.** "PunchrShelf" with the books symbol, in the top group beside iCloud Drive and
  OneDrive, not under Locations. It carries the app's name, not the domain's display name ("punchr
  test"): the known bug for a single domain.
- **The link works.** After enabling, the extension started, logged one link, and the domain's
  folder (`~/Library/CloudStorage/PunchrShelf-punchrtest`) held a real symbolic link to the
  scratch folder. Finder listed it as an alias; double-clicking it opened the folder.
- **One error mark.** Finder showed a cloud with an exclamation mark on the link: the system kept
  retrying an update of the item (Finder writes small things onto what it shows) and the spike
  refused every modification. A real version would accept and ignore those writes.

## Cleanup

The domain was removed (its CloudStorage folder went with it), the extension unregistered from
PlugInKit and Launch Services, the build and the scratch target deleted, and the app-group
container removed. The extension's empty sandbox container,
`~/Library/Containers/local.punchr.shelf.provider` (32 KB), is protected by macOS and could not be
deleted from a shell; Finder can move it to the Bin.

## For punchr

A "shelf" is feasible: one sidebar row per domain, a standard SF Symbol, contents that are links
to real folders, nothing copied. Open points for a spec: whether several domains show as several
rows with their own names (the single-domain naming bug suggests yes once there are two), how to
rebuild without losing the registration, accepting the system's writes quietly, and whether the
row should live in Punchr.app beside the Finder Sync extension.
