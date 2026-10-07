# WEB — plan voor een eenvoudige webbrowser in CD64

Een tekstbrowser als nieuwe app in het framework, net als WEATHER en BBS:
een eigen PRG (`BROWSER`) met de sprongtabel op `$8000`, een icoon op het
bureaublad, F1-help en de bestaande netwerklaag (RR-Net, Ultimate, WiC64).

Denk aan **Lynx op een C64**: tekst, koppen, lijstjes en links om aan te
klikken. Geen plaatjes, geen JavaScript, geen CSS.

---

## 1. Wat de gebruiker ziet

```
 CD64 | DESKTOP | FILES | SYSTEM
+-BROWSER - 68K.NEWS: TOP STORIES -------x+
| BACK  HOME  MARKS  RELOAD               |   rij 3: knoppen
| HTTP://68K.NEWS/                        |   rij 4: adres (klik = typen)
|---------------------------------------- |
| TOP STORIES                            ^|   rij 6-21: de pagina
|                                        #|   (16 regels x 36 tekens)
| * SPACEX LAUNCHES NEW ROCKET FROM      #|   links in de accentkleur
|   TEXAS                                 |
| * DUTCH TEAM WINS ...                   |   rechts: schuifbalk
|                                         |
| SEARCH: [________________]  GO          |   formulier (stap 6)
|                                         |
|                                        v|
| 68K.NEWS  14K  LINE 1-16 OF 212         |   rij 22: status / melding
+-----------------------------------------+
 F1=HELP                 07-10-2026 18:20
```

- **Het adres** (rij 4): klik erop en typ een adres, RETURN gaat erheen.
  `http://` mag weg (`68k.news` werkt ook).
- **Links** staan in de accentkleur; **klik erop** om ze te volgen.
- **Scrollen**: de schuifbalk rechts, of **SPATIE** (volgende bladzijde) en
  **-** (vorige), zoals bij een e-mail lezen in EMAIL.
- **BACK** (of B) gaat terug naar de vorige pagina (de laatste 8),
  **HOME** (H) naar de startpagina, **MARKS** (M) toont de bladwijzers,
  **RELOAD** haalt de pagina opnieuw op. **RUN/STOP** stopt het laden.
- **Statusregel**: tijdens het laden `LOADING 68K.NEWS  12K (RUN/STOP)`,
  daarna de regels die je ziet en het totaal. Meldingen staan daar ook.
- **De titel** van de pagina (`<title>`) staat in de titelbalk van het venster.
- **F1**: hulp, zoals overal.
- Alles in hoofdletters (de tekenset van het bureaublad), net als EMAIL.

## 2. Wat wel en wat niet (eerlijk)

| | |
|---|---|
| ✅ **HTTP** (`http://`) | gewone HTTP/1.0, net als RADIO en WEATHER |
| ❌ **HTTPS** | onmogelijk op een C64 (geen TLS). Een link of doorverwijzing naar `https://` geeft `THIS SITE NEEDS HTTPS - NOT POSSIBLE ON A C64` |
| ✅ HTML → tekst | koppen, alinea's, lijsten, tabellen (eenvoudig), `<pre>`, links, `&amp;`-tekens, UTF-8/Latin-1 → letters zonder accent |
| ✅ tekstbestanden | `text/plain` gewoon als tekst (textfiles.com) |
| ✅ zoeken | formulieren met **GET** en één tekstveld (wiby.me, 68k.news) — stap 6 |
| ❌ plaatjes | `<img>` wordt `[IMAGE: alt-tekst]` |
| ❌ JavaScript, CSS, cookies, POST-formulieren | niet |
| ❌ andere bestanden | een PRG/SID/ZIP-link geeft `CANNOT SHOW <type>` (opslaan op disk: mogelijke uitbreiding, §9) |

Dat **HTTPS** niet kan, is de grote beperking: het meeste van het web is
alleen nog HTTPS. Een proxy of omweg doen we niet (eerder besloten). Er zijn
gelukkig sites die bewust HTTP aanbieden (gecontroleerd op 07-10-2026):

| Site | Wat | Grootte |
|---|---|---|
| `info.cern.ch` | de allereerste website | 0,6 KB |
| `68k.news` | nieuws (Google News) voor oude computers | ~100 KB HTML |
| `wiby.me` | zoekmachine voor eenvoudige sites (`?q=...`) | ~6 KB |
| `textfiles.com` | teksten uit de BBS-tijd | 10 KB |
| `csdb.dk` | de C64-scene-database | ~45 KB |
| `theoldnet.com` | het web van de jaren 90 | ~75 KB |
| `hvsc.brona.dk` | de SID-collectie (die RADIO ook gebruikt) | 1 KB |

Niet (meer) over HTTP: c64-wiki.com, lemon64.com, commodore.ca,
lite.cnn.com, text.npr.org. Zoekresultaten van wiby.me linken naar zowel
`http://` als `https://`; die laatste gaan niet (de browser zegt waarom).

## 3. Bladwijzers en startpagina

- `BOOKMARKS` (SEQ, op de disk, zoals `RADIO.LST`): één adres per regel,
  met een naam erachter: `68k.news 68K NEWS`. Regel 1 = **HOME**.
- **MARKS** toont de lijst als een pagina met links.
- Bewerken met de TEXT EDITOR (de File Manager opent het bestand daar),
  of later met een knop ADD in MARKS.
- De standaardlijst komt uit de tabel van §2; `build_disk.bat` zet hem op de
  disk en **bewaart je eigen versie** bij het opnieuw bouwen (zoals RADIO.LST).

## 4. Techniek en geheugen

### 4.1 De app

- PRG `WEB` op `$8000-$BFFF`, app-id **15**, help-context **20**,
  bureaublad-item **#10**, eigen icoon (een wereldbol) in alle thema's.
- Netwerk: dezelfde laag als WEATHER (`mail_net.asm`: `mn_Open`,
  `mn_Send`, `tcpRxVec`). Die neemt ~7 KB (`$8000-$9B00`); er blijft
  **~9 KB voor de browser** zelf.
- Haken `ovIdle`/`ovExit` zoals WEATHER (niets extra in de Core).

### 4.2 Geheugen: de pagina past niet in één keer

Een pagina kan 100 KB HTML zijn. Net als de verwachting in WEATHER wordt
het antwoord **tijdens het binnenkomen** omgezet naar tekstregels; de HTML
zelf wordt nergens bewaard.

| Gebied | Gebruik |
|---|---|
| `$4000-$7FFF` (16 KB) | **de pagina**: tekstregels groeien omhoog vanaf `$4000`, de adressen van de links groeien omlaag vanaf `$7FFF`. Dit is het werkgeheugen van de app die open is (ook EDITOR, FILES, de SID-player en RADIO gebruiken het zo). |
| `$C500-$CFFF` | linktabel (wijzers, max. 255 links), terug-geschiedenis (8 adressen), adresregel, formulier |
| `$E000-$F7FF` | netwerkbuffers (bestaand) |

- **Een regel**: `[lengte] tekst [lengte]` (lengte voor- en achteraan,
  zodat scrollen in beide richtingen snel is). In de tekst zijn bytes vanaf
  `$80` codes: *link n begint*, *link eindigt*, *accent aan/uit* (koppen).
- 16 KB tekst is ongeveer **500 regels = 30 schermen**. Is een pagina
  langer, dan staat er onderaan `PAGE TOO LONG - REST NOT SHOWN`.
- **Een klik op de pagina**: de regel onder de muis wordt van links gelezen
  tot de kolom van de klik; ligt die binnen een link, dan wordt die link
  gevolgd.

### 4.3 HTML → tekst (de kern, ~2-3 KB)

Een toestandsmachine die per byte werkt:

- **Tekst**: spaties en regeleinden samenvoegen tot één spatie;
  woordafbreking op 36 tekens.
- **Tags** (naam en attributen worden alleen gelezen als ze nodig zijn):
  - `p div br tr li h1-h6 hr title table blockquote dl dt dd` → nieuwe regel,
    met lege regel waar dat hoort;
  - `h1-h6`, `b`, `strong` → accentkleur; `li` → `* `; `hr` → een streep;
  - `a href` → link (adres naar de linkruimte);
  - `img alt` → `[IMAGE: alt]`;
  - `pre` → spaties en regeleinden blijven staan (ASCII-art op textfiles.com);
  - `script`, `style`, `head`, `noscript` → **inhoud overslaan**;
  - `title` → titelbalk;
  - `form`, `input`, `button` → stap 6;
  - de rest wordt genegeerd (de tekst erin blijft).
- **Tekens**: `&amp; &lt; &gt; &quot; &#39; &nbsp; &#NNN; &#xHH;` en de
  meest voorkomende namen (`&eacute;` → E, `&copy;` → (C) …).
  UTF-8 en Latin-1: letters met accent → zonder accent, `’ “ ” – —` →
  `' " " - -`, onbekend → `.`. Kleine letters → hoofdletters.

### 4.4 HTTP en adressen

- `GET <pad> HTTP/1.0` met `Host:` en `User-Agent: CD64-Browser`
  (HTTP/1.0: geen chunked; de server sluit aan het eind).
- **Doorverwijzingen** (301, 302, 303, 307, 308): `Location:` volgen,
  max. 5 keer; naar `https://` → de HTTPS-melding.
- **Foutcodes** (404, 500 …): de pagina van de server tonen als die er
  is, anders `ERROR 404`.
- **Content-Type**: `text/html` → HTML, `text/*` → platte tekst, anders
  `CANNOT SHOW <type>`.
- **Relatieve adressen** omzetten: `/pad`, `pad`, `../pad`, `//host/pad`,
  `?q=…`; `#anker` wordt weggelaten; `mailto:` en `javascript:` worden geen
  link. Poort in het adres (`host:8080`) werkt.
- Spaties en andere tekens in een zoekopdracht worden `+` / `%XX`.

### 4.5 Invoer

- Het adres typen met `li_Edit` (zoals de plaats in WEATHER). Te
  controleren: kunnen `. : / - _ ~ ? = & %` er allemaal mee? Zo niet, dan
  een kleine uitbreiding (in de app, niet in de Core).
- Cursortoetsen bewegen in CD64 de muispijl; daarom scrollen met
  SPATIE / `-` en de schuifbalk, net als EMAIL.

### 4.6 Ruimte in de Core (nu **16 bytes** vrij)

Een nieuwe app kost in de Core ~25-30 bytes (naam, icoon, kleur, app-id,
overlay, label, bestandsnaam — gemeten bij WEATHER). Dat past niet.
**Stap 1** maakt eerst ruimte, zoals stap 1 van WEATHER. Mogelijkheden
(meten welke het meest oplevert, zonder iets anders te veranderen):

- de bestandsnamen van de apps (`hal/disk.asm`, PETSCII) afleiden van de
  schermcode-namen die er al zijn (ze zijn gelijk: `WEATHER`, `RADIO` …);
- de tabellen per app (naam, icoon, kleur, overlay) samenvoegen of naar
  DESKTOOL/HELPTEXT verhuizen;
- vaste teksten van de Core naar het HELPTEXT-gebied (`$D000`).

### 4.7 Disks

- D81, D71, en `release/CD64.d81`: altijd.
- D64: kant A is vol (13 blokken vrij) → `BROWSER` en `BOOKMARKS` gaan
  vanzelf naar **kant B** (`disk_add.py --spill`). De netwerkinstellingen
  (`NET.CFG`) staan op beide kanten.

## 5. Het icoon

Een **wereldbol** (blauw met groene landen; lijnen voor lengte- en
breedtegraden), zoals de andere iconen:

- C64/MATRIX/PAPER/FREMEN: 2×2 tekens (16×16), naast RADIO/WEATHER;
- STONE/DESK64: 3×3 tekens (24×24).

Eerst een voorbeeld ter goedkeuring (zoals de weersprites).

## 6. Testen

- **`tools/browser_test_server.py`** (zoals de WEATHER-testserver), met een
  pagina per geval:
  alle tags, lange woorden, `<pre>`, tekens (`&…;`, UTF-8, Latin-1),
  geneste lijsten/tabellen, `<script>`/`<style>`, 255+ links, een pagina
  van 200 KB (te lang), doorverwijzing (ook in een kring en naar https),
  404/500, een PRG (verkeerd type), een trage server (RUN/STOP), een leeg
  antwoord, een formulier, een relatieve-adressenpagina.
- **Echte sites** uit §2, via de WiC64 én de RR-Net in VICE.
- Alles ook in de thema's STONE/DESK64 en met een ander font.

## 7. Randgevallen

| Geval | Gedrag |
|---|---|
| geen netwerk | `NO NETWORK` (zoals CHAT/WEATHER) |
| naam onbekend (DNS) | `HOST NOT FOUND` |
| HTTPS-site | de HTTPS-melding; de vorige pagina blijft staan |
| pagina te lang | wat past wordt getoond + melding onderaan |
| meer dan 255 links | de rest is gewone tekst |
| heel lang woord / adres | hard afbreken op 36 tekens |
| RUN/STOP tijdens laden | stoppen; wat binnen is blijft zichtbaar |
| F1 / menu tijdens het lezen | scherm terug zoals het was (zoals elders) |
| BACK | de vorige pagina wordt opnieuw opgehaald (geen cache, zie §9) |
| verkeerd teken in het adres | wordt niet aangenomen bij het typen |

## 8. Stappenplan

| # | Stap | Klaar als |
|---|---|---|
| 1 | **Core-ruimte** + **icoon** + **overlay-skelet**: `web_main.asm`, app-id 15, venster met knoppen en adresregel | ✅ **klaar**: vijf werkbuffers van de Core (help-regel, klokregel, bestandsnaam, laadregel, DOS-opdracht: 133 bytes) staan nu in vrij RAM (`$C3A4-$C3E8`, `$C490-$C4CF`): Core van 16 naar **149 bytes** vrij, na WEB nog 77. Wereldbol-icoon: Win95-stijl op de omgekeerde tekens 155-159 + 162 (komen nooit omgekeerd in een knop voor), STONE-stijl 3x3 op 111-119. STONE-iconen voor ingebouwde apps vanaf 9 algemeen (en een oude fout weg: de sleepschaduw van een eigen programma toonde in STONE het WEATHER-icoon) |
| 2 | **Ophalen + platte tekst**: HTTP/1.0, statusregel, pagina-geheugen `$4000`, scrollen | ✅ **klaar**: `text/plain` als tekst, `LOADING <host> 12K (RUN/STOP)`, schuifbalk, SPATIE/-; een trage server geeft na 20 s `NO ANSWER FROM THE SERVER` |
| 3 | **HTML → tekst**: tags, tekens, `<pre>`, script/style overslaan, titel | ✅ **klaar**: koppen, vet (genest), lijsten, tabellen, `<pre>`, `<hr>`, plaatjes (`[alt]`), commentaar, `&...;` (namen, `&#..;`, `&#x..;`, eacute ...), UTF-8 en Latin-1 → letters zonder accent; info.cern.ch, 68k.news, wiby.me, csdb.dk netjes |
| 4 | **Links**: klikken, relatieve adressen, BACK, doorverwijzingen, HTTPS-melding, foutcodes | ✅ **klaar**: `../` `./` `map` `/pad` `?q` `//host`, `#anker`/`mailto:` geen link; max. 5 doorverwijzingen; `HTTPS: NOT POSSIBLE ON A C64`; 404 = de pagina van de server + melding. Adressen tot **767 tekens** (68k.news-artikelen zijn ~250-700): korte linkadressen bewaard, lange als controlegetal → bij een klik de pagina nog eens lezen en de link zoeken (getest met 300 links, 30 met een adres van 300+ tekens) |
| 5 | **Adres typen + bladwijzers**: `li_Edit`, `BOOKMARKS`, MARKS | ✅ **klaar**: de bladwijzers zijn de startpagina (68k.news, wiby.me); `BOOKMARKS` (SEQ) blijft bij het opnieuw bouwen; BACK (6 adressen), MARKS, RELOAD, toetsen B/M/R/G |
| 6 | **Zoeken**: GET-formulieren met één tekstveld | ✅ **klaar**: het eerste GET-formulier met een tekstveld (+ verborgen velden); POST wordt genegeerd; zoeken op wiby.me |
| 7 | **Testserver** + echte sites via WiC64 en RR-Net | ✅ **klaar**: `tools/web_test_server.py` (alle gevallen); echt: 68k.news, wiby.me (+ zoeken), info.cern.ch, csdb.dk, textfiles.com via de WiC64, wiby.me / csdb.dk / info.cern.ch via de RR-Net. Daarbij een oude fout in `net/dns.asm` gevonden: een CNAME voor het A-record (info.cern.ch) gaf via de RR-Net `HOST NAME NOT FOUND` (geldt voor alle netwerk-apps). Een artikel van 68k.news wordt goed opgevraagd; 68k.news zelf gaf op 07-10-2026 bij alle artikelen "Failed to get the article" (ook vanaf de pc) |
| 8 | **Afwerken**: F1-help, README, schermafdrukken, disks (D81, D71, D64 kant B) | ✅ **klaar**: help (context 20; een paar andere teksten korter), README-hoofdstuk, schermafdrukken (ook de thema's met het WEB-icoon), WEB op D81/D71/release-D81 en op de D64 kant B (`BOOKMARKS` op beide kanten) |

**Wat anders werd dan gepland:** de tekst van een pagina heeft 10 KB
(`$4000-$67FF`) in plaats van 16 KB: `$7000-$7FFF` is van de F1-help en
`$6800-$6FFF` houdt de bladwijzers en de formulier-/kopbuffers (de grote
adresbuffers van 768 bytes kostten de ruimte). BACK onthoudt 6 adressen
van max. 255 tekens (een langer adres wordt afgekapt).

---

## 9. Open vragen (beantwoord)

1. **Naam**: `WEB`.
2. **Startpagina**: de bladwijzers, met 68k.news en wiby.me.
3. **Hoofdletters**: alles in hoofdletters; met het font **LOWER** staan de
   pagina's vanzelf in kleine letters (de tekenset heeft geen plek voor
   beide: de codes erboven zijn iconen).
4. **Uitbreidingen** (nog niet gedaan, alleen als je ze wilt): een REU voor
   langere pagina's en BACK zonder opnieuw ophalen; downloaden naar disk;
   een knop om een bladwijzer toe te voegen.
