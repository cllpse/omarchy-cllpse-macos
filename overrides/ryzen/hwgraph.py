#!/usr/bin/env python3
"""Live graphs for the CPU, each RAM stick and the SSD, one screen, no deps.

  hwgraph.py                            q quits

CPU graphs its average clock and Tctl; each RAM stick and the SSD graph their
temperature. See README.md (4) in this directory for the sensors, the scales,
and why not btop or s-tui. Needs no root.
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
NAME = 6  # title column: device name, then its readings
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


class Clock:
    """Average and fastest core clock, from every core's scaling_cur_freq."""

    def __init__(self):
        cpus = glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq")
        self.cur = [c + "/scaling_cur_freq" for c in cpus]
        top = max(int(read(c + "/cpuinfo_max_freq")) for c in cpus) / 1e6
        self.scale = (0, math.ceil(top), GHZ_STEPS, "G")
        self.hist = deque(maxlen=HISTORY)

    def sample(self):
        ghz = [int(read(c)) / 1e6 for c in self.cur]
        self.hist.append(sum(ghz) / len(ghz))
        self.peak = max(ghz)


class Sensor:
    """One hwmon's temp1, in °C."""

    def __init__(self, hwmon, scale):
        self.hwmon = hwmon
        self.scale = scale
        self.hist = deque(maxlen=HISTORY)

    def sample(self):
        self.hist.append(int(read(self.hwmon + "/temp1_input")) / 1000)


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


def title(win, y, name, parts):
    put(win, y, 0, name, curses.A_BOLD)
    x = NAME
    for text, attr in parts:
        put(win, y, x, text, attr)
        x += len(text) + 3


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
    # CPU has two graphs, every other device one; each device has a title,
    # there is a rule between devices and a gap between CPU's two graphs
    devices = 2 + len(rams)
    gh = (rows - 2 * devices) // (devices + 1)
    if gh < 2 or cols < AXIS + 10:
        put(win, 0, 0, "window too small")
    elif not clock.hist:
        put(win, 0, 0, "sampling…", curses.A_DIM)
    else:
        title(win, 0, "CPU", [
            (f"{clock.hist[-1]:.2f} GHz avg  {clock.peak:.2f} peak", c["freq"]),
            (f"{cpu.hist[-1]:.1f}°C", c["cpu"]),
        ])
        graph(win, 1, gh, cols, clock.hist, clock.scale, c["freq"])
        graph(win, gh + 2, gh, cols, cpu.hist, cpu.scale, c["cpu"])
        y = 2 * gh + 3
        rows_below = [(f"RAM {n}", ram, "ram") for n, ram in enumerate(rams, 1)]
        for name, sensor, color in rows_below + [("SSD", ssd, "ssd")]:
            rule(win, y - 1, cols)
            title(win, y, name, [(f"{sensor.hist[-1]:.1f}°C", c[color])])
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
