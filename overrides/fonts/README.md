# Fonts

The SF faces the whole desktop is set in, plus Comic Code for the editor. Copied into ~/.local/share/fonts/; fontconfig/ is what makes anything resolve to them.

The script is [`fonts.sh`](fonts.sh). It is runnable on its own and is also
called by [`../apply.sh`](../apply.sh), which owns the order. Numbered
sections below match the `# See README.md (n)` pointers in that script.

## 1. say "Installing Comic Code -> ~/.local/share/fonts/ComicCode/"

Comic Code, the editor font cursor/settings.json names. Kept in its own
subdirectory rather than beside the SF faces, because the step above globs
fonts/*.otf into ~/.local/share/fonts/SF/ and these are not SF -- the subdir
keeps them out of that glob and out of that directory.
