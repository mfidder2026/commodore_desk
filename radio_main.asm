//========================================================
// Commodore Desk 64 - radio_main.asm
// SID RADIO als losse assembly -> build\radio.prg (overlay op $8000, app 13).
//
// De netwerklaag (net/*, zonder DHCP en netwerklog) en de TCP-laag van
// EMAIL (mail_net.asm) gaan mee, plus de SID-speler van SIDPLAY
// (apps/sidplay.asm, in radiomodus). Core-adressen: build\core_syms.inc.
// ABI met de Core: sprongtabel op $8000 (INIT/DRAW/CLICK/KEY).
//========================================================
#define NO_DHCP
#define NO_NETLOG
#import "include/hardware.inc"
#import "include/palette.inc"
#import "include/layout.inc"
#import "include/memmap.inc"
#import "include/abi.inc"
#import "include/events.inc"
#import "build/core_syms.inc"
#import "apps/radio/radio.inc"

.segmentdef Radio [start=$8000, max=$bfff]
.file [name="radio.prg", segments="Radio"]

.segment Radio
        jmp ra_Init              // $8000
        jmp ra_Draw              // $8003
        jmp ra_Click             // $8006
        jmp ra_Key               // $8009

        // netwerklaag (dezelfde bronnen als de andere netwerk-overlays)
        #import "net/net.inc"
        #import "net/netcommon.asm"
        #import "net/uci.asm"
        #import "net/cs8900.asm"
        #import "net/netdrv.asm"
        #import "net/ip.asm"
        #import "net/tcp.asm"
        #import "net/dns.asm"
        #import "net/ultimate.asm"
        #import "net/wic64net.asm"
        #import "net/logpoints.asm"
        #import "apps/email/mail_net.asm"
        // afspelen + de radio
        #import "apps/sidplay.asm"
        #import "apps/radio/radio.asm"
