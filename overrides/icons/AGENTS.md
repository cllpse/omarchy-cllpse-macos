# Finding and fitting icon overrides

A workflow, not a contract. [`icons/README.md`](icons/README.md) is the
contract — what a file must look like, and which directory it belongs in. This
file is how you find out *which* files are worth adding, and how to make a new
one sit correctly beside the ones already here.

**Ship the set as it is.** The 24 silhouettes in `icons/` and the 76 full-colour marks in `verbatim/` — and the same 100
ones in the switcher submodule — are aligned and committed. Do not run a bulk
pass over either. Everything below applies to
marks you are **adding**; a sweep that "fixes" the existing set is how `hunk`
lost its background box once already.

## Keeping the two repos in step

Both this repo and the plugin carry all 100 marks, and nothing enforces that they
match — the de-duplication that once made the plugin the single source was
deliberately undone when both were asked to be complete. So a mark added or
refitted in one silently diverges from the other. It happened the day the split
was made: seven files differed within minutes, because the plugin's copies were
fitted to the `viewBox` contract and this repo's were not.

Check before trusting either:

```bash
for f in overrides/icons/*/*.svg; do
  cmp -s "$f" "omarchy-cllpse-plugin-switcher/icons/$(basename "$f")" \
    || echo "DRIFTED: $(basename "$f")"
done
```

Silence means the two are identical. The plugin's copy is the one to fit to the
contract; copy it back here afterwards.

## Who consumes these

Three consumers, keyed three different ways. Get the key wrong and the file is
simply never found — nothing errors. The plugin ships every mark in its own
`omarchy-cllpse-plugin-switcher/icons/`, but on **this** machine the switcher
finds this directory's copies first: it reads `~/.icons/cllpse-flat/apps/`, and
its vendor sweep scans `~/.icons` — so `~/.icons/cllpse-color/apps/` — before its
own `icons/`. The example column says where each file is actually served from
here; elsewhere the last two come from the plugin's `icons/`.

| consumer | key | example (and where it lives) |
|---|---|---|
| Omarchy menu (app rows) | the desktop entry's `Icon=` | `org.gnome.DiskUtility.svg` — `icons/`, here |
| Switcher tile | the **window class**, then the `Icon=` of the desktop entry naming that class | `co.anysphere.cursor.svg` — `verbatim/` here, via `~/.icons/cllpse-color/apps/` |
| Switcher terminal icon | the **command name**, after the switcher's alias file | `hunk.svg` — `verbatim/` here, via `~/.icons/cllpse-color/apps/` |

A mark in `icons/` here also reaches the switcher, through the optional
`~/.icons/cllpse-flat/apps/` root it reads; `btop.svg` and `gh.svg` here are
what that looks like in practice.

The menu is the consumer that **only** we can serve: it draws a plain image and
cannot recolour anything, so it needs the repainted copies `app-icons.sh` writes
out of `icons/`.

**The full-colour marks are in this repository too, so a colour mark is added
twice.** `verbatim/` here holds 76 of them; the switcher submodule,
`omarchy-cllpse-plugin-switcher/icons/`, holds the same 76 among all 100 it ships
for its own tiles. `app-icons.sh` copies the one here verbatim into
`~/.icons/cllpse-color/apps/` so the menu gets the mark too — and on this machine
the switcher finds that copy before the plugin's own, so a mark refitted in the
plugin keeps its old fit in both surfaces until it is copied back here and
synced. There was a period when only the submodule had them —
`overrides/icons/color/` was deleted precisely so two copies of identical artwork
could not drift — and that de-duplication was **undone deliberately** when both
repos were asked to be complete. So the drift check above is the price, and the
two copies have to be written in the same pass. The submodule's `AGENTS.md` is
the contract for fitting one, and nothing in this directory's own silhouette
contract applies to a verbatim mark.

So this directory is two sets and only `icons/` is repainted. The switcher also
reads `~/.icons/cllpse-flat/apps/` as an optional integration, so a mark added to
`icons/` reaches both surfaces as well — but it draws every icon exactly as
authored, so nothing on that path has to care whether a mark is flat or
full-colour.

Its alias table moved too: command-to-icon mappings now live in
`icon-aliases.json` at the plugin root, not in `Hud.qml`. Adding a mark here
whose command name differs from its filename means adding the alias **there**.

A class and an `Icon=` often differ, and that costs a second copy less often
than it looks. `iconFor()` in `Hud.qml` tries the class against the drop-in
index, then follows `classIndex` — every desktop entry keyed by its
`StartupWMClass` and its file id, lowercased — to that entry's `Icon=`, and
only then tries the class against the vendor index. So a second copy named for
the class is needed only where **no** entry names the class.

**`cursor.svg` is never what the Cursor tile draws.** This table used to give it
as the class-keyed example. Verified live on 2026-10-09: the window's class is
`cursor`, nothing named `cursor` is in the drop-in index (`cllpse-flat` has no
such file, and the user root does not exist), and `cursor.desktop` carries
`StartupWMClass=Cursor` and `Icon=co.anysphere.cursor` — so `classIndex` wins
and the tile draws `~/.icons/cllpse-color/apps/co.anysphere.cursor.svg`, the
first hit for that name in the vendor sweep. `cursor.svg` (the same artwork,
its `viewBox` padded square where the other's is tight to the ink) is reached
only as a terminal process icon, for a title whose first word is `cursor`, or
on a machine with no entry naming the class.
Check a live window with `hyprctl clients -j | grep '"class"'`.

## 1. Find candidates

Three sources, and they answer different questions.

**Installed GUI apps** — every visible desktop entry's `Icon=`:

```bash
python3 - <<'PY'
import glob, re, os
for d in (os.path.expanduser("~/.local/share/applications"), "/usr/share/applications"):
    for f in sorted(glob.glob(d + "/*.desktop")):
        t = open(f, encoding="utf-8", errors="replace").read()
        g = lambda k: (re.search(r'^%s=(.*)$' % k, t, re.M) or [None, None])[1]
        if (g("NoDisplay") or "").strip().lower() == "true": continue
        if (g("Type") or "Application").strip() != "Application": continue
        icon = (g("Icon") or "").strip()
        if icon: print(icon)
PY
```

**TUIs and CLIs you actually run** — shell history, ranked. This is the useful
one for terminal icons: an installed binary you never invoke does not need a mark.

```bash
awk '{print $1}' ~/.bash_history | sort | uniq -c | sort -rn | head -40
```

**Version-managed tools** — `mise` shims are where the agent CLIs live
(`claude`, `codex`, `copilot`, `gemini`, `grok`, `crush`, `hunk`, `opencode`):

```bash
ls ~/.local/share/mise/shims
```

## 2. Find what is actually missing

A candidate is missing only when **neither** this directory **nor the installed
icon themes** already answer it. The themes cover ~1364 names on this machine,
so most candidates need nothing.

```bash
python3 - <<'PY'
import os, glob, re, subprocess, collections, shutil
HOME = os.path.expanduser("~")
override = {os.path.basename(p)[:-4]
            for p in glob.glob("omarchy-cllpse-plugin-switcher/icons/*.svg")
                   + glob.glob("overrides/icons/icons/*.svg")}
# Exactly the sweep Hud.qml's vendorScan runs, so "already covered" means the
# same thing here as it does at runtime.
sweep = r'''dirs="$HOME/.icons $HOME/.local/share/icons"; IFS=":";
for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS;
{ for ext in svg png; do for base in $dirs; do
  [ -d "$base" ] && find "$base" -path "*/apps/*" -name "*.$ext" 2>/dev/null;
  [ -d "$base" ] && find "$base" -path "*/devices/*" -name "*.$ext" 2>/dev/null;
done; find /usr/share/pixmaps -maxdepth 1 -name "*.$ext" 2>/dev/null; done; }'''
vendor = {os.path.basename(l).rsplit(".", 1)[0]
          for l in subprocess.run(["bash","-c",sweep],capture_output=True,text=True).stdout.split()}
# Builtins and coreutils never take over a terminal, so they can never be what
# a terminal icon is for. Without this the list is mostly `cd`, `cat` and `rm`.
NOISE = set("""cd ls cat rm cp mv mkdir rmdir echo pwd touch chmod chown ln head tail
grep sed awk sort uniq wc cut tr find xargs which sudo su exit source export set unset
alias unalias history clear kill sleep watch test true false printf read time env df du
ps top man less more tee basename dirname realpath stat date seq yes""".split())
# Keep in step with the switcher's icon-aliases.json, or you will "discover" a
# name it never looks up. That file is the source now; this is a copy for the
# gap analysis only.
ALIAS = {"diff":"hunk","log":"hunk","dash":"gh","edit":"msedit",
         "claude":"claude-code","node":"nodejs","python3":"python","sqlite3":"sqlite",
         "psql":"postgresql","redis-cli":"redis","ffprobe":"ffmpeg",
         "magick":"imagemagick","convert":"imagemagick",
         "brew":"homebrew","pacman":"arch-pacman",
         "ytm":"youtube-music","youtuimusic":"youtube-music",
         "π":"pi"}
cands = collections.defaultdict(set)
def add(name, src):
    if name in NOISE: return
    if not shutil.which(name): return          # drops typos and stray history words
    cands[ALIAS.get(name, name)].add(src)
for d in (HOME+"/.local/share/applications", "/usr/share/applications"):
    for f in glob.glob(d + "/*.desktop"):
        t = open(f, encoding="utf-8", errors="replace").read()
        g = lambda k: (re.search(r'^%s=(.*)$' % k, t, re.M) or [None, None])[1]
        if (g("NoDisplay") or "").strip().lower() == "true": continue
        ic = (g("Icon") or "").strip()
        if ic: cands[ic].add("app")            # an Icon= is not a PATH command
if os.path.exists(HOME + "/.bash_history"):
    for line in open(HOME + "/.bash_history", encoding="utf-8", errors="replace"):
        w = line.split()
        if w and re.match(r'^[a-z][a-z0-9._-]*$', w[0]): add(w[0], "history")
for sh in glob.glob(HOME + "/.local/share/mise/shims/*"): add(os.path.basename(sh), "mise")
missing = sorted(n for n in cands if n not in override and n not in vendor)
print("candidates %d | overridden %d | vendor %d | MISSING %d\n"
      % (len(cands), len(override), len(vendor), len(missing)))
for n in missing: print("  %-38s from: %s" % (n, ",".join(sorted(cands[n]))))
PY
```

Run from the repository root. Baseline on this machine at the time of writing:
**106 candidates, 100 overridden, 1374 vendor names, 14 missing.** A run that
reports wildly more has lost a filter.

Then use judgement. `npx`, `corepack` and `codex-code-mode-host` are shims
nobody looks at; `yay` and `lsd` are worth a mark. A missing name is a
suggestion, not a task.

**Check for a mark under another name before drawing one.** `brew` and `pacman`
sat on this list as "worth a mark" while `homebrew.svg` and `arch-pacman.svg`
were already shipping in both repos — what was missing was the alias, so nothing
ever looked those files up. The fix was two lines in `icon-aliases.json` and the
`ALIAS` copy above, not artwork. (`sudo pacman` still titles a terminal `sudo`,
and the switcher keys on the first word, so that form gets no icon either way.)

## 3. Choose the directory

Two destinations, both here. (They were in **different repositories** while
only the submodule held the colour set.) Either way the same file also goes
into `omarchy-cllpse-plugin-switcher/icons/` — see *Keeping the two repos in
step* above.

- **`icons/`, here** — a silhouette; the theme supplies the colour. Synced
  repainted to the theme `foreground`, which the switcher reads too, through
  `~/.icons/cllpse-flat/apps/`.
- **`verbatim/`, here** — the mark only reads in its own colours
  (`figma-desktop`, `claude-code`, `youtube-music`). Synced verbatim to
  `~/.icons/cllpse-color/apps/`, where the switcher finds it before its own copy.

One name, one directory, never both — the switcher checks the repainted index
first, so a duplicate silently wins there and the colour copy is dead.

**A monochrome mark whose only contrast comes from its own background belongs in
`icons/`, not with the colour set.** `hunk` is dark-on-cream: strip its box
and treat it as a colour mark and you get a `#16140F` glyph on a `#1E1E1E` card,
contrast 1.10, invisible. Either keep the background and stay with the colour
set, or drop the background and move to `icons/`.

Conversely, a file in `icons/` with a background rect is **broken**: the
repaint rewrites the rect and the mark to the same colour and it renders as a
solid block. `grok` shipped that way and nobody noticed — and then kept
shipping that way after `reference/window-switcher-notes.md` recorded it as
found and fixed: its full-canvas `<rect style="fill:#0a0a0a">` was still in
both copies on 2026-10-09. The repainted copy in `~/.icons/cllpse-flat/apps/`
was a filled square, and that is the copy the switcher finds first, so a
terminal titled `grok` wore a square badge. (The menu would draw the same
square for any entry with `Icon=grok`; none exists here.) Fixed then by
deleting the rect and tightening the `viewBox` from `0 0 163.53 163.53` to the
slash's own bounds, `38.72 34.51 86.26 94.68` — the polygon's exact extremes,
not the script's antialiased reading. Rendered through the same `sed` as
`app-icons.sh` into a scratch file to check: a slash in the foreground of both
themes, no box. A note that something was fixed is not evidence it was; render
the file.

## 4. Align the sizing

The switcher draws the image at `iconDrawn` with `PreserveAspectFit`, so a mark
padded inside its own canvas is scaled to that canvas and comes out small. There
is no compensation at draw time and there must not be — a ratio baked into the
QML is what caused the 256/200 mess both READMEs now retract. **Fix the file.**

**Measure the alpha extent, never a colour trim.** `magick -trim` trims whatever
colour the corner pixel is, so on a mark with a full-bleed background it eats
the background and reports the inner shape. Retightening to that is what once
cropped `hunk`'s box down to sit behind its own glyph.

```bash
# Measure one file: visible extent as a fraction of its canvas.
python3 - <<'PY' path/to/new-icon.svg
import re, subprocess, sys
p = sys.argv[1]
s = open(p, encoding="utf-8", errors="replace").read()
s = re.sub(r'<!--.*?-->', '', s, flags=re.S)   # a comment can quote a viewBox: pi's does
# The ROOT's viewBox, not the first in the file. Quote-agnostic: Inkscape single-quotes.
m = re.search(r'''<svg\b[^>]*?\bviewBox\s*=\s*["']([^"']+)["']''', s, re.S)
minx, miny, w, h = [float(x) for x in re.split(r'[\s,]+', m.group(1).strip())]
S = max(1.0, 800.0 / max(w, h)); W, H = round(w*S), round(h*S)
subprocess.run(["rsvg-convert","-w",str(W),"-h",str(H),p,"-o","/tmp/_i.png"], check=True)
mn = subprocess.run(["magick","/tmp/_i.png","-alpha","extract","-format","%[fx:minima]","info:"],
                    capture_output=True, text=True).stdout.strip()
if float(mn) > 0.99:
    print("FULL BLEED - nothing transparent. Leave the viewBox alone."); raise SystemExit
bb = subprocess.run(["magick","/tmp/_i.png","-alpha","extract","-format","%@","info:"],
                    capture_output=True, text=True).stdout.strip()
iw, ih, ix, iy = [float(x) for x in re.match(r'(\d+)x(\d+)\+(-?\d+)\+(-?\d+)', bb).groups()]
f = lambda v: ("%.4f" % v).rstrip("0").rstrip(".") or "0"
print("fills %.0f%% x %.0f%% of its canvas" % (iw/W*100, ih/H*100))
if max(iw/W, ih/H) < 0.99:
    print('tighten to: viewBox="%s %s %s %s"  width="%s" height="%s"'
          % (f(minx+ix/S), f(miny+iy/S), f(iw/S), f(ih/S), f(iw/S), f(ih/S)))
else:
    print("already edge-to-edge on its long axis - leave it")
PY
```

**Two guards, and a mark with a background needs both.** The full-bleed test
catches a background that reaches the canvas edge (`tldr`: nothing
transparent, so the script refuses; `grok` did too while it still carried its
rect). It does *not* catch a background with **rounded corners** — `hunk`
gained `rx="2"` and now has transparent corners, so it reads as 0 min-alpha.
The 99%-coverage test is what stops that one: its visible extent is still
100% x 100%, so there is nothing to tighten. Verified on all three. Never
remove one of those checks on the grounds that the other covers it.

The script reads the **root `<svg>` element's** `viewBox`, with comments
stripped first. It used to take the first `viewBox=` anywhere in the file, and
`pi`'s comment quotes one — so for that file it printed `34.5688 34.5688
81.8625 81.8625`, a box computed from the wrong origin and scale. On the other
99 marks the two readings agree; `pi` was the only one it got wrong.

Apply the printed `viewBox`, **and `width`/`height` with it** — if they disagree
with the new canvas, rsvg reintroduces the original aspect and the change does
nothing. Reference points: `com.mitchellh.ghostty` fills 99% x 100%;
`figma-desktop` filled 52% x 78% before it was tightened, which is exactly how
much smaller than its neighbours it looked. `pi` fills 74% x 74% and is the one
mark that is **supposed** to — inset on purpose, because a solid blocky mark
reads heavier than the thin-stroked ones beside it, and its own file carries an
XML comment saying so. A `tighten to:` line for that one is the script working,
not a finding. It reads `19.8187 19.8187 111.3625 111.3625`: the
`20 20 111 111` that comment promises, plus one rasterised pixel of
antialiasing a side (0.19 units at the 800px render).

A wide wordmark (`npm`, `bat`, `systemd`) correctly fills its long axis and stays
short. That is the logo, not padding — do not stretch it.

## 5. Verify

```bash
overrides/hooks/theme-set.d/app-icons.sh        # syncs BOTH directories
rsvg-convert -w 96 -h 96 ~/.icons/cllpse-flat/apps/<name>.svg -o /tmp/check.png
omarchy-restart-shell                           # the shell caches its icon index at launch
```

Then look at it in the strip, next to its neighbours. A file that fails to parse
is **silently skipped**, so an icon that simply does not appear is a malformed
drop-in, not a naming mistake — and a name that resolves to nothing draws
nothing, with no error either way.
