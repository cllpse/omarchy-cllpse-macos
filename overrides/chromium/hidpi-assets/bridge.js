// Stylesheets from another origin, which a page cannot read (no CORS). Runs in
// the extension's isolated world: worker.js fetches the CSS with the
// extension's host permission, this parses it, keeps only the @media blocks
// whose resolution conditions change at 2x (conditions rewritten, relative
// url()s made absolute), and inserts them as a <style> right after the <link>
// they came from -- the cascade position they have on a real 2x screen, so
// they beat the sheet's own 1x rules and lose to later sheets, as there.
// insertCSS was tried first: Chromium cascades injected sheets BEFORE the
// page's, so the 2x rules lost to the 1x ones (tested 2026-10-11). A <style>
// inserted from an isolated world is checked against the extension's CSP, not
// the page's, so pages that forbid inline styles still take it.
(() => {
  "use strict";

  const { rewrite } = globalThis[Symbol.for("cllpse-hidpi")] || {};
  if (!rewrite || !(window.devicePixelRatio > 1 && window.devicePixelRatio < 2)) return;

  const done = new Set();
  const stats = { fetched: 0, injected: 0, failed: 0 };
  const report = () =>
    document.documentElement?.setAttribute(
      "data-cllpse-hidpi-bridge",
      `fetched=${stats.fetched} injected=${stats.injected} failed=${stats.failed}`,
    );

  const extract = (text, href) => {
    const sheet = new CSSStyleSheet();
    try {
      sheet.replaceSync(text); // @import is ignored here
    } catch {
      return "";
    }
    const real = window.devicePixelRatio;
    const walk = (rules) => {
      let out = "";
      for (const rule of rules) {
        if (rule instanceof CSSMediaRule) {
          const text = rule.media.mediaText;
          const next = rewrite(text, real);
          if (next !== text) {
            out += `@media ${next}{${Array.from(rule.cssRules, (r) => r.cssText).join("")}}`;
          } else {
            const inner = walk(rule.cssRules);
            if (inner) out += `@media ${text}{${inner}}`;
          }
        } else if (rule instanceof CSSSupportsRule) {
          const inner = walk(rule.cssRules);
          if (inner) out += `@supports ${rule.conditionText}{${inner}}`;
        }
      }
      return out;
    };
    return walk(sheet.cssRules).replace(
      /url\(\s*(['"]?)([^'")]+)\1\s*\)/g,
      (match, quote, url) => {
        try {
          return `url("${new URL(url, href).href}")`;
        } catch {
          return match;
        }
      },
    );
  };

  const handle = async (link) => {
    const href = link.href;
    if (!/^https?:/.test(href) || done.has(href)) return;
    try {
      if (link.sheet && link.sheet.cssRules) return; // readable: hidpi.js has it
    } catch {
      // unreadable: ours
    }
    done.add(href);
    try {
      const reply = await chrome.runtime.sendMessage({ type: "fetch-css", href });
      stats.fetched++;
      if (reply?.text && /resolution|pixel-ratio/i.test(reply.text)) {
        const css = extract(reply.text, href);
        if (css && link.isConnected) {
          const style = document.createElement("style");
          style.dataset.cllpseHidpiFor = href;
          style.textContent = css;
          link.after(style);
          stats.injected++;
        }
      }
    } catch {
      stats.failed++;
    }
    report();
  };

  const scan = () => {
    report();
    for (const link of document.querySelectorAll('link[rel~="stylesheet"][href]')) {
      if (link.sheet) handle(link);
      else link.addEventListener("load", () => handle(link), { once: true });
    }
  };

  let queued = false;
  new MutationObserver(() => {
    if (queued) return;
    queued = true;
    setTimeout(() => {
      queued = false;
      scan();
    }, document.readyState === "complete" ? 250 : 0);
  }).observe(document, { childList: true, subtree: true });
  document.addEventListener("DOMContentLoaded", scan);
})();
