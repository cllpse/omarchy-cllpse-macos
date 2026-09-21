# Figma Desktop

The one application this repo's overrides assume but `apply.sh` does not
install. Installing and updating are the same operation, because the app has no
self-updater: you replace the extracted directory and put the launcher entry
back.

```bash
./overrides/figma/figma.sh            # latest release, then apply.sh --all
./overrides/figma/figma.sh --check    # installed vs. latest; changes nothing
./overrides/apply.sh figma            # same, from the apply picker (--no-apply)
```

Opt-in in [`../apply.sh`](../apply.sh): it appears in the picker but **not** in
`--all`. It reaches the network and installs an application, which nothing else
here does — and this script ends by calling `apply.sh --all` itself, so putting
it in `--all` would recurse. The picker passes `--no-apply` for the same reason.

## What it does

1. resolve the installed version from the app's **own** bundled desktop entry
2. resolve the target version + asset from the GitHub release
3. refuse to extract over a **running** Figma
4. download, verify it is really an AppImage, extract to a scratch dir
5. gate the swap on the extracted tree actually being the app
6. swap the app directory, keeping the old one until the new one is in
7. hand off to `apply.sh`, which owns the launcher entry (step `applications`)

No sudo. Nothing is written outside `$HOME`.

## Upstream

`IliyaBrook/figma-linux` — the official Figma Desktop Windows build, patched
for Linux and repacked as an AppImage. **Not** `Figma-Linux/figma-linux`, a
community Electron wrapper around the web app with a different settings schema.

The AppStream id is `io.github.nickvdp.figma-desktop-linux`, inherited from an
earlier project of nickvdp's and hardcoded upstream. That id is why this repo's
docs once named a `nickvdp/figma-desktop-linux` repo, which does not exist —
the id is real, the slug never was.

## The argv cap

This is the only thing in the repo that writes **inside** the app directory, and
it must be reapplied on every update. `figma://` login needs the launch to stay
under 9 argv elements and `FIGMA_USE_WAYLAND=1` pushes it over
([electron/electron#52020](https://github.com/electron/electron/issues/52020)):
at 9 or more, the second instance's argv fails to parse across the singleton
socket, and it then seizes the lock and kills the first. The symptom is not a
login error — the app closes, reopens and asks you to log in again, forever.
The script comments out the two Wayland IME flags to bring the native path to 7.
Diagnose from `~/.cache/figma-desktop-linux/launcher.log`, which records every
launch's full argv.
