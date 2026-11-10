#!/bin/bash
# Herdr: both themes as a light/dark pair of its own theme files
#
# See README.md in this directory for what this does and why.
# Runnable on its own, and called by ../apply.sh:
#   herdr.sh                 write both themes, point settings.json and the main layout at them
#   herdr.sh --print         write both theme files to stdout, change nothing
#   herdr.sh --revert        remove them, hand the theme back
#   herdr.sh keys            merge keys.json (this directory) into the app's: null unbinds
#   herdr.sh keys --revert   put the unbound keys back as they were
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib.sh"

LIGHT_ID=cllpse-macos-light
DARK_ID=cllpse-macos-dark
APP_HOME="${HERDR_APP_HOME:-$HOME/.config/herdr-app}"
SETTINGS="$APP_HOME/settings.json"
# The theme picker's choice for the main layout. It beats settings.json, so a
# machine where the picker was ever used shows this and not the setting.
PICKER="$APP_HOME/layouts/.state/main.json"
OURS_PAIR="{\"light\":\"$LIGHT_ID\",\"dark\":\"$DARK_ID\"}"

# Rendered from one colors.toml. Every key it reads must be a hex colour, or
# nothing is printed: Herdr lays a theme file over its own derivation, so a
# half-filled one would look almost right. -I: no environment or cwd on the
# import path.
render() { # $1 colors.toml
  python3 -I - "$1" <<'PY'
import json, re, sys, tomllib

def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))

def mix(top, bottom, a):
    """`top` at alpha `a` over `bottom`: how macOS cuts its separators and fills
    from textColor, and how colors.toml's `muted` was made."""
    t, b = rgb(top), rgb(bottom)
    return "#%02x%02x%02x" % tuple(round(t[i] * a + b[i] * (1 - a)) for i in range(3))

path = sys.argv[1]
with open(path, "rb") as f:
    C = tomllib.load(f)
for k, v in C.items():
    if k != "mode" and not k.startswith("hyprland_") and re.fullmatch(r"#[0-9A-Fa-f]{6}", str(v)) is None:
        sys.exit(f"{path}: '{k}' is not a hex colour ({v!r})")
dark = {"dark": True, "light": False}.get(C.get("mode"))
if dark is None:
    sys.exit(f"{path}: mode {C.get('mode')!r} is neither light nor dark")
C = {k: v.lower() if isinstance(v, str) else v for k, v in C.items()}

bg, fg, ink, accent = C["background"], C["foreground"], C["light_foreground"], C["accent"]
sidebar, card = C["dark_background"], C["lighter_background"]
# Light: border == darker_background (#e6e6e6) exactly, which is the check on the rule.
border = mix(ink, bg, 0.10)
red, green = (C["bright_red"], C["bright_green"]) if dark else (C["red"], C["green"])

theme = {
    # Ghostty's slots, as Omarchy's ghostty.conf.tpl fills them (README.md).
    "background": bg,
    "foreground": fg,
    "selection": C["selection"],
    "cursor": C["bright_foreground"],
    "ansi": [
        bg, C["red"], C["green"], C["yellow"], C["blue"], C["magenta"], C["cyan"], fg,
        C["muted"], C["bright_red"], C["bright_green"], C["bright_yellow"],
        C["bright_blue"], C["bright_magenta"], C["bright_cyan"], C["bright_foreground"],
    ],
    # The panels. Herdr would derive these from the slots above; the palette
    # has the real values, so they are named.
    "colors": {
        "foreground": fg,                       # labelColor
        "muted": C["dark_foreground"],          # secondaryLabelColor
        "dim": C["muted"],                      # tertiaryLabelColor
        "surface": bg,
        "canvas": sidebar,
        "chrome": sidebar,
        "popover": card,
        "raised": mix(ink, card, 0.05),
        "hover": mix(ink, bg, 0.05),
        "selected": mix(ink, bg, 0.10),
        "border": border,
        "input": mix(ink, bg, 0.20),
        "accent": accent,
        "accent_foreground": "#ffffff",
        "ring": accent,
        "solid": ink,
        "solid_foreground": bg,
        "selection": C["selection"],
        "working": C["orange"],
        "blocked": red,
        "done": green,
        "idle": C["muted"],
        "unknown": C["muted"],
    },
}
json.dump(theme, sys.stdout, indent=2)
print()
PY
}

# ── keys ─────────────────────────────────────────────────────────────────────
# keys.json beside this script has the shape of Herdr's own: sections of
# chord -> action. A null action unbinds the chord; anything else is set. Only
# the chords named here are touched, so Herdr's other defaults stay. Note that
# Herdr treats ANY edited keys.json as the person's and stops refreshing it on
# upgrade (its AGENTS.md), so a new default chord has to be added by hand after
# this has run once.
KEYS="$APP_HOME/keys.json"
OURS_KEYS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/keys.json"
PRIOR_KEYS="$STATE/previous-herdr-keys"
keys_apply() {
  if [[ ! -s $KEYS ]] || ! jq -e 'type == "object"' "$KEYS" >/dev/null 2>&1; then
    skip "$KEYS missing or not a JSON object — Herdr's keys left alone"
    return 0
  fi
  # What the chords we touch held before: {section: {chord: action|null}}.
  prior=$(jq -c --slurpfile ours "$OURS_KEYS" '
    . as $live | $ours[0] | to_entries | map(.key as $s | {key: $s, value: (.value | to_entries
      | map({key, value: ($live[$s][.key] // null)}) | from_entries)}) | from_entries' "$KEYS")
  record_prior "$PRIOR_KEYS" "$prior" "$(jq -c . "$OURS_KEYS")"
  merged=$(jq -c --slurpfile ours "$OURS_KEYS" '
    reduce ($ours[0] | to_entries[]) as $sec (.;
      .[$sec.key] = ((.[$sec.key] // {}) * $sec.value | with_entries(select(.value != null))))' "$KEYS")
  if [[ "$(jq -c . "$KEYS")" == "$merged" ]]; then
    skip "Herdr's keys already as declared"
    return 0
  fi
  backup "$KEYS"
  tmp=$(mktemp); jq . <<<"$merged" >"$tmp" && cat "$tmp" >"$KEYS"; rm -f "$tmp"
  say "Herdr keys.json: $(jq -r '[to_entries[] | .key as $s | .value | to_entries[] | select(.value == null) | "\($s) \(.key)"] | join(", ")' "$OURS_KEYS") unbound (live)"
}
keys_revert() {
  [[ -s $KEYS && -s $PRIOR_KEYS ]] || { rm -f "$PRIOR_KEYS"; return 0; }
  # Put a chord back only where it is still as we left it: unbound, or ours.
  tmp=$(mktemp)
  jq --slurpfile prior "$PRIOR_KEYS" --slurpfile ours "$OURS_KEYS" '
    reduce ($prior[0] | to_entries[]) as $sec (.;
      reduce ($sec.value | to_entries[]) as $k (.;
        if (.[$sec.key][$k.key] // null) == ($ours[0][$sec.key][$k.key] // null) then
          (if $k.value == null then del(.[$sec.key][$k.key]) else .[$sec.key][$k.key] = $k.value end)
        else . end))' "$KEYS" >"$tmp" && cat "$tmp" >"$KEYS"; rm -f "$tmp"
  rm -f "$PRIOR_KEYS" "$KEYS.pre-cllpse"
  say "Herdr keys.json: the unbound chords put back"
}

mode=apply
case ${1:-} in
  keys)
    [[ -d $APP_HOME ]] || { skip "Herdr has never run ($APP_HOME missing) — skipped its keys"; exit 0; }
    case ${2:-} in
      "") keys_apply ;;
      --revert) keys_revert ;;
      *) echo "usage: herdr.sh keys [--revert]" >&2; exit 2 ;;
    esac
    exit ;;
  --print)
    for t in light dark; do
      echo "# $t"; render "$REPO/omarchy-cllpse-theme-$t/colors.toml"
    done
    exit ;;
  --revert) mode=revert ;;
  "") ;;
  *) echo "usage: herdr.sh [--print|--revert|keys [--revert]]" >&2; exit 2 ;;
esac

if [[ ! -d $APP_HOME ]]; then
  skip "Herdr has never run ($APP_HOME missing) — skipped its themes"
  exit 0
fi
if ! command -v jq >/dev/null 2>&1; then
  skip "jq not installed — Herdr's themes left alone (pacman -S jq)"
  exit 0
fi

# `herdr-app do` reaches the open window and nothing else: with no window it
# fails, and then the files are edited directly, which is safe exactly then
# (the app reads them at start and holds them in memory after).
window_open() { command -v herdr-app >/dev/null 2>&1 && herdr-app status >/dev/null 2>&1; }
pick() { # $1 theme name — sets the half of the pair matching its lightness
  herdr-app do app.theme --name "$1" >/dev/null
}
# The window writes the picker's file only when its own pick changes, and never
# reads it back, so a file that says something else (an edit made while it was
# open) stays stale after a pick the window already had. Picking Herdr's own
# pair first makes the next pick a change.
pick_pair() { # $1 light  $2 dark
  pick "$1"; pick "$2"
  if [[ -s $PICKER ]] && [[ "$(jq -c '.theme // null' "$PICKER")" != "$(jq -c '{light: $l, dark: $d}' --arg l "$1" --arg d "$2" -n)" ]]; then
    pick paper; pick graphite; pick "$1"; pick "$2"
  fi
}

case $mode in
  apply)
    mkdir -p "$APP_HOME/themes"
    for t in light dark; do
      id=$LIGHT_ID; [[ $t == dark ]] && id=$DARK_ID
      tmp=$(mktemp)
      render "$REPO/omarchy-cllpse-theme-$t/colors.toml" >"$tmp"
      if [[ -s $APP_HOME/themes/$id.json ]] && cmp -s "$tmp" "$APP_HOME/themes/$id.json"; then
        rm -f "$tmp"
      else
        # Through the target, not mv: keeps its mode and inode.
        cat "$tmp" >"$APP_HOME/themes/$id.json"; rm -f "$tmp"
        say "Herdr -> themes/$id.json"
      fi
    done

    # settings.json: the fallback for a layout the picker has never touched.
    # The key is merged in; every other key stays.
    backup "$SETTINGS"
    [[ -s $SETTINGS ]] || echo '{}' >"$SETTINGS"
    if ! jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1; then
      skip "$SETTINGS is not a JSON object jq can read — left alone; set \"theme\": $OURS_PAIR by hand"
      exit 0
    fi
    record_prior "$STATE/previous-herdr-theme" "$(jq -c '.theme' "$SETTINGS")" "$(jq -c . <<<"$OURS_PAIR")"
    if [[ "$(jq -c '.theme' "$SETTINGS")" != "$(jq -c . <<<"$OURS_PAIR")" ]]; then
      tmp=$(mktemp)
      jq --argjson pair "$OURS_PAIR" '.theme = $pair' "$SETTINGS" >"$tmp" && cat "$tmp" >"$SETTINGS"; rm -f "$tmp"
      say "Herdr settings.json: theme -> light $LIGHT_ID, dark $DARK_ID"
    fi

    # The picker's state for the main layout, when there is one.
    if [[ -s $PICKER ]] && jq -e 'has("theme")' "$PICKER" >/dev/null 2>&1; then
      record_prior "$STATE/previous-herdr-picker" "$(jq -c '.theme' "$PICKER")" "$(jq -c . <<<"$OURS_PAIR")"
      if [[ "$(jq -c '.theme' "$PICKER")" == "$(jq -c . <<<"$OURS_PAIR")" ]] && ! window_open; then
        skip "Herdr's main layout already shows them"
      elif window_open; then
        # Also what makes an open window re-read a changed theme file.
        pick_pair "$LIGHT_ID" "$DARK_ID"
        say "Herdr: the open window now shows them; light/dark follows 'omarchy theme set'"
      else
        tmp=$(mktemp)
        jq --argjson pair "$OURS_PAIR" '.theme = $pair' "$PICKER" >"$tmp" && cat "$tmp" >"$PICKER"; rm -f "$tmp"
        say "Herdr: main layout's picked theme -> ours (window closed; shows at next start)"
      fi
    elif window_open; then
      pick_pair "$LIGHT_ID" "$DARK_ID"
      say "Herdr: the open window now shows them; light/dark follows 'omarchy theme set'"
    else
      skip "Herdr shows them at next start; light/dark follows 'omarchy theme set'"
    fi ;;

  revert)
    # What the picker and settings.json held before the first apply. Herdr's
    # own defaults stand in where there is no record and a key has to say
    # something (the open window cannot have its pick taken away, only moved).
    prior_setting=$(cat "$STATE/previous-herdr-theme" 2>/dev/null || echo null)
    prior_pick=$(cat "$STATE/previous-herdr-picker" 2>/dev/null || echo null)
    if [[ -s $SETTINGS ]] && [[ "$(jq -c '.theme // null' "$SETTINGS")" == "$(jq -c . <<<"$OURS_PAIR")" ]]; then
      tmp=$(mktemp)
      jq --argjson prior "$prior_setting" 'if $prior == null then del(.theme) else .theme = $prior end' "$SETTINGS" >"$tmp" \
        && cat "$tmp" >"$SETTINGS"; rm -f "$tmp"
      say "Herdr settings.json: theme -> $prior_setting"
    fi
    if [[ -s $PICKER ]] && [[ "$(jq -c '.theme // null' "$PICKER")" == "$(jq -c . <<<"$OURS_PAIR")" ]]; then
      if window_open; then
        light=$(jq -r 'if type == "object" then .light else . end // "paper"' <<<"$prior_pick")
        dark=$(jq -r 'if type == "object" then .dark else . end // "graphite"' <<<"$prior_pick")
        pick_pair "$light" "$dark"
        say "Herdr: the open window's theme -> light $light, dark $dark"
      else
        tmp=$(mktemp)
        jq --argjson prior "$prior_pick" 'if $prior == null then del(.theme) else .theme = $prior end' "$PICKER" >"$tmp" \
          && cat "$tmp" >"$PICKER"; rm -f "$tmp"
        say "Herdr: main layout's picked theme -> $prior_pick"
      fi
    fi
    rm -f "$APP_HOME/themes/$LIGHT_ID.json" "$APP_HOME/themes/$DARK_ID.json"
    # The key went back by itself, so the whole-file backup has nothing left to
    # say; a settings.json that did not exist before goes with it.
    [[ -e $STATE/no-prior$SETTINGS ]] && rm -f "$SETTINGS" "$STATE/no-prior$SETTINGS"
    rm -f "$SETTINGS.pre-cllpse" "$STATE/previous-herdr-theme" "$STATE/previous-herdr-picker"
    say "Herdr: both theme files removed" ;;
esac
