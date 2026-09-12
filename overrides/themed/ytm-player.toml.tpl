# ytm-player colors, generated from the active Omarchy theme.
#
# Rendered by omarchy-theme-set-templates into the current theme directory,
# then copied to ~/.config/ytm-player/theme.toml by the theme-set hook
# at ~/.config/omarchy/hooks/theme-set.d/ytm-player.
#
# Edit THIS file, not theme.toml -- theme.toml is overwritten on every
# theme change. Re-apply the theme to see changes: omarchy theme set <name>
#
# Only keys matching a field on ytm_player.ui.theme.ThemeColors are read;
# anything else is ignored. Base colors are fed back into the registered
# Textual theme, so they drive cursor and selection highlights too.

[colors]
# ── Base palette ──────────────────────────────────────────────────────
background   = "{{ background }}"
surface      = "{{ mix background foreground 7% }}"
foreground   = "{{ foreground }}"
text         = "{{ foreground }}"
primary      = "{{ accent }}"
secondary    = "{{ dark_foreground }}"
accent       = "{{ accent }}"
success      = "{{ green }}"
warning      = "{{ yellow }}"
error        = "{{ red }}"
border       = "{{ muted }}"
muted_text   = "{{ dark_foreground }}"

# ── App-specific surfaces ─────────────────────────────────────────────
playback_bar_bg = "{{ mix background foreground 5% }}"
selected_item   = "{{ selection }}"
active_tab      = "{{ accent }}"
inactive_tab    = "{{ dark_foreground }}"
progress_filled = "{{ accent }}"
progress_empty  = "{{ mix background foreground 20% }}"
lyrics_played   = "{{ dark_foreground }}"
lyrics_current  = "{{ accent }}"
lyrics_upcoming = "{{ foreground }}"
