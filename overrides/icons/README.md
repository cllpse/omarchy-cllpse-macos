# App icons

Hand-placed marks for the Omarchy menu, which draws app rows as a plain image and cannot recolour. See AGENTS.md here for the workflow.

The script is [`icons.sh`](icons.sh). It is runnable on its own and is also
called by [`../apply.sh`](../apply.sh), which owns the order. Numbered
sections below match the `# See README.md (n)` pointers in that script.

## 1. mkdir -p ~/.config/omarchy/hooks/theme-set.d

The Omarchy menu draws icons two ways. Non-app rows render `row.icon` as TEXT
in a Nerd Font, tinted `foreground` — that is the flat, theme-tracking look.
App rows instead render a plain Image of whatever the desktop entry's `Icon=`
resolves to (Menu.qml:1253), with no recolouring at all, so every app shows
its vendor's full-colour logo. Measured on this machine: 48 of 52 visible
entries resolve to a colour icon.

There is no setting for this. The only lever short of forking the first-party
menu plugin is to make `Icon=` resolve to a file we control — and
AppLibrary.qml makes that easy, because it consults its OWN index (a find over
every XDG icon dir, svg pass then png, first hit per name) BEFORE Qt's themed
lookup, and `$HOME/.icons` is the first directory in both passes. A file
dropped there outranks every installed theme. It carries no index.theme, so
GTK and Qt never see it: the override reaches the Omarchy shell and nothing
else.

Nothing is generated. icons/fallbacks/ holds hand-placed SVGs (or PNGs), one
per desktop-entry `Icon=` value; see that directory's README for the naming
and silhouette contract. An app with no file there simply keeps its vendor
icon. The sync is a theme-set hook rather than a step here because app icons
are never recoloured by the shell — a synced file has a fixed colour and must
be rewritten per theme. Run once now so the icons exist before step 8; step
8's `omarchy theme set` then re-runs it as a hook.

Neither this run nor that one relies on theme-set restarting the shell, which
it does NOT do — it pushes the palette in over IPC and restarts only the
terminal, hyprctl, btop, opencode and helix. The restart the icons need (Qt
caches them by URL, and the switcher indexes them once at launch) is app-
icons.sh's own, fired from its EXIT trap and only when a file actually
changed.
The hook is installed and run UNCONDITIONALLY, because it has two independent
halves and icons/fallbacks/ only governs one of them. Its colour pass copies
the switcher submodule's icons/ into ~/.icons/cllpse-color/apps/ for the menu,
which has nothing to do with this directory -- gating the whole hook on
icons/fallbacks/ existing would mean deleting that directory silently cost the
menu 75 full-colour marks as well. The hook already keeps the two halves
independent internally; doing otherwise here would put the coupling back at
the call site.

## From the step table

Flat app icons for the menu. The menu renders non-app rows as Nerd Font *text* tinted `foreground` (the flat look) but app rows as a plain `Image` of the vendor's icon with no recolouring — 48 of 52 visible entries here resolve to a full-colour logo. `AppLibrary.qml` checks its own `find`-built index *before* Qt's themed lookup, and `$HOME/.icons` is the first directory in both its svg and png passes, so a file dropped there outranks every installed theme; with no `index.theme` it stays invisible to GTK and Qt. **Nothing is generated** — `icons/fallbacks/` holds hand-placed SVGs, one per desktop-entry `Icon=` value, and an app with no file there simply keeps its vendor icon. Synced by a `theme-set` hook rather than here, because app icons are never recoloured by the shell: a synced file has a fixed colour and must be rewritten per theme, and the shell restart `omarchy theme set` performs is what drops Qt's image cache so the new colour lands. SVG paints are repainted — attribute *and* CSS-block fills, both quote styles, `fill="none"` preserved so outline shapes stay outlines, and a root fill injected when a file carries no paint at all (simple-icons ships bare `<path d>`, which would otherwise render black). PNGs are masked by their alpha. A file that fails to parse is skipped, so a missing icon means a malformed drop-in
