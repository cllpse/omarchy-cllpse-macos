-- Omarchy shell popups (menu, launcher, polkit, emoji, clipboard) draw in this
-- family instead of the monospace alias -- see Style.qml menuFontFamily. The bar
-- itself has no such override and stays on `monospace`. cllpse-macos wants the
-- proportional macOS UI face here (BUILD.md section 4).
-- Appended to ~/.config/hypr/hyprland.lua by overrides/apply.sh.
-- Takes effect on the next Hyprland start (relogin / reboot).
hl.env("OMARCHY_MENU_FONT", "SFProText Nerd Font Propo")
