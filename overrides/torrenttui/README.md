# TorrentTUI

[TorrentTUI](https://github.com/thijsvos/torrentTUI) is the BitTorrent client:
a terminal app (Rust, ratatui, librqbit) with its own engine, so there is no
daemon to run beside it. Chosen on 2026-10-16 for mouse support, which the
usual terminal clients lack: tremc has none in its source, stig turns it off
(`handle_mouse=False`), and rTorrent is keyboard-driven (not checked against
its source). Tewi, a Textual front end to a Transmission/qBittorrent/Deluge
daemon, was the other candidate with a mouse.

## What the step does

`torrenttui.sh` (apply.sh step 7) copies `config.toml` here to
`~/.config/torrenttui/config.toml`, backing up whatever was there once. A file
identical to ours is not backed up: on a machine with no config the second run
would otherwise save our own copy as the machine's, and revert.sh would put it
back instead of removing it (found on the first re-run, 2026-10-16). Two values
in it are ours; the rest is upstream's documented default:

- **`download_dir = "~/Downloads"`**, not upstream's `~/Downloads/torrents`.
- **`theme = "system"`**, upstream's default, pinned. It is TorrentTUI's ANSI
  palette, which follows the terminal's colours, so it tracks both cllpse
  themes the way the other TUIs here do (`../README.md`, *How each app is
  themed*). The named themes set 24-bit colours and are dark-only.

A copy, the lazygit pattern, not a link. The app writes the file in two
cases, both read from its `src/config.rs` (v0.18.1): it creates the defaults
when the file is missing, and the theme picker (`T`) rewrites `[ui] theme`,
the only line it touches (through `toml_edit`, so comments survive). A theme
picked there lasts until the next apply, which puts `system` back. Every key
has a default, so a partial file loads too.

When `torrenttui` is not on `PATH` the step skips and says so. revert.sh puts
back the backup, or removes the file, which the app recreates with upstream's
defaults on its next launch.

## Installing it

`apply.sh` installs nothing, and TorrentTUI is in no package manager: no
`pacman`, no AUR. Upstream's releases are static binaries, one per platform,
each with a Sigstore build-provenance attestation. Download, verify, then
install to `~/.local/bin`, which is on `PATH` and needs no sudo:

```bash
d=$(mktemp -d)
gh release download -R thijsvos/torrentTUI -p torrenttui-linux-x86_64 -D "$d"
gh attestation verify "$d/torrenttui-linux-x86_64" --repo thijsvos/torrentTUI
install -m755 "$d/torrenttui-linux-x86_64" ~/.local/bin/torrenttui
torrenttui --version
```

The same commands update it; `gh release view -R thijsvos/torrentTUI` names the
latest release. Installed on 2026-10-16: v0.18.1, built from `e0c71a1` by the
repository's `release.yml` on `main`.

**The verdict is the exit status.** Piped or captured, `gh attestation verify`
(gh 2.102) printed nothing on success; `--format json` shows the signer
workflow and commit if you want to see it.

## Using it

`torrenttui` opens it; a magnet link or `.torrent` path as the argument adds one
on startup, and `-d <dir>` overrides the download folder for that session. `q`
quits and stops every transfer; `Ctrl+D` detaches and leaves downloading and
seeding running in the background, `torrenttui` takes the session back and
`torrenttui --stop` ends it.
