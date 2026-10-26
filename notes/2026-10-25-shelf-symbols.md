# One symbol per sidebar row: the second shelf test (2026-10-25)

Question for the shelves plan: can each shelf have its own SF Symbol, when the symbol is declared
on the File Provider extension? macOS 26.6.2. Everything was removed afterwards.

- The SDK has no icon, image or symbol on `NSFileProviderDomain` or `NSFileProviderManager`.
- App A, one extension with symbol `person.2`, served two domains, Alpha and Beta.
- App B was a copy of app A with only its identifiers and symbol (`star`) changed by `plutil`
  and re-signed ad hoc; nothing was compiled again. It served one domain, Gamma.
- Finder's sidebar showed three rows: "ShelfA - Alpha" and "ShelfA - Beta", both with two people,
  and "ShelfB" with a star. One extension's domains share its symbol and are named
  "App - Domain"; a lone domain is named after its app.
- The bundle was named "Shelf B"; the row read "ShelfB". Whether spaces survive is still open.
- Cleanup removed the domains, unregistered both apps and deleted them. macOS keeps an empty
  32 KB sandbox container per extension that a shell may not delete; three are left from the two
  spikes (`~/Library/Containers/local.punchr.shelf*.provider`).

Consequence: the shelves plan generates one small app per shelf from a template
(`specs/004-shelves/research.md`).
