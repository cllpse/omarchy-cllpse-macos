# environment.d

systemd user-session environment. Read at session start, so these need a relogin.

The script is [`environment.d.sh`](environment.d.sh). It is runnable on its own and is also
called by [`../apply.sh`](../apply.sh), which owns the order. Numbered
sections below match the `# See README.md (n)` pointers in that script.

## 1. for _stale in 10-cllpse-macos-font-rendering.conf; do

Read by the systemd user session (uwsm starts Hyprland through it), so these
survive application updates in a way a wrapper script inside an app directory
does not. Applies from the next login.

Drop-ins this repo no longer ships, by name. Both the install loop below and
revert.sh iterate the REPO directory, so a file deleted from the repo becomes
invisible to both and the installed copy lives on forever -- which is exactly
what happened to the FreeType stem-darkening drop-in: removing it from the
repo changed nothing on any machine that had already applied, and the session
kept exporting FREETYPE_PROPERTIES with no line in the repo to explain it.
Same idiom as the legacy fontconfig names in step 2.

## From the step table

Install session environment drop-ins (Figma → native Wayland)
