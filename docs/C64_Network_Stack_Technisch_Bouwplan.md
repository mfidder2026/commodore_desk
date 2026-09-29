# Technisch bouwplan – C64 Network Stack & Internet Applications

## 1. Doel

Ontwikkel in Kick Assembler een modulaire netwerklaag voor de Commodore 64 die gebruikt kan worden vanuit onze eigen GUI.

De software moet uiteindelijk minimaal de volgende toepassingen ondersteunen:

- PING
- RSS-reader, tekst-only
- FTP-client
- e-mailclient via IMAP
- AI Chat via HTTPS/API, bijvoorbeeld OpenAI

De implementatie moet werken op:

1. VICE Emulator
   - RR-Net compatibility mode
   - CS8900 Ethernet emulatie
   - eigen Ethernet/IP/TCP-stack op de 6510

2. Commodore Ultimate / Ultimate 64 / C64 Ultimate
   - ingebouwde Ethernetinterface
   - Ultimate Command Interface, UCI
   - TCP/UDP via de Ultimate firmware

De GUI en applicatielaag mogen geen kennis hebben van het onderliggende netwerkdevice.

---

# 2. Belangrijk architectuurprincipe

Gebruik één uniforme socket/API-laag:

```text
APPLICATIONS
│
├── PING
├── RSS
├── FTP
├── IMAP
└── CHAT
    │
    ▼
NETWORK API
│
├── net_init
├── net_poll
├── dns_lookup
├── tcp_open
├── tcp_send
├── tcp_recv
├── tcp_close
├── udp_open
└── ping
    │
    ├───────────────────────────────┐
    ▼                               ▼
VICE/RR-NET                    ULTIMATE/UCI
    │                               │
CS8900                         UCI Network target
    │                               │
Ethernet/IP/TCP                Ultimate firmware TCP/IP
```

Dit betekent dat bijvoorbeeld de RSS-client uitsluitend dit mag doen:

```asm
jsr dns_lookup
jsr tcp_open
jsr tcp_send
jsr tcp_recv
jsr tcp_close
```

De RSS-client mag niet weten of deze onder VICE of op de Ultimate draait.

---

# 3. Technische uitgangspunten

Gebruik Kick Assembler.

Gebruik expliciet:

```asm
.cpu _6502NoIllegals
```

Vermijd undocumented/illegal opcodes zodat dezelfde code robuust blijft op verschillende C64-implementaties.

Kick Assembler ondersteunt hiervoor expliciet de standaard 6502-instructieset via `.cpu _6502NoIllegals`.

Primaire build-output:

```text
network-test.prg
```

Later eventueel:

```text
application.prg
application.crt
```

Ontwikkel eerst als PRG.

---

# 4. Repositorystructuur

Gebruik minimaal:

```text
src/
│
├── main.asm
├── config.asm
├── memory.asm
│
├── net/
│   ├── net.asm
│   ├── socket.asm
│   ├── dns.asm
│   ├── checksum.asm
│   ├── ethernet.asm
│   ├── arp.asm
│   ├── ipv4.asm
│   ├── icmp.asm
│   ├── udp.asm
│   └── tcp.asm
│
├── drivers/
│   ├── driver.asm
│   ├── rrnet.asm
│   ├── cs8900.asm
│   └── ultimate.asm
│
├── protocols/
│   ├── http.asm
│   ├── ftp.asm
│   ├── rss.asm
│   ├── xml.asm
│   ├── imap.asm
│   ├── mime.asm
│   ├── json.asm
│   └── tls.asm
│
├── apps/
│   ├── ping.asm
│   ├── rss.asm
│   ├── ftp.asm
│   ├── mail.asm
│   └── chat.asm
│
├── text/
│   ├── ascii.asm
│   ├── utf8.asm
│   └── petscii.asm
│
├── util/
│   ├── string.asm
│   ├── number.asm
│   ├── timer.asm
│   ├── debug.asm
│   └── buffer.asm
│
└── tests/
    ├── checksum.asm
    ├── packet.asm
    └── parser.asm
```

---

# 5. Hardware abstraction

Definieer één netwerkdrivercontract.

Bijvoorbeeld:

```asm
net_driver_init:
net_driver_poll:

net_driver_send_frame:
net_driver_receive_frame:

net_driver_tcp_open:
net_driver_tcp_send:
net_driver_tcp_recv:
net_driver_tcp_close:

net_driver_udp_open:
net_driver_udp_send:
net_driver_udp_recv:
```

Niet iedere backend hoeft iedere low-level functie te implementeren.

## VICE backend

VICE/RR-Net gebruikt:

```text
send_frame
receive_frame
```

Daarboven implementeren wij zelf:

```text
ARP
IPv4
ICMP
UDP
TCP
DNS
```

## Ultimate backend

Ultimate gebruikt UCI direct voor:

```text
TCP open
TCP read
TCP write
TCP close
UDP
```

De Ultimate-firmware verzorgt daar dus de onderste protocolstack.

Bestaande Ultimate-bibliotheken tonen reeds functies van het type:

```text
uci_tcp_connect
uci_socket_read
uci_socket_write
uci_socket_close
```

waardoor bewezen is dat C64-programma's via UCI rechtstreeks TCP-verbindingen kunnen gebruiken.

---

# 6. Platformdetectie

Bij startup:

```text
1. probeer Ultimate UCI te detecteren
2. indien gevonden:
      PLATFORM = ULTIMATE
3. anders:
      probeer CS8900/RR-Net
4. indien gevonden:
      PLATFORM = RRNET
5. anders:
      NETWORK unavailable
```

Bij Ultimate:

controleer UCI identification register.

De officiële interface gebruikt normaliter:

```text
$DF1C control/status
$DF1D command/identification
$DF1E response data
$DF1F status data
```

Het identification register op `$DF1D` retourneert volgens de huidige documentatie `$C9`.

Ontwikkel de detectie wel defensief, omdat er software bestaat die tevens `$DE1C-$DE1F` detecteert wanneer `$DFxx` conflicteert met cartridges.

---

# 7. VICE-configuratie

## Vereisten Windows

Installeer:

- actuele VICE-versie
- Npcap
- Npcap met WinPcap compatibility mode

VICE gebruikt Npcap/libpcap voor raw Ethernet-toegang.

## VICE-instellingen

Open:

```text
Settings / Preferences
→ Peripheral Devices
→ Ethernet
```

Selecteer:

```text
Driver: pcap
Interface: actieve fysieke netwerkadapter
```

Bij voorkeur voor eerste tests:

```text
bekabelde Ethernetinterface
```

in plaats van Wi-Fi.

Daarna:

```text
Settings
→ Cartridge
→ Ethernet Cartridge
```

Activeer:

```text
Enable Ethernet Cartridge = ON
RR-Net compatibility mode = ON
I/O base = $DE00
```

Indien de GUI-optie ontbreekt, is de gebruikte VICE-build zonder Ethernetondersteuning gebouwd.

---

# 8. Eerste netwerkconfiguratie

Begin zonder DHCP.

Gebruik compile-time of configuratievariabelen:

```text
IP:
192.168.1.64

NETMASK:
255.255.255.0

GATEWAY:
192.168.1.1

DNS:
1.1.1.1

MAC:
02:64:64:00:00:01
```

Gebruik een locally administered MAC:

```text
02:xx:xx:xx:xx:xx
```

Maak dit later configureerbaar.

Geen DHCP implementeren voordat de fundamentele stack stabiel is.

---

# 9. Memory management

De software moet ontworpen worden voor streaming.

Nooit:

```text
complete HTTP response in RAM
complete RSS feed in RAM
complete email in RAM
complete JSON response in RAM
```

Gebruik gedeelde buffers.

Voorstel:

```text
$0801     BASIC loader

$1000     program code

$C000     network workspace

$C000-$C5FF RX packet buffer
$C600-$CBFF TX packet buffer
$CC00-$CFFF protocol/parser buffers
```

Exacte memory map eerst valideren tegen de GUI.

Maak daarom in:

```text
memory.asm
```

alle geheugenblokken configureerbaar.

---

# 10. Fase 1 – RR-Net / CS8900 hardwaredriver

Doel:

VICE Ethernet hardware aanspreken.

Implementeren:

```text
cs8900_detect
cs8900_reset
cs8900_init
cs8900_set_mac
cs8900_tx
cs8900_rx
cs8900_rx_available
```

Base address:

```text
$DE00
```

Geen hogere protocollen implementeren voordat:

```text
CS8900 detected
TX werkt
RX werkt
```

Debugmode moet registerwaarden op het scherm kunnen tonen.

---

# 11. Fase 2 – Ethernet

Implementeer Ethernet II frames.

Header:

```text
Destination MAC  6
Source MAC       6
EtherType        2
Payload
```

Ondersteun minimaal:

```text
$0806 ARP
$0800 IPv4
```

Interfaces:

```asm
eth_send
eth_receive
eth_get_type
```

---

# 12. Fase 3 – ARP

Implementeren:

```text
ARP request
ARP reply parser
ARP cache
```

Begin met één ARP-cache-entry:

```text
IP
MAC
valid
timeout
```

Voor gateway access:

```text
destination lokaal subnet:
    resolve destination IP

destination extern:
    resolve gateway IP
```

Acceptatie:

```text
C64 stuurt ARP:
Who has 192.168.1.1?

router antwoordt

C64 toont:
192.168.1.1 = AA:BB:CC:DD:EE:FF
```

---

# 13. Fase 4 – IPv4

Alleen IPv4.

Geen IPv6.

Ondersteun:

```text
Version = 4
IHL = 5
TTL
Protocol
Source address
Destination address
Header checksum
```

In eerste versie:

```text
geen IP fragmentation
geen IP options
```

Ontvang gefragmenteerde pakketten niet.

Laat stack foutcode retourneren:

```text
NET_ERR_FRAGMENTED
```

---

# 14. Fase 5 – checksumlibrary

Bouw één generieke 16-bit one's-complement checksumfunctie.

Gebruik voor:

```text
IPv4
ICMP
TCP
UDP
```

Deze code moet afzonderlijk testbaar zijn.

Voorzie testvectors.

Geen volgende fase voordat checksums reproduceerbaar correct zijn.

---

# 15. Fase 6 – ICMP / PING

Implementeren:

```text
ICMP Echo Request
ICMP Echo Reply
```

Types:

```text
8 = Echo Request
0 = Echo Reply
```

Payload bijvoorbeeld:

```text
FREMEN C64 NETWORK
```

Interface:

```asm
ping_start
ping_poll
ping_result
```

Niet blocking gedurende meerdere seconden.

Gebruik een state machine:

```text
IDLE
ARP
SEND
WAIT
SUCCESS
TIMEOUT
```

GUI moet dus door kunnen blijven draaien.

Resultaat:

```text
PING 192.168.1.1

REPLY 12 MS
REPLY 11 MS
REPLY 13 MS
REPLY 11 MS

SENT:     4
RECEIVED: 4
LOST:     0
```

Millisecondeweergave hoeft niet extreem nauwkeurig te zijn.

---

# 16. PING op Ultimate

De ingebouwde Ethernetpoort van de Ultimate is niet RR-Net-compatible.

Gebruik daarom niet:

```text
$DE00 CS8900
```

op de Ultimate.

Onderzoek eerst of de actuele UCI Network target een native ICMP/PING-opdracht aanbiedt.

Als deze bestaat:

```text
implementeer ultimate_ping
```

Als deze niet bestaat:

- behoud echte ICMP PING voor RR-Net/VICE
- geef op Ultimate geen nep-ICMP-resultaat
- gebruik eventueel een apart `connection test` via TCP als diagnostische functie

Maak expliciet onderscheid tussen:

```text
ICMP PING
TCP connection test
```

---

# 17. Fase 7 – UDP

Implementeren op RR-Net backend:

```text
UDP header
source port
destination port
length
checksum
```

Voor IPv4 mag voor de eerste versie UDP-checksum desnoods nul zijn, maar implementeer hem uiteindelijk wel.

Gebruik UDP primair voor DNS.

---

# 18. Fase 8 – DNS

Ondersteun alleen eenvoudige:

```text
A record
```

Dus:

```text
api.openai.com → IPv4
example.com → IPv4
```

Geen:

```text
AAAA
DNSSEC
SRV
TXT
```

Parser moet compression pointers ondersteunen.

Interface:

```asm
dns_lookup
```

Input:

```text
hostname pointer
```

Output:

```text
4-byte IPv4
```

Caching:

```text
max 4 DNS records
```

---

# 19. Fase 9 – TCP

Dit is de grootste eigen protocolfase voor RR-Net.

Implementeren:

```text
SYN
SYN/ACK
ACK

data
ACK

FIN
ACK
```

States minimaal:

```text
CLOSED
SYN_SENT
ESTABLISHED
FIN_WAIT
CLOSE_WAIT
LAST_ACK
```

Ondersteun:

```text
sequence numbers
acknowledgement numbers
TCP checksum
retransmission
receive window
timeout
```

Eerste versie:

```text
1 actieve TCP-verbinding
IPv4-only
geen TCP options behalve minimaal MSS indien nodig
geen out-of-order receive buffering
geen SACK
geen window scaling
geen timestamps
```

Bij out-of-order:

```text
discard
ACK laatste geldige sequence
```

Gebruik geen gigantische TCP-window.

Bijvoorbeeld:

```text
RX window: 1024 bytes
```

---

# 20. Uniform TCP-contract

Applicaties gebruiken:

```asm
tcp_open

; input:
; hostname/IP
; port

tcp_send

; input:
; pointer
; length

tcp_recv

; output:
; pointer
; length

tcp_close
```

De backendrouter kiest:

```text
RR-Net:
    eigen TCP-stack

Ultimate:
    UCI TCP
```

---

# 21. Ultimate UCI backend

Schrijf deze code opnieuw in Kick Assembler.

Gebruik bestaande C/cc65 libraries uitsluitend als:

```text
protocolreferentie
gedragsreferentie
command-byte referentie
```

Niet direct kopiëren zonder licentieanalyse.

UCI gebruikt command-, response- en statusqueues.

Implementeren:

```text
uci_detect
uci_wait_idle
uci_send_command
uci_read_response
uci_read_status
uci_abort
```

Daarboven:

```text
ultimate_tcp_open
ultimate_tcp_send
ultimate_tcp_recv
ultimate_tcp_close
ultimate_udp_*
```

---

# 22. Ultimate instellingen

Op de Ultimate:

```text
F2
→ C64 and Cartridge Settings
→ Command Interface
→ Enabled
```

Daarna:

```text
F2
→ Network Settings
```

Configureer bij voorkeur:

```text
Use DHCP = Enabled
```

of handmatig:

```text
Static IP
Static Netmask
Static Gateway
```

Verbind fysieke Ethernetkabel.

Test eerst vanaf ander systeem of Ultimate op het LAN bereikbaar is.

---

# 23. Fase 10 – HTTP/1.1

Implementeer eigen HTTP-client bovenop onze uniforme TCP-interface.

Ondersteun:

```text
GET
POST
Host
Content-Type
Content-Length
Connection: close
User-Agent
```

Niet beginnen met:

```text
HTTP/2
HTTP/3
gzip
brotli
cookies
redirect chains
```

Ondersteun later:

```text
301
302
307
308
```

met maximaal bijvoorbeeld 3 redirects.

Gebruik standaard:

```text
Connection: close
```

---

# 24. Streaming HTTP parser

Parser moet byte voor byte werken.

States:

```text
STATUS_LINE
HEADERS
BODY
DONE
ERROR
```

Ondersteun minimaal:

```text
Content-Length
Content-Type
Transfer-Encoding: chunked
Location
```

---

# 25. Fase 11 – RSS

RSS is de eerste echte internetapplicatie.

Ondersteun:

```text
RSS 2.0
```

Later eventueel Atom.

Lees alleen:

```xml
<title>
<description>
<link>
<pubDate>
```

Streaming XML-parser.

Geen DOM.

Geen volledige feed opslaan.

Per item bijvoorbeeld:

```text
Title:       80 bytes
Description: 512 bytes
Date:        40 bytes
URL:         160 bytes
```

Maximaal bijvoorbeeld:

```text
10 items
```

of sla alleen indexmetadata op en laad itemdetails on demand.

---

# 26. HTML-stripper

RSS description bevat vaak HTML.

Implementeren:

```text
<tag> → verwijderen
```

Ondersteun entities:

```text
&amp;
&lt;
&gt;
&quot;
&apos;
&nbsp;
```

Negeer:

```text
<img>
<script>
<style>
```

Uitvoer uitsluitend platte tekst.

---

# 27. UTF-8 naar PETSCII

Bouw eenvoudige streaming UTF-8 decoder.

Ondersteun:

```text
ASCII rechtstreeks
```

Voor West-Europese karakters:

```text
é → e
ë → e
è → e
á → a
ö → o
ü → u
```

Andere Unicode:

```text
?
```

Bijvoorbeeld:

```text
“text” → "text"
– → -
— → -
€ → EUR
```

Niet proberen volledige Unicode op de C64 te implementeren.

---

# 28. Fase 12 – FTP

Gebruik klassieke FTP.

Control connection:

```text
TCP port 21
```

Ondersteun:

```text
USER
PASS
PWD
CWD
TYPE I
PASV
LIST
RETR
STOR
QUIT
```

Gebruik uitsluitend passive mode.

Geen active FTP.

Data connection wordt tweede TCP-verbinding.

Voorkeur:

```text
socket 0 = FTP control
socket 1 = FTP data
```

---

# 29. Geen FTPS in eerste FTP-versie

Eerste FTP-client ondersteunt:

```text
plain FTP
```

TLS wordt later toegevoegd.

Maak in GUI duidelijk:

```text
UNENCRYPTED CONNECTION
```

Gebruik dit primair tegen vertrouwde/private FTP-servers.

---

# 30. Fase 13 – TLS

Dit is een afzonderlijk subproject.

Niet beginnen voordat:

```text
PING
DNS
TCP
HTTP
RSS
FTP
```

stabiel zijn.

Doel:

```text
HTTPS
IMAPS
eventueel FTPS
```

Begin met exact één TLS-profiel.

Onderzoek eerst welke cipher suite praktisch haalbaar is op 6510 en compatible is met de gewenste servers.

Modules waarschijnlijk:

```text
SHA-256
HMAC
HKDF
AES
AES-GCM
elliptic curve operations
TLS record layer
TLS handshake
certificate parser
```

Dit is verreweg het zwaarste onderdeel van de volledige roadmap.

---

# 31. Ultimate HTTP-optimalisatie

Op recente Ultimate-firmware bestaat naast de Network target ook een HTTP-client target.

Ontwerp daarom twee mogelijke Ultimate-modi:

```text
ULTIMATE_SOCKET_MODE
ULTIMATE_HTTP_MODE
```

Voor maximale compatibiliteit gebruiken applicaties eerst:

```text
ULTIMATE_SOCKET_MODE
```

Later kan RSS/Chat eventueel gebruikmaken van de firmware HTTP-client.

Dit mag echter geen afhankelijkheid van de applicatielaag worden.

---

# 32. Fase 14 – IMAP

Na TLS.

Ondersteun minimale IMAP-functionaliteit:

```text
LOGIN / AUTHENTICATE
SELECT INBOX
SEARCH
FETCH
LOGOUT
```

Voor eerste versie:

```text
alleen INBOX
alleen lezen
geen verwijderen
geen verplaatsen
geen schrijven
```

Gebruik voor berichten:

```text
BODY.PEEK
```

zodat mail niet onbedoeld als gelezen wordt gemarkeerd.

Geen:

```text
STORE
DELETE
EXPUNGE
```

---

# 33. Maildata

Lees aanvankelijk alleen:

```text
From
To
Date
Subject
text/plain body
```

Negeer:

```text
attachments
HTML rendering
embedded images
calendar invites
PGP
S/MIME
```

MIME-parser hoeft initieel alleen:

```text
text/plain
quoted-printable
base64
multipart/alternative
```

te ondersteunen.

Bij:

```text
multipart/alternative
```

kies:

```text
text/plain
```

boven:

```text
text/html
```

---

# 34. Fase 15 – HTTPS API / AI Chat

Wanneer HTTPS werkt:

```text
DNS
TCP
TLS
HTTP
JSON
```

kan de Chat-app een API gebruiken.

De Chat-app mag niet afhankelijk zijn van OpenAI-specifieke logica in de netwerklaag.

Architectuur:

```text
chat.asm
   │
openai.asm
   │
http.asm
   │
tls.asm
   │
tcp.asm
```

OpenAI-specifieke client:

```text
protocols/openai.asm
```

API-key moet door gebruiker configureerbaar zijn.

Nooit een gedeelde productie-API-key in de binary opnemen.

---

# 35. JSON streaming parser

Geen complete JSON-tree bouwen.

Parser krijgt callbacks/events:

```text
OBJECT_START
OBJECT_END
ARRAY_START
ARRAY_END
KEY
STRING
NUMBER
BOOLEAN
NULL
```

Chat-client registreert alleen de velden die hij nodig heeft.

Alle overige content direct weggooien.

---

# 36. Cooperative multitasking

Alle netwerkfuncties moeten zoveel mogelijk non-blocking zijn.

Hoofdloop:

```asm
main_loop:

    jsr gui_poll
    jsr keyboard_poll
    jsr net_poll
    jsr app_poll

    jmp main_loop
```

Geen:

```text
wacht 10 seconden in tcp_open
```

Gebruik states en timers.

Bijvoorbeeld TCP:

```text
TCP_CONNECTING
TCP_ESTABLISHED
TCP_RECEIVING
TCP_CLOSING
TCP_ERROR
```

---

# 37. Error model

Definieer centrale foutcodes:

```text
NET_OK

NET_ERR_NO_DEVICE
NET_ERR_TIMEOUT
NET_ERR_ARP
NET_ERR_DNS
NET_ERR_TCP
NET_ERR_CONNECTION_REFUSED
NET_ERR_RESET
NET_ERR_PROTOCOL
NET_ERR_BUFFER
NET_ERR_TLS
NET_ERR_CERTIFICATE
NET_ERR_HTTP
NET_ERR_AUTH
```

Applicaties mogen geen hardwarefoutcodes direct tonen.

---

# 38. Logging/debugmodus

Compile-time:

```text
DEBUG = true
```

Debug output moet minimaal tonen:

```text
platform
MAC
IP
gateway
DNS

ARP request/reply
IPv4 packet RX/TX
TCP state
SEQ
ACK
payload length
```

Voor packetdebug:

```text
DEBUG_PACKETS = true
```

optioneel maken.

---

# 39. Tests in VICE

Elke fase afzonderlijk testen.

Milestone A:

```text
RR-NET FOUND
```

Milestone B:

```text
ARP gateway resolved
```

Milestone C:

```text
PING gateway
```

Milestone D:

```text
PING LAN host
```

Milestone E:

```text
DNS lookup
```

Milestone F:

```text
TCP open
```

Milestone G:

```text
HTTP GET
```

Milestone H:

```text
RSS feed
```

Milestone I:

```text
FTP
```

---

# 40. Packetanalyse

Tijdens ontwikkeling Wireshark gebruiken.

Filters:

```text
arp

icmp

ip.addr == 192.168.1.64

tcp

dns
```

Controleer altijd eerst via Wireshark of het door de C64 verzonden pakket protocoltechnisch correct is.

Bij TCP-bugs nooit alleen vanaf de C64-output debuggen.

---

# 41. Buildscript

Maak minimaal:

```text
build.bat
build.sh
run-vice.bat
```

Bijvoorbeeld conceptueel:

```text
java -jar KickAss.jar src/main.asm
```

Laat build genereren:

```text
build/network.prg
build/network.sym
build/network.vs
```

waar mogelijk.

---

# 42. Compile-time platforms

Gebruik:

```text
PLATFORM_AUTO
PLATFORM_RRNET
PLATFORM_ULTIMATE
```

Standaard:

```text
PLATFORM_AUTO
```

Auto detecteert hardware tijdens runtime.

Voor debugging moet geforceerd kunnen worden:

```text
.var PLATFORM = PLATFORM_RRNET
```

---

# 43. Coding standards

Alle publieke routines documenteren met:

```asm
// -----------------------------------------------------
// tcp_send
//
// input:
//   ptr1 = buffer
//   len1 = length
//
// output:
//   A = result
//
// destroys:
//   A,X,Y
// -----------------------------------------------------
```

Gebruik vaste afspraken voor:

```text
return values
register preservation
zero-page pointers
error handling
```

---

# 44. Zero-page management

Maak één centraal bestand:

```text
zeropage.asm
```

Bijvoorbeeld:

```text
$02/$03 ptr1
$04/$05 ptr2
$06/$07 len1
...
```

Geen modules die zelfstandig zero-page adressen claimen.

---

# 45. Acceptatiecriteria eerste release

Release 0.1 is klaar wanneer VICE:

```text
RR-Net detecteert
ARP uitvoert
IPv4 verzendt
PING naar gateway uitvoert
DNS A-record kan opvragen
TCP naar testserver opent
HTTP GET uitvoert
RSS-feed als tekst toont
```

en Ultimate:

```text
UCI detecteert
TCP-verbinding opent
data kan versturen
data kan ontvangen
HTTP GET kan uitvoeren
dezelfde RSS-app kan draaien
```

De RSS-applicatiecode moet voor beide builds identiek zijn.

---

# 46. Release 0.2

Toevoegen:

```text
FTP client
2 TCP sockets
upload
download
directory listing
```

---

# 47. Release 0.3

Toevoegen:

```text
TLS onderzoeksprototype
SHA-256
AES
TLS handshake experiment
HTTPS GET
```

Eerst tegen eigen testendpoint.

---

# 48. Release 0.4

Toevoegen:

```text
HTTPS RSS
JSON
AI API client
Chat GUI
```

---

# 49. Release 0.5

Toevoegen:

```text
IMAP
MIME
text-only email
```

---

# 50. Belangrijke scopebeperkingen

Voor eerste versies NIET implementeren:

```text
IPv6
HTTP/2
HTTP/3
SSH
SFTP
full HTML
JavaScript
CSS
complete MIME
attachments
full Unicode
multiple concurrent HTTP connections
complete POSIX sockets API
```

Doel is geen Unix-netwerkstack.

Doel is een compacte stack specifiek voor onze GUI.

---

# 51. Belangrijk verschil VICE versus Ultimate

VICE:

```text
C64 code
 ↓
CS8900
 ↓
Ethernet
 ↓
onze ARP/IP/ICMP/TCP
 ↓
internet
```

Ultimate:

```text
C64 code
 ↓
UCI
 ↓
Ultimate firmware
 ↓
TCP/IP
 ↓
Ethernet
 ↓
internet
```

De applicaties gebruiken in beide gevallen:

```text
tcp_open
tcp_send
tcp_recv
tcp_close
```

Hierdoor blijven:

```text
RSS
FTP
IMAP
Chat
```

portable.

---

# 52. Referentieprojecten

Onderzoek als technische referentie:

- officiële VICE Ethernetdocumentatie
- officiële Ultimate UCI-documentatie
- GideonZ/1541u-documentation
- xlar54/ultimateii-dos-lib
- bestaande CS8900/RR-Net C64-code

Gebruik bestaande code primair om:

```text
registergedrag
UCI command protocol
CS8900 initialisatie
packet flow
```

te begrijpen.

Kopieer geen GPL-code naar een niet-GPL-project zonder expliciete beslissing over licensing.

---

# 53. Eerste concrete developmentopdracht

Implementeer uitsluitend milestone 1:

```text
VICE + RR-Net + CS8900 detectie
```

Resultaat op scherm:

```text
C64 NETWORK DRIVER TEST

PLATFORM : RR-NET
BASE     : $DE00
CS8900   : FOUND
STATUS   : READY
```

Daarna milestone 2:

```text
Ethernet TX/RX
```

Daarna milestone 3:

```text
ARP
```

Pas daarna:

```text
PING
```

Niet direct TCP gaan implementeren.

---

# 54. Eerste Ultimate-developmentopdracht

Parallel:

implementeer alleen:

```text
UCI detection
```

Resultaat:

```text
C64 NETWORK DRIVER TEST

PLATFORM : ULTIMATE
UCI      : FOUND
INTERFACE: $DF1C
NETWORK  : READY
```

Daarna:

```text
TCP connect naar eenvoudige testserver
```

Geen RSS of GUI-integratie voordat TCP send/receive aantoonbaar correct werkt.

---

# 55. Definition of Done per increment

Iedere increment moet opleveren:

```text
1. compileerbare Kick Assembler source
2. PRG
3. documentatie
4. testprocedure
5. geen regressie van vorige milestones
6. foutafhandeling
7. timeout-afhandeling
8. debug-output
```

Geen increment als afgerond markeren uitsluitend omdat code compileert.

Hij moet daadwerkelijk in:

```text
VICE
```

of:

```text
Ultimate hardware
```

zijn getest.

---

# Eindarchitectuur

```text
                 OUR C64 GUI
                     │
       ┌─────────────┼──────────────┐
       │             │              │
      RSS           FTP           MAIL          CHAT
       │             │              │             │
       ├── XML       ├── FTP        ├── IMAP      ├── JSON
       │             │              │             │
       └─────────────┴──────┬───────┴─────────────┘
                            │
                         HTTP/TLS
                            │
                     NETWORK SOCKET API
                            │
                 ┌──────────┴──────────┐
                 │                     │
              RR-NET                ULTIMATE
                 │                     │
              CS8900                  UCI
                 │                     │
          OUR TCP/IP STACK       FIRMWARE TCP/IP
                 │                     │
                 └──────────┬──────────┘
                            │
                         INTERNET
```

De kernregel voor de implementatie is:

**Applicaties praten uitsluitend tegen de Network Socket API. Alle hardware- en platformspecifieke verschillen blijven onder die laag.**
