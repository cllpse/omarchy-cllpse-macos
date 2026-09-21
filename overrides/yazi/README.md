# yazi

Two halves: an ANSI theme that needs no regeneration, and a syntect previewer theme that does, because syntect takes hex only.

## 1. yazi

yazi. Its own preset theme is already ANSI-based, so this is not undoing a
hardcoded palette -- it pins the accent to blue so yazi agrees with the other
TUIs, and flattens the chrome onto `reset`. See yazi/theme.toml.

## 2. yazi's previewer

yazi's previewer — syntect reads a .tmTheme, which is hex-only, so the
previewer's syntax colours are baked per theme like hunk's. Unlike the rest of
yazi/theme.toml (ANSI, no regeneration), this one needs the hook. See the
syntect_theme note in yazi/theme.toml for what the trade buys.

Script: [`yazi.sh`](yazi.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
