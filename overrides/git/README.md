# git

Route git diff through hunk. Fenced rather than copied, because ~/.config/git/config also holds the user's identity.

The script is [`git.sh`](git.sh). It is runnable on its own and is also
called by [`../apply.sh`](../apply.sh), which owns the order. Numbered
sections below match the `# See README.md (n)` pointers in that script.

## 1. mkdir -p ~/.config/git

git: route `git diff` through hunk (see git/pager.conf for why it needs no
guard). Fenced rather than copied, because ~/.config/git/config is Omarchy's
stock file plus the user's own [user] block -- identity that must not come
from this repo. Seed from the stock copy first if the user has none, so a
fresh machine doesn't end up with a git config consisting only of our block
(the `sync_fenced` trap in README.md's gaps table).
