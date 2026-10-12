# HiDPI assets (shelved trial)

An unpacked Chromium extension that tells pages the screen is 2×, so they
serve their sharp images, without rendering anything bigger. **Nothing loads
it:** `apply.sh` never references this folder. It was tried on 2026-10-11 with a
`--load-extension` line in the live `~/.config/chromium-flags.conf` and shelved
the same day for approach A (Chromium drawing at 2× and Hyprland scaling it
down), under which pages genuinely see a ratio of 2 with no extension.

## The problem

At monitor scale 4/3 a CSS pixel is 1.333 device pixels. Sites switch to their
sharp image set at 1.5× and up (Google's `min-resolution: 144dpi`), so at 1.333
they hand over 1× images and the page stretches them by a third: Gmail's icons
are the visible case. No flag, policy or setting reports one ratio to pages
and draws with another: `--force-device-scale-factor`, page zoom and DevTools'
DPR emulation all scale the drawing too.

## What it does

Two content scripts in every page and frame, at `document_start`:

- **In the page's own world** (`rewrite.js` + `hidpi.js`):
  - `devicePixelRatio` reports 2 whenever the real value is between 1 and 2;
  - `matchMedia` and the `@media` rules of every stylesheet the page can read
    get their resolution conditions rewritten as if the screen were 2×;
  - so do `<picture>` sources.
  The replaced functions are Proxies over the natives, so
  `Function.prototype.toString` still reports native code (Google's sign-in
  checks look for patched natives).
- **In the extension's isolated world** (`rewrite-isolated.js` + `bridge.js`,
  with `worker.js`): stylesheets from another origin, which the page cannot
  read. `worker.js` fetches them with the extension's host permission;
  `bridge.js` keeps only the `@media` blocks whose conditions change at 2× and
  inserts them as a `<style>` right after their `<link>`, the cascade position
  they would have on a real 2× screen. `insertCSS` was tried first, but
  Chromium cascades injected sheets before the page's, so the 2× rules lost.

`rewrite-isolated.js` is a symlink to `rewrite.js`: each world needs its own
copy of the shared rewriter.

## What was verified

In a headless Chromium 152 at a pixel ratio of 1.333:
- pages see `devicePixelRatio` 2 and `matchMedia` agrees;
- inline, same-origin and cross-origin stylesheets all switch, in every syntax
  of the condition, and a later stylesheet still wins;
- it works on a page whose CSP forbids inline styles.

A 1x/2x `srcset` needs none of this: Chromium 152 already picks 2x at 1.333.
The cost was 15–25 ms once per load on a 20,000-rule page, then at most four
checks a second while the DOM changes. Each page reports what it did in the
`data-cllpse-hidpi` and `data-cllpse-hidpi-bridge` attributes on `<html>`.

## Why it was shelved

It changes what pages are told, not how Chromium draws, and that leaves gaps.
`image-set()` in CSS is resolved by the engine from the real ratio, which no
script can reach. A page that sizes a canvas from `devicePixelRatio` now
allocates for 2× on a 1.333 screen. And spoofing natives is what bot checks
look for. Approach A makes the ratio real instead.

## Loading it again

Only the last `--load-extension` in the flags file counts, so the line must
repeat Omarchy's own extension list and append this folder's absolute path.
Restart Chromium afterwards.
