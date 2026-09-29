# INET – Milestone 1: netwerkhardware-detectie

Onderdeel van het netwerk-bouwplan (`C64_Network_Stack_Technisch_Bouwplan.md`, §53/§54).

## Wat er is

- **INET** is een overlay (`inet.prg`, laadt op `$8000`) en staat in de dock.
  De netwerkstack groeit later te groot voor de Core, dus hij zit niet resident.
- `net/net.inc` bevat de constanten: platforms, `NET_ERR_*`-foutcodes, CS8900/RR-Net- en UCI-registers, bufferadressen.
- `net/uci.asm` bevat `uci_Detect`. Die leest het identificatieregister `$DF1D` (en eventueel `$DE1D`) 8x achter elkaar en verwacht elke keer `$C9`.
- `net/cs8900.asm` bevat `cs_Detect`:
  - zet de RR-Net-clockport aan (`$DE01` bit 0);
  - leest PacketPage `$0000` en verwacht product-ID `$630E`;
  - leest de revisie uit `$0002`.
- `net/netdrv.asm` bevat `net_Detect`.
  - Volgorde: eerst Ultimate, dan RR-Net, anders geen netwerk.
  - Kiezen kan ook compile-time met `.var PLATFORM` in `net.inc`.
  - In de cartridge-build wordt niets aangeraakt: EasyFlash gebruikt `$DE00`/`$DE02` en heeft RAM op `$DF00`.
  - Het resultaat staat in `netPlatform` en `netError`.
- De statische config staat nog vast: IP 192.168.1.64/24, GW 192.168.1.1, DNS 1.1.1.1, MAC 02:64:64:00:00:01.
- Netwerkbuffers komen later in het RAM onder de KERNAL (`$E000-$EFFF`). `$C000` is bezet door de launcher.

## Testprocedure (VICE)

1. Npcap installeren, met WinPcap-compatibiliteit.
2. Zet **GeoRAM uit**, want die zit op `$DE00` en botst met de RR-Net. Een REU op `$DF00` mag niet samen met een Ultimate-test.
3. Start VICE met de ethernet-cart in RR-Net-modus:

```bash
x64sc -drive8type 1541 +georam -ethernetcart -ethernetcartmode 1 -ethernetcartbase 0xDE00 -autostart build/CD64.d64
```

4. Klik in de dock op **INET**. Verwacht:

```text
C64 NETWORK DRIVER TEST
PLATFORM : RR-NET
BASE     : $DE00
CS8900   : FOUND
ID       : $630E REV $09      (VICE emuleert rev. D)
STATUS   : READY
```

5. Zonder `-ethernetcart` hoort dit te verschijnen: `PLATFORM : NONE`, `UCI/CS8900 : NOT FOUND` en `STATUS : NO NETWORK HARDWARE`.
6. De cartridge-build toont `I/O : IN USE BY CARTRIDGE` en `STATUS : NOT SCANNED`.
7. **RESCAN** zoekt opnieuw, bijvoorbeeld na het aan- of uitzetten van de cart in VICE.

De Ultimate-detectie (UCI) kan niet in VICE getest worden. Dat kan alleen op een Ultimate 64 of 1541 Ultimate-II+ met het Command Interface aan. Verwacht daar `PLATFORM : ULTIMATE`, `UCI : FOUND` en `INTERFACE: $DF1C`.

## Volgende stap

Milestone 2 is Ethernet TX/RX op de CS8900: reset, init, MAC instellen, frame zenden en ontvangen, met registerdump op het scherm.
