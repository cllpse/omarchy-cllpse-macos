// Tells pages the screen is 2x, so they serve their sharp images.
//
// At monitor scale 4/3 a CSS pixel is 1.333 device pixels. Sites switch to
// their sharp image set at 1.5x and up (Google's `min-resolution: 144dpi`), so
// at 1.333 they hand over 1x images and the page stretches them by a third.
// Nothing here changes how pages render, only what they are told, so they
// fetch 2x and Chromium scales it down. See README.md.
//
// Runs in the page's own world (manifest "world": "MAIN") at document_start,
// before any page script. Replaced functions are Proxies over the natives, so
// Function.prototype.toString still reports native code: Google's sign-in bot
// checks look for patched natives.
//
// This covers page script, the stylesheets the page can read and <picture>
// sources. Stylesheets from another origin cannot be read from here; bridge.js
// and worker.js handle those. A 1x/2x srcset needs nothing: Chromium 152
// already picks 2x at 1.333 (tested headless, 2026-10-11).
(() => {
  "use strict";

  const key = Symbol.for("cllpse-hidpi");
  const shared = globalThis[key];
  delete globalThis[key];
  const desc = Object.getOwnPropertyDescriptor(window, "devicePixelRatio");
  if (!shared || !desc || !desc.get) return;
  const { spoof, rewrite } = shared;
  const realDpr = () => desc.get.call(window);

  // 1. window.devicePixelRatio
  Object.defineProperty(window, "devicePixelRatio", {
    ...desc,
    get: new Proxy(desc.get, {
      apply: (target, self, args) => spoof(Reflect.apply(target, self, args)),
    }),
  });

  // 2. matchMedia
  window.matchMedia = new Proxy(window.matchMedia, {
    apply: (target, self, args) =>
      Reflect.apply(target, self, typeof args[0] === "string" ? [rewrite(args[0], realDpr()), ...args.slice(1)] : args),
  });

  // 3. Stylesheets the page can read: inline <style>, same-origin and CORS.
  const seen = new WeakSet();
  const stats = { sheets: 0, unreadable: 0, rules: 0, sources: 0 };

  const fixMedia = (media) => {
    if (!media || !media.mediaText) return;
    const next = rewrite(media.mediaText, realDpr());
    if (next !== media.mediaText) {
      media.mediaText = next;
      stats.rules++;
    }
  };
  const fixRules = (rules) => {
    for (const rule of rules) {
      if (rule.media) fixMedia(rule.media); // @media, @import
      if (rule.styleSheet) fixSheet(rule.styleSheet); // @import
      if (rule.cssRules) fixRules(rule.cssRules); // nested @media, @supports, @layer
    }
  };
  const fixSheet = (sheet) => {
    if (seen.has(sheet)) return;
    seen.add(sheet);
    let rules;
    try {
      rules = sheet.cssRules;
    } catch {
      stats.unreadable++; // bridge.js fetches these
      return;
    }
    stats.sheets++;
    fixMedia(sheet.media); // <link media>, <style media>
    fixRules(rules);
  };

  // 4. <picture><source media>
  const fixSource = (el) => {
    const next = rewrite(el.media, realDpr());
    if (next !== el.media) {
      el.media = next;
      stats.sources++;
    }
  };

  const flush = () => {
    for (const sheet of document.styleSheets) fixSheet(sheet);
    for (const el of document.querySelectorAll("source[media]")) {
      if (!seen.has(el)) {
        seen.add(el);
        fixSource(el);
      }
    }
    document.documentElement?.setAttribute(
      "data-cllpse-hidpi",
      `sheets=${stats.sheets} unreadable=${stats.unreadable} rules=${stats.rules} sources=${stats.sources}`,
    );
  };

  // While the page loads, every DOM change is checked in a microtask, so a
  // sheet is rewritten before its first paint. After load, at most every
  // 250ms: pages like Gmail change the DOM constantly.
  let queued = false;
  const schedule = () => {
    if (queued) return;
    queued = true;
    const run = () => {
      queued = false;
      flush();
    };
    if (document.readyState === "complete") setTimeout(run, 250);
    else queueMicrotask(run);
  };
  new MutationObserver(schedule).observe(document, { childList: true, subtree: true });
  document.addEventListener("DOMContentLoaded", flush);
  window.addEventListener("load", flush);
})();
