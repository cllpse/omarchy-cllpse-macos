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

Gated on the machine, not just on the tool. 52W sustained is a number for this
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
before the PPT slow average reached 50W (the sustained limit then) and pulled it down. That average moves
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

Run on 2026-10-03 at the defaults, with the sustained limit at 50W (52W
since 2026-10-07; a higher sustained limit lengthens every burst window a
little, since the slow average has further to climb):

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
screen as braille lines, sampling every 500 ms, two samples per character
column, newest on the right. Each scale's labels sit in one column at the
right end beside the newest reading, right-aligned so their last characters
line up. In the 107-column tile a graph shows ~100 s. It sampled once a
second until 2026-10-07, one sample a column, and the 2000-sample history
holds ~17 minutes.
Standard-library curses, no root, `q` quits. It
is the live view for this folder's numbers, where thermal-log is the record and
`burst-bench.py` the measurement. Not run by `apply.sh`.

Every sample is also appended to a CSV a day in `~/.local/state/hwgraph/`
(`$XDG_STATE_HOME/hwgraph/`), as
`time,clock_ghz,cpu_w,cpu_c,ram1_c,ram2_c,ssd_c`, a failed reading left empty.
On start hwgraph replays the last 24 hours of it, so the graphs, *overall*
and *peak* survive a restart. Where samples are more than 5 s apart (hwgraph
closed, or the machine asleep) the line breaks for one sample instead of
joining old readings to new ones. A file with nothing in the last 24 hours is
deleted. The window is 24 hours because replay cost scales with it: a day at
500 ms is 172,800 rows, ~6.7 MB, replaying in ~0.65 s, where a week was 65 MB
and ~4.7 s. Only the first hwgraph running writes (an `flock` on `lock` in
the same directory). A second one replays and shows without logging, so no
sample is logged twice. A crash's half-written last line is closed off with
a newline on the next run and skipped on replay. Replay matches columns by
name, so a file from a run with other columns (a RAM stick added, or the log
from before `cpu_w` existed) still replays, empty for what it lacks. When the
columns change mid-day, the day's file is renamed `<date>.<time>.csv` rather
than mixed with the new one, and replays from there.

The CPU gets two graphs and a power line. Its clock is the average of every
core's `scaling_cur_freq` on 2.5-5 GHz (`cpuinfo_max_freq` is 4.97), six lines
0.5 GHz apart, so an idle average under 2.5 GHz runs along the bottom, under
the 2.5GHz line. Its scale ran
0-5 GHz in whole GHz until 2026-10-07, lost the 0 and 1 GHz lines that day
for four lines like every other graph (2-5 GHz), then went to half-GHz steps
for six. The scale column widened from six cells to seven for "2.5GHz".

Under the clock, *CPU – power* is a label row with no graph: current,
overall and peak of the PPT slow value, the long-average package power that
the sustained limit holds. It comes from `ryzen_smu`'s `pm_table`, where
RyzenAdj reads the limit at `0x10` and the value at `0x14` on every table
version. The limit, 52 W from `ryzen-tdp`, is read at start, and *current*
turns red at it like the temperatures do at theirs. With no `ryzen_smu`
module the line is left out. On 2026-10-07 it was a graph for a few hours,
the limit its red top line (0-50 W, then 20-50 W for four lines, 22-52 W
after the limit moved), before the graph went to give the others their six
lines. It reads the slow value rather than the burst (PPT fast) value because
that is the one the limit applies to: under load it sits flat on the limit,
where the fast value wobbles either side of it. That is
what the clock's wobble is. Under a 16-thread `stress-ng` matrixprod run on
2026-10-07, 8 minutes in, at the 50 W limit then, PPT slow read 50.0 of 50 W in every sample while
Tctl ran 87-89.6°C and the clock 4.22-4.44 GHz. The fast value moved
48-52.5 W, STAPM was 42.6 of 50 W and climbing, and the VRM currents and the
skin temperature had headroom. So the CPU was power-limited, not thermally
throttled, about 3°C under its 92°C limit, which is what lowering the
sustained limit from 52 W was for. Its higher peak comes from the opening
seconds, when it bursts towards 58 W until the slow average catches up (§3).

Its temperature is Tctl from `k10temp` on 17-92°C. Everything else graphs
temperature only. For a RAM stick that is all it reports of its own: usage is
system-wide and the clock is fixed. The readings come from the `spd5118`
driver, the SPD hub on each DDR5 SODIMM, which loads by itself on this kernel.
Sticks are ordered by I²C address (0x50, then 0x51) and drawn up to the
sticks' own `temp1_crit`, 85°C, in six lines 10°C apart (35-85), which puts
one on their 55°C `temp1_max`. On 2026-10-07 the steps were 15°C from 25°C,
then 20°C (25, 45, 65, 85) for four lines. They sit at ~42-58°C. The SSD graphs the
drive's Composite sensor (`temp1` of its `nvme` hwmon) on 15-90°C: it idles at
16-27°C, under the RAM floor, and the top line sits on its own 89.85°C
`temp1_max`. The CPU and SSD scales were 30-100°C and 15-85°C until
2026-10-06. Two blank rows under every graph left each one ~6 rows at full
height, where those spans' only fitting step was 35°, so both were retuned for
a 15° step, the CPU to 25-100°C. The first version (2026-10-04) also graphed
CPU utilisation and SSD busy time, with read/write MB/s; they were dropped to
keep the screen to clocks and heat.

The CPU and RAM graphs each draw their throttle point as a red dotted line,
with a red label. Both values were checked against the machine and its
vendors' specs on 2026-10-07.

For the CPU the limit is 92°C Tctl. This is Geekom's firmware limit (BIOS
0.62), under the 100°C maximum operating temperature (Tjmax) AMD lists for
the [Ryzen 7 8745HS](https://www.amd.com/en/products/processors/laptop/ryzen/8000-series/amd-ryzen-7-8745hs.html).
`ryzen_smu`'s `pm_table` is version `0x004C0009` here.
[RyzenAdj](https://github.com/FlyGoat/RyzenAdj/blob/master/lib/api.c) reads
that version's Tctl limit (`get_tctl_temp`) from offset `0x40` and its live
value from `0x44`. `0x40` reads 92.00, and `0x44` tracks `k10temp` (42.1
against 44.2 on a fresh read; the first read after idle returns a stale
table). The two skin-temperature (STT) limits beside it read 92.00 too. The
`ryzen-tdp` unit passes no `--tctl-temp`, so nothing here sets the limit. It
is also what a real load does: the all-core run in
[`ryzen-tdp.env`](ryzen-tdp.env) held Tctl at exactly 92.0°C for ~40 minutes,
the thermal limit rather than the power limit setting the clock. (`k10temp`
has no crit file to read it from, so the 92 is a constant.)

For the RAM the limit is 85°C, read from each stick's `temp1_crit`. Their SPD
data identifies both sticks as Crucial CT16G56C46S5: DDR5-5600 CL46 SODIMMs
with Micron DRAM, the laptop form factor of plain DDR5 rather than soldered
LPDDR5. Micron's
[DDR5 SODIMM datasheet](https://www.farnell.com/datasheets/4530576.pdf)
(`ddr5_sodimm_core.pdf`, Rev. F 05/23) puts the DRAM's commercial operating
case temperature at 0-85°C. Above 85°C, up to 95°C, the DRAM "must be
refreshed externally at 2X refresh", which costs bandwidth and is the nearest
a stick comes to throttling; its clock does not change. The same datasheet
rates the modules' X5R capacitors to 85°C, so 85°C is also the stick's own
ceiling. One caveat: those are DRAM case temperatures, measured at the
centre of each DRAM package. What hwgraph graphs is the sensor in the SPD hub
chip on the same stick, so it approximates them rather than measuring them.
The sticks' 55°C `temp1_max` is the hub's alarm threshold; nothing in
Micron's datasheet ties throttling to it.

A label can only sit mid-row, so a red line has to land on a
gridline. Each is its scale's top, with the steps counting down from it. That
is why the CPU moved from 25-100°C to 17-92°C, where its lines had fallen on
the RAM's; it reads 17, 32, 47, 62, 77, 92 (17, 42, 67, 92 while every graph
had four lines). The SSD's
top line is the drive's own warning temperature, and is left grey.

Every graph has a label row above it, naming what it graphs (*CPU –
frequency*, *CPU – temperature*, *RAM #1 – temperature* and so on; en dashes
since 2026-10-07, hyphens before), then three
figures: *current*, *overall* and *peak*, in that order on every row. The
figures are set in columns, the first two spaces past the longest name, so
each of the three lines up down the screen. *current* is the latest reading,
the right end of the line. On the CPU and RAM temperatures it turns red once it
reaches the graph's red throttle line, compared as displayed, so a `92.0°` on
screen is red even when the reading underneath is 91.96. *overall* is the
mean and *peak* the highest reading over the replayed 24 hours and everything
since. They meant "since hwgraph started" until the log came in on
2026-10-07. Both are kept apart from the 2000-sample history, so neither
forgets. All three figures are of the graphed series, so the
clock's peak is of the all-core average, not of one core. From 2026-10-06 to
2026-10-07 the first figure was *window*, the mean of the samples the graph
was showing. Before that, the label showed the current reading, the fastest
core and the highest temperature across the graph.

Gridlines are `┄` (U+2504), three dashes a cell, and every one is labelled.
They were `┈` (U+2508) until 2026-10-06, which Ghostty draws as four tiny
dashes a cell, so it read as a faint solid hairline. A middle dot (`·`, U+00B7)
was tried next and replaced the same day: U+2504's coarser dashes were the
choice. A label can only sit in the middle of a terminal row, so the scale is
fitted to put every line there too. It runs from the middle of the bottom row
to the middle of the top one, with the lines a whole number of rows apart.
Up to three blank rows separate each block from the next (four from
2026-10-06 to 2026-10-07): the most, up to three, that still leaves every
graph all six lines. The power line is the exception: a label-only block
sits one blank row under the graph above it, so it reads as part of the
clock's block. Nothing else separates the devices: a solid rule above
each of RAM #1, RAM #2 and SSD was dropped on 2026-10-06. There are none
under the last graph, where they would separate nothing. A window too short
for six lines everywhere even with no gaps takes the widest gap that still
gives each graph its low and high lines.

Every graphed scale has one step, the one that gives it six lines. The
rows that are left go to the graphs by need. Every graph starts with only
its low and high lines. The one with the fewest lines then takes its six,
the cheapest first on a tie, while rows last. The two RAM sticks share one
scale and move together. Rows still spare stretch every graph's line spacing
together, or none, so the graphs keep one height. The full-height tile on
this screen is 49 rows (read with `stty size` on the live terminal). Five
graphs of six rows and six labels are 36 rows; one blank row above the power
line and three-row gaps between the other blocks are 13 more, 49 exactly.
With the power line spaced like every other block, three-row gaps needed 51,
so the 49-row tile got two-row gaps for the few hours that lasted. A
quarter-height tile (25 rows) gets two-row gaps and only low and high lines.
While every graph had four lines (2026-10-07), the 49-row tile fit three-row
gaps with four rows to spare.

Until 2026-10-07 each scale had several candidate steps, and the finest that
fit won. That gave the 49-row tile 1 GHz, 25 W, 25°C for the CPU and SSD and
30°C for the RAM, with four-row gaps. It also stretched the shortest graph
first, so heights differed. An equal split before that gave every graph 5
rows, so the clock showed only 0 and 5GHz and the CPU and SSD 25°C. The equal
split's earlier sizes were worked out for 51 rows, not 49, so what was
claimed for them (6 rows a graph, then 7 with the RAM at 10°C) was a row
out. Blocks stack by the rows their graphs use, and any spare rows collect
at the bottom. Drawing each gridline at its exact sub-row height in braille
was tried first and dropped, because labels then sat up to 3/8 of a row off
their line, above some and below others.

Each reading is a braille dot: a cell is 2 dots wide and 4 tall, so a column
holds two samples and a reading lands within an eighth of a row of its
height. Each dot joins the one before it with a vertical run, so a step
draws as a continuous line. A reading off the scale sits in the half row
beyond its end line, and a break leaves the line unjoined. Where the line
crosses a gridline it replaces it. Until 2026-10-07 the graphs were solid
bars of eighth-blocks (`▁`…`█`), one sample a column. They read as blocky,
so a braille area fill and the braille line were rendered side by side from
the log, and the line was the choice. A bar stood on the graph's bottom edge,
half a row under the low line, since a block can only grow from a cell's
bottom; starting it at the line hid any reading in the lowest quarter-row.

It exists because neither tool already installed or packaged gives that
picture, checked on 2026-10-04. btop 1.4.7 graphs one temperature
(`cpu_sensor`), so pointing it at a stick replaces Tctl, and it prints the
clock as text. s-tui reads every sensor and shows all of them at once, 16
cores of clock and utilisation plus every hwmon on the board. Sensors are found
by hwmon name rather than number, so boot order doesn't matter. A missing
`k10temp` or `nvme` sensor exits with a message, and with no `spd5118` the RAM
rows are left out.

## From the step table

CPU power limits: `ryzenadj` at 52W sustained / 58W burst, reapplied at **boot
and on resume** by `ryzen-tdp.service` — runtime SMU settings persist across
neither, so a machine tuned by hand is back at the firmware's 45W the next
morning with nothing on it to say so. **Hardware-gated**: the step refuses
unless `/proc/cpuinfo` reads 8745HS and DMI reads GEEKOM/A8, because 52W is a
number for one chassis, not a general setting. It was 50W from 2026-10-02,
after a 40-minute all-core load held Tctl pinned at the firmware's 92°C while
drawing only 51.3W of 52W, and back to 52W on 2026-10-07, after hwgraph showed
50W power-limited ~3°C under 92°C — see `ryzen-tdp.env` for both. 58W burst was measured against
50, 54 and 62W with `burst-bench.py` (§3): 62W is 1.1% faster on a ~5s burst
and no faster on a ~12s one. **Opt-in**: `--all` and **Run everything** skip
it; run `apply.sh ryzen`, or tick it under **Choose specific steps…**. Needs
**sudo**, and does not install `ryzenadj`

Script: [`ryzen.sh`](ryzen.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
