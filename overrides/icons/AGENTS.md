# Finding and fitting icon overrides

A workflow, not a contract. [`fallbacks/README.md`](fallbacks/README.md) is the
contract — what a file must look like, and which directory it belongs in. This
file is how you find out *which* files are worth adding, and how to make a new
one sit correctly beside the ones already here.

**Ship the set as it is.** The 99 marks in `color/` and `fallbacks/` are aligned
and committed. Do not run a bulk pass over them. Everything below applies to
marks you are **adding**; a sweep that "fixes" the existing set is how `hunk`
lost its background box once already.

## Who consumes these

Three consumers, keyed three different ways. Get the key wrong and the file is
simply never found — nothing errors.

| consumer | key | example |
|---|---|---|
| Omarchy menu (app rows) | the desktop entry's `Icon=` | `co.anysphere.cursor.svg` |
| Switcher tile | the **window class** | `cursor.svg` |
| Switcher terminal badge | the **command name**, after `badgeAliases` | `hunk.svg` |

A class and an `Icon=` often differ, so an app can need two copies under two
names. Check a live window with `hyprctl clients -j | grep '"class"'`.

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
one for badges: an installed binary you never invoke does not need a mark.

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
            for p in glob.glob("overrides/icons/color/*.svg")
                   + glob.glob("overrides/icons/fallbacks/*.svg")}
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
# Builtins and coreutils never take over a terminal, so they can never be what a
# badge is for. Without this the list is mostly `cd`, `cat` and `rm`.
NOISE = set("""cd ls cat rm cp mv mkdir rmdir echo pwd touch chmod chown ln head tail
grep sed awk sort uniq wc cut tr find xargs which sudo su exit source export set unset
alias unalias history clear kill sleep watch test true false printf read time env df du
ps top man less more tee basename dirname realpath stat date seq yes""".split())
# Keep in step with badgeAliases in Hud.qml, or you will "discover" a name the
# switcher never looks up.
ALIAS = {"diff":"hunk","log":"hunk","dash":"gh","edit":"msedit","ls":"lsd",
         "claude":"claude-code","node":"nodejs","python3":"python","sqlite3":"sqlite",
         "psql":"postgresql","ytm":"youtube-music"}
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
**93 candidates, 99 overridden, 1364 vendor names, 14 missing.** A run that
reports wildly more has lost a filter.

Then use judgement. `npx`, `corepack` and `codex-code-mode-host` are shims
nobody looks at; `brew`, `pacman`, `yay` and `lsd` are worth a mark. A missing
name is a suggestion, not a task.

## 3. Choose the directory

- **`color/`** — the mark only reads in its own colours (`figma-desktop`,
  `claude-code`, `youtube-music`). Synced verbatim.
- **`fallbacks/`** — a silhouette; the theme supplies the colour. Synced
  repainted to the theme `foreground`.

One name, one directory, never both — the switcher checks the repainted index
first, so a duplicate silently wins there and the colour copy is dead.

**A monochrome mark whose only contrast comes from its own background belongs in
`fallbacks/`, not `color/`.** `hunk` is dark-on-cream: strip its box and put it
in `color/` and you get a `#16140F` glyph on a `#1E1E1E` card, contrast 1.05,
invisible. Either keep the background and stay in `color/`, or drop the
background and move to `fallbacks/`.

Conversely, a file in `fallbacks/` with a background rect is **broken**: the
repaint rewrites the rect and the mark to the same colour and it renders as a
solid block. `grok` shipped that way and nobody noticed.

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
m = re.search(r'''viewBox\s*=\s*["']([^"']+)["']''', s)   # quote-agnostic: Inkscape single-quotes
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
catches a background that reaches the canvas edge (`tldr`, `grok`: nothing
transparent, so the script refuses). It does *not* catch a background with
**rounded corners** — `hunk` gained `rx="2"` and now has transparent corners, so
it reads as 0 min-alpha. The 99%-coverage test is what stops that one: its
visible extent is still 100% x 100%, so there is nothing to tighten. Verified on
all three. Never remove one of those checks on the grounds that the other
covers it.

Apply the printed `viewBox`, **and `width`/`height` with it** — if they disagree
with the new canvas, rsvg reintroduces the original aspect and the change does
nothing. Reference points: `com.mitchellh.ghostty` fills 99% x 100%;
`figma-desktop` filled 52% x 78% before it was tightened, which is exactly how
much smaller than its neighbours it looked.

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
