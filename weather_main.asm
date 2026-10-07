//========================================================
// Commodore Desk 64 - weather_main.asm
// WEERBERICHT (WEATHER) als losse assembly -> build\weather.prg, een eigen
// PRG binnen het framework net als BBS (overlay op $8000, app 14).
// Core-adressen: build\core_syms.inc.
// ABI met de Core: sprongtabel op $8000 (INIT/DRAW/CLICK/KEY).
// Plan: docs/WEATHER_Plan.md.
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
#import "apps/weather/weather.inc"

.segmentdef Weather [start=$8000, max=$bfff]
.file [name="weather.prg", segments="Weather"]

.segment Weather
        jmp we_Init              // $8000
        jmp we_Draw              // $8003
        jmp we_Click             // $8006
        jmp we_Key               // $8009

        // netwerklaag (dezelfde bronnen als RADIO)
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
        // het weer
        #import "build/weather_spr.inc"       // tools/make_weather_sprites.py
        #import "apps/weather/weather.asm"
        #import "apps/weather/weather_net.asm"
weSprData:
        .import binary "build/weather_spr.bin"
