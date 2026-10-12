// Shared by both content scripts (each world gets its own copy): rewrites the
// resolution features of a media query as if the screen were 2x. Each feature
// is evaluated against the spoofed ratio and replaced by an always-true or
// always-false range test, so the rest of the query keeps its own meaning.
//
// Handed over on a registry symbol rather than a named global; hidpi.js, in
// the page's own world, takes it and deletes it before any page script runs.
(() => {
  "use strict";

  const TARGET = 2;
  const spoof = (real) => (real > 1 && real < TARGET ? TARGET : real);

  const TRUE = "(width >= 0px)";
  const FALSE = "(width < 0px)";
  const toDppx = (value, unit) => {
    switch ((unit || "").toLowerCase()) {
      case "dpi": return value / 96;
      case "dpcm": return (value * 2.54) / 96;
      default: return value; // dppx, x, or device-pixel-ratio's bare number
    }
  };
  const PLAIN = /\(\s*(-webkit-)?(min-|max-)?(device-pixel-ratio|resolution)\s*:\s*([\d.]+)\s*(dppx|x|dpi|dpcm)?\s*\)/gi;
  const RANGE = /\(\s*resolution\s*(>=|<=|>|<|=)\s*([\d.]+)\s*(dppx|x|dpi|dpcm)?\s*\)/gi;
  const RANGE_REVERSED = /\(\s*([\d.]+)\s*(dppx|x|dpi|dpcm)?\s*(>=|<=|>|<|=)\s*resolution\s*\)/gi;
  const FLIP = { ">=": "<=", "<=": ">=", ">": "<", "<": ">", "=": "=" };
  const compare = (dpr, op, value) =>
    op === ">=" ? dpr >= value : op === "<=" ? dpr <= value :
    op === ">" ? dpr > value : op === "<" ? dpr < value : Math.abs(dpr - value) < 1e-6;

  const rewrite = (query, real) => {
    if (!/resolution|pixel-ratio/i.test(query)) return query;
    const dpr = spoof(real);
    if (dpr === real) return query;
    return query
      .replace(PLAIN, (_, webkit, minmax, feature, num, unit) => {
        const op = minmax === "min-" ? ">=" : minmax === "max-" ? "<=" : "=";
        return compare(dpr, op, toDppx(parseFloat(num), unit)) ? TRUE : FALSE;
      })
      .replace(RANGE, (_, op, num, unit) =>
        compare(dpr, op, toDppx(parseFloat(num), unit)) ? TRUE : FALSE)
      .replace(RANGE_REVERSED, (_, num, unit, op) =>
        compare(dpr, FLIP[op], toDppx(parseFloat(num), unit)) ? TRUE : FALSE);
  };

  Object.defineProperty(globalThis, Symbol.for("cllpse-hidpi"), {
    value: { spoof, rewrite },
    configurable: true,
  });
})();
