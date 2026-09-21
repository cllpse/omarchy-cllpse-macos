# ytm-player

A Textual TUI that reads theme.toml once at startup, so its palette is baked per theme-set -- through a themed/*.tpl rather than a hand-written hook.

## 1. ytm-player

ytm-player — a Textual TUI that reads theme.toml once at startup and feeds
those colours into Textual's own ColorSystem, so the palette has to be BAKED
per theme rather than picked up from the terminal. Unlike [`../starship/`](../starship/README.md) and [`../hunk/`](../hunk/README.md),
this one does use a themed/*.tpl: Omarchy's renderer already resolves {{ mix }}
and every colors.toml key, so the hook only copies the rendered file into
place. It also rewrites [ui] theme, because theme.toml cannot set Textual's
`dark` flag and that flag drives every derived contrast token.

## 2. Preferences

Preferences, as opposed to colours: the startup page, the playhead style
and the clutter toggles don't change with the theme, so they are written
once here rather than on every theme-set. Insert-or-replace per key, so
everything we have no opinion about -- [ui] theme included, which the hook
above owns -- keeps whatever ytm or the user last put there.

## 3. Sign-in state

Sign-in state. Deliberately a REPORT, not a prompt: apply.sh runs
unattended end to end, and `ytm setup` is an interactive wizard that picks
a browser and then an account. The keyring workaround it needs is in
bash/shell.sh -- without it a session that expires can never renew itself,
because ytm's try_auto_refresh() re-extracts browser cookies through the
same yt-dlp path that `ytm setup` does.
The sign-in command. Symlinked rather than install -m755 like keyd's helper,
so edits in the repo take effect without a re-apply -- it is a script you
read and tweak, not a binary something else points at.

## 4. Sign-in state is a REPORT

Sign-in state is a REPORT, not a prompt: apply.sh runs unattended end to
end, and `ytm setup` is an interactive wizard that picks a browser and then
an account. cllpse-ytm-signin carries the keyring workaround and does its
own preflight; without that workaround ytm's try_auto_refresh() can never
renew a session, because it re-extracts browser cookies through the same
failing yt-dlp path.

Script: [`ytm.sh`](ytm.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
