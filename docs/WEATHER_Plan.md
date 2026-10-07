# WEERBERICHT — plan voor een nieuwe CD64-applicatie

> Status: **plan** (nog niets gebouwd). Datum: 2026-10-07.
> Doel: een nieuwe app **WEATHER** op het bureaublad. De gebruiker kiest een
> locatie (wordt bewaard), de app haalt het actuele weer op via internet en
> toont het met grote, kleurige, geanimeerde **weersprites**.

---

## 1. Wat de gebruiker ziet

```
 CD64 | DESKTOP | FILES | SYSTEM
 ≡ WEATHER ≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡≡ ×
   LOCATION  UTRECHT, NL                [CHANGE]
  ┌──────────────┐
  │   (sprites)  │   +19 C      FEELS LIKE +18 C
  │   ☀  ☁☁      │   PARTLY CLOUDY
  │  zon + wolk  │   WIND      NE 6 KM/H
  │  96 x 84 px  │   HUMIDITY  63 %
  └──────────────┘   RAIN      0.0 MM
                     PRESSURE  1016 HPA
   SUNRISE 07:58   SUNSET 19:02   LOCAL 13:45
   UPDATED 13:45                 [REFRESH]
 F1=HELP                         07-10-2026 13:45
```

- **Nieuw icoon** op het bureaublad: WEATHER (in alle thema's: 2x3 in de
  Win95-stijl, 3x3 in STONE/DESK64).
- **Locatie kiezen**: CHANGE → invoerveld (zoals de naam bij EDITOR). Leeg
  laten = **AUTO**: de weerdienst kiest dan de plaats bij het IP-adres van
  de internetaansluiting. De keuze wordt bewaard in `WEATHER.CFG`.
- **Ophalen**: bij het openen, met REFRESH (of F5), en vanzelf elke 15
  minuten zolang de app open is.
- **Weerbeeld**: een groot plaatje van hardware-sprites (zon, maan, wolken,
  regen, sneeuw, mist, onweer…), geanimeerd: regen valt, sneeuw dwarrelt,
  de zon straalt, bliksem flitst.
- **Meldingen** bij problemen: `NO NETWORK`, `PLACE NOT FOUND`,
  `WEATHER SERVICE NOT REACHABLE` (zoals de andere netwerk-apps).

---

## 2. Gegevensbron

Getest op 2026-10-07 (gewone HTTP, geen HTTPS nodig, geen API-sleutel):

| Dienst | Verzoek | Antwoord | Oordeel |
|---|---|---|---|
| **wttr.in** | `GET /Utrecht?format=...&m&lang=en` | één regel tekst, ~60 bytes, `Content-Length` | **Eerste keus**: klein, plaatsnaam direct, geen JSON |
| Open-Meteo | `GET /v1/forecast?latitude=..&longitude=..&current=...` | JSON ~500 bytes, *chunked* | Reserve: betrouwbaar, maar 2 verzoeken (geocoding + weer) en JSON/chunked parsen |

**Verzoek (wttr.in, één regel met `|` als scheiding):**

```
GET /<plaats>?format=%l|%x|%t|%f|%C|%w|%h|%p|%P|%S|%s|%T&m&lang=en HTTP/1.0
Host: wttr.in
```

Voorbeeldantwoord: `Utrecht|m|+19°C|+18°C|Partly cloudy|↗6km/h|63%|0.0mm|1016hPa|07:58:12|19:02:40|13:45:10+0200`

| Veld | Betekenis | Opmerking |
|---|---|---|
| `%l` | locatie zoals de dienst hem kent | tonen als bevestiging |
| `%x` | **weersymbool** (platte tekst) | basis voor het plaatje, zie §4 |
| `%t` / `%f` | temperatuur / gevoelstemperatuur | UTF-8 `°` overslaan |
| `%C` | omschrijving (Engels) | max. 1 regel, afkappen |
| `%w` | windrichting (UTF-8-pijl) + snelheid | pijl → N/NE/E/…, zie §6 |
| `%h %p %P` | vochtigheid, neerslag, luchtdruk | |
| `%S %s %T` | zonsopkomst, -ondergang, lokale tijd | **dag/nacht** = `%T` tussen `%S` en `%s` |

- Spaties in de plaatsnaam → `+`; alleen A-Z, 0-9, spatie, `-` en `,` toegestaan.
- Lege plaats → `GET /?format=...` (wttr.in kiest de plaats bij het IP-adres).
- Bijzondere tekens (UTF-8, bytes ≥ `$80`) worden overgeslagen, behalve de
  windpijlen.
- Het verzoek vraagt om `HTTP/1.0`, dan sluit de server na het antwoord en
  is er geen *chunked*-codering.

---

## 3. Techniek en geheugen

### 3.1 De app

Een **eigen PRG binnen het framework, net als BBS** (`bbs_main.asm`) en
RADIO (`radio_main.asm`): apart geassembleerd, met de Core-adressen uit
`build/core_syms.inc`.

- `weather_main.asm` → `build/weather.prg` (op disk: `WEATHER`), geladen op
  `$8000`, app-id **14**, sprongtabel `INIT/DRAW/CLICK/KEY` op `$8000-$800B`.
- De Core kiest zulke PRG's sinds stap 1 met één test (`ovJT`): een nieuwe
  app-PRG kost daar alleen nog de tabelregels.
- Netwerklaag: dezelfde bronnen als RADIO (`net/*`, DNS, TCP,
  `net/ultimate.asm`, `net/wic64net.asm`) plus de TCP-hulp van EMAIL
  (`mail_net.asm`). Werkt dus op **RR-Net, Ultimate en WiC64**.
- App-code in `apps/weather/`: `weather.asm` (scherm, knoppen),
  `weather_net.asm` (ophalen + ontleden), `weather_spr.asm` (sprites,
  animatie), `weather.inc` (adressen).

### 3.2 Waar de sprites staan (het lastigste punt)

De VIC ziet alleen bank 0 (`$0000-$3FFF`), en die is vol: Core
`$0801-$37FF`, tekenset `$3800-$3FFF`, `$1000-$1FFF` is voor de VIC de
karakter-ROM. Vrij zijn alleen blok 14/15 (`$0380`, `$03C0`).

**Oplossing:** zolang WEATHER open is, zijn de **bureaublad-iconen niet
nodig**. Hun tekens staan op codes 192-255 = `$3E00-$3FFF` = **8
sprite-blokken** (blok 248-255).

1. Bij het openen: `$3E00-$3FFF` (512 bytes) bewaren in de app-buffer
   (`$C500-`), de sprites erin zetten.
2. Bij het sluiten: sprites 1-7 uit (`$D015`), de 512 bytes terugzetten.
   Daarna tekent het bureaublad zijn iconen weer gewoon.
3. De omgekeerde letters (codes 128-191, Win95-balken en -titels) blijven
   ongemoeid. Sprite 0 (muispijl) blijft vooraan staan.

### 3.3 Instelling bewaren

Eigen bestand **`WEATHER.CFG`** (plaatsnaam, 31 tekens). Het staat niet in
`CD64.CFG`, want daar en in de Core is geen ruimte.

`build_disk.bat` neemt het op in `USERFILES`, zodat de gebruikersinstelling
bij elke build bewaard blijft (net als `MAIL.CFG`).

### 3.4 Ruimte in de Core (nu **11 bytes** vrij)

WEATHER kost in de Core naar schatting 40-60 bytes:

| Onderdeel | Bytes |
|---|---|
| een ingebouwd icoon (`biName`, `biIcon`, `biIcoCol`, `biApp`, naam) | ~15 |
| app-id 14 in de keuzes (DRAW/CLICK/KEY) | ~15 |
| `loadApp`-tabel ("WEATHER", lengte) | ~10 |
| STONE-icoon via tabel i.p.v. `128+9*i` (zie §5) | ~10 |

Eerst ruimte maken (gedrag blijft gelijk):

1. `font_Base`: de uitgerolde 8-pagina-kopie → lus (**~28 bytes**).
2. `fo_Ov`: de uitgerolde 4-pagina-kopie → lus (**~12 bytes**).
3. De overlay-apps met sprongtabel (EMAIL 9/10, TIME 12, RADIO 13,
   WEATHER 14) met één bereik-test kiezen i.p.v. losse `cmp` per id
   (**~15 bytes**, en elke volgende app kost dan niets meer).

### 3.5 Disks

| Disk | Vrij nu | WEATHER (~45 blokken) |
|---|---|---|
| D81 | 2283 | past |
| D71 | 689 | past |
| D64 | 25 | **past niet**: op de D64 geen WEATHER (icoon geeft dan `CANNOT LOAD`), of een extra weglaten |

---

## 4. De weersprites

### 4.1 Opbouw: lagen in plaats van losse plaatjes

Het plaatje bestaat uit **lagen** van multicolor-sprites. Elke laag is 2
sprites breed (48 × 21 pixels, X/Y vergroot → 96 × 42 op het scherm):

| Laag | Sprites | Blokken | Inhoud |
|---|---|---|---|
| **HEMEL** (achter) | 5-6 | 2 | zon *of* maan |
| **WOLK** (midden) | 3-4 | 2 | wolk; kleur wisselt: wit / lichtgrijs / donkergrijs |
| **NEERSLAG** (voor) | 1-2 | 2 (= 2 animatiefases) | regen, zware regen, sneeuw, natte sneeuw, hagel |
| **EXTRA** | 7 | 2 | bliksem (knippert), mist (strepen), extra wolk |

- **Kleuren**:
  - gedeeld multicolor 1 = wit, multicolor 2 = lichtgrijs;
  - eigen kleur per sprite: geel (zon), lichtblauw (regen), wit (sneeuw),
    geel (bliksem), donkergrijs (onweerswolk).
- **Prioriteit**: lagere sprite = vooraan, dus neerslag vóór de wolk en de
  wolk vóór de zon.
- **Achtergrond**: de sprites staan voor de tekst (`$D01B` = 0); het
  sprite-vak heeft geen tekst.
- Zo zijn er maar **8 blokken tegelijk** nodig (precies wat vrij is, §3.2).
  De app houdt alle vormen in zijn eigen geheugen en kopieert per weertype
  de juiste 8 blokken naar `$3E00`.

### 4.2 Alle weertypes

| wttr `%x` | Weertype | HEMEL | WOLK | NEERSLAG / EXTRA | Animatie |
|---|---|---|---|---|---|
| `o` | Zonnig / helder | zon (dag) / maan (nacht) | — | — | stralen wisselen |
| `m` | Half bewolkt | zon / maan | witte wolk (klein, rechts) | — | wolk schuift 1-2 px heen en weer |
| `mm` | Bewolkt | — | lichtgrijze wolk | extra witte wolk | langzaam schuiven |
| `mmm` | Zwaar bewolkt | — | donkergrijze wolk | extra lichtgrijze wolk | — |
| `=` | Mist | — | — | 3 grijze mistbanden | banden schuiven |
| `.` `/` | Lichte regen / buien | zon (alleen bij buien, dag) | lichtgrijze wolk | dunne regenstrepen | regen valt (2 fases) |
| `//` `///` | Regen / zware regen | — | donkergrijze wolk | dichte regen | regen valt snel |
| `*` `*/` | Lichte sneeuw / buien | zon (alleen bij buien, dag) | lichtgrijze wolk | sneeuwvlokken | vlokken dwarrelen |
| `**` `*/*` | Zware sneeuw | — | donkergrijze wolk | veel vlokken | dwarrelen |
| `x` `x/` | Natte sneeuw / hagel | — | lichtgrijze wolk | regen + vlokken om en om | wisselen |
| `!/` `/!/` | Onweer (met regen) | — | donkergrijze wolk | regen + **bliksem** | bliksem flitst om de ~3 s |
| `*!*` | Onweer met sneeuw | — | donkergrijze wolk | vlokken + bliksem | flitsen + dwarrelen |
| `?` | Onbekend | — | lichtgrijze wolk | vraagteken | — |

Dag of nacht volgt uit `%T` tussen `%S` en `%s`: 's nachts maan i.p.v.
zon, en een donkerdere wolkkleur.

### 4.3 Maken en controleren

- **`tools/make_weather_sprites.py`**: alle vormen als ASCII-tekening
  (24 × 21, multicolor `.`/`1`/`2`/`3`), net als `make_stoneicons.py`.
  Uitvoer `build/weather_spr.bin` (bij de build gemaakt, dus niet in git).
- Hetzelfde script maakt **`build/weather_preview.png`**: alle weertypes
  naast elkaar in C64-kleuren. Die laat ik eerst zien, voordat het in de
  app gaat.
- Geheugen: ± 14 vormen × 64 bytes ≈ 1 KB; alles staat in de overlay.

---

## 5. Het icoon op het bureaublad

Een zonnetje half achter een wolkje, in alle thema's:

- **STONE / DESK64 (3×3, 24×24)**:
  - De 14 bestaande grote iconen vullen codes 128-253 volledig.
  - Het weericoon gaat op codes **102-110**: die zijn in de STONE-stijl
    vrij (daar staan anders de kleine Win95-strookiconen).
  - `da_giCode` gebruikt daarvoor een kleine tabel i.p.v. `128 + 9*i`.
- **Win95-stijl (2×3, 16×16)**:
  - Codes 192-251 en de RADIO-codes zijn bezet.
  - Vrij te maken: `82`, `83` en `126`. Daarnaast deelt "volle prullenbak"
    4 van zijn 6 tekens met "lege prullenbak"; alleen de bovenste 2
    verschillen. Dat geeft samen 7 codes, er zijn er 6 nodig.
- Kleur: geel (zon) op het thema; `da_icoCol` maakt hem leesbaar op lichte
  achtergronden.
- Volgorde op het bureaublad: na RADIO. Met 10 ingebouwde programma's plus
  de eigen programma's scrolt STONE (12 zichtbaar) eerder; dat werkt al.

---

## 6. Ontleden van het antwoord

- HTTP-statusregel: `200` → verder. `404`/`400` of het antwoord begint met
  `Unknown location` → `PLACE NOT FOUND`. Andere → `WEATHER SERVICE NOT
  REACHABLE (code)`.
- De body splitsen op `|` in maximaal 12 velden (elk max. 32 tekens) in een
  buffer op `$C500`.
- **Wind**: de UTF-8-pijlen `↑↗→↘↓↙←↖` (`E2 86 91` … `E2 86 96`, `E2 86
  90`) worden een richting. wttr.in toont de richting *waar de wind naartoe
  waait*; we tonen de gangbare richting *waar hij vandaan komt* (pijl ↗
  wordt `SW`).
- **Weersymbool** `%x`: vergelijken met de tabel uit §4.2 (langste eerst).
- Temperatuur: `+19°C` → `+19 C` (graden-teken overslaan; de tekenset heeft
  er geen).

---

## 7. Randgevallen en "geen problemen door de code heen"

| Situatie | Aanpak |
|---|---|
| App sluiten (ESC, sluitknop, menu → andere app) | altijd via één `we_Exit`: sprites uit, `$3E00-$3FFF` terug |
| F1-hulp terwijl de sprites aan staan | de hulp tekent over het venster; sprites eerst uit, na de hulp weer aan (kleine haak in `help_Show`, of `helpOff` zolang de app open is) |
| Uitklapmenu (CD64 / SYSTEM) | menu's komen tot rij ~6; het sprite-vak staat op rij 8-18, dus geen overlap |
| Screensaver | start alleen vanaf het bureaublad, dus niet in WEATHER |
| Thema of font wisselen in SETTINGS | niet mogelijk zolang WEATHER open is (SETTINGS is een andere app) |
| Geen netwerk-hardware / geen verbinding | melding, geen sprites; CHANGE/REFRESH blijven werken |
| Trage dienst | time-out zoals RADIO (`RA_TMO`), RUN/STOP breekt af |
| Plaatsnaam met rare tekens | alleen A-Z 0-9 spatie `-` `,` in het invoerveld |
| D64 zonder `WEATHER` | `CANNOT LOAD` zoals bij elke ontbrekende overlay |

---

## 8. Stappenplan

| # | Stap | Klaar als |
|---|---|---|
| 1 | **Core-ruimte**: `font_Base`/`fo_Ov` als lus, overlay-keuze als bereik | ✅ **klaar**: Core van 11 naar **139 bytes** vrij; 6 thema's, 10 fonts en de apps pixel voor pixel gelijk aan vóór de wijziging |
| 2 | **Sprites ontwerpen**: `make_weather_sprites.py` + preview | preview van alle weertypes goedgekeurd door jou |
| 3 | **Overlay-skelet**: `weather_main.asm`, app-id 14, icoon (STONE + Win95), venster met vaste testgegevens | app opent/sluit in alle thema's, icoon klopt, bureaublad-iconen na sluiten intact |
| 4 | **Sprite-motor**: lagen, kleuren, animatie, opslaan/terugzetten `$3E00` | alle 13 weertypes met testgegevens in VICE (screenshots) |
| 5 | **Ophalen**: HTTP GET naar wttr.in, ontleden, meldingen | echte data op RR-Net (VICE) en WiC64 (VICE-emulatie) |
| 6 | **Locatie**: CHANGE, AUTO, `WEATHER.CFG`, `build_disk.bat` | plaats blijft bewaard na herstart en na een nieuwe build |
| 7 | **Testserver**: `tools/weather_test_server.py` met elk weertype + foutgevallen | alle types en fouten getest zonder internet |
| 8 | **Afwerken**: auto-refresh, help (F1), README, screenshots, D81/D71 | alles gecommit, D81 gebouwd |

---

## 9. Open vragen voor jou

1. **Eenheden**: alleen metrisch (°C, km/h), of ook een keuze °F/mph?
2. **Verwachting**: alleen het **huidige** weer (dit plan), of later ook een
   korte verwachting voor 3 dagen eronder (wttr.in kan dat ook, met kleine
   icoontjes)?
3. **Taal** van de omschrijving: Engels (zoals de rest van CD64) of
   Nederlands (`lang=nl`, maar dan komen er é/ë-tekens in die we moeten
   omzetten)?
4. **D64**: WEATHER weglaten op de D64, of daar iets anders voor wijken?
