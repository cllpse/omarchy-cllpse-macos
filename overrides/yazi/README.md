# yazi

Two halves: an ANSI theme that needs no regeneration, and a syntect previewer theme that does, because syntect takes hex only.

The script is [`yazi.sh`](yazi.sh). It is runnable on its own and is also
called by [`../apply.sh`](../apply.sh), which owns the order. Numbered
sections below match the `# See README.md (n)` pointers in that script.

## 1. if command -v yazi >/dev/null 2>&1; then

yazi. Its own preset theme is already ANSI-based, so this is not undoing a
hardcoded palette -- it pins the accent to blue so yazi agrees with the other
TUIs, and flattens the chrome onto `reset`. See yazi/theme.toml.

## 2. if command -v yazi >/dev/null 2>&1; then

yazi's previewer — syntect reads a .tmTheme, which is hex-only, so the
previewer's syntax colours are baked per theme like hunk's. Unlike the rest of
yazi/theme.toml (ANSI, no regeneration), this one needs the hook. See the
syntect_theme note in yazi/theme.toml for what the trade buys.
