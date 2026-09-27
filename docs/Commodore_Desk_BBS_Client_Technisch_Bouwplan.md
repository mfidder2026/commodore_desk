# Commodore Desk – BBS Client
## Technisch bouwplan voor Kick Assembler

**Doelplatform:** Commodore 64 / Commodore Ultimate / VICE  
**Assembler:** Kick Assembler  
**Applicatie:** `BBS.PRG`  
**Integratie:** aparte applicatie binnen Commodore Desk met eigen desktop-icoon  
**Netwerkbasis:** bestaande werkende TCP-laag  
**Versie plan:** 1.0  
**Datum:** 27 september 2026

---

# 1. Doel

Bouw een zelfstandige BBS-client voor Commodore Desk waarmee de gebruiker rechtstreeks vanuit de desktop verbinding kan maken met Commodore- en retro-BBS-systemen.

De applicatie wordt een afzonderlijke PRG:

```text
BBS.PRG
```

Op de Commodore Desk desktop komt een apart BBS-icoon.

Bij openen van het icoon start de BBS-applicatie. De applicatie gebruikt de reeds bestaande TCP-netwerklaag van Commodore Desk.

De eerste versie bevat:

- BBS desktop-icoon
- aparte `BBS.PRG`
- adresboek met vooraf ingestelde BBS-systemen
- één geselecteerde/default BBS
- verbinden
- verbinding verbreken
- terminalvenster
- PETSCII-ondersteuning
- eenvoudige Telnet-negotiation
- toetsenbordinvoer
- statusweergave
- persistent opslaan van de default BBS
- veilige terugkeer naar Commodore Desk

Niet in versie 1:

- XMODEM
- YMODEM
- ZMODEM
- bestandsoverdracht
- volledige ANSI-art terminal
- SSH
- modememulatie
- meerdere gelijktijdige sessies
- gebruikersnamen/wachtwoorden opslaan

---

# 2. Architectuur

Gebruik de bestaande TCP-interface van Commodore Desk.

De BBS-client mag geen eigen Ethernet-, IP- of TCP-stack bouwen.

```text
COMMODORE DESK
      │
      ├── Mail
      ├── RSS
      ├── FTP
      ├── Chat
      └── BBS
           │
           ▼
        BBS.PRG
           │
           ├── Address Book
           ├── Telnet Parser
           ├── PETSCII Terminal
           ├── Keyboard Handler
           └── Session Manager
                 │
                 ▼
           NETWORK SOCKET API
                 │
        ┌────────┴────────┐
        │                 │
     VICE/RRNET       ULTIMATE/UCI
```

De BBS-client gebruikt alleen publieke netwerkfuncties zoals:

```asm
tcp_open
tcp_send
tcp_recv
tcp_close
net_poll
dns_lookup
```

Wanneer de bestaande netwerk-API andere functienamen gebruikt, maak dan een kleine adapter in:

```text
src/bbs/bbs_net.asm
```

Pas niet de bestaande netwerkstack aan tenzij technisch noodzakelijk.

---

# 3. Desktop-integratie

Voeg een nieuw applicatie-item toe aan Commodore Desk:

```text
Naam:       BBS
Executable: BBS.PRG
Type:       Application
```

Maak een apart desktop-icoon dat visueel past bij de bestaande Commodore Desk iconen.

Voorgesteld concept:

```text
CRT / terminal monitor
met kleine netwerkindicator
```

Gebruik dezelfde:

- icoonafmetingen
- sprite- of bitmapstructuur
- palette-regels
- selectie-indicator
- naampositionering

als andere Commodore Desk applicaties.

Geen afwijkend icoonformaat introduceren.

---

# 4. Bestandsstructuur

Gebruik bij voorkeur:

```text
src/
│
├── apps/
│   └── bbs/
│       ├── bbs.asm
│       ├── bbs_ui.asm
│       ├── bbs_session.asm
│       ├── bbs_addressbook.asm
│       ├── bbs_config.asm
│       ├── bbs_net.asm
│       ├── bbs_telnet.asm
│       ├── bbs_terminal.asm
│       ├── bbs_keyboard.asm
│       ├── bbs_petscii.asm
│       ├── bbs_ascii.asm
│       ├── bbs_buffers.asm
│       └── bbs_constants.asm
│
├── assets/
│   └── icons/
│       └── bbs.*
│
└── build/
    └── BBS.PRG
```

Als Commodore Desk al een andere conventie gebruikt: volg het bestaande platform.

---

# 5. Hoofdscherm

Bij starten verschijnt geen directe verbinding.

Voorbeeld:

```text
+--------------------------------------+
| BBS CLIENT                           |
+--------------------------------------+
| DEFAULT                              |
|                                      |
| THE OASIS BBS                        |
| oasisbbs.hopto.org:6400              |
|                                      |
| STATUS: NOT CONNECTED                |
|                                      |
| [ CONNECT ]                          |
| [ DISCONNECT ]                       |
| [ ADDRESS BOOK ]                     |
| [ SETTINGS ]                         |
| [ BACK TO DESKTOP ]                  |
+--------------------------------------+
```

Gebruik bestaande Commodore Desk UI-componenten. Bouw geen tweede GUI-framework.

---

# 6. Adresboek

Een BBS-record bevat minimaal:

```text
id
name
hostname
port
terminal_mode
enabled
```

Concept:

```asm
BBS_ENTRY_SIZE = ...

bbs_name_ptr
bbs_host_ptr
bbs_port_lo
bbs_port_hi
bbs_terminal_mode
bbs_flags
```

Gebruik pointers naar statische strings om RAM te besparen.

---

# 7. Initiële BBS-lijst

## 1. Commodore BBS Outpost

```text
Naam: Commodore BBS Outpost
Website: www.commodorebbs.com
Type: Directory
Connectable: NO
```

CBBS Outpost is een actuele Commodore BBS-directory, maar geen geverifieerd direct Telnet-endpoint. Neem hem op als informatie-entry en disable `CONNECT`.

## 2. Genetic-PET

```text
Naam: Genetic-PET
Host: g-point.tunk.org
Port: 1025
Terminal: PETSCII
Enabled: YES
```

## 3. The Oasis BBS

```text
Naam: The Oasis BBS
Host: oasisbbs.hopto.org
Port: 6400
Terminal: PETSCII
Enabled: YES
```

## 4. Microtown BBS

```text
Naam: Microtown BBS
Host: microtownbbs.com
Port: 6400
Terminal: PETSCII
Enabled: YES
```

## 5. Centronian BBS

```text
Naam: Centronian BBS
Host: bbs.centronian.ca
Port: 6400
Terminal: PETSCII
Enabled: YES
```

Gebruik niet het verouderde/onvolledige `servebeer.com`.

## 6. Particles! BBS

```text
Naam: Particles! BBS
Host: particlesbbs.dyndns.org
Port: 6400
Terminal: PETSCII
Enabled: YES
```

## 7. RapidFire

```text
Naam: RapidFire
Host: rapidfire.hopto.org
Port: 64128
Terminal: PETSCII
Enabled: YES
```

## 8. Reflections BBS

```text
Naam: Reflections BBS
Host: reflections.hopto.org
Port: 64128
Terminal: PETSCII
Enabled: YES
```

Gebruik niet meer `reflections.servebbs.com`.

## 9. Afterlife BBS

```text
Naam: Afterlife BBS
Host: afterlife.dynu.com
Port: 6400
Terminal: PETSCII
Enabled: YES
```

## 10. Mutiny Community

```text
Naam: Mutiny Community
Host: mutinybbs.com
Port: 2300
Terminal: AUTO / PETSCII
Enabled: YES
```

---

# 8. Default BBS

De gebruiker selecteert één adresboekitem. Na bevestiging wordt dit de `DEFAULT BBS`.

Voorbeeld:

```text
DEFAULT BBS

PARTICLES! BBS
particlesbbs.dyndns.org:6400
```

De default moet persistent worden opgeslagen.

---

# 9. Configuratiebestand

Maak bijvoorbeeld:

```text
BBS.CFG
```

Compact formaat:

```text
Byte 0   Magic "B"
Byte 1   Magic "B"
Byte 2   Config version
Byte 3   Default BBS ID
Byte 4   Local echo setting
Byte 5   Terminal setting
Byte 6   Reserved
Byte 7   Checksum
```

Minimaal moet de default BBS persistent zijn.

Bij ontbrekende of beschadigde configuratie: val terug op een compile-time default zonder crash.

---

# 10. Adresboek-UI

Voorbeeld:

```text
+--------------------------------------+
| BBS ADDRESS BOOK                     |
+--------------------------------------+
| > THE OASIS BBS                      |
|   GENETIC-PET                        |
|   MICROTOWN BBS                      |
|   CENTRONIAN BBS                     |
|   PARTICLES! BBS                     |
|   RAPIDFIRE                          |
|   REFLECTIONS BBS                    |
|   AFTERLIFE BBS                      |
|   MUTINY COMMUNITY                   |
|   COMMODORE BBS OUTPOST              |
|                                      |
| RETURN = SET DEFAULT                 |
| F1 = CONNECT                         |
| F7 = BACK                            |
+--------------------------------------+
```

Bij selectie:

1. update actieve selectie
2. schrijf ID naar `BBS.CFG`
3. toon korte bevestiging
4. keer terug naar hoofdscherm

---

# 11. Session Manager

Gebruik een state machine:

```text
BBS_STATE_IDLE
BBS_STATE_RESOLVING
BBS_STATE_CONNECTING
BBS_STATE_NEGOTIATING
BBS_STATE_CONNECTED
BBS_STATE_DISCONNECTING
BBS_STATE_ERROR
```

Geen lange blocking routines.

```asm
bbs_main_loop:
    jsr gui_poll
    jsr bbs_keyboard_poll
    jsr net_poll
    jsr bbs_session_poll
    jsr bbs_terminal_poll
    jmp bbs_main_loop
```

---

# 12. Verbinden

Bij `CONNECT`:

```text
1. controleer geselecteerde BBS
2. controleer enabled flag
3. resolve hostname
4. open TCP-verbinding
5. initialiseer Telnet parser
6. initialiseer terminal
7. ga naar CONNECTED state
```

Gebruik de bestaande TCP timeout- en foutafhandeling.

---

# 13. Verbindingsscherm

Voorbeeld:

```text
CONNECTING TO

THE OASIS BBS

oasisbbs.hopto.org:6400

RESOLVING HOST...
CONNECTING...
```

Na succes:

```text
CONNECTED
```

Daarna direct naar de terminal.

---

# 14. Full-duplex stream

```text
keyboard → tcp_send
tcp_recv → telnet parser → terminal renderer
```

```text
       KEYBOARD
          │
          ▼
   INPUT TRANSLATOR
          │
          ▼
       TCP SEND

       TCP RECV
          │
          ▼
    TELNET PARSER
          │
          ▼
 PETSCII/ASCII PARSER
          │
          ▼
 TERMINAL RENDERER
```

---

# 15. Telnet protocol

Veel BBS-systemen gebruiken Telnet over TCP. Een gewone raw byte-stream is dus niet genoeg.

Telnet gebruikt:

```text
IAC = $FF
```

Ondersteun minimaal:

```text
IAC DO
IAC DONT
IAC WILL
IAC WONT
IAC SB
IAC SE
IAC IAC
```

Telnet command bytes mogen nooit zichtbaar op het scherm verschijnen.

---

# 16. Telnet parser state machine

```text
TELNET_DATA
TELNET_IAC
TELNET_DO
TELNET_DONT
TELNET_WILL
TELNET_WONT
TELNET_SB
TELNET_SB_IAC
```

De parserstate moet behouden blijven wanneer een command sequence over meerdere TCP-packets verdeeld is.

---

# 17. Telnet options

Ondersteun minimaal:

```text
0   BINARY
1   ECHO
3   SUPPRESS-GO-AHEAD
24  TERMINAL-TYPE
31  NAWS
```

Voor PETSCII is `BINARY` belangrijk om alle 8 bits te behouden.

Onderhandel conservatief. Weiger onbekende opties correct via `DONT/WONT`.

---

# 18. Telnet negotiation policy

Aanbevolen:

```text
BINARY:
    accepteren

ECHO:
    server-side echo accepteren
    local echo uitschakelen

SUPPRESS-GO-AHEAD:
    accepteren

TERMINAL-TYPE:
    accepteren

NAWS:
    accepteren indien geïmplementeerd
```

---

# 19. Terminal Type

Bij `TERMINAL-TYPE SEND` antwoord:

```text
PETSCII
```

voor PETSCII-entries.

Maak terminal type configureerbaar per BBS-entry.

---

# 20. NAWS

Indien ondersteund, meld:

```text
WIDTH  = 40
HEIGHT = 25
```

alleen als de sessie daadwerkelijk 40x25 gebruikt.

---

# 21. PETSCII terminal

Versie 1 moet PETSCII goed ondersteunen.

Minimaal:

- letters
- cijfers
- leestekens
- carriage return
- cursorbeweging
- home
- clear screen
- reverse on/off
- kleuren
- delete/backspace
- cursor control waar praktisch

Gebruik bestaande Commodore Desk screen primitives als die beschikbaar zijn.

---

# 22. Terminalgebied

Aanbevolen:

```text
40 x 24 terminalregels
1 statusregel
```

Bijvoorbeeld:

```text
[24 regels BBS content]

CONNECTED  OASIS BBS       F7 DISCONNECT
```

Of gebruik fullscreen 40x25 als dat beter past binnen Commodore Desk.

---

# 23. PETSCII kleuren

Ondersteun standaard C64-kleuren:

```text
BLACK
WHITE
RED
CYAN
PURPLE
GREEN
BLUE
YELLOW
ORANGE
BROWN
LIGHT RED
DARK GREY
GREY
LIGHT GREEN
LIGHT BLUE
LIGHT GREY
```

---

# 24. Keyboard input

Ondersteun minimaal:

```text
A-Z
0-9
SPACE
RETURN
DELETE
cursor keys
function keys waar nodig
```

PETSCII-mode:

```text
keyboard → PETSCII byte
```

ASCII-mode:

```text
keyboard → ASCII byte
```

---

# 25. Local echo

Standaard:

```text
LOCAL ECHO = OFF
```

De meeste BBS-systemen echoën invoer zelf.

Maak eventueel een handmatige override beschikbaar in Settings.

---

# 26. Buffers

Gebruik ringbuffers.

Aanbevolen:

```text
RX ring buffer: 1024 bytes
TX ring buffer: 256 bytes
```

Als RAM krap is:

```text
RX: 512
TX: 128
```

Verwerk streamend. Wacht nooit op een volledig scherm.

---

# 27. Receive flow

```asm
bbs_receive_poll:
    jsr tcp_recv

next_byte:
    jsr telnet_parse_byte
    ; gewone terminaldata:
    jsr terminal_process_byte
    jmp next_byte
```

De Telnet parser moet packet-boundary-safe zijn.

---

# 28. Send flow

```text
keyboard
 ↓
input conversion
 ↓
telnet escaping
 ↓
TCP TX buffer
 ↓
tcp_send
```

Een echte data-byte `$FF` moet als Telnet-data worden escaped naar:

```text
$FF $FF
```

---

# 29. Disconnect

De gebruiker moet altijd handmatig kunnen verbreken.

Bijvoorbeeld:

```text
F7 = DISCONNECT
```

Flow:

```text
1. stop keyboard TX
2. tcp_close
3. clear buffers
4. reset Telnet parser
5. reset terminal state
6. status = DISCONNECTED
7. terug naar hoofdscherm
```

Geen C64-reset.

---

# 30. Remote disconnect

Wanneer de server de verbinding sluit:

```text
CONNECTION CLOSED BY REMOTE HOST

PRESS RETURN
```

Daarna terug naar hoofdscherm.

---

# 31. Lokale escape uit terminal

Er moet altijd een lokale toetscombinatie zijn die nooit naar de BBS wordt doorgestuurd.

Gebruik bijvoorbeeld een bestaande Commodore Desk systeemcombinatie of:

```text
C= + F7
```

Open dan:

```text
BBS SESSION

[ RESUME ]
[ DISCONNECT ]
[ BACK TO DESKTOP ]
```

---

# 32. Statusinformatie

Optioneel tijdens sessie:

```text
BBS naam
CONNECTED
RX bytes
TX bytes
connection time
```

Bijvoorbeeld:

```text
OASIS BBS  ONLINE  RX:12K TX:1K
```

---

# 33. Error model

Minimaal:

```text
BBS_ERR_NO_NETWORK
BBS_ERR_DNS
BBS_ERR_CONNECT_TIMEOUT
BBS_ERR_CONNECTION_REFUSED
BBS_ERR_REMOTE_CLOSED
BBS_ERR_TX
BBS_ERR_RX
BBS_ERR_PROTOCOL
BBS_ERR_CONFIG
BBS_ERR_BUFFER_OVERFLOW
```

Vertaal deze naar duidelijke UI-meldingen.

---

# 34. Geen credentials opslaan

Versie 1 slaat geen BBS-usernames of passwords op.

Login gebeurt interactief in de terminal.

---

# 35. Platformintegratie

Verplicht pad:

```text
Desktop → BBS icon → BBS.PRG
```

Bij afsluiten:

```text
BBS.PRG → Commodore Desk
```

Gebruik de bestaande application manager / launcher indien beschikbaar.

---

# 36. Applicatie lifecycle

Gebruik:

```text
bbs_init
bbs_run
bbs_shutdown
```

`bbs_init`:

```text
load config
init UI
init address book
init buffers
init terminal state
```

`bbs_shutdown`:

```text
disconnect indien nodig
flush config
release application state
return to desktop
```

---

# 37. Memory management

De BBS-client hoeft weinig RAM te gebruiken.

Belangrijkste data:

```text
terminal state
address book pointers
RX buffer
TX buffer
Telnet parser state
network socket state
UI state
```

Geen scrollback in versie 1.

---

# 38. PETSCII versus ANSI

Prioriteit:

```text
1. PETSCII
2. plain ASCII
3. ANSI later
```

Volledige VT100/ANSI is geen vereiste voor release 1.

---

# 39. Terminal mode per entry

Gebruik:

```text
TERMINAL_PETSCII
TERMINAL_ASCII
TERMINAL_AUTO
```

In versie 1 mag `AUTO` standaard PETSCII kiezen.

---

# 40. Centrale directorymodule

Plaats alle BBS entries in één tabel, bijvoorbeeld:

```text
bbs_directory.asm
```

Geen hosts verspreid door de code hardcoden.

---

# 41. Custom entries – toekomst

Ontwerp de datastructuur zo dat later kan worden toegevoegd:

```text
ADD BBS
EDIT BBS
DELETE BBS
```

Custom record:

```text
Name
Host
Port
Terminal mode
```

Builtin entries kunnen read-only zijn.

---

# 42. Directoryversie

Voeg toe:

```text
BBS_DIRECTORY_VERSION = 1
```

Hiermee kunnen adressen later worden bijgewerkt zonder configuratie te breken.

---

# 43. Milestone 1 – Desktop integration

Doel:

- nieuw BBS-icoon zichtbaar
- icoon selecteerbaar
- `BBS.PRG` start
- hoofdscherm verschijnt
- terugkeer naar desktop werkt

Nog geen netwerk.

---

# 44. Milestone 2 – Address Book

Implementeer:

- ingebouwde BBS-lijst
- selectie
- default BBS
- `BBS.CFG`
- opnieuw starten behoudt default

Test:

```text
selecteer Particles!
sluit BBS
start opnieuw
default = Particles!
```

---

# 45. Milestone 3 – Raw TCP terminal

Implementeer:

```text
CONNECT
tcp_open
tcp_recv
tcp_send
DISCONNECT
```

Doel:

```text
bytes ontvangen
bytes tonen
keyboard bytes versturen
```

---

# 46. Milestone 4 – Telnet parser

Implementeer:

```text
IAC
DO
DONT
WILL
WONT
SB
SE
```

Test expliciet split sequences over meerdere TCP-packets.

---

# 47. Milestone 5 – PETSCII terminal

Implementeer:

- clear
- home
- cursor
- kleuren
- reverse
- CR
- delete
- keyboard PETSCII

Test tegen minimaal:

```text
The Oasis BBS
Particles! BBS
Centronian BBS
```

---

# 48. Milestone 6 – Production session flow

Implementeer:

- connection screen
- timeout
- remote close
- local disconnect
- session escape menu
- foutmeldingen
- terugkeer naar hoofdscherm

---

# 49. Milestone 7 – Hardwaretest

Test dezelfde `BBS.PRG` op:

```text
VICE
```

en:

```text
Commodore Ultimate
```

Applicatiecode moet identiek blijven. Platformverschillen horen onder de bestaande Network Socket API.

---

# 50. VICE testmatrix

Test minimaal:

```text
The Oasis BBS
  oasisbbs.hopto.org:6400

Particles! BBS
  particlesbbs.dyndns.org:6400

Genetic-PET
  g-point.tunk.org:1025

RapidFire
  rapidfire.hopto.org:64128
```

Controleer indien nodig met Wireshark:

```text
DNS
TCP handshake
payload
FIN/RST
```

---

# 51. Ultimate testmatrix

Test dezelfde hosts op echte Commodore Ultimate hardware.

Controleer:

- hostname resolution
- verbinding
- continue RX
- keyboard TX
- lange sessie
- remote disconnect
- lokale disconnect
- opnieuw verbinden zonder reboot

---

# 52. Performance

BBS-terminalprioriteiten:

```text
correctheid
lage latency
geen verloren bytes
responsieve UI
```

Maximale throughput is secundair.

---

# 53. Flow control

Als RX-buffer bijna vol is:

```text
stop tijdelijk met verder lezen uit socket
```

Laat de terminalrenderer eerst bytes verwerken.

Geen bytes stil weggooien.

---

# 54. Debug mode

Compile-time:

```text
BBS_DEBUG = true
BBS_DEBUG_TELNET = true
```

Log bijvoorbeeld:

```text
state
hostname
port
resolved IP
socket status
RX count
TX count
Telnet command
Telnet option
buffer fill
```

Voorbeeld:

```text
RX IAC WILL ECHO
TX IAC DO ECHO
```

---

# 55. Telnet parsertests

Test minimaal:

```text
normal PETSCII data
IAC WILL ECHO
IAC DO BINARY
IAC WONT
IAC DONT
IAC IAC
subnegotiation
split IAC over packets
meerdere commands in één packet
```

---

# 56. Robuustheid

Netwerkinput is onbetrouwbaar.

Controleer altijd:

```text
buffer boundaries
subnegotiation lengths
invalid control bytes
unexpected disconnects
```

Een malformeerde BBS-stream mag nooit leiden tot memory corruption of een desktopcrash.

---

# 57. Toekomstige uitbreiding – XMODEM

Later kan worden toegevoegd:

```text
XMODEM receive
XMODEM send
```

Architectuur:

```text
BBS SESSION
    │
    ├── Terminal
    └── XMODEM
          │
          └── Commodore Desk filesystem
```

Niet in release 1.

---

# 58. Toekomstige uitbreiding – History/Favorites

Later:

```text
Favorites
Recent BBS
Last connected
Connection counter
```

---

# 59. Toekomstige uitbreiding – Online directory

CBBS Outpost kan later als bron dienen voor een dynamische BBS-directory.

```text
BBS ADDRESS BOOK
    │
    ├── BUILT-IN
    ├── CUSTOM
    └── ONLINE DIRECTORY
```

Release 1 gebruikt uitsluitend statische entries.

---

# 60. Definition of Done – Release 1.0

Release 1.0 is gereed wanneer:

1. BBS-icoon op Commodore Desk aanwezig is.
2. `BBS.PRG` als zelfstandige applicatie start.
3. Adresboek opent.
4. De gebruiker een BBS kan selecteren.
5. De selectie persistent als default wordt opgeslagen.
6. `CONNECT` verbinding maakt met de geselecteerde BBS.
7. Hostnamen via de bestaande netwerklaag worden opgelost.
8. TCP RX/TX stabiel werkt.
9. Telnet IAC-negotiation correct wordt verwerkt.
10. PETSCII-terminal bruikbaar is.
11. Keyboardinput naar de BBS wordt verzonden.
12. De gebruiker handmatig kan disconnecten.
13. Remote disconnect correct wordt afgehandeld.
14. Na disconnect opnieuw verbinden mogelijk is.
15. De gebruiker veilig naar Commodore Desk kan terugkeren.
16. Dezelfde applicatie onder VICE en op Commodore Ultimate werkt.
17. Geen netwerkcode wordt gedupliceerd uit de bestaande TCP-stack.
18. Geen BBS-wachtwoorden persistent worden opgeslagen.

---

# 61. Aanbevolen implementatievolgorde

Werk in deze volgorde:

```text
01 Desktop icon
02 BBS.PRG skeleton
03 main UI
04 address book
05 persistent default
06 session state machine
07 raw TCP connect
08 raw RX/TX terminal
09 Telnet IAC parser
10 PETSCII output
11 PETSCII keyboard
12 local disconnect
13 remote disconnect
14 error handling
15 VICE tests
16 Ultimate tests
17 polish
```

Eerst de kernterminal stabiel maken; pas daarna ANSI, XMODEM of downloads.

---

# 62. Eerste concrete AI-developmentopdracht

Start uitsluitend met Increment 1.

## Increment 1

Bouw:

```text
BBS desktop icon
BBS.PRG
BBS main window
Address Book window
Default BBS selection
BBS.CFG persistence
Back to Desktop
```

Nog geen netwerkverbinding.

Daarna:

```text
Increment 2: TCP connect/disconnect
Increment 3: Telnet parser
Increment 4: PETSCII terminal
```

---

# 63. Eindarchitectuur

```text
                   COMMODORE DESK
                         │
                    [ BBS ICON ]
                         │
                         ▼
                      BBS.PRG
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ADDRESS BOOK      SESSION UI       SETTINGS
        │                │
   DEFAULT BBS            │
                         ▼
                  SESSION MANAGER
                         │
             ┌───────────┴───────────┐
             │                       │
        KEYBOARD TX              NETWORK RX
             │                       │
             ▼                       ▼
      PETSCII/ASCII           TELNET PARSER
             │                       │
             ▼                       ▼
         TCP SEND             PETSCII TERMINAL
             │                       │
             └───────────┬───────────┘
                         │
                  NETWORK SOCKET API
                         │
              ┌──────────┴──────────┐
              │                     │
            VICE                 ULTIMATE
          RR-NET/TCP              UCI/TCP
```

De kernregel:

**De BBS-client implementeert sessie-, Telnet- en terminalgedrag, maar gebruikt uitsluitend de bestaande Commodore Desk Network Socket API voor DNS en TCP.**

---

# 64. Centrale initiële directory

```text
ID  NAME                    HOST                           PORT   MODE       CONNECT
01  Commodore BBS Outpost   www.commodorebbs.com          -      DIRECTORY  NO
02  Genetic-PET             g-point.tunk.org               1025   PETSCII    YES
03  The Oasis BBS           oasisbbs.hopto.org             6400   PETSCII    YES
04  Microtown BBS           microtownbbs.com               6400   PETSCII    YES
05  Centronian BBS          bbs.centronian.ca              6400   PETSCII    YES
06  Particles! BBS          particlesbbs.dyndns.org        6400   PETSCII    YES
07  RapidFire               rapidfire.hopto.org            64128  PETSCII    YES
08  Reflections BBS         reflections.hopto.org          64128  PETSCII    YES
09  Afterlife BBS           afterlife.dynu.com             6400   PETSCII    YES
10  Mutiny Community        mutinybbs.com                  2300   AUTO       YES
```

Deze lijst moet centraal in één directorymodule staan zodat adressen later eenvoudig kunnen worden bijgewerkt.
