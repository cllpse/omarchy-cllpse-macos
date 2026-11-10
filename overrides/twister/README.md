# twister/ — the Midi Fighter Twister's LEDs: a turn sets the colour, a push plays an animation

Step 7k, **opt-in** (`apply.sh twister` or the checklist; `--all` skips it).
It is on-device: a custom build of DJ TechTools' open-source firmware with
two new switch actions and one new per-encoder flag. On all sixteen encoders
of bank 4, the LED's colour follows the knob's value (*colour from rotation*)
and a push plays a two-second one-shot animation (action 10, *colour
toggle* by its first name): on the pressed encoder alone, and every third
press a colour shift across all sixteen LEDs. The first action added,
*colour cycle* (9, a press steps through a twelve-colour palette), stays
available for any switch. Nothing runs on
the host afterwards. The unit has carried the build since 2026-11-02.

## Why a firmware build

The stock firmware's nine switch actions are CC/Note Hold and Toggle, two
encoder resets, Fine Adjust, and Shift Hold/Toggle (`encoders.h`,
`enc_sw_action_type_t`). None changes the LED colour beyond the two-state
active/inactive pair, so "cycle through the colours on press" is either a host
daemon answering each press over MIDI (the firmware does take colour overrides
that way: the switch's own CC back with a colour-map index) or a firmware
change. The daemon was built and worked; the user wanted it on the device. That
version is not kept here — it is one sequencer client with twelve lines of
logic, and the firmware route makes it moot.

DJ TechTools publishes the source
([`DJ-TechTools/Midi_Fighter_Twister_Open_Source`](https://github.com/DJ-TechTools/Midi_Fighter_Twister_Open_Source),
licence: owners may view and modify for personal use, not redistribute), with
every official hex in its `Release/` folder and the bootloader hex beside them.

## What the patch does (`color-cycle.patch`, 9 files)

Against commit `782f9533` (2026-08-24):

- `encoders.h`: `SW_COLOR_CYCLE` appended to the action enum, value **9**.
  EEPROM stores the action in a nibble, so up to 15 fit.
- `encoders.c`: the case in `process_encoder_input_switch`. On press the LED
  moves to the next entry of a twelve-entry palette and that index becomes the
  encoder's **inactive colour**, in RAM and in EEPROM (one byte, the same
  address arithmetic as `get_encoder_config`), so it survives bank changes and
  power loss and the Utility shows it. The switch's CC still goes out as for
  CC Hold (127 on press, 0 on release), so a host sees the press; the action
  is added to `send_element_midi`'s CC list for that. The colour is written
  straight to the colour buffer, override or not: a press is the user's intent,
  and a later MIDI colour lands on top as before.
- `main.c`, *standalone mode*: the unit runs on a power bank, see *Running
  without a computer* below.
- `side_switch.c`, `constants.h`: the six side buttons do nothing at all
  (`CLLPSE_NO_SIDE_SWITCHES`: `process_side_switch_input` returns before
  reading them, so no bank change, no shift page, no native-mode combo, no
  MIDI). Asked for with the standalone work: "I don't want to be able to use
  the side buttons at all".
- `encoders.c`, `constants.h`: the last selected bank is kept in EEPROM
  (`EE_BOOT_BANK`, 0x0012, a free byte after the global settings, written by
  `change_encoder_bank` on a change only) and `encoders_init` starts there;
  0xFF, never set, means bank 1 as stock. Needed once the side buttons were
  gone: stock boots into bank 1 and the animations live on bank 4, and with
  no side buttons the only other way to change bank is a host sending CC 0-3
  on the system channel. Bank 4 was selected that way after the flash, so it
  is what the unit comes up in.
- `display_driver.h`, `display_driver.c`, `encoders.c`: the red/blue ring LED
  tinted from the shown colour, see *The ring cannot take the LED's colour*
  below; `ms_ticks` and the six detent one-shots, see *Landing on the detent
  value*.
- `encoders.h`, `encoders.c`: `SW_COLOR_TOGGLE`, value **10**, the
  animation trigger (`anim_trigger`): a press starts a local one-shot on the
  encoder, every third press across the unit a global colour shift. It was
  first a hide/show toggle for the LED, dropped the same day on request
  ("skip the turning off the LED part"); the enum name stayed so the stored
  value's meaning in old backups is unambiguous. The CC goes out as CC Hold's
  would. `prevSwitchColorValue` moved up the file for it.
- `encoders.h` + `encoders.c` + `config.c`, *colour from rotation*: a 16th
  config field, `color_from_rotation`, stored as bit 7 of the active-colour
  EEPROM byte (the one free bit that sits next to a colour; the Utility only
  ever writes 7-bit values there, so it stays 0 for anyone else) and carried
  as SysEx tag **25** in the bulk pull and push. With it set, the one place
  every value change passes through on its way to the LEDs
  (`update_encoder_display_single`, where the indicator is redrawn) also
  rewrites the colour buffer and the RAM inactive colour from the value:
  `1 + value·118/127`, index 1..119 of the classic map, a full turn of the hue
  wheel (blue, green, yellow, red, magenta, purple) without the near-duplicate
  dim blues at 120..126 or off at 0. The RAM inactive colour too, so a CC Hold
  release puts the rotated colour back rather than the configured one. The
  forced redraws at power-up and after a bank change go through the same
  hook, so the LED shows the value's colour from the first frame (blue at 0)
  instead of the configured inactive colour until the first turn, which is
  how it first shipped and read as "no colour until I turn it" with bank 4's
  colours configured off (2026-11-02). Never EEPROM, since a turn is many
  ticks and the colour lives as long as the value does, which resets at
  power-up anyway. MIDI feedback that moves the value moves the colour as
  well. With the flag on, the palette cycle (9) on the same switch holds only
  until the next redraw: the value's colour wins.
- `constants.h`: `EXTENDED_BANKS` commented out, the comment's own invitation:
  the 2026 source defaults to eight banks and no sequencer, this unit's config
  is laid out for four, and the official plain release is the four-bank build
  (its hex is 40 KB, the `_8banks` one 33 KB; ours is 39 KB).
- `colorMap.h`: `ASF.H` → `asf.h`, the one include whose case only Windows
  resolves.

The palette, as indices into the firmware's classic colour map (what this unit
draws from; the 2026 firmware adds an MF64-matching map behind a global
setting, which the restore leaves at classic):

| index | 85 | 69 | 64 | 62 | 47 | 36 | 22 | 17 | 1 | 96 | 107 | 0 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| colour | red | orange | yellow | lime | green | spring green | cyan | azure | blue | violet | magenta | off |

0 is "LED off" as an inactive colour. 126 and 127 are left out: the MIDI
colour path refuses them too (they fall back to the active colour). A colour
the encoder already shows that is not in the table starts the cycle at red.
Editing the table is the `cycle_colors[]` line of the patch, then `build` and
`flash`.

## Building on Linux (`Makefile.linux`)

The project is a Microchip Studio solution; the Makefile is its flags and
source list (61 C files plus `nvm_asm.s`, from the `.cproj`) minus the Windows
paths and the device pack: Arch's `avr-libc` ships the ATxmega128A4U header
and `avr-gcc` the device spec. Two things the 2026 toolchain needs that
Atmel's GCC 5 did by default: `-fcommon` (the headers hold tentative
definitions of the globals, merged at link), and the include-case fix above.
Everything else compiles as is under avr-gcc 16.2. Warnings worth knowing:
eight *excess elements in array initializer* in `constants.h` are the
per-bank default-colour tables holding eight entries for the four-bank arrays,
dropped on purpose; the `-Wrestrict` one is LUFA's HID parser, untouched.

`twister.sh build` clones the source into `~/.cache/cllpse-macos/twister/repo`,
checks out the pinned commit, applies the patch, drops the Makefile in and
builds; `build.log` sits beside it. Output: `repo/build/twister.hex`, 0x9900
bytes of the 0x20000 application section, nowhere near the bootloader above it.

## Flashing (`twister.sh flash`, sudo)

The Twister carries Atmel's XMEGA DFU bootloader (USB `03eb:2fde`), reached
from the running firmware by SysEx `F0 00 01 79 03 01 F7` (system command 1:
set a magic key, watchdog-reset, the init-section check jumps). Then
`dfu-programmer atxmega128a4u erase --force | flash | launch`. `erase` is the
application flash only; the EEPROM and the bootloader section are not touched.
Fallback: the official `Release/0005000120260702.hex` (2026-07-02, four banks)
in the clone, flashed the same way — or the DJTT utility's own updater.

**The new firmware factory-resets the EEPROM once.** `eeprom_init` compares a
layout-version byte and resets everything when it differs, and it differs
between the 2019-10-02 firmware this unit had and the 2026 source: every
encoder came back at defaults, side buttons included. So `flash` pulls every
setting first (`$STATE/twister-config-<stamp>.txt`), diffs after the reboot,
and replays the backup when it finds the reset. A pull reply is already a push
message (the firmware answers a pull *with* pushes), so the encoder lines
replay verbatim; the global settings go as one push of the backed-up pairs
plus the tags the new firmware added (colour map, animation channels, sleep,
bank animations), taken from its own defaults. Then it sets the switch action.
`config-backup-2026-11-02.txt` is that day's backup, kept as the record of what
the unit was configured as before the flash.

Rotation colour is `twister.sh rotation on|off [bank]` and a switch action for
a whole bank is `twister.sh switches ACTION [bank]`, each sixteen bulk pushes
and one global push. Bank 4 has rotation on and action 10 on every switch;
the step (`status`) checks the top-left and sets the whole bank when it is
off. `twister.sh set <tag> 9` puts the palette cycle on one switch instead.

## Running without a computer

Asked for last and called the most critical part: the unit on a power bank,
no computer. Stock, it cannot: `main()` disables the display, and the only
thing that enables it and starts the normal mode is
`EVENT_USB_Device_ConfigurationChanged`, LUFA's event for a USB *host* having
configured the device. A power bank supplies VBUS and nothing else, so the
device sits in `DEVICE_STATE_Powered` for ever, dark, with `Midifighter_Task`
returning at its first line. (The firmware has a vestige of the same idea:
`ENABLE_LEGACY_MIDI_USART_OUTPUT`, a scheduled fall-back to serial MIDI when
no host appears, off because it broke enumeration on cold-booting computers.)

The patch adds `standalone_mode`: `main_loop` watches `ms_ticks`, and if no
host has configured the device `STANDALONE_AFTER_MS` (1000; 2500 at first,
the user wanted one second) after power-up,
`enter_standalone` does what the configuration event does: display on, the
start-up sparkle, normal mode, display refresh, watchdog. `Midifighter_Task`
no longer returns early in that mode. Everything else is untouched because
LUFA's MIDI calls (`MIDI_Device_SendEventPacket`, `_ReceiveEventPacket`,
`_USBTask`, `_Flush`) all return at once while the device is not configured,
so turning, pressing and the animations work with the MIDI going nowhere. A
host that turns up later (plugging the cable into a computer) configures the
device as usual; the event clears the flag and the unit carries on as a
controller. A computer that takes longer than a second to enumerate it (a
cold boot with the cable in, or a slow hub) gets the sparkle twice, nothing
worse: the standalone start and the host's configuration both end in the
same state.

Clocking is unaffected: the CPU runs from the PLL on the 2 MHz RC; the DFLL
that trims the 32 MHz RC to 48 MHz against USB start-of-frame only matters
for USB itself. Sleep is unchanged: after the configured timeout without
input (60 min as shipped here) the sleep animation runs, rainbow wave as
configured. Two things the firmware cannot fix: a power bank that switches
off below a load threshold (the unit with its LEDs lit is well above the
usual ~60 mA, dimmed or asleep it may not be), and the fact that there is no
battery: unplugging is a power cycle, so colours start over at blue and the
animation counters at zero, like the indicator values always did.
## A push plays a one-shot animation

A press of a switch with action 10 starts a two-second animation, drawn
straight into the frame buffer from the main loop like the stock animations,
after which the normal display is forced to redraw. Presses are counted
across the unit: two in three play one of six *local* animations on the
pressed encoder alone, every third plays one of four *global* colour shifts
on all sixteen LEDs (the rings stay live underneath). Each set is taken in
turn so successive presses differ. The trigger was first "landing on the
detent value 63/64 by turning", moved to the push on request the same day.

The local six:

| # | name | ring | LED |
|---|---|---|---|
| 0 | spin | a dot laps the ring every 330 ms | breathes at 2 Hz in its colour |
| 1 | burst | a spread from 12 o'clock out to the full ring and back, four times | strobes at 8 Hz |
| 2 | rainbow | the whole ring breathes | sweeps the hue wheel twice; the red/blue LED follows |
| 3 | bounce | a dot bounces end to end every 400 ms | solid; the red/blue LED alternates every 100 ms |
| 4 | fill | fills from the left in half a second, drains from the left, twice | brightness follows the level |
| 5 | sparkle | three random LEDs every 50 ms | white, flickering |

The global four (RGB LEDs and their red/blue tints only):

| # | name | what |
|---|---|---|
| 0 | wave | a rainbow rolls across the grid by column and row, two full wheels in the two seconds |
| 1 | ripple | hue and brightness radiate from the pressed knob by grid distance |
| 2 | twinkle | every LED jumps to a new colour and level every 100 ms |
| 3 | spotlight | every LED takes the pressed knob's colour and breathes, the pressed one solid |

A global shift starting while a local one runs takes the LED; the local one
keeps its ring. Time comes from `ms_ticks`, a 16-bit counter added to the display's
animation timer (127 ticks of 32 MHz/256 = 1.016 ms); the stock `idle_timer`
is reset by every input and `animation_counter` runs on MIDI clock, so
neither serves. Integer maths only; the randomness is a xorshift. 2 seconds
is `ONESHOT_MS`; the sets are `oneshot_draw` and `global_draw` in
`encoders.c`, the cadence `anim_trigger`.

## The ring cannot take the LED's colour; its red/blue LED carries a tint

Asked for on 2026-11-02, with the indicators as dots: "have the dot match the
colour of the LED, as close as you can". The display driver's own header says
what the hardware is: 176 white LEDs (eleven per ring), 16 RGB LEDs (the one
under each knob), and 16 red/blue dual LEDs, one per encoder, at the ring's
12 o'clock. `build_indicator_pattern` lights that dual LED only when the
encoder has a detent and sits at 63/64, mixing red and blue by
`detent_color`; the eleven ring positions are white, PWM-dimmed, nothing
else. So a dot is white wherever it is, and the one coloured element on the
ring can show only a red-to-blue mix at one fixed position. The indicators were dots for a day and are blended bars since
(`twister.sh indicators blend`, field 22 = 2 on all of bank 4, and the step
keeps it so); either way the white LEDs stay white.

What was done instead, on request ("match the detent with the LED colour"):
for colour-from-rotation encoders without a detent, that red/blue LED is lit
permanently in the shown colour's red and blue shares, each at its own PWM
level (`set_encoder_indent_rgb`, a sibling of the driver's own
`set_encoder_indent`, which only crossfades), scaled by the indicator
brightness, off while the push has the colour hidden. Blue, red, magenta and
purple match well; yellow reads as red and cyan as blue, since the LED has no
green; pure green goes dark. The indicator redraw resets those two bits every
time, so the display update re-applies the tint after each one, tracked per
encoder in `prevIndentTint`. Encoders with a detent keep the stock centre
display, which owns the same LED.

## Which switch, and the unit as measured

`TAG=31` (hex) in `twister.sh`: bulk-transfer tags are 1-based,
`bank·16 + encoder + 1`, so 0x31 = bank 4, encoder 0, the top-left. Bank 4
because that was the page in use when this was asked for: the only evidence
the device gives is traffic, and one CC arrived from encoder 48 on channel 1
(bank 4's top-left knob, as mapped here) while probing. A SysEx pull returns
EEPROM only — never the current bank, never an LED's colour — and nothing else
queries it. Each bank's top-left is configured differently on this unit, so
the choice matters: bank 1's was Fine Adjust, then Shift Hold (the user was
editing with the web utility during the session); banks 2 and 3 are CC Toggle
on channels 3 and 2; bank 4 is CC Hold, channel 2, CC 48, both colours off.
Another switch is `twister.sh set <tag> 9`; `set <tag> 0` is CC Hold again.
Firmware boots into bank 1; the step does not change the bank.

## Probes

```
overrides/twister/twister-sysex version         # firmware date (2026-08-24 = our build)
overrides/twister/twister-sysex pull            # global settings, tag/value pairs
overrides/twister/twister-sysex send 'F0 00 01 79 04 01 31 F7'   # bank 4 encoder 0; field 0C = action
overrides/twister/twister-sysex pull-all > f    # everything, replayable with `restore f`
grep -A3 'Midi Fighter Twister' /proc/asound/seq/clients        # who is subscribed
```

`twister-sysex` speaks SysEx over the ALSA **sequencer** (ctypes on libasound,
standard library only). `amidi` is rawmidi and exclusive: it worked until
Chrome's Web MIDI subscribed to the port, then `Device or resource busy`. The
sequencer side is shared, so the tool works beside a browser, PipeWire or a DAW.
**Every bulk (per-encoder) push darkens the whole unit** until a global push:
`sysExCmdBulkXfer` calls `display_disable`, which raises the LED drivers'
output-enable line, and the only thing that lowers it again short of a USB
re-enumeration is `setting_confirmation_animation`, run by the global push
(`sysExCmdPushConfig`). That is the Utility's own sequence, encoders then
globals, and it bit here: the first `set` left the Twister dark (2026-11-02).
So `set-action` and `restore` both end by pulling the global settings and
pushing them straight back, green sweep included.

## Revert

`twister.sh --revert` (what `revert.sh` runs) puts all sixteen switches of
bank 4 back to CC Hold, turns rotation colour off there, and leaves the firmware: flashing is a deliberate act, and the custom build is
the official 2026-08-24 source plus one switch action nothing else selects.
To go back to a DJTT build, `twister.sh flash` with the official hex copied
over `build/twister.hex`, or the DJTT utility.

## Files

- `color-cycle.patch` — the four-file change, against the pinned commit
- `Makefile.linux` — the Linux build of the project
- `twister-sysex` — SysEx over the sequencer: `send`, `pull`, `pull-all`,
  `restore`, `set-action`, `set-field`, `bootloader`, `version`
- `twister.sh` — `status` (the step), `build`, `flash`, `backup`, `restore`,
  `set`, `switches`, `rotation`, `indicators`, `--revert`
- `config-backup-2026-11-02.txt` — the unit's settings before the flash
