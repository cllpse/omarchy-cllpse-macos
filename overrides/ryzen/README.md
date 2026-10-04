# CPU power limits

ryzenadj sustained/burst limits, reapplied at boot and on resume by a systemd unit. Hardware-gated, opt-in, and needs sudo.

## 1. ryzenadj sets the SMU's sustained/burst power limits at

ryzenadj sets the SMU's sustained/burst power limits at runtime and NOTHING
persists them: they are lost on every reboot and on every resume from suspend.
A machine tuned by hand is therefore back at the firmware's 45W the next
morning, with nothing on it to say so -- which is exactly what had happened
here. The unit is wanted by the sleep targets as well as multi-user for that
second half; a plain WantedBy=multi-user.target survives a reboot and not a
suspend.

Gated on the machine, not just on the tool. 50W sustained is a number for this
CPU in this chassis, and pushing it onto different hardware is a thermal
decision made by accident -- so the model and the DMI product have to match
before anything is written. Everything else in this repo is cosmetic if it
lands somewhere unexpected; this is not.

Verification needs no root: ryzen_smu exposes the live limits as world-
readable floats at /sys/kernel/ryzen_smu_drv/pm_table (STAPM limit first,
then its value, then PPT fast, then PPT slow), which is a far better check
than `ryzenadj --info` since it can be read after the fact, by anything.

## 2. `enable --now` is idempotent and also starts it

`enable --now` is idempotent and also starts it, so the limits land in this
session rather than at the next boot. A oneshot that has already run reports
inactive (dead), which is success -- so the limits are read back from the
SMU instead of from systemctl.

## 3. Measuring the burst limit: `burst-bench.py`

The sustained limit was settled by thermal-log catching a long load pinned at
92°C. The burst limit can't be settled that way: it acts in the first seconds
of a load, until the PPT slow average catches up, and thermal-log samples every
10s. [`burst-bench.py`](burst-bench.py) times a fixed amount of all-core work
(`stress-ng` matrixprod, a fixed `--cpu-ops` count, so a faster limit shows up
as a shorter run) at each burst limit. The limits are shuffled within every
round so drift lands on all of them, and each run waits for Tctl and the PPT
slow average to return near idle first, since both decide how much burst the
next run gets. Defaults: 50/54/58/62W × one ~5s size × 3 rounds = 12 runs,
~6 min, raw runs to `~/.local/share/burst-bench/`; `--sizes` and `--rounds`
take more.

Why one ~5s size: sampled at 100ms from idle, a 58W burst held 58W for ~8.6s
before the PPT slow average reached 50W and pulled it down. That average moves
with a ~5s time constant, which puts the window at ~11.5s for 54W and ~7s for
62W -- so ~5s is all burst at every limit tested. A first version also ran ~1s
and ~10s sizes over 5 rounds, 60 runs and ~25 min: the 1s runs measured the
same window plus `stress-ng`'s startup jitter, and the 10s ones mixed in the
sustained limit and had the longest cool-down. The same trace sized the
cool-down gate: after a 10s burst the slow average was within 3W of idle, and
Tctl within 5°C, after ~12s. In practice a ~5s run waits ~21s, Tctl's last few
degrees being the slow part, and three runs at 58W agreed to 1.1%
(4.792-4.844s). The idle those gates compare against is taken once Tctl and
the slow average stop falling, not as a snapshot: started straight after a
load, a snapshot read 67°C and 22.6W against a real ~48°C and ~9W.

It needs sudo for `ryzenadj`, holds Omarchy's idle off for the duration (the
screensaver is a CPU load of its own and starts at 150s), and restarts
`ryzen-tdp.service` on exit, Ctrl-C included, so the env file's limits are what
it leaves behind. Same hardware guard as `ryzen.sh`. Not run by `apply.sh`.

Smoke-tested at 58W only: a ~3s burst averaged 56W, so the burst limit is in
play for loads that short, and two ~1s runs differed by 9% (1.010s vs 1.106s)
where two ~3s runs agreed to 0.1%.

Run on 2026-10-03 at the defaults:

| burst | ~5s run | vs 58W | peak Tctl | avg MHz |
|---|---|---|---|---|
| 50W | 5.165s | +3.3% | 74.4°C | 4431 |
| 54W | 5.079s | +1.6% | 76.0°C | 4510 |
| 58W | 5.000s | -- | 79.9°C | 4566 |
| 62W | 4.943s | -1.1% | 82.0°C | 4614 |

No two ranges overlapped, every round came out in the same order, and the clock
moves with the timing, so this is the limit and not noise. 50W is no burst at
all (PPT fast equal to the sustained limit), so 58W's whole contribution is
3.3%: ~165ms on a 5s load, 12°C under the setpoint. Each watt bought ~0.4% up
to 58W and ~0.3% past it. `--limits 58,62 --sizes 12` then compared the top two
on a ~12s load: 11.924s at 58W against 11.949s at 62W, inside 58W's own
11.892-11.991s range, with 62W drawing 1.4W more and peaking ~2°C hotter. A
higher fast limit spends the PPT slow budget sooner. Back-calculated from the
average draw (not traced), 62W stopped bursting at ~8.5s and 58W at ~10.5s, and
those two seconds leave 62W ~30ms ahead on paper, under the ~100ms spread of
58W's own runs. Both windows are longer than the 100ms trace's because this run
started from a cooler idle (PPT slow ~4.6W), and the window grows the further
the average has to climb. 58W stays: the watts past it buy ~60ms on a 5s load
and nothing measurable on a 12s one.

## 4. Watching it live: `hwgraph.py`

[`hwgraph.py`](hwgraph.py) graphs the CPU, each RAM stick and the SSD on one
screen, one column per second, newest on the right, each scale at the right
end beside the newest reading. Standard-library curses, no root, `q` quits. It
is the live view for this folder's numbers, where thermal-log is the record and
`burst-bench.py` the measurement. Not run by `apply.sh`.

The CPU gets two graphs. Its clock is the average of every core's
`scaling_cur_freq` on 0-5 GHz (`cpuinfo_max_freq` is 4.97), with the fastest
core in the label. Its temperature is Tctl from `k10temp` on 30-100°C, which
keeps the firmware's 92°C setpoint on the scale. Everything else graphs
temperature only. For a RAM stick that is all it reports of its own: usage is
system-wide and the clock is fixed. The readings come from the `spd5118`
driver, the SPD hub on each DDR5 SODIMM, which loads by itself on this kernel.
Sticks are ordered by I²C address (0x50, then 0x51) and drawn from 25°C to the
sticks' own `temp1_crit`, 85°C, a floor chosen so every gridline step also
lands on their 55°C `temp1_max`. They sit at ~44-49°C. The SSD graphs the
drive's Composite sensor (`temp1` of its `nvme` hwmon) on 15-85°C, because it
idles at 16-27°C, under the RAM floor. The first version (2026-10-04) also
graphed CPU utilisation and SSD busy time, with read/write MB/s; they were
dropped to keep the screen to clocks and heat.

Every temperature's title carries two peaks after the current reading.
*visible* is the highest across the samples the graph is showing, so it
forgets as history scrolls off the left edge, and a wider window remembers
longer. *overall* is the highest since hwgraph started, kept apart from the
2000-sample history so it never forgets. The CPU's fastest-core clock is
labelled *fastest* rather than *peak* so the word means one thing.

Gridlines are dotted (`┈`), and every one is labelled. A label can only sit in
the middle of a terminal row, so the scale is fitted to put every line there
too. It runs from the middle of the bottom row to the middle of the top one,
with the lines a whole number of rows apart, at the finest step that fits:
1 GHz and 10°C in a full-height window, three lines per graph in a half-height
tile. Rows that don't divide evenly are left blank below. Bars stand on the
graph's bottom edge, half a row under the lowest line, because a block can
only grow from a cell's bottom. Starting them at the line instead hid any
reading in the lowest quarter-row. A bar's top is what reads against the
lines. Drawing each line at its exact sub-row height in braille was tried
first and dropped, because labels then sat up to 3/8 of a row off their line,
above some and below others.

It exists because neither tool already installed or packaged gives that
picture, checked on 2026-10-04. btop 1.4.7 graphs one temperature
(`cpu_sensor`), so pointing it at a stick replaces Tctl, and it prints the
clock as text. s-tui reads every sensor and shows all of them at once, 16
cores of clock and utilisation plus every hwmon on the board. Sensors are found
by hwmon name rather than number, so boot order doesn't matter. A missing
`k10temp` or `nvme` sensor exits with a message, and with no `spd5118` the RAM
rows are left out.

## From the step table

CPU power limits: `ryzenadj` at 50W sustained / 58W burst, reapplied at **boot
and on resume** by `ryzen-tdp.service` — runtime SMU settings persist across
neither, so a machine tuned by hand is back at the firmware's 45W the next
morning with nothing on it to say so. **Hardware-gated**: the step refuses
unless `/proc/cpuinfo` reads 8745HS and DMI reads GEEKOM/A8, because 50W is a
number for one chassis, not a general setting. It was 52W until a 40-minute
all-core load held Tctl pinned at the firmware's 92°C while drawing only 51.3W
of it — see `ryzen-tdp.env` for the measurement. 58W burst was measured against
50, 54 and 62W with `burst-bench.py` (§3): 62W is 1.1% faster on a ~5s burst
and no faster on a ~12s one. **Opt-in**: `--all` and **Run everything** skip
it; run `apply.sh ryzen`, or tick it under **Choose specific steps…**. Needs
**sudo**, and does not install `ryzenadj`

Script: [`ryzen.sh`](ryzen.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
