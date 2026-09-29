#importonce
//========================================================
// kernel/irq.asm - raster-IRQ (de systeemklok, 50 Hz PAL)
// Commodore Desk 64
//
// We nemen de HARDWARE-IRQ-vector ($FFFE) over. Dat vereist dat
// KERNAL uitgebankt is ($01 = $35), zodat de 6510 de vector uit
// RAM leest. De handler bewaart zelf A/X/Y.
//
// Elke frame: raster-IRQ bevestigen, frameteller ophogen, en de
// input pollen (die de cursor beweegt en events genereert).
//========================================================

// Eén raster-IRQ per frame, in de onderrand.
.const IRQ_RASTER_LINE = 252

// irq_Install - tellers nullen, vectoren zetten, raster-IRQ aan,
//               ROMs uitbanken, interrupts vrijgeven.
irq_Install:
        sei
        lda #0
        sta frameLo
        sta frameHi

        lda #<irqHandler
        sta $fffe
        lda #>irqHandler
        sta $ffff
        lda #<nmiHandler
        sta $fffa
        lda #>nmiHandler
        sta $fffb

        lda #$7f                 // CIA-interrupts uit
        sta CIA1_ICR
        sta CIA2_ICR
        bit CIA1_ICR
        bit CIA2_ICR

        lda VIC_CTRL1            // rasterregel < 256
        and #$7f
        sta VIC_CTRL1
        lda #IRQ_RASTER_LINE
        sta RASTER
        lda #$01
        sta VIC_IRQ_EN
        sta VIC_IRQ

        jsr mem_AllRam           // BASIC + KERNAL uit
        cli
        rts

//--------------------------------------------------------
irqHandler:
        pha
        txa
        pha
        tya
        pha

        lda #$01
        sta VIC_IRQ              // raster-IRQ bevestigen

        inc frameLo
        bne !+
        inc frameHi
!:
        jsr input_Poll           // cursor bewegen + events genereren

        pla
        tay
        pla
        tax
        pla
        rti

// NMI (RESTORE-toets): niets doen.
nmiHandler:
        rti

//--------------------------------------------------------
frameLo:    .byte 0
frameHi:    .byte 0
