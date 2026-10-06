#!/usr/bin/env python3
"""Live graphs for the CPU, each RAM stick and the SSD, one screen, no deps.

  hwgraph.py                            q quits

CPU graphs its average clock and Tctl; each RAM stick and the SSD graph their
temperature. Every graph is labelled window (the mean of what it shows),
overall (the mean since start) and peak (the highest since start). See
README.md (4) in this directory for the sensors, the scales, and why not
btop or s-tui. Needs no root.
"""
import curses
import glob
import math
import os
import sys
import time
from collections import deque, namedtuple

INTERVAL = 1.0
HISTORY = 2000
BLOCKS = " ▁▂▃▄▅▆▇█"
AXIS = 6  # scale column at the right end, beside the newest reading
DOT = "┄"  # gridline: three dashes per cell, at the row's vertical centre

# A scale's gridline steps are finest first; label turns a line's value into
# its text, and limit is where the part throttles, drawn red. A line can only
# sit mid-row, so a limit has to land on one: the CPU's and RAM's are each
# their scale's top, counting down from it in steps. Every temperature span
# takes a 15° step, which with the clock's 1 GHz fits the 28 rows a 49-row
# window leaves for graphs.
#
# CPU throttles at 92°C Tctl: the SMU's thermal limits in ryzen_smu's
# pm_table all read 92.00, and a 40-minute all-core load held Tctl at
# exactly 92.0 (ryzen-tdp.env). Tctl has no crit file to read it from.
# RAM throttles at its temp1_crit, 85°C, the top of DDR5's normal range:
# above it JEDEC doubles the refresh rate, which costs bandwidth. From 25°C
# every RAM step also lands on the sticks' 55°C temp1_max. The SSD's
# Composite sensor idles at 16-27°C, hence its floor; it tops out at its
# 89.85°C max.
Scale = namedtuple("Scale", "lo hi steps label limit", defaults=(None,))


def degrees(v):
    return f"{v:g}°"


def gigahertz(v):
    return f"{v:g}GHz" if v else "0"


GHZ_STEPS = (1,)
CPU_THROTTLE = 92
CPU_TEMP = Scale(CPU_THROTTLE - 75, CPU_THROTTLE, (5, 15, 25), degrees,
                 CPU_THROTTLE)
RAM_FLOOR, RAM_STEPS = 25, (5, 10, 15, 30)
SSD_TEMP = Scale(15, 90, (5, 15, 25), degrees)
GAP = 4  # blank rows between graphs, where the window has them to spare


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
    """One reading's history, with its peak and mean since start kept apart
    from it, so neither forgets when the history fills."""

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

    def stats(self, width):
        """(window, overall, peak): mean of the last `width` samples, which is
        what the graph shows; mean since start; highest since start."""
        shown = list(self.hist)[-width:]
        # Summed the way total is: sum() compensates since 3.12, and the two
        # then round apart at .x5 while the graph still holds every sample
        window = 0.0
        for v in shown:
            window += v
        return window / len(shown), self.total / self.count, self.peak


class Clock(Series):
    """Average core clock, from every core's scaling_cur_freq."""

    def __init__(self):
        cpus = glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq")
        self.cur = [c + "/scaling_cur_freq" for c in cpus]
        top = max(int(read(c + "/cpuinfo_max_freq")) for c in cpus) / 1e6
        super().__init__(Scale(0, math.ceil(top), GHZ_STEPS, gigahertz))

    def sample(self):
        ghz = [int(read(c)) / 1e6 for c in self.cur]
        self.add(sum(ghz) / len(ghz))


class Sensor(Series):
    """One hwmon's temp1, in °C."""

    def __init__(self, hwmon, scale):
        super().__init__(scale)
        self.hwmon = hwmon

    def sample(self):
        self.add(int(read(self.hwmon + "/temp1_input")) / 1000)


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


def fields(series, width, unit, places):
    window, overall, peak = series.stats(width)
    return [(key, f"{v:.{places}f}{unit}")
            for key, v in (("window", window), ("overall", overall), ("peak", peak))]


def labels(win, rows):
    """Every graph's label row: its name, then `key: value` fields in columns
    that line up down the screen, the values in the graph's colour."""
    at = max(len(name) for _, name, _, _ in rows) + 2
    widths = [max(len(f"{key}: {value}, ") for key, value in column)
              for column in zip(*(f for _, _, f, _ in rows))]
    for y, name, row, attr in rows:
        put(win, y, 0, name, curses.A_BOLD)
        x = at
        for i, ((key, value), w) in enumerate(zip(row, widths)):
            put(win, y, x, f"{key}: ", curses.A_DIM)
            put(win, y, x + len(key) + 2, value, attr)
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
    Rows still spare stretch the shortest graph's line spacing. Graphs on
    the same scale (the RAM sticks) move together, so they always match."""
    groups = {}
    for i, s in enumerate(scales):
        groups.setdefault(s, []).append(i)
    groups = list(groups.values())  # top graph first
    opts = [grids(scales[g[0]]) for g in groups]
    pick, d = [0] * len(groups), [1] * len(groups)
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
    while True:
        n = [o[p][0] for o, p in zip(opts, pick)]
        taller = [(n[k] * d[k] + 1, k) for k, g in enumerate(groups)
                  if used + n[k] * len(g) <= budget]
        if not taller:
            break
        _, k = min(taller)
        d[k] += 1
        used += n[k] * len(groups[k])
    spec = [None] * len(scales)
    for k, g in enumerate(groups):
        for i in g:
            spec[i] = (opts[k][pick[k]][1], opts[k][pick[k]][0], d[k])
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
        put(win, bottom - k * d, width + 1, scale.label(v), line)
    values = list(hist)[-width:]
    x0 = width - len(values)
    for i, v in enumerate(values):
        if v <= lo:
            continue
        top = 0.5 + min((v - lo) / (hi - lo), 1) * (h - 1)  # rows above bottom
        for row in range(h):
            fill = min(max(round((top - row) * 8), 0), 8)
            if fill:
                put(win, bottom - row, x0 + i, BLOCKS[fill], attr)
    return h


def draw(win, clock, cpu, rams, ssd, c):
    win.erase()
    rows, cols = win.getmaxyx()
    # (name, series, colour, unit, decimals), top to bottom
    graphs = [("CPU - frequency", clock, "freq", "GHz", 2),
              ("CPU - temperature", cpu, "cpu", "°", 1)]
    graphs += [(f"RAM #{n} - temperature", ram, "ram", "°", 1)
               for n, ram in enumerate(rams, 1)]
    graphs.append(("SSD - temperature", ssd, "ssd", "°", 1))
    # rows for graphs: all of them but a label each and the gaps between;
    # a short window gives up blank rows before graphs drop below two rows
    for gap in range(GAP, -1, -1):
        budget = rows - len(graphs) - (len(graphs) - 1) * gap
        if budget >= 2 * len(graphs):
            break
    if budget < 2 * len(graphs) or cols < AXIS + 10:
        put(win, 0, 0, "window too small")
    elif not clock.hist:
        put(win, 0, 0, "sampling…", curses.A_DIM)
    else:
        width = cols - AXIS  # samples a graph shows
        specs = layout([g[1].scale for g in graphs], budget)
        rows_out, y = [], 0
        for (name, series, color, unit, places), spec in zip(graphs, specs):
            rows_out.append((y, name, fields(series, width, unit, places), c[color]))
            y += 1 + graph(win, y + 1, cols, series.hist, series.scale, spec,
                           c[color], c["hot"])
            y += gap
        labels(win, rows_out)
    win.refresh()


def main(win):
    curses.curs_set(0)
    curses.start_color()
    curses.use_default_colors()
    names = ("freq", "cpu", "ram", "ssd", "hot")
    colors = (curses.COLOR_MAGENTA, curses.COLOR_BLUE,
              curses.COLOR_YELLOW, curses.COLOR_GREEN, curses.COLOR_RED)
    c = {}
    for pair, (name, color) in enumerate(zip(names, colors), 1):
        curses.init_pair(pair, color, -1)
        c[name] = curses.color_pair(pair)

    clock = Clock()
    cpu = first("k10temp", CPU_TEMP, "the CPU row reads an AMD CPU's Tctl")
    ssd = first("nvme", SSD_TEMP, "the SSD row reads an NVMe drive's Composite")
    rams = []
    for _, h in hwmons("spd5118"):
        crit = int(read(h + "/temp1_crit")) / 1000
        rams.append(Sensor(h, Scale(RAM_FLOOR, crit, RAM_STEPS, degrees, crit)))
    devices = [clock, cpu, *rams, ssd]
    last = time.monotonic()
    while True:
        draw(win, clock, cpu, rams, ssd, c)
        win.timeout(max(0, math.ceil((last + INTERVAL - time.monotonic()) * 1000)))
        if win.getch() == ord("q"):
            break
        now = time.monotonic()
        if now >= last + INTERVAL - 0.005:
            for d in devices:
                d.sample()
            last = now


if __name__ == "__main__":
    curses.wrapper(main)
