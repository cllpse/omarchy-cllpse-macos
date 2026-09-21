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

Script: [`omarchy.sh`](omarchy.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
