//========================================================
// Commodore Desk 64 - time_main.asm
// DATUM EN TIJD (SYSTEM -> TIME) als losse assembly -> build\time.prg
// (overlay op $8000, app 12).
//
// Zoals email_main.asm: de netwerklaag (net/*) gaat mee, zonder DHCP en
// netwerklog; de Core-adressen komen uit build\core_syms.inc.
// ABI met de Core: sprongtabel op $8000 (INIT/DRAW/CLICK/KEY zoals de
// andere losse overlays) plus $800C AUTO: na een koude start de tijd
// ophalen (kernel/clock.asm: time_Boot).
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

.segmentdef Time [start=$8000, max=$bfff]
.file [name="time.prg", segments="Time"]

.segment Time
        jmp ti_Init              // $8000
        jmp ti_Draw              // $8003
        jmp ti_Click             // $8006
        jmp ti_Key               // $8009
        jmp ti_Auto              // $800C

        // netwerklaag (dezelfde bronnen als de INET-, BBS- en EMAIL-overlay;
        // tcp.asm voor de gedeelde variabelen van de Ultimate-driver)
        #import "net/net.inc"
        #import "net/netcommon.asm"
        #import "net/uci.asm"
        #import "net/cs8900.asm"
        #import "net/netdrv.asm"
        #import "net/ip.asm"
        #import "net/tcp.asm"
        #import "net/dns.asm"
        #import "net/ultimate.asm"
        #import "net/logpoints.asm"
        // DATE AND TIME
        #import "apps/time/ntp.asm"
        #import "apps/time/tzdata.asm"
        #import "apps/time/time.asm"
