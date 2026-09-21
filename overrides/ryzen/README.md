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

## From the step table

CPU power limits: `ryzenadj` at 52W sustained / 58W burst, reapplied at **boot and on resume** by `ryzen-tdp.service` — runtime SMU settings persist across neither, so a machine tuned by hand is back at the firmware's 45W the next morning with nothing on it to say so. **Hardware-gated**: the step refuses unless `/proc/cpuinfo` reads 8745HS and DMI reads GEEKOM/A8, because 52W is a number for one chassis, not a general setting. Needs **sudo**, and does not install `ryzenadj`

Script: [`ryzen.sh`](ryzen.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
