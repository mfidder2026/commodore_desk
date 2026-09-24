//========================================================
// Commodore Desk 64 - disk_main.asm
// PRG-variant voor de D71-disk (voorlopige uitlevering).
// Laadt normaal in RAM met de KERNAL aanwezig; de kernel bankt
// daarna de ROMs uit en neemt de raster-IRQ over.
//
// Bouw:  build_disk.bat  ->  build\CD64.d71
// Laden: LOAD"CD64",8,1 : RUN   (of -autostart in VICE)
//========================================================
#import "include/hardware.inc"
#import "include/palette.inc"
#import "include/layout.inc"
#import "include/memmap.inc"
#import "include/abi.inc"

        *=$0801
        BasicUpstart2(start)     // 10 SYS 2061

        *=$0810
start:
        jmp kernel_Init

//--------------------------------------------------------
// Kernel + drivers (fase 1).
//--------------------------------------------------------
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
#import "apps/filemanager.asm"
#import "apps/editor.asm"
#import "apps/calc.asm"
#import "apps/paint.asm"
#import "apps/settings.asm"
#import "gui/help.asm"
#import "gui/shell.asm"
#import "kernel/kernel.asm"
