//========================================================
// Commodore Desk 64 - weather_main.asm
// WEERBERICHT (WEATHER) als losse assembly -> build\weather.prg, een eigen
// PRG binnen het framework net als BBS (overlay op $8000, app 14).
// Core-adressen: build\core_syms.inc.
// ABI met de Core: sprongtabel op $8000 (INIT/DRAW/CLICK/KEY).
// Plan: docs/WEATHER_Plan.md.
//========================================================
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

        #import "apps/weather/weather.asm"
