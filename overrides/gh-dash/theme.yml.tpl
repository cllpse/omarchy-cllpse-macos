# GENERATED -- do not edit. Rewritten from this template by
# overrides/hooks/theme-set.d/gh-dash-colors.sh on every `omarchy theme set`,
# which merges it into ~/.config/gh-dash/config.yml (merged, not copied: that
# file also holds the user's own prSections / issuesSections / layout).
#
# HEX, not ANSI indices -- and that is the whole point of this file. The earlier
# version named palette slots ("4", "7", "8") on the theory that lipgloss passes
# a bare number through as an index for the terminal to resolve from its own
# repainted palette. It does not. gh-dash hands the string to termenv, which
# resolves an ANSI index against ITS OWN hardcoded table and then converts to
# whatever the profile supports. Measured on v4.25.2, in a pty that answers the
# OSC 11 query gh-dash blocks on:
#
#   COLORTERM=truecolor  "4" -> ESC[38;2;0;0;128m     (xterm navy)
#                        "7" -> ESC[38;2;192;192;192m (xterm silver)
#                        "1" -> ESC[38;2;128;0;0m     (xterm maroon)
#   COLORTERM unset      "4" -> ESC[38;5;18m          (256-cube, not slot 4)
#
# Slots 0-15 are never emitted either way, so Omarchy's repainting of them could
# not reach gh-dash and the dashboard rendered in default VGA colours over the
# theme background. Hex sidesteps termenv's table entirely, at the cost of
# needing this regeneration on theme-set -- the same trade hunk makes next door.
theme:
  colors:
    text:
      primary: "{{ foreground }}"            # normal row text
      secondary: "{{ accent }}"              # section titles, counts
      inverted: "{{ selection_foreground }}" # text drawn on an accent fill
      faint: "{{ dark_foreground }}"         # timestamps, secondary metadata
      warning: "{{ yellow }}"
      success: "{{ green }}"
      error: "{{ red }}"
    background:
      selected: "{{ selection }}"
    border:
      primary: "{{ accent }}"
      secondary: "{{ muted }}"
      faint: "{{ dark_background }}"
