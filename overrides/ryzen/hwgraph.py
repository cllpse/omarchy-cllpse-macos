#!/usr/bin/env python3
"""Live graphs for the CPU, each RAM stick and the SSD, one screen, no deps.

  hwgraph.py                            q quits

CPU graphs utilisation and average clock. A RAM stick reports nothing of its
own but temperature (usage is system-wide, the clock is fixed), so that is
what each stick graphs. SSD graphs busy time: the share of each second with
I/O in flight. See README.md (4) in this directory for why these and not
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
AXIS = 6


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


def temp(hwmon):
    return int(read(hwmon + "/temp1_input")) / 1000


class Cpu:
    def __init__(self):
        found = hwmons("k10temp")
        if not found:
            die("no k10temp sensor -- the CPU row reads an AMD CPU's Tctl")
        self.hwmon = found[0][1]
        cpus = glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq")
        self.cur = [c + "/scaling_cur_freq" for c in cpus]
        self.fmax = max(int(read(c + "/cpuinfo_max_freq")) for c in cpus) / 1e6
        self.prev = self._stat()
        self.util = deque(maxlen=HISTORY)
        self.freq = deque(maxlen=HISTORY)

    def _stat(self):
        # user nice system idle iowait irq softirq steal; guest is inside user
        v = [int(x) for x in read("/proc/stat").split("\n", 1)[0].split()[1:9]]
        return sum(v), v[3] + v[4]

    def sample(self, dt):
        total, idle = self._stat()
        dtotal = total - self.prev[0]
        busy = 1 - (idle - self.prev[1]) / dtotal if dtotal else 0
        self.prev = (total, idle)
        self.util.append(100 * busy)
        ghz = [int(read(c)) / 1e6 for c in self.cur]
        self.freq.append(sum(ghz) / len(ghz))
        self.peak = max(ghz)
        self.temp = temp(self.hwmon)


class Ram:
    def __init__(self, hwmon):
        self.hwmon = hwmon
        self.crit = int(read(hwmon + "/temp1_crit")) / 1000
        self.temp = deque(maxlen=HISTORY)

    def sample(self, dt):
        self.temp.append(temp(self.hwmon))


class Ssd:
    def __init__(self):
        blocks = sorted(glob.glob("/sys/block/nvme*n1"))
        if not blocks:
            die("no NVMe drive in /sys/block")
        controller = os.path.basename(blocks[0])[:-2]  # nvme0n1 -> nvme0
        self.stat = blocks[0] + "/stat"
        self.hwmon = next((h for d, h in hwmons("nvme")
                           if os.path.basename(d) == controller), None)
        if self.hwmon is None:
            die(f"no temperature sensor for {controller}")
        self.prev = self._stat()
        self.busy = deque(maxlen=HISTORY)

    def _stat(self):
        f = [int(x) for x in read(self.stat).split()]
        return f[2], f[6], f[9]  # sectors read, sectors written, ms busy

    def sample(self, dt):
        r, w, ms = self._stat()
        self.busy.append(min(100, (ms - self.prev[2]) / (dt * 10)))
        self.read_mb = (r - self.prev[0]) * 512 / dt / 1e6
        self.write_mb = (w - self.prev[1]) * 512 / dt / 1e6
        self.prev = (r, w, ms)
        self.temp = temp(self.hwmon)


def put(win, y, x, text, attr=0):
    try:
        win.addstr(y, x, text, attr)
    except curses.error:
        pass  # writing the bottom-right cell always raises


def title(win, y, name, parts):
    put(win, y, 0, name, curses.A_BOLD)
    x = AXIS
    for text, attr in parts:
        put(win, y, x, text, attr)
        x += len(text) + 3


def graph(win, y, h, w, hist, lo, hi, top, bottom, attr):
    put(win, y, 0, top.rjust(AXIS - 1), curses.A_DIM)
    if h > 1:
        put(win, y + h - 1, 0, bottom.rjust(AXIS - 1), curses.A_DIM)
    width = w - AXIS
    values = list(hist)[-width:]
    x0 = AXIS + width - len(values)
    for i, v in enumerate(values):
        frac = min(max((v - lo) / (hi - lo), 0), 1)
        eighths = round(frac * h * 8)
        for row in range(h):
            fill = min(max(eighths - row * 8, 0), 8)
            if fill:
                put(win, y + h - 1 - row, x0 + i, BLOCKS[fill], attr)


def draw(win, cpu, rams, ssd, c):
    win.erase()
    rows, cols = win.getmaxyx()
    # CPU has two graphs, every other device one; each device has a title,
    # there is a gap between devices and one between CPU's two graphs
    devices = 2 + len(rams)
    gh = (rows - 2 * devices) // (devices + 1)
    if gh < 1 or cols < AXIS + 10:
        put(win, 0, 0, "window too small")
    elif not cpu.util:
        put(win, 0, 0, "sampling…", curses.A_DIM)
    else:
        title(win, 0, "CPU", [
            (f"{cpu.util[-1]:.0f}%", c["util"]),
            (f"{cpu.freq[-1]:.2f} GHz avg  {cpu.peak:.2f} peak", c["freq"]),
            (f"{cpu.temp:.0f}°C", curses.A_DIM),
        ])
        graph(win, 1, gh, cols, cpu.util, 0, 100, "100%", "0%", c["util"])
        graph(win, gh + 2, gh, cols, cpu.freq, 0, cpu.fmax,
              f"{cpu.fmax:.1f}G", "0G", c["freq"])
        y = 2 * gh + 3
        for n, ram in enumerate(rams, 1):
            title(win, y, f"RAM {n}", [(f"{ram.temp[-1]:.1f}°C", c["ram"])])
            graph(win, y + 1, gh, cols, ram.temp, 20, ram.crit,
                  f"{ram.crit:.0f}°", "20°", c["ram"])
            y += gh + 2
        title(win, y, "SSD", [
            (f"{ssd.busy[-1]:.0f}% busy", c["ssd"]),
            (f"R {ssd.read_mb:.1f} MB/s  W {ssd.write_mb:.1f} MB/s", curses.A_DIM),
            (f"{ssd.temp:.0f}°C", curses.A_DIM),
        ])
        graph(win, y + 1, gh, cols, ssd.busy, 0, 100, "100%", "0%", c["ssd"])
    win.refresh()


def main(win):
    curses.curs_set(0)
    curses.start_color()
    curses.use_default_colors()
    names = ("util", "freq", "ram", "ssd")
    colors = (curses.COLOR_BLUE, curses.COLOR_MAGENTA,
              curses.COLOR_YELLOW, curses.COLOR_GREEN)
    c = {}
    for pair, (name, color) in enumerate(zip(names, colors), 1):
        curses.init_pair(pair, color, -1)
        c[name] = curses.color_pair(pair)

    cpu, ssd = Cpu(), Ssd()
    rams = [Ram(h) for _, h in hwmons("spd5118")]
    devices = [cpu, *rams, ssd]
    last = time.monotonic()
    while True:
        draw(win, cpu, rams, ssd, c)
        win.timeout(max(0, math.ceil((last + INTERVAL - time.monotonic()) * 1000)))
        if win.getch() == ord("q"):
            break
        now = time.monotonic()
        if now >= last + INTERVAL - 0.005:
            for d in devices:
                d.sample(now - last)
            last = now


if __name__ == "__main__":
    curses.wrapper(main)
