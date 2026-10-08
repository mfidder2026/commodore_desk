//========================================================
// Commodore Desk 64 - calendar_main.asm
// CALENDAR (kalender met agenda) als losse assembly -> build\calendar.prg,
// een eigen PRG binnen het framework net als WEATHER en WEB (overlay op
// $8000, app 16). Core-adressen: build\core_syms.inc.
// ABI met de Core: sprongtabel op $8000 (INIT/DRAW/CLICK/KEY) en $800C:
// de herinnering bij het opstarten (CAL_REMIND, zie gui/shell.asm).
// Plan: docs/CALENDAR_Plan.md.
//========================================================
#import "include/hardware.inc"
#import "include/palette.inc"
#import "include/layout.inc"
#import "include/memmap.inc"
#import "include/abi.inc"
#import "include/events.inc"
#import "build/core_syms.inc"
#import "apps/printer_drv.asm"
#import "apps/calendar/cal.inc"

.segmentdef Calendar [start=$8000, max=$bfff]
.file [name="calendar.prg", segments="Calendar"]

.segment Calendar
        jmp cl_Init              // $8000
        jmp cl_Draw              // $8003
        jmp cl_Click             // $8006
        jmp cl_Key               // $8009
        jmp cl_Remind            // $800C: herinnering bij het opstarten

        #import "apps/calendar/cal.asm"
        #import "apps/calendar/cal_file.asm"
        #import "apps/calendar/cal_date.asm"
        #import "apps/calendar/cal_print.asm"
