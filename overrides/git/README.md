# git

git: route `git diff` through hunk (see git/pager.conf for why it needs no
guard). Fenced rather than copied, because ~/.config/git/config is Omarchy's
stock file plus the user's own [user] block -- identity that must not come
from this repo. Seed from the stock copy first if the user has none, so a
fresh machine doesn't end up with a git config consisting only of our block
(the `sync_fenced` trap in README.md's gaps table).

Script: [`git.sh`](git.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
