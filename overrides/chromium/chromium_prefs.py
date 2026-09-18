"""Shared plumbing for the scripts that write Chromium profile preferences.

Two settings in this repo have no command-line flag and no managed policy, so
they can only be reached by editing the profile's `Preferences` JSON:
default-zoom.py (page zoom) and system-theme.py (the GTK/system theme). Both
need the same three things, and there is no reason for two copies of any of
them:

  * the same "is Chromium running?" test, which must resolve /proc/<pid>/exe
    rather than grep a command line -- see running() below;
  * the same profile enumeration, since a machine may have more than one and
    both settings are per-profile;
  * the same atomic read/write, so an interrupted run cannot leave a truncated
    profile behind.

Imported by filename-hyphenated siblings, which cannot `import` each other, so
this module carries the underscore.
"""

import json
import os
import tempfile

CONFIG = os.path.expanduser("~/.config/chromium")
BINARY = "chromium"
LABEL = "Chromium"


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


def read(path):
    """The profile's Preferences as a dict, or None if it cannot be read.

    A missing file is an empty profile, not an error: both callers are happy to
    create the key in a profile Chromium has never written.
    """
    prefs = os.path.join(path, "Preferences")
    if not os.path.exists(prefs):
        return {}
    try:
        with open(prefs) as fh:
            return json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"  - {os.path.basename(path)}: unreadable Preferences ({exc}) "
              "— left alone")
        return None


def write(path, data):
    """Atomic replace, so an interrupted run cannot truncate a profile."""
    os.makedirs(path, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path, prefix=".cllpse-prefs-")
    try:
        with os.fdopen(fd, "w") as fh:
            json.dump(data, fh, separators=(",", ":"))
        os.chmod(tmp, 0o600)
        os.replace(tmp, os.path.join(path, "Preferences"))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise
