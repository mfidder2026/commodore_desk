# Commodore Desk 64

Een grafische, Apple-achtige desktop-GUI voor de Commodore 64, geschreven in
6502/6510-assembly (Kick Assembler). Dock onderin, contextuele menubalk bovenin,
de app in het midden — géén sleepbare vensters. Bootbaar als **D71-disk** en als
**EasyFlash-`.CRT`-cartridge** (instant boot).

![status](https://img.shields.io/badge/fase-0--10-brightgreen)

![Commodore Desk 64 — bureaublad](docs/desktop.png)

<sub>Draaiend in VICE: bureaublad met contextuele menubalk, statusbalk en de dock.</sub>

### Schermen

| File Manager | Settings |
|---|---|
| ![File Manager](docs/filemanager.png) | ![Settings](docs/settings.png) |

---

## Wat kan het

- **Bureaublad-shell**: bureaublad, contextuele menubalk (per app), statusbalk en
  een dock met 5 apps.
- **Één aanwijzer, drie invoerbronnen**: 1351-**muis** (poort 1), **joystick**
  (poort 2) én **toetsenbord** (cursortoetsen) bewegen dezelfde sprite-cursor.
- **Apps**:
  - **Files** — File Manager: leest de disk-directory en toont hem in een
    scrollbare lijst.
  - **Editor** — teksteditor: typen, RETURN (nieuwe regel), DEL (backspace).
  - **Paint** — blok-paint: canvas + 16-kleuren-palet.
  - **Calc** — 16-bits rekenmachine (+ − × ÷).
  - **Settings** — alle **thema-kleuren aanpasbaar** en opslaan naar `CD64.CFG`.
- **Widgets**: knoppen, checkbox, scrollbare lijst, modale dialoog.
- **Boot-splash** + **SID-klikgeluid**.
- Strikt het **16-kleuren VIC-II-palet**.

## Kleurenpalet

Uitsluitend de 16 VIC-II-kleuren — geen benaderingen.

![Kleurenpalet](docs/palette.png)

| # | Naam (NL) | Hex | | # | Naam (NL) | Hex |
|---|---|---|---|---|---|---|
| 0 | Zwart | `#000000` | | 8 | Oranje | `#DD8855` |
| 1 | Wit | `#FFFFFF` | | 9 | Bruin | `#664400` |
| 2 | Rood | `#880000` | | 10 | Lichtrood | `#FF7777` |
| 3 | Cyaan | `#AAFFEE` | | 11 | Donkergrijs | `#333333` |
| 4 | Paars | `#CC44CC` | | 12 | Grijs | `#777777` |
| 5 | Groen | `#00CC55` | | 13 | Lichtgroen | `#AAFF66` |
| 6 | Blauw | `#0000AA` | | 14 | Lichtblauw | `#0088FF` |
| 7 | Geel | `#EEEE77` | | 15 | Lichtgrijs | `#BBBBBB` |

De kleuren en thema-rollen staan als constanten in
[`include/palette.inc`](include/palette.inc); via **Settings** koppel je elke
thema-rol aan een van deze 16.

## Besturing

| Actie | Muis | Joystick (poort 2) | Toetsenbord |
|---|---|---|---|
| Cursor bewegen | beweeg de muis | duw de stick | cursortoetsen (+ shift voor links/omhoog) |
| Klik | linkerknop | fire | **spatie** of **return** |
| Typen (Editor) | — | — | letters/cijfers, RETURN, DEL |

Klik een **dock-icoon** om een app te openen; de menubalk en het werkgebied
wisselen mee.

## Bouwen

Vereist (paden in de `.bat`-scripts, pas aan waar nodig): **Java**, **Kick
Assembler** (`KickAss.jar`), **VICE** (`x64sc`, `c1541`, `cartconv`).

**Eenmalig — charset extraheren.** De System-charset (`data/chargen.bin`) is de
C64 char-ROM en zit **niet** in deze repo (auteursrecht). Haal 'm lokaal uit je
VICE-installatie:
```bash
mkdir -p data
head -c 2048 "<VICE>/C64/chargen-901225-01.bin" > data/chargen.bin
```
(De eerste 2 KB = de hoofdletter/grafiek-set.)

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
Flashen naar echte hardware: kopieer de `.CRT` naar een SD-kaart en flash 'm met
**EasyProg** op de C64.

> De D71-versie laadt via de trage IEC-bus (~½ minuut op echte hardware). De
> cartridge-versie boot **instant**: de reset-stub kopieert de OS-image uit ROM
> naar RAM (`$0801`), zet de cartridge uit en draait als een gewone C64.

## Architectuur

```
apps/     Files · Editor · Paint · Calc · Settings
gui/      shell (desktop/dock/menubalk) · widgets
gfx/      gfx-primitieven · font · sprite (cursor)
kernel/   kernel · events · irq (raster 50 Hz) · memory · banking
hal/      vic · input (muis/joy/kbd) · disk (IEC) · sound (SID)
include/  palette · layout · memmap · abi · hardware
```

- **Beeld**: hi-res char-mode (40×25). De cursor is hardware-sprite 0.
- **Systeemklok**: raster-IRQ (50 Hz) pollt input en genereert events.
- **Geheugen**: draait uit RAM met BASIC/KERNAL uitgebankt; KERNAL wordt tijdelijk
  ingebankt voor disk-I/O.
- **Font**: de System-charset zit ingesloten (`data/chargen.bin`) op `$3800`.

## Instellingen (persistentie)

In **Settings** kies je per thema-rol (rand, bureaublad, menubalk, accent,
selectie) een kleur; **SAVE** schrijft `CD64.CFG` naar de D71. Bij het opstarten
laadt de OS dat bestand automatisch terug.

## Bestanden

| Bestand | Rol |
|---|---|
| `disk_main.asm` | entry voor de D71-build (PRG op `$0801`) |
| `main_cart.asm` | entry voor de EasyFlash-CRT (OS-image + reset-stub) |
| `build_disk.bat` / `build_cart.bat` | build-scripts |
| `Commodore-Desk-64-Ontwikkelplan.md` | volledig ontwikkelplan (fases 0–10) |
| `C64_KICKASS_SKILL.md` | Kick Assembler-werkinstructie |
| `c64_ka_syntax_checker.py` | statische syntax-check |

## Status

Fases **0–10** afgerond: boot (disk + cart), kernel/IRQ, gfx-primitieven,
input-HAL, events, desktop-shell, widgets, 5 apps, kleur-personalisatie met
opslag, en afwerking (splash, geluid, cartridge, docs).

**Nog open / upgrades:** echte hi-res/multicolor bitmap-Paint; dock-vorm en
lettertype ook in Settings (variabelen staan klaar); Classic/Bold-fonts; 2×2
dock-iconen; uitklap-menu's; config in flash i.p.v. disk. Later: **Commodore
128**-port (alles hardware-specifieks zit in `hal/`).
