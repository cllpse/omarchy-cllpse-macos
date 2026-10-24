# Fonts

The SF faces the desktop is set in, plus Comic Code for the editor, copied into `~/.local/share/fonts/`. [`../fontconfig/`](../fontconfig/README.md) is what makes anything resolve to them.

## SF Pro, built from Apple's DMG

The 16 `SFPro{Text,Display}NerdFontPropo-*.otf` are Apple's SF Pro 22.0d5e4
patched with Nerd Fonts 3.5.1 by [`build/build-sf-pro.sh`](build/build-sf-pro.sh),
from `SF-Pro.dmg` (developer.apple.com/fonts, downloaded 2026-10-20). Text in
Regular, Medium, SemiBold and Bold, Display in Light, Regular, SemiBold and Bold,
each with its italic. Since 2026-10-24. Before that the eight uprights were an
older SF Pro patched elsewhere (136 of 22.0's glyph names missing, no `rlig`),
with no italics, and fontconfig slanted the uprights when an app asked for one.
Apple's package has always had them, in every weight.

**Kerning.** The uprights shipped until then had none: HarfBuzz gave 0 for
every pair, where Apple's face kerns AV by −130, To by −200 and LT by −190 (of
2048 units). The patcher runs on fontforge, which renumbers every glyph in
Unicode order and recompiles GSUB and GPOS. In SF Pro's uprights the kerning
lookup then overflows its 16-bit offsets and is written truncated (fontforge:
"Will not be useable"). The italics, at 34,839 glyphs against 35,683, came
through. [`build/restore_layout.py`](build/restore_layout.py) puts Apple's glyph
order and Apple's own GSUB and GPOS back. Its tables alone were not enough:
under fontforge's order fontTools overflows the same lookup, splits it and
loses pairs ("78" lost its −30). Then it checks its output against the
patcher's, every charstring, advance and cmap entry, and against Apple's face,
a corpus shaped with HarfBuzz under 12 feature settings, glyph for glyph and
position for position.

**Names.** Apple's license, name ID 13, is 60 KB of UTF-16. fontforge writes it
again for the Mac platform, which takes the name table past what its 16-bit
offsets reach, and every record stored after the overflow points at the wrong
bytes: in the first build the Medium, SemiBold and Light faces had glyph names
for a family name. So the patcher gets each face without that record
([`build/drop_license.py`](build/drop_license.py)), and the repair puts Apple's
back once, for the Windows platform as Apple ships it. With it come Apple's
records 256 and up, the stylistic set names Apple's GSUB points at, which
fontforge renumbers.

What else the patcher changes, measured on Text Regular: 6 of Apple's glyphs
give way to Nerd ones at the same code points (the IEC power symbols
U+23FB–23FE and U+2B58, and U+2665), as in every Nerd font. No advance width
changes, and 2 Latin outlines are re-encoded with identical areas. Apple's
`trak` (tracking by point size), `MERG` and `meta` tables are dropped, as they
were in the earlier set.

| Stage | Tool | Why |
|---|---|---|
| Unpack | [`build/udif.py`](build/udif.py), [`build/carve_xar.py`](build/carve_xar.py), `bsdtar` | The DMG is UDIF (187 MB of raw chunks, 31 MB of LZFSE) around an APFS volume that nothing here reads without root. The installer package on it is one piece, so it is cut out of the raw image by its xar header. |
| Patch | [`build/drop_license.py`](build/drop_license.py), then `nerdfonts/patcher:4.27.2` in Docker, `--complete --variable-width-glyphs` | The image is tagged by font-patcher's version, and 4.27.2 is the one in Nerd Fonts 3.5.1. The two options give the `Nerd Font Propo` names, and with them the family the fontconfig drop-ins name. |
| Repair | [`build/restore_layout.py`](build/restore_layout.py), fontTools 4.67.0 and uharfbuzz 0.57.0 through `uv` | Above. |

The build needs no root and takes about four minutes. It writes over the 16
files here; `git diff --stat` shows what moved. SF Mono's 12 faces, with their
italics, are not part of it: patched with Nerd Fonts 3.5.1 elsewhere.

## Comic Code

Comic Code, the editor font cursor/settings.json names. Kept in its own
subdirectory rather than beside the SF faces, because the SF copy globs
fonts/*.otf into ~/.local/share/fonts/SF/ and these are not SF -- the subdir
keeps them out of that glob and out of that directory.

Script: [`fonts.sh`](fonts.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
