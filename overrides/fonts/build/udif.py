#!/usr/bin/env python3
"""Decode a UDIF disk image (.dmg) into a raw one: udif.py IN.dmg OUT.img

Apple's font DMGs are UDIF: a koly trailer points at a plist whose blkx
entries list the image in chunks, each stored raw, zero-filled or compressed.
SF-Pro.dmg uses LZFSE, which needs pyliblzfse; zlib, bzip2 and LZMA are in
the standard library. Zero-filled chunks are left as holes in the output.
"""

import bz2
import lzma
import plistlib
import struct
import sys
import zlib

SKIP = {0x00000000, 0x00000002, 0xFFFFFFFE, 0xFFFFFFFF}  # zero fill, ignore, comment, end


def decode(kind, raw):
    if kind == 0x00000001:
        return raw
    if kind == 0x80000005:
        return zlib.decompress(raw)
    if kind == 0x80000006:
        return bz2.decompress(raw)
    if kind == 0x80000007:
        import liblzfse
        return liblzfse.decompress(raw)
    if kind == 0x80000008:
        return lzma.decompress(raw)
    sys.exit(f"udif.py: chunk type {kind:#x} is not handled")


def main():
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, "rb") as f, open(dst, "wb") as out:
        f.seek(-512, 2)
        koly = f.read(512)
        if koly[:4] != b"koly":
            sys.exit(f"udif.py: {src} has no koly trailer, so it is not UDIF")
        data_fork, = struct.unpack(">Q", koly[0x18:0x20])
        xml_off, xml_len = struct.unpack(">QQ", koly[0xD8:0xE8])
        f.seek(xml_off)
        for entry in plistlib.loads(f.read(xml_len))["resource-fork"]["blkx"]:
            mish = entry["Data"]
            first, = struct.unpack(">Q", mish[8:16])
            base, = struct.unpack(">Q", mish[24:32])
            count, = struct.unpack(">I", mish[0xC8:0xCC])
            for i in range(count):
                kind, _, sector, sectors, offset, length = struct.unpack(
                    ">IIQQQQ", mish[0xCC + 40 * i:0xCC + 40 * (i + 1)])
                if kind in SKIP:
                    continue
                f.seek(data_fork + base + offset)
                blob = decode(kind, f.read(length))
                assert len(blob) == sectors * 512, (hex(kind), len(blob), sectors)
                out.seek((first + sector) * 512)
                out.write(blob)


if __name__ == "__main__":
    main()
