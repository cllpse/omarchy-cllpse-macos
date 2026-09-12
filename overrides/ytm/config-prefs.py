#!/usr/bin/env python3
"""Set ytm-player's non-colour preferences in ~/.config/ytm-player/config.toml.

The colours are a theme concern and live in themed/ytm-player.toml.tpl, pushed
by the theme-set hook. Everything here is a *preference* -- it does not change
with the Omarchy theme -- so apply.sh writes it once instead.

Three things about this file are worth knowing before editing the table below.

  * ytm rewrites config.toml WHOLE from its in-memory model. `Settings.save()`
    (config/settings.py) walks SECTION_MAP and emits every field of every
    section, so the file always carries all 58 keys and never carries a
    comment -- there is no point putting one there, it does not survive.
    Saving is not an on-exit thing, though: only two actions reach it (the
    "set current theme as default" command, and Browse's region picker), so
    this is nowhere near as hostile as Chromium's Preferences or Cursor's
    settings.json. A write made while ytm is open is kept; it just does not
    take effect until the next launch, because settings are read once at start.
  * ytm's loader is per-key and type-checked (`Settings.load`): a key we omit
    falls back to the dataclass default, and a key with the wrong *type* is
    logged and ignored rather than failing the launch. So a partial file is
    fine, which is why this script can create one before ytm has ever run.
  * An out-of-range value is not an error either. `startup_page` is validated
    against PAGE_NAMES at navigation time (app/_app.py:830) and silently falls
    back to "library" -- so a typo here looks exactly like the setting having
    no effect. The valid names are in app/_navigation.py:23: library, search,
    context, browse, queue, help, liked_songs, recently_played.

Usage:  config-prefs.py [PATH]     default ~/.config/ytm-player/config.toml
"""

import os
import re
import sys
import tempfile

DEFAULT_PATH = os.path.expanduser("~/.config/ytm-player/config.toml")

# (section, key, TOML literal). Anything not listed is left at whatever ytm or
# the user last wrote -- [ui] theme especially, which the theme-set hook owns.
PREFS = [
    # Open on Liked Songs rather than the Library landing page.
    ("general", "startup_page", '"liked_songs"'),
    # The playback bar (track info + playhead) docked along the bottom edge.
    # Inert as of 2.1.0 -- grep finds this key defined in config/settings.py
    # and read nowhere, the position coming from PlaybackBar's own
    # `dock: bottom` CSS instead -- but it is the only place the intent can be
    # written down, and ytm emits the key on every save regardless.
    ("general", "playback_bar_position", '"bottom"'),
    # No update check on launch: the package comes from the AUR, so a nag
    # pointing at a release we cannot install from here is pure noise.
    ("general", "check_for_updates", "false"),
    # Search suggestions as you type -- a dropdown over the results list.
    ("search", "predictive", "false"),
    # ── Clutter ──────────────────────────────────────────────────────────
    # Album art is a 10x3 cell of colour-quantised blocks in the corner of the
    # playback bar; at this size it reads as noise, and dropping it gives the
    # track title the full width.
    ("ui", "album_art", "false"),
    # THE PLAYHEAD. "block" fills the elapsed part with solid blocks (U+2588)
    # against light-shade blocks (U+2591) for the rest; "line" is a thin rule
    # with a round head at the current position. Both sit on the playback
    # bar's bottom row, both seek on click, and both show a heavy bar marker
    # while scroll-seeking -- the difference is only the resting weight.
    ("ui", "progress_style", '"block"'),
    # Kept ON, even though the line it draws is clutter by itself: turning it
    # off takes the PLAYBACK BAR AND THE FOOTER with it. `#bottom-stack`
    # (app/_app.py:173) is `height: auto`, and the selection-info bar is its
    # only child that is not `dock: bottom` -- docked children contribute
    # nothing to an auto height -- so `bar.display = False` (app/_app.py:838)
    # collapses the whole stack to zero and clips both of the widgets that
    # were actually wanted. Measured in a headless Textual app with this exact
    # structure: with it, rows 7-11 carry the info line, the bar and the
    # footer; without it, rows 7-11 are blank. There is no way to drop the one
    # line and keep the bar -- ytm loads no user stylesheet.
    ("ui", "show_selection_info", "true"),
    # "from <playlist>" appended to every queue row -- almost always the same
    # playlist repeated down the whole queue.
    ("ui", "show_queue_source", "false"),
    # Desktop notifications on track change. MPRIS stays on, so the bar's
    # media widget and playerctl still see everything.
    ("notifications", "enabled", "false"),
]


def running():
    """The pid of a live ytm, or None.

    ytm writes ~/.config/ytm-player/ytm.pid at start and removes it on
    unmount, but a crash leaves it behind -- so the file alone is not the
    test. Checking /proc is (and is cheaper than the pgrep -f this repo has
    been bitten by, which matches the caller's own command line).
    """
    try:
        with open(os.path.join(os.path.dirname(DEFAULT_PATH), "ytm.pid")) as fh:
            pid = int(fh.read().strip())
    except (OSError, ValueError):
        return None
    return pid if os.path.isdir(f"/proc/{pid}") else None


def set_key(text, section, key, value):
    """Return (text, changed) with section.key set to value.

    Insert-or-replace against the existing text rather than a parse-and-dump,
    so every key we have no opinion about keeps its place and its spelling.
    """
    line = f"{key} = {value}"
    header = re.search(rf"^\[{re.escape(section)}\]\s*$", text, re.M)

    if not header:
        block = f"[{section}]\n{line}\n"
        if not text.strip():
            return block, True
        return f"{text.rstrip(chr(10))}\n\n{block}", True

    start = header.end()
    nxt = re.search(r"^\[", text[start:], re.M)
    end = start + (nxt.start() if nxt else len(text) - start)
    body = text[start:end]

    existing = re.search(rf"^[ \t]*{re.escape(key)}[ \t]*=.*$", body, re.M)
    if existing:
        if existing.group(0).strip() == line:
            return text, False
        body = body[: existing.start()] + line + body[existing.end():]
    else:
        # Append after the section's last content line, keeping whatever blank
        # line separates it from the next header -- so a file built from
        # nothing reads in the order this table declares.
        tail = re.search(r"\n*\Z", body)
        body = body[: tail.start()] + "\n" + line + tail.group(0)

    return text[:start] + body + text[end:], True


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PATH

    try:
        text = open(path, encoding="utf-8").read()
    except FileNotFoundError:
        text = ""  # ytm has never run; a partial file is a valid one
    except OSError as exc:
        print(f"  - {path} is unreadable ({exc}) — left alone")
        return 0

    original = text
    changed = []
    for section, key, value in PREFS:
        text, did = set_key(text, section, key, value)
        if did:
            changed.append(f"{section}.{key} = {value}")

    if text == original:
        print("  - ytm-player preferences already set")
        return 0

    # Preserve the mode ytm gave it (0600 -- config.toml sits beside auth.json
    # and gets the same secure_chmod), and replace atomically.
    mode = os.stat(path).st_mode & 0o777 if os.path.exists(path) else 0o600
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".config-prefs-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise

    for entry in changed:
        print(f"  • {entry}")
    if running():
        print("    (ytm is running; settings are read at launch — restart it to see these)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
