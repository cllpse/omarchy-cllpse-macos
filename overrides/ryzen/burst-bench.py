#!/usr/bin/env python3
"""Time short all-core bursts at several burst (PPT fast) limits.

  burst-bench.py                        50/54/58/62W x ~1/3/10s bursts x 5 rounds, ~25 min
  burst-bench.py --limits 54,58 --rounds 3
  burst-bench.py --summarize FILE.csv   re-print the table from a finished run

See README.md (3) in this directory for what this measures and why. Needs sudo
for ryzenadj, holds Omarchy's idle off while it runs, and puts both back --
the limits by restarting ryzen-tdp.service -- on exit, Ctrl-C included.
"""
import argparse
import csv
import json
import os
import random
import shutil
import statistics
import struct
import subprocess
import sys
import threading
import time
from collections import deque
from pathlib import Path

PM_TABLE = "/sys/kernel/ryzen_smu_drv/pm_table"
ENV_FILE = "/etc/default/ryzen-tdp"
OUT_DIR = Path.home() / ".local/share/burst-bench"
CAL_OPS = 24000  # ~2s of all-core matrixprod on this chip
COLUMNS = ["round", "size_s", "ops", "fast_w", "ref_w", "smu_fast_w", "seconds",
           "start_tctl", "peak_tctl", "mean_w", "peak_w", "mean_mhz",
           "stapm_start_w", "slow_start_w", "waited_s", "cooled"]


def die(msg):
    sys.exit(f"burst-bench: {msg}")


def read(path):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return ""


# STAPM limit, STAPM value, PPT fast limit, PPT fast value, PPT slow limit,
# PPT slow value -- the same six floats ryzen.sh reads back.
def pm():
    with open(PM_TABLE, "rb") as f:
        return struct.unpack("<6f", f.read(24))


# hwmon numbers move between boots, so sensors are found by driver name.
def hwmon(name):
    for h in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
        if read(h / "name") == name:
            return h
    die(f"no {name} hwmon")


def gate():
    # The same machine guard as ryzen.sh: this writes burst limits up to 62W,
    # which is a thermal decision for one chassis, not a general setting.
    cpu = next((l for l in open("/proc/cpuinfo") if l.startswith("model name")), "")
    if ("8745HS" not in cpu or read("/sys/class/dmi/id/sys_vendor") != "GEEKOM"
            or read("/sys/class/dmi/id/product_name") != "A8"):
        die("tuned for a Ryzen 7 8745HS in a Geekom A8, refusing to run here")
    for tool in ("ryzenadj", "stress-ng"):
        if not shutil.which(tool):
            die(f"{tool} missing")
    if not os.access(PM_TABLE, os.R_OK):
        die("ryzen_smu not loaded -- nothing to verify the limits against")


TCTL = None
FREQS = sorted(Path("/sys/devices/system/cpu").glob("cpu[0-9]*/cpufreq/scaling_cur_freq"))


def tctl():
    return int(read(TCTL / "temp1_input")) / 1000


def mhz():
    return sum(int(read(p)) for p in FREQS) / len(FREQS) / 1000


def configured_fast():
    for arg in read(ENV_FILE).split():
        if arg.startswith("--fast-limit="):
            return round(int(arg.split("=")[1].strip('"')) / 1000)
    return round(pm()[2])


def set_fast(watts):
    if abs(pm()[2] - watts) >= 0.5:
        subprocess.run(["sudo", "-n", "ryzenadj", f"--fast-limit={watts * 1000}"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.5)
    return pm()[2]


def idle_enabled():
    try:
        out = subprocess.run(["omarchy-shell", "idle", "status"],
                             capture_output=True, text=True, timeout=5).stdout
        return json.loads(out).get("enabled")
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None


def idle(method):
    subprocess.run(["omarchy-shell", "-q", "idle", method],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def baseline(seconds=5):
    temps, slows = [], []
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        temps.append(tctl())
        slows.append(pm()[5])
        time.sleep(0.1)
    return statistics.median(temps), statistics.median(slows)


# A burst's speed depends on where it starts: the die's temperature, and how
# much of the PPT slow average the last run left behind (the fast limit only
# holds until that average catches up). Every run therefore waits for both to
# come back near idle, judged on a 2s mean because Tctl jumps on any wakeup.
def cool_down(base_t, base_slow, min_wait=15, max_wait=180):
    start = time.monotonic()
    window = deque(maxlen=20)
    while True:
        window.append((tctl(), pm()[5]))
        waited = time.monotonic() - start
        if waited >= min_wait and len(window) == window.maxlen:
            t = statistics.mean(w[0] for w in window)
            s = statistics.mean(w[1] for w in window)
            if t <= base_t + 4 and s <= base_slow + 4:
                return waited, True
        if waited >= max_wait:
            return waited, False
        time.sleep(0.1)


class Sampler(threading.Thread):
    def __init__(self):
        super().__init__(daemon=True)
        self.rows, self.done = [], threading.Event()

    def run(self):
        while not self.done.is_set():
            self.rows.append((tctl(), pm()[3], mhz()))
            self.done.wait(0.1)


# Fixed work, not fixed time: --cpu-ops counts across all workers, so the
# wall time is the number, and a faster limit shows up as a shorter run.
def burst(ops):
    s = Sampler()
    s.start()
    t0 = time.perf_counter()
    subprocess.run(["stress-ng", "--cpu", str(os.cpu_count()), "--cpu-method", "matrixprod",
                    "--cpu-ops", str(ops), "--quiet"], check=True)
    dt = time.perf_counter() - t0
    s.done.set()
    s.join()
    temps, watts, freqs = zip(*s.rows) if s.rows else ((0,), (0,), (0,))
    return dt, max(temps), statistics.mean(watts), max(watts), statistics.mean(freqs)


def summarize(rows):
    if not rows:
        print("no runs recorded")
        return
    ref = int(float(rows[0]["ref_w"]))
    sizes = sorted({float(r["size_s"]) for r in rows})
    for size in sizes:
        sel = [r for r in rows if float(r["size_s"]) == size]
        by = {}
        for r in sel:
            by.setdefault(int(float(r["fast_w"])), []).append(r)
        ref_med = statistics.median(float(r["seconds"]) for r in by.get(ref, sel))
        print(f"\n  ~{size:g}s burst ({sel[0]['ops']} ops)")
        print(f"  {'burst':>6} {'runs':>5} {'median':>8} {'range':>15} {'vs ' + str(ref) + 'W':>8}"
              f" {'peak Tctl':>10} {'avg W':>6} {'avg MHz':>8}")
        for lim in sorted(by):
            rs = by[lim]
            secs = [float(r["seconds"]) for r in rs]
            med = statistics.median(secs)
            vs = "--" if lim == ref else f"{(med / ref_med - 1) * 100:+.1f}%"
            print(f"  {str(lim) + 'W':>6} {len(rs):>5} {med:>7.3f}s {min(secs):>6.3f}-{max(secs):.3f}s"
                  f" {vs:>8} {statistics.median(float(r['peak_tctl']) for r in rs):>8.1f}°C"
                  f" {statistics.mean(float(r['mean_w']) for r in rs):>6.1f}"
                  f" {statistics.mean(float(r['mean_mhz']) for r in rs):>8.0f}")
    warm = sum(r["cooled"] == "False" for r in rows)
    print(f"\n  vs {ref}W: negative = finished sooner. A difference smaller than the"
          f"\n  range column is run-to-run noise, not the limit.")
    if warm:
        print(f"  {warm} run(s) started before the machine had cooled to idle (see 'cooled').")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--limits", default="50,54,58,62", help="burst limits to test, in W")
    ap.add_argument("--sizes", default="1,3,10", help="burst lengths in seconds, at the current limit")
    ap.add_argument("--rounds", type=int, default=5)
    ap.add_argument("--summarize", metavar="CSV", help="print the table from a finished run and exit")
    a = ap.parse_args()

    if a.summarize:
        with open(a.summarize) as f:
            summarize(list(csv.DictReader(f)))
        return

    gate()
    global TCTL
    TCTL = hwmon("k10temp")
    limits = [int(x) for x in a.limits.split(",")]
    sizes = [float(x) for x in a.sizes.split(",")]
    ref = configured_fast()
    runs = a.rounds * len(sizes) * len(limits)
    est = runs * (20 + statistics.mean(sizes)) / 60  # cool-down measured at ~15-20s
    print(f"burst-bench: {runs} runs, roughly {est:.0f} min. Limits {limits}W against the"
          f" configured {ref}W.\nLeave the machine alone until it finishes -- any other load"
          f" lands in the timings.")
    if float(read("/proc/loadavg").split()[0]) > 1.0:
        print("  warning: 1-minute load average is above 1.0; something else is running")

    needs_sudo = any(abs(pm()[2] - l) >= 0.5 for l in limits)
    stop = threading.Event()
    if needs_sudo:
        if subprocess.run(["sudo", "-v"]).returncode:
            die("sudo needed for ryzenadj")

        # sudo's credential cache expires mid-run otherwise.
        def keepalive():
            while not stop.wait(50):
                subprocess.run(["sudo", "-n", "-v"])
        threading.Thread(target=keepalive, daemon=True).start()

    # The screensaver starts after 150s idle and is a full-screen animation:
    # CPU load of its own, landing in whichever run it starts during.
    was_idle = idle_enabled()
    if was_idle:
        idle("disable")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / f"burst-{time.strftime('%Y%m%d-%H%M%S')}.csv"
    rows, rejected = [], set()
    try:
        print("measuring idle baseline...")
        base_t, base_slow = baseline()
        print(f"  idle: Tctl {base_t:.1f}°C, PPT slow {base_slow:.1f}W")

        set_fast(ref)
        cool_down(base_t, base_slow)
        rate = CAL_OPS / burst(CAL_OPS)[0]
        ops = {s: max(1000, round(rate * s / 100) * 100) for s in sizes}
        print(f"  calibrated at {ref}W: {rate:.0f} ops/s -> "
              + ", ".join(f"~{s:g}s = {o} ops" for s, o in ops.items()))

        with open(out, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=COLUMNS)
            w.writeheader()
            n = 0
            for rnd in range(1, a.rounds + 1):
                for size in sizes:
                    # Shuffled within each round so drift -- room warming up,
                    # dust, a background task -- spreads across every limit
                    # instead of landing on whichever ran last.
                    order = [l for l in limits if l not in rejected]
                    random.shuffle(order)
                    for lim in order:
                        n += 1
                        actual = set_fast(lim)
                        if abs(actual - lim) >= 0.5:
                            rejected.add(lim)
                            print(f"  {lim}W: SMU reports {actual:.1f}W -- rejected, skipping it")
                            continue
                        waited, cooled = cool_down(base_t, base_slow)
                        p = pm()
                        start_t = tctl()
                        dt, peak_t, mean_w, peak_w, mean_mhz = burst(ops[size])
                        row = dict(round=rnd, size_s=size, ops=ops[size], fast_w=lim, ref_w=ref,
                                   smu_fast_w=round(actual, 1), seconds=round(dt, 3),
                                   start_tctl=round(start_t, 1), peak_tctl=round(peak_t, 1),
                                   mean_w=round(mean_w, 1), peak_w=round(peak_w, 1),
                                   mean_mhz=round(mean_mhz), stapm_start_w=round(p[1], 1),
                                   slow_start_w=round(p[5], 1), waited_s=round(waited),
                                   cooled=cooled)
                        w.writerow(row)
                        f.flush()
                        rows.append({k: str(v) for k, v in row.items()})
                        print(f"  [{n}/{runs}] round {rnd}  ~{size:g}s  {lim}W  {dt:.3f}s"
                              f"  peak {peak_t:.1f}°C  {mean_w:.1f}W"
                              f"{'' if cooled else '  (started warm)'}")
    except KeyboardInterrupt:
        print("\ninterrupted -- summarising what ran")
    finally:
        if needs_sudo:
            subprocess.run(["sudo", "-n", "systemctl", "restart", "ryzen-tdp.service"])
            time.sleep(0.5)
            p = pm()
            print(f"\nrestored from {ENV_FILE}: SMU reports {p[0]:.0f}W sustained, {p[2]:.0f}W burst")
        stop.set()
        if was_idle:
            idle("enable")
        summarize(rows)
        if rows:
            print(f"\n  raw runs: {out}")


if __name__ == "__main__":
    main()
