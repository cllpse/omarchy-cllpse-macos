# Omarchy shell.json

Five targeted jq writes into the shell config: the window-switcher plugin, a transparent bar, the recorded bar layout and the disabled first-party plugins.

## 1. Targeted key writes into ~/.config/omarchy/shell.json

Targeted key writes into ~/.config/omarchy/shell.json, Omarchy's own
machine-level shell config. Deliberately still not a whole-file copy or a deep
merge: the file also carries `idle`, `version` and any other plugin's own
widget config, none of which this repo has an opinion about, and `plugins[]`
is an array a deep merge would replace rather than append to.

  plugins[]         step 1 symlinks the switcher into ~/.config/omarchy/
                    plugins/, but that only INSTALLS it — Omarchy enables a
                    plugin from this array, keyed by the manifest id (the
                    folder name is cosmetic). Without the entry the plugin
                    sits there and the HUD never loads, with nothing to say so.
  bar.transparent   Omarchy ships false. This hands the bar's background to
                    the theme's [bar] background-alpha instead of the shell
                    painting its own — which currently changes nothing on
                    screen, since shell.bar.toml ships alpha 1.0, but is what
                    any future translucent bar needs in place first.
  bar.layout        the widget set and its order, from omarchy/shell-bar.json.
  bar.centerAnchor  which center widget is pinned to the true screen centre.
  disabledPlugins   first-party non-widget plugins to turn off.

The last three used to be left alone as personal. They are owned now because
they are the same kind of decision as everything else here — which chrome the
desktop shows — and because two of them are already half-made elsewhere in
this repo: the keybind sweep unbinds SUPER+CTRL+V, SUPER+CTRL+E and the three
reminder binds, so clipboard / emojis / reminders were already unreachable
while still loading. Note the consequence: a bar rearranged in a settings GUI
after an apply is reset by the next one. Edit shell-bar.json, don't re-drag.

disabledPlugins[] only reaches FIRST-PARTY NON-WIDGET plugins — panels and
services (PluginRegistry.qml:148-165). A bar widget has no off state there;
it is disabled by not being in bar.layout, which is how the OmaSettings widget
is switched off. A third-party plugin is enabled iff its id appears anywhere
in shell.json, so dropping it from the layout is the whole uninstall.

One third-party widget is in the layout on purpose: io.github.thisisgm.omapods,
an AirPods battery readout that hides itself when nothing is connected. apply.sh
installs no plugin, so on any other machine that entry is inert rather than
broken -- Bar.qml:1788-1791 resolves an unknown widget id to a null component
and the slot loads nothing, the same way bar.centerAnchor is inert below. That
silence is what section 6 exists to break.

Two things the layout is NOT allowed to clobber. The tray's `pinned` /
`hidden` arrays are genuinely per-machine — they name tray items that exist on
this box — so whatever the live file has is carried over onto our tray entry
rather than replaced; shell-bar.json keeps the entry bare on purpose. And
bar.centerAnchor names omarchy.clock, which is not in the layout: with the
anchor absent Bar.qml's `hasAnchor` is false and the whole center section just
centres as a block (Bar.qml:1538), so the key is inert — kept at Omarchy's
stock value so that re-adding a clock restores the anchoring for free.

The pre-existing values are recorded once for revert.sh, on the same terms as
the font and theme above: a value that already matches what we would write is
refused, so a re-run can't turn revert into a no-op.

Picked up live, with no restart needed and none available: shell.qml:134-142
holds a FileView on ~/.config/omarchy/shell.json with watchChanges: true and
onFileChanged: reload(), so a targeted key write lands as soon as it is saved.
(A hyprctl reload would do nothing here either way — this file is the shell's,
not Hyprland's. And step 8's theme-set does not restart the shell, which an
earlier version of this comment assumed it did.)

## 2. The id this plugin's manifest used to declare

The id this plugin's manifest used to declare. Omarchy enables a third-party
plugin iff its id appears anywhere in shell.json, so an entry left over from
an earlier apply keeps a plugin "enabled" that no longer exists under that
name. Dropped alongside the legacy symlink removed in step 1.

## 3. Everything the block above would change

Everything the block above would change, as one compact blob, so revert
has a single thing to put back. Compared against what we are about to
write rather than against shell-bar.json, so the tray carry-over doesn't
read as a difference and get recorded on an already-applied machine.

## 4. NOT `.bar.transparent // empty`

NOT `.bar.transparent // empty`. jq's `//` treats FALSE as absent, so that
form emits nothing for the one value that actually needs recording --
Omarchy ships transparent = false, so on a stock machine record_prior got
an empty string, refused it, and revert.sh was left with nothing to put
back and no way to tell the bar was ever opaque. Test against null
explicitly and stringify, so false records as "false".

## 5. The bar layout is restored at session start, not defended

Omarchy's bar lets you **drag a widget to reorder it**, and drag the bar itself
to another screen edge. There is no setting to turn that off. Checked rather
than assumed, three ways: `applyBarConfig` (`plugins/bar/Bar.qml`) reads exactly
`position` / `transparent` / `centerAnchor` / `layout`, `builtinShellConfig`
(`shell.qml`) defines no more, and Omarchy's own stock `shell.json` carries the
same four keys. The reorder gate is a **capability test, not a config key**:

```qml
readonly property bool canReorder:
  root.shell && typeof root.shell.mutateShellConfig === "function"
```

and `mutateShellConfig` is unconditional on the shell root. The only ways to
genuinely prevent the drag are to patch a **pacman-owned** file
(`omarchy 4.0.4-1` owns `Bar.qml`, so every package upgrade silently reverts it)
or to fork the 2,307-line bar plugin and select it through `bar.id`. Both were
considered and declined.

So the drag is not prevented, it is made **free**. The layout is already
declarative in [`shell-bar.json`](shell-bar.json), and
[`../hooks/post-boot.d/cllpse-bar-layout.sh`](../hooks/post-boot.d/cllpse-bar-layout.sh)
puts it back once per session — fired by `omarchy-hook post-boot`, which
Omarchy dispatches from `default/hypr/autostart.lua:13`
(`sleep 2 && omarchy-hook post-boot`). No timer, no daemon, no watcher of ours.
`shell.json` is watched live (`shell.qml` holds a `FileView` on it with
`watchChanges: true`), so the bar re-reads it with no restart.

The hook calls `omarchy.sh --bar-only`, and that flag is the load-bearing part:
it writes `bar.layout` and `bar.centerAnchor` and **nothing else**. A hook that
fires every session must not re-assert `plugins[]`, `bar.transparent` or
`disabledPlugins`, or it would silently undo a plugin the user enabled from
Omarchy's own menu — verified by re-enabling `omarchy.emojis` by hand and
confirming the hook left it enabled, while a full `omarchy.sh` run put it back.
It records no prior state either: establishing what `revert.sh` restores is the
first apply's job, and a hook that runs before `apply.sh` ever has would record
*our* layout as the pre-existing one.

The cost, stated plainly: there is no bar-change event to hang this on, so an
accidental drag stands until the next login or until you run

```bash
bash overrides/omarchy/omarchy.sh --bar-only
```

This reverses a decision recorded in
[`../hooks/post-update.d/cllpse-macos-repair.sh`](../hooks/post-update.d/cllpse-macos-repair.sh),
which used to list bar widget order among the machine-level things no hook
should rewrite. That reasoning still holds for the *update* hook and for the
other three keys; the comment there now says which half moved and why.

## From the step table

Omarchy shell config, five targeted `jq` key writes — never a whole-file copy
or deep merge, since the file also holds `idle`, `version` and other plugins'
widget config, and `plugins[]` is an array a merge would replace rather than
append to. **`plugins[]`**: enable the window-switcher (entry keyed by the
manifest id — step 1's symlink only *installs* it; without this entry the HUD
never loads and nothing says so). **`bar.transparent`**: true (Omarchy ships
false). **`bar.layout`** + **`bar.centerAnchor`** + **`disabledPlugins`**:
from `omarchy/shell-bar.json`, the recorded bar. `disabledPlugins[]` reaches
only first-party *non-widget* plugins — panels and services
(`PluginRegistry.qml:148-165`); a widget is disabled by absence from the
layout, which is also the whole uninstall for a third-party one. The tray's
`pinned`/`hidden` arrays are carried over from the live file rather than
replaced — they name items that exist on this box. `centerAnchor` stays at
Omarchy's `omarchy.clock` although no clock is in the layout: with the anchor
absent `Bar.qml`'s `hasAnchor` is false and the center section just centres as
a block (`Bar.qml:1538`), so the key is inert until a clock comes back. The
pre-existing values are recorded once for `revert.sh`, refusing values already
ours

## 6. A declared third-party widget that isn't installed

The layout is allowed to name a plugin this repo does not ship, and today it
names one: `io.github.thisisgm.omapods`. Nothing goes wrong when it is absent
-- which is the problem. `Bar.qml`'s slot resolves an unknown widget id to a
null component (`Bar.qml:1788-1791`) and the `Loader` loads nothing, so a
missing plugin is indistinguishable from a bar that was always one widget
shorter, with no error in the shell log and no clue in `shell.json`.

So the write is followed by a presence check that only *reports*. It installs
nothing and holds no source URL, on the same terms as `keyd` -- the two
commands live in `../README.md`, under *Before running `apply.sh`*, and the
skip points there rather than restating them where they would drift.

The test is mechanical rather than a hardcoded id, so a widget added to
`shell-bar.json` later is covered without touching this script: a first-party
plugin id is `omarchy.`-prefixed, so anything else in the declared layout is
third-party, and is looked for at `~/.config/omarchy/plugins/<id>`. The folder
name is cosmetic to Omarchy's *enable* path (which keys on the manifest id),
but `omarchy plugin add` names the directory after the id, so it is a fair test.

What is deliberately NOT checked is the daemon behind the widget. omapods is a
front end to `librepods`, and without it the icon appears and reads nothing --
a visible symptom that points at itself, unlike an absent widget. Checking it
would mean a per-plugin table of backends in a script whose whole premise is
that it knows nothing about any particular plugin.

Skipped under `--bar-only`: the boot hook has no terminal to print to.

Script: [`omarchy.sh`](omarchy.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
