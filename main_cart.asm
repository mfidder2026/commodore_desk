//========================================================
// Commodore Desk 64 - main_cart.asm  (EasyFlash CRT-build, Fase 10)
//
// Verpakt de VOLLEDIGE OS in cartridge-ROM. Bij reset draait een
// stub in ROMH (ultimax, $E000), kopieert een trampoline naar RAM,
// schakelt naar 16K-modus, kopieert de OS-image van $8000 naar RAM
// ($0801) en start hem. Instant boot, geen disk-load.
//
// Bouw:  build_cart.bat  ->  build\CommodoreDesk64.crt
//========================================================
#import "include/hardware.inc"
#import "include/palette.inc"
#import "include/layout.inc"
#import "include/memmap.inc"
#import "include/abi.inc"

//--------------------------------------------------------
// OS-image, geassembleerd op $0801 (het RAM-doeladres).
// Zelfde modules/volgorde als disk_main.asm.
//--------------------------------------------------------
.segmentdef OSIMG [start=$0801]
        .segment OSIMG
osStart:
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
#import "apps/filemanager.asm"
#import "apps/editor.asm"
#import "apps/calc.asm"
#import "apps/paint.asm"
#import "apps/settings.asm"
#import "gui/help.asm"
#import "gui/shell.asm"
#import "kernel/kernel.asm"
osEnd:

.var osLen = osEnd - $0801

//--------------------------------------------------------
// 16 KB cartridge-image ($8000-$BFFF = ROML + ROMH bank 0).
//--------------------------------------------------------
.segmentdef CARTIMG [start=$8000, min=$8000, max=$bfff, fill, fillByte=$ff]
        .segment CARTIMG
        *=$8000
        .segmentout [segments="OSIMG"]     // OS-bytes vanaf $8000 (loopt door in ROMH)

        // Reset-stub + trampoline, geassembleerd op de ultimax-adressen ($F000).
        *=$b000
.pseudopc $f000 {
coldStart:
        sei
        cld
        ldx #$ff
        txs
        ldx #0
!cp:    lda tramp,x
        sta $0200,x
        inx
        cpx #[trampEnd - tramp]
        bne !cp-
        jmp $0200                // verder vanuit RAM

tramp:
        lda #$37                 // standaard config (BASIC/KERNAL/I/O)
        sta $01
        lda #$87                 // 16K-modus + LED (ROML/ROMH = cart)
        sta $de02
        lda #0
        sta $de00
        // OS kopiëren: $8000 -> $0801 (osLen bytes)
        lda #$00
        sta $fb
        lda #$80
        sta $fc                  // src = $8000
        lda #$01
        sta $fd
        lda #$08
        sta $fe                  // dst = $0801
        ldx #>osLen
        beq !tail+
!pg:    ldy #0
!in:    lda ($fb),y
        sta ($fd),y
        iny
        bne !in-
        inc $fc
        inc $fe
        dex
        bne !pg-
!tail:  ldy #0
!tl:    cpy #<osLen
        beq !fin+
        lda ($fb),y
        sta ($fd),y
        iny
        bne !tl-
!fin:   lda #$04                 // cartridge UIT -> zuivere C64 (RAM + ROMs)
        sta $de02
        sei
        jsr $fd15                // RESTOR: KERNAL-vectoren ($0314 e.d.)
        jsr $fda3                // IOINIT: CIA/VIC/SID init (nodig voor disk-I/O)
        jmp osStart              // $0801 in RAM
trampEnd:
}

        *=$bffa
        .word coldStart          // NMI
        .word coldStart          // RESET
        .word coldStart          // IRQ/BRK

//--------------------------------------------------------
// Uitvoer: ruwe 16 KB cart-binary (cartconv maakt de .CRT).
//--------------------------------------------------------
.segment CART [outBin="cd64_cart.bin"]
        .segmentout [segments="CARTIMG"]
