#!/usr/bin/env python3
"""Copy Apple's faces for the patcher without name ID 13: drop_license.py OUTDIR FONT...

ID 13 is Apple's license, 60 KB of UTF-16. fontforge writes it again for the
Mac platform, which takes the name table past what its 16-bit offsets reach,
and every record stored after the overflow points at the wrong bytes: in the
Medium, SemiBold and Light faces the family names read as glyph names.
restore_layout.py puts Apple's record back, once. Nothing else is touched:
fontTools copies every other table as it is.
"""

import os
import sys

from fontTools.ttLib import TTFont


def main():
    out = sys.argv[1]
    for path in sys.argv[2:]:
        font = TTFont(path)
        font["name"].names = [r for r in font["name"].names if r.nameID != 13]
        font.save(os.path.join(out, os.path.basename(path)))


if __name__ == "__main__":
    main()
