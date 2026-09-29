---
name: c64-kickassembler
description: Complete werkinstructie voor het schrijven van correcte Kick Assembler code voor de Commodore 64 — syntax, adresseringsmodi, scripttaal, macro's, scopes, segments, d64-output, en kant-en-klare recepten voor raster-IRQ's, sprites, SID en graphics. Gebruik dit document altijd wanneer er 6502/6510-assembly voor een echte C64 of VICE wordt geschreven, gereviewd of gedebugd.
---

# Kick Assembler voor de C64 — Skill voor de AI Developer

Dit document is de werkinstructie voor alle 6502-assembly die met **Kick
Assembler** (versie 5.x) wordt gebouwd. Doelplatform: **echte Commodore 64 /
VICE, PAL.**

Companion-document: `C64_BASIC_SKILL.md` voor Commodore BASIC V2. Zie §14 voor
hoe de twee samenwerken.

---

## 0. Werkvolgorde — bij ELKE opdracht

1. Lees §1 (harde regels) voordat je één regel code schrijft.
2. Schrijf de code volgens de patronen in §3 t/m §13.
3. Loop de checklist in §16 af.
4. Draai `c64_ka_syntax_checker.py`. Nul ERRORs is verplicht.
5. Assembleer met `java -jar KickAss.jar bron.asm`. Nul fouten is verplicht.
6. Test in VICE.

Als iets niet kan, **zeg dat expliciet**. Verzin geen directives en geen
opcodes.

---

## 1. De harde regels

| # | Regel | Waarom |
|---|---|---|
| 1 | **`//` is commentaar, `;` is een statement-scheider** | `lda #0 ; zet rand` probeert `zet` als commando uit te voeren. Dit is de nummer-1 fout van overstappers. |
| 2 | **`[ ]` voor groeperen, `( )` betekent indirect** | `lda (2+5)*2` wordt als indirecte adressering gelezen. Schrijf `lda #[2+5]*2`. |
| 3 | **Elk programma begint met `*=` of een segment** | Zonder laadadres weet de assembler niet waar de code hoort. |
| 4 | **Labels eindigen op `:` bij definitie, zonder achtervoegsel bij gebruik** | `loop: inc $d020` … `jmp loop` |
| 5 | **Illegale opcodes staan standaard aan** | `.cpu _6502` is de default en bevat de illegals. Wil je ze uitsluiten: `.cpu _6502NoIllegals`. |
| 6 | **Immediate waarden passen in een byte** | `lda #$100` is een fout. Gebruik `#<label` en `#>label` voor adressen. |
| 7 | **`.var` declareert, `.eval` wijzigt** | `.eval x=1` zonder eerdere `.var x` geeft een fout. |
| 8 | **Mutabele waarden buiten hun pass moeten gelockt zijn** | Een `List()` die je in een latere pass gebruikt: `.lock()` of definieer hem in een `.define`-blok. |
| 9 | **Macro's, functies en pseudocommands mogen pas na hun aanroep gedefinieerd worden — labels ook** | Alleen `.var` en `.const` moeten vóór gebruik staan. |
| 10 | **Één sprite = 63 bytes, pointerwaarde = adres/64** | Zie §13.3. |
| 11 | **Zeropage-labels die later worden gedefinieerd: markeer met `.zp`** | Anders kiest de assembler de absolute vorm en kost elke toegang een byte en een cyclus extra. |
| 12 | **Bij twijfel: laat de assembler het uitrekenen, niet jij** | `.fill 256, round(127.5+127.5*sin(toRadians(i*360/256)))` is beter dan een handmatige tabel. |

---

## 2. Toolchain

### 2.1 Assembleren

```bash
java -jar KickAss.jar programma.asm
java -jar KickAss.jar programma.asm -o out/demo.prg
java -jar KickAss.jar programma.asm -showmem -vicesymbols
java -jar KickAss.jar programma.asm -libdir ../lib -libdir ~/hvsc
```

Kick Assembler vereist **Java 8 of hoger**. Zonder `-o` heet de uitvoer zoals
het bronbestand met extensie `.prg`.

### 2.2 KickAss.cfg

Zet naast `KickAss.jar` een bestand `KickAss.cfg` met opties die je altijd
wilt. Regels die met `#` beginnen zijn commentaar.

```text
# standaardopties voor elk project
-showmem
-vicesymbols
-libdir ../lib
-execute "x64sc -confirmexit"
```

Met `-execute` start VICE automatisch na een geslaagde assemblage.

### 2.3 Belangrijkste commandline-opties

| Optie | Effect |
|---|---|
| `-o BESTAND` | naam van het uitvoerbestand |
| `-odir MAP` | uitvoermap |
| `-libdir MAP` | extra zoekpad voor `#import` en `.import` (meerdere keren toegestaan) |
| `-showmem` | print een geheugenkaart na het assembleren |
| `-bytedump` | schrijft `ByteDump.txt` met alle bytes plus de code die ze maakte |
| `-vicesymbols` | schrijft een `.vs` labelbestand voor VICE |
| `-symbolfile` | schrijft een `.sym` met alle symbolen, importeerbaar in andere bronnen |
| `-debugdump` | schrijft debug-info voor C64Debugger |
| `-execute "..."` | start een programma (emulator) na succes |
| `-define NAAM` | definieert een preprocessor-symbool |
| `-binfile` | schrijft een bin in plaats van een prg (zonder de twee adresbytes) |
| `-afo` | staat schrijven van bestanden buiten de uitvoermap toe (nodig voor `createFile`) |
| `-aom` | overlappend geheugen geeft een waarschuwing in plaats van een fout |
| `-excludeillegal` | sluit de illegale opcodes uit |
| `-time` | toont de assembleertijd |
| `:naam=waarde` | geeft een string aan het script door, leesbaar via `cmdLineVars` |

### 2.4 Syntax checker — verplicht vóór oplevering

```bash
python c64_ka_syntax_checker.py programma.asm
python c64_ka_syntax_checker.py programma.asm --json
python c64_ka_syntax_checker.py programma.asm --no-warn
python c64_ka_syntax_checker.py programma.asm --cpu _65c02
```

De checker vindt onder meer: onbalans in `()`, `[]`, `{}` en `#if`/`#endif`;
niet-afgesloten strings en blokcommentaar; onbekende directives en
preprocessor-directives; onbekende mnemonics en mnemonics die niet in de
gekozen `.cpu` zitten; ongeldige adresseringsmodi (`sta #$10`, `ldx $10,x`,
`lda ($10),x`); `;` gebruikt als commentaar; leidende `(` die als indirect
wordt gelezen; waardebereiken (`#$100`, `.byte 300`, `.word $12345`);
`.for`-headers zonder twee puntkomma's; `.function` zonder `.return`;
macro-aanroepen met het verkeerde aantal argumenten; dubbele labels binnen
dezelfde scope; `.eval` op een niet-gedeclareerde variabele; ontbrekende
importbestanden bij zowel `.import` als `#import`; `.import` zonder
bestandsnaam; `jmp`/`jsr` naar een label dat data bevat in plaats van code;
een `.encoding` binnen een blok terwijl er daarna nog tekstdata volgt; een raster-interrupt die met
`$d01a` wordt aangezet maar nergens met `$d019` bevestigd; en een
hardware-vector `$fffe` die via de kernal (`$ea31`/`$ea81`) wordt afgesloten.

**Eis: 0 ERRORs.** De checker is statisch en geen assembler: hij rekent geen
labelwaarden uit, dus branch-bereik, geheugenoverlap en zeropage-keuze worden
**niet** gecontroleerd. Hij vervangt de echte assembleerstap niet.

Programmatisch aanroepen — de API spiegelt `c64_syntax_checker.py`:

```python
from c64_ka_syntax_checker import check_source, check_file

report = check_source(src, print_errors=False)
data   = check_source(src, return_structured=True)   # dict met issues + summary
rc     = check_file("programma.asm")                 # 0 = ok, 1 = errors
```

### 2.5 Testen in VICE

```bash
x64sc programma.prg
x64sc -moncommands breakpoints.txt programma.prg
```

Met `-vicesymbols` krijg je een labelbestand dat je in de VICE-monitor kunt
laden, zodat je op labelnaam kunt breken in plaats van op adres.

---

## 3. Syntax

### 3.1 Mnemonics en instructiesets

```asm
        lda #0
        sta $d020
        sta $d021
        lda #0; sta $d020; sta $d021    // ';' scheidt statements
```

Vier instructiesets, te kiezen met `.cpu`:

| Naam | Inhoud |
|---|---|
| `_6502NoIllegals` | alleen de gedocumenteerde 6502-instructies |
| `_6502` | **standaard** — 6502 plus de illegale opcodes |
| `dtv` | `_6502` plus `bra`, `sac`, `sir` |
| `_65c02` | de 65c02-set (niet bruikbaar op een standaard C64) |

```asm
.cpu _65c02
loop:   inc $20
        bra loop        // bestaat niet in de standaard 6502-set
```

Voor een C64 blijf je bij `_6502`. Gebruik `_65c02` alleen als de hardware het
echt heeft — een gewone C64 heeft een 6510 en kent `bra`, `stz`, `phx` niet.

### 3.2 Adresseringsmodi

| Modus | Voorbeeld |
|---|---|
| geen argument | `nop`, `rts`, `asl` |
| immediate | `lda #$30` |
| zeropage | `lda $30` |
| zeropage,x | `lda $30,x` |
| zeropage,y | `ldx $30,y` |
| indirect zeropage,x | `lda ($30,x)` |
| indirect zeropage,y | `lda ($30),y` |
| absoluut | `lda $1000` |
| absoluut,x | `lda $1000,x` |
| absoluut,y | `lda $1000,y` |
| indirect | `jmp ($1000)` |
| relatief | `bne loop` |

De assembler kiest automatisch de zeropage-vorm als het adres in een byte
past. Forceren kan met een achtervoegsel:

```asm
        lda.abs $0040,x     // dwing absolute vorm af
        lda.a   $0030,x     // afkorting van .abs
        stx.zp  zpLabel,y   // dwing zeropage af
        stx.z   zpLabel,y   // afkorting van .zp
```

De oude achtervoegsels (`.im`, `.zx`, `.izy`, `.ax`, `.ind`, `.rel`, …) zijn
verouderd. Gebruik ze niet; ze bestaan alleen nog voor oude bronbestanden.

**Wat vaak misgaat:**

| Fout | Waarom | Goed |
|---|---|---|
| `sta #$10` | `sta` kent geen immediate | `lda #$10` … `sta adres` |
| `ldx $10,x` | `ldx` kent alleen `,y` | `ldx $10,y` of `lda $10,x` |
| `lda ($10),x` | bestaat niet op de 6502 | `lda ($10,x)` of `lda ($10),y` |
| `lda ($10)` | alleen 65c02 | `ldy #0` … `lda ($10),y` |
| `inx $10` | `inx` heeft geen argument | `inc $10` |
| `lda (2+5)*2` | `(` wordt als indirect gelezen | `lda #[2+5]*2` |

### 3.3 Getalformaten

```asm
        lda #42          // decimaal
        lda #$2a         // hexadecimaal
        lda #%101010     // binair
        .var f = 1.5e3   // wetenschappelijke notatie in het script
```

### 3.4 Labels

```asm
loop:   inc $d020
        inc $d021
        jmp loop
```

Labels mogen ook vóór een argument staan — handig voor zelfmodificerende code:

```asm
        stx tmpX
        ...
        ldx tmpX:#$00     // 'tmpX' wijst naar de operandbyte
```

**Multi-labels** voorkomen naamconflicten. Ze beginnen met `!`; bij gebruik
verwijst `-` naar de vorige en `+` naar de volgende:

```asm
        ldx #100
!loop:  inc $d020
        dex
        bne !loop-        // naar de vorige !loop
        ldx #100
!loop:  inc $d021         // mag opnieuw zo heten
        dex
        bne !loop-
```

```asm
        jmp !+            // spring over de twee nops
        nop
        nop
!:      rts
```

Meerdere tekens slaan labels over: `!+++` springt naar het derde `!`-label.

`*` levert de huidige geheugenpositie:

```asm
        jmp *             // eeuwige lus
        inc $d020
        jmp *-6           // spring terug
```

Voor de leesbaarheid: gebruik `jmp *` alleen voor "hier blijven hangen", en
echte labels voor al het andere.

### 3.5 Zeropage-labels

Een label dat nog niet is opgelost wordt als tweebyte-adres behandeld, óók als
het later in de zeropage blijkt te liggen. Markeer zulke labels met `.zp`:

```asm
        lda zpReg1        // gebruikt de zeropage-vorm
        sta zpReg2

        *=$10 virtual
.zp {
zpReg1: .byte 0
zpReg2: .byte 0
}
```

Let op: `.zp` werkt niet door in macro's en pseudocommands die binnen het blok
worden aangeroepen.

---

## 4. Geheugen- en datadirectives

### 4.1 Geheugenpositie

```asm
        *=$1000 "Program"
        ldx #10
!loop:  dex
        bne !loop-
        rts

        *=$4000 "Data"
        .byte 1,0,2,0,3,0,4,0
```

De naam achter het adres is optioneel en verschijnt in de geheugenkaart bij
`-showmem`:

```text
Memory Map
----------
$1000-$1005 Program
$4000-$4007 Data
```

`.pc = $1000` is de oude schrijfwijze; gebruik `*=`.

**virtual** reserveert adresruimte zonder bytes uit te voeren:

```asm
        *=$0400 "Buffers" virtual
buf1:   .fill $100,0
buf2:   .fill $100,0
```

Virtuele blokken mogen overlappen met andere blokken en staan met een `*` in
de geheugenkaart. Ze belanden niet in het prg-bestand.

**align** duwt de positie naar een grens — bespaart een cyclus bij tabellen
die anders een pagina-grens overschrijden:

```asm
        *=$10ff
        .align $100       // schuift naar $1100
data:   .byte 1,2,3,4,5,6,7,8
```

**pseudopc** assembleert alsof de code ergens anders staat:

```asm
        *=$1000 "Wordt naar $2000 verplaatst"
.pseudopc $2000 {
loop:   inc $d020
        jmp loop          // wordt jmp $2000, niet jmp $1000
}
```

### 4.2 Data

```asm
        .byte 1,2,3,4               // ook: .by
        .word $2000,$1234           // ook: .wo — little endian
        .dword $12341234            // ook: .dw
        .text "Hello World"         // ook: .te
```

`.fill` vult een reeks; de lusvariabele heet altijd `i`:

```asm
        .fill 5, 0                  // 0,0,0,0,0
        .fill 5, i                  // 0,1,2,3,4
        .fill 256, round(127.5+127.5*sin(toRadians(i*360/256)))
        .fill 4, [$10,$20]          // herhaalt het patroon: $10,$20,$10,$20,...
        .fill 3, [i,i*$10]          // 0,0,1,$10,2,$20
        .fillword 5, i*$80          // .word $0000,$0080,$0100,$0180,$0200
```

`.lohifill` maakt in één keer een lo- en een hi-tabel, bereikbaar via `.lo` en
`.hi` op het gekoppelde label. Dit is de standaardmanier om een
schermregel-tabel te bouwen:

```asm
        ldx #20                     // rij
        ldy #15                     // kolom
        lda mul40.lo,x
        sta $fe
        lda mul40.hi,x
        ora #$04                    // schermgeheugen op $0400
        sta $ff
        lda #'x'
        sta ($fe),y
        rts

mul40:  .lohifill $100, 40*i
```

`.fill` is sneller te assembleren dan een `.for`-lus met `.byte`. Gebruik
`.fill` waar het kan.

### 4.3 Encoding

`.text` zet tekens om volgens de actieve encoding. De standaard is
`screencode_mixed`.

| Naam | Betekenis |
|---|---|
| `ascii` | ruwe ASCII |
| `petscii_mixed` | PETSCII, kleine + hoofdletters |
| `petscii_upper` | PETSCII, hoofdletters + grafiek |
| `screencode_mixed` | schermcodes van `petscii_mixed` |
| `screencode_upper` | schermcodes van `petscii_upper` |

```asm
.encoding "screencode_upper"
        .text "ALLEEN HOOFDLETTERS EN GRAFIEK"

.encoding "petscii_mixed"
        .text "Voor print-routines via de kernal"
```

Vuistregel: schrijf je met `sta $0400,x` rechtstreeks in het schermgeheugen,
gebruik dan een **screencode**-encoding. Print je via `jsr $ffd2`, gebruik dan
een **petscii**-encoding. De encoding werkt ook door op `.import text`.

**`.encoding` is een globale schakelaar, geen scope-eigenschap.** Zet je hem
binnen een `{}`-blok, dan geldt hij ook voor alle tekstdata die daarna komt,
buiten dat blok. Zet hem daarom bovenaan het bestand, of herstel hem meteen na
de tabel waarvoor je hem nodig had.

### 4.4 Data importeren

```asm
        .import binary "music.bin"          // ruwe bytes
        .import c64    "charset.prg"        // slaat de 2 adresbytes over
        .import text   "scroll.txt"         // via de actieve encoding

        .import binary "music.bin", 100     // sla de eerste 100 bytes over
        .import c64    "charset.prg", $400, $200   // offset en lengte
```

### 4.5 Commentaar

```asm
/*----------------------------------------
   Blokcommentaar
----------------------------------------*/
        lda #10
        sta $d020       // regelcommentaar
        sta /* mag ook midden in */ $d021
        rts
```

**`;` is géén commentaar.** Dat is een statement-scheider, omdat de puntkomma
in `.for`-lussen wordt gebruikt.

### 4.6 Console-uitvoer en fouten

```asm
        .print "Hallo"
        .print "start=$" + toHexString(start)
        .printnow "meteen tonen, ook als een latere pass faalt"

        .var breedte = 45
        .errorif breedte>40, "breedte mag niet boven 40"
        .if (breedte>40) .error "breedte mag niet boven 40"
```

`.print` verschijnt pas in de laatste pass. `.printnow` print in elke pass, wat
handig is bij debuggen van scripts die crashen vóór de output-pass — maar de
waarde kan in vroege passes nog `<<Invalid String>>` zijn.

`.errorif` is flexibeler dan `.if ... .error`, omdat `.if` al in de eerste pass
beslist moet worden. Voor controles op nog niet opgeloste labels gebruik je
altijd `.errorif`:

```asm
        beq label1
        .errorif (>*) != (>label1), "Pagina-grens overschreden!"
        nop
label1:
```

### 4.7 Breakpoints en watches

Deze veranderen niets aan de code; ze zetten debug-info in het VICE-symbol- of
C64Debugger-bestand.

```asm
        ldy #10
loop:   .break                      // breekpunt op de volgende instructie
        inc $d020
        dey
        .break "if y<5"             // conditie voor de VICE-monitor
        bne loop

        .watch $d018
        .watch $d000,$d00f          // een bereik
        .watch teller,,"hex8"       // tweede argument mag leeg blijven
```

---

## 5. De scripttaal

Kick Assembler heeft een ingebouwde scripttaal die tijdens het assembleren
draait. Daarmee genereer je data in plaats van hem met de hand uit te typen.
Dit is het grootste voordeel van Kick Assembler boven een klassieke assembler —
gebruik het.

### 5.1 Variabelen, constanten en labels

```asm
        .var x = 25
        lda #x                  // lda #25
        .eval x = x + 10
        lda #x                  // lda #35

        .const DELAY = 7        // kan niet meer wijzigen
        .label BORDER = $d020   // zichtbaar in het hele scope, ook ervóór
```

Verschil dat je moet kennen:

- `.var` / `.const` zijn **pas zichtbaar na de declaratie**.
- `.label` is **zichtbaar in het hele scope**, dus ook op regels erboven.

```asm
        inc myLabel1
        .const myLabel1 = $d020    // FOUT: nog niet zichtbaar

        inc myLabel2
        .label myLabel2 = $d020    // goed
```

Verkorte operatoren: `++`, `--`, `+=`, `-=`, `*=`, `/=`. De post-increment
gedraagt zich als in C: `.eval y = x++` zet `y` op de oude waarde.

`.enum` maakt een reeks constanten:

```asm
        .enum { SINGLE, MULTI }                 // 0, 1
        .enum { UP, DOWN, LEFT, RIGHT, NONE=$ff }
        .enum { EFFECT1=1, EFFECT2=2, END=$ff }
```

### 5.2 Scopes

Accolades maken een scope. Wat erbinnen is gedeclareerd, is buiten onzichtbaar:

```asm
Function1: {
        .var length = 10
        ldx #0
loop:   sta table1,x            // dit 'loop' botst niet
        inx
        cpx #length
        bne loop
}

Function2: {
        .var length = 20        // botst niet met de vorige
        ldx #0
loop:   sta table2,x
        inx
        cpx #length
        bne loop
}
```

Scopes mogen genest worden. Een binnenscope ziet de buitenscope, niet andersom.

### 5.3 Waardetypen

| Type | Voorbeeld | Opmerking |
|---|---|---|
| Number | `27.4` | intern floating point |
| Boolean | `true` / `false` | |
| String | `"hallo"` | |
| Char | `'x'` | is tegelijk een getal |
| List | `List().add(1,2,3)` | mutabel |
| Hashtable | `Hashtable()` | mutabel |
| Struct | `Point(1,2)` | via `.struct` |
| Vector | `Vector(1,2,3)` | 3D |
| Matrix | `Matrix()` | 4x4 |
| Null | `null` | |

### 5.4 Rekenen

Operatoren: `+ - * /`, bitsgewijs `& | ^ ~ << >>`, en de hoge/lage-byte
operatoren `>` en `<`.

```asm
        .var charmem = $0400
        ldx #0
loop:   sta charmem + 0*$100,x
        sta charmem + 1*$100,x
        sta charmem + 2*$100,x
        sta charmem + 3*$100,x
        inx
        bne loop

        lda #<interrupt1        // lage byte
        sta $0314
        lda #>interrupt1        // hoge byte
        sta $0315

        .var v = $12345678
        .word v & $00ff, [v>>16] & $00ff    // $0078, $0034
```

**Haakjes:** `[]` groepeert, `()` betekent indirecte adressering in een
mnemonic-argument. In pure scriptexpressies mag je beide gebruiken, maar maak
er gewoonte van om overal `[]` te schrijven — dan kun je nooit per ongeluk een
indirecte instructie maken.

### 5.5 Strings

```asm
        .var msg = "Hallo " + naam       // + plakt aan elkaar
        .const pad = "c:\newstuff"       // \n is hier GEEN newline
        .print @"Regel1\nRegel2"         // @ zet escapes aan
        .print @"Hij zei: \"hallo\""
        .text  @"eindmarkering\$ff"      // \$ voor een hexbyte
```

Escapes werken **alleen** in `@"..."`. In een gewone string is `\` een gewoon
teken — dat is met opzet zo, zodat Windows-paden niet stukgaan.

Escapecodes: `\b \f \n \r \t \\ \" \$hh`

| Functie | Werking |
|---|---|
| `size()` | aantal tekens |
| `charAt(n)` | teken op positie n |
| `substring(i1,i2)` | deelstring, i2 niet inbegrepen |
| `toUpperCase()` / `toLowerCase()` | |
| `asNumber()` / `asNumber(radix)` | `"f".asNumber(16)` = 15 |
| `asBoolean()` | |

Getal naar string: `toIntString(x[,min])`, `toBinaryString(x[,min])`,
`toOctalString(x[,min])`, `toHexString(x[,min])`. Voor labels vrijwel altijd:

```asm
        .print "irq1 = $" + toHexString(irq1, 4)
```

### 5.6 Wiskunde

Constanten `PI` en `E`. Functies: `abs acos asin atan atan2 cbrt ceil cos cosh
exp expm1 floor hypot IEEEremainder log log10 log1p max min mod pow random
round signum sin sinh sqrt tan tanh toDegrees toRadians`.

`mod(a,b)` is de enige niet-Java functie: hij maakt van beide integers en geeft
de rest.

```asm
        lda #random()*256
        .fill 256, round(127.5+127.5*sin(toRadians(i*360/256)))
```

### 5.7 Vertakken en herhalen

```asm
        .if (x>10) .eval x = 10

        .if (toonRastertijd) inc $d020
        jsr PlayMusic
        .if (toonRastertijd) dec $d020

        .if (irqNr==3) {
            inc $d020
            jsr music+3
            dec $d020
        } else {
            nop
        }

        .var max = a>b ? a : b          // korte if
        inc debug ? $d020 : $d013
```

```asm
        .for (var i=0; i<10; i++) .print "Nummer " + i
        .for (var i=0; i<256; i++) .byte round(127.5+127.5*sin(toRadians(360*i/256)))

        .var i=0
        .while (i<10) {
            .print i
            .eval i++
        }
```

Vergelijkingen leveren `true`/`false`; `&&` en `||` zijn short-circuit.

### 5.8 Lijsten, hashtables en structs

```asm
        .var lijst = List().add("Fairlight", "Booze Design", "etc.")
        .print lijst.get(0)
        .print lijst.size()
```

Functies op lijsten: `get(n) set(n,v) add(...) addAll(list) size() remove(n)
shuffle() reverse() sort() lock()`.

```asm
.define ht {
        .var ht = Hashtable()
        .eval ht.put("ram", 64)
        .eval ht.put(1, "Hello")
        .var ht2 = Hashtable().put(1,"Ja").put(2,"Nee")
}
        .print ht.get("ram")
```

```asm
        .struct Point { x, y }
        .var p1 = Point(1,2)
        .print p1.x
        .var p2 = Point()
        .eval p2.x = 3
```

Structs kennen ook `getStructName() getNoOfFields() getFieldNames()
get(index|naam) set(index|naam, waarde)`.

### 5.9 Mutabele waarden en `.define`

Lijsten, hashtables en structs zijn **mutabel**. Wil je zo'n waarde in een
latere pass gebruiken, dan moet hij gelockt zijn. Twee manieren:

```asm
        .var lijst1 = List().add(1,3,5).lock()

.define lijst2, lijst3 {
        .var lijst2 = List().add(1,2)
        .var lijst3 = List()
        .eval lijst3.add("a")
        .eval lijst3.add("b")
}
```

`.define` voert het blok uit in **function mode**: sneller en zuiniger, maar
alleen scriptdirectives zijn toegestaan — geen `lda`, `.byte`, `.fill`. De
opgesomde symbolen worden daarna als constante in de buitenscope gezet.

**Optimalisatietip:** zware rekenlussen horen in een `.define`-blok of in een
`.function`. Daarbuiten onthoudt de assembler alle tussenresultaten per pass,
wat geheugen en tijd kost.

---

## 6. Functies, macro's en pseudocommands

### 6.1 Functies

Een functie rekent en geeft een waarde terug. Hij mag **geen** bytes
produceren.

```asm
.function area(width, height) {
        .return width*height
}

.function oddEven(number) {
        .if ([number&1] == 0) .return "even"
        .return "odd"
}

        .var x = area(3,2)
        lda #10+area(4,8)
```

Zonder `.return` levert de functie `null`. Meerdere functies met dezelfde naam
mogen, mits het aantal argumenten verschilt.

### 6.2 Macro's

Een macro plakt code op de plek van de aanroep.

```asm
.macro SetColor(color) {
        lda #color
        sta $d020
}

        SetColor(1)
        :SetColor(2)        // de dubbele punt is optioneel
```

Elke aanroep krijgt zijn eigen scope, dus interne labels botsen niet:

```asm
        ClearScreen($0400,$20)
        ClearScreen($4400,$20)      // 'Loop' botst niet

.macro ClearScreen(screen, clearByte) {
        lda #clearByte
        ldx #0
Loop:   sta screen,x
        sta screen+$100,x
        sta screen+$200,x
        sta screen+$300,x
        inx
        bne Loop
}
```

Een macro mag vóór zijn definitie worden aangeroepen, mag andere macro's
aanroepen en mag zichzelf aanroepen — zorg dan wel voor een stopconditie.

### 6.3 Pseudocommands

Een pseudocommand is een macro die **echte mnemonic-argumenten** aanneemt. Zo
bouw je je eigen uitgebreide instructieset.

```asm
.pseudocommand mov src : tar {
        lda src
        sta tar
}

        mov #10 : $1000             // lda #10 / sta $1000
        mov bron : doel
        mov bron,x : doel,y
        mov #20 : ($30),y
```

Argumenten worden gescheiden door `:` (in versie 3.x was dat `;`).

Elk argument is een `CmdValue` met `getType()` en `getValue()`. De typen:
`AT_ABSOLUTE`, `AT_ABSOLUTEX`, `AT_ABSOLUTEY`, `AT_IMMEDIATE`, `AT_INDIRECT`,
`AT_IZEROPAGEX`, `AT_IZEROPAGEY`, `AT_NONE`. Nieuwe argumenten maak je met
`CmdArgument(type, waarde)`.

Praktisch voorbeeld — een 16-bits instructieset:

```asm
.function _16bitNext(arg) {
        .if (arg.getType()==AT_IMMEDIATE)
            .return CmdArgument(arg.getType(), >arg.getValue())
        .return CmdArgument(arg.getType(), arg.getValue()+1)
}

.pseudocommand inc16 arg {
        inc arg
        bne over
        inc _16bitNext(arg)
over:
}

.pseudocommand mov16 src : tar {
        lda src
        sta tar
        lda _16bitNext(src)
        sta _16bitNext(tar)
}

.pseudocommand add16 arg1 : arg2 : tar {
        .if (tar.getType()==AT_NONE) .eval tar = arg1
        clc
        lda arg1
        adc arg2
        sta tar
        lda _16bitNext(arg1)
        adc _16bitNext(arg2)
        sta _16bitNext(tar)
}
```

Gebruik:

```asm
        inc16 teller
        mov16 #irq1 : $0314
        add16 $30 : #128            // doel weggelaten: resultaat in $30
        add16 $30 : #$1000 : $32
```

Een weggelaten argument komt binnen als type `AT_NONE`; daarmee maak je
optionele parameters.

**Let op:** een pseudocommand mag dezelfde naam hebben als een mnemonic. Zet
er dan een `:` voor om het pseudocommand te kiezen:

```asm
        adc #$10                    // het echte mnemonic
        :adc #$20 : $10 : $20       // het pseudocommand
```

---

## 7. Preprocessor

De preprocessor draait vóór de parser en beslist welke stukken bron de
assembler überhaupt te zien krijgt. Preprocessor-directives beginnen met `#`.

```asm
#define DEBUG
#undef DEBUG

#if DEBUG
        inc $d020
#endif

#if A
        .print "A"
#elif B
        .print "B"
#else
        .print "geen van beide"
#endif
```

Binnen een niet-genomen `#if` mag alles staan; de parser ziet het niet. Dat
maakt het ook geschikt om kapotte of platformspecifieke code weg te schakelen.

Symbolen definieer je in de bron met `#define` of op de commandline met
`-define NAAM`. Een symbool heeft geen waarde — het is er wel of niet.

Operatoren in `#if`: `!`, `&&`, `||`, `==`, `!=` en haakjes.

Bestanden importeren:

```asm
#import "MyLibrary.asm"
#importif STAND_ALONE "UpstartCode.asm"
```

Zet bovenin elk bibliotheekbestand `#importonce`, dan wordt het hoogstens één
keer ingevoegd:

```asm
// MyLibrary.asm
#importonce
.filenamespace MyLibrary
```

**Gebruik `#import`, niet `.import source`.** De oude directive bestaat nog
maar leest het bestand pas tijdens de evaluatie, wat tot een verwarrende
volgorde leidt. De preprocessor voegt het meteen in.

Kick Assembler zoekt een bestand eerst in de map van de bron, daarna in elke
map die met `-libdir` is opgegeven.

---

## 8. Scopes en namespaces

Twee verschillende containers:

- Een **scope** bevat symbolen: variabelen, constanten en labels.
- Een **namespace** bevat functies, macro's en pseudocommands — en heeft zijn
  eigen scope.

De hiërarchie loopt van binnen naar buiten:

```text
1. system namespace + scope   (alles wat Kick Assembler zelf meebrengt)
2. root namespace + scope     (de wortel van je broncode)
3. door de gebruiker gemaakte namespaces
4. door de gebruiker gemaakte scopes ({}, macro's, functies, lussen)
```

Bij het opzoeken van een symbool kijkt de assembler eerst in het huidige scope
en klimt daarna omhoog.

### 8.1 Namespaces gebruiken

De praktische toepassing: zet bovenin elk bronbestand een `.filenamespace`,
dan botsen de labels van dat bestand nooit met die van een ander.

```asm
/* main.asm */
        jsr part1.init
        jsr part1.exec
        jsr part2.init
        jsr part2.exec
        rts

/* part1.asm */
#importonce
.filenamespace part1
init:   rts
exec:   rts

/* part2.asm */
#importonce
.filenamespace part2
init:   rts
exec:   rts
```

Een blok-namespace groepeert registers netjes:

```asm
.namespace vic {
        .label borderColor      = $d020
        .label backgroundColor0 = $d021
        .label backgroundColor1 = $d022
        .label backgroundColor2 = $d023
}

        lda #0
        sta vic.backgroundColor0
        sta vic.borderColor
```

Dezelfde namespace mag meerdere keren geopend worden; de tweede keer ga je
verder in de bestaande. Een functie of macro twee keer definiëren mag niet.

`getNamespace()` geeft de naam van de huidige namespace terug — handig bij
debuggen.

### 8.2 Ontsnappen naar de root

`@` verwijst naar de root:

```asm
        .label myLabel = 1
        {
            .label myLabel = 2
            .print "lokaal = " + myLabel      // 2
            .print "root   = " + @myLabel     // 1
        }
```

Je kunt ook iets ín de root plaatsen vanuit een binnenscope:

```asm
        {
@outside_label:
            lda #0
            sta $d020
            rts
        }
        jsr outside_label
```

Datzelfde werkt voor functies, macro's en pseudocommands — precies wat je
nodig hebt als een bibliotheek met een `.filenamespace` toch één publiek
symbool moet exporteren:

```asm
/* mylib.lib */
#importonce
.filenamespace MyLibrary

.function @myFunction() { .return 1 }
.macro    @MyMacro()    { .print "Macro" }
```

### 8.3 Labelscopes

Zet je een scope achter een label, dan zijn de labels erbinnen bereikbaar als
velden van dat label. Zo houd je subroutine-labels lokaal én toch bruikbaar:

```asm
        lda #'a'
        sta clearScreen.fillbyte
        jsr clearScreen
        rts

clearScreen: {
        .label fillbyte = *+1
        lda #0
        ldx #0
loop:   sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $0700,x
        inx
        bne loop
        rts
}
```

Door `.label fillbyte = *+1` te gebruiken hoef je bij het aanroepen niet meer
zelf `+1` op te tellen.

Hetzelfde geldt voor macro-aanroepen:

```asm
        *=$1000
start:  inc c1.color
        dec c2.color
c1:     :setColor()
c2:     :setColor()
        jmp start

.macro setColor() {
        .label color = *+1
        lda #0
        sta $d020
}
```

Bij `.for`- en `.while`-lussen krijg je een **array** van labelscopes:

```asm
        .for (var i=0; i<20; i++) {
            lda #i
            sta loop2[i].color+1
        }

loop2:  .for (var i=0; i<20; i++) {
color:      lda #0
            sta $d020
        }
```

Bij een `.if` krijg je de labels van de genomen tak.

---

## 9. Segments

Segments zijn lijsten van geheugenblokken. Ze bepalen de volgorde in het
geheugen, laten je code en data in de bron bij elkaar houden, en sturen de
uitvoer naar bestanden of disk-images.

Gebruik je geen segments, dan komt alles in het `Default`-segment en gaat het
naar het standaard uitvoerbestand — precies zoals je gewend bent.

### 9.1 Definiëren en wisselen

```asm
        .segmentdef Code [start=$0810]
        .segmentdef Data [startAfter="Code", align=$100]

        .segment Code
        inc $d020
        jmp *-3

        .segment Data
tabel:  .fill $100, i

        .segment Code       // terug naar Code, gaat verder waar je was
        rts

        .segment Default    // terug naar het standaardsegment
```

Korter, definiëren en wisselen in één keer:

```asm
        .segment Code [start=$1000]
```

Een segment mag maar één keer gedefinieerd worden.

### 9.2 Uitvoer

Zonder bestemming verdwijnt de inhoud van een segment. Zichtbaar maken kan met
`-bytedump`; naar een bestand schrijven doe je zo:

```asm
        .segment Code [outPrg="colors.prg"]     // prg met adresbytes
        .segment Data [outBin="data.bin"]       // ruwe bytes
```

Of via `.file`, dat meerdere segments kan samenvoegen:

```asm
        .file [name="demo.prg", segments="Code,Data"]
```

### 9.3 Code en data bij elkaar houden

Dit is de belangrijkste reden om segments te gebruiken. Je schrijft de data
naast de routine die hem gebruikt, maar in het geheugen staat alles netjes
gescheiden:

```asm
.segmentdef Code [start=$0900]
.segmentdef Data [start=$8000]
.file [name="demo.prg", segments="Code,Data",
       modify="BasicUpstart", _start=$0900]

//--------------------------------------------------
        .segment Code "Main"
        jsr colorSetup
        jsr textSetup
        rts

//--------------------------------------------------
        .segment Code "Color Setup"
colorSetup:
        lda colors
        sta $d020
        lda colors+1
        sta $d021
        rts

        .segment Data "Colors"
colors: .byte LIGHT_GRAY, DARK_GRAY

//--------------------------------------------------
        .segment Code "Text Setup"
textSetup: {
        ldx #0
loop:   lda text,x
        cmp #$ff
        beq out
        sta $0400,x
        inx
        jmp loop
out:    rts

        .segment Data "Static Text"
text:   .text "hello world!"
        .byte $ff
}
```

De tekst achter `.segment` benoemt het nieuwe geheugenblok en verschijnt in de
geheugenkaart:

```text
Code-segment:
  $0900-$0906 Main
  $0907-$0913 Color Setup
  $0914-$0924 Text Setup
Data-segment:
  $8000-$8001 Colors
  $8002-$800e Static Text
```

Merk op dat scopes en segments elkaar niet in de weg zitten: in het voorbeeld
staat `text:` binnen de scope van `textSetup`, dus een andere routine mag zijn
eigen `text:` hebben.

### 9.4 Nuttige parameters

| Parameter | Betekenis |
|---|---|
| `start=$1000` | startadres van het standaardblok |
| `startAfter="Code"` | begint waar het genoemde segment ophoudt |
| `align=$100` | lijnt het standaardblok uit op een grens |
| `min` / `max` | grenzen; erbuiten volgt een fout |
| `fill` / `fillByte` | vult ongebruikte ruimte tussen `min` en `max` |
| `virtual` | alle blokken virtueel (leveren geen bytes op) |
| `segments="A,B"` | neemt de blokken van andere segments over |
| `prgFiles="a.prg"` | voegt prg-bestanden als blokken toe |
| `sidFiles="m.sid"` | voegt de data van een sid-bestand toe |
| `outPrg` / `outBin` | schrijft het segment naar een bestand |
| `allowOverlap` | overlappende blokken geven geen fout |
| `modify="Naam"` | stuurt de blokken door een modifier |
| `hide` | verbergt het segment in geheugendumps |
| `dest="DISKDRIVE"` | markering voor debuggers |

`startAfter` is ideaal om geheugen te hergebruiken: initialisatiecode die
maar één keer draait, kan dezelfde ruimte innemen als een buffer die pas
daarna wordt gebruikt.

```asm
        .file [name="program.prg", segments="Code, InitCode"]
        .segmentdef Code     [start=$1000]
        .segmentdef InitCode [startAfter="Code"]
        .segmentdef Buffer   [startAfter="Code", virtual]

        .segment Buffer
table1: .fill $100, 0
table2: .fill $100, 0
```

`Code` en `InitCode` gaan het bestand in, `Buffer` niet. Overlap tussen
verschillende segments geeft geen fout — alleen binnen één segment.

### 9.5 Grenzen bewaken

```asm
        .segment Data [start=$c000, min=$c000, max=$cfff]
        .fill $1800, 0          // FOUT: loopt tot $d7ff
```

Met `fill` dwing je een exacte grootte af — nodig voor cartridge-banks:

```asm
        .segment Data [min=$1000, max=$1008, fill]
        *=$1002
        .byte 1,2,3             // geeft $1000: 0,0,1,2,3,0,0,0,0
```

### 9.6 Bestanden patchen

```asm
        .file [name="patched.prg", segments="Base,Patch", allowOverlap]
        .segmentdef Base  [prgFiles="base.prg"]
        .segmentdef Patch []

        .segment Patch
        *=$3802 "jmp invoegen"
        jmp $3fe0
        *=$38c2 "lda #$ff invoegen"
        lda #$ff
```

Overlappende blokken worden geknipt; het laatst toegevoegde segment wint, dus
`Patch` overschrijft `Base`.

### 9.7 Modifiers

Een modifier bewerkt de bytes van een segment voordat ze naar hun bestemming
gaan — bijvoorbeeld een cruncher. Kick Assembler levert er één mee:

```asm
        .file [name="test.prg", segments="Code"]
        .segment Code [start=$8000, modify="BasicUpstart", _start=$8000]
        inc $d020
        jmp *-3
```

Modifier-parameters beginnen per afspraak met `_`, zodat ze nooit botsen met
segment-parameters. Eigen modifiers schrijf je als Java-plugin.

### 9.8 `.segmentout`

`.segmentout` plakt de bytes van een segment in het huidige geheugenblok. Zo
verhuis je code naar een andere plek, bijvoorbeeld naar de zeropage:

```asm
        BasicUpstart2(start)
start:  sei
        ldx #0
loop:   lda zpCode,x
        sta zpStart,x
        inx
        cpx #zpCodeSize
        bne loop
        jmp zpStart

zpCode: .segmentout [segments="ZeroPage_Code"]
        .label zpCodeSize = *-zpCode

        .segment ZeroPage_Code [start=$10]
zpStart:
        inc $d020
        jmp *-3
```

Ook handig om meerdere banks in één binair bestand achter elkaar te zetten:

```asm
        .segment CARTRIDGE [outBin="cart.bin"]
        .segmentout [segments="BANK1"]
        .segmentout [segments="BANK2"]

        .segmentdef BANK1 [min=$1000, max=$1fff, fill]
        .segmentdef BANK2 [min=$1000, max=$1fff, fill]
```

Elke bank mag hetzelfde adresbereik gebruiken, omdat ze in aparte segments
staan.

---

## 10. Bestanden en d64-images

### 10.1 `.file`

```asm
        .file [name="demo.prg", segments="Code"]
        .file [name="demo.bin", type="bin", segments="Code,Data"]
        .file [name="Data.prg", mbfiles, segments="Data"]   // één bestand per blok
        .file [name="%o.prg", segments="Code"]              // %o = naam van de bron
```

`name` is verplicht. Alle segment-parameters uit §9.4 werken hier ook, want de
inhoud loopt via een impliciet tussensegment.

### 10.2 `.disk`

```asm
.disk [filename="MyDisk.d64", name="THE DISK", id="2021!"] {
        [name="----------------", type="rel"                              ],
        [name="BORDER COLORS   ", type="prg",  segments="BORDER_COLORS"    ],
        [name="BACK COLORS     ", type="prg<", segments="BACK_COLORS"      ],
        [name="HIDDEN          ", type="prg",  hide, segments="HIDDEN"     ],
        [name="MUSIC           ", type="prg",  sidFiles="data/music.sid"   ],
        [name="FROM DISK       ", type="prg",  prgFiles="data/extra.prg"   ],
}
```

Disk-parameters: `filename`, `name`, `id`, `format` (`commodore`, `speeddos`,
`dolphindos`), `interleave`, `showInfo`, `storeFilesInDir`,
`dontSplitFilesOverDir`.

Bestandsparameters: `name`, `type` (`del`, `seq`, `prg`, `usr`, `rel`; met een
`<` erachter is het bestand gelockt), `hide`, `interleave`, `noStartAddr`, plus
alle segment-parameters.

Een `rel`-regel met streepjes is de klassieke truc om een scheidingslijn in de
directory te tekenen. `hide` houdt een bestand uit de directory; met `showInfo`
op de disk krijg je track en sector te zien.

---

## 11. Import en export

### 11.1 Commandline-variabelen

```bash
java -jar KickAss.jar demo.asm :versie="beta2" :sound=true :x=27
```

```asm
        .print "versie=" + cmdLineVars.get("versie")
        .var x = cmdLineVars.get("x").asNumber()
        .var sound = cmdLineVars.get("sound").asBoolean()
        .if (sound) jsr $1000
```

### 11.2 Binaire bestanden inlezen

`LoadBinary` laadt een bestand in een waarde die je kunt uitlezen:

```asm
        .var data = LoadBinary("myDataFile")
myData: .fill data.getSize(), data.get(i)
```

`get(i)` levert een **signed** byte zoals Java die kent, dus `$ff` wordt `-1`.
Dat is prima om bytes weg te schrijven, maar niet om mee te rekenen. Gebruik
dan `uget(i)`, die 255 teruggeeft.

Met een template geef je de blokken in het bestand een naam. Je krijgt dan per
blok een `getNaam(i)` en `getNaamSize()`:

```asm
        .var tmpl = "Xcoord=0, Ycoord=$100, BounceData=$200"
        .var f = LoadBinary("moveData", tmpl)
Xcoord: .fill f.getXCoordSize(),     f.getXCoord(i)
Ycoord: .fill f.getYCoordSize(),     f.getYCoord(i)
Bounce: .fill f.getBounceDataSize(), f.getBounceData(i)
```

De tag `C64FILE` in de template laat de eerste twee bytes (het laadadres)
overslaan. Ingebouwde constanten:

| Constante | Blokken |
|---|---|
| `BF_C64FILE` | — (slaat alleen de adresbytes over) |
| `BF_BITMAP_SINGLECOLOR` | ScreenRam, Bitmap |
| `BF_KOALA` | Bitmap, ScreenRam, ColorRam, BackgroundColor |
| `BF_FLI` | ColorRam, ScreenRam, Bitmap |
| `BF_DOODLE` | ColorRam, Bitmap |

```asm
        .var fli = LoadBinary("GreatPicture", BF_FLI)
        .print "Koala-indeling = " + BF_KOALA    // toont de template
```

### 11.3 SID-bestanden

`LoadSid` leest een HVSC-sidbestand en geeft je init-adres, play-adres,
laadadres en de data:

```asm
        .var music = LoadSid("Tel_Jeroen/Closing_In.sid")

        lda #music.startSong-1
        jsr music.init
        ...
        jsr music.play
        ...
        *=music.location "Music"
        .fill music.size, music.getData(i)
```

Velden: `header version location init play songs startSong name author
copyright speed flags startpage pagelength size getData(n)`.

Zet je HVSC-map in `-libdir`, dan kun je met korte paden werken.

Print de gegevens tijdens het assembleren, dat scheelt zoeken:

```asm
        .print "location = $" + toHexString(music.location, 4)
        .print "init     = $" + toHexString(music.init, 4)
        .print "play     = $" + toHexString(music.play, 4)
        .print "name     = " + music.name
        .print "author   = " + music.author
```

### 11.4 Graphics converteren

`LoadPicture` leest een gif of jpg. Met een kleurtabel bepaal je welke RGB-kleur
op welk bitpatroon wordt afgebeeld:

```asm
        // Enkelkleurige charset van 32x8 tekens
        .var logo = LoadPicture("CML_32x8.gif")
        *=$3800
        .fill $800, logo.getSinglecolorByte((i>>3)&$1f, (i&7) | (i>>8)<<3)

        // Multicolor, met expliciete kleurtoewijzing
        .var mc = LoadPicture("blob_16x16.gif",
                              List().add($444444, $6c6c6c, $959595, $000000))
        *=$4000
        .fill $800, mc.getMulticolorByte(i>>7, i&$7f)
```

De vier RGB-waarden in de lijst horen bij de bitparen `%00`, `%01`, `%10` en
`%11`. Geef je geen lijst, dan kiest de assembler zelf — doe dat niet, want dan
is de toewijzing onvoorspelbaar.

| Functie | Werking |
|---|---|
| `width` / `height` | afmetingen in pixels |
| `getPixel(x,y)` | RGB-waarde van een pixel |
| `getSinglecolorByte(x,y)` | 8 pixels naar één byte; `x` in bytes, `y` in pixels |
| `getMulticolorByte(x,y)` | 4 pixels naar één byte; halve horizontale resolutie |

### 11.5 Eigen bestanden schrijven

```asm
        .var brk = createFile("breakpoints.txt")
.macro breakHere() {
        .eval brk.writeln("break " + toHexString(*))
}
```

Dit vereist de `-afo` optie, anders blokkeert de assembler het schrijven.
Start VICE daarna met `-moncommands breakpoints.txt`. In de praktijk is de
ingebouwde `.break`-directive (§4.7) hiervoor handiger.

### 11.6 Labels exporteren

```bash
java -jar KickAss.jar deel1.asm -symbolfile      # maakt deel1.sym
java -jar KickAss.jar demo.asm  -vicesymbols     # maakt demo.vs voor VICE
```

Het `.sym`-bestand bevat een namespace met alle labels en kun je in een ander
bronbestand inlezen:

```asm
        .import source "deel1.sym"
        jsr deel1.clearColor
```

---

## 12. Nuttige ingebouwde zaken

### 12.1 Bronbestandsnaam

```asm
        .print "Pad      : " + getPath()
        .print "Bestand  : " + getFilename()
```

### 12.2 BASIC-upstart

```asm
        *=$0801 "Basic Upstart"
        BasicUpstart(start)         // 10 sys $0810
        *=$0810 "Program"
start:  inc $d020
        jmp start
```

`BasicUpstart2` doet hetzelfde én zet meteen het geheugenblok op:

```asm
        BasicUpstart2(start)
start:  inc $d020
        jmp start
```

Het verschil is belangrijk: bij `BasicUpstart` zet je zelf `*=$0801` ervóór
en `*=$0810` erna; `BasicUpstart2` doet dat allebei zelf. Een bestand dat met
`BasicUpstart2(start)` begint heeft dus **geen** eigen `*=` nodig.

Gebruik `BasicUpstart2` tenzij je expliciete controle over de blokken wilt.
Combineer met `-execute` en je programma start meteen in VICE.

### 12.3 Opcode-constanten

Voor zelfmodificerende code en speedcode:

```asm
        lda #RTS
        sta target

        .var rtsSize = asmCommandSize(RTS)          // 1
        .var ldaImm  = asmCommandSize(LDA_IMM)      // 2
        .var ldaAbs  = asmCommandSize(LDA_ABS)      // 3
```

De constante is het mnemonic in hoofdletters plus het modus-achtervoegsel:
`IMM ZP ZPX ZPY IZPX IZPY ABS ABSX ABSY IND REL`, of niets voor
argumentloze instructies.

### 12.4 Kleurconstanten

`BLACK WHITE RED CYAN PURPLE GREEN BLUE YELLOW ORANGE BROWN LIGHT_RED
DARK_GRAY GRAY LIGHT_GREEN LIGHT_BLUE LIGHT_GRAY` (0 t/m 15). De grijstinten
mogen ook met `GREY`.

```asm
        lda #BLACK
        sta $d020
        lda #LIGHT_BLUE
        sta $d021
```

### 12.5 3D-berekeningen

`Vector(x,y,z)` en `Matrix()` met `RotationMatrix(aX,aY,aZ)`,
`ScaleMatrix(sX,sY,sZ)`, `MoveMatrix(mX,mY,mZ)` en
`PerspectiveMatrix(zProj)`. Matrixen combineer je door ze te vermenigvuldigen;
de transformatie leest van rechts naar links.

```asm
        .var m = ScaleMatrix(120,120,0) *
                 PerspectiveMatrix(2.5) *
                 MoveMatrix(0,0,7.5) *
                 RotationMatrix(aX,aY,aZ)
        .var v = m * Vector(1,1,1)
```

Hiermee reken je vectorobjecten vooraf uit in plaats van op de C64.

---

## 13. C64-recepten

Alle code hieronder is door `c64_ka_syntax_checker.py` gehaald.

### 13.1 Raster-IRQ via de kernal-vector

De eenvoudigste vorm. De kernal blijft actief, dus toetsenbord en klok blijven
werken. Sluit af met `jmp $ea31`.

```asm
.const VIC = $d000

        *=$0810
start:  sei
        lda #$7f
        sta $dc0d           // CIA-interrupts uit
        sta $dd0d
        lda $dc0d           // openstaande interrupts bevestigen
        lda $dd0d
        lda #<irq
        sta $0314
        lda #>irq
        sta $0315
        lda #$01
        sta VIC+$1a         // raster-interrupt aan
        lda #$32
        sta VIC+$12         // rasterregel
        lda VIC+$11
        and #$7f
        sta VIC+$11         // bit 8 van de rasterregel op 0
        asl VIC+$19         // openstaande raster-IRQ bevestigen
        cli
        jmp *

irq:    asl VIC+$19         // ALTIJD als eerste: bevestigen
        inc VIC+$20
        // ... werk ...
        dec VIC+$20
        jmp $ea31           // door naar de kernal-afhandeling
```

Vergeet het bevestigen niet — zonder dat vuurt de interrupt meteen weer en
hangt de machine. Twee gangbare vormen, beide goed:

```asm
        asl $d019           // kort
        inc $d019           // idem, ook gangbaar
        lda #$ff            // expliciet, wist alle interruptbronnen
        sta $d019
```

**Twee kernal-uitgangen, kies bewust:**

| Uitgang | Doet | Wanneer |
|---|---|---|
| `jmp $ea31` | volledige kernal-afhandeling: toetsenbord scannen, `TI` bijwerken, cursor knipperen | één interrupt per frame die de kernal-diensten nodig heeft |
| `jmp $ea81` | alleen registers herstellen en `rti` | rastersplits en extra interrupts binnen hetzelfde frame |

Bij meerdere splits per frame laat je precies één interrupt via `$ea31` gaan en
de rest via `$ea81`. Anders scan je het toetsenbord meerdere keren per frame,
wat rastertijd kost en de timing verstoort.

### 13.2 Volledige overname (kernal uit)

Meer cycli beschikbaar, maar je moet de registers zelf bewaren en `rti`
gebruiken.

```asm
        *=$0810
start:  sei
        lda #$35
        sta $01             // BASIC en KERNAL ROM eruit, I/O erin
        lda #$7f
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d
        lda #<irq
        sta $fffe
        lda #>irq
        sta $ffff
        lda #$01
        sta $d01a
        lda #$32
        sta $d012
        lda $d011
        and #$7f
        sta $d011
        asl $d019
        cli
        jmp *

irq:    pha
        txa
        pha
        tya
        pha
        asl $d019
        inc $d020
        dec $d020
        pla
        tay
        pla
        tax
        pla
        rti
```

**Stabiele raster:** met bovenstaande opzet heb je nog enkele cycli jitter,
genoeg voor kleurbalken maar niet voor FLI of sprite-stretching. De klassieke
oplossing is een dubbele IRQ: de eerste zet een tweede IRQ één rasterregel
later op, doet `inc $d012`, bevestigt, en valt via `cli` in een reeks `nop`s;
de tweede IRQ komt dan op een vaste cyclus binnen. Het aantal `nop`s is
afhankelijk van je code en **moet je in VICE uitmeten** — neem geen aantal uit
een voorbeeld over zonder te controleren.

### 13.3 Sprites

Eén sprite is 24x21 pixels = 63 bytes in een blok van 64. De pointerwaarde is
`adres/64`; de pointers staan op schermbasis + 1016, standaard `$07f8`.

```asm
.const VIC      = $d000
.const SPRPTR   = $07f8
.const SPRDATA  = $3000

        *=$0810
init:   lda #%00000001
        sta VIC+$15         // sprite 0 aan
        lda #SPRDATA/64     // de assembler rekent de pointer uit
        sta SPRPTR
        lda #1
        sta VIC+$27         // kleur wit
        lda #0
        sta VIC+$17         // geen y-vergroting
        sta VIC+$1d         // geen x-vergroting
        sta VIC+$1c         // geen multicolor
        rts

        // x is 16 bits: de negende bit gaat naar $d010
move:   lda xpos
        sta VIC+0
        lda xpos+1
        beq !+
        lda VIC+$10
        ora #%00000001
        sta VIC+$10
        jmp !++
!:      lda VIC+$10
        and #%11111110
        sta VIC+$10
!:      lda ypos
        sta VIC+1
        rts

xpos:   .word 160
ypos:   .byte 120

        *=SPRDATA "Sprite data"
        .fill 63, i<3 ? $ff : 0
```

Vergeet de "uit"-tak bij `$d010` niet — zonder die tak blijft het sprite rechts
hangen zodra het één keer voorbij x=255 is geweest.

Sprite-data kun je ook uit een bestand of een plaatje halen:

```asm
        *=SPRDATA
        .import binary "sprites.bin"
```

Registers: `$d015` aan/uit, `$d010` x-bit-8, `$d017` y-vergroting,
`$d01b` prioriteit, `$d01c` multicolor, `$d01d` x-vergroting,
`$d01e`/`$d01f` botsing (**lezen wist ze**), `$d025`/`$d026` multicolor 1 en 2,
`$d027`..`$d02e` spritekleuren.

### 13.4 SID-muziek afspelen

```asm
.var music = LoadSid("Nightshift.sid")

        *=$0810
start:  lda #music.startSong-1
        jsr music.init
        sei
        lda #$7f
        sta $dc0d
        lda #<irq
        sta $0314
        lda #>irq
        sta $0315
        lda #$01
        sta $d01a
        lda #$32
        sta $d012
        asl $d019
        cli
        jmp *

irq:    asl $d019
        inc $d020           // rastertijd meten
        jsr music.play
        dec $d020
        jmp $ea31

        *=music.location "Music"
        .fill music.size, music.getData(i)
```

De randkleur rond `music.play` laat zien hoeveel rastertijd de speler kost —
de standaardmanier om te zien of je nog ruimte over hebt.

### 13.5 Bitmap uit een Koala-bestand

```asm
.var pic = LoadBinary("picture.prg", BF_KOALA)

        *=$0810
start:  lda #$38
        sta $d018           // bitmap op $2000, scherm op $0c00
        lda #$d8
        sta $d016           // multicolor aan
        lda #$3b
        sta $d011           // bitmapmodus aan
        lda #pic.getBackgroundColor()
        sta $d021
        ldx #0
!loop:  .for (var i=0; i<4; i++) {
            lda colorRam+i*$100,x
            sta $d800+i*$100,x
        }
        inx
        bne !loop-
        jmp *

        *=$0c00 "Screen"
        .fill pic.getScreenRamSize(), pic.getScreenRam(i)
        *=$1c00 "ColorRam"
colorRam:
        .fill pic.getColorRamSize(), pic.getColorRam(i)
        *=$2000 "Bitmap"
        .fill pic.getBitmapSize(), pic.getBitmap(i)
```

De kleur-RAM moet met een lus gekopieerd worden omdat `$d800` niet in het
prg-bestand kan staan. De `.for` erin wordt uitgerold, dus dit kost geen
lustelling.

### 13.6 Schermregeltabellen

Vermenigvuldigen met 40 is duur op een 6502. Laat de assembler de tabel maken:

```asm
        *=$0810
plot:   ldx #12             // rij
        ldy #20             // kolom
        lda rows.lo,x
        sta $fb
        lda rows.hi,x
        sta $fc
        lda #'*'
        sta ($fb),y
        lda crows.lo,x
        sta $fb
        lda crows.hi,x
        sta $fc
        lda #1
        sta ($fb),y
        rts

rows:   .lohifill 25, $0400 + i*40
crows:  .lohifill 25, $d800 + i*40
```

### 13.7 Sinustabellen en speedcode

```asm
sine:   .fill 256, round(127.5 + 127.5*sin(toRadians(i*360/256)))
cosine: .fill 256, round(127.5 + 127.5*cos(toRadians(i*360/256)))
```

Een uitgerolde kopieerlus (speedcode) maak je met `.for`:

```asm
copyScreen: {
        .for (var i=0; i<4; i++) {
            .for (var j=0; j<250; j++) {
                lda source + i*250 + j
                sta $0400  + i*250 + j
            }
        }
        rts
}
```

Dat is 1000 keer `lda`/`sta` zonder lusoverhead. Weeg geheugen tegen snelheid
af — dit kost ruim 6 KB.

### 13.8 IRQ-bouwstenen als pseudocommands

Dit is het idioom uit de officiële voorbeelden en het is beter dan de
IRQ-boilerplate met de hand overtypen. Je maakt twee pseudocommands, `irqStart`
en `irqEnd`, waarbij `irqEnd` optionele argumenten heeft: de volgende
rasterregel en het adres van de volgende interrupt.

```asm
#importonce

.pseudocommand irqStart {
        pha
        txa
        pha
        tya
        pha
        lda #$ff
        sta $d019
}

.pseudocommand irqEnd line : addr {
        .if (line.getType()!=AT_NONE) { lda line; sta $d012 }
        .if (addr.getType()!=AT_NONE) {
            lda #<addr.getValue()
            sta $fffe
            lda #>addr.getValue()
            sta $ffff
        }
        pla
        tay
        pla
        tax
        pla
        rti
}
```

De rastersplits worden dan bijna leesbaar:

```asm
irq1:   irqStart
        lda #DARK_GRAY
        sta $d020
        irqEnd #$32+25*8 : #irq2

irq2:   irqStart
        lda #GRAY
        sta $d020
        irqEnd #$32 : #irq1
```

De sleutel is `getType()!=AT_NONE`: een weggelaten argument komt binnen als
`AT_NONE`, en de `.if` laat de bijbehorende code dan gewoon weg. Zo kun je
`irqEnd #$d8` schrijven als de volgende interrupt dezelfde routine is, of zelfs
`irqEnd intD012,x` met een geïndexeerd argument — pseudocommands accepteren
alle adresseringsmodi.

### 13.9 Implementaties wisselen met de preprocessor

Dit is een inzicht dat je met `.if` niet kunt bereiken. Omdat de preprocessor
vóór alles draait, kun je er **definities** mee omschakelen: macro's, functies,
pseudocommands en imports. Een gewone `.if` kan dat niet, want die draait pas
tijdens de evaluatie.

```asm
#define IRQ_UNDER_ROM

#if !IRQ_UNDER_ROM
    // Kernal blijft actief: vector op $0314, afsluiten via $ea81
    .pseudocommand irqStart {
            lda #$ff
            sta $d019
    }
    .pseudocommand irqEnd line : addr {
            .if (line.getType()!=AT_NONE) { lda line; sta $d012 }
            .if (addr.getType()!=AT_NONE) {
                lda #<addr.getValue()
                sta $0314
                lda #>addr.getValue()
                sta $0315
            }
            jmp $ea81
    }
#else
    // Kernal uit: vector op $fffe, registers zelf bewaren, afsluiten met rti
    .pseudocommand irqStart {
            pha
            txa
            pha
            tya
            pha
            lda #$ff
            sta $d019
    }
    .pseudocommand irqEnd line : addr {
            .if (line.getType()!=AT_NONE) { lda line; sta $d012 }
            .if (addr.getType()!=AT_NONE) {
                lda #<addr.getValue()
                sta $fffe
                lda #>addr.getValue()
                sta $ffff
            }
            pla
            tay
            pla
            tax
            pla
            rti
    }
#endif
```

De rest van je programma verandert niet — `irq1: irqStart … irqEnd` blijft
hetzelfde. Eén `#define` schakelt de hele opzet om. Hetzelfde patroon gebruik je
voor een `STANDALONE`-schakelaar die de upstart-code alleen invoegt als het
onderdeel los moet draaien:

```asm
#if STANDALONE
        BasicUpstart2(start)
start:  sei
        ...
#endif
```

Let op dat de vertragingslussen mee moeten veranderen: onder ROM kost
`irqStart` meer cycli, dus is de `delay`-constante anders.

```asm
#if !IRQ_UNDER_ROM
        .const delay = 3
#else
        .const delay = 7
#endif
```

### 13.10 VIC-registerwaarden laten uitrekenen

Dit is de sterkste reden om Kick Assembler te gebruiken. Schrijf functies die
`$d018`, de VIC-bank en spritepointers uit **labeladressen** afleiden. Verplaats
je de graphics, dan volgen alle registers automatisch.

```asm
#importonce

.function screenToD018(addr)  { .return ((addr&$3fff)/$400)<<4 }
.function charsetToD018(addr) { .return ((addr&$3fff)/$800)<<1 }
.function bitmapToD018(addr)  { .return ((addr&$3fff)/$2000)<<3 }
.function toD018(screen, charset) {
        .return screenToD018(screen) | charsetToD018(charset)
}
.function toSpritePtr(addr) { .return (addr&$3fff)/$40 }
.function toVicBank(addr)   { .return 3 - (addr>>14) }

        *=$2000
start:  lda #toD018(screen, charset)
        sta $d018
        lda #toVicBank(screen)
        sta $dd00
        ldx #7
!:      lda spritePtrs,x
        sta screen+$3f8,x
        dex
        bpl !-
        rts

spritePtrs:
        .byte toSpritePtr(sprite1), toSpritePtr(sprite2)
        .byte 0,0,0,0,0,0

        .align $0800
charset:
        .fill $800, 0
        .align $40
sprite1:
        .fill 64, 0
sprite2:
        .fill 64, 0

        *=$3c00 "Scherm" virtual
screen: .fill $0400, 0
```

Drie dingen die hier samenkomen en die je moet overnemen:

- De `&$3fff` in elke functie rekent het adres om naar een offset binnen de
  VIC-bank; dat is precies wat `$d018` verwacht.
- `.align $0800` vóór de charset en `.align $40` vóór de sprites zorgen dat de
  adressen op de vereiste grens vallen. Zonder uitlijning klopt de
  pointerberekening niet en zie je rommel.
- Het scherm staat in een **virtueel** blok. Het beslaat wel adresruimte en
  levert een bruikbaar `screen`-label op, maar er gaan geen 1024 lege bytes mee
  het prg-bestand in.

### 13.11 Labels in geïmporteerde binaries

Een muziekroutine die je als `.bin` of `.c64` importeert heeft geen labels. Die
maak je zelf met `.label` op basis van `*`:

```asm
        *=$1000 "Music"
        .label music_init = *
        .label music_play = *+3
        .import binary "ode to 64.bin"
```

Vrijwel alle C64-spelers hebben een jump-tabel van drie bytes per ingang:
init op offset 0, play op offset 3. Voor een sid-bestand hoeft dit niet — daar
geven `music.init` en `music.play` je de adressen al (§11.3).

### 13.12 Multispeed-speler met berekende splittabellen

Een 8x-speler roept de muziek acht keer per frame aan, op acht rasterregels.
Laat de assembler de tabellen uitrekenen; PAL heeft 312 rasterregels:

```asm
.const xSpeed = 8

irq1:   ldx frameNo
        inx
        cpx #xSpeed
        bne !+
        ldx #0
!:      stx frameNo
        lda intPlay,x
        sta playJsr+1           // zelfmodificerende jsr
playJsr:
        jsr $1003
        ldx frameNo
        lda intD011,x
        sta $d011
        lda intD012,x
        sta $d012
        rts

frameNo:
        .byte 0
intPlay:
        .fill xSpeed, <($1003 + i*3)
intD012:
        .fill xSpeed, i*312/xSpeed
intD011:
        .fill xSpeed, $1b + (((i*312/xSpeed)&$100)>>1)
```

De `intD011`-tabel is het stukje dat mensen vergeten: rasterregels boven 255
hebben hun negende bit in **bit 7 van `$d011`**. De uitdrukking
`(((i*312/xSpeed)&$100)>>1)` haalt bit 8 van de rasterregel op en schuift hem
naar bit 7. Zonder die tabel springen je splits vanaf regel 256 naar de
verkeerde plek.

### 13.13 Data genereren tijdens het assembleren

De scripttaal is krachtig genoeg voor echte conversiealgoritmen. Een
Floyd-Steinberg-dithering die een jpg naar een hires-bitmap omzet, past in één
`.function` die een `List` teruggeeft:

```asm
        *=$2000 "Picture"
        .var pic = floydSteinberg("camel.jpg")
        .fill 40*200, pic.get(i)
```

De functie leest de pixels met `picture.getPixel(x,y)`, berekent per pixel een
intensiteit, verspreidt de afrondingsfout over de buren (7/16 rechts, 3/16
linksonder, 5/16 onder, 1/16 rechtsonder) en zet het resultaat om naar bytes in
C64-charvolgorde.

Twee praktische punten: zet zulke lussen altijd in een `.function` of een
`.define`-blok, want daar draait de code in function mode en worden geen
tussenresultaten per pass bewaard. En houd er rekening mee dat een
intensiteitskaart van 320x200 met randkolom een lijst van ruim 64.000 elementen
is — dat kost assembleertijd.

Voor een hires-bitmap zet je de voor- en achtergrondkleur samen in één
schermbyte:

```asm
        lda #BLACK | (WHITE<<4)     // hoge nibble = voorgrond, lage = achtergrond
        ldx #0
loop:   sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $0700,x
        inx
        bne loop
```

En het scherm wissen kan met de kernal, zolang die nog gemapt is:

```asm
        jsr $e544                   // kernal: scherm wissen
```
### 13.14 Modules als labelscope

Naast `.filenamespace` (§8.1) bestaat een tweede modulestijl die in de praktijk
vaak prettiger werkt: zet de hele module in een labelscope. De modulenaam staat
dan op de aanroepplek, wat de code leesbaarder maakt.

```asm
#importonce

Joystick: {
        .segment ZP
tmp:    .byte 0

        .segment CODE
        .label UP    = 0
        .label DOWN  = 1
        .label LEFT  = 2
        .label RIGHT = 3
        .label FIRE  = 4

Reset:  {
        ldx #0
        lda #$ff
!:      sta data,x
        inx
        cpx #8
        bne !-
        rts
}

Poll:   {
        lda $dc00           // poort 2
        lsr                 // schuif elk richtingsbit
        ror data+UP         // in een eigen historie-byte
        lsr
        ror data+DOWN
        lsr
        ror data+LEFT
        lsr
        ror data+RIGHT
        lsr
        ror data+FIRE
        rts
}

Held:   {
        lda data,x          // x = UP..FIRE
        and #1
        rts                 // 0 = nu ingedrukt
}

data:   .fill 8, 0
}
```

Van buiten roep je aan met `jsr Joystick.Poll`, `ldx #Joystick.FIRE` en
`lda Joystick.data+Joystick.UP`. Scopes mogen genest worden, dus je kunt ook
bij een label binnen een subroutine: `TaskOS.Step.CurrentTask`.

Wanneer welke stijl:

| | Labelscope `Module: { }` | `.filenamespace` |
|---|---|---|
| Aanroep | `jsr Joystick.Poll` | `jsr Poll` |
| Zichtbaarheid | expliciet, je ziet waar het vandaan komt | korter, maar de herkomst is onzichtbaar |
| Meerdere modules per bestand | ja | nee, één per bestand |
| Geschikt voor | herbruikbare modules met een publieke API | een programmadeel dat één geheel is |

De `Poll`-routine hierboven is het schuifregister-idioom van codebase64: elke
`lsr` schuift het volgende poortbit in de carry, en `ror data+RICHTING` schuift
dat de historie-byte in. Zo houd je per richting acht ticks geschiedenis in één
byte. Bit 0 is de huidige stand, bit 1 de vorige.

Daarmee detecteer je een *nieuwe* druk in vier instructies, met `bit`:

```asm
Pressed: {
        lda data,x
        sta tmp
        lda #%11111111
        bit tmp             // bit 7 -> N, bit 6 -> V
        bmi no
        bvc no
        lda #$00            // net ingedrukt
        rts
no:     lda #$01
        rts
}
```

`bit` kopieert bit 7 van de operand naar de N-vlag en bit 6 naar de V-vlag,
zonder de accumulator aan te raken. Dat is de goedkoopste manier om twee bits
tegelijk te testen.

### 13.15 Zeropage-variabelen naast de code

Dit is het belangrijkste segment-patroon dat je kunt overnemen. Definieer een
`ZP`-segment en **neem het niet op in `.file`**. Dan declareer je
zeropage-variabelen precies bij de code die ze gebruikt, terwijl ze nooit in
het prg-bestand belanden.

```asm
        .file [name="demo.prg", segments="CODE,DATA"]   // ZP staat er niet bij

        .segment ZP     [start=$02]
        .segment CODE   [start=$0801]
        .segment DATA   [startAfter="CODE"]
        .segment TABLES [startAfter="DATA", virtual, align=256]

        .segment CODE
        BasicUpstart2(Start)
Start:  {
        sei
        jsr Player.Init
        jmp *
}

Player: {
        .segment ZP
xpos:   .byte 0             // komt op $02, niet in het bestand
ypos:   .byte 0

        .segment TABLES
history: .fill 256, 0       // pagina-uitgelijnd, kost geen bestandsruimte

        .segment CODE
Init:   {
        lda #160
        sta xpos
        lda #120
        sta ypos
        rts
}

        .segment DATA
name:   .text "player"
        .byte 0
}
```

Wat hier gebeurt en waarom het goed is:

- Elke module claimt zijn eigen zeropage-bytes bij zijn eigen code. Je hoeft
  geen centrale lijst met zeropage-adressen bij te houden en handmatig te
  verdelen — de assembler stapelt ze achter elkaar vanaf `$02`.
- `ZP` staat niet in `.file`, dus de bytes verdwijnen. Precies wat je wilt:
  zeropage-variabelen hebben geen beginwaarde nodig.
- `TABLES` is `virtual` én `align=256`. Tabellen die je toch bij het opstarten
  vult, kosten zo geen bestandsruimte en beginnen op een paginagrens, wat een
  cyclus per geïndexeerde toegang scheelt.

**Twee valkuilen.** Declareer een zeropage-variabele altijd *vóór* je hem
gebruikt. Bij een vooruitverwijzing gokt de assembler in de eerste pass op een
tweebyte-adres en blijft daarbij, ook als later blijkt dat het adres in de
zeropage ligt (§3.5). Kan dat niet, gebruik dan `.zp { }` of forceer per
instructie met `<`:

```asm
        inc <apl_srcptr+1   // '<' levert de lage byte, dus altijd zeropage
```

En: `.segment ZP [start=$02]` bijt met alles wat de kernal of BASIC in de
zeropage gebruikt. Vanaf `$02` is veilig zolang je met `sei` en zonder BASIC
draait; heb je de kernal nodig, gebruik dan de vrije gaten (`$fb`–`$fe`, `$02`)
of zet `start` hoger.

### 13.16 PAL of NTSC detecteren

PAL heeft 312 rasterregels, NTSC 263. Wacht tot de rasterteller omslaat en lees
de hoogste waarde: de onderste twee bits zijn `%11` op PAL.

```asm
#importonce
SystemType: {
        lda #$00
        sta isNTSC
w0:     lda $d012
w1:     cmp $d012
        beq w1              // wacht tot de teller verandert
        bmi w0              // pas op de omslag hebben we het maximum
        and #$03
        cmp #$03
        beq notNTSC
        inc isNTSC
notNTSC:
        .label isNTSC = *+1
        lda #$00            // deze operandbyte ís de variabele
        rts
}
```

Let op het slot: `.label isNTSC = *+1` wijst naar de operandbyte van de
`lda #$00` die er direct onder staat. De routine schrijft er zelf naartoe en
leest hem in dezelfde instructie weer uit. Dat scheelt een zeropage-byte en een
losse `lda`. Van buiten lees je `lda SystemType.isNTSC`.

Dit idioom — een variabele die in een instructie-operand woont — is de reden
dat `.label x = *+1` zo vaak voorkomt in C64-code. Gebruik het voor waarden die
bij één routine horen en zelden veranderen.

Wil je dezelfde spellogica op beide systemen, sla dan op NTSC periodiek een
frame over zodat je op 50 Hz uitkomt:

```asm
        lda #$04
        sta maxframes       // PAL: elke frame
        lda SystemType.isNTSC
        beq notNTSC
        lda #$05            // NTSC: 1 van de 6 frames overslaan
        sta maxframes
notNTSC:
```

### 13.17 Bewust doorvallen tussen scopes

Een `{}`-scope produceert zelf geen bytes. Twee opeenvolgende scopes liggen dus
direct achter elkaar in het geheugen, en je kunt van de ene in de andere vallen.
Dat scheelt een `jmp` of een gedupliceerde routine:

```asm
RND8Seed: {
        sta seed            // geen rts - valt bewust door
}
RND8: {
        lda seed
        beq doEor
        asl
        beq noEor
        bcc noEor
doEor:  eor #$c3
noEor:  sta seed
        rts
}
```

`jsr RND8Seed` zet de seed én levert meteen het eerste getal. Zet er altijd
een commentaarregel bij, anders leest het als een vergeten `rts`.
### 13.18 Kernal- en BASIC-routines aanroepen

Zolang de ROM's gemapt zijn (`$01` op de standaardwaarde `$37`) kun je een
hoop werk uitbesteden. De vier die je het vaakst nodig hebt:

| Adres | Routine | Aanroep |
|---|---|---|
| `$e544` | scherm wissen, cursor linksboven | `jsr $e544` |
| `$ab1e` | BASIC STROUT: print een nul-afgesloten string | A = lage byte, Y = hoge byte van het adres |
| `$fff0` | kernal PLOT: cursorpositie zetten of lezen | X = rij, Y = kolom, `clc` = zetten, `sec` = lezen |
| `$ffd2` | kernal CHROUT: print één teken | A = PETSCII-code |

```asm
        jsr $e544                   // scherm wissen
        lda #<tekst
        ldy #>tekst
        jsr $ab1e                   // print de string vanaf de cursor
        rts

tekst:  .text @"hallo wereld\$00"   // \$00 sluit de string af
```

Cursorpositie zetten kan ook rechtstreeks: adres `211` is de kolom, `214` de
rij.

**Let op de encoding.** Deze routines verwachten **PETSCII**, terwijl direct
naar het schermgeheugen schrijven **schermcodes** vraagt (§5.1 van het
BASIC-document legt het verschil uit). Zet `.encoding` dus per uitvoermethode:

```asm
.encoding "petscii_mixed"
kernalTekst:  .text @"via de kernal\$00"

.encoding "screencode_mixed"
schermTekst:  .text "direct naar het scherm"
              .byte 0
```

Vertrouw er niet op dat één encoding voor beide werkt. Voor sommige tekens
vallen de tabellen toevallig samen, waardoor code lijkt te werken tot je een
leesteken of hoofdletter toevoegt.

### 13.19 Parameters doorgeven aan subroutines

De 6502 heeft geen aanroepconventie. Kies bewust; elke methode heeft zijn
plek. Vijf werkwijzen, van simpel naar flexibel:

| Methode | Werking | Voordeel | Nadeel |
|---|---|---|---|
| **Constanten**
- [ ] Elk verband tussen twee constanten is vastgelegd met `.errorif`, niet
      alleen in een commentaarregel (§20.13).
- [ ] Geen enkel statement loopt over meer dan een regel (§20.14).

**Registers** | A, X en Y als parameters | snelst, geen geheugen nodig | maximaal drie bytes |
| **Vast blok** | de routine bezit een blok bytes dat de aanroeper vult | onbeperkt aantal parameters, simpel | één blok voor alle aanroepers, dus niet herintreedbaar |
| **Zelfmodificatie** | de aanroeper schrijft in de operandbytes van de routine | snel bij uitvoering, waarden blijven staan | breekt zodra je de routine bewerkt; nooit in ROM |
| **Blok van de aanroeper** | de aanroeper maakt zijn eigen blok en geeft het adres mee | meerdere blokken naast elkaar, meest flexibel | kost een zeropage-pointer en indirecte toegang |
| **Stack** | parameters vóór de `jsr` op de stack duwen | registers blijven vrij, onbeperkt aantal | stack is 256 bytes; het retouradres moet je zelf beheren |

De eerste vier spreken voor zich. De stackmethode heeft een addertje dat je
moet kennen: `jsr` duwt het retouradres **min één** op de stack, ín boven jouw
parameters. Je moet het er dus eerst afhalen en later terugzetten:

```asm
PrintStack: {
        pla                 // retouradres eraf halen
        sta rts_lo          // (dit is het adres min 1)
        pla
        sta rts_hi

        pla                 // nu pas bij de parameters
        tay
        pla
        sta $0400,y

        lda rts_hi          // retouradres weer terugzetten
        pha                 // hoge byte eerst
        lda rts_lo
        pha
        rts                 // rts telt er zelf weer 1 bij op
rts_lo: .byte 0
rts_hi: .byte 0
}
```

Doe je het andersom en spring je zelf terug met `jmp`, dan moet je het adres
**wel** met één ophogen, want `rts` doet dat normaal voor je. En je hebt dan
een indirecte sprong nodig:

```asm
        inc rts_lo
        bne !+
        inc rts_hi
!:      jmp (rts_lo)        // indirect! 'jmp rts_lo' springt de data in
```

Dat laatste is een klassieke valkuil: `jmp rts_lo` springt naar het *adres van
de variabele* en voert de opgeslagen bytes uit als instructies. De haakjes
maken het verschil. De syntax checker waarschuwt hierop.

Vuistregel: registers voor één of twee bytes, een blok van de aanroeper voor
alles wat herintreedbaar of herbruikbaar moet zijn, en de stack alleen als je
echt registers vrij moet houden.

### 13.20 Sprite-metadata in byte 63

Sprite-editors zoals spritemate schrijven 64 bytes per sprite weg: 63 bytes
pixeldata plus een extra byte met de eigenschappen van het sprite. De lage
nibble is de kleur, de hoge nibble is gezet bij een multicolor-sprite.

Daarmee draagt de spritedata zijn eigen instellingen, en hoef je ze niet
apart bij te houden:

```asm
.const VIC = $d000

setup:  lda #$f0
        bit sprite+63       // hoge nibble gezet?
        beq single          // nee -> enkelkleurig
        lda VIC+$1c
        ora #$01            // multicolor aan voor sprite 0
        sta VIC+$1c
single: lda sprite+63       // hele byte schrijven mag; alleen bits 0-3 tellen
        sta VIC+$27         // kleur van sprite 0
        lda #sprite/64
        sta $07f8
        lda VIC+$15
        ora #$01
        sta VIC+$15
        rts

        .align $40
sprite: .fill 63, 0
        .byte $84           // multicolor, kleur 4
```

`bit` test hier de hoge nibble zonder de accumulator te verstoren, precies
zoals bij de joystick in §13.14.

### 13.21 De BASIC-opstartregel met de hand

`BasicUpstart2` (§12.2) is bijna altijd de juiste keuze. Wil je toch precies
weten wat er gebeurt, of heb je een afwijkende regel nodig, dan zijn dit de
bytes van `10 SYS (4096)`:

```asm
        *=$0801 "Basic"
        .byte $0e, $08              // adres van de volgende BASIC-regel
        .byte $0a, $00              // regelnummer 10
        .byte $9e                   // token voor SYS
        .byte $20, $28, $34, $30, $39, $36, $29   // " (4096)"
        .byte $00                   // einde van deze regel
        .byte $00, $00              // einde van het programma
```

Twee dingen die vaak fout gaan:

- **BASIC-tekst begint op `$0801`, en `$0800` moet nul zijn.** Begin je met
  `*=$0800`, zet er dan een `.byte $00` vóór. Begin je met `*=$0801`, dan laat
  je die weg — het geheugen op `$0800` is bij een verse machine al nul, maar
  dat geldt niet na een eerder programma.
- **De doorverwijzing `$080e` moet kloppen met waar de regel eindigt.** Verander
  je het SYS-adres in een langer getal, dan verschuift die waarde mee. Dit is
  precies het soort rekenwerk dat `BasicUpstart2` je uit handen neemt.

Het sprongadres `4096` is `$1000`; wil je ergens anders starten, pas dan de
ASCII-cijfers aan. Ook dat is een reden om gewoon de macro te gebruiken.
---

## 14. Koppeling met de BASIC-pipeline

`C64_BASIC_SKILL.md` §11 zegt: voor raster-, muziek- en scrollcode moet je naar
6502 machinetaal. Kick Assembler is het gereedschap daarvoor. Zo passen de twee
in elkaar.

### 14.1 Wanneer wat

| Situatie | Gereedschap |
|---|---|
| Menu's, invoer, spellogica zonder timing-eisen | BASIC V2 |
| Rasterinterrupts, sprite-multiplexing, scrolling, muziek onder een spel | Kick Assembler |
| BASIC-programma dat een machinetaalroutine aanroept | beide |
| Zelfstandig demo of spel | Kick Assembler |

### 14.2 Een BASIC-programma met een machinetaalroutine

De routine assembleer je apart naar een vast adres, bijvoorbeeld `$c000`
(49152), en laadt hem vóór het BASIC-programma:

```asm
        *=$c000 "Routine"
        // wordt aangeroepen met sys 49152
        inc $d020
        rts
```

```basic
10 rem laad de routine eerst: load "routine",8,1
20 sys 49152
30 end
```

Wil je één bestand, laat Kick Assembler dan zowel de BASIC-regel als de code
maken met `BasicUpstart2` — dan hoef je `bas2prg.py` niet te gebruiken.

### 14.3 Twee tokenizers, twee conventies

Let op dit verschil, het is een bron van verwarring:

| | BASIC-pipeline (`bas2prg.py`) | Kick Assembler |
|---|---|---|
| Broncode | kleine letters | vrije keuze, hoofdletters gebruikelijk |
| Case-omzetting | verplicht `invert_case=True` | niet van toepassing |
| Commentaar | `rem` | `//` en `/* */` |
| Statement-scheider | `:` | `;` |
| Uitvoer | tokenized BASIC PRG | machinecode PRG |
| Regellengte | max 80 tekens | geen beperking |

Ga niet zoeken naar een `invert_case`-equivalent in Kick Assembler; dat bestaat
niet en is ook niet nodig. Wat wél overeenkomt is de encoding-keuze in §4.3:
`screencode_*` voor `sta $0400,x`, `petscii_*` voor `jsr $ffd2`.

---

## 15. Veelgemaakte fouten

| Fout | Waarom het misgaat | Goed |
|---|---|---|
| `lda #0 ; rand zwart` | `;` scheidt statements; `rand` wordt als commando gelezen | `lda #0 // rand zwart` |
| `lda (2+5)*2` | leidende `(` betekent indirect | `lda #[2+5]*2` |
| `sta #$10` | `sta` kent geen immediate | `lda #$10` … `sta adres` |
| `ldx $10,x` | `ldx` kent alleen `,y` | `ldx $10,y` |
| `lda ($10),x` | bestaat niet | `lda ($10,x)` of `lda ($10),y` |
| `lda #$100` | past niet in een byte | `lda #<$100` / `lda #>$100` |
| `bra loop` op een C64 | `bra` is 65c02/DTV | `jmp loop` of `beq`/`bne` |
| IRQ zonder `asl $d019` | interrupt blijft vuren, machine hangt | eerste regel van de IRQ |
| `$fffe`-IRQ zonder registers te bewaren | A/X/Y worden gesloopt | `pha/txa/pha/tya/pha` … `pla/tay/pla/tax/pla/rti` |
| `$d010` alleen op 1 gezet | sprite blijft rechts hangen | ook de "uit"-tak schrijven |
| `peek`/`poke` van `$d01e` twee keer per frame | lezen wist het register | één keer lezen in een variabele |
| `.eval x=1` zonder `.var x` | variabele niet gedeclareerd | `.var x=1` |
| `.const X=1` … `.eval X=2` | constanten zijn onveranderlijk | gebruik `.var` |
| Lijst in een latere pass gebruikt | mutabele waarde niet gelockt | `.lock()` of `.define`-blok |
| `.import source "lib.asm"` | verouderd, verwarrende volgorde | `#import "lib.asm"` |
| Bibliotheek twee keer ingelezen | dubbele definities | `#importonce` bovenaan |
| Zeropage-label pas later gedefinieerd | assembler kiest absolute vorm | `.zp { ... }` |
| Tabel over een pagina-grens | kost een extra cyclus per toegang | `.align $100` |
| `.for` met heavy math buiten een `.define` | traag en geheugenvretend | zet de lus in `.define` of een `.function` |
| `$fffe`-IRQ die eindigt op `jmp $ea31` | kernal is uitgeschakeld, dat adres bestaat niet meer | `rti` na de registers hersteld te hebben |
| Elke split via `jmp $ea31` | toetsenbord wordt meermaals per frame gescand | één split via `$ea31`, de rest via `$ea81` |
| Rastersplit boven regel 255 zonder `$d011` bit 7 | de negende bit van de rasterregel ontbreekt | zet bit 7 van `$d011` mee, zie §13.12 |
| `$d018` met de hand uitgerekend | breekt zodra je de graphics verplaatst | reken hem uit met `toD018()`, zie §13.10 |
| Charset of sprites zonder `.align` | pointerberekening klopt niet, je ziet rommel | `.align $0800` / `.align $40` |
| `*=$0801` vóór `BasicUpstart2` | v2 zet het blok al zelf op | alleen `BasicUpstart` (v1) heeft dat nodig |
| Macro's omschakelen met `.if` | `.if` draait pas bij evaluatie | gebruik `#if`, zie §13.9 |
| `.encoding` binnen een blok | geldt globaal, kleurt latere tekstdata mee | bovenaan zetten of erna herstellen |
| Zeropage-variabele na gebruik gedeclareerd | assembler koos in pass 1 al de absolute vorm | vóór gebruik declareren, `.zp { }`, of `<label` |
| Zeropage-segment mee in `.file` | lege bytes belanden in het prg | laat `ZP` uit de segmentlijst |
| Segmentnaam met een typefout | de assembler maakt stil een nieuw, leeg segment en je code verdwijnt | controleer de geheugenkaart met `-showmem` |
| `.import binary` zonder bestandsnaam | placeholder die niet assembleert | echte bestandsnaam tussen quotes |
| `jmp ptr` waar `ptr` data is | springt de datatabel in en voert die uit | `jmp (ptr)` voor een indirecte sprong |
| Stackparameters zonder het retouradres te bewaren | `jsr` legt het retouradres bóven je parameters | eerst afhalen, later terugzetten (§13.19) |
| Kernal-routine gevoed met schermcodes | `$ab1e` en `$ffd2` verwachten PETSCII | `.encoding "petscii_mixed"` voor die strings |
| `*=$0800` zonder `.byte $00` ervoor | BASIC-tekst begint op `$0801`, `$0800` moet nul zijn | `*=$0801`, of gebruik `BasicUpstart2` |

---

## 16. Verificatiechecklist

**Syntax**
- [ ] Alle commentaar met `//` of `/* */`, nergens `;` als commentaar.
- [ ] Groeperen met `[]`, `()` alleen voor indirecte adressering.
- [ ] Geen mnemonic uit een andere cpu dan de ingestelde `.cpu`.
- [ ] Alle adresseringsmodi bestaan voor het gebruikte mnemonic.
- [ ] Immediate waarden passen in een byte.
- [ ] Alle haakjes en accolades in balans; alle `#if` afgesloten met `#endif`.

**Structuur**
- [ ] Bestand begint met `*=` of definieert een segment.
- [ ] Bibliotheekbestanden beginnen met `#importonce` en een `.filenamespace`.
- [ ] `#import` gebruikt, niet `.import source`.
- [ ] Subroutines in een `{}`-scope zodat interne labels lokaal blijven.
- [ ] Labels die van buiten nodig zijn via een labelscope of `.label`.
- [ ] Elke `.function` heeft een `.return`.
- [ ] Macro-aanroepen met het juiste aantal argumenten.

**Script**
- [ ] Elke `.eval`-variabele is eerder met `.var` gedeclareerd.
- [ ] Mutabele waarden (`List`, `Hashtable`) gelockt of in een `.define`.
- [ ] Zware rekenlussen in een `.define` of `.function`.
- [ ] Tabellen met `.fill` in plaats van handmatige `.byte`-reeksen.

**Hardware**
- [ ] IRQ bevestigt met `asl $d019` als eerste instructie.
- [ ] Bij `$fffe`-IRQ worden A, X en Y bewaard en teruggezet, en eindigt hij op `rti`.
- [ ] Bij `$0314`-IRQ eindigt hij op `jmp $ea31` of `jmp $ea81`.
- [ ] Hoogstens één interrupt per frame gaat via `jmp $ea31`.
- [ ] Rastersplits boven regel 255 zetten bit 7 van `$d011` mee.
- [ ] `$d018`, VIC-bank en spritepointers uit labeladressen berekend.
- [ ] Charset en spritedata uitgelijnd met `.align`.
- [ ] `$dd02` bits 0-1 als uitgang gezet vóór het schrijven van `$dd00` (§20.1).
- [ ] Geen grafiek op `$1000-$1fff` of `$9000-$9fff` in VIC-bank 0 of 2 (§20.4).
- [ ] Sprites pas aangezet nadat positie, pointer en kleur staan (§20.6).
- [ ] Bij twee schermbuffers: spritepointers in beide geschreven (§20.1).
- [ ] Framesync die op `$d012` wacht: geverifieerd bij welke rasterlijn hij
      terugkomt — niet aannemen dat dat lijn 0 is (§20.3).

**Segments en zeropage**
- [ ] Zeropage-variabelen in een eigen segment dat niet in `.file` staat.
- [ ] Elke zeropage-variabele gedeclareerd vóór het eerste gebruik.
- [ ] RAM-tabellen zonder beginwaarde in een `virtual`-segment.
- [ ] Elke variabele in een `virtual`-blok wordt expliciet gezet in de
      init- of laadroutine, niet alleen in het pad dat je toevallig
      voor ogen had (§20.5).
- [ ] Voeg je een variabele toe die de hoofdlus leest, zet hem dan meteen in
      de initialisatie (§20.16).
- [ ] Segmentnamen in `.segment` en `.file` gecontroleerd tegen de geheugenkaart.
- [ ] `.encoding` op bestandsniveau, niet binnen een blok.

**Subroutines en sprongen**
- [ ] `jmp`/`jsr` wijst naar code, niet naar een datalabel (`jmp (ptr)` bij indirect).
- [ ] Bij stackparameters wordt het retouradres bewaard en teruggezet.
- [ ] Strings voor `$ab1e`/`$ffd2` staan in een PETSCII-encoding.
- [ ] CIA-interrupts uitgezet (`$dc0d`, `$dd0d`) en bevestigd.
- [ ] Rasterregel bit 8 expliciet gezet of gewist in `$d011`.
- [ ] Spritedata is 63 bytes; pointer = adres/64.
- [ ] `$d010` wordt in beide richtingen bijgewerkt.
- [ ] Botsingsregisters `$d01e`/`$d01f` één keer per frame gelezen.
- [ ] Bitregisters gemaskeerd met `ora`/`and`, bestaande bits blijven staan.
- [ ] `.encoding` past bij de manier van uitvoeren (schermgeheugen of kernal).

**Constanten**
- [ ] Elk verband tussen twee constanten is vastgelegd met `.errorif`, niet
      alleen in een commentaarregel (§20.13).
- [ ] Geen enkel statement loopt over meer dan een regel (§20.14).

**Registers**
- [ ] Geen enkele routine rekent over een `jsr` heen op X of Y zonder dat
      de aangeroepen routine die met rust laat (§20.12).

**Sprongen en tabellen**
- [ ] Geen enkele branch overbrugt meer dan 127 bytes (§19.10, §20.11).
- [ ] Elk `jsr`/`jmp`-doel bestaat ergens in het programma (§20.11). Vooral
      na een grote herschrijving: een tekstbewerking die een blok vervangt
      neemt makkelijk een routine mee die er middenin stond.
- [ ] Bij het doorlopen van een tabel: aantal `iny`'s per regel geteld tegen
      de recordgrootte, in álle takken van de lus (§20.8).

**Tooling**
- [ ] `c64_ka_syntax_checker.py` geeft 0 ERRORs.
- [ ] `java -jar KickAss.jar` geeft 0 fouten.
- [ ] Geheugenkaart (`-showmem`) gecontroleerd op onbedoelde overlap.
- [ ] Adresrekenkunde die de checker niet ziet — tabelwandelingen, render- en
      cameraroutines — nagebouwd in Python op de echte `.asm`-data (§20.8, §20.10).
- [ ] Cyclusbegroting gemaakt voor alles wat de raster moet bijhouden (§20.2).
- [ ] Getest in VICE.

---

## 17. Templates

Beide onderstaande templates zijn door de syntax checker gehaald: 0 fouten,
0 waarschuwingen.

### 17.1 Hoofdbestand met segments en raster-IRQ

```asm
//--------------------------------------------------------------------
// Projectnaam - korte omschrijving
//--------------------------------------------------------------------
#importonce

.cpu _6502
.encoding "screencode_mixed"

//------------------------------ constanten --------------------------
.const VIC    = $d000
.const SCREEN = $0400
.const COLRAM = $d800
.const RASTER = $32

.label BORDER = VIC+$20
.label BGCOL  = VIC+$21

//------------------------------ segments ----------------------------
.segmentdef Code [start=$0810]
.segmentdef Data [startAfter="Code", align=$100]
.file [name="demo.prg", segments="Code,Data",
       modify="BasicUpstart", _start=$0810]

//------------------------------ main --------------------------------
        .segment Code "Main"
start:  jsr initScreen
        jsr initIrq
        jmp *

//------------------------------ scherm ------------------------------
        .segment Code "Screen setup"
initScreen: {
        lda #BLACK
        sta BORDER
        sta BGCOL
        ldx #0
loop:   lda text,x
        beq done
        sta SCREEN,x
        lda #LIGHT_BLUE
        sta COLRAM,x
        inx
        jmp loop
done:   rts

        .segment Data "Screen text"
text:   .text "kick assembler skelet"
        .byte 0
}

//------------------------------ interrupt ---------------------------
        .segment Code "IRQ setup"
initIrq: {
        sei
        lda #$7f
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d
        lda #<irq
        sta $0314
        lda #>irq
        sta $0315
        lda #$01
        sta VIC+$1a
        lda #RASTER
        sta VIC+$12
        lda VIC+$11
        and #$7f
        sta VIC+$11
        asl VIC+$19
        cli
        rts
}

        .segment Code "IRQ"
irq:    asl VIC+$19
        inc BORDER
        // ... werk per frame ...
        dec BORDER
        jmp $ea31
```

### 17.2 Bibliotheekbestand

```asm
//--------------------------------------------------------------------
// Bibliotheekbestand - importeer met #import "screenlib.asm"
//--------------------------------------------------------------------
#importonce
.filenamespace ScreenLib

.const SCREEN = $0400
.const COLRAM = $d800

// Wist het scherm met een teken en een kleur.
.macro @ClearScreen(char, color) {
        lda #char
        ldx #0
!:      sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$300,x
        inx
        bne !-
        lda #color
        ldx #0
!:      sta COLRAM,x
        sta COLRAM+$100,x
        sta COLRAM+$200,x
        sta COLRAM+$300,x
        inx
        bne !-
}

// Zet een 16-bits waarde in een adrespaar.
.pseudocommand @setptr src : tar {
        lda src
        sta tar
        lda _hiByte(src)
        sta _hiByte(tar)
}

.function _hiByte(arg) {
        .if (arg.getType()==AT_IMMEDIATE)
            .return CmdArgument(arg.getType(), >arg.getValue())
        .return CmdArgument(arg.getType(), arg.getValue()+1)
}
```

De `@` voor `ClearScreen` en `setptr` zet ze in de root-namespace, zodat de
aanroeper geen `ScreenLib.` hoeft te schrijven. De hulpfunctie `_hiByte` blijft
wel binnen de namespace.

---

## Appendix A — Adresseringsmodi per mnemonic

Legenda: `-` geen argument, `#` immediate, `d` direct (zp of abs),
`d,x` `d,y` geïndexeerd, `(d,x)` `(d),y` indirect geïndexeerd, `(a)` indirect.

### Standaard 6502

| Mnemonic | Modi |
|---|---|
| `adc and cmp eor lda ora sbc` | `#`, `d`, `d,x`, `d,y`, `(d,x)`, `(d),y` |
| `asl lsr rol ror` | `-`, `d`, `d,x` |
| `bcc bcs beq bmi bne bpl bvc bvs` | `d` (relatief) |
| `bit` | `d` |
| `brk clc cld cli clv dex dey inx iny nop pha php pla plp rti rts sec sed sei tax tay tsx txa txs tya` | `-` |
| `cpx cpy` | `#`, `d` |
| `dec inc` | `d`, `d,x` |
| `jmp` | `d`, `(a)` |
| `jsr` | `d` |
| `ldx` | `#`, `d`, `d,y` |
| `ldy` | `#`, `d`, `d,x` |
| `sta` | `d`, `d,x`, `d,y`, `(d,x)`, `(d),y` — **geen `#`** |
| `stx` | `d`, `d,y` |
| `sty` | `d`, `d,x` |

### Illegale opcodes (standaard beschikbaar onder `.cpu _6502`)

| Mnemonic (aliassen) | Modi |
|---|---|
| `ahx` / `sha` | `(d),y`, `d,y` |
| `alr` / `asr`, `anc`, `anc2`, `arr`, `axs` / `sbx`, `sbc2`, `xaa` / `ane` | `#` |
| `dcp` / `dcm`, `isc` / `ins` / `isb`, `rla`, `rra`, `slo`, `sre` | `d`, `d,x`, `d,y`, `(d,x)`, `(d),y` |
| `las` / `lae` / `lds`, `tas` / `shs`, `shx` | `d,y` |
| `lax` / `lxa` | `#`, `d`, `d,y`, `(d,x)`, `(d),y` |
| `sax` | `d`, `d,y`, `(d,x)` |
| `shy` | `d,x` |
| `nop` (uitgebreid) | `-`, `#`, `d`, `d,x` |

### DTV

`_6502` plus `bra` (relatief), `sac` (`#`), `sir` (`#`).

### 65c02

De standaardset met: `bra`; `(d)` erbij voor `adc and cmp eor lda ora sbc sta`;
`-` erbij voor `dec inc`; `(a,x)` erbij voor `jmp`; `#`, `d,x` en `d,x`-vormen
erbij voor `bit`; plus `phx phy plx ply stp wai` (`-`), `stz` (`d`, `d,x`),
`trb tsb` (`d`), `rmb0..7` / `smb0..7` (`d`) en `bbr0..7` / `bbs0..7`
(`d,label`). Een gewone C64 heeft géén 65c02.

---

## Appendix B — Directives

| Directive | Werking |
|---|---|
| `*=` / `.pc=` | zet de geheugenpositie |
| `.align` | lijnt de positie uit op een grens |
| `.assert` / `.asserterror` | test een expressie of codeblok |
| `.break` / `.watch` | debug-info voor emulator |
| `.byte` `.by` / `.word` `.wo` / `.dword` `.dw` | data |
| `.const` / `.var` / `.label` / `.eval` | symbolen |
| `.cpu` | kies de instructieset |
| `.define` | blok in function mode, exporteert gelockte symbolen |
| `.disk` | maakt een d64-image |
| `.encoding` | tekenset voor `.text` en `.import text` |
| `.enum` | reeks constanten |
| `.error` / `.errorif` | eigen foutmelding |
| `.file` | schrijft prg of bin uit segments |
| `.filemodify` / `.modify` | stuurt uitvoer door een modifier |
| `.filenamespace` / `.namespace` | namespace |
| `.fill` / `.fillword` / `.lohifill` | gegenereerde data |
| `.for` / `.while` / `.if` | vertakken en herhalen |
| `.function` / `.macro` / `.pseudocommand` | eigen bouwstenen |
| `.import binary/c64/text/source` | data of bron inlezen |
| `.memblock` | benoemt een nieuw geheugenblok |
| `.plugin` | registreert een Java-plugin |
| `.print` / `.printnow` | console-uitvoer |
| `.pseudopc` | assembleer alsof de code elders staat |
| `.return` | resultaat van een functie |
| `.segment` / `.segmentdef` / `.segmentout` | segments |
| `.struct` | eigen datastructuur |
| `.text` `.te` | tekstdata |
| `.zp` | markeert labels als zeropage |

Preprocessor: `#define #undef #if #elif #else #endif #import #importif
#importonce`.

---

## 18. Praktijklessen — getest en workend (uit "Captain Cock en de Black Whore")

Deze sectie bevat patronen die **daadwerkelijk in VICE (x64sc) zijn getest** en
bewezen hebben te werken. Ze zijn niet gebaseerd op theorie maar op een
debug-sessie met veel valstreken — dus hier staan ook de specifieke valstreken.

### 18.1 Text-printing via KERNAL vs direct schermgeheugen

**Getest en workend patroon (KERNAL, betrouwbaar, simpel):**

```asm
.encoding "petscii_upper"

.const CHROUT = $ffd2
.const GETIN  = $ffe4
.const CLRSCR = $e544

        BasicUpstart2(start)

start:
        lda #$00
        sta $d020                   // border zwart
        sta $d021                   // achtergrond zwart
        lda #$05                    // groen
        sta $0286                   // tekstkleur
        jsr CLRSCR

        ldx #<tekst
        lda #>tekst
        jsr printStr                // X=lo, A=hi
        jmp *

printStr:
        stx $fd                     // $fd/$fe zijn vrij voor de gebruiker
        sta $fe
        ldy #$00
loop:   lda ($fd),y
        beq klaar
        jsr CHROUT
        iny
        bne loop
klaar:  rts

tekst:  .text "HALLO WERELD"
        .byte $0d
        .text "DIT WERKT."
        .byte $00
```

**Cruciale punten:**

1. **`.encoding "petscii_upper"`** wanneer je via KERNAL `$ffd2` (CHROUT)
   print. KERNAL interpreteert bytes als PETSCII. Hoofdletters in je `.text`
   geven correcte uppercase glyphs. Lowercase renderen in de uppercase/
   graphics charset als kleine blokjes — NIET wat je verwacht.
2. **`$fd/$fe` zijn vrij** voor de gebruiker (KERNAL zelf raakt ze niet aan
   tijdens CHROUT/GETIN/CLRSCR). `$fb/$fc` zijn dat ook, maar let op:
   gebruik **NOOIT dezelfde zp-pointers voor verschillende dingen** binnen
   één flow — zie §18.2.
3. **`CLRSCR = $e544`** wist het scherm én zet de cursor linksboven.
   Werkt prima samen met CHROUT daarna.
4. **`GETIN = $ffe4`** leest het keyboard-buffer (gevuld door de KERNAL
   IRQ die 1/60s draait). Werkt alleen als je de IRQ **AAN** laat staan.
   Retourneert `0` als er geen toets is ingedrukt; PETSCII-code anders.

### 18.2 Zeropage-conflict: DÉ klassieke valstrek

Symptoom: je ziet de eerste regel van je tekst, daarna rommel of niets.
Of na een `jsr` is je string-pointer plotseling anders.

Oorzaak bij **onze** bug: we gebruikten twee aparte zp-pointerparen
(zpRec en zpStr), maar in de **eerste versie** gebruikten we
per ongeluk één en hetzelfde paar `$fb/$fc` voor zowel de record-pointer
als de string-pointer. Dan overwoekert deze aanroep:

```
jsr printStr   // printStr doet: sta zpPtr+1 / stx zpPtr
// na return wijst zpPtr naar de EERSTE BYTES VAN DE STRING,
// niet meer naar het record
lda (zpPtr),y  // leest karakterdata als "nOptions" -> garbage
```

**Regel**: per dataflow-pad een eigen zp-pointerpaar. Bij een record+
string-patroon minimum:

```asm
.const zpRec = $fb                // $fb/$fc: pointer naar het record
.const zpStr = $fd                // $fd/$fe: pointer naar de string
```

### 18.3 Screencode vs PETSCII: wanneer welke

| Encoding | Gebruikscontext | Resultaat-codes |
|---|---|---|
| `petscii_upper` | KERNAL `CHROUT $ffd2` | hoofdletters = `$41..$5A`; getal `1` = `$31` |
| `petscii_mixed` | KERNAL met gemengde tekst | hoofdletters = `$C1..$DA` (set 2), kleine = `$41..$5A` |
| `screencode_upper` | direct `sta $0400,x` | hoofdletters = `$01..$1A`; `@` = `$00`; spatie = `$20` |
| `screencode_mixed` | direct met kleine letters | hoofdletters = `$01..$1A`, kleine = `$41..$5A` (in charset 2) |

**Valkuilen die we raakten:**

- **`screencode` + uppercase + `sta $0400,x`** geeft je exact wat je ziet
  — dit is betrouwbaar maar zelf te verantwoorden (geen auto-scroll,
  geen cursor-knippering, je moet zelf kolommen en rijen tellen).
- **`petscii` + `jsr $ffd2`** laat KERNAL alles doen (scroll, cursor,
  knippering) — eenvoudiger, maar zorg dat je encoding overeenkomt met
  hoe KERNAL die interpreteert.
- **NOOIT mengen binnen één string**: `screencode`-byte `"A"` op `$01`
  wordt via CHROUT als SOH-control-code geïnterpreteerd (cursor home-achtig).
- **CR/LF**: `$0d` is PETSCII "Carriage Return" (KERNAL maakt er een
  scherm-newline van). `$0a` is Linefeed. In praktijk: `$0d` is voldoende
  voor KERNAL, en bij directe screen-writes zet je zelf `rij++` en `kol=0`.

### 18.4 "Scherm vol groene staafjes" — de klassieke eerste-run-valstrek

Symptoom: het hele scherm staat vol met dezelfde (groene) kleine blokjes of
strepen.

Oorzaak bij **onze** bug: `*=$02 virtual` + `.zp {}` direct na
`BasicUpstart2(start)`. KickAssembler plaatste alles dan op adres `$0002`,
met als gevolg een PRG van 11 bytes en vrijwel geen programma. De C64
bootte met de standaard boot-ROM die het scherm initialiseerde op
standaard kleuren; het "staafjespatroon" was het leegteken `$20` (spatie)
plus kleur `$04` paars of `$05` groen (afhankelijk van welke bytes in
vrij RAM op de kleurgeheugen-adressen stonden na reset).

**Fix**: gebruik `.const label = $zz` voor zeropage-adressen, NIET
`*=$02 virtual` + `.zp { }`. De volgorde wordt dan bepaald door waar
je de `.const`-regels plaatst in de source (bovenaan, vóór je code),
en `BasicUpstart2` blijft de eerste en enige `*=`-wijziging vóór de
start-label.

### 18.5 Case-bug in strings

Symptoom: tekst zichtbaar, maar letters in het midden van een zin zijn
ineens grafische symbolen.

Oorzaak: `screencode_upper` (of `petscii_upper`) encodeert lowercase
letters als PETSCII-codes `$61..$7A`, die in de uppercase/graphics-charset
als **geblokte symbolen** renderen. KickAssembler waarschuwt niet.

**Fix**: schrijf je `.text ""`-strings volledig in **HOOFDLETTERS**, of
schakel over naar `petscii_mixed` / `screencode_mixed` (en accepteer dan
dat de karakters anders gemapt zijn).

### 18.6 Debug met VICE: `-vicesymbols` en remote-moncommands

KickAssembler-output voor VICE-debugging:

```
java -jar KickAss.jar program.asm -o build\program.prg -vicesymbols -showmem
```

Dit genereert `build/program.vs` met label-definities in VICE-formaat.
In VICE kun je dan breakpoints zetten op labels:

```
break printStr
```

Starten met een script dat commands invoert:

```
start "VICE" /D "<cwd>" ".../x64sc.exe" -autostart build\program.prg -console -moncommands debug.txt
```

waarin `debug.txt` regels als bevat:

```
break runScene
break waitKey
```

**Belangrijke observaties uit praktijk:**

- **Break on label** is veel leesbaarder dan break op adres.
- Zet een breakpoint *direct na* `CLRSCR` om te verifiëren dat je daar
  aankomt.
- Als het scherm leeg blijft maar je breakpoint wordt wél gehaald, zit
  de bug in wat er na die breakpoint komt, niet ervoor.
- Test eerst met een **minimale test** die alleen `A` op het scherm zet
  (`lda #$01 / sta $0400`) om te bewijzen dat je uberhaupt schrijft.

### 18.7 CIA-matrix scan (zonder KERNAL IRQ)

Als je `sei` gebruikt en de KERNAL-IRQ uitschakelt, werkt `GETIN = $ffe4`
niet meer (KERNAL scant het keyboard niet meer in zijn buffer). Je moet
dan **zelf** via de CIA-matrix scannen.

C64 keyboard-matrix (CIA1: `$dc00` select kolom, `$dc01` lees rij):

| Toets | Kolom (A) | Rij (B) | Mask op $dc00 | Mask op $dc01 |
|---|---|---|---|---|
| `1` | 7 | 0 | `$7f` | `$01` |
| `2` | 3 | 7 | `$f7` | `$80` |
| `3` | 7 | 1 | `$7f` | `$02` |

Voorbeeld:

```asm
        // test toets '1'
        lda #$7f
        sta $dc00
        lda $dc01
        and #$01
        beq is1
        rts

is1:    lda #$31
        rts
```

Active-low: als de bit op `$dc01` nul wordt, is de toets ingedrukt.

**Let op**: als de KERNAL-IRQ aan staat, gebruik dan gewoon `GETIN $ffe4`
— dat is veel eenvoudiger en betrouwbaarder. Eigen matrix-scan is alleen
nodig als je de KERNAL bewust uitschakelt (bijvoorbeeld bij demo's met
eigen raster-timing).

### 18.8 `BasicUpstart2` correct gebruiken

Correct patroon:

```asm
.encoding "petscii_upper"

        BasicUpstart2(start)        // vult $0801-$080c met BASIC-regel

start:  // hier begint je code op $080e
        // ...
```

**Fout patroon (eerder gemaakt):**

```asm
        BasicUpstart2(start)

*=$02 virtual                       // OEPS: dit verandert de program-counter
.zp { zpPtr: .word 0 }              // alles komt nu op $0002 te staan
```

Resultaat: PRG van 11 bytes (alleen het BASIC-gedeelte) en geen
machinecode na `RUN`. De machine loopt terug naar de READY-prompt.

**Fix**: gebruik `.const zpPtr = $fb` etc. vóór `BasicUpstart2`. Dan
is er geen `*=`-wijziging na de macro en blijft alles op volgorde.

### 18.9 Memory map opvragen (essentieel na elke build)

Na elke build:

```
java -jar KickAss.jar program.asm -o program.prg -showmem
```

Controleer dat je ziet:

```
Default-segment:
  $0801-$080c Basic         <-- de BasicUpstart2-regel
  $080e-XXXX  Basic End     <-- je code+data
```

Als je `$0002-XXXX` of iets anders dan `$0801` ziet als eerste adres,
is de volgorde van je `*=`-blokken fout.

### 18.10 Build- en run-script (Windows, cmd.exe)

De combinatie die hier werkte (cmd.exe, niet PowerShell):

```cmd
taskkill /F /IM x64sc.exe 2>nul ^& ^
"C:\Users\aegwh\OneDrive\dev\c64\java\bin\java.exe" -jar "C:\Users\aegwh\OneDrive\dev\c64\kick\KickAss.jar" adventure.asm -o build\adventure.prg -vicesymbols -showmem ^& ^
start "VICE" /D "c:\Users\aegwh\OneDrive\dev\KickAss" "C:\Users\aegwh\OneDrive\dev\c64\vice\bin\x64sc.exe" -autostart build\adventure.prg +confirmonexit
```

Belangrijk:
- `1>nul 2>nul` redirecten in cmd, niet met Unix-syntax
- `^&` chained commands in cmd (in PowerShell gebruik `;` of aparte statements)
- `+confirmonexit` onderdrukt de "Exit VICE?"-dialoog bij het sluiten
- `start` opent VICE los van de terminal, zodat je build-commando's
  verder kunt draaien

### 18.11 Python-syntax-checker: wanneer hij niet werkt

`c64_ka_syntax_checker.py` is een Python-script — dat betekent dat
je een Python-interpreter nodig hebt. Op een kaal Windows systeem zonder
Python geïnstalleerd **faalt** het draaien ervan met:

```
'python' is not recognized as an internal or external command
```

Voor KickAssembler zelf is er GEEN Python nodig (het is een Java JAR),
maar de checker wel. Alternatief: lees dit document zelf zorgvuldig door
na het schrijven van code en controleer handmatig op de harde regels uit §1.

### 18.12 Direct naar schermgeheugen schrijven — `screencode_upper` werkt

Getest én geassembleerd zonder fouten: tekst direct in `$0400` met
`.encoding "screencode_upper"` en alle tekst in HOOFDLETTERS werkt. Dit is de
aanpak die in [`adventure.asm`](adventure.asm) is gebruikt en gebouwd is tot
[`build/adventure.prg`](build/adventure.prg).

**Wat 100% goed werkte:**

- `.encoding "screencode_upper"` bovenin (globaal), alle `.text`-strings in
  hoofdletters (§18.5).
- `BasicUpstart2(start)` als enige program-counterwijziging vóór `start:`
  (§18.8). De geheugenkaart na `-showmem` liet correct `$0801-$0809 Basic`
  gevolgd door de code zien.
- Schermadres berekenen als `SCREEN + rij*40 + kolom`. De ×40-implementatie
  met `asl`/`rol $05` op een 16-bit zp-paar ($04/$05) werkt: eerst ×8 bewaren
  in ($06,$07), dan verder schuiven tot ×32 en optellen (§18.13).
- Kleurgeheugen `$d800..` één keer vullen bij `clearScreen` is voldoende —
  daarna hebben alle geschreven tekens meteen de juiste kleur.
- Toetsen lezen met `jsr $ffe4` (GETIN) in een actieve lus werkt; de KERNAL-
  IRQ moet aan blijven (geen `sei`).
- Scene-engine als data: een `.word`-tabel (`sceneTable`) met per record
  `.word tekstPtr, .byte optieAantal` en daarna per optie `.word optieTekst,
  .byte doelScene`. Indirect lezen via `(zpPtr),y` met een lopende Y-offset
  werkt zonder problemen.

### 18.13 16-bit vermenigvuldiging met 40 zonder tabel

Getest patroon (rijnummer in `curRow`, resultaat in $04/$05):

```asm
        lda curRow
        sta $04
        lda #$00
        sta $05
        lda $04
        asl
        rol $05
        asl
        rol $05
        asl
        rol $05             // nu *8
        sta $06
        lda $05
        sta $07             // *8 bewaard in $06/$07
        lda $04
        asl
        rol $05
        asl
        rol $05             // *32
        clc
        adc $06
        sta $04
        lda $05
        adc $07
        sta $05             // *40
```

Let op: de `asl` in de *32-stap werkt op de accumulator die **nog steeds het
oorspronkelijke rijnummer bevat** (herladen met `lda $04` is dus vereist, want
`sta $06` wist de accumulator niet maar `sta $04` na de *8-reeks ook niet —
`lda $04` hierboven is verplicht omdat `sta` de accumulator niet wijzigt maar
de `asl`-reeks van *8 hem al heeft verlaten). De veiligste variant laadt voor
elke reeks opnieuw:

```asm
        // simpele, zeker-correcte variant:
        lda curRow
        asl
        asl
        asl                 // *8   (rij < 25, past in 1 byte)
        sta $fe
        lda curRow
        asl
        asl
        asl
        asl
        asl                 // *32
        clc
        adc $fe             // *40, past in 1 byte (max 24*40 = 960, dus toch 16-bit nodig)
```

Omdat 24×40 = 960 niet in één byte past heb je bij *32 de carry naar boven
nodig; gebruik daarom bij voorkeur **`rows: .lohifill 25, $0400+i*40` uit
§13.6** — dat is korter, sneller en foutloos. De handmatige ×40-schuiver werkt,
maar de tabel is beter.

### 18.14 Shell-pijlen op Windows: cmd.exe vs PowerShell

Praktijkles die tijd kostte: de terminal op deze machine bleek **cmd.exe**,
niet PowerShell. Gevolgen:

| Constructie | PowerShell | cmd.exe |
|---|---|---|
| commando aanroepen met pad tussen quotes | `& "C:\pad\tool.exe" arg` | `"C:\pad\tool.exe" arg` (geen `&`) |
| commando's chainen | `;` | `&` (vergeet de `&`-betekenis: het is de operator zelf) |
| processen killen | `Get-Process x \| Stop-Process` | `taskkill /F /IM x64sc.exe` |
| tool aanroep-amp | `&` is verplicht vóór een geciteerd pad | `&` is *verboden*, geeft `'&' was unexpected` |

Signalen: de fout `'&' was unexpected at this time.` betekent dat je in
cmd.exe zit. `'Get-Process' is not recognized` betekent óók cmd.exe.
Gebruik dus plain `taskkill`, geen PowerShell-cmdlets, en roep Java/VICE
rechtstreeks aan zonder `&`-prefix.

### 18.15 VICE starten vanuit deze omgeving

Wat hier daadwerkelijk werkte:

```cmd
"C:\...\x64sc.exe" -autostart build\adventure.prg +confirmonexit
```

- `-autostart` laadt **én** start het programma (automatisch `RUN`). Wil je
  alleen laden (handig als je zelf `RUN` wilt typen of met de BASIC-prompt
  wilt spelen): gebruik `-autostartprgmode 0` of omit `-autostart` en geef
  het prg als plain argument.
- `+confirmonexit` voorkomt de afsluitdialoog.
- Als VICE na de commando-regel meteen weg is: meestal is het prg-pad fout of
  is de optie-syntax misverstaan (bijv. een `&`-prefix van PowerShell-gewoonte).

### 18.16 Text-adventure-engine: recordindeling die werkte

De indeling die assembleerde en draaide:

```asm
sceneTable:
        .word sc00, sc01, ...           // pointers naar records

sc00:
        .word s00txt                    // scene-tekst
        .byte 3                         // aantal opties
        .word o00a, 1                   // per optie: tekst-pointer, doel-scene
        .word o00b, 2
        .word o00c, 3
```

De interpreter leest via `(zpRec),y` met een lopende Y-offset (2 voor het
aantal, dan per optie 3 bytes). Belangrijk:

- **Aparte zp-pointers** voor record en string (§18.2).
- Ongeldige optie-slots: `.word dummy, .byte $ff` en in de key-handler op
  `$ff` testen vóór de scene wordt gezet.
- Toetsen `'1'..'3'` zijn PETSCII `$31..$33`; `sec / sbc #$31` geeft de index.
- Einde van scene = nieuwe `clearScreen` en opnieuw renderen — er is géén
  scroll-ondersteuning nodig als elke scene op één scherm past (25×40).

---

## 19. Praktijklessen — getest en werkend (uit "Super Pong")

Getest op PAL VICE x64sc met `KickAss.jar` v5.25; eindresultaat in
`build/pong.prg`. Dit spel gebruikt sprites, direct schermgeheugen,
toetsenbordmatrix-scanning en SID-geluid.

### 19.1 Sprite-y ↔ scherm-y vertaling

**Sprite-y 50 = scherm-pixel-y 0.** Tekstscherm-rij 2 bestrijkt scherm-y
16..23, dus voor een bal die exact op die rij bounce: sprite-y 66..73.
Rij 23 (onderaan) = scherm-y 184..191 → sprite-y 234..241. Werkende
gameplay-constantes uit het eindresultaat:

```asm
.const TOP_Y    = 75   // paddle-top min sprite-y (net onder rand rij 2)
.const BOT_Y    = 212  // paddle-top max sprite-y (balk rij 1..20 van sprite)
.const BALL_TOP = 76   // bal bounce boven
.const BALL_YMAX= 224  // bal bounce onder
```

De paddle-sprite tekent zijn balk op sprite-rijen 1..20 (niet 0..19), dus de
onderkant van de paddle zit op paddleY+20. Daarom kan BOT_Y 212 zijn terwijl
BALL_YMAX 224 is: op die plek komt de balk-visueel tot scherm-y 182, exact
boven de rand op rij 23.

### 19.2 Sprite-data: exacte layout

Een sprite = 63 bytes + 1 pad-byte in het PRG (Kick Ass wil 64-byte blokken
als je `*=$3000`-stijl gebruikt). Een paddle die er als balk uitziet:

```asm
sprPaddle:
        .byte $00,$00,$00          // rij 0: leeg
        .fill 20, [$00,$ff,$00]    // rijen 1-20: middelste 8 pixels aan
        .byte 0                    // pad-byte tot 64
```

Een ronde bal (8×8 in het midden):

```asm
sprBall:
        .fill 7, [$00,$00,$00]     // 7 lege rijen
        .byte $00,$3c,$00          // rijpatroon: $3c,$7e,$ff,$ff,$ff,$7e,$3c
        .byte $00,$7e,$00
        ...
```

**Valstrek:** `[$00,$ff,$00]` met verkeerde `+pad` geeft versprongen blokken
— houd exact 63 bytes data + 1 pad aan.

### 19.3 Sprite x-hi bits — NIET wissen bij update

Sprite-x loopt van 0..511 in `$d000/2/4/...` (lo) + bits in `$d010` (hi).
Bit n van `$d010` = hi-bit van sprite n. Als je paddle2 (sprite 1) op x=312
zet (lo=56, hi=1), moet je bij elke update:

```asm
lda VIC+$10         // $d010
and #%00000100      // BEWAAR alleen bit 2 (onze bal, sprite2-hi)
ora  #%00000010     // ZET bit 1 (paddle2 is altijd >255)
sta VIC+$10
```

**Fout die we maakten:** `and #%11111100` wisse bit 2 → bal sprong plotseling
256 px terug zodra hij rechts van x=255 kwam. Gebruik altijd mask-and + ora.

### 19.4 Ball-bounce op paddles: gebruik richtingscheck + zones

Vroegere bug: bal vloog door de linker paddle heen. Werkend patroon — check
EERST of de bal überhaupt naar die paddle beweegt, daarna pas op bereik:

```asm
// --- linker paddle (sprite 0 op x=24, bal komt van rechts) ---
        lda ballX+1
        bne tryP2            // hi≠0 → bal zit rechts, skip P1
        lda ballDX
        bpl doneX            // bal gaat naar rechts → nooit P1 raken
        lda ballX
        cmp #P1_BOUNCE_LO    // 34
        bcc doneX
        cmp #P1_BOUNCE_HI    // 42
        bcs doneX
        // y-check tegen pad1Y..pad1Y+20, dan:
        lda #$01 : sta ballDX
        jsr sndHit

tryP2:
        lda ballX+1
        beq doneX            // hi=0 → te ver links, geen P2
        lda ballDX
        bmi doneX            // bal gaat naar links → P2 niet raken
        lda ballX
        cmp #P2_BOUNCE_LO    // 52 (met xhi=1 → echte x 308)
        bcc doneX
        cmp #P2_BOUNCE_HI    // 64 (→ echte x 320)
        bcs doneX
        // y-check, dan:
        lda #$ff : sta ballDX
        jsr sndHit
doneX:
```

De LO/HI-window is waar de bal-LEADING-EDGE (voorkant in beweegrichting) de
paddle raakt. Bij een 8px brede bal en paddle op x=24 is bounce-LO 34,
niet 24: je wilt bounce op bal-x+8 = 42, dus window 34..42.

### 19.5 Toetsenbordmatrix lezen (naast joysticks)

Joys zitten op `$dc00` (port 1) / `$dc01` (port 2). Keyboard deelt die
chip: je SCHRIJFT naar `$dc00` om een kolom te selecteren en LEEST `$dc01`
voor de rijen. Bit laag = toets ingedrukt. **Na elk scan `$dc00=$ff`
terugzetten**, anders werken joysticks raar.

Werkend patroon (W/S voor P1, P/L voor P2, spatie = fire, ← = ESC):

```asm
        // --- W (kolom 1, rij-bit 1) / S (k1, b5) ---
        lda #%11111101
        sta $dc00
        lda $dc01
        and #%00000010       // W
        beq p1Up
        lda $dc01
        and #%00100000       // S
        beq p1Down

        // --- P (kolom 5, b1) / L (k5, b2) ---
        lda #%11011111
        sta $dc00
        lda $dc01
        and #%00000010       // P
        beq p2Up
        lda $dc01
        and #%00000100       // L
        beq p2Down

        lda #$ff
        sta $dc00            // herstel voor joysticks

        // --- spatie = fire (kol 7, rij 4) ---
        lda #%01111111
        sta $dc00
        lda $dc01
        and #%00010000
        // laag → fire

        // --- ESC in VICE is de C64 ← toets: kol 0, rij 1 ---
        lda #%11111110
        sta $dc00
        lda $dc01
        and #%00000010
        // laag → ESC ingedrukt
        lda #$ff : sta $dc00
```

Matrix-layout voor deze toetsen: W k1r1, S k1r5, P k5r1, L k5r2, spatie
k7r4, ← k0r1.

### 19.6 Fire-detectie op BEIDE joystickpoorten

```asm
        lda #$ff : sta $dc00     // keyboard idle → joy leesbaar
        lda $dc00                // port 1: bit 4 = fire
        and $dc01                // port 2: bit 4 = fire
        and #$10
        bne noFire               // hoog = NIET ingedrukt
        // één van beide fire-knoppen is laag → start
```

### 19.7 Knipperende tekst zonder timers

Gebruik een frame-teller en test bit 4 (≈ 16 frames aan / 16 uit op PAL):

```asm
        inc frame
        lda frame
        and #$10
        beq show
        // hide: schrijf spaties over de tekst
show:   // schrijf tekst
```

**Valstrek:** `cpx #17` bij 19 tekens → laatste twee letters nooit gekleurd.
Tel de bronstring: inclusief spaties en punten tussen aanhalingstekens.

### 19.8 Hoofdletters op scherm (screencode_upper)

`.encoding "screencode_upper"` kent geen kleine letters — lowercase in je
`.text` wordt rommel. Altijd HOOFDLETTERS gebruiken in `.text` wanneer je
direct naar schermgeheugen schrijft:

```asm
        .encoding "screencode_upper"
        ...
tekst:  .text "PRESS FIRE OR SPACE"   // werkt
        .text "press fire or space"   // GEBRUIK NIET — onleesbaar
```

### 19.9 SID-pingpong-geluiden (kort en simpel)

Eén voice, geen IRQ nodig. Geluid = frequentie + gate aan; game-loop
schakelt gate uit na N frames:

```asm
sidInit:
        lda #$0f : sta $d418       // volume
        lda #$11 : sta $d405       // AD voice 1
        lda #$f0 : sta $d406       // SR
        rts

sndHit:                          // korte piep
        lda #$30 : sta $d400
        lda #$20 : sta $d401
        lda #$11 : sta $d404       // triangle + gate
        lda #6 : sta sndTimer
        rts

sndWall:  // idem, andere frequentie
sndScore: // lagere toon, langere timer

// elke frame in mainLoop:
soundUpdate:
        lda sndTimer
        beq done
        dec sndTimer
        bne done
        lda #$10 : sta $d404       // gate uit
done:   rts
```

### 19.10 Branch-bereik ±127 bytes

`beq/bne/bpl/bmi/bcc/bcs` bereiken ±127 bytes. Compile-fout "Branch out of
range" betekent: je doel is te ver. Fix via omgekeerde branch + `jmp`:

```asm
        // in plaats van: beq verWeg   ← out of range
        bne !+
        jmp verWeg
!:
```

Kick Ass multi-labels `!:` ... `bne !+` werken alleen als er werkelijk een
`!:` vóór/na de branch staat. Een `bcc !+` naar een niet-bestaand `!` geeft
een vage parse-fout; noem het label gewoon (`bcc checkX`).

### 19.11 `.const` MET punt — nooit vergeten

`const FOO = 1` (zonder punt) is GEEN geldige directive → 18+ parse-fouten
verspreid door je bestand. Altijd `.const FOO = 1`. Hetzelfde geldt voor
`.zp`, `.fill`, `.text`, `.byte` — alle Kick Ass directives beginnen met `.`.

### 19.12 Toolchain aanroepen onder PowerShell

- `;` werkt NIET als command-scheider in PowerShell binnen deze terminal:
  Kick Ass krijgt `;` mee als argument en crasht met "Already have an
  inputfile". Voer commando's **apart** uit.
- Bouwen: `java.exe -jar KickAss.jar main.asm -o build\pong.prg`
- VICE: `start "" "...x64sc.exe" -autostart "...pong.prg" +confirmonexit`
- Python is op deze machine NIET beschikbaar → `c64_ka_syntax_checker.py`
  niet draaibaar; de assembler zelf is de syntax-check.

## 20. Praktijklessen — scrollende wereld met dubbelbuffer (uit "c64red")

Uit een port van een Game Boy-RPG naar de C64: kaarten die groter zijn dan
het scherm, een camera die de speler volgt, twee schermbuffers in VIC-bank 1
en volledige kleur per char tijdens het scrollen. Geassembleerd met
`KickAss.jar` v5.25 en gedraaid in VICE x64sc.

De fouten hieronder zijn allemaal echt gemaakt. Ze kostten stuk voor stuk een
bouwronde, en ze zijn geen van alle uit de assembler-output af te leiden.

### 20.1 Twee schermbuffers in VIC-bank 1

Dubbelbufferen doe je door twee schermen in dezelfde VIC-bank te zetten en
`$d018` om te schakelen. Drie dingen die daarbij misgaan:

```asm
.const VICBANK   = $4000
.const SCREEN0   = VICBANK + $0000
.const SCREEN1   = VICBANK + $0400
.const CHARSET   = VICBANK + $0800     // 2K-grens
.const SPRITEBASE= VICBANK + $1000     // 64-grens
.const SPRPTRBASE= [SPRITEBASE - VICBANK] / 64

// $d018: schermadres in bits 4-7 (stappen van 1K binnen de bank),
// charsetadres in bits 1-3 (stappen van 2K binnen de bank).
.const VMCSB_S0  = %00000010
.const VMCSB_S1  = %00010010
```

**Eén: `$dd00` is een CIA-poort, geen VIC-register.** Bits 0-1 kiezen de bank,
maar omgekeerd geteld — 3 is bank 0, 2 is bank 1, 1 is bank 2, 0 is bank 3 —
en ze moeten eerst als uitgang worden ingesteld:

```asm
        lda $dd02
        ora #%00000011              // bits 0-1 als uitgang
        sta $dd02
        lda $dd00
        and #%11111100
        ora #%00000010              // bank 1: $4000-$7fff
        sta $dd00
```

**Twee: de spritepointers staan op schermbasis + `$03f8`.** Met twee buffers
zijn dat twee plekken, en je moet ze allebei schrijven — anders krijg je bij
elke omschakeling andere sprites:

```asm
.const SPRPTR0   = SCREEN0 + $03f8
.const SPRPTR1   = SCREEN1 + $03f8

        lda #SPRPTRBASE
        sta SPRPTR0
        sta SPRPTR1
```

**Drie: het adres in de spritepointer is relatief aan de bank**, niet aan
`$0000`. Vandaar de aftrekking in `SPRPTRBASE` hierboven.

### 20.2 Kleur-RAM valt niet te dubbelbufferen

Schermgeheugen mag overal in de bank staan, dus daar kun je twee buffers van
maken. Kleur-RAM zit vast op `$d800` en er is er precies één. Bij het
omschakelen moet die dus bijgewerkt worden terwijl de VIC hem uitleest.

Dat kan, door de raster voor te blijven: schrijf rij *r* voordat de VIC hem
tekent. Vul tijdens het renderen een schaduwbuffer in het werkgeheugen en
kopieer die in één keer naar `$d800`.

De cijfers die dat mogelijk maken, voor PAL:

| | cycli |
|---|---|
| de VIC doet over 24 tekstrijen | 12096 |
| voorsprong vanaf rasterlijn 256 tot rij 0 | 6741 |
| badlines en sprite-DMA kosten | 1416 |
| **beschikbaar** | **17421** |

Wat de kopie kost hangt volledig af van hoever je uitrolt:

| bytes per lusronde | cycli per byte | totaal voor 960 bytes | code |
|---|---|---|---|
| 1 | 14,0 | 13440 | 14 bytes |
| 4 | 11,8 | 11280 | 32 bytes |
| **8** | **10,4** | **9960** | **56 bytes** |
| 40 | 9,3 | 8904 | 248 bytes |

Acht bytes per ronde is het omslagpunt: bijna de snelheid van volledig
uitrollen, voor een fractie van de codegrootte.

```asm
blitColour: {
        ldx #$00
loop:   lda colShadow+0,x
        sta $d800+0,x
        lda colShadow+1,x
        sta $d800+1,x
        lda colShadow+2,x
        sta $d800+2,x
        lda colShadow+3,x
        sta $d800+3,x
        lda colShadow+4,x
        sta $d800+4,x
        lda colShadow+5,x
        sta $d800+5,x
        lda colShadow+6,x
        sta $d800+6,x
        lda colShadow+7,x
        sta $d800+7,x
        txa
        clc
        adc #$08
        tax
        bne loop                    // 256 bytes; herhaal per blok
        rts
}
```

Gebruik absolute adressering met `,x`. Indirecte adressering via `(zp),y`
kost 11 cycli per byte in plaats van 9 en dan haal je de raster niet meer.

**Reken dit na voor je het bouwt.** Een cyclusbegroting in Python is tien
minuten werk en voorkomt dat je een architectuur kiest die niet past. De
eerste schatting hier ging uit van volledig uitrollen en was daarmee 40% te
optimistisch.

### 20.3 `waitFrame` komt terug op rasterlijn 256, niet op 0

Dit is de klassieke misvatting bij de standaard framesync:

```asm
waitFrame: {
low:    lda $d012
        cmp #$80
        bcc low                     // wacht tot >= $80
high:   lda $d012
        cmp #$80
        bcs high                    // wacht tot < $80
        rts
}
```

`$d012` is acht bits en de PAL-raster telt tot 311. Lijnen 256-311 geven
`$d012` = 0-55, met bit 7 van `$d011` als negende bit. De overgang van
`>= $80` naar `< $80` valt dus bij lijn 256, in de **onderrand** — niet bij
lijn 0.

Dat is meestal juist gunstig: je krijgt 107 rasterlijnen voorsprong in plaats
van 51, en alles wat je vanaf dat punt schrijft komt volgend beeld netjes te
voorschijn. Maar reken er niet op dat je "bovenin" zit. Wil je echt lijn 0,
controleer dan ook `$d011` bit 7.

### 20.4 In bank 0 en 2 ziet de VIC het karakter-ROM op `$1000`

Het karakter-ROM verschijnt voor de VIC op `$1000-$1fff` en `$9000-$9fff`.
Zet je daar je eigen charset, bitmap of spritedata neer, dan zie je het
ROM-font en niet je eigen data — terwijl de CPU er wél gewoon leest en
schrijft. Er is geen foutmelding; je ziet alleen letters waar je grafiek had
verwacht.

Gebruik bank 1 of 3, of blijf uit die twee gebieden.

### 20.5 Een `virtual` blok bevat rommel tot je het zelf vult

```asm
        *=$c000 "Werkgeheugen" virtual
plyDir:         .byte 0
```

Die `.byte 0` is misleidend. Een virtual blok levert geen bytes op in de
`.prg`, dus wat er bij het opstarten staat is wat er toevallig in het RAM
lag. In VICE is dat een blokpatroon, op echte hardware willekeurig.

De fout die dit opleverde: `plyDir` werd alleen door de bewegingsroutine
geschreven. Vóór de eerste toetsaanslag las de sprite-routine dus rommel, en
werd de spritepointer een willekeurig getal. Resultaat: een verminkte sprite
die goed werd zodra je één keer een richting indrukte.

**Regel: elke variabele in een virtual blok hoort expliciet gezet te worden
in de init- of laadroutine.** Loop die lijst na, ook de variabelen waarvan je
"weet" dat ze toch wel gezet worden — dat weet je alleen voor het pad dat je
op dat moment in je hoofd hebt.

De checker vangt nu het simpele geval: gelezen maar nergens geschreven.
Variabelen die wél ergens geschreven worden maar niet vóór het eerste
gebruik, blijven jouw verantwoordelijkheid.

### 20.6 Zet sprites pas aan als ze een positie én een pointer hebben

```asm
        lda #%00000000              // alles uit
        sta $d015
        // ... posities, pointers en kleuren zetten ...
        lda spriteEnable,x          // en nu pas aanzetten
        sta $d015
```

Sprites aanzetten in de video-init en pas later positioneren geeft een korte
flits van een verdwaalde sprite op een willekeurige plek.

### 20.7 Bij dubbelbufferen: wees expliciet over welke buffer de achtergrond is

De valkuil is een omkering die er logisch uitziet:

```asm
// FOUT: draait de doelbuffer om vóór het renderen, waardoor je in de
// buffer tekent die op dat moment in beeld staat
        lda backBuf
        eor #$01
        sta backBuf
        lda #$01
        sta renderBusy
```

De omwisseling hoort bij het **omschakelen**, niet bij het starten van de
render:

```asm
        lda flipPending
        beq noFlip
        lda #$00
        sta flipPending
        lda backBuf                 // de zojuist gerenderde buffer wordt
        eor #$01                    // de voorgrond
        sta backBuf
        jsr showFront
        jsr blitColour
noFlip:
```

Symptoom van de foute versie: het scherm ziet er bij het laden goed uit, maar
zodra er iets ververst wordt zie je de hertekening rij voor rij over het
beeld lopen. Statisch niet te vinden — schrijf op papier welke buffer op welk
moment in beeld staat.

### 20.8 Tabellen doorlopen: tel de recordgrootte na

```asm
// warpregel = 5 bytes: x, y, doelkaart, doel-x, doel-y
next:   iny                         // vanaf hier 5 iny's
next2:  iny                         // vanaf hier 4: de eerste is al gedaan
        iny
        iny
        iny
        jmp loop
```

Met vier in plaats van vijf `iny`'s landt de teller midden in de vorige regel
en leest daar onzin. Het effect was subtiel: alleen de éérste regel van elke
tabel werd ooit gevonden. Met twee regels per tabel viel dat niet op; met
vier wel, en dan kwam de speler een gebouw niet meer uit.

Dit type fout is statisch niet te vinden — de data klopt, alleen de code die
erdoorheen loopt niet. **Simuleer de doorstapping in Python** op de echte
`.asm`-data, dan valt hij zonder te assembleren op:

```python
def find_warp(raw, cx, cy):
    """Loopt de tabel af zoals de assembly dat doet, inclusief stapgrootte."""
    y = 0
    while y < len(raw) and raw[y] != 0xff:
        if raw[y] == cx and raw[y + 1] == cy:
            return raw[y + 2], raw[y + 3], raw[y + 4]
        y += 5                      # WARP_SIZE
    return None
```

### 20.9 Met een camera zijn cel- en schermcoördinaten niet meer hetzelfde

Zolang de kaart één scherm is, mag je celpositie en schermpositie door elkaar
halen. Zodra er een camera bij komt niet meer:

```asm
// A = celkolom op de kaart -> pixX = schermpositie van de sprite
cellToPixelX: {
        sec
        sbc camCellX
        bcs onScreen
        lda #$ff                    // links buiten beeld: sprite verbergen
        sta pixX
        sta pixX+1
        rts
onScreen:
        cmp #VIEW_CELLS_W
        bcc ok
        lda #$ff                    // rechts buiten beeld
        sta pixX
        sta pixX+1
        rts
ok:     // ... * 16 en de sprite-offset erbij
}
```

Twee gevolgen die je makkelijk vergeet:

- **Botsingsdetectie kan niet meer uit het schermgeheugen lezen.** Met twee
  buffers is "welk char staat daar" niet eenduidig. Lees de kaartdata; die is
  toch de bron van de waarheid.
- **Sprites buiten beeld moeten expliciet verborgen worden**, anders duiken
  ze aan de verkeerde kant weer op.

Voor de beweging zelf: laat de speler stilstaan in beeld als de camera
meebeweegt, en laat hem lopen als de camera tegen een kaartrand vastzit.
Doe je allebei tegelijk, dan schuift de speler heen en weer bij elke stap.

### 20.10 Verifieer wat je niet kunt assembleren

Bij deze port was er in eerste instantie geen assembler beschikbaar. Drie
soorten controles vingen samen elke fout op één na:

1. **`c64_ka_syntax_checker.py`** — syntaxis, adresseringsmodi, branch-bereik,
   hardwarepatronen.
2. **Een simulatie van je eigen adresrekenkunde** in Python, die de echte
   `.asm`-data inleest. Render-, camera- en tabelroutines nabouwen en de
   uitkomst als ASCII tekenen legt fouten bloot die geen enkele
   syntaxcontrole ziet.
3. **Een cyclusbegroting** voor alles wat de raster moet bijhouden.

De enige fout die er doorheen kwam, was de bufferomkering uit §20.7 — die zit
in de volgorde van gebeurtenissen, niet in de code of de data.

### 20.11 Bewerk grote bestanden op ankers, niet op bereiken

Bij het omzetten van dit project naar een pixelcamera verving een script alles
tussen twee routines in één keer. Daar stonden twee andere routines tussenin,
en die verdwenen mee. De syntaxcheck zag er niets van — het bestand bleef
geldig — en pas de assembler struikelde over `Unknown symbol`.

Vervang een blok dus op de exacte begin- en eindtekst van dat blok, niet op
"alles van A tot B". En controleer na een grote wijziging welke routines er
nog in het bestand staan:

```
grep -n "^[a-zA-Z_][a-zA-Z0-9_]*: {" engine/overworld/player.asm
```

De checker vangt dit nu ook: zie §20.20.

### 20.12 Een hulproutine die X sloopt bevriest een indexlus

```asm
// FOUT: cellToScreenX gebruikte X als telraam voor een vermenigvuldiging
loop:   lda npcCellX,x
        jsr cellToScreenX           // zet X op nul
        lda npcCellY,x              // leest nu de verkeerde npc
        ...
        inx                         // X wordt 1
        cpx npcCount                // bereikt nooit 2
        bne loop                    // oneindige lus
```

Het gevolg was niet alleen een verkeerd uitgelezen tabel, maar een spel dat
volledig stilstond: de lus kwam er nooit meer uit. En omdat de NPC-registers
half beschreven achterbleven, stond er ook nog een sprite met een pointer die
nooit was gezet.

De goedkoopste oplossing is meestal om het telraam helemaal weg te laten. Een
vermenigvuldiging met 16 is vier keer schuiven; uitgerold kost dat geen enkel
register:

```asm
        asl tmpW
        rol tmpW+1
        asl tmpW
        rol tmpW+1
        asl tmpW
        rol tmpW+1
        asl tmpW
        rol tmpW+1
```

De checker waarschuwt hier nu voor: zie §20.13.

### 20.13 Leg verbanden tussen constanten vast met `.errorif`

Twee constanten die samen één ding beschrijven, gaan een keer uit elkaar
lopen. In dit project bepaalden `MOVE_FRAMES` en `PLAYER_SPEED` samen hoeveel
pixels een stap oplevert, en dat moest exact één cel van 16 px zijn:

```asm
.const CELL_PIXELS   = 16
.const MOVE_FRAMES   = 16
.const PLAYER_SPEED  = 1

// Zonder deze regel merk je pas veel later dat de logische positie en de
// zichtbare positie elke stap verder uit elkaar lopen.
.errorif [MOVE_FRAMES * PLAYER_SPEED != CELL_PIXELS],
         "MOVE_FRAMES * PLAYER_SPEED moet gelijk zijn aan CELL_PIXELS"
```

Toen `MOVE_FRAMES` per ongeluk op 8 bleef staan terwijl `PLAYER_SPEED` 1 was,
verzette elke stap de cel wel 16 px maar de sprite maar 8. Het spel zag er
volkomen normaal uit — het scrollen was zelfs vloeiend — maar de speler botste
tegen dingen die acht pixels verderop in beeld stonden, en liep dwars door
muren die er visueel wel waren. Na tien stappen is dat een halve cel, na
twintig een hele.

**Het patroon om te herkennen:** loopt er ergens een logische positie naast een
zichtbare positie, dan hoort er een assertie te staan die ze aan elkaar
knoopt. Dat geldt net zo goed voor scrollsnelheid tegen buffergrootte, of voor
een spritepointer tegen het adres waar de data staat.

**En bij het testen:** verander nooit constanten in de werkkopie om iets uit te
proberen. Deze fout ontstond doordat een tijdelijke wijziging niet volledig
werd teruggedraaid — het herstel matchte de regel niet meer omdat er een
commentaar achter stond. Werk op een kopie in een tijdelijke map.

### 20.14 Een statement past op een regel

Kick Assembler leest een directive per regel. Een argumentenlijst netjes
afbreken bij de komma lijkt logisch, maar levert een syntaxfout op:

```asm
// FOUT: 'Syntax error' op de komma aan het eind van de eerste regel
.errorif [MOVE_FRAMES * PLAYER_SPEED != CELL_PIXELS],
         "MOVE_FRAMES x PLAYER_SPEED moet CELL_PIXELS zijn"

// GOED
.errorif [MOVE_FRAMES * PLAYER_SPEED != CELL_PIXELS], "MOVE_FRAMES x PLAYER_SPEED moet CELL_PIXELS zijn"
```

Wil je het leesbaar houden, zet de uitleg dan in commentaar erboven en houd de
melding zelf kort. Regels langer dan tachtig tekens zijn hier het kleinere
kwaad.

### 20.15 Een dubbelbuffer heeft twee vragen, niet een

Bij het vooruit renderen van een schermbuffer moet je twee dingen apart
beantwoorden, en het is verleidelijk om ze te verwarren:

1. **Waar staat de camera nu?** Dat volgt uit de spelerpositie.
2. **Waar staat de camera straks?** Dat volgt uit de *camera*, niet uit de
   speler.

Die twee lopen uiteen zodra de camera tegen een kaartrand geklemd staat: de
speler beweegt dan wel, de camera niet. Een voorspelling die vanaf de speler
rekent wijst dan naar de plek waar de camera al staat, dus wordt de buffer
niet opnieuw getekend — en zodra de klem loslaat past hij niet meer bij de
camerastand.

```asm
// FOUT: acht pixels vooruit vanaf de speler
        lda plyPixX
        sta argPixX
        ...                         // +8 in de looprichting
        jsr camCompute              // trekt het vensterm-midden eraf en klemt

// GOED: acht pixels vooruit vanaf de camera zelf
        lda camPixX
        sta argPixX
        ...                         // +8 in de looprichting
        jsr camClampSplit           // alleen klemmen en splitsen
```

Splits de camerarekenkunde daarvoor in twee routines: een die het midden van
het venster aftrekt, en een die klemt en in charoorsprong plus fijn-scroll
splitst. De eerste hoort alleen bij vraag 1.

**En bouw een noodtak in.** Schakel alleen om als de klaarstaande buffer echt
bij de huidige camerastand hoort; klopt hij niet, plan hem dan opnieuw in in
plaats van toch om te schakelen. Zonder die controle wijkt de oorsprong na het
omschakelen nog steeds af en schakelt de lus het volgende frame opnieuw om —
elk frame, wat je als een hevig trillend beeld ziet.

Die noodtak is ook een prima meetpunt. Tel in een simulatie hoe vaak hij
vuurt: gaat dat aantal naar nul, dan klopt de voorspelling. Bij dit project
liep het van 132 keer per 3000 stappen naar 0.

### 20.16 "Wordt wel geschreven" is niet hetzelfde als "is gezet"

Dit is §20.5 nog een keer, maar in de vorm waarin hij het lastigst te vinden
is. Een variabele in een `virtual` blok die wel degelijk ergens geschreven
wordt — maar pas door code die op dat moment nog niet gedraaid heeft.

```asm
// De hoofdlus, elk frame:
        lda txtState                // staat het tekstvenster open?
        beq walking
        jsr textUpdate
        ...
walking:
        jsr updatePlayer
```

`txtState` wordt netjes gezet: in `openWindow`, in `textUpdate` en in
`closeWindow`. Alleen draait geen van die drie voordat er een venster open
staat. Bij het opstarten leest de hoofdlus dus rommel, en bij een waarde
ongelijk aan nul gaat elk frame naar `textUpdate` in plaats van naar
`updatePlayer`. Symptoom: de besturing doet helemaal niets, terwijl alles
schoon assembleert en het beeld normaal oogt.

**De vuistregel:** elke variabele in het virtual blok die de hoofdlus leest,
hoort in de initialisatie te staan. Niet "ergens", maar in de routine die
vóór de hoofdlus draait.

De checker vangt dit nu: hij bouwt uit de importboom op welke routine welke
variabelen schrijft, volgt de aanroepen vanaf `start:` tot `mainLoop:`, en
loopt daarna de hoofdlus regel voor regel af. Leest die een virtual-variabele
waar op dat punt nog niets in geschreven is, dan is dat een fout.

### 20.17 Hires of multicolor zit in het kleur-RAM, niet in de char

Een char is niet van zichzelf hires of multicolor. Dat bepaalt bit 3 van de
kleur-RAM-waarde op die schermpositie: laag is hires, hoog is multicolor. Zet
je dus een fontchar op het scherm zonder de kleur mee te schrijven, dan wordt
hij getekend met de waarde die daar nog stond — die van de kaart eronder.

Het gevolg is verraderlijk, want het is geen zwart scherm maar iets dat er
bijna uitziet. Elk bitpaar van de letter wordt één dubbelbrede pixel, en de
dunne streken van een letter worden daarmee losse stippels. Het venster
eromheen kan er ondertussen prima uitzien.

```asm
        sta (zpScr),y               // de char zelf
        lda #WHITE                  // en meteen de kleur, anders hires niet
        sta (zpCol),y               // <- moet naar $d800 wijzen
```

**Let op waar je pointer heen wijst.** Werk je met een schaduwbuffer voor
kleur-RAM, dan is schrijven naar die schaduw niet genoeg: de VIC leest
`$d800`. Schrijf naar het echte kleur-RAM, of naar allebei als er nog een
blit overheen kan komen.

### 20.18 Zet de dubbelbuffer stil zolang je erin tekent

Een tekstvenster of menu teken je in de schermbuffer. Draait de hoofdlus
ondertussen gewoon door met renderen en omschakelen, dan werkt die de
achtergrondbuffer bij uit de kaartdata — precies de buffer waar je net je
venster in hebt gezet. Bij de eerstvolgende omschakeling is het weg.

```asm
        jsr updateSprites

        lda txtState                // venster open: niet renderen,
        bne skipRender              // niet omschakelen
        ...
skipRender:
```

Zet bij het openen ook een lopende render stop:

```asm
        lda #$00
        sta renderBusy
        sta renderRow
```

En bij het sluiten bouw je beide buffers opnieuw op uit de kaartdata, want
allebei zijn ze beschreven.

**Het symptoom is misleidend.** Het lijkt of de knop niet werkt: er gebeurt
niets zichtbaars. Maar de routine draait wel degelijk, en het venster staat er
ook — een fractie van een seconde, tot de eerstvolgende omschakeling.

### 20.19 Een indirecte pointer moet in zeropage staan

`lda (ptr),y` en `lda (ptr,x)` bestaan alleen met een pointer in zeropage. De
6502 heeft geen indirecte modus met een 16-bits adres — behalve `jmp (abs)`.

```asm
// FOUT: txtPtr stond in het werkgeheugen op $c0xx
txtPtr:         .word 0
        ...
        lda (txtPtr),y

// GOED: in zeropage. $fb t/m $fe zijn de klassieke vrije bytes
.const txtPtr = $fb
```

Het vervelende is dat dit gewoon assembleert: het adres wordt afgekapt tot een
byte, en je leest van een zeropage-adres dat toevallig die lage byte is. De
routine draait dus, maar met gegevens die nergens op slaan.

Het symptoom in dit project: een tekstvenster dat zich vulde met willekeurige
tekens, nooit bij zijn eindmarkering uitkwam, en de speler daarmee opsloot.
Drie klachten uit één regel.

**Herkenningspunt:** loopt een routine wél maar met onzin, kijk dan eerst of
alle indirecte pointers in zeropage staan. De checker doet dat nu ook.

### 20.20 Wat `c64_ka_syntax_checker.py` hiervan zelf vangt

Sinds deze port controleert de checker ook:

- **Branch-bereik.** Een `bne` die meer dan 127 bytes moet overbruggen wordt
  gemeld met de afstand erbij en de fix uit §19.10. De grootte van elk
  statement wordt geschat; bij twijfel over zeropage versus absoluut komt er
  een waarschuwing in plaats van een fout.
- **`$dd00` zonder `$dd02`.** De VIC-bank omschakelen zonder de CIA-poort als
  uitgang te zetten.
- **Grafiek in `$1000-$1fff` of `$9000-$9fff`** terwijl het programma `$d018`
  schrijft — het schaduwgebied van het karakter-ROM uit §20.4.
- **Virtual variabelen die gelezen maar nergens geschreven worden**, over de
  hele importboom heen.
- **Virtual variabelen die de hoofdlus leest voordat de initialisatie ze heeft
  gezet** (§20.16). Dat is een ander geval: ze worden wél geschreven, maar te
  laat.
- **`jsr` of `jmp` naar een label dat nergens bestaat.** Alleen voor het
  hoofdbestand, want daar is via de imports het hele programma bereikbaar.
  De assembler vindt dit ook, maar pas ná de syntaxcheck en zonder te
  vertellen in welk bestand het label had moeten staan.
- **Een `jsr` naar een routine die X of Y overschrijft terwijl de aanroeper
  dat register nog nodig heeft.** Dat is de fout uit §20.12, en geen enkele
  assembler ziet hem.
- **Een directive waarvan de argumenten op een komma eindigen** en op de
  volgende regel doorlopen (§20.14).
- **Een indirecte pointer die niet in zeropage staat** (§20.19).
- **`.errorif`-voorwaarden**, alvast uitgerekend. Kick Assembler doet dat ook,
  maar pas bij het assembleren. Constanten uit geïmporteerde bestanden worden
  daarbij meegenomen, dus `.const`-waarden hoeven niet in hetzelfde bestand te
  staan.

Adressen achter `.const`- en `.label`-namen worden opgelost, dus de
hardwarecontroles werken ook als je `sta VMCSB` schrijft in plaats van
`sta $d018`.


---

*Gebaseerd op de Kick Assembler Reference Manual van Mads Nielsen (versie 5.x)
en op de C64-hardwaredocumentatie. Alle codevoorbeelden in dit document zijn
door `c64_ka_syntax_checker.py` gehaald zonder fouten. Secties 18, 19 en 20 bevatten
aanvullend patronen die daadwerkelijk met `KickAss.jar` zijn geassembleerd en
in VICE x64sc getest (zie `build/adventure.prg`, `build/pong.prg` en
`build/main.prg` uit c64red).*
