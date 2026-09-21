# environment.d

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

Script: [`environment.d.sh`](environment.d.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
