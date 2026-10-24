# Fonts

The SF faces the desktop is set in, plus Comic Code for the editor, copied into `~/.local/share/fonts/`. [`../fontconfig/`](../fontconfig/README.md) is what makes anything resolve to them.

## SF Pro and SF Mono, built from Apple's DMGs

All 28 SF faces are built here, from Apple's own DMGs (developer.apple.com/fonts,
downloaded 2026-10-20), by one script:

```bash
overrides/fonts/build/build-sf.sh ~/Downloads/SF-Pro.dmg    # the 16 SF Pro faces
overrides/fonts/build/build-sf.sh ~/Downloads/SF-Mono.dmg   # the 12 SF Mono faces
```

It writes over the files here and checks each against Apple's face (Repair,
below); `git diff --stat` shows what moved. Commit the result, then `apply.sh
fonts` installs it.

### SF Pro

The 16 `SFPro{Text,Display}NerdFontPropo-*.otf` are Apple's SF Pro 22.0d5e4
patched with Nerd Fonts 3.5.1 (Nerd Font Propo), from `SF-Pro.dmg`. Text in
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

### SF Mono

The 12 `SFMonoNerdFontMono-*.otf` are Apple's SF Mono 18.0d1e1 from
`SF-Mono.dmg`, patched with Nerd Fonts 3.5.1 as Nerd Font Mono (`--mono`: every
icon one cell wide, as terminals and the bar expect): Light, Regular, Medium,
SemiBold, Bold and Heavy, each with its italic. Since 2026-10-24. The set
shipped before came from the same Apple release and the same Nerd Fonts, so
nothing on screen changes: every Apple glyph's outline is the same, and both
sets shape exactly as Apple's face does. What moved is structural. SF Mono has
no kerning and Apple ships no GPOS, and fontforge's empty GPOS, its GDEF and its
`PfEd` are gone. Apple's glyph order and license record are back. The family,
style and weight names and the 12,194 mapped characters (12,140 in the
italics) are unchanged, every glyph one 1266-unit cell. No glyph of Apple's
gives way to a Nerd one.

### The stages

| Stage | Tool | Why |
|---|---|---|
| Unpack | [`build/udif.py`](build/udif.py), [`build/carve_xar.py`](build/carve_xar.py), `bsdtar` | A DMG is UDIF: compressed chunks (LZFSE for SF Pro, zlib for SF Mono) around an APFS or HFS+ volume that nothing here reads without root. The installer package on it is one piece, so it is cut out of the raw image by its xar header. |
| Patch | [`build/drop_license.py`](build/drop_license.py), then `nerdfonts/patcher:4.27.2` in Docker, `--complete` plus `--variable-width-glyphs` (SF Pro) or `--mono` (SF Mono) | The image is tagged by font-patcher's version, and 4.27.2 is the one in Nerd Fonts 3.5.1. The options give the `Nerd Font Propo` and `Nerd Font Mono` names, and with them the families the fontconfig drop-ins name. |
| Repair | [`build/restore_layout.py`](build/restore_layout.py), fontTools 4.67.0 and uharfbuzz 0.57.0 through `uv` | Above: Apple's glyph order, GSUB and GPOS (none for SF Mono), name records and license back, then checked against the patcher's output and against Apple's face. |

The build needs docker and uv, no root, and takes about four minutes for SF Pro
and one for SF Mono.

### Installing over running apps

`fonts.sh` copies with `--remove-destination`, so a changed face replaces the
installed file rather than rewriting it. Running apps have the old file
memory-mapped, and rewriting it under them crashes them: on 2026-10-24 the
rebuilt SF Pro landed through a plain `cp -u` and Ghostty died that second,
inside FreeType's autohinter reading the font through HarfBuzz. An unlinked file
lives on for the apps that have it open, so they carry on with the old face
until they restart, and the next start gets the new one.

## Comic Code

Comic Code, the editor font cursor/settings.json names. Kept in its own
subdirectory rather than beside the SF faces, because the SF copy globs
fonts/*.otf into ~/.local/share/fonts/SF/ and these are not SF -- the subdir
keeps them out of that glob and out of that directory.

Script: [`fonts.sh`](fonts.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
