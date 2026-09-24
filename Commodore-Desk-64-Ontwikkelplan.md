# Commodore Desk 64 — Ontwikkelplan

> Een grafische, Apple-achtige desktop-GUI voor de Commodore 64, gebouwd in
> 6502/6510-assembly met Kick Assembler, uitgeleverd als EasyFlash-cartridge
> (.CRT) die als eerste opstart. Geen sleepbare vensters — een vaste dock
> onderin, een contextuele menubalk bovenin, en de app in het midden.

**Status:** planningsdocument · **Doelplatform:** C64 PAL (VICE + echte hardware) ·
**Toolchain:** Kick Assembler 5.x + VICE x64sc (zie `C64_KICKASS_SKILL.md`) ·
**Latere port:** Commodore 128 (daarom de "64" in de naam).

---

## Inhoud

1. [Visie & ontwerpprincipes](#1-visie--ontwerpprincipes)
2. [Kernbeslissingen (met onderbouwing)](#2-kernbeslissingen-met-onderbouwing)
3. [Het kleurenpalet — hard vastgelegd](#3-het-kleurenpalet--hard-vastgelegd)
4. [Schermindeling & grid](#4-schermindeling--grid)
5. [Hardware, geheugen & EasyFlash-banking](#5-hardware-geheugen--easyflash-banking)
6. [Software-architectuur & mapstructuur](#6-software-architectuur--mapstructuur)
7. [ABI — geheugen-, register- en aanroepconventies](#7-abi--geheugen-register--en-aanroepconventies)
8. [Input-HAL (muis / joystick / toetsenbord)](#8-input-hal-muis--joystick--toetsenbord)
9. [Het GUI-framework — API](#9-het-gui-framework--api)
10. [Het app-model & de app-lifecycle](#10-het-app-model--de-app-lifecycle)
11. [Build-pipeline: van .asm naar .CRT naar hardware](#11-build-pipeline-van-asm-naar-crt-naar-hardware)
12. [Ontwikkel-stappenplan in fases (0–10)](#12-ontwikkel-stappenplan-in-fases-010)
13. [Werken met AI — de "context pack" methode](#13-werken-met-ai--de-context-pack-methode)
14. [Teststrategie](#14-teststrategie)
15. [Risico's & valkuilen](#15-risicos--valkuilen)
16. [Commodore 128-toekomst](#16-commodore-128-toekomst)
17. [DESIGN-BRIEF — voorbeeldschermen (kopieerbaar)](#17-design-brief--voorbeeldschermen-kopieerbaar)
18. [Woordenlijst](#18-woordenlijst)

---

## 1. Visie & ontwerpprincipes

Commodore Desk 64 (hierna **CD64**) is een grafische shell die na het aanzetten
van de C64 direct verschijnt, in plaats van de BASIC-READY-prompt. Het gevoel is
**Apple/macOS-achtig**, niet Windows/GEOS:

- **Dock onderin** met applicatie-iconen.
- **Contextuele menubalk bovenin**: klik je een app-icoon aan, dan verschijnt de
  menubalk van díe app bovenaan.
- **Werkgebied in het midden**: de actieve app vult het middendeel.
- **Eén aanwijzer** die met **muis, joystick én toetsenbord** te bedienen is,
  ongeacht wat er is aangesloten.
- **Geen sleepbare, overlappende vensters.** Dat is de bewuste kernkeuze: het
  bespaart geheugen én rekentijd (zie §2).

Ontwerpprincipes die elke beslissing sturen:

| Principe | Concreet gevolg |
|---|---|
| **Geheugen is het schaarste goed** | Vaste schermregio's; char-mode i.p.v. bitmap voor de shell; apps worden vanaf de cartridge ingebankt, niet allemaal tegelijk in RAM. |
| **De VIC-II doet het zware werk** | De desktop is een tekst/char-scherm dat de VIC-II gratis blijft tekenen; de CPU hoeft het beeld niet te onderhouden. |
| **Alles achter een HAL** | Muis, joystick, toetsenbord, disk en beeld zitten achter drivers, zodat de C128-port alleen drivers vervangt. |
| **Stabiele API vóór implementatie** | AI genereert code tegen een vastgelegde API (§9), niet ad hoc. |
| **Palet is heilig** | Uitsluitend de 16 VIC-II-kleuren uit §3, geen benaderingen. |

---

## 2. Kernbeslissingen (met onderbouwing)

Dit zijn de architectonische keuzes die alles daarna bepalen. Ze staan hier
expliciet zodat ze bewust genomen zijn en niet later "per ongeluk" anders lopen.

### 2.1 Beeldmodus: hi-res **character mode** voor de shell

**Keuze:** de desktop, dock, menubalk en de meeste apps draaien in de standaard
**tekstmodus met een herdefinieerde character set** (40×25 cellen van 8×8
pixels, 320×200). Grafische apps (Paint, plaatjesviewer) schakelen tijdelijk
naar **hi-res bitmap** (320×200) of **multicolor bitmap** (160×200).

**Waarom char-mode en niet bitmap zoals GEOS?**

- GEOS gebruikte een bitmap omdat het **overlappende, sleepbare vensters** had —
  daarvoor moet je willekeurige pixels kunnen overtekenen. CD64 heeft dat
  bewust **niet**. Zonder sleepbare vensters is een bitmap pure verspilling.
- Char-mode kost **~4 KB** (2 KB charset + 1000 bytes scherm-RAM + 1000 bytes
  kleuren-RAM) tegenover **~9 KB** voor één hi-res bitmap, en het scherm
  hertekenen is in char-mode bijna gratis: je schrijft één byte per cel.
- Per 8×8-cel heb je in hi-res char-mode een **vrij te kiezen voorgrondkleur**
  (uit kleuren-RAM) op één gedeelde achtergrondkleur. Dat is precies genoeg voor
  scherpe tekst, kaders en 2-kleurs-iconen.
- Multicolor char-mode is er als variant voor kleurrijkere iconen (4 kleuren per
  cel, maar halve horizontale resolutie). Overweeg dit per app.

### 2.2 De aanwijzer: **hardware-sprite 0**

De muispijl is **sprite 0**. Sprites zweven in hardware boven zowel char- als
bitmap-mode, zonder dat je het scherm eronder hoeft te herstellen. Dit is de
klassieke, goedkope oplossing (ook GEOS deed dit). Sprite = 24×21 pixels, prima
voor een pijl. De sprite volgt de **virtuele cursor** die de input-HAL bijhoudt.

### 2.3 Eén virtuele cursor, drie invoerbronnen

De HAL leest elke frame muis (1351), joystick (poort 1 én 2) en toetsenbord, en
voedt daarmee **één** cursorstaat `(x, y, knop)`. Auto-detectie kiest de actieve
bron. Zie §8 voor details — dit is technisch het lastigste onderdeel (met name
de 1351-muis via de POT-lijnen).

### 2.4 Assembler & taal: **Kick Assembler**, pure 6502-asm

Je hebt Kick Assembler al draaien (`build.bat`, `C64_KICKASS_SKILL.md`). We
blijven daarbij. Kick Assembler is bovendien ideaal voor cartridges: met
**segments** en `.segmentout` bouw je meerdere 8/16 KB-banks in één binair
bestand (zie §5, §11 en §9.8 van de skill). Geen C — de GUI-loop en
tekenroutines moeten strak en cyclus-bewust zijn.

### 2.5 Uitlevering: **EasyFlash .CRT**, boot als eerste

CD64 wordt een EasyFlash-cartridge. Bij reset draait de cartridge-bootcode
(CBM80-signatuur), kopieert de kernel naar RAM en start de shell — vóór BASIC.
Zie §5.3 en §11.

### 2.6 Persistente instellingen: op disk, niet op cartridge

De gebruiker mag alle kleuren aanpassen (eis). Die instellingen bewaren we op
**disk / SD2IEC / 1541** (`CD64.CFG`), niet in de flash: flash is traag te
beschrijven en heeft een beperkt aantal schrijfcycli. EasyFlash-RAM (`$DF00`,
256 bytes) gebruiken we alleen als vluchtige scratch, niet voor opslag.

---

## 3. Het kleurenpalet — hard vastgelegd

**Alleen deze 16 kleuren. Geen afwijkingen, geen benaderingen.** In VIC-II
selecteer je een kleur met de index (0–15); de hex is alleen voor de mockups.

| Index | Naam (EN) | Naam (NL) | Hex | Kick-constante |
|---|---|---|---|---|
| 0 | Black | Zwart | `#000000` | `BLACK` |
| 1 | White | Wit | `#FFFFFF` | `WHITE` |
| 2 | Red | Rood | `#880000` | `RED` |
| 3 | Cyan | Cyaan | `#AAFFEE` | `CYAN` |
| 4 | Purple | Paars/Violet | `#CC44CC` | `PURPLE` |
| 5 | Green | Groen | `#00CC55` | `GREEN` |
| 6 | Blue | Blauw | `#0000AA` | `BLUE` |
| 7 | Yellow | Geel | `#EEEE77` | `YELLOW` |
| 8 | Orange | Oranje | `#DD8855` | `ORANGE` |
| 9 | Brown | Bruin | `#664400` | `BROWN` |
| 10 | Light Red | Lichtrood | `#FF7777` | `LIGHT_RED` |
| 11 | Dark Grey | Donkergrijs | `#333333` | `DARK_GREY` |
| 12 | Medium Grey | Grijs | `#777777` | `GREY` |
| 13 | Light Green | Lichtgroen | `#AAFF66` | `LIGHT_GREEN` |
| 14 | Light Blue | Lichtblauw | `#0088FF` | `LIGHT_BLUE` |
| 15 | Light Grey | Lichtgrijs | `#BBBBBB` | `LIGHT_GREY` |

**Voorgesteld standaard-thema (aanpasbaar door de gebruiker):**

| Rol | Kleur | Index |
|---|---|---|
| Bureaublad-achtergrond | Blauw | 6 |
| Rand (border, `$D020`) | Lichtblauw | 14 |
| Menubalk-achtergrond | Lichtgrijs | 15 |
| Menubalk-tekst | Zwart | 0 |
| Dock-achtergrond | Donkergrijs | 11 |
| Venster/paneel-achtergrond | Grijs | 12 |
| Standaardtekst | Wit | 1 |
| Selectie/highlight | Cyaan | 3 |
| Accent / actieve knop | Geel | 7 |
| Waarschuwing | Lichtrood | 10 |

> **Cel-kleurregel (cruciaal voor mockups én code):** in hi-res char-mode heeft
> het héle scherm **één** achtergrondkleur (`$D021`); elke 8×8-cel mag daarnaast
> **één** voorgrondkleur uit de 16 hebben (kleuren-RAM). Wil je binnen één cel
> méér kleuren, dan moet die regio multicolor zijn (bg + 2 gedeelde + 1 per cel,
> halve h-resolutie). Ontwerp de schermen binnen deze regel — zie de design-brief
> in §17.

Leg dit in code vast als `include/palette.inc` met de 16 `.const`-kleuren én de
thema-rollen, zodat elke module dezelfde namen gebruikt.

---

## 4. Schermindeling & grid

Werkveld: **40 kolommen × 25 rijen**. De indeling is **runtime instelbaar**
(zie hieronder); dit is het standaard-preset **LARGE**:

```
 Kol:  0                                       39
      +------------------------------------------+
Rij 0 |  Menubalk (contextueel per app)          |  <- rij 0
      +------------------------------------------+
Rij 1 |                                          |
  ..  |            WERKGEBIED / CONTENT          |  <- rij 1..20 (20 rijen)
Rij20 |                                          |
      +------------------------------------------+
Rij21 |  Statusregel:  "READY"       38K FREE    |  <- rij 21
      +------------------------------------------+
Rij22 |  [Files] [Editor] [Paint] [Calc] [Set]   |  <- dock-iconen, rij 22-23 (2x2)
Rij23 |                                          |
Rij24 |   labels onder de iconen                  |  <- rij 24
      +------------------------------------------+
```

**Layout is een instelling, geen vaste constante.** Teken- en app-code leest de
content-grenzen uit **runtime-variabelen** (`LAY_*` in de OS-vars-pagina `$0200`),
nooit uit hardgecodeerde rij-nummers. Bij boot worden die gevuld uit het gekozen
preset; Settings (fase 9) kan schakelen tussen presets en het scherm hertekenen.
Dit kost nu vrijwel niets en maakt bovendien de C128-port (80 koloms) eenvoudiger.

Twee presets in `include/layout.inc`:

| Regio | LARGE (standaard) | COMPACT |
|---|---|---|
| Menubalk | rij 0 | rij 0 |
| Werkgebied | rij 1–20 | rij 1–21 |
| Statusbalk | rij 21 | rij 22 |
| Dock-iconen | rij 22–23 (2×2) | rij 23 (compact) |
| Dock-labels | rij 24 | rij 24 |

Runtime-variabelen: `LAY_dockMode`, `LAY_menubarRow`, `LAY_contentTop`,
`LAY_contentBottom`, `LAY_statusRow`, `LAY_dockIconRow`, `LAY_dockLabelRow`.

**LARGE**: 2×2-iconen (16×16 px) + label eronder — meest Apple-achtig en best
leesbaar; ~5 iconen ruim verdeeld. **COMPACT**: kleinere iconen, één werkrij extra.

### 4.1 Lettertypes (charsets) — instelbaar

In char-mode ís een lettertype de **character set**: 256 tekens × 8 bytes = 2 KB.
CD64 biedt **3 fonts** als instelling (`FONT_SYSTEM`, `FONT_CLASSIC`, `FONT_BOLD`),
opgeslagen in flash/op disk en bewaard als `fontId` in `CD64.CFG`.

- **Wisselen:** de gekozen font wordt bij boot/wissel naar de actieve charset-RAM
  (`CHARSET_BASE = $3000`) gekopieerd (2 KB, paar ms). Alternatief: alle drie in de
  VIC-bank en instant wisselen via `$D018` (kost meer VIC-bank-ruimte; latere optim.).
- **Gedeeld UI-glyphblok:** iconen, kaderlijnen, pijltjes en scrollbar zijn óók
  tekens. Die staan in **alle 3 de fonts op dezelfde posities** (vanaf
  `UI_GLYPH_FIRST`), zodat alleen de tekst-glyphs verschillen. Per font ontwerp je
  dus ~96 tekens i.p.v. 256, en de interface blijft consistent.
- **Beperking:** alles moet in **8×8** leesbaar blijven op 40 kolommen — de fonts
  verschillen in stijl, niet in grootte.
- **Kosten:** 3 fonts = ~6 KB opslag; verwaarloosbaar op 512 KB / de D71.

Runtime-variabele: `CFG_fontId`. Ontwerp de 3 charsets in **fase 2**; voeg de
font-keuze toe aan Settings in **fase 9**.

Scherm-RAM staat standaard op `$0400`; kleuren-RAM vast op `$D800`. De
charset-locatie kies je met `$D018` (zie §5.2).

---

## 5. Hardware, geheugen & EasyFlash-banking

### 5.1 De C64-hardware die we gebruiken

- **6510 CPU** @ ~1 MHz, met de bank-schakelaar op `$0001` (I/O, ROMs in/uit).
- **VIC-II** (`$D000–$D02E`): scherm, sprites, char/bitmap-mode, rasterinterrupt.
- **CIA #1** (`$DC00`): toetsenbord-matrix + joystick poort 2, timers.
- **CIA #2** (`$DD00`): VIC-bank-selectie, seriële IEC-bus (disk), joystick p.1.
- **SID** (`$D400`): geluid, én **POT X/POT Y** (`$D419/$D41A`) voor de 1351-muis.
- **KERNAL/BASIC-ROM**: banken we grotendeels uit om RAM vrij te maken.

### 5.2 Geheugenkaart (voorstel)

We schakelen BASIC-ROM (`$A000–$BFFF`) en meestal KERNAL-ROM (`$E000–$FFFF`)
uit via `$0001`, en houden I/O (`$D000–$DFFF`) zichtbaar. Dat geeft veel vrij RAM.

| Bereik | Grootte | Gebruik |
|---|---|---|
| `$0000–$0001` | 2 B | 6510-poort (memory config) — **nooit misbruiken** |
| `$0002–$00FF` | 254 B | Zeropage — OS-pseudoregisters + scratch (§7) |
| `$0100–$01FF` | 256 B | Stack |
| `$0200–$03FF` | 512 B | OS-variabelen, event-queue, cursorstaat |
| `$0400–$07FF` | 1 KB | Scherm-RAM (char-mode) |
| `$0800–$1FFF` | 6 KB | Kernel + GUI-framework + drivers (resident) |
| `$2000–$3FFF` | 8 KB | **Bitmap** (als een app naar bitmap-mode gaat) |
| `$3000–$37FF` | 2 KB | Herdefinieerde charset (als geen bitmap actief) — pas locatie aan indien bitmap gebruikt |
| `$4000–$BFFF` | 32 KB | App-werkgeheugen + resources (ingebankt vanaf cartridge) |
| `$C000–$CFFF` | 4 KB | Vrije scratch / buffers (nooit door BASIC gebruikt) |
| `$D000–$DFFF` | 4 KB | I/O (VIC/SID/CIA/kleuren-RAM/cartridge-registers) |
| `$E000–$FFFF` | 8 KB | RAM onder KERNAL, of KERNAL zelf tijdens disk-I/O |

> Dit is een **startvoorstel**. De charset- en bitmap-locaties botsen bewust niet
> tegelijk: in char-mode-shell staat de charset op `$3000`; schakelt een app naar
> bitmap, dan verhuist de charset of gebruik je een andere VIC-bank. Leg de
> definitieve kaart vast in `include/memmap.inc` in fase 1 en houd hem heilig.

### 5.3 EasyFlash-banking

EasyFlash levert flash in **banken van 16 KB** (8 KB LOROM op `$8000–$9FFF` via
ROML + 8 KB HIROM op `$A000–$BFFF` / `$E000–$FFFF` via ROMH), geschakeld met:

- **`$DE00`** — bankregister (bank 0–63, wij gebruiken de eerste 32 voor 512 KB).
- **`$DE02`** — controleregister: bit 7 = LED, bit 2 = GAME, bit 1 = EXROM,
  bit 0 = mode.
- **`$DF00–$DFFF`** — 256 B EasyFlash-**RAM**, altijd zichtbaar ongeacht de bank.

**Boot-flow (geverifieerd in fase 0 — NIET via CBM80!):**

Een EasyFlash start bij reset in **ultimax-modus**: de 6510 leest de reset-vector
uit `$FFFC`, en ROMH ligt dan op `$E000–$FFFF`. In ultimax is er echter alleen
RAM op `$0000–$0FFF` en heeft de VIC **geen toegang tot de char-ROM**. Daarom:

1. Reset → 6510 leest `$FFFC` (in ROMH/`$E000`) → springt naar `coldStart` in
   bank 0 ROMH.
2. `coldStart` kopieert een kleine **trampoline** naar RAM (`$0200`) en springt
   ernaartoe (de trampoline gebruikt alleen absolute adressering, dus hij werkt
   vanaf zijn RAM-kopie).
3. De trampoline schakelt de EasyFlash naar **16K-modus** (`$DE02 = $87`) — dit
   verlaat ultimax; nu zijn char-ROM en volledig RAM beschikbaar, ROML ligt op
   `$8000`, ROMH op `$A000`. Zet `$01 = $37` en spring naar het hoofdprogramma in
   ROML (`$8000`).
4. Het hoofdprogramma zet zelf de VIC op (geen KERNAL-init: VIC-bank via CIA2,
   `$D018`, `$D011=$1B`, …), kopieert kernel + framework naar RAM en start de shell.

> **Let op:** de ROMH-bytes worden op **`$E000`** geassembleerd (voor de
> ultimax-fase en de vectoren), maar door cartconv opgeslagen als de nominale
> `$A000`-chip. Alleen de trampoline-fase draait op `$E000`; daarna draait alles
> op `$8000`/RAM.

**De bank-switch-regel:** de code die `$DE00`/`$DE02` verandert, mag **niet** zelf
onder de bank staan die verdwijnt (die valt dan onder je voeten weg). Plaats de
`switch_bank`/`farcall`-routine in RAM (bv. `$0200` of het `$0800`-gebied) of in
de EasyFlash-RAM `$DF00`.

**Toolchain-details (geverifieerd):** cartconv gebruikt type-naam **`easy`** (niet
`easyflash`); bouw met `cartconv -t easy -b -p` voor een volledige 1 MB-image.
Headless testen: `x64sc -warp -limitcycles <n> -exitscreenshot out.png -cartcrt
CommodoreDesk64.crt` maakt automatisch een schermafbeelding van het eindbeeld.

**Bank-indeling (voorstel voor 512 KB = 32 banken × 16 KB):**

| Bank(en) | Inhoud |
|---|---|
| 0 | Bootstub + CBM80 + kernel-kern + `farcall`-loader |
| 1–2 | GUI-framework + drivers (naar RAM gekopieerd bij boot) |
| 3 | Charset(s), dock-iconen, cursor-sprite, standaardthema |
| 4–7 | App: File Manager |
| 8–11 | App: Text Editor |
| 12–15 | App: Paint |
| 16–17 | App: Calculator |
| 18–19 | App: Settings/Colors |
| 20–31 | Vrij voor extra apps + resources |

---

## 6. Software-architectuur & mapstructuur

Gelaagd, elke laag praat alleen met de laag eronder via de API:

```
+---------------------------------------------------+
|  APPS   Files · Editor · Paint · Calc · Settings  |
+---------------------------------------------------+
|  SHELL  desktop · dock · menubalk · app-switcher  |
+---------------------------------------------------+
|  GUI    window · menu · button · dialog · list    |
+---------------------------------------------------+
|  GFX    text · box · fill · color · icon · sprite |
+---------------------------------------------------+
|  KERNEL memory · banking · events · timers · IRQ  |
+---------------------------------------------------+
|  HAL    keyboard · mouse · joystick · disk · vic  |
+---------------------------------------------------+
|  HARDWARE  6510 · VIC-II · CIA · SID · EasyFlash  |
+---------------------------------------------------+
```

Mapstructuur (Kick Assembler, `#import`-gedreven, één `.filenamespace` per
bestand — zie skill §8):

```
commodore_desk/
├─ main.asm                  // top-level: segments, banks, boot-entry
├─ include/
│  ├─ palette.inc            // 16 kleuren + thema-rollen
│  ├─ layout.inc             // schermregio-constanten
│  ├─ memmap.inc             // geheugenkaart-constanten
│  ├─ abi.inc                // zeropage-pseudoregisters, macro's, farcall
│  └─ hardware.inc           // VIC/CIA/SID/EasyFlash-registernamen
├─ boot/
│  └─ bootstub.asm           // CBM80, RAM-setup, kernel-copy, jump
├─ kernel/
│  ├─ kernel.asm             // init, hoofd-eventloop
│  ├─ memory.asm             // eenvoudige allocator / buffers
│  ├─ banking.asm            // switch_bank, farcall (in RAM/$DF00)
│  ├─ events.asm             // event-queue (klik, toets, timer)
│  └─ irq.asm                // raster-IRQ: input pollen + sprite bewegen
├─ hal/
│  ├─ vic.asm                // beeldmodus, VIC-bank, raster-setup
│  ├─ keyboard.asm           // matrix-scan -> keycodes
│  ├─ mouse.asm              // 1351 via POT X/Y (delta)
│  ├─ joystick.asm           // poort 1 & 2, digitaal
│  └─ disk.asm               // IEC load/save (CD64.CFG, bestanden)
├─ gfx/
│  ├─ text.asm               // schrijf tekst in scherm-RAM (screencodes)
│  ├─ box.asm                // kaders/panelen met randtekens
│  ├─ fill.asm               // vlakken + kleuren-RAM vullen
│  ├─ icon.asm               // teken 2x2/3x3-icoon uit charset
│  └─ sprite.asm             // cursor-sprite + hardware-sprites
├─ gui/
│  ├─ desktop.asm            // bureaublad + statusregel
│  ├─ dock.asm               // dock-iconen + hit-test
│  ├─ menubar.asm            // contextuele menubalk + dropdowns
│  ├─ button.asm             // knoppen + hover/click-state
│  ├─ checkbox.asm           // checkbox/radiobutton
│  ├─ dialog.asm             // modale dialogen (OK/Cancel/Save)
│  └─ list.asm               // scrollbare lijst (bestanden, kleuren)
├─ apps/
│  ├─ filemanager.asm
│  ├─ editor.asm
│  ├─ paint.asm
│  ├─ calc.asm
│  └─ settings.asm
├─ data/
│  ├─ charset.bin            // herdefinieerde tekenset (2 KB)
│  ├─ icons.bin              // dock-iconen (chars)
│  ├─ cursor.spr             // sprite-data voor de pijl
│  └─ theme_default.bin      // standaardkleuren
└─ build/                    // uitvoer: .prg, .bin, .crt, symbols
```

---

## 7. ABI — geheugen-, register- en aanroepconventies

Dit is de **contractlaag** waar AI-gegenereerde modules zich aan houden. Leg dit
één keer vast in `include/abi.inc` en verwijs er in elke prompt naar.

### 7.1 Zeropage-pseudoregisters

Omdat we BASIC/KERNAL uitbanken, is vrijwel de hele zeropage van ons (behalve
`$00/$01`). Voorstel:

| ZP-adres | Naam | Gebruik |
|---|---|---|
| `$02–$0F` | `r0`–`r6` (7×word) | 16-bits pseudoregisters / pointers |
| `$10–$1F` | `a0`–`a7` (8×byte) | byte-argumenten & scratch |
| `$20–$2F` | `tmp0`–`tmp15` | vrije scratch binnen één routine |
| `$30–$3F` | cursor/GUI-state | `curX,curY,curBtn,hotItem,...` |
| `$40–$8F` | module-gereserveerd | per subsysteem toegewezen |
| `$90–$FF` | vrij / KERNAL-restanten | alleen gebruiken als KERNAL uit staat |

Definieer ze als `.label r0 = $02` enz., en gebruik pseudocommands als `mov16`,
`add16`, `inc16` uit de skill (§6.3) voor 16-bits werk.

### 7.2 Aanroepconventie

- **Byte-argument:** in `A`. **Tweede byte:** in `X`. **Derde:** in `Y`.
- **Word-argument / pointer:** in `r0` (low in `$02`, high in `$03`), volgende in
  `r1`, enz.
- **Retour:** byte in `A`, word in `r0`. **Foutvlag:** `carry` gezet = fout,
  `A` = foutcode.
- **Bewaren:** *caller-saves*. Een routine mag `A/X/Y` en alle `tmp*` vrij
  vernietigen. Wil de aanroeper iets bewaren, doet die dat zelf.
- **Documentatie-koptekst:** elke publieke routine krijgt een vast commentaarblok:

```asm
// gfx_DrawText — schrijf een string in scherm-RAM
// In : r0 = pointer naar string ($ff-getermineerd, screencodes)
//      a0 = kolom (0-39), a1 = rij (0-24), a2 = kleur-index
// Uit: r0 = pointer voorbij het einde
// Klobbert: A,X,Y, tmp0-tmp3
// Carry: -
```

### 7.3 Cross-bank aanroepen (`farcall`)

Code in een andere cartridge-bank roep je nooit rechtstreeks aan. Gebruik één
`farcall` in RAM/`$DF00`:

```asm
// farcall — roep een routine in een andere EasyFlash-bank aan
// In : a0 = doelbank, r0 = doeladres, overige args volgens de routine
// Doet: bewaart huidige bank, schakelt, JSR (r0), herstelt bank, RTS
```

Zo blijft banking onzichtbaar voor de aanroeper en kan AI gewoon "roep
`app_Paint_Init` aan" genereren zonder de bankmechaniek te kennen.

---

## 8. Input-HAL (muis / joystick / toetsenbord)

De HAL levert elke frame (in de raster-IRQ) één bijgewerkte cursorstaat:
`curX (0–319/0–39), curY (0–199/0–24), curBtn (bit0=links, bit1=rechts)` plus
losse toets-events in de event-queue.

### 8.1 Commodore 1351-muis (proportioneel)

- Aangesloten op **controlepoort 1**. De X/Y-beweging leest de VIC-II via de
  **SID POT-registers** `$D419` (POT X) en `$D41A` (POT Y).
- De 1351 stuurt een 6-bits waarde die **doorloopt** (0→63→0). Je houdt per as de
  vorige waarde bij en berekent de **delta** (met wrap-correctie), en telt die
  bij `curX/curY` op. Klem op de schermgrenzen.
- Muisknoppen: linker = joystick-"fire" bit, rechter = een van de
  richtingsbits, gelezen via de CIA joystick-poort.
- **Valkuil:** POT-lijnen zijn gemultiplext met de paddles en reageren traag;
  lees ze stabiel (één as per frame kan al genoeg zijn) en filter ruis.

### 8.2 Joystick (poort 1 én 2, digitaal)

- Lees de richtingsbits en fire via **CIA #1 `$DC00`** (poort 2) en
  **`$DC01`** (poort 1). Actief-laag: een 0-bit = ingedrukt.
- Digitaal betekent: de cursor beweegt met een **vaste snelheid** per frame
  zolang een richting ingedrukt is (met eventueel versnelling na X frames).
- Een **1350-muis** gedraagt zich als joystick — die valt hier vanzelf onder.

### 8.3 Toetsenbord

- Matrix-scan via CIA #1 (`$DC00` schrijven = kolom kiezen, `$DC01` lezen = rij).
  Óf gebruik de KERNAL-scan als KERNAL even ingebankt is — maar eigen scan geeft
  meer controle (meerdere toetsen, geen key-repeat-verrassingen).
- **Cursorbesturing:** de pijltjestoetsen bewegen de aanwijzer; `Return`/`Space`
  = klik; `Tab` = volgende dock-icoon/knop; letters = sneltoetsen in menu's.
- Gewone tekstinvoer (Editor, dialoogvelden) gaat via keycodes in de
  event-queue.

### 8.4 Auto-detectie & prioriteit

Elke frame: als de muis meetbaar beweegt → muismodus; anders als joystick een
richting geeft → joystickmodus; toetsenbord werkt altijd parallel. Eén
`input_source`-vlag onthoudt de laatst-actieve bron zodat de cursor niet
"schokt" tussen bronnen.

---

## 9. Het GUI-framework — API

Dit is de API waar apps én AI tegen programmeren. Namen zijn voorstellen; leg de
definitieve set vast vóór je begint te bouwen. Alle coördinaten in **cellen**
(kolom/rij) tenzij anders vermeld.

### 9.1 GFX — teken-primitieven (`gfx/`)

| Routine | In | Doet |
|---|---|---|
| `gfx_Cls` | a2=kleur | wis scherm-RAM, vul kleuren-RAM |
| `gfx_SetBg` | a0=kleur | zet `$D021` achtergrond |
| `gfx_SetBorder` | a0=kleur | zet `$D020` rand |
| `gfx_PutChar` | a0=kol,a1=rij,a2=screencode,a3=kleur | één cel |
| `gfx_DrawText` | r0=str,a0=kol,a1=rij,a2=kleur | string (screencodes, `$ff`-eind) |
| `gfx_DrawBox` | a0,a1=hoek, a2,a3=breedte/hoogte, a4=kleur | kader met randtekens |
| `gfx_FillRect` | a0,a1,a2,a3=rect, a4=char, a5=kleur | vlak vullen |
| `gfx_InvertCell` | a0=kol,a1=rij | highlight (kleur wisselen) |
| `gfx_DrawIcon` | a0=kol,a1=rij, r0=icoon-id | teken 2×2/3×3-icoon |
| `gfx_SetMode` | a0=mode (CHAR/HIRES/MC) | schakel beeldmodus |

### 9.2 Cursor & sprites (`gfx/sprite.asm`)

| Routine | In | Doet |
|---|---|---|
| `spr_CursorShow` / `spr_CursorHide` | — | pijl aan/uit |
| `spr_CursorMove` | curX,curY (px) | zet sprite 0 op cursorpositie |
| `spr_Set` | a0=nr, r0=data, a1=kleur | overige sprites |

### 9.3 GUI-widgets (`gui/`)

| Routine | In | Doet |
|---|---|---|
| `dock_Init` | r0=applijst | teken dock + labels |
| `dock_HitTest` | curX,curY | geeft app-index onder cursor, of -1 |
| `menubar_Set` | r0=menudef | vervang menubalk (bij app-wissel) |
| `menubar_HitTest` | curX,curY | geef menu-id / item-id |
| `menu_DropDown` | a0=menu-id | teken dropdown, wacht op keuze |
| `button_Draw` | rect,label,state | knop tekenen |
| `button_HitTest` | curX,curY | ingedrukt? |
| `checkbox_Draw` / `checkbox_Toggle` | rect,state | checkbox |
| `dialog_Show` | r0=dialogdef | modale dialoog, retourneert keuze |
| `list_Draw` / `list_Scroll` / `list_Select` | rect,items | scrollbare lijst |

### 9.4 Kernel & events (`kernel/`)

| Routine | In | Doet |
|---|---|---|
| `evt_Poll` | — | volgende event uit queue (klik/toets/timer) of "leeg" |
| `evt_Wait` | — | blokkeer tot er een event is |
| `mem_Alloc` / `mem_Free` | grootte | simpele bufferallocatie |
| `bank_Switch` | a0=bank | wissel EasyFlash-bank |
| `farcall` | a0=bank,r0=adres | cross-bank JSR (§7.3) |

Event-record (voorstel, in de queue): `type` (MOUSE_DOWN, MOUSE_UP, KEY, TIMER),
`x`, `y`, `code`.

---

## 10. Het app-model & de app-lifecycle

Een app is een module in één of meer cartridge-banken. Elke app exporteert een
**vaste tabel met vier vectoren**:

```asm
// App-header (aan het begin van de app-bank, vaste offset)
app_Init:     // zet menubalk, teken beginscherm in het werkgebied
app_Event:    // verwerk één event (klik/toets); wordt door de shell gevoed
app_Draw:     // (her)teken indien nodig
app_Suspend:  // ruim op, geef geheugen terug (bij app-wissel)
```

**Lifecycle:**

1. Gebruiker klikt dock-icoon → `dock_HitTest` geeft de app-index.
2. Shell roept `app_Suspend` van de huidige app aan (indien er één actief is).
3. Shell doet `farcall` naar `app_Init` van de nieuwe app: die zet via
   `menubar_Set` zijn eigen menubalk en tekent het werkgebied.
4. Hoofd-eventloop van de shell voedt events door aan `app_Event` tot de
   gebruiker een andere app kiest of afsluit.

Belangrijk: er is **altijd precies één actieve app** in het werkgebied (geen
overlappende vensters). De "desktop" zelf is de nul-app (leeg werkgebied +
misschien een klok/logo).

---

## 11. Build-pipeline: van .asm naar .CRT naar hardware

Je hebt de kern al (`build.bat`, Java, KickAss.jar, x64sc). We breiden uit naar
cartridge-uitvoer.

### 11.1 Stap 1 — banken bouwen met Kick Assembler-segments

Gebruik segments + `.segmentout` (skill §9.8) om per bank een 16 KB-blok te
bouwen en ze achter elkaar in één cartridge-binary te zetten:

```asm
        .segment CART [outBin="build/cd64.bin"]
        .segmentout [segments="BANK0"]
        .segmentout [segments="BANK1"]
        // ... alle 32 banken ...

        .segmentdef BANK0 [min=$8000, max=$bfff, fill]   // 16 KB, opgevuld
        .segmentdef BANK1 [min=$8000, max=$bfff, fill]
        // ...
```

Elke bank mag hetzelfde adresbereik gebruiken omdat ze in aparte segments staan.
`fill` dwingt de exacte 16 KB af (verplicht voor een cartridge-image).

### 11.2 Stap 2 — .CRT maken met VICE `cartconv`

Zet de rauwe bank-binary om naar een EasyFlash-.CRT (cartridge-type 32):

```bash
cartconv -t easyflash -i build/cd64.bin -o build/CommodoreDesk64.crt -n "Commodore Desk 64"
```

`cartconv` zit bij VICE. Controleer met `cartconv -o` op fouten (te grote/kleine
image, verkeerde banklengte).

### 11.3 Stap 3 — testen in VICE

```bash
x64sc -cartcrt build/CommodoreDesk64.crt +confirmonexit
```

Voor invoer-tests: koppel in VICE een **1351-muis** aan poort 1 en een joystick
aan poort 2 (Settings → Control port devices). Gebruik `-vicesymbols` (skill
§2.3) zodat je in de monitor op labelnaam kunt breken. De `capture_vice.ps1` die
je al hebt, maakt screenshots van het VICE-venster voor visuele controle.

### 11.4 Stap 4 — flashen naar echte hardware

Zet de `.CRT` op een SD-kaart, start **EasyProg** op de C64 en flash het bestand
naar de EasyFlash-cartridge. Reset → CD64 start.

### 11.5 Build-script

Breid `build.bat` (of maak `build_cart.bat`) uit met: assembleren → syntax-check
(`c64_ka_syntax_checker.py`, 0 errors verplicht, skill §2.4) → `cartconv` →
optioneel x64sc starten. Houd ook een **snelle .prg-build** voor losse modules
(een module in isolatie testen zónder de hele cartridge te herbouwen — zie §12
fase 0).

---

## 12. Ontwikkel-stappenplan in fases (0–10)

Elke fase heeft een **doel**, **deliverables**, een **AI-aanpak** en een
**testcriterium (definition of done)**. Bouw strikt op volgorde: elke fase leunt
op de vorige. Test elke module in isolatie in VICE vóór integratie.

### Fase 0 — Fundament & pipeline
**Doel:** een lege cartridge die opstart en één kleur op de rand zet.
**Deliverables:** repo als git-init; `include/*.inc` (palette, layout, memmap,
abi, hardware); `boot/bootstub.asm` met CBM80; segments voor bank 0; werkende
`build_cart.bat` → `.CRT`; VICE start hem.
**AI-aanpak:** genereer de CBM80-stub en de segment-skeletten; laat de rest leeg.
**Done:** `x64sc -cartcrt` start, rand wordt bv. lichtblauw, geen crash.

### Fase 1 — Kernel, geheugen & banking ✅ (disk-build)
**Doel:** RAM-setup, ROMs uitbanken, systeemklok (raster-IRQ), module-laden.
**Deliverables:** `kernel/kernel.asm` (`kernel_Init` + hoofdloop + `osvars_Init`),
`kernel/memory.asm` (`mem_AllRam` $35 / `mem_KernalIn` $36), `kernel/irq.asm`
(raster-IRQ via hardware-vector `$FFFE`, heartbeat + uptime-teller),
`kernel/banking.asm` (`mod_Load` voor disk; `farcall`/`switch_bank` als
CRT-infrastructuur), `hal/vic.asm` (`vic_Init`).
**Done (geverifieerd):** de kernel draait uit RAM met BASIC+KERNAL uitgebankt
(`$01=$35`); de raster-IRQ tikt op 50 Hz — uptime-teller loopt correct en de
heartbeat pulseert. `mod_Load` laadt PRG's van de D71 (KERNAL tijdelijk ingebankt).

> **Disk vs. cartridge:** op de disk-build laden modules met `mod_Load` (KERNAL
> LOAD). De EasyFlash-`farcall`/bank-switch is meegebouwd maar pas actief in de
> CRT-build; dan verhuist die routine naar RAM/`$DF00` (zie §5.3).

### Fase 2 — Beeldfundament (char-mode + charset + palet) ✅ (System-font)
**Doel:** de VIC-II in hi-res char-mode met de eigen charset en het thema.
**Deliverables:** `hal/vic.asm` (mode + VIC-bank + `$D018` + font-switch naar
`CHARSET_BASE`), **3 charsets** `data/font_system.bin`, `font_classic.bin`,
`font_bold.bin` (ontworpen met CharPad of via `.fill`-scripts; **gedeeld
UI-glyphblok** vanaf `UI_GLYPH_FIRST` identiek in alle drie), `gfx/text.asm`,
`gfx/fill.asm`, `gfx/box.asm`; `palette.inc` in gebruik.
**Done (geverifieerd):** `gfx_Cls`, `gfx_PutChar`, `gfx_DrawText`, `gfx_DrawBox`
en `gfx_FillRect` tekenen scherpe tekst, kaders (eigen lijnglyphs, sluiten op de
hoeken aan) en vlakken in de juiste kleuren; `font_Init` kopieert de char-ROM naar
`$3000` en overlayt het UI-glyphblok. **Nog te doen in deze fase:** de eigen
Classic- en Bold-charsets ontwerpen (System draait nu op de char-ROM-vorm).

### Fase 3 — Input-HAL & cursor-sprite ✅ (headless geverifieerd)
**Doel:** één virtuele cursor, bestuurbaar met muis, joystick én toetsenbord.
**Deliverables:** `hal/input.asm` (joystick poort 2, cursortoetsen + shift + spatie,
1351-muis via POT X/Y met delta-tracking, klemmen op scherm, debug-uitlezing),
`gfx/sprite.asm` (`spr_CursorInit`/`spr_CursorUpdate`, cursor = sprite 0), polling
in de raster-IRQ.
**Done (headless):** de pijl-sprite verschijnt, `input_Poll` draait elke frame
zonder drift/crash, cursorstaat + knop kloppen in de debug-uitlezing.
**Nog interactief te testen (op hardware/VICE met invoer):** vloeiend bewegen met
elk van de drie bronnen; mogelijke aanpassingen: 1351-poortselectie (`MOUSE_SEL`)
en Y-richting, en volledige bron-auto-detectie (`inSrc`). Nu bewegen alle bronnen
de cursor additief. `hal/mouse.asm`/`joystick.asm`/`keyboard.asm` zijn samengevoegd
tot `hal/input.asm`; later opsplitsen kan.

### Fase 4 — Event-systeem ✅
**Doel:** een event-queue die klik- (en later toets-/timer-)events levert.
**Deliverables:** `kernel/events.asm` (ringbuffer van 8, `evt_Init`/`evt_Push`/
`evt_Poll`, `EVT_MOUSEDOWN`/`EVT_MOUSEUP`); `evt_GenMouse` in `hal/input.asm`
zet knop-flanken om naar events met de cursor omgerekend naar cel (kol,rij).
**Done (geverifieerd):** de IRQ-input genereert events, de shell-hoofdlus leest ze
via `evt_Poll` en handelt klikken af.

### Fase 5 — De shell: desktop, dock, menubalk ✅ (v1)
**Doel:** het herkenbare CD64-scherm met werkende dock en contextuele menubalk.
**Deliverables:** `gui/shell.asm` — bureaublad (blauw), menubalk (rij 0, reverse
lichtgrijs), werkgebied met kader + naam actieve app, statusbalk ("READY … 38K
FREE"), dock (5 iconen + labels, rij 22-23); `dock_HitTest` (kol/8 → app),
menubalk/werkgebied wisselen contextueel per app; eigen icoon-glyphs in `font.asm`.
**Done (geverifieerd):** het bureaublad tekent volledig; een geforceerde actieve
app wisselt menubalk, werkgebied-naam én dock-highlight correct (klik-afhandeling
is gekoppeld). **Later:** 2×2-iconen i.p.v. 1 cel, hover-highlight, dropdown-menu's.

### Fase 6 — GUI-widgets ✅ (v1)
**Doel:** de herbruikbare bouwstenen voor apps.
**Deliverables:** `gui/widgets.asm` (`btn_Draw`/`btn_HitTest`, `cb_Draw`/`cb_HitTest`,
`dlg_Show`/`dlg_Draw` modale dialoog, `num2dec`), plus een interactieve widget-demo
in `gui/shell.asm` (knop-teller, checkbox, scrollbare lijst met UP/DN, dialoog-knop);
klik-routing in `onMouseDown` (dock vs. widgets).
**Done (render geverifieerd):** knop, checkbox, scrollbare lijst (5 zichtbaar,
selectie-highlight) en de dialoog-knop tekenen correct in het werkgebied; de
klik-afhandeling is gekoppeld. **Interactief te testen:** teller ophogen, checkbox
togglen, lijst scrollen/selecteren, modale OK/ANNULEER-dialoog. `button.asm`/
`checkbox.asm`/`dialog.asm`/`list.asm` zijn samengevoegd tot `widgets.asm` + shell-demo.

### Fase 7 — App-model + eerste app (File Manager) ✅ (v1, disk)
**Doel:** het app-model werkt end-to-end; de eerste echte app leest de disk.
**Deliverables:** app-dispatch in `gui/shell.asm` (per app een eigen werkgebied
+ klik-handler; bureaublad/stub/Settings-widgets/File-Manager); `apps/filemanager.asm`
(scrollbare directory-lijst + UP/DN + selectie); `hal/disk.asm` (`dir_Read` leest
de directory via het KERNAL "$"-kanaal, met raster-IRQ + ROMs correct om KERNAL
heen geschakeld; `petscii2screen`).
**Done (geverifieerd):** klik op Files → de echte D71-directory verschijnt
("COMMODORE DESK", "CD64"), scrollbaar en selecteerbaar; geen IRQ-conflict.
**Belangrijke les:** een `(ptr),y`-pointer MOET in zeropage staan (`bufPtr`), en
KERNAL-I/O vereist de raster-IRQ tijdelijk uit + KERNAL ingebankt (zie `dir_Read`).
**Later:** bestanden laden/starten, kopiëren/verwijderen, dynamisch app-laden
(bank-`farcall`) bij de CRT-build. `app_Init/Event/Draw/Suspend`-vectoren komen met
dat dynamische laden; nu is het een statische dispatch.

### Fase 8 — Meer apps: Editor, Calculator ✅ (v1)
**Doel:** tekstinvoer en een tweede/derde app bewijzen de herbruikbaarheid.
**Deliverables:** `apps/editor.asm` (32×11 tekstveld, typen + RETURN + DEL),
`apps/calc.asm` (16-bits integer-calculator, 4×4 toetsengrid, + - * / = C);
een volledige **toetsenbord-decoder** in `hal/input.asm` (`kbd_Scan` + `keyTab`,
flank-detectie, `EVT_KEY`); shell routeert toetsen naar de editor en RETURN =
klik op de cursorpositie (`cursorToCell`).
**Done (render geverifieerd):** Editor toont getypte tekst + tekstcursor;
Calculator toont display + toetsengrid; beide via de app-dispatch bereikbaar.
**Interactief te testen:** typen in de editor; rekenen in de calculator (klik de
toetsen). **Later:** editor opslaan/laden naar disk; calc-toetsen ook via het
toetsenbord; shifted symbolen in de decoder.

### Fase 9 — Paint + Settings (kleuren aanpasbaar) ✅ (v1)
**Doel:** paint-app + de kleur-personalisatie-eis met opslag.
**Deliverables:** thema-kleuren als **runtime-variabelen** (`TH_*`, gelezen door
de shell-chrome) + `theme_Apply`; `apps/settings.asm` (5 thema-rollen koppelen
aan een van de 16 kleuren, live toepassen); `apps/paint.asm` (char-mode blok-paint:
32×10 canvas + 16-kleuren-palet); `hal/disk.asm` (`cfg_Save`/`cfg_Load` via KERNAL
SAVE/LOAD, met IRQ + ROMs correct geschakeld).
**Done (geverifieerd, incl. round-trip):** in Settings kies je een kleur per rol,
die meteen doorwerkt in het hele scherm; **SAVE** schrijft `CD64.CFG` naar de D71
(directory bevestigd) en **bij een verse boot laadt `cfg_Load` hem terug** — een
rood gezette rand kwam na herstart terug. Paint verft cellen met de gekozen kleur.
**Later:** echte hi-res/multicolor bitmap-paint; dock-vorm/lettertype ook in
Settings (de `LAY_*`/`CFG_fontId` staan al klaar); tekst-glyphs voor Classic/Bold.

### Fase 10 — Polish, cartridge, documentatie ✅ (v1)
**Doel:** afwerking + de EasyFlash-CRT-route afmaken.
**Deliverables:** boot-splash (`splash_Show`), SID-klikgeluid (`hal/sound.asm`),
**`main_cart.asm`** — de volledige OS verpakt in een EasyFlash-cartridge:
reset-stub (ultimax) → trampoline → OS uit ROM naar RAM (`$0801`) → cartridge uit
→ standaard-C64. `README.md`. De System-charset is nu **ingesloten**
(`data/chargen.bin` op `$3800`) i.p.v. uit de char-ROM gekopieerd, zodat disk én
cart identiek werken.
**Done (geverifieerd in VICE):** de **cartridge boot instant** naar het volledige
bureaublad (`-cartcrt`); de disk-versie werkt onveranderd.
**Onderweg opgelost (robuustheid voor beide builds):** char-ROM-onafhankelijke
charset; charset boven de OS-image; KERNAL-init (`RESTOR`/`IOINIT`) + meldingen uit
(`MSGFLG`) voor disk-I/O op de cart; CIA-IRQ's vroeg uit om een jam in het
boot-venster te voorkomen.
**Nog open:** flashen op fysieke EasyFlash-hardware (buiten deze omgeving);
config in flash i.p.v. disk; overige upgrades (zie README).

---

## 13. Werken met AI — de "context pack" methode

6502-assembly betrouwbaar door AI laten genereren lukt alleen met een strak
kader. Werk zo:

1. **API vóór implementatie.** Leg §7 (ABI) en §9 (API) vast vóór je code laat
   schrijven. De AI implementeert tegen die handtekeningen, niet omgekeerd.
2. **Context pack per prompt.** Geef bij elke code-opdracht steeds mee:
   - het relevante deel van `C64_KICKASS_SKILL.md` (harde regels §1);
   - `palette.inc`, `layout.inc`, `memmap.inc`, `abi.inc` (of de relevante
     stukken);
   - de exacte routine-koptekst (In/Uit/Klobbert/Carry) die je wilt;
   - welke zeropage-adressen vrij zijn en welke bank de code draait.
3. **Eén module per opdracht.** Kleine, geïsoleerde routines. Geen "bouw de hele
   shell" — wél "implementeer `gfx_DrawBox` volgens deze koptekst".
4. **Verplichte checks.** Elke oplevering: `c64_ka_syntax_checker.py` = 0 errors
   (skill §2.4), dan assembleren, dan in VICE testen. Zeg expliciet dat de AI
   geen niet-bestaande opcodes/directives mag verzinnen (skill §0).
5. **Cyclus-bewustzijn waar het telt.** Voor IRQ- en tekenroutines: vraag om
   cyclustelling en `.zp`-markering van zeropage-labels (skill §1 regel 11).
6. **Test-harnas per module.** Bouw kleine losse `.prg`-testjes (`BasicUpstart2`)
   die één routine aanroepen en het resultaat op het scherm zetten, zodat je een
   module test zonder de hele cartridge te herbouwen.

**Prompt-sjabloon:**

> "Implementeer `<routine>` voor Commodore Desk 64 in Kick Assembler.
> Koptekst: `<In/Uit/Klobbert/Carry>`. Gebruik de constanten uit `palette.inc`
> en `abi.inc` (bijgevoegd). Vrije zeropage: `tmp0–tmp15`. De code draait
> resident in RAM (`$0800`-gebied). Houd je aan `C64_KICKASS_SKILL.md` §1.
> Lever een los `BasicUpstart2`-testprogramma mee dat de routine demonstreert.
> Draai de syntax-checker (0 errors verplicht)."

---

## 14. Teststrategie

| Niveau | Wat | Hoe |
|---|---|---|
| Statisch | syntaxfouten, verzonnen opcodes | `c64_ka_syntax_checker.py` (0 errors) |
| Unit | één routine | los `.prg`-testje in x64sc, visueel + monitor |
| Integratie | subsysteem (bv. shell) | eigen testbank in de cartridge |
| Systeem | volledige `.CRT` | `x64sc -cartcrt`, muis+joystick gekoppeld |
| Regressie | screenshots | `capture_vice.ps1` per bouw, vergelijk beeld |
| Hardware | echte C64 | EasyProg-flash, testen op fysieke machine |
| Geheugen | overlap/grenzen | `-showmem` + segment `min/max/fill` (skill §9.5) |

Test invoer altijd met **alle drie** de bronnen (muis, joystick, toets), want dat
is de meest hardware-afhankelijke laag.

---

## 15. Risico's & valkuilen

| Risico | Impact | Mitigatie |
|---|---|---|
| **1351-muis via POT-lijnen** is traag/ruizig en lastig goed te krijgen | Cursor schokt | Delta met wrap-correctie, filteren, één as per frame; test vroeg (fase 3) |
| **Bank-switch onder je voeten** (`$DE00` wijzigen vanuit code die zelf wegvalt) | Crash | `farcall`/`switch_bank` uitsluitend in RAM/`$DF00` |
| **Charset vs. bitmap botsen** in de VIC-bank | Corrupt beeld | Vaste VIC-bank-plan in `memmap.inc`; charset verhuizen bij bitmap-mode |
| **Kleuren-RAM vergeten** (alleen scherm-RAM zetten) | Onzichtbare/foute tekst | Elke teken-routine zet ook `$D800+`; test met `gfx_Cls` |
| **Screencode vs. PETSCII** verwarring | Verkeerde tekens | Direct in scherm-RAM = `screencode_*` encoding (skill §4.3) |
| **KERNAL uitgebankt tijdens disk-I/O** | Load/save faalt | KERNAL tijdelijk inbanken rond IEC-calls, of eigen IEC-routines |
| **512 KB / 32 banken vol** | Apps passen niet | Resources delen; apps die zelden samen draaien in dezelfde banken |
| **Sprite-multiplex** (max 8, 1 voor cursor) | Te weinig sprites | Iconen als chars i.p.v. sprites; sprites spaarzaam |
| **cartconv verkeerde banklengte** | .CRT werkt niet | Segment `min/max/fill` exact 16 KB; `cartconv` output controleren |

---

## 16. Commodore 128-toekomst

De naam "Desk **64**" houdt ruimte voor een C128-variant. Houd nu al rekening met:

- **Alles hardware-specifieks in de HAL.** De C128-port vervangt idealiter alleen
  `hal/*` en een deel van `kernel/banking.asm`.
- **C128-voordelen om later te benutten:** extra RAM-banken (128 KB via MMU),
  2 MHz-modus (VIC uit tijdens rekenwerk), en optioneel 80-koloms VDC-tekst
  (`$D600`) voor een tweede, scherpere desktopmodus.
- **Geen aannames over `$0001`/geheugenlayout** buiten `memmap.inc` en de HAL.

Zolang apps alleen tegen de API (§9) praten, draaien ze straks ongewijzigd op de
128.

---

## 17. DESIGN-BRIEF — voorbeeldschermen (kopieerbaar)

> Dit blok is bedoeld om **los te kopiëren** naar een design-/beeldtool of naar
> een ontwerper. Het legt de hardware-getrouwe beperkingen vast zodat de mockups
> 1-op-1 naar de C64 vertaald kunnen worden.

```
DESIGN-BRIEF — COMMODORE DESK 64 (voorbeeldschermen)

CANVAS
- Resolutie: exact 320 x 200 pixels (schaal voor presentatie x3 of x4 op).
- Raster: 40 kolommen x 25 rijen van 8x8-pixelcellen. Teken elk grafisch
  element uitgelijnd op dit 8x8-raster.
- Pixel-aspect: C64-pixels zijn licht rechthoekig; voor mockups mag je
  vierkante pixels aanhouden.

KLEUREN — GEBRUIK UITSLUITEND DEZE 16 (geen andere, geen tinten ertussen):
  0 Zwart #000000     8  Oranje      #DD8855
  1 Wit   #FFFFFF     9  Bruin       #664400
  2 Rood  #880000     10 Lichtrood   #FF7777
  3 Cyaan #AAFFEE     11 Donkergrijs #333333
  4 Paars #CC44CC     12 Grijs       #777777
  5 Groen #00CC55     13 Lichtgroen  #AAFF66
  6 Blauw #0000AA     14 Lichtblauw  #0088FF
  7 Geel  #EEEE77     15 Lichtgrijs  #BBBBBB

KLEURREGEL (hi-res char-mode — VERPLICHT respecteren):
- Het HELE scherm heeft EEN achtergrondkleur.
- Elke 8x8-cel mag DAARNAAST slechts EEN voorgrondkleur uit de 16 hebben.
- Dus binnen een cel zijn er maar 2 kleuren: de gedeelde achtergrond + 1
  voorgrondkleur. Iconen en tekst zijn 2-kleurig per cel.
- Wil je in een regio meer kleuren per cel (bv. kleurrijke Paint-canvas of
  fotoachtige iconen), markeer die regio als "multicolor": achtergrond + 2
  gedeelde kleuren + 1 kleur per cel, maar HALVE horizontale resolutie
  (160 x 200, dubbelbrede pixels). Meng char-mode en multicolor niet binnen
  dezelfde cel.

STANDAARD-THEMA (aanpasbaar in de app, maar gebruik dit voor de mockups):
- Bureaublad-achtergrond: Blauw (6)
- Scherm-rand (border rondom): Lichtblauw (14)
- Menubalk-achtergrond: Lichtgrijs (15), tekst Zwart (0)
- Dock-achtergrond: Donkergrijs (11)
- Paneel/venster-achtergrond: Grijs (12)
- Standaardtekst: Wit (1)
- Selectie/highlight: Cyaan (3)
- Accent/actieve knop: Geel (7)
- Waarschuwing: Lichtrood (10)

VASTE SCHERMINDELING (40x25):
- Rij 0        : contextuele MENUBALK (achtergrond lichtgrijs, tekst zwart).
- Rij 1..21    : WERKGEBIED (de actieve app).
- Rij 22       : STATUSREGEL (bv. links "READY", rechts "38K FREE").
- Rij 23..24   : DOCK met app-iconen (2x2 cellen) + labels eronder.

TYPOGRAFIE
- Eén vaste 8x8-tekenset (te herdefinieren). Ontwerp een strakke, leesbare
  set; hoofdletters + cijfers + leestekens + kaderlijnen + pijltjes.
- Kaders/panelen bouw je uit rand-tekens (hoeken, horizontale/verticale lijn).

CURSOR
- De muispijl is een los zwevend element (hardware-sprite), 24x21 px, 1 kleur
  (bv. wit met zwarte rand-truc). Teken hem in de mockups boven alles, ergens
  in het werkgebied.

TE ONTWERPEN SCHERMEN (aparte mockups, allemaal 320x200):

1. BOOT/SPLASH
   - Logo "Commodore Desk 64", versienummer, korte laadindicatie.
   - Achtergrond blauw (6) of zwart (0); logo in wit/cyaan/geel.

2. DESKTOP (leeg bureaublad)
   - Menubalk rij 0 met alleen een "systeem"-menu (bv. appelicoon/logo +
     "CD64" en klok rechts).
   - Leeg blauw werkgebied, evt. subtiel patroon of centraal logo.
   - Statusregel rij 22. Dock rij 23-24 met 5 iconen:
     Files, Editor, Paint, Calc, Settings (elk met label).

3. FILE MANAGER
   - Menubalk: File / Edit / Disk / View.
   - Werkgebied: scrollbare LIJST met disk-directory (bestandsnaam links,
     type/grootte rechts), 1 regel geselecteerd (cyaan highlight).
   - Rechts of onder: knoppen Open / Delete / Rename.
   - Scrollbalk aan de rechterkant van de lijst.

4. TEXT EDITOR
   - Menubalk: File / Edit / Search.
   - Werkgebied: tekstvlak met een paar regels voorbeeldtekst en een
     knipperende tekstcursor; onderin regel/kolom-indicator in de statusregel.

5. PAINT
   - Menubalk: File / Edit / Tools / Colors.
   - Werkgebied: teken-canvas (mag multicolor zijn -> meer kleuren, halve
     h-resolutie) met links een smal gereedschapspalet (potlood, lijn,
     rechthoek, vullen, gum) en onderin een kleurenkiezer met de 16 kleuren.

6. CALCULATOR
   - Menubalk: minimaal (bv. alleen systeem-menu).
   - Werkgebied: display bovenaan + knoppengrid (0-9, + - x /, =, C),
     knoppen met hover/ingedrukt-staat.

7. SETTINGS / COLORS
   - Menubalk: systeem-menu.
   - Werkgebied: lijst met thema-rollen (Bureaublad, Menubalk, Dock, Tekst,
     Selectie, Accent...) elk met een 16-kleuren-swatchrij ernaast en de
     huidige keuze gemarkeerd. Knoppen: Apply / Save / Reset.

8. DIALOOG (modaal) — als overlay bovenop de desktop
   - Gecentreerd paneel (grijs) met titel, een vraag ("Save changes?"),
     en knoppen: OK / Cancel (of Save / Don't Save / Cancel).
   - Rest van het scherm licht gedimd/onveranderd eronder.

9. DROPDOWN-MENU (open)
   - Toon de desktop met één menu (bv. "File") uitgeklapt: een lijstje items
     (New, Open, Save, ---, Quit), het item onder de cursor gehighlight (cyaan),
     scheidingslijn tussen groepen.

LEVER PER SCHERM
- Een 320x200 mockup (opgeschaald), strikt binnen de 16 kleuren en de
  cel-kleurregel.
- Vermeld bij twijfelgevallen welke regio's multicolor zijn.
- Houd alle UI op het 8x8-raster.
```

---

## 18. Woordenlijst

| Term | Betekenis |
|---|---|
| **Char-mode** | Tekstmodus: scherm is 40×25 cellen die naar een tekenset verwijzen; VIC-II tekent het in hardware. |
| **Hi-res / bitmap** | 320×200 pixels direct adresseerbaar; 2 kleuren per 8×8-cel. |
| **Multicolor** | 160×200 (dubbelbrede pixels); meer kleuren per cel. |
| **Scherm-RAM** | 1000 bytes (`$0400`) die per cel een tekencode bevatten. |
| **Kleuren-RAM** | 1000 nibbles (`$D800`) die per cel de voorgrondkleur bevatten. |
| **Screencode** | Interne tekencode voor scherm-RAM (≠ PETSCII). |
| **Sprite** | Hardware-object dat over het beeld zweeft; wij: cursor = sprite 0. |
| **HAL** | Hardware Abstraction Layer: drivers die de hardware afschermen. |
| **EasyFlash** | Herprogrammeerbare cartridge met bank-geschakelde flash + 256 B RAM. |
| **.CRT** | VICE/emulator-cartridgebestand; EasyFlash = type 32. |
| **cartconv** | VICE-tool die binaries naar `.CRT` omzet. |
| **CBM80** | Signatuur op `$8000` waarmee een cartridge autostart bij reset. |
| **farcall** | Onze routine om code in een andere bank aan te roepen. |
| **1351** | Commodore's proportionele muis (via POT-lijnen). |

---

*Bijbehorende documenten: `C64_KICKASS_SKILL.md` (asm-regels & recepten),
`c64_ka_syntax_checker.py` (statische check), `build.bat` / `capture_vice.ps1`
(build & screenshots).*
