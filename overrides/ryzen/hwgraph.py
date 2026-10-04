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
from collections import deque

INTERVAL = 1.0
HISTORY = 2000
BLOCKS = " ▁▂▃▄▅▆▇█"
AXIS = 6  # scale column at the right end, beside the newest reading
DOT = "┈"  # gridline, drawn at the vertical centre of a cell

# Scales are (low, high, gridline steps finest first, unit). Tctl has no crit
# file; the firmware holds it at 92°C. From 25°C every RAM step lands on the
# sticks' 55°C temp1_max as well as their 85°C crit. The SSD's Composite
# sensor idles at 16-27°C, hence its lower floor.
GHZ_STEPS = (0.5, 1, 2.5)
CPU_TEMP = (30, 100, (5, 10, 35), "°")
RAM_FLOOR, RAM_STEPS = 25, (5, 10, 15, 30)
SSD_TEMP = (15, 85, (5, 10, 35), "°")


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
        super().__init__((0, math.ceil(top), GHZ_STEPS, "G"))

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


def label(win, y, name, fields, attr, x):
    """Graph name, then `key: value` fields from column x, values in colour."""
    put(win, y, 0, name, curses.A_BOLD)
    for i, (key, value) in enumerate(fields):
        sep = ", " if i < len(fields) - 1 else ""
        for text, a in ((f"{key}: ", curses.A_DIM), (value, attr), (sep, curses.A_DIM)):
            put(win, y, x, text, a)
            x += len(text)


def clock_fields(clock, width):
    window, overall, peak = clock.stats(width)
    return [("window", f"{window:.2f}GHz"), ("peak", f"{peak:.2f}GHz"),
            ("overall", f"{overall:.2f}GHz")]


def temp_fields(sensor, width):
    window, overall, peak = sensor.stats(width)
    return [("window", f"{window:.1f}°"), ("overall", f"{overall:.1f}°"),
            ("peak", f"{peak:.1f}°")]


def rule(win, y, w):
    put(win, y, 0, "─" * w, curses.A_DIM)


def grid(span, steps, h):
    """(step, lines - 1, rows between lines) for the finest step that fits."""
    for step in (*steps, span):
        n = span / step
        if abs(n - round(n)) < 1e-9 and (h - 1) // round(n) >= 1:
            return step, round(n), (h - 1) // round(n)


def graph(win, y, h, w, hist, scale, attr):
    """Bars against dotted gridlines. A label can only sit mid-row, so every
    line does too: the scale runs from the middle of the bottom row to the
    middle of the top one, the lines a whole number of rows apart, and the
    rows that don't divide evenly are left blank below. A bar's top is what
    reads against the lines, so a bar stands on the bottom edge, half a row
    under the low line, rather than starting at it, where nothing finer than
    a half-block could be drawn."""
    lo, hi, steps, unit = scale
    step, n, d = grid(hi - lo, steps, h)
    h = n * d + 1
    width = w - AXIS
    bottom = y + h - 1
    for k in range(n + 1):
        put(win, bottom - k * d, 0, DOT * width, curses.A_DIM)
        put(win, bottom - k * d, width + 1, f"{lo + k * step:g}{unit}", curses.A_DIM)
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


def draw(win, clock, cpu, rams, ssd, c):
    win.erase()
    rows, cols = win.getmaxyx()
    # CPU has two graphs, every other device one; every graph has a label
    # row above it, and there is a rule between devices
    devices = 2 + len(rams)
    gh = (rows - 2 * devices) // (devices + 1)
    if gh < 2 or cols < AXIS + 10:
        put(win, 0, 0, "window too small")
    elif not clock.hist:
        put(win, 0, 0, "sampling…", curses.A_DIM)
    else:
        width = cols - AXIS  # samples a graph shows
        below = [(f"RAM #{n} - temperature", ram, "ram")
                 for n, ram in enumerate(rams, 1)]
        below.append(("SSD - temperature", ssd, "ssd"))
        names = ["CPU - frequency", "CPU - temperature"] + [b[0] for b in below]
        at = len(max(names, key=len)) + 2  # one figures column for every row
        label(win, 0, names[0], clock_fields(clock, width), c["freq"], at)
        graph(win, 1, gh, cols, clock.hist, clock.scale, c["freq"])
        label(win, gh + 1, names[1], temp_fields(cpu, width), c["cpu"], at)
        graph(win, gh + 2, gh, cols, cpu.hist, cpu.scale, c["cpu"])
        y = 2 * gh + 3
        for name, sensor, color in below:
            rule(win, y - 1, cols)
            label(win, y, name, temp_fields(sensor, width), c[color], at)
            graph(win, y + 1, gh, cols, sensor.hist, sensor.scale, c[color])
            y += gh + 2
    win.refresh()


def main(win):
    curses.curs_set(0)
    curses.start_color()
    curses.use_default_colors()
    names = ("freq", "cpu", "ram", "ssd")
    colors = (curses.COLOR_MAGENTA, curses.COLOR_BLUE,
              curses.COLOR_YELLOW, curses.COLOR_GREEN)
    c = {}
    for pair, (name, color) in enumerate(zip(names, colors), 1):
        curses.init_pair(pair, color, -1)
        c[name] = curses.color_pair(pair)

    clock = Clock()
    cpu = first("k10temp", CPU_TEMP, "the CPU row reads an AMD CPU's Tctl")
    ssd = first("nvme", SSD_TEMP, "the SSD row reads an NVMe drive's Composite")
    rams = [Sensor(h, (RAM_FLOOR, int(read(h + "/temp1_crit")) / 1000,
                       RAM_STEPS, "°"))
            for _, h in hwmons("spd5118")]
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
