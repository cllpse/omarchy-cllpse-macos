# CPU power limits

ryzenadj sustained/burst limits, reapplied at boot and on resume by a systemd unit. Hardware-gated, and needs sudo.

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
as a shorter run) at each burst limit, in ~1s, ~3s and ~10s sizes calibrated at
the configured limit. The limits are shuffled within every round so drift lands
on all of them, and each run waits for Tctl and the PPT slow average to return
to idle first, since both decide how much burst the next run gets. Defaults:
50/54/58/62W × 3 sizes × 5 rounds = 60 runs, ~25 min, raw runs to
`~/.local/share/burst-bench/`.

It needs sudo for `ryzenadj`, holds Omarchy's idle off for the duration (the
screensaver is a CPU load of its own and starts at 150s), and restarts
`ryzen-tdp.service` on exit, Ctrl-C included, so the env file's limits are what
it leaves behind. Same hardware guard as `ryzen.sh`. Not run by `apply.sh`.

Smoke-tested at 58W only: a ~3s burst averaged 56W, so the burst limit is in
play for loads that short, and two ~1s runs differed by 9% (1.010s vs 1.106s)
where two ~3s runs agreed to 0.1% -- the 1s size needs every one of its rounds.

## From the step table

CPU power limits: `ryzenadj` at 50W sustained / 58W burst, reapplied at **boot
and on resume** by `ryzen-tdp.service` — runtime SMU settings persist across
neither, so a machine tuned by hand is back at the firmware's 45W the next
morning with nothing on it to say so. **Hardware-gated**: the step refuses
unless `/proc/cpuinfo` reads 8745HS and DMI reads GEEKOM/A8, because 50W is a
number for one chassis, not a general setting. It was 52W until a 40-minute
all-core load held Tctl pinned at the firmware's 92°C while drawing only 51.3W
of it — see `ryzen-tdp.env` for the measurement. Needs **sudo**, and does not
install `ryzenadj`

Script: [`ryzen.sh`](ryzen.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
