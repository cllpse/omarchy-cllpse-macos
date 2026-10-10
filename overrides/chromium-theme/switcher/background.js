// Enable the cllpse-macos theme that managed policy names, so Chromium applies
// it WITHOUT the "Installed theme" bar. See ../README.md §7.5.
//
// Both themes are installed by policy as normal_installed and never change
// kind, so a switch never reinstalls them. Chromium applies a theme when it is
// enabled, with suppress_infobar set (a fresh install is what raises the bar),
// and disables the theme it replaces. This extension is force-installed, which
// lets it enable and disable other extensions (AdminPolicyIsModifiable).
//
// The root-owned writer sets {mode, light, dark} through the policy's
// "3rdparty" section; a policy refresh fires storage.onChanged ("managed").

async function apply() {
  const { mode, light, dark } = await chrome.storage.managed.get(["mode", "light", "dark"]);
  if ((mode !== "light" && mode !== "dark") || !light || !dark) return;
  const target = mode === "dark" ? dark : light;
  const other = mode === "dark" ? light : dark;

  let t, o;
  try {
    t = await chrome.management.get(target);
    o = await chrome.management.get(other);
  } catch {
    return; // not installed yet; management.onInstalled brings us back
  }

  if (!t.enabled) {
    // The normal switch: enabling applies it and disables the other.
    await chrome.management.setEnabled(target, true);
  } else if (o.enabled) {
    // Both enabled (right after both were installed): which one is applied is
    // whichever installed last. Re-enable the target to make it the one.
    await chrome.management.setEnabled(other, false);
    await chrome.management.setEnabled(target, false);
    await chrome.management.setEnabled(target, true);
  }
  // Target enabled and other disabled: the target is the applied theme already.
}

chrome.runtime.onStartup.addListener(apply);
chrome.runtime.onInstalled.addListener(apply);
chrome.storage.onChanged.addListener((_changes, area) => {
  if (area === "managed") apply();
});
chrome.management.onInstalled.addListener((info) => {
  if (info.type === "theme") setTimeout(apply, 1000);
});
