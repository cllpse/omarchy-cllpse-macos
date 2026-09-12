[Desktop Entry]
# Managed by omarchy-cllpse-macos — apply.sh step 7e renders this template into
# ~/.local/share/applications/. Edit the template in the repo, not the installed
# copy; a re-run overwrites it.
#
# The app is nickvdp/figma-desktop-linux, an AppImage repack of Figma's own
# Electron build, run from an extracted directory rather than the .AppImage.
# Two fields here differ from what it writes for itself (AppRun: integrate_desktop),
# and both are deliberate.
#
# 1. Name. Its generated entry says "Figma"; its AppStream <name> and
#    X-AppImage-Name both say "Figma Desktop". The longer one is the real
#    product name and is what the launcher and the window switcher both show.
#
# 2. StartupWMClass. It declares "Figma". The class Hyprland actually reports is
#    the lowercase "figma-desktop", so its own value joins to no window at all —
#    taskbar grouping, startup notification and the switcher's class ->
#    desktop-entry lookup (Hud.qml classIndex, which is where the tile label
#    "Figma Desktop" comes from) all miss with it.
#
# EXEC MUST STAY BYTE-EXACT. integrate_desktop() runs on every launch and
# rewrites this whole file — Name and StartupWMClass back to its own — unless
# the Exec line already equals `Exec="${appimage_path}" %u`. With APPIMAGE unset
# (which it is: this is an extracted directory, not a mounted .AppImage) that
# path is `readlink -f "$0"`, i.e. the line below. It carries no version, so it
# stays correct across updates and the rewrite never fires.
#
# This is why nothing wraps AppRun. A wrapper displaces the real launcher to
# AppRun.real, which changes that computed path and has to be repaired with an
# APPIMAGE export — a file inside the app directory, which an update deletes.
# FIGMA_USE_WAYLAND, a wrapper's other job, comes from environment.d instead.
Name=Figma Desktop
Exec="{{ home }}/Applications/figma-desktop/AppRun" %u
# Resolves two ways, so it survives either going missing: the app's own
# integration installs hicolor/256x256/apps/figma-desktop.png, and this repo
# ships icons/color/figma-desktop.svg, which lands in ~/.icons/cllpse-color/apps/
# — the first directory in the sweep both AppLibrary and the switcher run.
Icon=figma-desktop
Type=Application
Terminal=false
Categories=Graphics;
Comment=Figma Desktop for Linux (AppImage)
MimeType=x-scheme-handler/figma;
StartupWMClass=figma-desktop
