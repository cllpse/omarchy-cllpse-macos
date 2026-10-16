# T3 Code

T3 Code, Omarchy's coding-agent app (Install > AI > T3 Code, package
`t3code-bin`), has 57 colour slots. Omarchy's theme sets 25 of them, and T3 Code
generated the other 32 from the theme's background and accent, which put a
blue-violet cast over the whole app under both cllpse themes. `t3code.sh` links
[`../themed/t3code.json.tpl`](../themed/t3code.json.tpl) into
`~/.config/omarchy/themed/`, where Omarchy renders it instead of its own, and
that template sets all 57, so nothing is left to generate.

## Why the app had a purple cast

Read from the bundle, `/usr/lib/t3code/resources/app.asar`, 0.0.45, on
2026-10-16:

- A theme that gives `appearance`, `canvas` and `accent` has its whole palette
  generated from those two colours, and its explicit `colors` are then laid on
  top as they are, with nothing derived from them.
- Omarchy's `t3code.json.tpl` (4.0.4) sets 25 tokens: the window frame,
  sidebar, text, borders, code blocks and terminal, all from the theme. The 32
  it leaves out were generated.
- The generator keeps the canvas's lightness and takes the accent's hue for
  every surface, at a chroma scaled from the accent's. macOS blue `#007AFF`
  (OKLCH hue 257°, chroma 0.218) is a strong accent, so in dark the panels,
  hover rows, inputs and message bubbles came out navy to indigo: message
  bubbles `#0D448A` where an untinted grey at that lightness is `#464646`,
  inputs `#365580` against `#545454`. Muted text took the same hue.
- The primary colour, `--primary: var(--app-theme-message-action)`, is the
  accent with its hue turned by 50°: 307°, about `#B36BEE` in dark and
  `#9B51D3` in light. The send and action buttons were violet.

A neutral grey frame around a navy interior with violet buttons reads as a
purple cast. The first fix, on 2026-10-16, set only the three `messageAction`
tokens. That fixed the buttons and left the rest, so it was replaced with this.

T3 Code's own theme, the one a fresh install uses, is "T3 Code" (id `default`),
neutral with a blue accent. "T3 Chat" (`t3-chat`) is a separate built-in that is
purple throughout, OKLCH hues 307° to 332° with a pink accent. It is also the
base the generator starts from, which made it look like the default while this
was being traced.

## What the template adds

Every line of Omarchy's template, unchanged, plus the 32 tokens it leaves out,
each next to the group it belongs to:

| Tokens | Value | Dark / light |
|---|---|---|
| `surface`, `surfaceRaised`, `surfaceOverlay` | `background` mixed 3, 5 and 7% toward `foreground` | `#242424` / `#f9f9f9` for `surface` |
| `toolbarControl`, `toolbarControlHover` | 6% and 10% | |
| `secondary`, `accentSurface`, `messageSurface` | 8%: buttons, hover rows, message bubbles | `#2d2d2d` / `#eeeeee` |
| `muted` | 5% | |
| `sidebarControlSurface` | `dark_background` 6% toward `foreground`, as Omarchy's own `sidebarRowHover` | |
| `*Foreground` on those surfaces | `foreground` | |
| `textMuted`, `mutedForeground`, `placeholder`, `secondaryLabel`, `iconMuted`, `sidebarMutedForeground` | `dark_foreground` | `#9A9A9A` / `#808080` |
| `input` | `muted`, like `border`: in this UI kit it is the input's border | |
| `messageAction`, `update` | `accent` | `#007AFF` |
| `messageActionHover` | `accent` 12% toward `background`: darker in dark, lighter in light, as T3 Code's own palettes do it | |
| `accentForeground`, `messageActionForeground` | `#FFFFFF` | |
| `updateForeground`, `updateSurface` | `accent` 25% toward `foreground`; `background` 15% toward `accent` | |
| `errorForeground`, `warningForeground` | Omarchy's own `error` and `warning` mixes | |
| `errorSurface`, `warningSurface` | `background` 15% toward `red` / `yellow` | `#402223` / `#ffe1e2` |

The accent is left only where it means something: buttons, focus, the update
banner and Omarchy's own `sidebarRowActive`. Rendered against all 24 themes on
this machine (both cllpse themes and Omarchy's 22) on 2026-10-16: valid JSON,
all 57 tokens, nothing unresolved. That last part matters because
`omarchy-theme-set-t3code` skips a file with a `{{` left in it and keeps the
old palette. So use only keys `omarchy-theme-color --all` derives for every
theme.

**White is a literal, and a limit.** No `colors.toml` key is white in both
themes (the light theme's foregrounds are all black), and Omarchy's templates
cannot pick by contrast. macOS draws white on the accent in both appearances,
so white is right for both cllpse themes. But a user template replaces
Omarchy's for every theme, so an Omarchy theme with a pale accent gets white
text on its buttons too. Remove the symlink, or run revert.sh, if you use those.

## Keeping it in step with Omarchy

Ours shadows Omarchy's whole, so a line Omarchy adds or changes later would
never reach T3 Code. The step checks on every run that every line of Omarchy's
template is still in ours, and says so when one is not. The same check by hand:

```bash
grep -v '^$' /usr/share/omarchy/default/themed/t3code.json.tpl |
  grep -vxF -f <(grep -v '^$' overrides/themed/t3code.json.tpl)
```

Silence means in step; anything printed is a line to merge in. Keep Omarchy's
last line last, since it carries no trailing comma.

## How it reaches the app

`omarchy theme set` renders the template into the current theme's
`t3code.json`, and Omarchy's own `omarchy-theme-set-t3code` copies that to
`~/.t3/userdata/themes/omarchy.json`, which T3 Code watches and applies live
while the Omarchy theme is selected (`t3 theme set omarchy`, which Omarchy's
installer runs once). So the step only links: step 8 renders it in a full run,
and run alone it needs `omarchy-theme-refresh`. The step skips when `t3code` is
not installed. revert.sh removes the link, and the next theme set goes back to
Omarchy's.
