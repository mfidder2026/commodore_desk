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

// Twee raster-IRQ's per frame (Win95-layout):
//  - SPLIT (rij 20, massief grijze desktoprij): $D021 -> balkkleur, zodat
//    de dock (rijen 21-24) een lichtgrijze achtergrond heeft. Omdat rij 20
//    volledig uit massieve blokken bestaat is de wissel onzichtbaar.
//  - FRAME (onderrand): $D021 -> vensterkleur voor het volgende frame +
//    het normale werk (frameteller, input pollen).
// splitOn = 0 (Paint/bitmapmodus): $D021 wordt niet aangeraakt.
.const IRQ_SPLIT_LINE = 51 + 20*8 + 2     // = 213
.const IRQ_FRAME_LINE = 252
.const IRQ_RASTER_LINE = IRQ_FRAME_LINE

// irq_Install - tellers nullen, vectoren zetten, raster-IRQ aan,
//               ROMs uitbanken, interrupts vrijgeven.
irq_Install:
        sei
        lda #0
        sta frameLo
        sta frameHi
        sta irqPhase             // volgende IRQ = FRAME

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

        lda irqPhase
        beq !frame+
        // ---- SPLIT: dock-achtergrond ----
        lda splitOn
        beq !s1+
        lda TH_menubg
        sta BG_COL0
!s1:    lda #0
        sta irqPhase
        lda #IRQ_FRAME_LINE
        sta RASTER
        jmp !out+
        // ---- FRAME: vensterachtergrond + frame-werk ----
!frame: lda splitOn
        beq !f1+
        lda TH_deskbg
        sta BG_COL0
!f1:    lda #1
        sta irqPhase
        lda #IRQ_SPLIT_LINE
        sta RASTER

        inc frameLo
        bne !+
        inc frameHi
!:
        jsr input_Poll           // cursor bewegen + events genereren

!out:   pla
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
irqPhase:   .byte 0              // 0 = volgende IRQ is FRAME, 1 = SPLIT
splitOn:    .byte 1              // 0 = $D021 niet aanraken (Paint)
