# Superset

Superset (Paradev), the agent workspace app, is an Electron build unpacked in
`~/Applications/superset/`. `superset.sh` makes one edit to its bundle,
`resources/app.asar`, and nothing else.

## What it fixes

In the Changes tree, seven file icons sit on an opaque square in the file's
status colour (orange modified, green new): `readme`, `changelog`, `diff`,
`log`, `lib`, `document` and `settings`. Every `README.md` shows it.

Read from the bundle, 2.0.0, on 2026-10-29:

- The Changes tree draws its icons from an SVG sprite sheet, not `<img>`. The
  sprite builder (`page-*.js`, `fetchSymbolBody`) fetches each Material icon
  from `file-icons/<name>.svg`, cuts the `<svg …>` root tag off and keeps the
  inside as a `<symbol>`.
- Those seven files all start `<svg … fill="none" …><path d="M0 0h24v24H0z"/>`:
  a placeholder with no fill of its own, invisible only because the root says
  `fill="none"`. Cutting the root away lets the path inherit the tree's
  `currentColor`, which is the row's status colour. The Files tab and the
  attachment tiles use `<img>`, keep the root, and are fine.
- `.md` itself is fine: that glyph is the tree library's own, not the sprite's.

## What it does

Replaces the 25-byte stray path with an XML comment of the same 25 bytes
(`<!--cllpse stray path -->`), in all 14 places the asar holds it: 7 icons × the
two copies, `dist/renderer/file-icons/` and `resources/public/file-icons/`.

- **Same length**, so the asar header, which holds every file's offset and
  size, stays true and nothing is repacked. The patch is a copy, taking a
  second at most on Btrfs, edited and renamed over the original.
- **Never in place.** A running Superset reads the asar by offset, and a rewrite
  under it is the font crash in `fonts/` (CLAUDE.md). The rename leaves the old
  inode to whoever has it open. A running Superset shows the fix after a restart.
- **Only icons whose root is `fill="none"`** are matched. Any other file holding
  the same path keeps it.
- **Idempotent.** A run reports `N already patched`; a bundle with no stray path
  (fixed upstream, or the icons moved) reports that and changes nothing.
- **Reversible byte for byte.** `superset.sh --revert`, which `revert.sh` runs,
  swaps the comment back for the path. No backup of the 1 GB bundle is kept.

## Why not something else

- The bundle's asar integrity fuse is off (`npx @electron/fuses read --app
  ~/Applications/superset/superset`), so a changed asar loads.
- No user stylesheet reaches Superset's renderer, so the symbols cannot be
  corrected from outside.
- An app update replaces `app.asar` and the square returns; run
  `apply.sh superset`. Auto-update is off for this build (`APPIMAGE env is not
  defined` in `~/.config/Superset/logs/main.log`).
- The AppImage (`~/Applications/Superset.AppImage`) is a read-only squashfs and
  is not touched.

Probe, from the asar (`npx @electron/asar extract-file`): `readme.svg` should
carry `<!--cllpse stray path -->` where `<path d="M0 0h24v24H0z"/>` was.
