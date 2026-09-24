# Commodore Desk 64

A graphical, Apple-style desktop GUI for the Commodore 64, written in 6502/6510
assembly (Kick Assembler). Dock at the bottom, a contextual menu bar at the top,
the app in the middle — no draggable windows. Boots as a **D71 disk** and as an
**EasyFlash `.CRT` cartridge** (instant boot).

![status](https://img.shields.io/badge/phase-0--10-brightgreen)

![Commodore Desk 64 — desktop](docs/desktop.png)

<sub>Running in VICE: the desktop with contextual menu bar, status bar and the dock.</sub>

### Screens

| File Manager | Settings | Paint |
|---|---|---|
| ![File Manager](docs/filemanager.png) | ![Settings](docs/settings.png) | ![Paint](docs/paint.png) |

<sub>Paint: full-screen multicolor bitmap with a 4-color palette (erase / white / red / cyan).</sub>

---

## Features

- **Desktop shell**: desktop, contextual menu bar (per app) and a **static dock**
  with 5 apps (macOS-style — always on screen).
- **Auto-hiding menu bar**: the top menu bar appears when the cursor reaches the
  top edge; the dock stays put. No status bar, so the whole middle is the app.
- **Windows-95-style boot screen**: a separate loader (`BOOT`) shows a sharp
  **hi-res bitmap** splash, then chain-loads the desktop — so the splash costs
  **no memory** in the running OS (it's overwritten when `CD64` loads).
- **One pointer, three input sources**: 1351 **mouse** (port 1), **joystick**
  (port 2) and the **keyboard** (cursor keys) all move the same sprite cursor.
- **Apps**:
  - **Files** — File Manager: reads the disk directory into a scrollable list.
  - **Editor** — text editor: type, RETURN (new line), DEL (backspace).
  - **Paint** — real **multicolor bitmap** paint (160×200): full-screen canvas,
    white background, all **16 colors** (per-cell colour slots) + an **eraser**
    button, starts on black; hold fire to drag-draw, **ESC** to exit.
  - **Calc** — 16-bit calculator (+ − × ÷).
  - **Settings** — all **theme colors are adjustable**, plus a **font** picker
    (System / Classic / Bold); everything is saved to `CD64.CFG`.
- **F1 context help** — a help panel whose text depends on the active app; press
  space to close it.
- **Drop-down menu** — reveal the menu bar (top edge) and click it to open the
  system menu (HELP · DESKTOP · ABOUT); click an item or click away to close.
- **Widgets**: buttons, checkbox, scrollable list, modal dialog.
- **SID click sound**.
- Strictly the **16-color VIC-II palette**.

## Color palette

Only the 16 VIC-II colors — no approximations.

![Color palette](docs/palette.png)

| # | Name | Hex | | # | Name | Hex |
|---|---|---|---|---|---|---|
| 0 | Black | `#000000` | | 8 | Orange | `#DD8855` |
| 1 | White | `#FFFFFF` | | 9 | Brown | `#664400` |
| 2 | Red | `#880000` | | 10 | Light red | `#FF7777` |
| 3 | Cyan | `#AAFFEE` | | 11 | Dark grey | `#333333` |
| 4 | Purple | `#CC44CC` | | 12 | Grey | `#777777` |
| 5 | Green | `#00CC55` | | 13 | Light green | `#AAFF66` |
| 6 | Blue | `#0000AA` | | 14 | Light blue | `#0088FF` |
| 7 | Yellow | `#EEEE77` | | 15 | Light grey | `#BBBBBB` |

The colors and theme roles are constants in
[`include/palette.inc`](include/palette.inc); in **Settings** you map each theme
role to one of these 16.

## Controls

| Action | Mouse | Joystick (port 2) | Keyboard |
|---|---|---|---|
| Move cursor | move the mouse | push the stick | cursor keys (+ shift for left/up) |
| Click | left button | fire | **space** or **return** |
| Type (Editor) | — | — | letters/digits, RETURN, DEL |
| Context help | — | — | **F1** (space closes it) |
| Back to desktop (close app) | — | — | **ESC** (= RUN/STOP) |

Move the cursor to the **top edge** to reveal the menu bar; **click the menu bar**
to open the system drop-down (HELP · DESKTOP · ABOUT). The **dock** is always on
screen — click a **dock icon** to open an app. **ESC** closes the active app and
returns to the desktop — that's how you leave the text editor (where space types a
space) and Paint. (In VICE on a PC the RUN/STOP key is mapped to **Esc**.)

## Building

Requires (paths are set in the `.bat` scripts — adjust as needed): **Java**,
**Kick Assembler** (`KickAss.jar`), **VICE** (`x64sc`, `c1541`, `cartconv`).

**One-time — extract the charset.** The System charset (`data/chargen.bin`) is the
C64 character ROM and is **not** in this repo (copyright). Extract it locally from
your VICE installation:
```bash
mkdir -p data
head -c 2048 "<VICE>/C64/chargen-901225-01.bin" > data/chargen.bin
```
(The first 2 KB = the uppercase/graphics set.)

**Disk (D71):**
```bat
build_disk.bat        :: -> build\CD64.d71
```
```bash
x64sc -autostart build/CD64.d71
```

**Cartridge (EasyFlash .CRT):**
```bat
build_cart.bat        :: -> build\CommodoreDesk64.crt
```
```bash
x64sc -cartcrt build/CommodoreDesk64.crt -8 build/CD64.d71
```
Flashing to real hardware: copy the `.CRT` to an SD card and flash it with
**EasyProg** on the C64.

> The D71 version loads over the slow IEC bus (~½ minute on real hardware). The
> cartridge version boots **instantly**: the reset stub copies the OS image from
> ROM into RAM (`$0801`), switches the cartridge off and runs as a plain C64.

## Architecture

```
apps/     Files · Editor · Paint · Calc · Settings
gui/      shell (desktop/dock/menu bar) · widgets · help
gfx/      gfx primitives · font · sprite (cursor)
kernel/   kernel · events · irq (raster 50 Hz) · memory · banking
hal/      vic · input (mouse/joy/kbd) · disk (IEC) · sound (SID)
include/  palette · layout · memmap · abi · hardware
```

- **Display**: hi-res character mode (40×25) for the desktop; Paint switches to
  multicolor bitmap in VIC bank 1 (`$4000-$7FFF`, free RAM above the OS) and back.
  The cursor is hardware sprite 0.
- **System clock**: a raster IRQ (50 Hz) polls input and generates events.
- **Memory**: runs from RAM with BASIC/KERNAL banked out; KERNAL is banked back in
  temporarily for disk I/O.
- **Font**: the System charset is embedded (`data/chargen.bin`) at `$3800`.

## Settings (persistence)

In **Settings** you pick a color per theme role (border, desktop, menu bar,
accent, selection) and a **font** — **System** (crisp), **Classic** (italic) or
**Bold** (heavy). Click the `FONT:` line to cycle; the whole UI switches
instantly. **SAVE** writes `CD64.CFG` to the D71. At boot the OS loads that file
back automatically. All three fonts share one UI-glyph block (frames, dock icons),
so only the text glyphs change.

## Files

| File | Role |
|---|---|
| `disk_main.asm` | entry point for the D71 build (PRG at `$0801`) |
| `boot_main.asm` | Windows-95-style boot loader: shows the splash, chain-loads `CD64` |
| `main_cart.asm` | entry point for the EasyFlash CRT (OS image + reset stub) |
| `tools/make_bootscreen.py` | generates the native hi-res boot screen bitmap (`data/boot_*.bin`) |
| `build_disk.bat` / `build_cart.bat` | build scripts |
| `Commodore-Desk-64-Ontwikkelplan.md` | full development plan (phases 0–10, Dutch) |
| `C64_KICKASS_SKILL.md` | Kick Assembler working instructions (Dutch) |
| `c64_ka_syntax_checker.py` | static syntax check |

## Status

Phases **0–10** complete: boot (disk + cart), kernel/IRQ, gfx primitives,
input HAL, events, desktop shell, widgets, 5 apps, color personalization with
persistence, and finishing (splash, sound, cartridge, docs). Plus F1 context help,
auto-hiding bars, and apps that fill the full work area.

**Open / upgrades:** selectable dock shape; config in flash instead of on disk.
Later: a **Commodore 128** port (all hardware-specific code lives in `hal/`).

> The development plan and the Kick Assembler skill document are still in Dutch;
> the application's on-screen text and this README are English.
