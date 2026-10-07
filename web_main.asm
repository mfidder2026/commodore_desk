//========================================================
// Commodore Desk 64 - web_main.asm
// WEB (de browser) als losse assembly -> build\web.prg, een eigen PRG
// binnen het framework net als BBS en WEATHER (overlay op $8000, app 15).
// Core-adressen: build\core_syms.inc.
// ABI met de Core: sprongtabel op $8000 (INIT/DRAW/CLICK/KEY).
// Plan: docs/BROWSER_Plan.md.
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
#import "apps/web/web.inc"

.segmentdef Web [start=$8000, max=$bfff]
.file [name="web.prg", segments="Web"]

.segment Web
        jmp wb_Init              // $8000
        jmp wb_Draw              // $8003
        jmp wb_Click             // $8006
        jmp wb_Key               // $8009

        // netwerklaag (dezelfde bronnen als RADIO en WEATHER)
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
        // de browser
        #import "apps/web/web.asm"
        #import "apps/web/web_url.asm"
        #import "apps/web/web_net.asm"
        #import "apps/web/web_html.asm"
// einde van de code: hierboven (tot $C000) de bewaarde linkadressen
wbEnd:
