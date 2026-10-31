# Samsung QN90F (2025, 43") service menu: every item, with what it does

Transcribed from 75 photos of the TV's own factory menu on 2026-10-31,
firmware `T-RSMFDEUC-0090-1301.0` (Tizen 2025 "RoseM" hotfix release
2026-07-14). Model `TQ43QN90FATXXC`, panel type `43L3GU9TF`. Samsung publishes
no listing for this chassis: its public documents since 2024 are 24-page repair
guides that stop at the first screen. This is the listing.

**Entry:** TV in standby, on the IR remote: `Info`, `Menu`, `Mute`, `Power`,
one key after the other. Network sends of the same keys never work. **Exit:**
`Power`. Values are the ones the TV showed, not defaults. Nothing here is
documented by Samsung; the notes are from the item names, Samsung's 2019
service manuals (Q60R / Q900R, which tabulated the same tree), forum findings
and this TV's behaviour. A note marked *guess* is just that.

Page not photographed: none of the top-level pages. Submenus not opened:
SVC ▸ Reset, Test Pattern, Upgrade, S/N, EW Diagnosis; Sub Option ▸
OPTION_SWU, FAnet Option; Engineer Option ▸ Config_AV_PATH, Motor, EM, Write MAC
Address; FMS (opens no page). Two tables are cut by the photo's right edge:
OPTION_HDMI's third column and EzCal's blue column.

**Never touch:** Factory Reset, Type / Writing Type, Front Color, Sound Type,
TUNER, HV Flip, Watchdog, SPI Protection, IR CUSTOM, EDID WRITE *, OC SMPS
index write, LD_FPGA_MODEL_SEL, anything under Platform ▸ SSCI, SUBMICOM
upgrade, ADC/WB gains. Changing the model code or the EDID can leave the set
unbootable or blind on an input, and Samsung's repair path for that is a
mainboard.

## The first screen

Shown before any page is entered, and again under FMS (which has no page of
its own). Read-only.

```
T-RSMFDEUC-0090-1301.0                   main firmware (EU, 2025 RoseM chassis)
T-RSMINTV-1005                           submicom / micro firmware
T-RSMF-353182.240.520.131223             platform build
TIZEN-TRUNK2025-RoseM-HOTFIX-RELEASE_20260714.1 (Release)
BT Version : BLUETOOTH-VER-25111720
User guide : ROPDVBEUF-6.9.1             e-Manual build
E-POP Version : 25ROSEUHD-1.17.0         in-store demo loop
EDID SUCCESS / HDCP SUCCESS              both key blocks present and valid
Option : 43L3GU9TF,...,...,NONE          panel type, (blank), (blank), no One Connect
FRC-[ROSEM][USIT][165 Hz][Panel Output:03][U.SSC:O]   frame-rate converter in the SoC, 165 Hz panel
DIMMING-[FA-30X12][05]                   local dimming: full array, 30 × 12 = 360 zones, driver rev 5
LD FW1 : 25B19697 / LD FW2 : ----        LED driver firmware (one driver board)
TCON-[ROSEM] FW[F20F] DATA[F43L1UQD21]   timing controller firmware and panel data file
Model : TQ43QN90FATXXC
Wired MAC SUCCESS / Wireless MAC SUCCESS
WIFI Version : mt7668u-MTK.v5.1.0 20260616   MediaTek MT7668 module
CIP: SUCCESS / CIP ECP : SUCCESS         content-protection keys (Common Interface Plus)
C/ Nf/ NfDO WO H2 HtO PO AO O WS/ DIO IO SSO MO D/ S/ N/ RO
FPO Co/ SiO UX CI/ SNO KR/ KA/ (P)       feature / certification flags (Netflix, HDR10+, Dolby, ...): O = present
NSOO,00000027dd000002,0000
-1-1-1-1-1-1-1-1 S -1-1                  tuner / CI slot states, -1 = none
EM Status : 00000000                     Enterprise Management: no token installed
Fixed: 19000 / WB: 6                     calibration data revision, white-balance set 6
SmartControl : EA592200/000000           remote pairing id
Board Info : ----/--/--/--/--/--------- [D.SSC:O]   mainboard ids blank, DDR spread-spectrum on
Factory Reset In Production : O
Zigbee FW Version: 6.0.2 / Zigbee MAC:SUCCESS       SmartThings hub radio
Pogo Connection : Not supported          no One Connect / pogo-pin accessory
Date of purchase : 10/31/2026            the day the TV first registered; this TV's clock is wrong by a year
```

The dimming line is the one worth remembering: **360 zones** of full-array local
dimming behind this 43" panel.

## Option

The model-identity page. Everything a service centre re-enters after a
mainboard swap lives here.

| Item | Value | What it does |
|---|---|---|
| Factory Reset | | Full reset, including network and the service-menu entry counters. Harsher than the user-menu reset. |
| Type | `43L3GU9TF` | The panel/model type code the whole firmware keys on (which dimming driver, which EDID table, which picture tuning). |
| Writing Type | | Writes a new Type. Mainboard-swap step. |
| Front Color | `QN90FC-Q43FC1` | Bezel/design variant, selects the on-screen product imagery. |
| Writing Front Color | | Writes it. |
| Sound Type | `QN90FC-20-2-43` | Speaker configuration: 20 W, 2 channels, 43" cabinet. Selects the speaker EQ set. |
| Writing Sound Type Index | | Writes it. |
| TUNER | `D_T2CS2` | Tuner module: DVB-T2 / C / S2. |
| MRT Option | ▸ | Region and feature flags, below. |
| Production Option | ▸ | Factory feature flags, below. The local-dimming switch is here. |
| Engineer Option | ▸ | Low-level hardware config, below. |

### Option ▸ MRT Option

| Item | Value | What it does |
|---|---|---|
| Lvds Format | `JEIDA` | Bit mapping on the panel link. Panel-specific. Wrong value = scrambled picture. |
| Language Set | `EU` | Which language list the Settings menu offers. |
| Region | `PANEURO` | Operating region: app store, broadcast standards, TV Plus catalogue. |
| PnP Language | `ENG` | Language of the out-of-box setup. |
| PnP Lang.Sel.Support | `ON` | Whether setup asks for a language at all. |
| OTN Support | `ON` (greyed) | Over-the-network updates (Samsung's own update server). |
| OTA Support | `General` | Over-the-air (broadcast) firmware updates. |
| HV Flip | `OFF` | Mirrors the picture horizontally and vertically. For upside-down mounts. ON means an upside-down picture on next boot. |
| BT ADDRESS | `38:8C:…` | Bluetooth MAC. Read-only. |
| Wifi Vendor | `MT7668` | Which Wi-Fi driver to load. |
| Instant On | `ON` | Keeps the SoC in a warm state in standby for a fast start. |
| Always Instant On Support | `ON` | Same from a cold mains connection. |
| OPTION_NUM | ▸ | Numeric option block (not opened). |
| Game Mode | `15` | Bitmask of game-mode features offered (VRR, ALLM, Game Bar, ...). |
| Low Input lag Enable | `1` | Enables the low-latency path. |
| Frame Rate/VRR | `5` | VRR capability set advertised: 5 is the 165 Hz tier on this chassis (*guess from the value*). |

### Option ▸ Production Option

| Item | Value | What it does |
|---|---|---|
| Cable Modulation | `…` | Default cable-tuner modulation table. |
| EcoSensor Location | `0` | Where the ambient-light sensor sits on the bezel (0 = bottom centre). |
| **PC Mode Dimming Support** | `ON` | Whether local dimming stays active when the input's device type is PC. **This is the switch.** OFF = the backlight runs flat (all 360 zones at one level) for a PC source, which removes the halo and the zone-tracking lag on a static desktop at the cost of contrast. Takes effect when the source is set to PC. |
| Flickerless | `OFF` | Backlight PWM mode. ON lifts the PWM frequency (or goes to DC dimming) to remove visible flicker at low backlight, at the cost of low-end brightness precision. Worth trying for a desk monitor. |
| Auto Power | `LAST POWER` | After a mains cut: come back in the last state, always on, or always off. |
| Blur Reduction | `ON` | Shows the Blur Reduction slider under Picture Clarity. |
| ATSC3 Support | `OFF` | US NextGen TV tuner stack. Dead here. |

### Option ▸ Engineer Option

| Item | Value | What it does |
|---|---|---|
| Config_AV_PATH | ▸ | Signal-path routing table. Not opened. |
| Fast Logo Delay | `0` | Delay before the boot logo appears. |
| Panel Init Time | `250` | ms to wait after panel power before driving it. Panel-specific. |
| Write MAC Address | `…` | Writes the Ethernet MAC. Mainboard-swap step. |
| OVD Support | `1` | Over-voltage detect / overdrive flag (*which one is unclear*). |
| High Temp Protect | `ON` | Dims the backlight when the mainboard sensor runs hot. |
| Ramdump Support | `ON` | Writes a RAM dump on a kernel crash (to USB if present). |
| REALTIME PERFORMANCE | | Performance counters page. |
| USING_PSI_UPDATE | `…` | Updates via the broadcast's PSI tables. |
| OCL SMPS TYPE | `NONE` | Power-supply model, for sets with a current-limited SMPS. |
| Motor | ▸ | The rotating stand on the Sero. Inert. |
| CVEE | `ON` | *Unknown.* Plausibly a video-enhancement engine flag. |
| LD_FPGA_MODEL_SEL | `903` | Which local-dimming driver profile to load. Must match `FA-30X12`. |
| EM | ▸ | Enterprise Management (see Platform ▸ SSCI). |
| OC SMPS index write | | Writes a power-supply index. Mainboard-swap step. |

## Control

Hardware and sub-system configuration. Eight submenus.

### Control ▸ EDID

The factory tool that rewrites the EDID EEPROM behind each HDMI port.

| Item | Value | What it does |
|---|---|---|
| EDID ON/OFF | `OFF` | Arms the write functions below. Does not stop the TV serving its EDID. |
| EDID WRITE ALL | `…` | Rewrites every input's EDID from the table in firmware. |
| EDID WRITE HDMI | `…` | Same, HDMI ports only. |
| EDID WRITE PC | `…` | Same for a VGA input. None on this chassis. |
| HDMI EDID Ver | `…` | Which EDID table version is written (HDMI 1.4 / 2.0 / 2.1 class). |
| HDMI EDID Port | `…` | Which port a write targets. |
| EDID Release Version | `…` | Revision of the EDID table in this firmware. Read-only. |
| EDID USB UPDATE | `…` | Loads an EDID binary from a USB stick and writes it to a port. The one route to a custom EDID with a native 4K144 timing. A bad write leaves the port unusable until written again. |

### Control ▸ Sub Option

Factory and debug flags.

| Item | Value | What it does |
|---|---|---|
| RS-232 Jack | `UART` | What the service jack carries: the SoC debug console (UART) or the Ex-Link control protocol. |
| EXT Link Support | `OFF` | Enables Ex-Link, Samsung's serial control protocol for AV controllers. |
| Serial Log On/Off | | Prints the boot and runtime log to the jack. |
| Watchdog | `ON` | Hardware watchdog that reboots a hung firmware. Leave ON. |
| Fast Boot in Production | `OFF` | Factory-line flag that skips initialisation steps. |
| USB Serial | `OFF` | Exposes the debug console over USB instead. |
| Info Link Server Type | `Operating` | Which Samsung backend the Smart Hub uses. Operating = production. |
| OPTION_SWU | ▸ | Software-update options. Not opened. |
| FAnet Thread | `2` | Factory automation network, thread count. Inert outside the factory. |
| SPI Protection | | Write protection for the SPI flash holding the bootloader. Never touch. |
| FKP Server Type | `Default` | A server selector. *FKP not expandable.* |
| Power off interval Reset | `60` | *Unknown.* Likely seconds, tied to the standby counters. |
| bixby server | `prod` | Bixby voice backend. |
| Cell Auto Detect | `OFF` | Identify the panel (the cell) from its EEPROM rather than the Type code. |
| LCM Auto Mode | `OFF` | LCD-module auto-identification. |
| LCM JIG Mode | `OFF` | Panel test-fixture mode. |
| LOGO delay | `0` | Boot-logo delay. |
| IR CUSTOM | `0x10` | The IR address byte the TV answers to. Change it and the remote stops working. |
| Keep Inverter On | `OFF` | Keeps the backlight on in standby or test. |
| FAnet Option | ▸ | More factory-network options. |
| SES Update Server Type | `Operating` | Update server selector. |
| Energy Data Lock Flag | `ON` | Locks the EU energy-label picture preset (*plausible, unverified*). |
| Enable Logs After Reset | `OFF` | Keep debug logging on after a factory reset. |

### Control ▸ Shop Option

| Item | Value | What it does |
|---|---|---|
| Exhibition Mode | `OFF` | Store-floor lock: disables channel, number and power-off keys. |
| Peak Mode | `ON` | Allows the retail-brightness peak in Dynamic mode. |
| Metadata | `ON` | Whether the demo loop reads its metadata (E-POP). |

### Control ▸ Asia Option

| Item | Value | What it does |
|---|---|---|
| Mono Last Memory | `OFF` | Remembers a mono analogue-sound selection across channels. Legacy. |

### Control ▸ Sound

| Item | Value | What it does |
|---|---|---|
| Amp Information | ▸ | Status and id of the speaker amplifier IC. |
| Amp Recovery | `ON` | Auto-resets the amplifier after a fault. |
| Subwoofer Support | `4` | Speaker-layout / woofer configuration code. |
| High Devi | `OFF` | High-deviation FM sound carrier. Legacy analogue. |
| Carrier_Mute | `OFF` | Mute when the analogue sound carrier drops. Legacy. |
| Pilot Level High Thld | `0x70h` | Analogue stereo-pilot detection threshold. Legacy. |
| Pilot Level Low Thld | `0x20h` | Same, low. |
| SPDIF BYPASS | `NORMAL` | Whether the optical output passes the bitstream untouched. |
| DSP EQ | `ON` | The built-in speaker equalisation. OFF = flat, uncorrected. |

### Control ▸ Outdoor TV Option

For The Terrace, which shares this firmware. Fan speed and the outdoor
temperature readout do nothing here. The protections may be live.

| Item | Value | What it does |
|---|---|---|
| Outdoor TV FAN Speed | `100` | Fan duty. No fan here. |
| Outdoor TV Temperature | | Outdoor sensor readout. None here. |
| Cell Temperature Protection | `OFF` | Dim when the panel sensor exceeds the threshold. |
| Cell Temperature Threshold | `0` | That threshold. |
| Main Temperature Protection | `ON` | Dim when the mainboard sensor exceeds 80. |
| Main Temperature Threshold | `80` | |
| Ambient Light Protection | `ON` | Dim against direct sunlight above the light-sensor level. If unexplained dimming is ever seen in a bright room, this is a suspect. |
| Ambient Light Threshold | `20` | |

### Control ▸ QD option

The burn-in protection stack for Samsung's QD-OLED and WOLED sets. This is a
mini-LED LCD, so the page is present but should be inert; the values agree
(pixel shift 0, every sensing counter 0, EL sensing off).

| Item | Value | What it does |
|---|---|---|
| NPC LUT | `1` | Compensation lookup table select. *NPC not expandable.* |
| Pixel Shift Range | `0` | Orbiter range in pixels. 0 = off. |
| Pixel Shift Speed | `0` | Orbiter step interval. |
| Pixel Shift Scaling On/Off | `OFF` | Scale the picture slightly so the orbit never shows a bare edge. |
| Screen Saver Method | `1` | Which still-image screen saver. |
| Screen Saver Brightness | `7` | Its dim level. Forum lore: 0 disables the OLED auto-static-brightness-limiter. Inert on LCD. |
| Screen Saver Waiting Time | `2` | Minutes before it starts. |
| Screen Saver Slope | `2` | Fade speed. |
| ISP Global Brightness | `3` | Image-sticking prevention: whole-picture dim level after a still image. |
| ISP Global Waiting Time | `1` | Minutes before it acts. |
| ISP Global Slope | `0` | Ramp speed. |
| ISP Global Recovery Slope | `1` | Ramp back. |
| ISP Global REFLAG SW | `ON` | Re-arm flag. |
| Multi Logo ISP Global TH1 | `230` | Luminance threshold for logo detection. |
| Multi Logo ISP Global TH2 | `190` | Second threshold. |
| ISP Local Brightness | `2` | Local (per-logo) dim level. |
| Low Power Mode Level | `6` | Panel low-power tier. |
| R_NPC_DIM_LVL2 | `137` | Compensation dim level 2. |
| Banner Brightness | `2` | Detected-banner dim level. |
| Offsensing TEST Period | `0` | Test interval for the off-sensing cycle. |
| SoC Pixel Shift | `60` | Orbiter interval when done by the SoC rather than the TCON. |
| Off Sensing CNT | `0` | How many off-sensing (pixel-wear) cycles have run. |
| EL Sensing CNT | `0` | How many electroluminance-sensing cycles have run. |
| TM On/Off | `ON` | Temperature-based luminance management. |
| Off Sensing Start | `OFF` | Start a sensing cycle now. |
| TM temp SDR Home | `1` | TM tier per picture mode. |
| TM temp SDR Retail | `1` | |
| TM temp HDR | `1` | |
| TM temp Portrait | `0` | |
| Multi Logo Brightness | `3` | Logo dim level. |
| WOLED EL Sensing Time | `Off` | Sensing schedule for WOLED panels. |
| TM Min luminance | `2` | Floor for TM dimming. |
| TM Boundary | `0` | |
| TM Speed | `1` | |
| NPC Bypass | `OFF` | Bypass the compensation LUT. |
| Off Sensing Rework | `OFF` | Re-run a failed sensing cycle. |

### Control ▸ QD2 Option

The second half of the same stack: the orbiter at a finer level, peak-luminance
control (PLC), the local/global brightness limiter (LBC) and two further ramped
compensations (LEA, CPC; not expandable).

| Item | Value | What it does |
|---|---|---|
| Orbit Enable | `0` | Orbiter master switch. 0 = off. |
| Orbit Mode Enable | `1` | |
| Orbit Mode | `1` | Pattern. |
| Orbit Distance | `1` | Step size. |
| Orbit X | `16` | Range in pixels. |
| Orbit Y | `8` | |
| LEA Limit Ratio 1 | `3` | |
| LEA Limit Ratio 2 | `51` | |
| LEA Limit Gain 1 | `3` | |
| LEA Limit Gain 2 | `51` | |
| LEA Top CTRL | `1` | |
| LEA Refresh En | `0` | |
| PLC Start | `1` | Peak luminance control on. |
| PLC Default Liminance | `38` | Its default level. |
| PLC Sampling Period | `128` | Frames between samples. |
| PLC Still Image Margin | `4` | How much change still counts as still. |
| PLC Return Offset | `84` | |
| PLC Return Period Decreasing | `8` | Ramp down speed. |
| PLC Return Period Recovering | `5` | Ramp up speed. |
| CPC Enable | `1` | |
| CPC Gain step | `1` | |
| CPC Frame step | `8` | |
| LBC Enable 22Y | `1` | 2022 algorithm version. |
| LBC Enable 21Y | `1` | 2021 algorithm version. |
| LBC Local gain value | `180` | Local limiter strength. |
| LBC Local TH1 | `8` | Thresholds. |
| LBC Local TH2 | `28` | |
| LBC currnet | `1` | Current-based limiter (sic). |
| LBC Global gain value | `192` | Global limiter strength. |
| LBC Global TH3 | `16` | |
| LBC Global idle time | `60` | Seconds of static before acting. |
| LBC Sampling Period | `120` | |
| LBC Global reduce time | `7` | Ramp down. |
| LBC Global return time | `6` | Ramp back. |
| Global Multi Logo Brightness | `2` | Global logo dim. |

## Debug

Signal-chain tuning and engineering toggles.

| Item | Value | What it does |
|---|---|---|
| Spread Spectrum | ▸ | Spread-spectrum clocking on the DDR, panel link and FRC buses (EMI). |
| Tuner Margin | `3` | Tuner sensitivity margin for the self-test. |
| FRC | ▸ | Frame-rate converter page. |
| TCON | ▸ | Timing-controller page. |
| MPEG Margin | `20` | Decoder error tolerance before a frame is dropped. |
| H.264 Margin | `15` | Same for H.264. |
| Voice Debug | `OFF` | Logs the voice pipeline. |
| Power Management | `0` | Power-management profile. |
| RM_BIST_DTV | ▸ | Built-in self test of the digital, analogue and cable tuners. |
| RM_BIST_ATV | ▸ | |
| RM_BIST_CABLE | ▸ | |
| Error Popup On/Off | `OFF` | Shows firmware errors on screen. |
| CES Option | `OFF` | Trade-show demo flags. |
| BT DUT | `OFF` | Bluetooth device-under-test mode (RF certification). |
| BT EU DUT | | Same, EU band plan. |
| BT Throughput | `Failure` | Last Bluetooth throughput test result. |
| Read Eco Sensor Data | `0` | Live ambient-light reading. |
| No Signal Power OFF | `ON` | Standby 15 minutes after the HDMI signal drops. Relevant to a PC that sleeps its display: OFF keeps the TV on. |
| Default HDMI1 Booting | `OFF` | Always start on HDMI 1. |
| Run EW | `720h` | Early-warning diagnostic schedule. |
| EMP_BACKEND | ▸ | Enterprise-management endpoints. |
| EMP_AVE | ▸ | |
| BT Non-Discoverable | `OFF` | Hides the TV from Bluetooth scans. |
| Always On TV | `OFF` | Never enter standby. |
| Zigbee Region Code | `DEFAULT` | SmartThings radio region. |
| Always BG Standby | `OFF` | Keep the background services running in standby. |
| Engineer Reset | `OFF` | Resets the engineer options. |
| Downgrade Panel Size | `043` | Tells the firmware a smaller panel size than Type says (for a swapped panel). Matches. |
| WOC TEST CHANNEL | `0` | Wireless One Connect test channel. None here. |
| WOC Fast Perf Mode | `Off` | |

## SVC

Service tools: tests, counters, HDMI receiver tuning, resets.

| Item | Value | What it does |
|---|---|---|
| Self Test(for HW) | ▸ | Hardware self-tests, below. |
| Info | ▸ | Counters, below. |
| Reset | ▸ | Partial resets (Apps Reset, SVC Reset). Not opened. |
| OPTION_HDMI | ▸ | HDMI receiver tuning, below. |
| DVB CI | ▸ | Common-interface slot timing, below. |
| Test Pattern | ▸ | Internal patterns from the scaler, FRC and TCON. Not opened. |
| Upgrade | ▸ | Sub-firmware upgrades from USB (TCON, LED driver, submicom). SUBMICOM UPGRADE bricks sets. Not opened. |
| Other Setting | ▸ | Expert tools and calibration backup, below. |
| SVC Panel | `ORIGINAL` | Whether the fitted panel is the original or a service replacement. |
| S/N | ▸ | Serial-number writer. |
| Key Scenario | `OFF` | Records remote keypresses for a repro. |
| EW Diagnosis | ▸ | Early-warning diagnostic report. |
| MASS Full Test | `-` | Factory mass-production tests. |
| MASS Simple Test | `-` | |
| MASS Fast Test | `-` | |
| TSI Auto Test | ▸ | Test-system-interface automation hook. |

### SVC ▸ Self Test(for HW)

Each runs a check of that block and shows pass/fail. Harmless to run, apart
from the sound inspections, which play tones.

Loop Back, DDR, FLASH, EEPROM, Tuner X-TAL, Tuner1, HDMI Switch IC, WIFI (`0`),
LVDS, T-CON/FRC, TCON Post, PMIC, MOIP, BT, EcoSensor, Voltage (`0`), Module
Test, ATV CH Inspection (`Failure`, no analogue signal), DTV CH Inspection,
Satellite CH Inspection, EXT Sound Inspection, Woofer Sound Inspection, Tweeter
Sound Inspection, TP Sound Inspection, Aging line test (`0`), Outdoor Function
Test, Pogo Module Test (`Ready`).

### SVC ▸ Info

| Item | Value | What it does |
|---|---|---|
| SVC Info | `0` | |
| ER Count | ▸ | Error counters: watchdog resets (WD Count), abnormal resets (AR Count). |
| Panel Display Time | `0Hr` | Panel-on hours. Reset by a factory reset, which this shows. |
| Factory Entry Number | `2` | How often the service menu has been opened. |
| Factory Execution History | ▸ | Log of service-menu changes. |
| Factory Reset History | ▸ | |
| Logo BR Off Time | `0Hr` | |

### SVC ▸ OPTION_HDMI

The HDMI receiver's tuning. The left column is timing and equalisation, the
middle is the colour primaries the EDID advertises, the right is the FRC/VRR
EDID flags. The third column was cut by the photo's edge.

| Item | Value | What it does |
|---|---|---|
| HOT PLUG DURATION | `800ms` | How long HPD is pulled low on a re-handshake. |
| HDMI MUTE TIME | `0ms` | Video mute after a mode change. |
| HDMI NFST UNMUTE TIME | `600ms` | Unmute delay when no fast-switch. |
| HdmiRx EQ | `0` | Receiver equaliser preset. 0 = auto. |
| HDMI TMDS ERR DET | `1` | TMDS error detection on. |
| Auto EQ sweep | `READY` | Runs an EQ sweep on the live input. |
| VMD OPT | `0` | Video-mode-detection option. |
| HdmiRx PLL_BW | `0` | Receiver PLL bandwidth. |
| PREDEFINED HDMI VALUE | `ON` | Use the stored tuning rather than auto. |
| HDMI Color Noise Remove | `ON` | A chroma-noise filter on HDMI input. Worth checking OFF on a PC source if fine colour detail looks soft (*guess at its reach*). |
| Adaptive SW EQ | `OFF` | Software-adaptive equalisation. |
| eARC SW HPD Duration | `0` | |
| HDMI CTS mode | `OFF` | Compliance-test mode. |
| HDMI Comp. mode | `0` | Compatibility mode for troublesome sources. |
| Red X / Red Y | `670` / `311` | Colour primaries written into the EDID (CIE xy × 1000). These are the DCI-P3-ish primaries the TV advertises. |
| Green X / Green Y | `273` / `659` | |
| Blue X / Blue Y | `153` / `45` | |
| White X / White Y | `312` / `329` | D65. |
| Max Lux 1 / Min Lux 1 | `177` / `1` | HDR static metadata in the EDID: max and min luminance codes. |
| Max Lux 2 / Min Lux 2 | `126` / `15` | Second set (frame-average). |
| HDR EDID | `62` | HDR block flags. |
| 120Hz VRR / 144Hz VRR | `0` / `0` | Per-rate VRR flags in the EDID. 0 here while the TV advertises VRR 48–165 in its DisplayID block, so these look like legacy per-timing flags. |
| VRR Off | `0` | |
| 120Hz FRC / 144Hz FRC | `0…` (cut) | |
| Product ID | `308…` (cut) | EDID product code; the HDMI 2.1 EDID reads 30707 when Input Signal Plus is on. |

### SVC ▸ DVB CI

| Item | Value | What it does |
|---|---|---|
| TS Clock delay TC | `0` | Transport-stream clock skew into the CI slot. |
| TS Clock delay S | `0` | |
| CI Control Buf ON | `ON` | Buffer between tuner and CI. |
| TS Clock delay CPU | `2` | |

### SVC ▸ Other Setting

| Item | Value | What it does |
|---|---|---|
| Expert | ▸ | Night/Day calibration presets (N/D ADJ), Source Banner Hide, and the like. Not opened. |
| CAL Data Backup | `…` | Writes the white-balance and ADC calibration to USB. **Worth doing once** before touching anything under ADC/WB. |
| CAL Data Restore | | Reads it back. |
| ATV IF AGC SPEED | | Analogue-tuner AGC. Legacy. |
| Upgrade UHD OSD Test | `0` | |
| Main USB Path | `0` | Which USB port the upgrade tools read. |
| JackP USB path | `0` | |
| Apps Update | ▸ | Forces an app-store update. |
| Picture Direct | `OFF` | Bypasses the picture-processing chain (*plausible*). |
| Motion Sensor | ▸ | For sets with one. |
| V APP | `OFF` | |
| SWI | `OFF` | |
| Restart No | `3` | Reboot count threshold before recovery. |
| Sound Sensor Test | ▸ | Microphone test. |
| Tap Sensor Test | ▸ | The Frame's tap-to-wake. Inert. |
| Wi-Fi Motion Sensing | ▸ | Presence detection via Wi-Fi reflections. |
| MBR STB Power On Sync | `Enabled` | Power the set-top box on with the TV over IR. |

## FMS

Has no page: selecting it shows the first screen again. Factory management
system hook.

## ADC/WB

Analogue-to-digital calibration and white balance. These are per-set numbers
written at the factory. Back them up (SVC ▸ Other Setting ▸ CAL Data Backup)
before changing one.

### ADC/WB ▸ ADC Result

The analogue input calibration result. The 1st set is component (YCbCr) gain
high/low, all 0 since there is no analogue video input. The 2nd set is RGB
low/high, at mid-scale (128) and 69.

1st_Y_GH `0`, 1st_Y_GL `0`, 1st_Cb_BH `0`, 1st_Cb_BL `0`, 1st_Cr_RH `0`,
1st_Cr_RL `0`, 2nd_R_L `128`, 2nd_G_L `128`, 2nd_B_L `128`, 2nd_R_H `69`,
2nd_G_H `69`, 2nd_B_H `69`.

### ADC/WB ▸ White Balance

The factory 2-point white balance that sits under every picture mode's own
2-point. 128 is unity.

| Item | Value | What it does |
|---|---|---|
| R-Offset / G-Offset / B-Offset | `128` / `128` / `128` | Black-end offsets. All unity. |
| R-Gain / G-Gain / B-Gain | `142` / `128` / `144` | White-end gains: red +14, blue +16 against green. This is what makes the panel's native white hit the target. |
| WB_W2_R_Offset / WB_W2_B_Offset | `128` / `128` | Second white point (Warm2 colour tone). |
| WB_W2_R_Gain / WB_W2_B_Gain | `156` / `96` | Warm2: red up, blue well down. This is the Warm2 tone the user runs. |
| WB_N_R_Offset / WB_N_B_Offset | `128` / `128` | Normal colour tone. |
| WB_N_R_Gain / WB_N_B_Gain | `161` / `143` | |

### ADC/WB ▸ MGA

Multi-point (10-point) gamma adjustment. `MGA On/OFF` is `OFF`, so these are
not applied. Values are gains at 10 %, 20 % … 100 % stimulus, 512 = unity.

| Point | R | G | B |
|---|---|---|---|
| 1 | 550 | 532 | 532 |
| 2 | 544 | 526 | 526 |
| 3 | 544 | 530 | 534 |
| 4 | 534 | 520 | 522 |
| 5 | 530 | 522 | 524 |
| 6 | 528 | 518 | 520 |
| 7 | 524 | 514 | 518 |
| 8 | 520 | 514 | 516 |
| 9 | 516 | 512 | 514 |
| 10 | 512 | 512 | (cut) |

### ADC/WB ▸ EzCal

The measurement data behind Samsung's phone-based Smart Calibration: for each
primary at 10 / 20 / 40 / 70 / 100 % stimulus, the measured chromaticity (x,
y) and luminance (L). Values are stored with a `1000000xx` prefix for the
sub-1 numbers; `100006800` reads as x = 0.6800. The 100 % rows carry the raw
value. The blue column was cut by the photo's edge.

| Stimulus | R x | R y | R L | G x | G y | G L |
|---|---|---|---|---|---|---|
| 10 | 0.6800 | 0.3200 | 0.67 | 0.2650 | 0.6900 | 2.12 |
| 20 | 0.6800 | 0.3200 | 3.08 | 0.2650 | 0.6900 | 9.73 |
| 40 | 0.6800 | 0.3200 | 14.17 | 0.2650 | 0.6900 | 44.70 |
| 70 | 0.6800 | 0.3200 | 48.54 | 0.2650 | 0.6900 | 153.12 |
| 100 | 6783 | 3058 | 9977 | 2685 | 6718 | 43956 |

Red at x 0.680 y 0.320 and green at 0.265 / 0.690 are the DCI-P3 primaries,
which matches the EDID primaries above.

### ADC/WB ▸ WB_Energy

Backlight limits per mode, for the energy label.

| Item | Value | What it does |
|---|---|---|
| WB_Dynamic Backlight | `50` | Backlight level the Dynamic mode is capped at out of the box. |
| WB_Eco Backlight | `22` | Backlight for the EU energy-label (Eco) preset. |
| WB_Eco Backlight2 | `22` | |
| WB_Eco Backlight_uzb | `22` | |
| WB_PWM_MLD | `0` | PWM dimming value for the measured-luminance-data point. |
| WB_PWM_MLD_OC | `0` | |
| WB_ANA_MLD | `40` | Analogue (current) dimming value at that point. |
| WB_ANA_MLD_OC | `0` | |
| WB_ATV_PWM_MLD | `0` | |
| WB_ATV_ANA_MLD | `0` | |
| WB_Min BL | `7070707` | Minimum backlight, packed per zone group. |
| WB_Backlight GAIN | `200` | Backlight gain multiplier. |
| WB_Backlight_GAIN2 | `200` | |

## Platform

Enterprise and monitoring hooks.

### Platform ▸ SSCI

Enterprise Management (the hotel / signage management channel). Every action
is destructive to the TV's registration. Do not run them.

| Item | Value | What it does |
|---|---|---|
| EM Erase | `READY` | Erases the enterprise token. |
| Install EMToken | `READY` | Installs one from USB. |
| Read EMStatus | `00000000` | No token. |
| Write EMDUIDFile | `READY` | Writes the device-unique id file. |
| Enter Ticket number | | Service ticket for the Samsung agent channel. |

### Platform ▸ SSM

| Item | Value | What it does |
|---|---|---|
| SSM Monitoring for VIP Set | `OFF` | Remote monitoring for sets in a VIP programme. |

## The items that matter for this desk

- **Option ▸ Production Option ▸ PC Mode Dimming Support** (`ON`): the
  local-dimming switch for a PC source. OFF makes the 360 zones run flat.
- **Option ▸ Production Option ▸ Flickerless** (`OFF`): a higher-frequency
  backlight PWM. Try it if low backlight flickers.
- **Debug ▸ No Signal Power OFF** (`ON`): the TV sleeps 15 minutes after the
  PC's display sleeps.
- **SVC ▸ OPTION_HDMI ▸ HDMI Color Noise Remove** (`ON`): a chroma filter on
  the HDMI path, candidate for the soft fine colour.
- **SVC ▸ Other Setting ▸ CAL Data Backup**: do this before anything under
  ADC/WB.
- **Control ▸ EDID ▸ EDID USB UPDATE**: the route to a native 4K144 timing.
- **Control ▸ Outdoor TV Option ▸ Ambient Light Protection** (`ON` at `20`):
  a sunlight-dimming rule that may be live.
