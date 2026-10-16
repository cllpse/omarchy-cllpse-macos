# T3 Code

T3 Code, Omarchy's coding-agent app (Install > AI > T3 Code, package
`t3code-bin`), drew its primary colour, the send and action buttons, in purple
under both cllpse themes, while its focus rings and accents were macOS blue.
`t3code.sh` links [`../themed/t3code.json.tpl`](../themed/t3code.json.tpl)
into `~/.config/omarchy/themed/`, where Omarchy renders it instead of its own,
and the primary is the accent again.

## Why it was purple

Read from the bundle, `/usr/lib/t3code/resources/app.asar`, 0.0.45, on
2026-10-16:

- The primary colour is `--primary: var(--app-theme-message-action)`, the
  theme's `messageAction` token.
- A theme that gives `appearance`, `canvas` and `accent` has its whole palette
  generated from those two colours, and its explicit `colors` are laid on top
  as they are, with nothing derived from them.
- The generator sets `messageAction` to the accent with its OKLCH hue turned by
  50°: `h: (accent hue + 50) % 360`.
- Omarchy's `t3code.json.tpl` sets `accent` and `focus` but not
  `messageAction`. macOS blue `#007AFF` is hue 257°, so the button came out at
  307°, about `#B36BEE` in dark and `#9B51D3` in light.

## What the template adds

Omarchy's template, copied from 4.0.4, with three lines after `focus`:

| Key | Value | Why |
|---|---|---|
| `messageAction` | `{{ accent }}` | the primary is the accent, as on macOS |
| `messageActionForeground` | `#FFFFFF` | text on the button. Explicit, because T3 Code computes the generated one by contrast against its own purple, and copies explicit colours without deriving anything |
| `messageActionHover` | `{{ mix accent background 12% }}` | darker in dark, lighter in light, as T3 Code's own default palettes do it (`#346bf1` → `#3061d9` dark, `#1b4ed8` → `#3160db` light) |

**White is a literal, and a limit.** No `colors.toml` key is white in both
themes, the light theme's foregrounds are all black, and Omarchy's templates
cannot pick by contrast. macOS draws white on the accent in both appearances,
so white is right for both cllpse themes. But a user template replaces
Omarchy's for every theme, so an Omarchy theme with a pale accent gets white
text on it too. Remove the symlink (or re-run revert.sh) if you use those.

## Keeping it in step with Omarchy

Ours shadows Omarchy's whole, so a key Omarchy adds to its template later would
never reach T3 Code. The step checks for that on every run and says so when the
two differ by more than our three lines. The same check by hand:

```bash
diff <(sed '/"messageAction/d' overrides/themed/t3code.json.tpl) \
     /usr/share/omarchy/default/themed/t3code.json.tpl
```

Silence means in step. Otherwise copy Omarchy's again and re-add the three
lines after `focus`.

## How it reaches the app

`omarchy theme set` renders the template into the current theme's
`t3code.json`, and Omarchy's own `omarchy-theme-set-t3code` copies that to
`~/.t3/userdata/themes/omarchy.json`, which T3 Code watches and applies live. So
the step only links: step 8 renders it in a full run, and run alone it needs
`omarchy-theme-refresh`. The step skips when `t3code` is not installed.
revert.sh removes the link, and the next theme set goes back to Omarchy's.
