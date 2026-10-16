# Desktop entries

Figma Desktop ships an entry whose Name= and StartupWMClass are both wrong for this setup. This replaces it. T3 Code's entry names a window class it does not use; section 3 corrects that one line.

## 1. The app regenerates its own entry on every

The app regenerates its own entry on every launch (AppRun: integrate_desktop)
and gets two fields wrong for this desktop: Name=Figma, where the product is
"Figma Desktop" (its own AppStream <name> and X-AppImage-Name agree), and
StartupWMClass=Figma against a live Hyprland class of "figma-desktop". Nothing
joins an entry to a window through that second value, which costs taskbar
grouping, startup notification, and the window switcher's class -> entry
lookup -- the switcher printed a hardcoded "Figma" for as long as that lookup
could not land.

integrate_desktop() only rewrites the file when the existing Exec differs from
`Exec="${appimage_path}" %u`, and with APPIMAGE unset that path is
`readlink -f "$0"` -- here ~/Applications/figma-desktop/AppRun, which carries
no version. So the template's Exec matches what the app would write, on every
version, and the rewrite never fires. Updating Figma is therefore: extract
over the app directory, re-run this script.

That only holds while AppRun is the app's OWN launcher. A wrapper displaces it
to AppRun.real, which changes the computed path and then needs an APPIMAGE
export to paper over -- a file inside the app directory, which the next
extraction deletes, silently handing Name and StartupWMClass back. This
machine carried exactly that wrapper; its other job, FIGMA_USE_WAYLAND=1, is
step 7c's environment.d drop-in, which no update can reach. So the wrapper is
removed rather than maintained, and the unwrap is idempotent and conservative:
it acts only when AppRun is demonstrably not the launcher and AppRun.real
demonstrably is.

Not installing Figma is the normal case on another machine, so a missing app
directory is a skip, not an error -- nothing else here depends on the entry.

## 2. Something is standing in for the launcher and

Something is standing in for the launcher and there is no AppRun.real
to put back. Figma is already broken in this state (a wrapper execs a
file that is gone), but it fails at launch, far from here -- so say so
rather than writing an entry that points at it.

## 3. T3 Code's entry names a class it does not use

`t3code-bin`'s `/usr/share/applications/t3code.desktop` declares
`StartupWMClass=t3code`, and the window reports `com.t3tools.T3Code` (checked
with `hyprctl clients -j` on 2026-10-16, 0.0.45). So the switcher's class →
entry lookup lands nowhere, and its tile name fell back first to a
curated rule ("contains `code`", which read it as VS Code, fixed in the
switcher the same day) and then to title-casing the class: "T3code".

The step writes `~/.local/share/applications/t3code.desktop`, which shadows
the package's entry by having the same file id: the package's file with the
`StartupWMClass` line replaced, regenerated on every run, so an update to
`Exec`, `Name` or the `x-scheme-handler/t3code` handlers comes through. With
it the tile reads the entry's `Name=`, "T3 Code". The icon is not taken from
this entry: the class-named drop-in `com.t3tools.T3Code.svg` is looked up
first (`../icons/AGENTS.md`). If the package ever declares the right class
itself, the step says so and the section can go. revert.sh restores a prior
copy or removes ours.

## From the step table

Figma Desktop's launcher entry. The app regenerates its own entry on every
launch (`AppRun: integrate_desktop`) and gets two fields wrong for this
desktop: `Name=Figma` (its AppStream `<name>` and `X-AppImage-Name` both say
*Figma Desktop*) and `StartupWMClass=Figma` against a live Hyprland class of
`figma-desktop` — so nothing that joins an entry to a window through that
value lands, including the window switcher's class → entry lookup, which is
where its tile label comes from. Rendered from a template (`{{ home }}`
expanded), skipped entirely if Figma isn't installed. The regeneration only
fires when `Exec` differs from `Exec="${appimage_path}" %u`, which for an
extracted directory is `readlink -f "$0"` — a path with no version in it, so
the template's Exec matches on every release and the entry is never taken
back. The step also **removes a wrapper around `AppRun`** if it finds one: a
wrapper displaces the launcher to `AppRun.real`, which is what breaks that
path in the first place, and lives inside the app directory where the next
extraction deletes it

T3 Code's entry, with the class it actually uses (`StartupWMClass=com.t3tools.T3Code`
against the package's `t3code`), derived from the package's own entry on every
run (§3).

Script: [`applications.sh`](applications.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
