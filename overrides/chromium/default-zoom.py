#!/usr/bin/env python3
"""Set Chromium's default page zoom for every site.

There is no command-line flag for this. Checked against the shipped binary on
4.0.2 / Chromium 151: the only zoom-related switches are pinch-zoom, camera
pan-tilt-zoom and lens internals, and the only zoom policies are AllowUserZoom
(Android WebView) and the StandardizedBrowserZoom trio -- none of which set a
default. `--force-device-scale-factor` is a different knob: it changes the
device pixel ratio, so it scales the browser UI along with the page and alters
the resolution glyphs are rasterised at. Page zoom leaves both alone.

The real setting is a profile preference, `partition.default_zoom_level`, and
Chromium stores it as a LOG, not a factor:

    zoom_level = ln(zoom_factor) / ln(1.2)

so 80% is -1.223901 and 110% is 0.522759. Verified end to end: a throwaway
profile carrying -1.223901 renders the same page's text 460px wide against
575px unzoomed, a ratio of exactly 0.800.

Two things worth knowing before running this:

  * Chromium rewrites Preferences from memory when it exits, so a write made
    while it is running is silently discarded. This script refuses to write in
    that case rather than reporting a change that will not survive.
  * Per-host entries in `partition.per_host_zoom_levels` take precedence over
    this default -- anything zoomed with ctrl+/- on a specific site keeps its
    own level. Those are deliberate user choices, so this leaves them alone and
    just reports how many exist.

Usage:  default-zoom.py [PERCENT]   set the default zoom (default 110)
        default-zoom.py --print     print the current default as a percent, or
                                    nothing if none is set (apply.sh records it)
        default-zoom.py --reset     delete the key, so Chromium's own default
                                    applies again (revert.sh's fallback)
"""

import json
import math
import os
import sys
import tempfile

CONFIG = os.path.expanduser("~/.config/chromium")
BINARY = "chromium"
LABEL = "Chromium"
# Chromium's default storage partition id. Confirmed against the live profile,
# whose per_host_zoom_levels sit under the same key.
PARTITION = "x"


def running():
    """True if a live process actually IS the browser binary (BINARY).

    Deliberately not `pgrep -f /usr/lib/chromium/chromium`: -f matches whole
    command lines, so anything merely *mentioning* the path counts as a hit --
    a wrapper invoking this script, an editor, a grep, the shell running it.
    That bug refused every write here while Chromium was closed, and it fails
    in the silent direction: the caller is told the setting was skipped for a
    good reason. Resolving /proc/<pid>/exe matches the binary and nothing else.
    """
    for entry in os.scandir("/proc"):
        if not entry.name.isdigit():
            continue
        try:
            exe = os.readlink(os.path.join("/proc", entry.name, "exe"))
        except OSError:
            continue  # exited between listing and reading, or not ours
        if os.path.basename(exe) == BINARY:
            return True
    return False


def profiles():
    """Every existing profile directory, or Default if Chromium never ran."""
    found = []
    if os.path.isdir(CONFIG):
        for name in sorted(os.listdir(CONFIG)):
            path = os.path.join(CONFIG, name)
            if name == "Default" or name.startswith("Profile "):
                if os.path.isdir(path):
                    found.append(path)
    return found or [os.path.join(CONFIG, "Default")]


def apply(path, level, percent):
    name = os.path.basename(path)
    prefs = os.path.join(path, "Preferences")

    data = {}
    if os.path.exists(prefs):
        try:
            with open(prefs) as fh:
                data = json.load(fh)
        except (OSError, ValueError) as exc:
            print(f"  - {name}: unreadable Preferences ({exc}) — left alone")
            return False

    partition = data.setdefault("partition", {})
    current = partition.get("default_zoom_level", {}).get(PARTITION)

    if level is None:
        # Reset: DELETE the key rather than writing 0.0. The two are equivalent
        # to Chromium today, but only the deletion hands the setting back to
        # whatever Chromium's own default happens to be, instead of this script
        # asserting a number it has no opinion about -- the same reasoning
        # revert.sh applies to the generated fonts.conf.
        if current is None:
            print(f"  - {name}: no default zoom set")
            return False
        partition.get("default_zoom_level", {}).pop(PARTITION, None)
    else:
        if current is not None and abs(current - level) < 1e-6:
            print(f"  - {name}: already {percent}%")
            return False
        partition.setdefault("default_zoom_level", {})[PARTITION] = level

    # Atomic replace, so an interrupted run cannot leave a truncated profile.
    os.makedirs(path, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path, prefix=".default-zoom-")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(data, fh, separators=(",", ":"))
        os.chmod(tmp, 0o600)
        os.replace(tmp, prefs)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise

    per_host = partition.get("per_host_zoom_levels", {}).get(PARTITION, {})
    note = f"  ({len(per_host)} per-site zoom(s) still override it)" if per_host else ""
    if level is None:
        print(f"  • {name}: default zoom cleared ({LABEL}'s own default applies)")
    else:
        print(f"  • {name}: default zoom -> {percent}%{note}")
    return True


def read_percent():
    """The first profile's current default zoom as a percent string, or ''.

    Nothing is printed but the number: apply.sh captures this in a command
    substitution to record what the machine had before its first apply, the
    same way it records the pre-existing font and theme. An unset default, an
    unreadable profile or a missing config directory all come back empty, and
    record_prior treats empty as "nothing to record".
    """
    for path in profiles():
        prefs = os.path.join(path, "Preferences")
        try:
            with open(prefs) as fh:
                data = json.load(fh)
        except (OSError, ValueError):
            continue
        level = data.get("partition", {}).get("default_zoom_level", {}).get(PARTITION)
        if level is None:
            continue
        return "%g" % round(100.0 * (1.2 ** level), 4)
    return ""


def main():
    # apply.sh pipes CLLPSE_CHROMIUM_ZOOM straight through, so a typo arrives
    # here as an argument. Fail with a sentence, not a traceback.
    raw = sys.argv[1].strip() if len(sys.argv) > 1 and sys.argv[1].strip() else "110"

    # `--print` reports, `--reset` un-sets. Both exist so revert.sh can undo
    # this step without inventing a zoom of its own: record the prior value at
    # first apply, put it back on revert, and with nothing recorded just clear
    # the key so Chromium's own default applies.
    if raw == "--print":
        out = read_percent()
        if out:
            print(out)
        return 0

    percent, level = None, None
    if raw != "--reset":
        try:
            percent = float(raw.rstrip("%"))
        except ValueError:
            sys.exit(f"zoom {raw!r} is not a number")
        if not 25 <= percent <= 500:
            sys.exit(f"zoom {percent}% is outside {LABEL}'s 25-500% range")
        level = math.log(percent / 100.0) / math.log(1.2)

    if running():
        print(f"  - {LABEL} is running; it would overwrite Preferences on exit "
              "— quit it and re-run")
        return 0

    # A list, NOT a generator: any() short-circuits on the first True, which
    # over a genexp would leave every profile after the first one unwritten.
    changed = any([apply(p, level, percent) for p in profiles()])
    if changed:
        print(f"    (applies to {LABEL} windows opened from now on)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
