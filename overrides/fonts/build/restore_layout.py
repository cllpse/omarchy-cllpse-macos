#!/usr/bin/env python3
"""Give a Nerd-patched SF face back Apple's layout: restore_layout.py APPLE PATCHED OUT

The Nerd Font patcher runs on fontforge, which renumbers every glyph in
Unicode order and recompiles GSUB and GPOS. In SF Pro's uprights the kerning
lookup no longer fits its 16-bit offsets after that, and fontforge writes it
truncated ("Will not be useable"): every kerning pair comes out 0, in the faces
this repo shipped until 2026-10-24 too. Moving Apple's own tables back in is
not enough alone. Under fontforge's glyph order the same lookup overflows in
fontTools as well, which splits it and loses pairs ("78" lost its -30).

So, in order:

  1. Apple's GSUB and GPOS, with the few glyphs the patcher replaced (6 in
     22.0: power symbols and a heart, which Nerd glyphs took over) pruned out
     by fontTools' subsetter, closure off so nothing else changes.
  2. The patched font's glyphs put back in Apple's order, the Nerd glyphs
     after them, so the tables compile as compactly as Apple's did.
  3. fontforge's GDEF dropped (Apple ships none, and its classes would change
     how Apple's lookups skip marks), and its glyph-indexed PfEd table.
  4. Apple's name records 256 and up, the stylistic set and character variant
     names Apple's GSUB points at, which fontforge renumbers, and Apple's
     license (ID 13), which drop_license.py kept from the patcher. Once, for
     the Windows platform, as Apple ships it.

Then it checks its own output: the family and style names in plain ASCII,
every glyph's charstring, advance and cmap entry as the patcher left them,
and a corpus shaped with HarfBuzz, with and
without features, glyph for glyph and position for position against Apple's
face. Any difference exits non-zero.
"""

import sys

import uharfbuzz as hb
from fontTools import subset
from fontTools.ttLib import TTFont

# Kerning pairs, figures, fractions, ligatures, case and small caps, accents,
# Greek and Cyrillic, punctuation.
TEXTS = [
    "AVATAR To Type, Wave. Yo! LT P. f. rv y, Té Ŵ Ľ",
    "The quick brown fox jumps over the lazy dog 0123456789",
    "1/2 3/4 10:45 (H) [x] {y} -> --- ... “quoted” ‘it’s’",
    "ffi ffl fi fl ff Office Th Tw Tr",
    "Ørsted Æble ÅÄÖ ß ẞ İ ı Ǆ",
    "Ελληνικά Кириллица Український",
    "H₂O x² 1st 2nd @#&*%$€£¥ ©®™ §¶ • · ‰",
]
FEATURES = [{}, {"kern": False}, {"liga": False}, {"tnum": True}, {"frac": True},
            {"case": True}, {"smcp": True}, {"sups": True}, {"ss01": True},
            {"ss02": True}, {"ss06": True}, {"cv01": True}]


def shaped(path):
    font = hb.Font(hb.Face(hb.Blob.from_file_path(path)))
    order = TTFont(path, lazy=True).getGlyphOrder()
    runs = []
    for text in TEXTS:
        for features in FEATURES:
            buf = hb.Buffer()
            buf.add_str(text)
            buf.guess_segment_properties()
            hb.shape(font, buf, features)
            runs.append([(order[i.codepoint], p.x_advance, p.x_offset, p.y_offset)
                         for i, p in zip(buf.glyph_infos, buf.glyph_positions)])
    return runs


def main():
    apple_path, patched_path, out_path = sys.argv[1:4]
    name = out_path.rsplit("/", 1)[-1]

    patched = TTFont(patched_path)
    # Decompile what is indexed by glyph before the order changes. The rest is
    # copied as it is: the name table only fits its 16-bit offsets as fontforge
    # wrote it, with strings shared between records.
    for tag in ("CFF ", "hmtx", "cmap", "post", "maxp"):
        patched[tag]
    top = patched["CFF "].cff.topDictIndex[0]
    keep = set(patched.getGlyphOrder())
    charstrings = {g: top.CharStrings[g].bytecode for g in keep}
    advances = {g: patched["hmtx"][g] for g in keep}
    cmap = patched.getBestCmap()

    apple = TTFont(apple_path)
    apple_order = apple.getGlyphOrder()
    replaced = [g for g in apple_order if g not in keep]
    options = subset.Options()
    options.layout_features = ["*"]
    options.layout_scripts = ["*"]
    options.layout_closure = False
    options.glyph_names = True
    options.notdef_outline = True
    options.recalc_bounds = False
    options.prune_unicode_ranges = False
    options.drop_tables = []
    options.name_IDs = ["*"]
    subsetter = subset.Subsetter(options)
    subsetter.populate(glyphs=[g for g in apple_order if g in keep])
    subsetter.subset(apple)

    order = [g for g in apple_order if g in keep]
    shared = set(order)
    order += [g for g in patched.getGlyphOrder() if g not in shared]
    patched.setGlyphOrder(order)
    top.charset = order

    for tag in ("GSUB", "GPOS"):
        apple[tag].table  # decompiled under Apple's names before it moves
        patched[tag] = apple[tag]
    for tag in ("GDEF", "PfEd"):
        if tag in patched:
            del patched[tag]
    names = patched["name"]
    names.names = [r for r in names.names if r.nameID != 13 and r.nameID < 256]
    names.names += [r for r in TTFont(apple_path)["name"].names
                    if r.nameID == 13 or r.nameID >= 256]
    patched.save(out_path)

    out = TTFont(out_path)
    out_top = out["CFF "].cff.topDictIndex[0]
    problems = []
    for r in out["name"].names:
        if r.nameID in (1, 2, 4, 6, 16, 17) and not r.toUnicode().isascii():
            problems.append(f"name ID {r.nameID} is not plain text")
            break
    if out.getGlyphOrder() != order:
        problems.append("glyph order")
    if any(out_top.CharStrings[g].bytecode != b for g, b in charstrings.items()):
        problems.append("charstrings")
    if any(out["hmtx"][g] != a for g, a in advances.items()):
        problems.append("advances")
    if out.getBestCmap() != cmap:
        problems.append("cmap")
    want, got = shaped(apple_path), shaped(out_path)
    differ = sum(a != b for a, b in zip(want, got))
    if differ:
        problems.append(f"{differ} of {len(want)} shaped runs differ from Apple")
    if problems:
        sys.exit(f"  ✗ {name}: " + ", ".join(problems))
    print(f"  • {name}: {len(replaced)} replaced glyphs pruned, "
          f"{len(want)} shaped runs match Apple")


if __name__ == "__main__":
    main()
