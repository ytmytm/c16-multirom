# C16 multirom

[![Build ROMs](https://github.com/ytmytm/c16-multirom/actions/workflows/build-roms.yml/badge.svg)](https://github.com/ytmytm/c16-multirom/actions/workflows/build-roms.yml)
[![Latest release](https://img.shields.io/github/v/release/ytmytm/c16-multirom?include_prereleases)](https://github.com/ytmytm/c16-multirom/releases)

This project is a **multirom board for the Commodore 16 only**. It is heavily inspired by the [ROM update for Commodore 16](https://myoldcomputer.nl/other-computers/commodore-16/rom-update-commodore-16/) at My Old Computer. It does not fit the Plus/4 mechanically, and the Plus/4 already has a function ROM on board.

The main idea: the stock C16 uses **two separate chips** for BASIC and KERNAL. By putting **BASIC and KERNAL in a single 64K chip** (U3), we free the second socket for a **function ROM** (U4)—e.g. 3-plus-1 and [Parobek](https://github.com/ytmytm/plus4-parobek)—so the C16 gains capabilities similar to the Plus/4. Replacing the original mask ROMs with EEPROMs (e.g. 27E512) also reduces power draw.

**ROM switching** is an extra: each 64K chip holds two 32K images selected by address line A15. You can fix the choice with **jumpers** (closed = lower half, open = upper half), use **switches** on J1/J2, or add the optional **ATtiny85** to cycle through the four combinations with a long press on RESET. The ATtiny is optional; many users will set jumpers once and leave them.

## What you get

- **U3 (system ROM)**: One 64K chip with BASIC (same in both halves) and two kernals—e.g. stock in the lower 32K and JiffyDOS or 6510-patched in the upper 32K. Jumper J1 or a switch (or the ATtiny) selects which half is active.
- **U4 (function ROM)**: One 64K chip with **3-plus-1** in the lower 32K and **Parobek** in the upper 32K. Jumper J2 or a switch (or the ATtiny) selects 3-plus-1 vs Parobek.
- **Optional ATtiny85**: long-press RESET cycles U3 and U4 A15 through 00, 01, 10, 11 so you can change ROM set without opening the case.

## Hardware

![Board](media/board.jpg)

The board is designed for the **C16** only. It plugs into the original ROM sockets (system and function) and uses:

- **U3**: 27C512 / 27E512 (64K) — system ROM (BASIC + two kernals in one chip).
- **U4**: 27C512 / 27E512 (64K) — function ROM (3-plus-1 + Parobek).
- **Glue logic**: 74LS00 (or HCT).
- **Optional**: ATtiny85-20P for RESET long-press bank switching.

Precision pin headers plug into the existing socket footprints. Jumpers J1 and J2 set A15 on U3 and U4 to choose the active 32K half; you can wire switches to J1/J2 instead, or let the ATtiny control them.

### BOM

- 2× 28-pin DIP socket (for 27C512/27E512)
- 1× 8-pin DIP socket (for ATtiny85, if used)
- 1× 74LS00 or 74HCT00
- 2× 10K resistors
- 2× 2-pin pinheaders (J1, J2 — ROM half select)
- Precision pinheaders as required for socket connection (see schematic)
- 2× 27C512 or 27E512 (64K EPROM/EEPROM)
- 1× ATtiny85-20P (optional, for long-press bank switch)

### Assembly

1. Solder the precision pin headers so the board mates with the original ROM sockets (U3 and U4 positions on the C16 mainboard). Check orientation.
2. Solder resistors, 74LS00, and sockets. If using the ATtiny, program it with the firmware in `attiny/` and fit it.
3. Burn the two 64K ROM images to the EPROMs (see **ROM images** below). Put the system ROM in U3 and the function ROM in U4.
4. Set J1 and J2 (or leave open for default halves). Power on and test.

## Project files (KiCad)

- [KiCad project](kicad-c16-multirom/)
- [Schematic PDF](kicad-c16-multirom/plots/kicad-c16-multirom.pdf)
- [Gerbers](kicad-c16-multirom/gerbers/) (or use the packaged zip in that folder for JLCPCB etc.)
  <!-- Order boards: <a href="https://www.pcbway.com/project/shareproject/...">PCBWay</a> -->
- [docs/](docs/) — additional documentation and notes.

## ROM images

The `rom/` directory contains a script and Makefile that build the 64K ROM images from public sources (Zimmers, Parobek, 6510 kernals). Downloads are done once; you choose PAL/NTSC and which kernals go in the lower and upper half of U3.

**Pre-built images** (built from this repo and published in the **Releases** section) are:

- **System ROM (PAL)** — BASIC + stock kernal in lower half, 6510-patched kernal in upper half. For U3; use when J1 is closed = stock, open = 6510.
- **System ROM (NTSC)** — Same layout for NTSC.
- **Function ROM** — 3-plus-1 in lower 32K, Parobek in upper 32K. Single image for U4; J2 closed = 3-plus-1, open = Parobek.

So you can burn one system ROM per region (PAL and NTSC) and one function ROM, and use jumpers or the ATtiny to switch.

### Building the ROMs yourself

From the `rom/` directory:

```sh
cd rom
make
```

Interactive mode will ask for TV standard (PAL/NTSC) and which kernal to use for the lower and upper half of U3 (stock, JiffyDOS, or 6510-patched). Default is stock in the lower half and JiffyDOS in the upper; 6510 kernals are downloaded automatically from hackjunk.com. JiffyDOS binaries (not redistributable) go in `rom/sources/jiffydos/`; see `rom/sources/jiffydos/README.txt`.

Non-interactive example (stock lower, JiffyDOS upper, PAL):

```sh
./build.sh --pal --kernal-lower=stock --kernal-upper=jiffydos
```

Outputs are `rom/out/u3-system.rom` and `rom/out/u4-function.rom`.

To build the **release** variants (stock+6510 PAL, stock+6510 NTSC, and the single function ROM):

```sh
make build-ni PAL=1 KERNAL_LOWER=stock KERNAL_UPPER=6510   # PAL system ROM
make build-ni PAL=0 KERNAL_LOWER=stock KERNAL_UPPER=6510   # NTSC system ROM
# Function ROM is always 3-plus-1 + Parobek (one image)
```

Then copy `out/u3-system.rom` and `out/u4-function.rom` to your release assets.

## Related

- [ROM update for Commodore 16](https://myoldcomputer.nl/other-computers/commodore-16/rom-update-commodore-16/) (My Old Computer) — main inspiration for this project.
- [Parobek ROM](https://github.com/ytmytm/plus4-parobek) — Function ROM with fast loader and extras for C16/+4; the upper half of U4 on this board holds Parobek.
- [C16 / Plus/4 — 8501 to 6510 CPU conversion](https://hackjunk.com/2017/06/23/commodore-16-plus-4-8501-to-6510-cpu-conversion/) — 6510-patched kernals (used in the release ROM builds) come from this project.
- [CBM firmware (Zimmers.net)](https://www.zimmers.net/anonftp/pub/cbm/firmware/computers/plus4/) — Stock BASIC, KERNAL, and 3-plus-1 ROM images; the `rom/` build script downloads from here.
