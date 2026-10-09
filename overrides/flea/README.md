# Flea

[Flea](https://github.com/thisisgm/flea) is a keyboard-first file manager built
for Omarchy: a Rust backend under a Quickshell window that reads Omarchy's own
`Commons` and `Ui`, so it follows the active theme with nothing to generate.
This step makes it the desktop's file manager in the three places one is
asked for: opening a folder, "Show in folder", and the Open/Save dialog. It
binds it to **SUPER+ALT+SPACE** (macOS's Cmd+Option+Space) instead of the
SUPER+SHIFT+F that Flea's own `flea --default` takes.

It is everything `flea --default` does except that command's keys block, which
would take Cmd+Shift+F away from the find-in-files forward. Section 5 explains
why.

## 1. The fourth package this repo depends on, and it installs none of them

`keyd`, `ryzenadj` and `tailscale` were the first three. Flea has to be present
already: this step configures it or says why it cannot. The skip line gives
upstream's recommended install:

```
omarchy pkg aur add flea-bin
```

`flea-bin` is the tagged release, prebuilt, and `omarchy update` keeps it
current. Omarchy's own repository carries the same release as `flea` a day or
more later. Install one, never both: all three packages (`flea`, `flea-bin`,
`flea-git`) own `/usr/bin/flea`.

Installed is tested two ways: `flea` on `PATH`, and the package's
`com.thisisgm.flea.desktop`. The desktop entry is the one that matters, since
the folder handler (2) names it. A `cargo build` binary with no package behind
it has the binary and lacks the entry, and the step treats that as not
installed.

When Flea is absent the step also checks for leftovers. If an earlier run bound
SUPER+ALT+SPACE, it says the key now does nothing. If Flea's "Show in folder"
registration (3) names a binary that is gone, it says that is broken and how to
delete it.

## 2. Folders: one `xdg-mime` line, read back

```
xdg-mime default com.thisisgm.flea.desktop inode/directory
```

This is the same stock tool `flea --default` uses, and it writes one line to
`~/.config/mimeapps.list`. It sets that one type only, because Flea's entry
registers no other. `xdg-mime default` exits 0 whatever it did, so the answer is
read back with `xdg-mime query default` rather than trusted.

The handler in effect before the first apply is recorded verbatim in
`$STATE/previous-flea-handler`, with an empty refuse-value as in
[`tailscale/README.md`](../tailscale/README.md) §3. Here that means "Flea was
already the default" gets recorded as Flea's own id instead of nothing.
`revert.sh` relies on that difference: it undoes the integration only when this
step is what made Flea the default, and leaves alone a Flea the user had set up
before.

## 3. "Show in folder": a user D-Bus registration, byte for byte Flea's

Chromium, Firefox, Steam and the rest reveal a file by calling
`org.freedesktop.FileManager1` on the session bus. The package registers Flea
for that name in `/usr/share/dbus-1/services/`, but Nautilus registers there
too (it is in `omarchy-base.packages`), and D-Bus keeps whichever registration
it reads first. That order is not something a package can steer. A file in
`~/.local/share/dbus-1/services/` is read before every system one, so that is
where this goes:

```
# Written by `flea --default`; `flea --default off` removes it.
[D-BUS Service]
Name=org.freedesktop.FileManager1
Exec=/usr/lib/flea/flea-filemanager1
```

The `Exec` is copied from the packaged registration rather than hardcoded,
which is also how Flea does it. If the packaged registration is missing, the
step skips instead of naming a path that may not exist.

**The first line claims Flea wrote it, and that is deliberate.** Flea reads
that line to decide whether the file is its own. With any other first line,
`flea --default` reports "already there and Flea did not write it, so it was
left alone", `flea --default off` leaves the file behind, and Flea's Settings ▸
About switch can no longer manage it. A byte-identical file keeps Flea's own
undo working on what this step wrote, and the line's claim that
`flea --default off` removes it stays true. Measured: the file this step
generates `cmp`s equal to the one `flea --default` writes.

A registration somebody else put there (any other first line) is backed up to
`.pre-cllpse` before it is replaced.

**The one leftover that is not inert.** If Flea is removed and this file stays,
D-Bus does not fall through to the next claimant. It tries the missing binary
and the call fails with `org.freedesktop.DBus.Error.Spawn.ExecFailed`. Flea's
own install doc measured this. That is why (1) checks for the case, and why
`revert.sh` removes the file when Flea is already gone.

## 4. File dialogs: `flea --picker`, unmodified

This is Flea's own verb, used as is. It writes one key into
`~/.config/xdg-desktop-portal/portals.conf`:

```
[preferred]
org.freedesktop.impl.portal.FileChooser=flea;gtk
```

It has no `default=` line, so every other portal interface still falls through
to Omarchy's `hyprland-portals.conf`. `gtk` stays behind `flea` as a fallback
chooser. The command also writes a small block into `bindings.lua` that floats
the picker window (`com.thisisgm.flea.picker`), the same tag treatment Omarchy
gives `xdg-desktop-portal-gtk`. If `hyprland-portals.conf` exists in the user
directory, Flea writes the key there instead, because xdg-desktop-portal then
ignores `portals.conf`.

xdg-desktop-portal reads its configuration only at startup. Flea restarts it
itself when its output is a terminal and leaves that to the caller otherwise.
This step captures the output, so the restart is done here, and only when a
`*portals.conf` actually changed: `systemctl --user try-restart
xdg-desktop-portal.service`, which leaves a portal that is not running alone.
Flea's own "restart it yourself" and "undo with" lines are dropped from the
output for that reason. Everything else it prints is passed through.

A failure is reported and does not stop the run. Flea restores
`bindings.lua` itself if its block breaks the config.

## 5. The keys block `flea --default` writes is removed

`flea --default` appends this to the end of `~/.config/hypr/bindings.lua`:

```lua
-- flea --default: begin. Written by `flea --default`; `flea --default off` removes the block whole.
hl.unbind("SUPER + SHIFT + F")
o.bind("SUPER + SHIFT + F", "File manager", { launch = 'flea --gui' })
hl.unbind("SUPER + ALT + SHIFT + F")
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { launch = 'flea --gui "$(omarchy-cmd-terminal-cwd)"' })
-- flea --default: end.
```

On stock Omarchy those two keys open Nautilus, so this is a like-for-like swap.
Here they are not Nautilus:

- **SUPER+SHIFT+F** is `macos-shortcuts.lua`'s Cmd+Shift+F → Ctrl+Shift+F
  forward, which is find in files in Cursor and the equivalent in anything else
  that has one. Flea's block lands after every one of our fenced blocks, so it
  wins on file position (the gap
  [`../README.md`](../README.md#what-applysh-does-and-does-not-guarantee) calls
  *plugin-owned regions*), and Cmd+Shift+F opened a file manager everywhere.
- **SUPER+ALT+SHIFT+F** is one `keybind-allowlist.conf` had pruned. The
  allowlist cannot prune it back: its unbinds are in the `keybinds` block,
  which sits above Flea's.

So the step removes the block: the lines from `-- flea --default: begin.` to
`-- flea --default: end.` and the blank line Flea put before them. Nothing else
is touched. Both markers have to be present. A begin with no end would have the
removal run to the end of the file, so in that case the block is left in place
and reported. The rewrite goes through the original file, as `sync_fenced`'s
does, to keep its inode. The first removal records `present` in
`$STATE/previous-flea-keys` so that `revert.sh` can put it back on a machine
where Flea was set up before this repo (2).

**This is why the step re-implements (2) and (3) instead of calling
`flea --default` and stripping afterwards.** Calling it would re-append the
block and reload Hyprland on every run, and the strip would then undo it and
reload again. Each part done here is idempotent on its own, and a second run
writes nothing.

**What brings the block back:** running `flea --default` by hand, or toggling
Settings ▸ About ▸ *Make Flea the default* in Flea, which runs the same
command. Cmd+Shift+F then opens Flea until the next `apply.sh flea`. The switch
itself still reads as ticked after this step, because it tests only
`xdg-mime query default inode/directory`.

## 6. SUPER+ALT+SPACE

[`flea-bindings.lua`](flea-bindings.lua) is synced into `bindings.lua` as the
`: flea` fenced block. Apple's page lists Cmd+Option+Space under Spotlight, as
the way "to perform a Spotlight search from a Finder window", and it opens a
Finder window from anywhere. This opens a Flea window. Flea's own search is
`f`, so it lands one key short of Apple's.

The chord was Omarchy's *Apps menu* until the allowlist pruned it. It stays
**out** of the allowlist on purpose: the `keybinds` block unbinds whatever
Omarchy puts there now or later, and this block, synced after it, is the one
that survives. That is the same SUPER+W pattern `macos-shortcuts.lua` describes.
It also explains why `apply.sh` lists `hypr` as this step's prerequisite. On a
machine where `hypr` has never run, the `: flea` block would be appended before
the `keybinds` block. The next scan would find SUPER+ALT+SPACE bound and not
allowlisted, and the generated unbind, landing after it, would remove it.

Like every SUPER chord outside the `figma:C` layer's carve-outs, it does nothing
while Figma is focused.

## Revert

`revert.sh` removes the `: flea` block along with every other fenced block.
The rest depends on what (2) recorded:

- **Flea was already the default** before the first apply: the integration is
  left alone. If (5) removed Flea's keys block, `flea --default` is run to put
  it back, since that block is what the machine had.
- **Something else was**: `flea --default off` undoes all of it (the
  `mimeapps.list` line, the D-Bus file, the portal key and the picker block),
  and the recorded handler is pinned back if the system default is not it.
- **Flea has since been uninstalled**: there is no binary to run the undo. The
  D-Bus file is deleted if it is Flea's (3), since that is the leftover that
  breaks "Show in folder". The other leftovers are inert and are named rather
  than edited.

## Not handled here

- **Flea's own settings** (`~/.local/state/flea/ui.json`) are Flea's. The
  repo records none of them, though `flea --ui-state '<json patch>'`
  deep-merges a patch into them if that ever changes.
- **The shelf**, Flea's bar plugin, stays off. It is copied into the plugin
  directory only from Flea's own settings, and nothing in `shell.json`'s
  recorded layout names it.
- **Uninstalling Flea.** Run `flea --default off` first, then
  `omarchy pkg drop flea-bin`. Flea's pacman hook prints the same reminder.
