# gh-dash

gh-dash. Installed as a theme-set HOOK rather than merged once here, because
gh-dash cannot follow the terminal's ANSI palette: it hands colour strings to
termenv, which resolves an index against its own hardcoded table instead of
leaving slots 0-15 to the terminal. Measured on v4.25.2 -- "4" came out as
ESC[38;2;0;0;128m (xterm navy), not the theme's blue. So the palette is baked
from colors.toml on every theme-set, the way hunk and starship are.
The hook still MERGES rather than copies: config.yml also holds the user's own
prSections / issuesSections / layout, so only theme.colors is replaced.

Script: [`gh-dash.sh`](gh-dash.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
