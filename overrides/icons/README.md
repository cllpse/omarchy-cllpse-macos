# App icons

The Omarchy menu draws non-app rows as Nerd Font *text* tinted `foreground`, but
app rows as a plain `Image` of whatever the desktop entry's `Icon=` resolves to
— no recolouring, so 48 of the 52 entries here came out as full-colour vendor
logos. There is no setting for it. The only lever is to make `Icon=` resolve to
a file we control.

`AppLibrary.qml` consults its own `find`-built index *before* Qt's themed
lookup, and `$HOME/.icons` is first in both its svg and png passes, so a file
dropped there outranks every installed theme. With no `index.theme` it stays
invisible to GTK and Qt: the override reaches the Omarchy shell and nothing
else.

## Two sets, one hook

| source | published to | treatment |
|---|---|---|
| [`icons/`](icons/README.md), here — 24 hand-placed SVGs | `~/.icons/cllpse-flat/apps/` | **repainted** to the theme `foreground` |
| the **plugin's** `omarchy-cllpse-switcher/icons/` — 75 marks | `~/.icons/cllpse-color/apps/` | **verbatim** |

The verbatim half follows the plugin's rule: an icon is the source of truth for
its own appearance, and the only thing ever changed in a file is its `viewBox`.
Those marks live in the plugin repo, not here — see
[`../../omarchy-cllpse-switcher/AGENTS.md`](../../omarchy-cllpse-switcher/AGENTS.md).

Both are published by `app-icons.sh`, a `theme-set` hook rather than an apply
step, because a repainted file carries a fixed colour and must be rewritten per
theme. The shell restart that hook performs is what drops Qt's image cache so
the new colour lands.

Nothing is generated. One file per desktop-entry `Icon=` value; an app with no
file keeps its vendor icon. See [`AGENTS.md`](AGENTS.md) for finding and fitting
new ones, and [`icons/README.md`](icons/README.md) for what a repainted
file must contain.
