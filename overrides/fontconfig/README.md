# fontconfig

Two drop-ins: point the UI font at SF Pro, and force hinting off. The GTK/GNOME and Ghostty sides of hinting are separate knobs, set in apply.sh step 5 and ghostty/.

The script is [`fontconfig.sh`](fontconfig.sh). It is runnable on its own and is also
called by [`../apply.sh`](../apply.sh), which owns the order. Numbered
sections below match the `# See README.md (n)` pointers in that script.
