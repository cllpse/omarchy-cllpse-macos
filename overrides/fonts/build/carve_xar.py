#!/usr/bin/env python3
"""Cut the installer package out of a raw disk image: carve_xar.py IMG OUT.pkg

SF-Pro.dmg's volume is APFS, which nothing here reads without root. The
package on it is a xar archive stored in one piece, so it is found by its
"xar!" magic and cut at the end of its heap: the header, the compressed table
of contents, then the furthest offset + length any entry in that table names.
"""

import mmap
import struct
import sys
import zlib
import xml.etree.ElementTree as ET


def main():
    img, dst = sys.argv[1], sys.argv[2]
    with open(img, "rb") as f:
        m = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
        start = m.find(b"xar!")
        if start < 0:
            sys.exit(f"carve_xar.py: no xar archive in {img}")
        header, _, toc_len, toc_raw_len, _ = struct.unpack(">HHQQI", m[start + 4:start + 28])
        toc = zlib.decompress(m[start + header:start + header + toc_len])
        assert len(toc) == toc_raw_len
        heap = 0
        for el in ET.fromstring(toc).iter():
            offset, length = el.find("offset"), el.find("length")
            if length is None:
                length = el.find("size")
            if offset is not None and length is not None:
                heap = max(heap, int(offset.text) + int(length.text))
        with open(dst, "wb") as out:
            out.write(m[start:start + header + toc_len + heap])


if __name__ == "__main__":
    main()
