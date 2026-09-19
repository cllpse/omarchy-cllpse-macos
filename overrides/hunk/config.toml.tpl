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

# Force the files pane open rather than letting the responsive layout decide
# ("auto", the runtimeDefault). This only bites because ../bash/shell.sh routes
# `diff` through `hunk diff`: a PAGER session -- which is what ../git/pager.conf
# still hands plain `git diff` -- hard-codes the pane shut regardless of config
# (`forceSidebarOpen = !pagerMode && initialSidebar === true`, read out of the
# 0.22.0 binary), so this key is inert on that path. `s` toggles it by hand in
# either session, and a narrow terminal still wins: the pane has a 22-column
# minimum and drops out below it.
sidebar = true

# View preferences, pinned rather than left to hunk's responsive defaults. These
# are top-level, so they apply to every entry point -- `diff` (hunk diff), `log`
# (hunk log) and the `hunk pager` that ../git/pager.conf still hands plain
# `git diff` -- except where pagerMode overrides one, as it does for the menu
# bar and the files pane.
#
# hunk writes this same file when you save view changes from inside the TUI (the
# "save view preferences?" prompt on quit), so a key changed there lands here
# and is then lost at the next theme switch. Change it in the template, not in
# the prompt.
mode = "split"          # always side-by-side, never the responsive collapse
menu_bar = true         # top application menu bar
line_numbers = true     # old and new line-number columns
wrap_lines = true       # wrap long lines instead of truncating to one row
hunk_headers = false    # no @@ metadata rows in the review stream

# `hunk diff` reloads as the working tree changes underneath it. This is the
# config form of the `--watch` flag, and it is SCOPED to [vcs] on purpose --
# that section is hunk's own name for "working-tree and target reviews
# (`hunk diff`)" (CONFIG_COMMAND_SECTIONS in the 0.22.0 binary, alongside
# show / stash-show / diff / patch / difftool).
#
# A top-level `watch = true` would apply to every command instead, and that
# BREAKS the pager path: ../git/pager.conf hands plain `git diff` to
# `hunk pager`, whose input is a patch on stdin, and watch refuses it --
# measured under a pty, the pager exits with "`--watch` requires a file- or
# Git-backed input that Hunk can reopen" and no diff is drawn at all. Scoped to
# [vcs], the same pty run paints normally. Keep the key in this section.
#
# The one cost, which no config key avoids: with watch on, a NON-TTY `hunk diff`
# fails rather than printing its static diff -- "`--watch` requires an
# interactive output terminal", exit 1. `hunk diff | head` and
# `hunk diff > out.patch` are the shapes that hit it. `git diff` is unaffected
# either way, since git only reaches for a pager when stdout is a terminal.
#
# Note this table has to sit below every bare key above it, TOML being
# order-sensitive -- a plain `key = value` after a [section] header would land
# inside that section.
[vcs]
watch = true

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
