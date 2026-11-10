# Superset shortcuts

Superset (Paradev), the agent workspace app, ships 85 keyboard shortcuts. This
step unassigns 75 of them, listed in [`unbound.txt`](unbound.txt) with each
one's title and default Linux chord. Ten stay bound: Clear Terminal, Close Pane,
Close Tab, Find in Chat, Find in Terminal, Open Command Palette, Reopen Closed
Tab, Toggle Workspaces Sidebar, Undo and Reset Zoom.

`superset-hotkeys.sh` writes the list into the app's own override store. It is
the same thing Settings ▸ Keyboard does when a row is selected and Backspace is
pressed, so the rows read "Unassigned" there and can be rebound by hand.

## How it works

Read from the bundle (`resources/app.asar`, source maps included), 2.0.0, on
2026-10-30:

- The registry is `HOTKEYS_REGISTRY` in `src/renderer/hotkeys/registry.ts`
  (`dist/renderer/assets/useRecordHotkeys-*.js`): id, label, category,
  description and one chord per platform. This machine reads the `linux` column,
  `Ctrl`-based. Four ids (Focus Pane Left/Right/Up/Down) have no Linux chord.
- Overrides are a zustand store persisted as `hotkey-overrides` in the
  renderer's localStorage: `{"state":{"overrides":{ID: binding|null}},"version":1}`.
  `buildRegisteredAppChords` skips an id whose override is `null`, so nothing is
  registered for it. `getHotkeyConflict` also treats it as free.
- Chromium keeps localStorage as a leveldb in
  `~/.config/Superset/Partitions/superset/Local Storage/leveldb`. The key is
  `_file://` 00 01 `hotkey-overrides`; the value is 01 (Latin-1) plus the JSON.
  `overrides.cjs` reads that JSON, sets or deletes our ids and puts it back,
  leaving every other override (a shortcut rebound by hand) as it was.

## Why it needs Superset closed

The renderer holds the store's lock for as long as the app runs, and writes its
own copy back on exit, so a change made under it is lost or corrupts the store.
`overrides.cjs` opens the leveldb first and exits 3 on the lock; the script then
skips and says "quit it, then run `overrides/apply.sh superset-hotkeys`". The
check is the lock, not `pgrep`: the pty daemon and host service keep the process
name `superset` after the window is gone.

Quit it, apply, start it again:

```bash
overrides/apply.sh superset-hotkeys
```

The writer needs a native leveldb binding, `classic-level`, which the script
installs once into `~/.cache/cllpse-macos/superset-hotkeys/` with `npm`.

## Idempotent and reversible

- A run prints `N shortcuts unassigned (M already were)`. Nothing is written when
  `N` is 0.
- `superset-hotkeys.sh --revert`, which `revert.sh` runs, deletes our ids from the
  store so the defaults return. Another override on the same id is removed too:
  this step owns every id in `unbound.txt`.
- Adding or dropping a line in `unbound.txt` and re-running is the whole edit.
  Dropping one does not rebind it; run `--revert` first, or rebind it in Settings.

## Probe

With Superset closed:

```bash
cd ~/.cache/cllpse-macos/superset-hotkeys && node -e '
const {ClassicLevel}=require("classic-level");(async()=>{
const db=new ClassicLevel(process.env.HOME+"/.config/Superset/Partitions/superset/Local Storage/leveldb",{keyEncoding:"buffer",valueEncoding:"buffer"});
await db.open();const v=await db.get(Buffer.from("_file://\x00\x01hotkey-overrides","latin1"));
console.log(v.subarray(1).toString("latin1"));await db.close()})()'
```

An app update that renames a shortcut id leaves the old one in the store, where
it does nothing. A new id comes back bound; add it to `unbound.txt`.
