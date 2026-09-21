# Fonts

The SF faces the desktop is set in, plus Comic Code for the editor, copied into `~/.local/share/fonts/`. [`../fontconfig/`](../fontconfig/README.md) is what makes anything resolve to them.

Comic Code, the editor font cursor/settings.json names. Kept in its own
subdirectory rather than beside the SF faces, because the SF copy globs
fonts/*.otf into ~/.local/share/fonts/SF/ and these are not SF -- the subdir
keeps them out of that glob and out of that directory.

Script: [`fonts.sh`](fonts.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
