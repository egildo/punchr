# Struck looks in Finder, by eye (2026-10-22)

Egildo watched an open Finder window on `/tmp/punchr-eye` while `punchr strike` dressed two
scratch folders, macOS 26.6.2. Finder was never restarted.

- **Tag colour without the label bits.** `a` struck with the tag `eye` (orange) showed the orange
  dot and the orange tint at once. punchr writes only the tag attribute, with the colour number;
  the old label bits in the Finder information are not needed.
- **A stamp needs the custom-icon bit.** The first strike wrote the stamp attribute alone and `a`
  stayed a plain orange folder, as the findings had recorded. With the bit set (byte 8, `0x04`)
  the branch symbol appeared, embossed in the folder's own orange. punchr now sets the bit with
  either the stamp or the icon and clears it only when both are gone.
- **The hand-written icon draws.** `b` struck with the stand-in logo (full-colour PNGs at 128 and
  512 px, 20,657 bytes of resource fork) showed the logo in place of the folder.
- **No restart.** Each change appeared in the open window without restarting Finder and without
  any nudge from punchr. The delay was not timed; it was short enough to go unremarked.
