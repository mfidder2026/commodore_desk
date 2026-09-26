#importonce
//========================================================
// kernel/clock.asm - datum en tijd voor de statusbalk
// Commodore Desk 64
//
// De tijd loopt in de TOD-klok van CIA1 ($DC08-$DC0B). Die blijft
// doorlopen tijdens disk-I/O en als er een PRG draait. De datum staat
// op $C3F8 (naast de launcher-stubs); met de marker overleeft hij de
// terugkeer uit een PRG (kernel_Init draait dan opnieuw). Alles BCD.
//========================================================

.label CLK_MARK  = $c3f8         // 2 bytes: "CD" = datum geldig
.label clkDay    = $c3fa
.label clkMon    = $c3fb
.label clkYearHi = $c3fc
.label clkYearLo = $c3fd
.label clkLastH  = $c3fe         // uur bij vorige poll (dagwissel)

.label TOD_10TH = $dc08
.label TOD_SEC  = $dc09
.label TOD_MIN  = $dc0a
.label TOD_HR   = $dc0b
.label CIA1_CRA = $dc0e
.label CIA1_CRB = $dc0f

// -----------------------------------------------------
// clk_Init - 50/60 Hz-bit van de TOD goed zetten; bij een koude start
//            datum 01-01-2026 en tijd 00:00.
// -----------------------------------------------------
clk_Init: {
        // PAL/NTSC: hoogste rasterregel >= 256+$20 alleen op PAL (311)
w1:     bit VIC_CTRL1
        bmi w1
w2:     bit VIC_CTRL1
        bpl w2
        lda #0
        sta clkTmp
w3:     lda RASTER
        cmp clkTmp
        bcc w4
        sta clkTmp
w4:     bit VIC_CTRL1
        bmi w3
        lda CIA1_CRA
        and #$7f
        ldx clkTmp
        cpx #$20
        bcc ntsc
        ora #$80                 // PAL: TOD telt 50 Hz
ntsc:   sta CIA1_CRA
        lda CIA1_CRB
        and #$7f                 // schrijven = TOD, niet het alarm
        sta CIA1_CRB
        lda CLK_MARK
        cmp #'C'
        bne cold
        lda CLK_MARK+1
        cmp #'D'
        beq warm
cold:   lda #'C'
        sta CLK_MARK
        lda #'D'
        sta CLK_MARK+1
        lda #$01
        sta clkDay
        sta clkMon
        lda #$20
        sta clkYearHi
        lda #$26
        sta clkYearLo
        lda #0
        tax
        jsr clk_SetTime
warm:   lda #$ff                 // statusbalk bij de eerste poll tekenen
        sta clkShown
        rts
}

// -----------------------------------------------------
// clk_SetTime - A = uur (BCD 00-23), X = minuut (BCD). Seconden = 0.
// -----------------------------------------------------
clk_SetTime: {
        sei
        sed
        cmp #$12
        bcc am
        beq pm12                 // 12 uur 's middags
        sec
        sbc #$12
pm12:   ora #$80
        jmp set
am:     cmp #0
        bne set
        lda #$12                 // middernacht = 12 AM
set:    cld
        sta clkTmp
        jsr wr
        lda TOD_HR               // de 6526 draait AM/PM om bij "12":
        ldy TOD_10TH             // (ontgrendelen)
        eor clkTmp               // teruglezen en zo nodig nogmaals
        bpl ok                   // schrijven met het bit omgedraaid
        lda clkTmp
        eor #$80
        jsr wr
ok:     lda #0
        sta clkLastH
        lda #$ff
        sta clkShown
        cli
        rts
wr:     sta TOD_HR               // stopt de klok tot 1/10 geschreven is
        stx TOD_MIN
        lda #0
        sta TOD_SEC
        sta TOD_10TH             // start
        rts
}

// -----------------------------------------------------
// clk_Read - TOD -> clkHour (24 uur, BCD), clkMin.
// -----------------------------------------------------
clk_Read: {
        lda TOD_HR               // vergrendelt de registers
        sta clkTmp
        lda TOD_MIN
        sta clkMin
        lda TOD_10TH             // ontgrendelen
        lda clkTmp
        and #$1f
        cmp #$12
        bne h
        lda #0                   // 12 AM/PM -> 0 (+12 bij PM)
h:      bit clkTmp
        bpl am
        sei                      // decimale modus: geen IRQ ertussen
        sed
        clc
        adc #$12
        cld
        cli
am:     sta clkHour
        rts
}

// -----------------------------------------------------
// clk_Poll - vanuit de hoofdlus: dagwissel + statusbalk bij een nieuwe
//            minuut.
// -----------------------------------------------------
clk_Poll: {
        jsr clk_Read
        lda clkHour
        cmp clkLastH
        sta clkLastH
        bcs same                 // uur niet teruggesprongen
        jsr clk_NextDay
same:   lda clkMin
        cmp clkShown
        bne clk_Draw
        rts
}

// clk_NextDay - datum een dag verder (BCD, met schrikkeljaren).
clk_NextDay: {
        sei
        sed
        lda clkDay
        clc
        adc #1
        sta clkDay
        cld
        jsr clk_DaysInMonth      // A = laatste dag (BCD)
        cmp clkDay
        bcs done
        sed
        lda #$01
        sta clkDay
        lda clkMon
        clc
        adc #1
        sta clkMon
        cmp #$13
        bcc done
        lda #$01
        sta clkMon
        lda clkYearLo
        clc
        adc #1
        sta clkYearLo
        lda clkYearHi
        adc #0
        sta clkYearHi
done:   cld
        cli
        rts
}

// clk_DaysInMonth - A = aantal dagen (BCD) van clkMon/clkYear.
clk_DaysInMonth: {
        lda clkMon
        cmp #$10
        bcc lo
        sbc #6                   // BCD $10-$12 -> 10-12
lo:     tax
        lda clkDim-1,x
        cpx #2
        bne done
        lda clkYearLo            // schrikkeljaar: (tientallen*2 + eenheden) mod 4
        lsr
        lsr
        lsr
        and #$1e
        sta clkTmp
        lda clkYearLo
        and #$0f
        clc
        adc clkTmp
        and #3
        bne feb
        lda #$29
        rts
feb:    lda #$28
done:   rts
}
clkDim: .byte $31, $28, $31, $30, $31, $30, $31, $31, $30, $31, $30, $31

// -----------------------------------------------------
// clk_Draw - "DD-MM-YYYY  HH:MM" rechts in de statusbalk.
// -----------------------------------------------------
clk_Draw: {
        lda clkMin
        sta clkShown
        ldx #0
        lda clkDay
        jsr bcd
        jsr dash
        lda clkMon
        jsr bcd
        jsr dash
        lda clkYearHi
        jsr bcd
        lda clkYearLo
        jsr bcd
        lda #$20
        sta clkBuf,x
        inx
        sta clkBuf,x
        inx
        lda clkHour
        jsr bcd
        lda #$3a                 // :
        sta clkBuf,x
        inx
        lda clkMin
        jsr bcd
        lda #$ff
        sta clkBuf,x
        lda #<clkBuf
        sta r0
        lda #>clkBuf
        sta r0+1
        lda #22
        sta a0
        lda #STATUS_ROW
        sta a1
        lda TH_menubg
        sta a2
        jmp gfx_DrawTextRev
dash:   lda #$2d                 // -
        sta clkBuf,x
        inx
        rts
bcd:    pha
        lsr
        lsr
        lsr
        lsr
        ora #$30
        sta clkBuf,x
        inx
        pla
        and #$0f
        ora #$30
        sta clkBuf,x
        inx
        rts
}

clkHour:  .byte 0
clkMin:   .byte 0
clkShown: .byte $ff              // minuut die nu op het scherm staat
clkTmp:   .byte 0
clkBuf:   .fill 18, 0
