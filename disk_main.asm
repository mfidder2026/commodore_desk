//========================================================
// Commodore Desk 64 - disk_main.asm
// Overlay-build: een residente CORE ($0801) + losse app-PRG's die
// op $8000 geladen worden (één tegelijk). De core roept app-routines
// aan op hun vaste $80xx-adressen; die zijn geldig zodra de betreffende
// app in de overlay-zone geladen is.
//
// Bouw:  build_disk.bat  ->  build\CD64.d71  (BOOT -> CD64 -> apps)
//========================================================
#import "include/hardware.inc"
#import "include/palette.inc"
#import "include/layout.inc"
#import "include/memmap.inc"
#import "include/abi.inc"

// Core mag NOOIT de charset op $3800 raken: max=$37FF laat de assembler
// een fout geven zodra de Core te groot wordt.
.segmentdef Core   [start=$0801, max=$37ff]
// System-charset: zit in hetzelfde cd64.prg, direct op $3800 geladen.
.segmentdef SysCharset [start=$3800]
.segmentdef Files  [start=$8000]
.segmentdef Editor [start=$8000]
.segmentdef Calc   [start=$8000]
.segmentdef Paint  [start=$8000]
.segmentdef Setup  [start=$8000]
.segmentdef DeskTool [start=$8000]      // launcher-beheer (menu ADD/EDIT/DELETE)
.segmentdef Inet   [start=$8000]        // INET + netwerkdrivers (net/)
.segmentdef Lower  [start=$3800]
.segmentdef Tiny   [start=$3800]
// font-charsets (laden naar charset-RAM $3800; overlappen, 1 tegelijk)
.segmentdef Fremen [start=$3800]
.segmentdef Serif  [start=$3800]
.segmentdef Mono   [start=$3800]
.segmentdef Casual [start=$3800]
.segmentdef Heavy  [start=$3800]

.file [name="cd64.prg",   segments="Core,SysCharset"]
.file [name="files.prg",  segments="Files"]
.file [name="editor.prg", segments="Editor"]
.file [name="calc.prg",   segments="Calc"]
.file [name="paint.prg",  segments="Paint"]
.file [name="setup.prg",  segments="Setup"]
.file [name="desktool.prg", segments="DeskTool"]
.file [name="inet.prg",   segments="Inet"]
.file [name="lower.prg",  segments="Lower"]
.file [name="tiny.prg",   segments="Tiny"]
.file [name="fremen.prg", segments="Fremen"]
.file [name="serif.prg",  segments="Serif"]
.file [name="mono.prg",   segments="Mono"]
.file [name="casual.prg", segments="Casual"]
.file [name="heavy.prg",  segments="Heavy"]

//--------------------------------------------------------
// CORE - kernel, drivers, gfx, shell/desktop (altijd resident).
//--------------------------------------------------------
.segment Core
        *=$0801
        BasicUpstart2(start)     // 10 SYS 2061
        *=$0810
start:
        jmp kernel_Init

        #import "hal/vic.asm"
        #import "hal/sound.asm"
        #import "gfx/font.asm"
        #import "gfx/gfx.asm"
        #import "gfx/sprite.asm"
        #import "kernel/events.asm"
        #import "hal/input.asm"
        #import "kernel/memory.asm"
        #import "kernel/irq.asm"
        #import "kernel/banking.asm"
        #import "hal/disk.asm"
        #import "gui/widgets.asm"
        #import "gui/help.asm"
        #import "gui/shell.asm"
        #import "gui/deskapps.asm"
        #import "kernel/clock.asm"
        #import "kernel/kernel.asm"

// System-charset (2 KB, hoofdletter/grafiek-set uit de C64 char-ROM),
// meegeladen op $3800 zodat hij niet in de Core hoeft te staan.
.segment SysCharset
        .import binary "data/chargen.bin"

//--------------------------------------------------------
// App-overlays - elk een los PRG dat op $8000 geladen wordt.
//--------------------------------------------------------
.segment Files
        #import "apps/filemanager.asm"
.segment Editor
        #import "apps/editor.asm"
.segment Calc
        #import "apps/calc.asm"
.segment Paint
        #import "apps/paint.asm"
.segment Setup
        #import "apps/settings.asm"
.segment DeskTool
        #import "gui/desktool.asm"
.segment Inet
        #import "net/net.inc"
        #import "net/uci.asm"
        #import "net/cs8900.asm"
        #import "net/netdrv.asm"
        #import "apps/inet.asm"

// LOWER- en TINY-font als complete charsets op disk: System-charset met
// de kleine letters (a-z op code 1-26) resp. het 3x5-font (A-Z op 1-26,
// 0-9 op 48-57) erin gezet. Zo hoeven de overlays niet in de Core.
.segment Lower
        .import binary "data/chargen.bin", 0, 8
        .import binary "data/lower.bin", 0, 208
        .import binary "data/chargen.bin", 216, 2048-216
.segment Tiny
        .import binary "data/chargen.bin", 0, 8
        .import binary "data/tiny.bin", 0, 208
        .import binary "data/chargen.bin", 216, 384-216
        .import binary "data/tiny.bin", 208, 80
        .import binary "data/chargen.bin", 464, 2048-464

// Font-charsets (elk 2 KB) - losse PRG's met laadadres $3800.
.segment Fremen
        .import binary "data/fremen.bin"
.segment Serif
        .import binary "data/serif.bin"
.segment Mono
        .import binary "data/mono.bin"
.segment Casual
        .import binary "data/casual.bin"
.segment Heavy
        .import binary "data/heavy.bin"
