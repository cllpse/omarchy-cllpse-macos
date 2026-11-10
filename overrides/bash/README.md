# bash

fzf, lsd colours, the tool aliases and Ghostty's bottom-row prompt, fenced into ~/.bashrc.

Script: [`bash.sh`](bash.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.

## The aliases

tool aliases (`edit` → msedit, `diff` → `hunk diff` — a live-reloading
working-tree review with the files pane open (both from
`hunk/config.toml.tpl`, not flags), which shadows `/usr/bin/diff` in
interactive shells, `log` → `hunk log` — the commit browser that pairs with
it, shadowing nothing, `dash` → `gh dash`) plus the `ytm` function (which
fixes yt-dlp's keyring backend, not just the name), each guarded on its tool
the way the `ls` → `lsd` alias is — `gh-dash` is a gh *extension* rather than
a binary, so its guard tests the extension directory instead of shelling out
to `gh extension list` (34ms, on every interactive shell)

## The prompt on the bottom row (Ghostty)

A new Ghostty window prompts on its last row, and a cleared one does too: the
"input at the bottom" shape of Warp and macOS Terminal with a tall scrollback.
Ghostty has no setting for it; the shell places the prompt, so the block at the
end of `shell.sh` hooks the three moments it is drawn anywhere else. It is
guarded on `TERM_PROGRAM == ghostty`, so inside tmux or over ssh nothing
changes.

- **Every prompt:** `_cllpse_prompt_bottom`, appended to `PROMPT_COMMAND`
  (after starship, the title printf and zoxide), moves the cursor to the last
  row with CUD (`ESC [ 9999 B`). CUD clamps and never scrolls, so a command's
  output stays put with blank rows between it and the prompt. Once the prompt
  is on the bottom row, output scrolls past it as always; the hook only acts
  after a fresh window, a `clear`, or a program that drew its own screen.
- **A blank screen** (first prompt of a window, the `clear` wrapper, Ctrl+L):
  newlines instead, twice the screen height. Half walk the cursor down, half
  scroll, so a screen of blank rows lands in *scrollback*. That is for
  resizes: Ghostty 1.4.0 grows a window by pulling rows back out of scrollback
  only while the cursor is on the bottom row (`PageList.resize`,
  `pull_scrollback`), and with nothing to pull it appends blank rows below the
  prompt, which then sits mid-screen until the next Enter. A neighbouring tile
  closing is exactly that grow. The cost: scrolling up right after a clear
  shows one blank screen. Only a shell that knows the screen is blank may do
  this, since the newlines would scroll real output off the top, so
  `_CLLPSE_BOTTOM_SEEN` is exported and a nested `bash` takes the CUD path.
- **Ctrl+L and Cmd+K:** readline's `clear-screen` redraws the prompt on the
  first row. A `bind -x` on `\C-l` replaces it with an erase plus the
  blank-screen fill; readline then redraws the prompt, typed text included,
  where the cursor is. Cmd+K ends up in the same handler: Ghostty's
  `clear_screen` (CTRL+SHIFT+K in `../ghostty/ghostty.conf`, forwarded from
  SUPER+K) erases screen and scrollback itself and, when its OSC 133 marks say
  the cursor is at a prompt, writes a form feed (0x0C) to the pty
  (`termio/Termio.zig`, `clearScreen`). 0x0C is Ctrl+L to readline. Inside a
  program it sends nothing.

Why not a `WINCH` trap for resizes: bash runs it, but after readline's own
redraw, so the prompt it moves is never repainted (readline redraws only on a
size *change*, so a second `kill -WINCH` is ignored). `bind -x` is the one
shell-side hook readline repaints after. Why not a cursor-position query
(`ESC [ 6 n`) in the prompt: anything typed ahead during a long command sits
in front of the reply and is eaten with it.

Verified 2026-11-09 in a tmux-hosted bash with Ghostty's own shell
integration (`GHOSTTY_BASH_INJECT=1 ENV=.../ghostty.bash bash --posix`) and
the real `~/.bashrc`: first prompt, `seq 3`, Ctrl+L with text typed, `clear`,
output without a trailing newline, a nested `bash`. The grow case is read from
Ghostty's source, not measured: a window on a workspace nobody is looking at
takes `hl.dsp.window.resize` in Hyprland's eyes but GTK never resizes the
unmapped surface, so its pty keeps its rows. Probe in a new Ghostty shell:
`bind -X | grep C-l` and `declare -p PROMPT_COMMAND`.

Takes effect in new shells only. A running Ghostty window keeps the old bash
until it is closed, or `exec bash`.
