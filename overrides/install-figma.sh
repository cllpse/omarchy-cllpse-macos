#!/bin/bash
# Install or update Figma Desktop, the one application this repo's overrides
# assume but apply.sh does not install. Idempotent: re-run any time.
#
# Installing and updating are the same operation, because the app has no
# self-updater — you replace the extracted directory and re-run apply.sh to put
# the launcher entry back. This script is that, with the parts that are easy to
# get wrong done for you:
#
#   1. resolve the installed version from the app's OWN bundled desktop entry
#   2. resolve the target version + asset from the GitHub release
#   3. refuse to extract over a RUNNING Figma
#   4. download, verify it is really an AppImage, extract to a scratch dir
#   5. gate the swap on the extracted tree actually being the app
#   6. swap the app directory, keeping the old one until the new one is in
#   7. hand off to apply.sh, which owns the launcher entry (step 7e)
#
# Upstream is IliyaBrook/figma-linux: the official Figma Desktop Windows build,
# patched for Linux and repacked as an AppImage. NOT Figma-Linux/figma-linux,
# which is a community Electron wrapper around the web app with a different
# settings schema — see CLAUDE.md. The AppStream component id is
# io.github.nickvdp.figma-desktop-linux, inherited from an earlier project of
# nickvdp's and hardcoded in the upstream build script; that id is the reason
# this repo's docs used to name a `nickvdp/figma-desktop-linux` repo, which does
# not exist. The id is real, the repo slug never was.
#
# No sudo. Nothing here is written outside $HOME.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_SLUG='IliyaBrook/figma-linux'
APP_DIR=~/Applications/figma-desktop
APPS_DIR=~/Applications
COMPONENT_ID='io.github.nickvdp.figma-desktop-linux'

say()  { printf '\033[34m▸\033[0m %s\n' "$*"; }
skip() { printf '  \033[2m– %s\033[0m\n' "$*"; }
warn() { printf '  \033[33m! %s\033[0m\n' "$*"; }
die()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: install-figma.sh [options]

  --check             Report installed vs. latest and exit. Changes nothing.
  --version X.Y.Z     Install that release instead of the latest one.
  --appimage PATH     Extract a local .AppImage instead of downloading.
  --force             Re-extract even when the installed version already matches.
  --keep-appimage     Keep the downloaded .AppImage in ~/Applications.
                      Default is to delete it — the extracted directory is what runs.
  --no-apply          Do not run apply.sh afterwards. The launcher entry then
                      keeps whatever the app writes for itself, which is wrong
                      for this desktop (Name=Figma, StartupWMClass=Figma).
  -h, --help          This.

Installing and updating are the same command:

  ./overrides/install-figma.sh
USAGE
}

MODE_CHECK=0 WANT_VERSION='' LOCAL_APPIMAGE='' FORCE=0 KEEP_APPIMAGE=0 RUN_APPLY=1
while [[ $# -gt 0 ]]; do
  case $1 in
    --check)         MODE_CHECK=1 ;;
    --version)       WANT_VERSION="${2:-}"; [[ -n $WANT_VERSION ]] || die "--version needs a value"; shift ;;
    --version=*)     WANT_VERSION="${1#*=}" ;;
    --appimage)      LOCAL_APPIMAGE="${2:-}"; [[ -n $LOCAL_APPIMAGE ]] || die "--appimage needs a path"; shift ;;
    --appimage=*)    LOCAL_APPIMAGE="${1#*=}" ;;
    --force)         FORCE=1 ;;
    --keep-appimage) KEEP_APPIMAGE=1 ;;
    --no-apply)      RUN_APPLY=0 ;;
    -h|--help)       usage; exit 0 ;;
    *)               usage >&2; die "unknown option: $1" ;;
  esac
  shift
done

[[ -n $LOCAL_APPIMAGE && -n $WANT_VERSION ]] &&
  die "--appimage and --version are mutually exclusive: the file is the version"

for tool in curl jq; do
  command -v "$tool" >/dev/null || die "$tool is required and not installed"
done

# ── Installed version ────────────────────────────────────────────────────────
# From the app's own bundled entry, not from a stamp file we keep: the entry is
# written by the upstream build and restored by every extraction, so it cannot
# drift out of step with what is actually on disk the way our own record could.
# (The entry in ~/.local/share/applications is OURS and carries no version —
# this is the one at the AppDir root, which we never touch.)
installed_version() {
  local f="$APP_DIR/$COMPONENT_ID.desktop"
  [[ -f $f ]] || return 1
  local v
  v=$(sed -n 's/^X-AppImage-Version=//p' "$f" | head -1)
  [[ -n $v ]] || return 1
  printf '%s\n' "$v"
}

INSTALLED=''
if [[ -d $APP_DIR ]]; then
  INSTALLED=$(installed_version || true)
  [[ -n $INSTALLED ]] || warn "$APP_DIR exists but carries no version — treating it as unknown"
fi

# ── Target version + download URL ────────────────────────────────────────────
# Release TAGS are inconsistent upstream (126.5.6, but figma-desktop-126.4.11
# and figma-desktop-126.3.12.1 for older ones), so a tag is not a version. The
# ASSET name is: figma-desktop-<version>-amd64.AppImage. Resolve through that.
TARGET='' ASSET_URL='' ASSET_NAME='' ASSET_SIZE=''
resolve_release() {
  local api json
  if [[ -n $WANT_VERSION ]]; then
    # Scan releases for the one whose AppImage asset carries this version,
    # rather than guessing which of the two tag spellings it used.
    json=$(curl -fsSL --max-time 30 "https://api.github.com/repos/$REPO_SLUG/releases?per_page=100") ||
      die "could not reach the GitHub API"
    api=$(jq -r --arg v "$WANT_VERSION" '
      [ .[] | .assets[]? | select(.name == "figma-desktop-\($v)-amd64.AppImage") ][0] // empty' <<<"$json")
    [[ -n $api ]] || die "no release publishes figma-desktop-$WANT_VERSION-amd64.AppImage"
    TARGET="$WANT_VERSION"
  else
    json=$(curl -fsSL --max-time 30 "https://api.github.com/repos/$REPO_SLUG/releases/latest") ||
      die "could not reach the GitHub API"
    api=$(jq -r '[ .assets[]? | select(.name | test("^figma-desktop-.*-amd64\\.AppImage$")) ][0] // empty' <<<"$json")
    [[ -n $api ]] || die "the latest release publishes no amd64 AppImage"
    ASSET_NAME=$(jq -r '.name' <<<"$api")
    TARGET=$(sed -E 's/^figma-desktop-(.*)-amd64\.AppImage$/\1/' <<<"$ASSET_NAME")
  fi
  ASSET_NAME=$(jq -r '.name' <<<"$api")
  ASSET_URL=$(jq -r '.browser_download_url' <<<"$api")
  ASSET_SIZE=$(jq -r '.size' <<<"$api")
}

if [[ -n $LOCAL_APPIMAGE ]]; then
  [[ -f $LOCAL_APPIMAGE ]] || die "no such file: $LOCAL_APPIMAGE"
  TARGET=$(sed -E 's/.*figma-desktop-(.*)-amd64\.AppImage$/\1/' <<<"$(basename "$LOCAL_APPIMAGE")")
  [[ $TARGET == "$(basename "$LOCAL_APPIMAGE")" ]] && TARGET='(local file)'
else
  say "resolving the release from $REPO_SLUG"
  resolve_release
fi

printf '  installed: %s\n' "${INSTALLED:-none}"
printf '  target:    %s\n' "$TARGET"

if (( MODE_CHECK )); then
  if [[ -z $INSTALLED ]]; then
    skip "not installed — run without --check to install $TARGET"
  elif [[ $INSTALLED == "$TARGET" ]]; then
    skip "up to date"
  elif [[ $(printf '%s\n%s\n' "$INSTALLED" "$TARGET" | sort -V | tail -1) == "$TARGET" ]]; then
    say "an update is available: $INSTALLED -> $TARGET"
  else
    warn "the installed version is NEWER than the target"
  fi
  exit 0
fi

if [[ -n $INSTALLED && $INSTALLED == "$TARGET" && $FORCE -eq 0 ]]; then
  skip "Figma Desktop $INSTALLED is already installed — nothing to extract (--force to re-extract)"
  if (( RUN_APPLY )); then
    say "re-running apply.sh anyway, so the launcher entry is known-good"
    exec "$HERE/apply.sh"
  fi
  exit 0
fi

# ── Refuse to extract over a running app ─────────────────────────────────────
# An extraction deletes the tree the running Electron process is mapping, which
# ends in a crash and a half-written profile. Resolve /proc/<pid>/exe rather
# than grepping ps: `pgrep -f` matches the caller's OWN command line (it would
# find this script, whose text contains the path), a trap this repo has already
# been bitten by once.
figma_pids() {
  local pid exe
  for pid in /proc/[0-9]*; do
    exe=$(readlink -f "$pid/exe" 2>/dev/null) || continue
    [[ $exe == "$APP_DIR"/* ]] && printf '%s\n' "${pid#/proc/}"
  done
}
mapfile -t running < <(figma_pids)
if (( ${#running[@]} )); then
  pids=$(IFS=,; printf '%s' "${running[*]}")
  die "Figma is running (pid ${pids//,/, }) — quit it first; extracting over a live app corrupts it"
fi

# ── Scratch space ────────────────────────────────────────────────────────────
mkdir -p "$APPS_DIR"

# The extracted tree runs about 4x the AppImage, and the old directory is kept
# until the new one is in place, so budget for both.
if [[ -n $ASSET_SIZE ]]; then
  need_kb=$(( ASSET_SIZE / 1024 * 6 ))
  free_kb=$(df -Pk "$APPS_DIR" 2>/dev/null | awk 'NR==2 {print $4}') || true
  if [[ -n ${free_kb:-} ]] && (( free_kb < need_kb )); then
    die "not enough free space in $APPS_DIR: need ~$(( need_kb / 1024 )) MB, have $(( free_kb / 1024 )) MB"
  fi
fi

# Scratch lives NEXT TO the destination, not in /tmp. Two reasons: /tmp is tmpfs
# on this system, so a ~500 MB extracted tree would be held in RAM; and the swap
# below is then a same-filesystem rename instead of a half-gigabyte copy across
# devices. The name is dotted and stamped so a crashed run is obvious and a
# second run cannot collide with a first.
WORK=$(mktemp -d "$APPS_DIR/.figma-install-XXXXXX")
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# ── Get the AppImage ─────────────────────────────────────────────────────────
if [[ -n $LOCAL_APPIMAGE ]]; then
  IMG="$(cd "$(dirname "$LOCAL_APPIMAGE")" && pwd)/$(basename "$LOCAL_APPIMAGE")"
  say "using $IMG"
else
  IMG="$WORK/$ASSET_NAME"
  say "downloading $ASSET_NAME ($(( ASSET_SIZE / 1024 / 1024 )) MB)"
  # --progress-bar redraws with \r, which a pipe or a log turns into one very
  # long line of hashes. Only ask for it when stderr is a terminal.
  if [[ -t 2 ]]; then
    curl -fL --progress-bar -o "$IMG" "$ASSET_URL" || die "download failed"
  else
    curl -fsSL -o "$IMG" "$ASSET_URL" || die "download failed"
  fi
  got=$(stat -c %s "$IMG")
  (( got == ASSET_SIZE )) || die "size mismatch: expected $ASSET_SIZE bytes, got $got"
fi

# An HTML error page saved under an .AppImage name extracts to nothing and the
# failure surfaces three steps later. Check the ELF magic instead.
[[ $(head -c 4 "$IMG" | od -An -tx1 | tr -d ' \n') == 7f454c46 ]] ||
  die "$IMG is not an executable AppImage (no ELF header)"

chmod +x "$IMG"

# ── Extract ──────────────────────────────────────────────────────────────────
# --appimage-extract always writes ./squashfs-root, so run it from the scratch
# dir. It needs no FUSE and no root.
say "extracting"
( cd "$WORK" && "$IMG" --appimage-extract >/dev/null ) || die "--appimage-extract failed"
NEW="$WORK/squashfs-root"
[[ -d $NEW ]] || die "extraction produced no squashfs-root"

# Gate the swap on this really being the app. `integrate_desktop` is the app's
# own launcher function and the marker apply.sh step 7e keys on; without it the
# entry step would refuse the result anyway, after the old install was gone.
[[ -x $NEW/AppRun ]] || die "the extracted tree has no executable AppRun"
grep -q 'integrate_desktop' "$NEW/AppRun" ||
  die "the extracted AppRun is not the app's own launcher — refusing to install it"

new_version=$(sed -n 's/^X-AppImage-Version=//p' "$NEW/$COMPONENT_ID.desktop" 2>/dev/null | head -1 || true)
[[ -n $new_version ]] && skip "extracted Figma Desktop $new_version"

# ── Swap ─────────────────────────────────────────────────────────────────────
# Move the old directory aside rather than deleting it first, so a failure here
# leaves a working install behind. Nothing inside the app directory belongs to
# this repo — that is a deliberate property, and it is what makes this safe.
OLD=''
if [[ -d $APP_DIR ]]; then
  OLD="$APP_DIR.replacing.$$"
  mv "$APP_DIR" "$OLD"
fi
if ! mv "$NEW" "$APP_DIR"; then
  [[ -n $OLD ]] && mv "$OLD" "$APP_DIR"
  die "could not move the new install into place — the previous one is untouched"
fi
[[ -n $OLD ]] && rm -rf "$OLD"
say "installed to $APP_DIR"

if [[ -z $LOCAL_APPIMAGE ]] && (( KEEP_APPIMAGE )); then
  mv "$IMG" "$APPS_DIR/$ASSET_NAME"
  skip "kept $APPS_DIR/$ASSET_NAME"
fi

# ── Hand off to apply.sh ─────────────────────────────────────────────────────
# Step 7e owns the launcher entry, and the app has just written its own wrong
# one on first launch (or will). Everything else apply.sh does is idempotent, so
# running the whole script is cheaper than trying to run one step of it.
first_install=0
[[ -z $INSTALLED ]] && first_install=1

if (( RUN_APPLY )); then
  say "running apply.sh — step 7e puts the launcher entry back"
  "$HERE/apply.sh"
else
  warn "skipped apply.sh: the launcher entry still says Name=Figma / StartupWMClass=Figma"
  warn "  run ./overrides/apply.sh to correct it"
fi

if (( first_install )); then
  printf '\n'
  say "first install — two things do not take effect yet:"
  skip "FIGMA_USE_WAYLAND comes from ~/.config/environment.d (apply.sh step 7c) and"
  skip "  is read at login. Until you log out, Figma runs under XWayland at 80% scale."
  if ! command -v keyd >/dev/null; then
    skip "keyd is not installed. It is what gives Figma a real Ctrl for Cmd+click and"
    skip "  Cmd+scroll: sudo pacman -S keyd, then re-run ./overrides/apply.sh."
  fi
fi
