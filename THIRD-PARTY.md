# Third-party assets

This repository bundles binary assets it does not own. They are included for
convenience so `overrides/apply.sh` is a single step, and they are **not**
covered by the repository's MIT license (see [`LICENSE`](LICENSE)).

If you are packaging, forking, or mirroring this repo, this is the part to look
at first.

## SF fonts — `overrides/fonts/` (20 `.otf`, ~100 MB)

SF Mono, SF Pro Text and SF Pro Display, patched with
[Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) glyphs.

The San Francisco typefaces are Apple's. Apple distributes them under a license
that permits use — designing and developing interfaces for Apple platforms, and
producing mockups — but does **not** grant redistribution rights, and the files
here are additionally patched derivatives.

Obtain them from Apple directly: <https://developer.apple.com/fonts/>

## Comic Code - `overrides/fonts/comic-code/` (2 `.otf`, ~4.4 MB)

`ComicCodeNerdFont-SemiBold.otf` and `-Bold.otf`, the editor font
`overrides/cursor/settings.json` names. Nerd Fonts-patched derivatives of Comic
Code.

Comic Code is a **commercial** typeface by Toshi Omagari, sold through
<https://tosche.net/fonts/comic-code>. Its license does not grant
redistribution, and these files are additionally patched derivatives. They are
here because this repo is the install mechanism, not because the license allows
it - buy your own copy.

`apply.sh` installs them to `~/.local/share/fonts/ComicCode/`; `revert.sh`
removes that directory. Deleting the two files is enough to opt out - the font
stack in `cursor/settings.json` ends in `monospace`, so Cursor falls back to SF
Mono on its own.

## Wallpapers — `omarchy-cllpse-theme/*/backgrounds/` (~128 MB)

Stock macOS wallpapers (Big Sur, Monterey, Sonoma, Sequoia and others), plus
community-made macOS-styled images. The Apple-authored images are Apple's
copyright and are not licensed for redistribution.

Five were originally shipped as `.heic`, which Omarchy cannot enumerate or
display (`omarchy-theme-bg-next` and `omarchy-menu-images` both filter to
`jpg/jpeg/png/gif/bmp/webp`). They have been converted to JPEG at quality 92,
full resolution, RMSE ≤ 0.012 against a lossless reference.

## yazi icon table — `overrides/yazi/theme.toml` (the generated block)

The `[icon]` block at the end of that file is yazi's own icon table — ~725
rules pairing a filename/extension with a Nerd Font glyph — reproduced verbatim
apart from the `fg` values, which are rewritten onto ANSI colour names so the
icons follow the active Omarchy theme. Names, glyphs, ordering and yazi's own
comments are unchanged.

[yazi](https://github.com/sxyazi/yazi) is MIT-licensed, which permits this;
the block is a derivative of its preset themes and is covered by yazi's
license, not this repository's. It is extracted from the installed binary by
`overrides/yazi/generate-icons.py` rather than vendored from upstream, so
re-running that after a yazi upgrade picks up new icons.

The glyphs themselves are [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts)
codepoints (MIT); only the codepoints are stored here, not any font data.

## App icon drop-ins — `overrides/icons/color/` and `overrides/icons/fallbacks/`

Hand-placed SVGs, one per desktop entry's `Icon=` (and, for the switcher, per
window class). Two kinds, and only one of them is a concern:

*Vendor marks*, which are the trademarks of the products they identify and are
**not** this repository's to license — `figma-desktop.svg` (Figma, Inc.),
`co.anysphere.cursor.svg` (Anysphere), `com.mitchellh.ghostty.svg` (Ghostty),
`org.omarchy.agent.svg` (Omarchy), `youtube.svg` and `youtube-music.svg`
(Google). They are reproductions of each product's own mark, sourced by hand
rather than generated, and are here so the Omarchy menu shows a flat icon
instead of a full-colour vendor logo — see
[`overrides/icons/fallbacks/README.md`](overrides/icons/fallbacks/README.md) for
the shape contract. Using a mark to identify the product it belongs to is
ordinary nominative use, but redistribution is not a right any of these grant,
and none of them are covered by this repository's MIT license.

*Generic freedesktop icons* — `applications-system`, `printer`, `cups`,
`network-wired`, `disk-usage`, `org.gnome.DiskUtility`, `fcitx`, `btop` — name
things rather than brands and carry their upstream projects' own licenses.

`overrides/hooks/theme-set.d/app-icons.sh` recolours the `fallbacks/` set to the
active palette on every theme-set; `color/` is copied verbatim. Neither is
generated from anything, so deleting a file simply hands that app back to its
own icon — which is also the cheapest way to stop redistributing one.

## Yaru icon themes

`icons.theme` references `Yaru-dark` / `Yaru-blue`, which are packaged
separately by the distribution and are **not** bundled here.
[Yaru](https://github.com/ubuntu/yaru) is licensed CC-BY-SA 4.0 / GPL-3.0.

## If you own one of these assets

Open an issue and the file will be removed promptly.
