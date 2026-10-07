#!/usr/bin/env python3
"""Live graphs for the CPU, each RAM stick and the SSD, one screen, no deps.

  hwgraph.py                            q quits

CPU graphs its average clock, its sustained power against its limit (with
ryzen_smu loaded) and Tctl; each RAM stick and the SSD graph their
temperature. Every graph is labelled current (the latest reading), overall
(the mean) and peak (the highest). Every sample is logged to LOG_DIR, and a
restart replays the last LOG_HOURS of it, so overall and peak cover that and
everything since. See README.md (4) in this directory for the sensors, the
scales, and why not btop or s-tui. Needs no root.
"""
import curses
import fcntl
import glob
import math
import os
import struct
import sys
import time
from collections import deque, namedtuple
from datetime import date
from pathlib import Path

INTERVAL = 0.5  # seconds between samples; one graph column each
HISTORY = 2000
LOG_DIR = Path(os.environ.get("XDG_STATE_HOME")
               or Path.home() / ".local/state") / "hwgraph"
LOG_HOURS = 24  # what a restart replays: ~0.7 s to load; a week took ~5 s
BREAK = 5  # seconds without a sample that draw as a blank column
BLOCKS = " ▁▂▃▄▅▆▇█"
AXIS = 6  # scale column at the right end, labels right-aligned in it
PM_TABLE = "/sys/kernel/ryzen_smu_drv/pm_table"
DOT = "┄"  # gridline: three dashes per cell, at the row's vertical centre

# A scale's gridline steps are finest first; label turns a line's value into
# its text, and limit is where the part throttles, drawn red. A line can only
# sit mid-row, so a limit has to land on one: the CPU's, power's and RAM's
# are each their scale's top, counting down from it in steps. Every scale
# takes four lines, one step: the clock 2-5 GHz, power the 30 W under its
# limit, and the temperatures their whole span. A window too short for four
# falls back to the low and high lines.
#
# CPU throttles at 92°C Tctl, Geekom's firmware limit under AMD's 100°C
# Tjmax: pm_table 0x004C0009's Tctl limit (offset 0x40, per RyzenAdj) reads
# 92.00, and a 40-minute all-core load held Tctl at exactly 92.0
# (ryzen-tdp.env). Tctl has no crit file to read it from.
# RAM throttles at its temp1_crit, 85°C: the Crucial/Micron SODIMMs' DRAM
# case limit, above which Micron's datasheet requires 2X refresh, and the
# rating of the modules' X5R capacitors. The hub sensor graphed approximates
# the DRAM case temperature. The SSD's Composite sensor idles at 16-27°C,
# hence its floor; it tops out at its 89.85°C max.
# Power is limited at the PPT slow limit, read live, which tops its scale.
Scale = namedtuple("Scale", "lo hi steps label limit", defaults=(None,))
Graph = namedtuple("Graph", "name series color unit places column")


def degrees(v):
    return f"{v:g}°"


def gigahertz(v):
    return f"{v:g}GHz"


def watts(v):
    return f"{v:g}W"


GHZ_FLOOR, GHZ_STEP = 2, 1
POWER_STEP = 10  # 30 W under the limit: 20, 30, 40, 50 at 50 W
CPU_THROTTLE = 92
CPU_TEMP = Scale(CPU_THROTTLE - 75, CPU_THROTTLE, (25,), degrees, CPU_THROTTLE)
RAM_STEP = 20  # down from the 85°C crit: 25, 45, 65, 85
SSD_TEMP = Scale(15, 90, (25,), degrees)
GAP = 3  # blank rows between graphs, where the window has them to spare


def die(msg):
    sys.exit(f"hwgraph: {msg}")


def read(path):
    with open(path) as f:
        return f.read().strip()


def hwmons(name):
    """(device path, hwmon dir) for every hwmon with this name, in bus order."""
    found = []
    for h in glob.glob("/sys/class/hwmon/hwmon*"):
        if read(h + "/name") == name:
            found.append((os.path.realpath(h + "/device"), h))
    return sorted(found)


class Series:
    """One reading's history, with its peak and mean kept apart from it, so
    neither forgets when the history fills. None in the history is a break:
    hwgraph wasn't sampling (closed, or the machine asleep)."""

    def __init__(self, scale):
        self.scale = scale
        self.hist = deque(maxlen=HISTORY)
        self.peak = float("-inf")
        self.total = 0.0
        self.count = 0

    def add(self, v):
        self.hist.append(v)
        self.peak = max(self.peak, v)
        self.total += v
        self.count += 1

    def gap(self):
        self.hist.append(None)

    def stats(self):
        """(current, overall, peak): the latest reading, the mean and the
        highest, over the replayed log and everything since. None where
        there is nothing yet, as for a column the log didn't have."""
        if not self.count:
            return None, None, None
        return self.hist[-1], self.total / self.count, self.peak


class Clock(Series):
    """Average core clock, from every core's scaling_cur_freq."""

    def __init__(self):
        cpus = glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq")
        self.cur = [c + "/scaling_cur_freq" for c in cpus]
        top = max(int(read(c + "/cpuinfo_max_freq")) for c in cpus) / 1e6
        super().__init__(Scale(GHZ_FLOOR, math.ceil(top), (GHZ_STEP,), gigahertz))

    def measure(self):
        ghz = [int(read(c)) / 1e6 for c in self.cur]
        return sum(ghz) / len(ghz)


class Sensor(Series):
    """One hwmon's temp1, in °C."""

    def __init__(self, hwmon, scale):
        super().__init__(scale)
        self.hwmon = hwmon

    def measure(self):
        return int(read(self.hwmon + "/temp1_input")) / 1000


class Power(Series):
    """The CPU's PPT slow value, the long-average package power its
    sustained limit holds, from ryzen_smu's pm_table: RyzenAdj reads the
    limit at 0x10 and the value at 0x14 on every table version. The limit
    tops the scale; a pm_table that isn't there raises OSError."""

    def __init__(self):
        limit = round(self._table()[0])
        super().__init__(Scale(limit - 3 * POWER_STEP, limit, (POWER_STEP,),
                               watts, limit))

    @staticmethod
    def _table():
        with open(PM_TABLE, "rb") as f:
            return struct.unpack("<2f", f.read(0x18)[0x10:0x18])

    def measure(self):
        try:
            return self._table()[1]
        except (OSError, struct.error):
            return None  # logged empty, drawn as a break


class Log:
    """Every sample, appended to one CSV a day in LOG_DIR. A file with
    nothing newer than LOG_HOURS is deleted. Only the first hwgraph running
    holds the lock and writes; a second one replays and shows, adding
    nothing, so no sample is logged twice."""

    def __init__(self, columns):
        self.header = ",".join(("time", *columns))
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        self.lock = open(LOG_DIR / "lock", "w")
        try:
            fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.writes = True
        except BlockingIOError:
            self.writes = False
        self.day = self.file = None

    def replay(self, since):
        """(time, values) for every sample logged at or after `since`, oldest
        first, values in this run's column order. Columns are matched by
        name, so a file from a run with other columns still replays, None
        for what it lacks; an empty field is None too. A line torn by a
        crash doesn't parse and is skipped."""
        columns = self.header.split(",")[1:]
        for path in sorted(LOG_DIR.glob("????-??-??*.csv")):
            if path.stat().st_mtime < since:
                continue
            with open(path) as f:
                names = f.readline().rstrip("\n").split(",")
                at = [names.index(c) if c in names else None for c in columns]
                for line in f:
                    parts = line.rstrip("\n").split(",")
                    if len(parts) != len(names):
                        continue
                    try:
                        t = float(parts[0])
                        row = [float(p) if p else None for p in parts]
                    except ValueError:
                        continue
                    if t >= since:
                        yield t, [None if i is None else row[i] for i in at]

    def write(self, t, values):
        if not self.writes:
            return
        day = date.fromtimestamp(t)
        if day != self.day:
            self._open(day, t)
        fields = ("" if v is None else f"{v:g}" for v in values)
        self.file.write(f"{t:.2f}," + ",".join(fields) + "\n")
        self.file.flush()

    def _open(self, day, now):
        """Today's file, a header on a new one. One with other columns (a
        sensor added or removed) is renamed <date>.<time>.csv rather than
        mixed; it sorts before the new one and still replays."""
        if self.file:
            self.file.close()
        path = LOG_DIR / f"{day.isoformat()}.csv"
        torn = False
        if path.exists():
            with open(path, "rb") as f:
                head = f.readline().decode(errors="replace").rstrip("\n")
                if f.seek(0, os.SEEK_END):
                    f.seek(-1, os.SEEK_END)
                    torn = f.read(1) != b"\n"
            if head != self.header:
                path.rename(path.with_name(f"{path.stem}.{int(now)}.csv"))
        new = not path.exists()
        self.file = open(path, "a")
        if new:
            self.file.write(self.header + "\n")
        elif torn:
            self.file.write("\n")  # finish a crash's half line on its own
        self.day = day
        for old in LOG_DIR.iterdir():
            if old.suffix == ".csv" and \
                    old.stat().st_mtime < now - LOG_HOURS * 3600:
                old.unlink()


def first(name, scale, what):
    found = hwmons(name)
    if not found:
        die(f"no {name} sensor -- {what}")
    return Sensor(found[0][1], scale)


def put(win, y, x, text, attr=0):
    try:
        win.addstr(y, x, text, attr)
    except curses.error:
        pass  # writing the bottom-right cell always raises


def fields(series, unit, places, hot):
    """(key, text, colour) for current, overall and peak. current turns hot
    once it reaches the scale's limit, compared as displayed, so a 92.0°
    on screen is red even when the reading underneath is 91.96; the rest
    keep the graph's colour (None). A figure there's nothing for yet (a
    break last, or a column the replayed log lacked) reads as a dash."""
    current, overall, peak = series.stats()
    limit = series.scale.limit
    reached = None not in (limit, current) and round(current, places) >= limit
    return [(key, "–" if v is None else f"{v:.{places}f}{unit}", a)
            for key, v, a in (("current", current, hot if reached else None),
                              ("overall", overall, None), ("peak", peak, None))]


def labels(win, rows):
    """Every graph's label row: its name, then `key: value` fields in columns
    that line up down the screen, the values in the graph's colour unless a
    field brings its own."""
    at = max(len(name) for _, name, _, _ in rows) + 2
    widths = [max(len(f"{key}: {value}, ") for key, value, _ in column)
              for column in zip(*(f for _, _, f, _ in rows))]
    for y, name, row, attr in rows:
        put(win, y, 0, name, curses.A_BOLD)
        x = at
        for i, ((key, value, own), w) in enumerate(zip(row, widths)):
            put(win, y, x, f"{key}: ", curses.A_DIM)
            put(win, y, x + len(key) + 2, value, own or attr)
            if i < len(row) - 1:
                put(win, y, x + len(key) + 2 + len(value), ",", curses.A_DIM)
            x += w


def grids(scale):
    """(lines - 1, step) for every step that divides the span, coarsest first."""
    span = scale.hi - scale.lo
    return sorted({(round(span / s), s) for s in (*scale.steps, span)
                   if abs(span / s - round(span / s)) < 1e-9})


def layout(scales, budget):
    """(step, lines - 1, rows between lines) for each graph, in budget rows.
    Every graph starts with only its low and high lines. The one with the
    fewest lines then takes its next finer grid, the cheapest first on a
    tie, while rows last, so no graph is left coarse to make another fine.
    Rows still spare stretch every graph's line spacing together, or none,
    so the graphs keep one height. Graphs on the same scale (the RAM
    sticks) move together, so they always match."""
    groups = {}
    for i, s in enumerate(scales):
        groups.setdefault(s, []).append(i)
    groups = list(groups.values())  # top graph first
    opts = [grids(scales[g[0]]) for g in groups]
    pick, d = [0] * len(groups), 1
    used = 2 * len(scales)
    while True:
        finer = [(o[p][0], (o[p + 1][0] - o[p][0]) * len(g), k)
                 for k, (g, o, p) in enumerate(zip(groups, opts, pick))
                 if p + 1 < len(o)]
        finer = [f for f in finer if used + f[1] <= budget]
        if not finer:
            break
        _, extra, k = min(finer)
        pick[k] += 1
        used += extra
    taller = sum(o[p][0] * len(g) for g, o, p in zip(groups, opts, pick))
    while used + taller <= budget:  # one more row between every graph's lines
        d += 1
        used += taller
    spec = [None] * len(scales)
    for k, g in enumerate(groups):
        for i in g:
            spec[i] = (opts[k][pick[k]][1], opts[k][pick[k]][0], d)
    return spec


def graph(win, y, w, hist, scale, spec, attr, hot):
    """Bars against dotted gridlines, the scale's limit line and label in
    hot. A label can only sit mid-row, so every line does too: the scale
    runs from the middle of the bottom row to the middle of the top one, the
    lines a whole number of rows apart, as spec (from layout) says. A bar's
    top is what reads against the lines, so a bar stands on the bottom edge,
    half a row under the low line, rather than starting at it, where nothing
    finer than a half-block could be drawn. Returns the rows it used."""
    lo, hi = scale.lo, scale.hi
    step, n, d = spec
    h = n * d + 1
    width = w - AXIS
    bottom = y + h - 1
    for k in range(n + 1):
        v = lo + k * step
        line = hot if scale.limit is not None and abs(v - scale.limit) < 1e-9 \
            else curses.A_DIM
        put(win, bottom - k * d, 0, DOT * width, line)
        put(win, bottom - k * d, width + 1, scale.label(v).rjust(AXIS - 1), line)
    values = list(hist)[-width:]
    x0 = width - len(values)
    for i, v in enumerate(values):
        if v is None or v <= lo:  # a break, or nothing to draw
            continue
        top = 0.5 + min((v - lo) / (hi - lo), 1) * (h - 1)  # rows above bottom
        for row in range(h):
            fill = min(max(round((top - row) * 8), 0), 8)
            if fill:
                put(win, bottom - row, x0 + i, BLOCKS[fill], attr)
    return h


def draw(win, graphs, c):
    win.erase()
    rows, cols = win.getmaxyx()
    # rows for graphs: all of them but a label each and the gaps between;
    # a short window gives up blank rows before graphs drop below two rows
    for gap in range(GAP, -1, -1):
        budget = rows - len(graphs) - (len(graphs) - 1) * gap
        if budget >= 2 * len(graphs):
            break
    if budget < 2 * len(graphs) or cols < AXIS + 10:
        put(win, 0, 0, "window too small")
    elif not graphs[0].series.hist:
        put(win, 0, 0, "sampling…", curses.A_DIM)
    else:
        specs = layout([g.series.scale for g in graphs], budget)
        rows_out, y = [], 0
        for g, spec in zip(graphs, specs):
            s = g.series
            rows_out.append((y, g.name, fields(s, g.unit, g.places, c["hot"]),
                             c[g.color]))
            y += 1 + graph(win, y + 1, cols, s.hist, s.scale, spec,
                           c[g.color], c["hot"])
            y += gap
        labels(win, rows_out)
    win.refresh()


def main(win):
    curses.curs_set(0)
    curses.start_color()
    curses.use_default_colors()
    names = ("freq", "power", "cpu", "ram", "ssd", "hot")
    colors = (curses.COLOR_MAGENTA, curses.COLOR_CYAN, curses.COLOR_BLUE,
              curses.COLOR_YELLOW, curses.COLOR_GREEN, curses.COLOR_RED)
    c = {}
    for pair, (name, color) in enumerate(zip(names, colors), 1):
        curses.init_pair(pair, color, -1)
        c[name] = curses.color_pair(pair)

    # top to bottom; column names the series in the log
    graphs = [Graph("CPU - frequency", Clock(), "freq", "GHz", 2, "clock_ghz")]
    try:
        graphs.append(Graph("CPU - power", Power(), "power", "W", 1, "cpu_w"))
    except (OSError, struct.error):
        pass  # no ryzen_smu module: no power block
    graphs.append(Graph("CPU - temperature",
                        first("k10temp", CPU_TEMP,
                              "the CPU row reads an AMD CPU's Tctl"),
                        "cpu", "°", 1, "cpu_c"))
    for n, (_, h) in enumerate(hwmons("spd5118"), 1):
        crit = int(read(h + "/temp1_crit")) / 1000
        ram = Sensor(h, Scale(crit - 3 * RAM_STEP, crit, (RAM_STEP,), degrees,
                              crit))
        graphs.append(Graph(f"RAM #{n} - temperature", ram, "ram", "°", 1,
                            f"ram{n}_c"))
    graphs.append(Graph("SSD - temperature",
                        first("nvme", SSD_TEMP,
                              "the SSD row reads an NVMe drive's Composite"),
                        "ssd", "°", 1, "ssd_c"))
    devices = [g.series for g in graphs]
    log = Log([g.column for g in graphs])

    def sampled(t, values, before):
        """Hand one sample to every series, a break first if it follows the
        one before by more than BREAK seconds. None, a reading that failed
        or a column the log lacked, is a break for that series alone."""
        if before is not None and t - before > BREAK:
            for d in devices:
                d.gap()
        for d, v in zip(devices, values):
            if v is None:
                d.gap()
            else:
                d.add(v)
        return t

    put(win, 0, 0, "loading history…", curses.A_DIM)
    win.refresh()
    stamp = None  # wall-clock time of the newest sample, replayed or live
    for t, values in log.replay(time.time() - LOG_HOURS * 3600):
        stamp = sampled(t, values, stamp)
    last = time.monotonic()
    while True:
        draw(win, graphs, c)
        win.timeout(max(0, math.ceil((last + INTERVAL - time.monotonic()) * 1000)))
        if win.getch() == ord("q"):
            break
        now = time.monotonic()
        if now >= last + INTERVAL - 0.005:
            t = time.time()
            values = [d.measure() for d in devices]
            stamp = sampled(t, values, stamp)
            log.write(t, values)
            last = now


if __name__ == "__main__":
    curses.wrapper(main)
