# Ghostty

Ghostty reads its own hinting knob rather than fontconfig's, so it needs a line of its own. Everything else about Ghostty's colours comes from the theme.

The script is [`ghostty.sh`](ghostty.sh). It is runnable on its own and is also
called by [`../apply.sh`](../apply.sh), which owns the order. Numbered
sections below match the `# See README.md (n)` pointers in that script.
