# font-flags

`--disable-font-subpixel-positioning` for every Chromium-based app except
Chromium itself, so the SF autohint drop-in ([`../fontconfig/`](../fontconfig/README.md))
reaches their text.

Above a device scale of 1, Chromium turns on subpixel positioning and sets
hinting to none (`ui/gfx/font_render_params_linux.cc`). Every one of these apps
runs above 1 here: the Electron apps take the GTK text factor (1.5625 at text
size 18), and Chrome takes it too. The flag stops that, so fontconfig's
`hintslight` and `autohint` apply again. The browser process computes the
result and hands it to the page renderers through their preferences
(`renderer_preferences_util.cc`), so it only has to be on the browser's command
line, which is where each launcher puts it. In the UI, glyphs then sit on whole
pixels. In web content, Blink keeps subpixel x positions at any hinting short
of full and hints slightly, vertically only (`web_font_render_style.cc`).

| File | Read by | Apps |
|---|---|---|
| `~/.config/chrome-flags.conf` | `/usr/bin/google-chrome-stable` | Google Chrome (Omarchy's stock file, with our block after it) |
| `~/.config/code-flags.conf` | `/usr/bin/code` | VS Code |
| `~/.config/claude-desktop-flags.conf` | `/usr/bin/claude-desktop` | Claude |
| `~/.config/t3code-flags.conf` | `/usr/bin/t3code` | T3 Code |
| `~/.config/electron-flags.conf` | `/usr/bin/electron42`, `electron43` | Cursor, Obsidian |

The Electron wrappers fall back to `electron-flags.conf` only when no
per-version `electronNN-flags.conf` exists; the script says so if one appears.
Chromium's copy of the flag lives in [`../chromium/chromium-flags.conf`](../chromium/chromium-flags.conf),
and Figma's goes into its launcher library from [`../figma/figma.sh`](../figma/figma.sh),
because AppRun reads no flags file.

Each launcher skips `#` lines, so the fence markers and comments are inert.
Some pass each line through as one argument, so the flag has a line to itself.
Takes effect when an app next starts.

## From the step table

Chrome + Electron apps: fontconfig's hinting back (subpixel positioning off)

Script: [`font-flags.sh`](font-flags.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
