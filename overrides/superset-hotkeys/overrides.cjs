// Sets or clears hotkey overrides in Superset's renderer localStorage.
//   node overrides.cjs <classic-level dir> <leveldb dir> <ids file> apply|revert
// Prints "<changed> <already>" on success. Exits 3 when the store is locked
// (Superset is running), 1 on anything else, with the reason on stderr.
//
// Chromium's localStorage is a leveldb: key "_file://" 00 01 "<name>", value 01
// (Latin-1) followed by the string. Superset's zustand store is the JSON under
// "hotkey-overrides", and a `null` override is what its Settings > Keyboard
// writes for Backspace: buildRegisteredAppChords skips the id, so no chord.
const fs = require("fs");
const path = require("path");

const [libDir, dbDir, idsFile, mode] = process.argv.slice(2);
const { ClassicLevel } = require(path.join(libDir, "node_modules", "classic-level"));
const KEY = Buffer.from("_file://\x00\x01hotkey-overrides", "latin1");

const ids = fs.readFileSync(idsFile, "utf8").split("\n")
  .map((l) => l.replace(/#.*/, "").trim()).filter(Boolean);

(async () => {
  const db = new ClassicLevel(dbDir, { keyEncoding: "buffer", valueEncoding: "buffer" });
  try {
    await db.open();
  } catch (e) {
    // classic-level words every open failure the same; leveldb's own text is the cause.
    const why = [e.message, e.cause && e.cause.message].filter(Boolean).join(": ");
    console.error(why);
    process.exit(/lock/i.test(why) ? 3 : 1);
  }
  let raw;
  try { raw = await db.get(KEY); } catch (e) { raw = null; }
  // 0x01 is the Latin-1 marker. UTF-16 (0x00) would mean a non-ASCII value, which
  // a map of ids to null or a chord never is; refuse rather than guess.
  if (raw && raw[0] !== 1) {
    console.error("hotkey-overrides is not Latin-1; leaving it alone");
    process.exit(1);
  }
  const cur = raw ? JSON.parse(raw.subarray(1).toString("latin1")) : { state: { overrides: {} }, version: 1 };
  const ov = (cur.state.overrides ||= {});
  let changed = 0, already = 0;
  for (const id of ids) {
    if (mode === "apply") {
      if (ov[id] === null && id in ov) already++;
      else { ov[id] = null; changed++; }
    } else if (id in ov && ov[id] === null) {
      delete ov[id]; changed++;
    } else already++;
  }
  if (changed) {
    await db.put(KEY, Buffer.concat([Buffer.from([1]), Buffer.from(JSON.stringify(cur), "latin1")]));
  }
  await db.close();
  console.log(changed, already);
})();
