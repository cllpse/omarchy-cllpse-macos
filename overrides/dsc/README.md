# DSC bit rate on the TV's link

Forces the compression on the Samsung TV's DisplayPort link from amdgpu's 12 bpp
(2:1) to 20 bpp (1.2:1) at 4K120, through two amdgpu debugfs files that a boot
unit sets again on every boot. Hardware-gated, opt-in, and needs sudo.

```bash
./overrides/apply.sh dsc            # install, enable, apply now (sudo)
sudo cllpse-dsc-bpp status          # what the GPU is sending
sudo cllpse-dsc-bpp off             # amdgpu's own 12 bpp, until the next boot
sudo cllpse-dsc-bpp on              # the forced rate again
```

## 1. Why amdgpu picks 12 bpp

The chain is GPU → USB-C (DisplayPort, 4 lanes) → Synaptics VMM7100 →
HDMI 2.1 FRL → TV. 4K120 in 8-bit RGB is 28.5 Gbps and the DisplayPort link
carries 25.92 (25.14 once DSC turns FEC on), so DSC is unavoidable above 60 Hz.
The adapter decodes it and sends the TV uncompressed RGB at FRL 48 Gbps.

Read from the v7.2 amdgpu source and checked live on 2026-10-12:

- **amdgpu plans the stream for the TV.** `update_dsc_caps` (`amdgpu_dm.c`):
  when a DP-to-HDMI converter reports DSC passthrough and FRL, and the TV's
  HDMI Forum block advertises DSC, the bit rate comes from the TV's HDMI DSC
  caps (`dc_dsc_parse_dsc_edid`, `is_frl`).
- **The TV's caps allow 12.** `hdmi_dsc_get_bpp` (`dc_dsc.c`) caps at 12 bpp
  when the sink lacks `DSC_All_bpp`, which this TV does not set, and CTA timings
  like 4K120 (VIC 118) get a fixed preset.
- **Then the adapter decodes it anyway.** `dm_helpers_dp_write_dsc_enable`
  writes `DP_DSC_ENABLE = 0x01` (decode at the converter) for a single-stream
  converter, never `0x02` (passthrough). Live: DPCD `0x160` reads `01`, and the
  adapter's HDMI side trains FRL 48, above the TV's 24 Gbps limit for DSC. The
  TV never sees a compressed stream; its limit sizes one it never decodes.

Two debugfs files change that:

- `dsc_disable_passthrough` = 1 sends amdgpu to the adapter's own DPCD caps,
  which cap at 14 bpp (`0x67–0x68` = `0x00E0`: formally an eDP field, which
  amdgpu applies to every sink as `edp_sink_max_bits_per_pixel`).
- `dsc_bits_per_pixel` replaces the rate after every limit has been applied:
  hex, in sixteenths of a bit, `0x0` to hand it back.

Gated on the TV and the adapter, both readable without root: the EDID's
manufacturer and product code (`SAM:30707`, the HDMI 2.1 EDID the TV serves
with Input Signal Plus on) on an amdgpu output, and the adapter's USB id
(`06cb:7100`). 20 bpp is a number for this decoder on this link; on another
display it is a guess.

## 2. The boot unit

amdgpu keeps both settings in RAM, per connector, and nothing resets them but
a reboot: they survive suspend, the TV going off and on, and a replug.
`cllpse-dsc.service` runs `cllpse-dsc-bpp boot`, which polls until the TV is up
and then:

- **at a mode without DSC** (the console's 4K60), sets both files once, so
  Hyprland's first DSC modeset already uses them;
- **at a DSC mode**, reads the rate the decoder runs at, and sets it again (up
  to three times) until it matches. The bpp write is silently dropped when no
  stream is driving the connector, so only the read-back proves it took.

The bpp write also flags the connector for a full re-modeset on the next frame
(`dsc_force_changed` → `mode_changed`), so it lands without Hyprland's help, as
one blink of the TV. Passthrough is written first so that modeset sees both.

It is `Type=exec`, not `oneshot`: it waits for Hyprland's first mode, and a
oneshot wanted by `multi-user.target` would hold the boot, and so the login,
until it returned.

**Only modes the rate fits.** 20 bpp fits 4 lanes of HBR3 up to a pixel clock
of about 1.24 GHz: the TV's own 4K100 and 4K120 (1188 MHz), not 4K144 (1333)
or 4K165 (1543). amdgpu rejects a modeset whose stream does not fit, so the
helper reads the mode from the DRM atomic state and never writes at one above
`DSC_MAX_CLOCK_KHZ`. Once set, though, the override stays: switching to 165 at
runtime is rejected until `sudo cllpse-dsc-bpp off`.

**`echo` cannot write `dsc_disable_passthrough`.** Its handler returns 0 bytes
written instead of the count, so a shell's `echo 1 >` retries forever, as a
root process spinning a core and setting the value on every retry. The helper
writes once, with `os.write`.

## 3. The numbers

At 4K120 (1188 MHz, 4 slices of 960 pixels), against 25.14 Gbps (4 lanes ×
8.1 Gbps, 8b/10b, FEC 97%) plus amdgpu's DSC overhead of 0.28 Gbps:

| bpp | hex | compression | link use | |
|---|---|---|---|---|
| 12 | `0xC0` | 2:1 | 14.5 Gbps | amdgpu's choice, HBR2 |
| 14 | `0xE0` | 1.7:1 | 16.9 Gbps | the adapter's stated maximum |
| **20** | **`0x140`** | **1.2:1** | **24.0 Gbps** | **this override**, HBR3 |
| 20.875 | `0x14E` | 1.15:1 | 25.08 Gbps | the ceiling, no margin |

amdgpu's budget ignores spread-spectrum clocking, which can take up to 0.5% off
the link, so 20 leaves 4% rather than sit at the ceiling.

Tried on 2026-10-12, 40 seconds each: 14 bpp and 20 bpp. debugfs read 224 and
320, the link trained HBR3, `0x160` stayed `01` (the adapter decodes), FRL 48.
At 20 bpp the picture was fine, with no difference anyone could see. That
was expected: DSC is visually lossless at 12 bpp already, so the gain is
margin on the hardest content, not something visible in use.

## Checking and undoing

`sudo cllpse-dsc-bpp status` names the mode's pixel clock and the rate the
decoder runs at, and whether it is the forced one. `journalctl -u cllpse-dsc`
says what the boot run did; a unit that finished reads `inactive (dead)`, which
is success. `revert.sh` hands the rate back to amdgpu and removes the unit, the
helper and `/etc/default/cllpse-dsc`.

## The files here

| file | installed to | what it is |
|---|---|---|
| [`dsc.sh`](dsc.sh) | — | the apply step (sudo): gate, install, enable, apply now |
| [`cllpse-dsc-bpp`](cllpse-dsc-bpp) | `/usr/local/bin/` | the root helper: `boot`, `on`, `off`, `status` |
| [`cllpse-dsc.env`](cllpse-dsc.env) | `/etc/default/cllpse-dsc` | the rate, the clock limit, the TV and adapter ids |
| [`cllpse-dsc.service`](cllpse-dsc.service) | `/etc/systemd/system/` | runs `cllpse-dsc-bpp boot` at every boot |

Script: [`dsc.sh`](dsc.sh) — runnable on its own; [`../apply.sh`](../apply.sh) owns the order.
