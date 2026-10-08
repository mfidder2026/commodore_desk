# CALENDAR — plan voor een kalender met agenda in CD64

Een nieuwe app in het framework, net als WEATHER en WEB: een eigen PRG
(`CALENDAR`) met de sprongtabel op `$8000`, een icoon op het bureaublad,
F1-help, en de afspraken in een bestand op de disk. Een lokale agenda:
geen netwerk nodig. Met Nederlandse feestdagen, printen, en een herinnering
bij het opstarten.

---

## 1. Wat de gebruiker ziet

Eén venster: bovenaan de maand, onderaan de afspraken van de gekozen dag.

```
 CD64 | DESKTOP | FILES | SYSTEM
+-CALENDAR-------------------------------x+
|  <   OCTOBER 2026   >          TODAY    |  rij 3: maand kiezen
|                                         |
|  WK  MO  TU  WE  TH  FR  SA  SU         |  rij 5: dagen
|  40               1   2   3   4         |  rij 6-11: de maand
|  41   5   6   7  [8]  9  10  11         |  [8] = vandaag (accentkleur)
|  42  12  13 *14  15  16  17  18         |  * = dag met afspraken
|  43  19  20  21  22  23 *24  25         |  (gekozen dag: selectiekleur)
|  44  26  27  28  29  30  31             |
|                                         |
|  THURSDAY 8 OCTOBER 2026                |  rij 13: de gekozen dag
|  09:30  DENTIST                         |  rij 14-19: afspraken
|  14:00  CALL MARK ABOUT THE C64         |  (meer dan 6: scrollen)
|         ALL DAY: BIRTHDAY ANNA          |
|                                         |
|  ADD    EDIT    DELETE    PRINT         |  rij 21: knoppen
|                                         |  rij 22: meldingen
+-----------------------------------------+
 F1=HELP                 08-10-2026 10:15
```

- **De maand**: `<` en `>` (of de toetsen `-` en `+`) naar de vorige/volgende
  maand, **TODAY** (T) terug naar vandaag. Vandaag staat in de accentkleur,
  de gekozen dag in de selectiekleur, een dag met afspraken heeft een `*`.
  Links het weeknummer (ISO, zoals in Nederland gebruikelijk).
- **Klik op een dag**: de afspraken van die dag verschijnen eronder.
- **ADD** (A): een afspraak op de gekozen dag: tijd (`HH:MM`, of leeg = de
  hele dag), tekst (max. 30 tekens) en herhalen (geen / elke week / elke
  maand / elk jaar). **EDIT** en **DELETE**: eerst een afspraak in de lijst
  aanklikken. DELETE vraagt `Y` om te bevestigen.
- **Feestdagen** (Nederland) staan in een eigen kleur in het raster en
  bovenaan de lijst van de dag (`KONINGSDAG`); zie §3.5.
- **PRINT** (P): de afspraken van de gekozen **dag**, of de hele **maand**
  (het raster + alle afspraken van die maand) — PRINT vraagt `D` of `M`.
  Via de printer die bij PRINT op het bureaublad gekozen is.
- **Bewaren**: na elke wijziging wordt `AGENDA` op de disk geschreven
  (met de bekende melding, zoals bij SETTINGS).
- **Geen datum gezet?** (koude start: 01-01-2026) De status zegt
  `SET THE DATE: SYSTEM - TIME`.
- **F1**: hulp, zoals overal.

## 2. De afspraken op disk

`AGENDA` (SEQ), één afspraak per regel, gewone tekst — dus ook met de
TEXT EDITOR te lezen en te wijzigen (zoals `RADIO.LST` en `BOOKMARKS`):

```
20261008 0930 - DENTIST
20261008 1400 - CALL MARK ABOUT THE C64
19900312 ---- Y BIRTHDAY ANNA
20261005 0800 W GYM
```

| Veld | Betekenis |
|---|---|
| `JJJJMMDD` | de datum (bij herhalen: de eerste keer) |
| `HHMM` / `----` | het tijdstip, of de hele dag |
| `-` `W` `M` `Y` | niet herhalen, elke week, elke maand, elk jaar |
| tekst | max. 30 tekens |

- Het bestand wordt bij het openen helemaal gelezen en gesorteerd op datum
  en tijd; bij elke wijziging opnieuw geschreven (`@0:AGENDA`).
- Het is **jouw bestand**: `build_disk.bat` bewaart het (zoals `MAIL.CFG`
  en `BOOKMARKS`) in `userfiles\` en zet het terug; het komt nooit in git.
- Een regel die niet klopt, wordt overgeslagen (en blijft bij het
  opslaan staan, zodat er niets verloren gaat).

## 3. Techniek en geheugen

### 3.1 De app

- PRG `CALENDAR` op `$8000-$BFFF`, app-id **16**, help-context **21**,
  bureaublad-item **#11**. Geen netwerkstack: de code is klein (schatting
  4-5 KB).
- De afspraken in het werkgeheugen van de app, `$4000-$6FFF` (12 KB):
  per afspraak ~40 bytes, dus **ruim 250 afspraken**. Meer: melding
  `AGENDA IS FULL`.
- Per maand een tabel van 31 bits "heeft afspraken" (voor de `*`), opnieuw
  berekend bij het wisselen van maand (ook de herhalingen).

### 3.2 Datumrekenen (6502, alles in de app)

- **Weekdag**: dezelfde formule als de 3-dagenverwachting van WEATHER
  (jaar + jaar/4 + maandtabel + dag, mod 7), geldig 2000-2099; voor
  geboortedagen telt alleen maand/dag (herhalen) mee.
- **Dagen per maand**: `clk_DaysInMonth` uit de Core (schrikkeljaar).
- **Weeknummer (ISO 8601)**: week 1 = de week met de eerste donderdag;
  uitgerekend uit de dag van het jaar en de weekdag.
- **Vandaag**: `clkDay`/`clkMon`/`clkYear*` uit de Core (BCD).
- **Herhalen**: W = zelfde weekdag vanaf de startdatum; M = zelfde
  dagnummer (bestaat de dag niet, zoals 31-02: overslaan); Y = zelfde dag
  en maand (29-02 alleen in schrikkeljaren).

### 3.3 Invoer

- Tijd en tekst typen met `li_Edit` (zoals in WEATHER en WEB).
- Herhalen: klik om te wisselen (`NONE` → `WEEKLY` → `MONTHLY` → `YEARLY`),
  zoals de waarden in SETTINGS.

### 3.4 De Core: ruimte en het icoon (het lastigste punt)

- **Core**: een nieuwe app kost ~45 bytes (tabellen, naam, bestandsnaam,
  icoon), de herinnering bij het opstarten (§3.6) ~30. Er is **77 bytes**
  vrij: dat is te krap, dus stap 1 maakt eerst ruimte (zoals bij WEB:
  werkbuffers of tabellen van de Core naar vrij RAM).
- **Icoon**: het glyphgebied (`$DC00-$DFFF`) is na WEB precies vol, en de
  Win95-stijl heeft geen vrije tekencodes meer. **Stap 1** maakt hier eerst
  ruimte, met deze opties (meten welke het best past):
  - Win95-stijl: weer 6 omgekeerde tekens die nooit omgekeerd te zien zijn,
    zoals bij WEB. Veilig zijn `,` `*` `?` (die mogen niet in een
    C64-bestandsnaam), de andere drie te controleren tegen alle
    omgekeerde teksten (knoppen, de klok in de statusbalk, FILES);
  - STONE-stijl (3x3): de tekeningen van de app-iconen van WEATHER en WEB
    uit het glyphgebied naar `STONEICON` verhuizen (dat bestand wordt
    toch al geladen), zodat er ruimte vrijkomt;
  - of de helpteksten iets korter maken (die delen het gebied).
- **Help**: het helpgebied is vol; de tekst van CALENDAR (~8 regels) kost
  weer ~150 bytes inkorten elders.

### 3.5 Feestdagen (Nederland)

Uitgerekend in de app, voor elk jaar 2000-2099:

| Feestdag | Datum |
|---|---|
| NIEUWJAARSDAG | 1 januari |
| GOEDE VRIJDAG | Pasen - 2 |
| PASEN (1e en 2e) | Pasen, Pasen + 1 |
| KONINGSDAG | 27 april (26 april als de 27e een zondag is) |
| BEVRIJDINGSDAG | 5 mei |
| HEMELVAART | Pasen + 39 |
| PINKSTEREN (1e en 2e) | Pasen + 49, + 50 |
| KERSTMIS (1e en 2e) | 25 en 26 december |

- **Pasen** met de bekende rekenregel (Meeus/Jones/Butcher: delen door
  19, 100, 4, 25, 3, 30, 7, 451) — op de 6502 met een kleine deelroutine.
- De namen in het Nederlands (het zijn Nederlandse dagen); in het raster
  een eigen kleur, in de lijst bovenaan.

### 3.6 Herinnering bij het opstarten

- Na het opstarten (en na het ophalen van de tijd: `time_Boot`) laadt de
  Core de app CALENDAR en roept een extra ingang aan (`$800C`, zoals
  `TIME_AUTO` bij TIME). Die leest `AGENDA`, telt de afspraken van vandaag
  (ook herhalingen en feestdagen) en toont een melding:
  `TODAY: 2 APPOINTMENTS` (met de eerste erbij). Niets vandaag: geen
  melding.
- Alleen bij een **koude start** (niet na een spel, als CD64 opnieuw laadt)
  en alleen als de **datum gezet** is (door TIME of eerder); anders zou hij
  over 01-01-2026 gaan.
- **Aan/uit** in SETTINGS (`REMIND`), standaard aan; bewaard in `CD64.CFG`.
- Het kost elke start even laden (CALENDAR + `AGENDA`); met de D64 alleen
  als CALENDAR op de disk in de drive staat (kant B: dan niets).

### 3.7 Printen

- De printerdriver van EDITOR en PAINT (`PrinterDriver()`-macro: Epson,
  Star, HP LaserJet; device 4 of userport) komt ook in CALENDAR.
- **Dag**: kop (`THURSDAY 8 OCTOBER 2026`), dan de afspraken (tijd +
  tekst), feestdag erboven.
- **Maand**: kop, het raster als tekst (7 kolommen, weeknummers), dan per
  dag met afspraken de lijst.
- RUN/STOP stopt; geen printer: de melding van de driver.

### 3.8 Disks

- D81, D71 en `release/CD64.d81`: altijd.
- D64: kant A is vol → `CALENDAR` gaat vanzelf naar kant B
  (`disk_add.py --spill`); `AGENDA` staat op beide kanten.
- `release/CD64.d81` krijgt een voorbeeld-`AGENDA` met een paar
  afspraken? (zie de vragen)

## 4. Randgevallen

| Geval | Gedrag |
|---|---|
| geen `AGENDA` op de disk | lege agenda; het bestand komt er bij de eerste ADD |
| disk vol / schrijfbeveiligd | melding met de foutcode van de drive (`72, DISK FULL`) |
| datum nooit gezet | de kalender werkt, met `SET THE DATE: SYSTEM - TIME` |
| een dag met meer dan 6 afspraken | de lijst scrollt (SPATIE / `-`) |
| 31-02 maandelijks, 29-02 jaarlijks | zie §3.2 |
| jaargrens (december → januari) | gewoon door; jaren 2000-2099 |
| `AGENDA` met een fout in een regel | die regel overslaan, maar bewaren |
| F1 / menu tijdens het typen | scherm terug zoals het was |

## 5. Het icoon

Een **kalenderblaadje** (twee ringen bovenaan, een rode kopbalk, een raster
eronder), in alle thema's: Win95-stijl 2x2 (16x16) en STONE-stijl 3x3
(24x24). Eerst een voorbeeld ter goedkeuring.

## 6. Testen

- **Datumrekenen in Python nagerekend**: weekdag, weeknummer en de
  herhalingen voor elke dag van 2000-2099 vergeleken met Python's
  `datetime` (via een kleine testtabel die de app in VICE uitrekent en
  het testscript uitleest).
- **VICE**: maanden bladeren (ook december/januari, februari in een
  schrikkeljaar), ADD/EDIT/DELETE, opnieuw starten en alles staat er nog,
  `AGENDA` bewerkt in de TEXT EDITOR, alle thema's en fonts, de D64 kant B.

## 7. Stappenplan

| # | Stap | Klaar als |
|---|---|---|
| 1 | **Ruimte + icoon + skelet**: plek voor het icoon (§3.4), `calendar_main.asm`, app-id 16 | icoon in alle thema's; CALENDAR opent en sluit; alle andere apps en thema's ongewijzigd |
| 2 | **De maand**: raster, weekdagen, weeknummers, vandaag, bladeren, TODAY | elke maand van 2026-2027 klopt met een gewone kalender |
| 3 | **Afspraken lezen en tonen**: `AGENDA` laden, sorteren, `*` in het raster, lijst van de dag | een met de hand gemaakte `AGENDA` staat goed op het scherm |
| 4 | **ADD / EDIT / DELETE + opslaan** | wijzigen, VICE herstarten, alles staat er nog |
| 5 | **Herhalen** (W/M/Y) | verjaardagen, wekelijkse afspraken, 31-02 en 29-02 kloppen |
| 6 | **Feestdagen** (§3.5) | Pasen en alle feestdagen 2000-2099 kloppen, nagerekend met Python |
| 7 | **Printen**: dag en maand (§3.7) | uitvoer in VICE (`-pr4drv raw`) klopt, voor Epson en HP |
| 8 | **Herinnering bij het opstarten** + `REMIND` in SETTINGS (§3.6) | melding bij een koude start met afspraken vandaag; niet na een spel, niet zonder datum, niet als hij uit staat |
| 9 | **Testen**: datumrekenen tegen Python voor 2000-2099, randgevallen §4 | alles gecontroleerd met schermafdrukken |
| 10 | **Afwerken**: F1-help, README, schermafdrukken, disks (D81, D71, D64 kant B), `AGENDA` bij de gebruikersbestanden | alles gecommit, D81 gebouwd |

## 8. Open vragen (beantwoord)

1. **Naam**: `CALENDAR`.
2. **Week**: begint op maandag, met weeknummers.
3. **Herhalen**: alle vier (geen / week / maand / jaar).
4. **Herinnering bij het opstarten**: ja (§3.6), aan/uit in SETTINGS.
5. **Feestdagen**: ja, de Nederlandse (§3.5).
6. **Printen**: zowel een dag als een maand (§3.7).
7. **Internet**: nee, een lokale agenda.

## 9. Resultaat (8 oktober 2026)

Alle stappen gedaan. Wat anders liep dan gepland:

- **Core**: ruimte gemaakt door de event-queue, `ghC`/`daLbl` en de
  WiC64-buffers naar het vrije RAM op `$C0B4-$C0EF` te verhuizen,
  `osvars_Init` met een tabel te doen en de `userIconGlyphs`-tabel uit te
  rekenen. Daarna (met de herinnering `cal_Boot`) nog 20 bytes vrij.
- **Icoon**: STONE 3x3 komt nu voor WEATHER, WEB en CALENDAR uit
  `STONEICON` (laadt op `$3B30`, codes 102-127 + 254); Win95 2x3 op 126 en
  de omgekeerde `% * , ; ?` (165, 170, 172, 187, 191). Eerst stond er een
  cel op 127, maar dat is `GL_SOLID` (cursor en kleurvlakken): verplaatst.
- **Help**: andere teksten iets korter (o.a. de regels "ESC CLOSES ..."
  die al in de bureaubladhulp staan); 3006 van de 3072 bytes.
- **Datumrekenen**: met een kleine 6502-emulator in Python elke dag van
  1900 tot en met 2099 nagerekend (weekdag, ISO-week, dag van het jaar en
  terug, Pasen, alle feestdagen): 0 fouten. Januari/februari 1900 gaf
  eerst de verkeerde weekdag (de 28-jaartruc); opgelost.
- **Getest in VICE** (D81-kopie met een test-`AGENDA`): maand en
  weeknummers (ook week 53 van 2026), daglijst, ADD/EDIT/DELETE met
  opslaan en opnieuw lezen, herhalingen, foute regels, feestdagen,
  printen van een dag en een maand (Epson, `-pr4drv raw`; HP niet apart
  getest, dezelfde tekstregels), de herinnering bij het opstarten in de
  C64- en DESK64-stijl, REMIND in SETTINGS.
- **Gevonden fouten**: lokale labels `a1:`/`a2:` die de zeropage-registers
  van de ABI overschaduwden (`sta a1` schreef in de code); `o_Chr`
  overschreef X; na een mislukte `pr_Open` werd `pr_Close` nog aangeroepen
  (met de KERNAL al weggeschakeld: vastlopen); het tijdveld liet "AY" van
  "ALL DAY" staan.
- **D64**: CALENDAR (29 blokken) staat op kant B; op kant A slaat de
  herinnering zich stil over.
- Een regel van `AGENDA` die niet te lezen is, wordt overgeslagen en bij
  het volgende opslaan niet meer weggeschreven.
- De namen van de feestdagen zijn Engels (KING'S DAY, BOXING DAY ...),
  net als de rest van het bureaublad.
