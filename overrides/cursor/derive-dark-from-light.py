#!/usr/bin/env python3
"""Derive a dark Cursor colour scheme from the light one this repo already uses.

The light side of Cursor is Bearded Theme Light with our chrome painted over it
(hooks/theme-set.d/cursor-chrome.sh). The dark side was a DIFFERENT Bearded
variant, Black & Gold Soft, so the two modes were siblings rather than the same
scheme: same hues for keywords and functions, but a warm grey for strings and
comments where light has a cool one, and a gold editor accent where light has
teal.

This generates the dark counterpart of the LIGHT theme instead, so the two modes
are one scheme in two polarities.

Three rules, because one does not fit every kind of colour:

  FOREGROUNDS (syntax, text, icons) preserve CONTRAST, not lightness. Composite
  the colour over the background it is actually drawn on -- our light mode is
  #FFFFFF, since the chrome hook overrides editor.background -- measure its WCAG
  ratio against that, then keep its hue and its CHROMA and solve for the
  lightness giving the SAME ratio against #1E1E1E.

  Chroma, not HSL saturation, and the difference is not academic. A near-black
  like the editor text #091316 has an HSL saturation of 0.42 while being visually
  neutral, because saturation is measured relative to how much room the lightness
  leaves. Carrying that 0.42 up to a light value paints the editor text pale
  cyan; carrying the absolute chroma (max-min = 0.05) up instead keeps it the
  near-grey it looks like. In HSL terms chroma is S * (1 - |2L - 1|), so the
  solve recomputes S at every candidate lightness to hold it steady. So a comment at 2.1:1 against
  white, deliberately faint, comes out 2.1:1 against #1E1E1E, still deliberately
  faint, in the same hue.

  The search is constrained to be LIGHTER than the background, which is not a
  detail: contrast rises in BOTH directions from a background, so an unconstrained
  solve happily answers a low target with a colour darker than the page. The
  first run of this script turned the keyword gold #bb9600 into #796100 -- a
  correct 2.81:1, and invisible. On a dark theme, text goes above the background.

  BACKGROUNDS (surfaces, washes) preserve the DELTA instead. A widget sitting
  0.02 of lightness below a white window should sit 0.02 ABOVE a #1E1E1E one, so
  the mirror is around the two window colours rather than around 0.5. Preserving
  contrast here would be meaningless -- these are not read, they are sat on.

  TRANSPARENT VALUES ARE NEVER TOUCHED. A theme turns a feature OFF by painting
  it #00000000 -- contrastBorder, the diff text borders, editorError.border and
  15 others in this one -- and deriving those produces a visible grey line where
  the light theme deliberately has none. The first run of this did exactly that
  to all 18 of them, which is where the outlines around every tab came from.

  ALPHA SURFACES mirror the delta of what they COMPOSITE TO, then the base
  colour is back-solved at the same alpha. Leaving them verbatim was the first
  version of this rule and it is wrong: a wash is only polarity-free when its
  base is mid-lightness and chromatic, like the teal selection. The scrollbar
  slider is #09131626 -- a near-black at 15% -- which is a grey slider on white
  (1.38:1) and nothing at all on #1E1E1E (1.02:1). Composite on light, mirror
  that composite around the two window colours, rebuild it at the same hue and
  chroma, and solve base = (target - (1 - a) * bg) / a. Where the alpha is too
  low for the target to be reachable the base clamps to white and the shortfall
  is accepted -- still far more visible than the verbatim value.

  ALPHA VALUES on text are left as they are ONLY WHERE THAT STILL READS. A wash like #22a5c94d composites against whatever is behind it, so it
  already adapts: 30% teal over white is a pale selection, the same 30% teal over
  #1E1E1E is a dark one. Rewriting them would break a polarity-independence they
  already have -- and for the token colours it does something better than that.
  Bearded writes comments as #68919cb3, faint by alpha rather than by hue, so
  keeping the alpha keeps them faint against the dark background too, where
  running them through the foreground rule would flatten them onto the lightness
  floor alongside the keywords and lose the hierarchy entirely. But the rule only
  holds while the composite is still legible: #091316cc is a near-black at 80%,
  which is a soft grey on white and invisible on #1E1E1E, so a TEXT colour whose composite falls
  below 2:1 on the dark background is derived as an opaque colour instead. Only
  text: a faint wash on a surface or a border is decoration, and forcing it to
  meet a reading threshold turns a 10% scroll shadow into a solid grey bar --
  which is the other half of what the first run got wrong.

  ACCENTS AND CHIP TEXT are left alone as well, because they are not drawn on
  the window at all. A saturated surface (HSL saturation >= 0.25) is an accent --
  a badge, a button, a progress bar -- and an accent needs no adaptation: #22a5c9
  reads on white and on #1E1E1E alike. Mirroring its lightness instead turns a
  teal chip into a pale one, which is how the first run produced a light badge
  with grey text on it. By the same token a foreground that is already near-white
  (L >= 0.85) is text sitting ON one of those chips, not on the page, so it stays
  near-white; only the near-black foregrounds -- the ones actually on the window
  -- flip.

Inverting lightness (L' = 1 - L) does none of this: identical lightness steps
carry different contrast on the two backgrounds, which is why naive inversion
looks washed out at the top end and muddy at the bottom.

Text also has a CEILING, not just a floor: #DDDDDD, which is this repo's own
dark `foreground` (macOS labelColor composited). Preserving contrast alone sends
the near-black editor text of a light theme to pure white -- 21:1 is not
reachable on #1E1E1E, so the solve saturates -- and pure white is harsher than
anything else on this desktop. Capping there makes the editor agree with the
palette instead of overshooting it.

Contrast ratio is not perceptually symmetric, so preservation alone is not
enough at the bottom end: a colour that is low-contrast on white (the keyword
gold #bb9600 is 2.81:1) solves to something equally low-contrast on black, and
dark-on-dark reads worse than dark-on-light at the same number. Foregrounds
therefore also carry a LIGHTNESS FLOOR of 0.42. That figure is not invented --
Bearded's own dark variants put the same hues at L 0.41 (their gold is #c7910c),
so the floor lands where the theme's authors put them by hand.

Where a hue cannot reach its target ratio even at full lightness (a saturated
blue can only get so bright), the closest achievable value is used and the
shortfall is reported rather than silently accepted.

Usage:  derive-dark-from-light.py [--report]   print the mapping table
        derive-dark-from-light.py --write      write the two artifacts:
            cursor/bearded-dark-colors.json    workbench colours, merged UNDER
                                               the chrome copy by the theme hook
            cursor/bearded-dark-tokens.json    editor.tokenColorCustomizations +
                                               semanticTokenColorCustomizations,
                                               merged into settings.json by
                                               apply.sh

Both are GENERATED -- committed for the install path, but re-run this after a
Bearded update rather than hand-editing them. The scope name they are written
under is read from cursor/settings.json's workbench.preferredDarkColorTheme, so
the variant is still named in exactly one place.
"""

import colorsys
import json
import os
import sys

EXT = os.path.expanduser(
    "~/.cursor/extensions/beardedbear.beardedtheme-10.1.0-universal/themes"
)
SOURCE = os.path.join(EXT, "bearded-theme-classics-light.json")  # "Bearded Theme Light"

# The backgrounds each mode ACTUALLY renders on: the chrome hook pins
# editor.background to Omarchy's window colour in both, so these are the repo's
# palette values, not Bearded's own #f3f4f5 / #221f1d.
BG_LIGHT = "#FFFFFF"
BG_DARK = "#1E1E1E"

# Minimum lightness for a derived foreground -- see the header. Bearded's own
# dark variants sit at 0.41 for these hues, so this is where hand-authored dark
# themes in this family already land.
L_FLOOR = 0.42

# Ceiling for derived text: #DDDDDD, the dark theme's own `foreground` in
# colors.toml. Without it, light themes' near-black text saturates to pure white.
L_CEIL = 0.867

# An alpha value whose composite on the dark background falls below this ratio
# is not "faint by design" any more, it is gone -- derive it opaquely instead.
ALPHA_MIN_RATIO = 2.0

# A surface this saturated is an accent (badge, button, progress bar) rather
# than a shade of the window, and accents carry across polarities unchanged.
ACCENT_SAT = 0.25

# A foreground this light is text drawn ON one of those accents, so it stays as
# it is instead of being flipped along with the text that sits on the window.
CHIP_TEXT_L = 0.85

# Keys the chrome hook owns. They are skipped here so the two never disagree:
# the hook's copy wins anyway (it is merged on top), and emitting them would
# just make the generated file misleading about what is in force.
CHROME_PREFIXES = (
    "titleBar.", "activityBar", "sideBar", "statusBar", "editorGroupHeader.",
    "tab.", "panel", "menu", "commandCenter.", "toolbar.", "banner.",
    "breadcrumb", "quickInput", "pickerGroup.", "editorHoverWidget.",
    "keybindingLabel.",
)
CHROME_EXACT = {"editor.background", "editorGutter.background"}


def parse(c):
    """'#rgb' / '#rrggbb' / '#rrggbbaa' -> (r, g, b, a) floats in 0..1."""
    c = c.lstrip("#")
    if len(c) in (3, 4):
        c = "".join(ch * 2 for ch in c)
    r, g, b = (int(c[i:i + 2], 16) / 255 for i in (0, 2, 4))
    a = int(c[6:8], 16) / 255 if len(c) == 8 else 1.0
    return r, g, b, a


def hexof(r, g, b):
    return "#%02X%02X%02X" % tuple(max(0, min(255, round(v * 255))) for v in (r, g, b))


def over(fg, bg):
    """Composite fg (with alpha) onto opaque bg."""
    r, g, b, a = fg
    br, bg_, bb, _ = bg
    return (r * a + br * (1 - a), g * a + bg_ * (1 - a), b * a + bb * (1 - a), 1.0)


def luminance(rgb):
    def ch(v):
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(v) for v in rgb[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def adapt(value, bg_light=None, bg_dark=None):
    """Foreground rule: same hue and saturation, same contrast, lighter than bg.

    Returns (hex, achieved_ratio, target_ratio).
    """
    bg_light = bg_light or parse(BG_LIGHT)
    bg_dark = bg_dark or parse(BG_DARK)
    eff = over(parse(value), bg_light)
    target = contrast(eff, bg_light)
    h, l, s = colorsys.rgb_to_hls(*eff[:3])
    chroma = s * (1 - abs(2 * l - 1))       # absolute, see the header

    def at(light):
        """The colour at this lightness, holding hue and chroma."""
        room = 1 - abs(2 * light - 1)
        sat = min(1.0, chroma / room) if room > 1e-6 else 0.0
        return colorsys.hls_to_rgb(h, light, sat)

    # Bisect on lightness, starting ABOVE the background's own lightness -- see
    # the header: an unconstrained solve answers low targets on the dark side of
    # the page, which is technically correct and unreadable.
    _, bl, _ = colorsys.rgb_to_hls(*bg_dark[:3])
    lo, hi = bl, 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        if contrast(at(mid) + (1.0,), bg_dark) < target:
            lo = mid
        else:
            hi = mid
    best = min(max((lo + hi) / 2, L_FLOOR), L_CEIL)
    rgb = at(best)
    return hexof(*rgb), contrast(rgb + (1.0,), bg_dark), target


# Surfaces rather than text: these are sat on, not read, so they mirror the
# lightness DELTA from the window colour instead of preserving contrast.
BG_SUFFIXES = ("ackground", "Border", "border", "Shadow", "shadow")

# Shadows are not derived at all. cursor/settings.json zeroes six shadow ids at
# the UNSCOPED top level and the theme hook assigns widget.shadow itself, and a
# scoped value beats an unscoped one -- so emitting any shadow here would
# silently undo both. The scroll shadow reappearing under the tab bar is exactly
# that failure.
SKIP_SUFFIXES = ("Shadow", "shadow")


def adapt_surface(value, bg_light=None, bg_dark=None):
    """Background rule: same hue and saturation, mirrored lightness delta."""
    bg_light = bg_light or parse(BG_LIGHT)
    bg_dark = bg_dark or parse(BG_DARK)
    h, l, s = colorsys.rgb_to_hls(*parse(value)[:3])
    _, ll, _ = colorsys.rgb_to_hls(*bg_light[:3])
    _, dl, _ = colorsys.rgb_to_hls(*bg_dark[:3])
    out = max(0.0, min(1.0, dl + (ll - l)))
    return hexof(*colorsys.hls_to_rgb(h, out, s))


def adapt_wash(value, bg_light=None, bg_dark=None):
    """Alpha surface rule: mirror what it composites to, keep the alpha.

    Returns the same 8-digit form it was given.
    """
    bg_light = bg_light or parse(BG_LIGHT)
    bg_dark = bg_dark or parse(BG_DARK)
    alpha = parse(value)[3]
    comp = over(parse(value), bg_light)
    h, l, s = colorsys.rgb_to_hls(*comp[:3])
    chroma = s * (1 - abs(2 * l - 1))
    _, ll, _ = colorsys.rgb_to_hls(*bg_light[:3])
    _, dl, _ = colorsys.rgb_to_hls(*bg_dark[:3])

    target_l = max(0.0, min(1.0, dl + (ll - l)))
    room = 1 - abs(2 * target_l - 1)
    sat = min(1.0, chroma / room) if room > 1e-6 else 0.0
    target = colorsys.hls_to_rgb(h, target_l, sat)

    base = [max(0.0, min(1.0, (target[i] - (1 - alpha) * bg_dark[i]) / alpha))
            for i in range(3)]
    return hexof(*base) + "%02X" % round(alpha * 255)


def has_alpha(value):
    return len(value.lstrip("#")) in (4, 8)


def keep_alpha(value):
    """True when an alpha colour still reads once composited on the dark bg.

    Token colours get the SAME legibility test as text in the colours map, which
    an earlier version applied to the colours only. Measured on this theme, two
    of its four alpha token colours fail it: #09131666 is a near-black at 40%,
    a soft grey on white (2.62:1) and 1.06:1 on #1E1E1E -- gone -- and #3e5414cc
    lands at 1.70:1. Keeping alpha is for colours that are faint BY DESIGN, not
    for ones that merely happen to be dark.
    """
    if not has_alpha(value):
        return False
    composite = over(parse(value), parse(BG_DARK))
    return contrast(composite, parse(BG_DARK)) >= ALPHA_MIN_RATIO


def token_colours(src):
    """Every distinct foreground that needs mapping.

    Opaque ones always; alpha ones only when keeping them would leave the token
    illegible on the dark background.
    """
    seen = {}

    def note(fg):
        if isinstance(fg, str) and fg.startswith("#") and not keep_alpha(fg):
            seen[fg] = seen.get(fg, 0) + 1

    for rule in src.get("tokenColors", []):
        note(rule.get("settings", {}).get("foreground"))
    for val in src.get("semanticTokenColors", {}).values():
        note(val.get("foreground") if isinstance(val, dict) else val)
    return seen


def main():
    src = json.load(open(SOURCE))
    mapping = {c: adapt(c) for c in token_colours(src)}

    if "--write" not in sys.argv:
        print(f"source: {os.path.basename(SOURCE)}  "
              f"({len(src['tokenColors'])} rules, {len(token_colours(src))} distinct colours)")
        print(f"\n{'light':<12}{'dark':<12}{'target':>8}{'got':>8}   note")
        for c, (dark, got, target) in sorted(mapping.items(), key=lambda kv: -kv[1][2]):
            if got > target + 0.05:
                note = f"floored (+{got - target:.2f})"
            elif got < target - 0.05:
                note = f"short by {target - got:.2f}"
            else:
                note = ""
            print(f"{c:<12}{dark:<12}{target:>8.2f}{got:>8.2f}   {note}")
        return 0

    out_dir = os.path.dirname(os.path.abspath(__file__))

    rules = []
    for rule in src.get("tokenColors", []):
        settings = dict(rule.get("settings", {}))
        fg = settings.get("foreground")
        if fg and fg in mapping:
            settings["foreground"] = mapping[fg][0]
        scope = rule.get("scope")
        if scope is None:
            continue
        rules.append({"scope": scope, "settings": settings})

    semantic = {}
    for key, val in src.get("semanticTokenColors", {}).items():
        if isinstance(val, dict) and isinstance(val.get("foreground"), str):
            v = dict(val)
            v["foreground"] = mapping[val["foreground"]][0]
            semantic[key] = v
        elif isinstance(val, str):
            semantic[key] = mapping[val][0]

    # Scoped to the dark variant BY NAME, so light mode keeps Bearded Theme
    # Light untouched -- the whole point is that the two modes are one scheme,
    # and the light half already is that scheme. The name is read from
    # settings.json rather than repeated here.
    settings_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 "settings.json")
    dark_name = json.load(open(settings_path)).get(
        "workbench.preferredDarkColorTheme")
    if not dark_name:
        sys.exit("cursor/settings.json has no workbench.preferredDarkColorTheme")
    scope = "[%s]" % dark_name

    tokens = {
        "editor.tokenColorCustomizations": {scope: {"textMateRules": rules}},
        "editor.semanticTokenColorCustomizations": {
            scope: {"enabled": True, "rules": semantic},
        },
    }

    colors = {}
    for key, val in src.get("colors", {}).items():
        if not isinstance(val, str) or not val.startswith("#"):
            continue
        if key in CHROME_EXACT or any(key.startswith(p) for p in CHROME_PREFIXES):
            continue
        if key.endswith(SKIP_SUFFIXES):
            continue
        h, l, sat = colorsys.rgb_to_hls(*parse(val)[:3])
        alpha = parse(val)[3]
        if alpha == 0:
            colors[key] = val                       # a feature switched OFF
        elif alpha < 1:
            if key.endswith(BG_SUFFIXES):
                colors[key] = adapt_wash(val)       # wash: mirror the composite
            elif contrast(over(parse(val), parse(BG_DARK)),
                          parse(BG_DARK)) >= ALPHA_MIN_RATIO:
                colors[key] = val                   # text, faint by design
            else:
                colors[key] = adapt(val)[0]         # text, would be invisible
        elif key.endswith(BG_SUFFIXES):
            # An accent surface needs no adaptation; a neutral one mirrors.
            colors[key] = val if sat >= ACCENT_SAT else adapt_surface(val)
        elif l >= CHIP_TEXT_L:
            colors[key] = val                       # text on a chip, not the page
        else:
            colors[key] = adapt(val)[0]             # text/icon: preserve contrast

    with open(os.path.join(out_dir, "bearded-dark-tokens.json"), "w") as fh:
        json.dump(tokens, fh, indent=2, sort_keys=True)
        fh.write("\n")
    with open(os.path.join(out_dir, "bearded-dark-colors.json"), "w") as fh:
        json.dump(colors, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print(f"wrote bearded-dark-tokens.json ({len(rules)} rules, "
          f"{len(semantic)} semantic) scoped to {scope}")
    print(f"wrote bearded-dark-colors.json ({len(colors)} colours)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
