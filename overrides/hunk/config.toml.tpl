# GENERATED -- do not edit. Rewritten from this template by
# overrides/hooks/theme-set.d/hunk-colors.sh on every `omarchy theme set`.
# Hand edits are lost at the next theme switch; change the template instead.
#
# hunk is the one tool in this set that CANNOT use the terminal's ANSI palette.
# Its own validator rejects anything else: "must be a hex color like #112233"
# (describeThemeColorIssue, checked in the 0.21.1 binary), and none of its
# built-in theme ids is terminal-derived -- they are bundled Shiki themes, the
# default being github-dark-default. So instead of naming palette slots, this
# regenerates real hex from the ACTIVE theme's colors.toml, which gets to the
# same place by the other road: it tracks the Omarchy theme, just at theme-set
# time rather than at render time.
#
# transparent_background is the one genuinely terminal-aligned lever hunk does
# offer ("Let the terminal background show through Hunk surfaces"), so the
# chrome sits on the terminal's own background rather than a painted one.

theme = "custom"
transparent_background = true

[custom_theme]
label = "cllpse-macos"
# Syntax highlighting stays a Shiki theme -- hunk has no per-token hook that
# would let colors.toml drive it, so this only picks the light/dark variant.
base = "{{ base }}"

# Surfaces
background = "{{ background }}"
panel      = "{{ dark_background }}"
panelAlt   = "{{ lighter_background }}"
border     = "{{ muted }}"

# Text
text   = "{{ foreground }}"
muted  = "{{ dark_foreground }}"
accent = "{{ accent }}"
accentMuted = "{{ selection }}"

# Diff bodies. The *Bg pair is a tint of the hue over the theme background
# (18% for the row, 30% for the changed span inside it) rather than the raw
# system colour, which at full strength is far too loud behind body text.
addedBg          = "{{ added_bg }}"
addedContentBg   = "{{ added_content_bg }}"
addedSignColor   = "{{ green }}"
removedBg        = "{{ removed_bg }}"
removedContentBg = "{{ removed_content_bg }}"
removedSignColor = "{{ red }}"
contextBg        = "{{ background }}"
contextContentBg = "{{ background }}"
movedAddedBg     = "{{ moved_added_bg }}"
movedRemovedBg   = "{{ moved_removed_bg }}"
selectedHunk     = "{{ selected_hunk }}"

# Gutter
lineNumberBg = "{{ dark_background }}"
lineNumberFg = "{{ dark_foreground }}"

# File-status and badge hues, straight off the palette's system colours.
fileNew       = "{{ green }}"
fileModified  = "{{ yellow }}"
fileDeleted   = "{{ red }}"
fileRenamed   = "{{ blue }}"
fileUntracked = "{{ dark_foreground }}"
badgeAdded    = "{{ green }}"
badgeRemoved  = "{{ red }}"
badgeNeutral  = "{{ dark_foreground }}"

# Agent-note callouts
noteBackground      = "{{ dark_background }}"
noteBorder          = "{{ muted }}"
noteTitleBackground = "{{ lighter_background }}"
noteTitleText       = "{{ foreground }}"
