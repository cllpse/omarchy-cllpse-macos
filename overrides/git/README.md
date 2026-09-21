# git

git: route `git diff` through hunk (see git/pager.conf for why it needs no
guard). Fenced rather than copied, because ~/.config/git/config is Omarchy's
stock file plus the user's own [user] block -- identity that must not come
from this repo. Seed from the stock copy first if the user has none, so a
fresh machine doesn't end up with a git config consisting only of our block
(the `sync_fenced` trap in README.md's gaps table).

Script: [`git.sh`](git.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.

## Why fenced, not copied

`git diff` routed through the `hunk` pager via a fenced block in
`~/.config/git/config` — fenced rather than copied because that file is
Omarchy's stock config plus the user's own `[user]` identity block, which must
not come from this repo, and seeded from
`/usr/share/omarchy/config/git/config` first when absent so a fresh machine
doesn't get a git config consisting only of our block
