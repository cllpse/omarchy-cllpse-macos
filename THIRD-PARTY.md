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

## Yaru icon themes

`icons.theme` references `Yaru-dark` / `Yaru-blue`, which are packaged
separately by the distribution and are **not** bundled here.
[Yaru](https://github.com/ubuntu/yaru) is licensed CC-BY-SA 4.0 / GPL-3.0.

## If you own one of these assets

Open an issue and the file will be removed promptly.
