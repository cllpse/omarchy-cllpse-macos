// Fetches stylesheets a page cannot read, for bridge.js. Only this
// extension's own content scripts can message it, and only text/css comes
// back: the same bytes the page's <link> already applied.
chrome.runtime.onMessage.addListener((message, sender, reply) => {
  if (message?.type === "fetch-css" && /^https?:/.test(message.href)) {
    // As the page's <link> did: with credentials, from the HTTP cache when it
    // can be.
    fetch(message.href, { credentials: "include", cache: "force-cache" })
      .then((response) =>
        response.ok && /css/i.test(response.headers.get("content-type") || "") ? response.text() : "")
      .then((text) => reply({ text }), () => reply({ text: "" }));
    return true; // reply is async
  }
  return false;
});
