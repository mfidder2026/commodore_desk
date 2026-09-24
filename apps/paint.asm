#importonce
//========================================================
// apps/paint.asm - Paint (echte multicolor-bitmap)
// Commodore Desk 64
//
// Paint is een VOLLEDIG-SCHERM multicolor-bitmapmodus. Zolang de app
// open is schakelt de VIC naar VIC-bank 1 ($4000-$7FFF) - vrij RAM
// boven de OS-image - met de bitmap op $6000 en de video-matrix op
// $4000. Bij het verlaten (RUN/STOP) schakelt alles terug naar de
// char-mode desktop.
//
// 160x200 "dikke pixels", 4 vaste kleuren per cel:
//   00 = achtergrond ($D021)      = ZWART (gum)
//   01 = matrix hoge nibble       = WIT
//   10 = matrix lage nibble       = LICHTROOD
//   11 = kleuren-RAM              = CYAAN
// Door één vast kleurenschema over het hele canvas zijn er geen
// attribuut-conflicten.
//========================================================

.label BITMAP  = $6000           // 8000 bytes bitmap (VIC-bank 1 + $2000)
.label VMATRIX = $4000           // video-matrix (kleurparen per cel)
.label pnPtr   = $3c             // zeropage-pointer

.const PN_MATRIX = $1a           // hoog=WIT(1), laag=LICHTROOD(10)
.const PN_CRAM   = CYAN           // kleur voor bitpaar 11
.const PN_PALTOP = 184           // py >= dit = palet-strook

//--------------------------------------------------------
// paint_Enter - schakel naar multicolor-bitmap en teken canvas+palet.
//--------------------------------------------------------
paint_Enter:
        // 1) bitmap wissen ($6000-$7FFF = 32 pagina's)
        lda #<BITMAP
        sta pnPtr
        lda #>BITMAP
        sta pnPtr+1
        ldx #$20
        lda #0
        ldy #0
!pg:    sta (pnPtr),y
        iny
        bne !pg-
        inc pnPtr+1
        dex
        bne !pg-
        // 2) video-matrix $4000-$43FF met het kleurpaar vullen
        lda #PN_MATRIX
        ldx #0
!m:     sta VMATRIX + $000,x
        sta VMATRIX + $100,x
        sta VMATRIX + $200,x
        sta VMATRIX + $300,x
        inx
        bne !m-
        // 3) kleuren-RAM = kleur voor bitpaar 11
        lda #PN_CRAM
        ldx #0
!c:     sta COLOR_RAM + $000,x
        sta COLOR_RAM + $100,x
        sta COLOR_RAM + $200,x
        sta COLOR_RAM + $300,x
        inx
        bne !c-
        // 4) achtergrond = zwart, rand zwart
        lda #BLACK
        sta BG_COL0
        sta BORDER_COL
        // 5) cursor-sprite in bank 1: data op $4400 (blok 16), pointer $43F8
        ldx #0
!sp:    lda arrowData,x
        sta $4400,x
        inx
        cpx #63
        bne !sp-
        lda #16
        sta $43f8
        // 6) VIC-bank 1 ($4000-$7FFF)
        lda CIA2_PRA
        and #$fc
        ora #%10
        sta CIA2_PRA
        // 7) $D018 = $08 -> matrix $4000, bitmap $6000
        lda #$08
        sta VIC_MEM
        // 8) bitmapmodus aan ($D011 bit5)
        lda VIC_CTRL1
        ora #$20
        sta VIC_CTRL1
        // 9) multicolor aan ($D016 bit4)
        lda VIC_CTRL2
        ora #$10
        sta VIC_CTRL2
        // 10) palet tekenen + startkleur wit
        jsr paint_DrawPalette
        lda #1
        sta pnCurrent
        rts

//--------------------------------------------------------
// paint_Exit - terug naar char-mode desktop.
//--------------------------------------------------------
paint_Exit:
        lda VIC_CTRL1
        and #$df                 // bitmap uit
        sta VIC_CTRL1
        lda VIC_CTRL2
        and #$ef                 // multicolor uit
        sta VIC_CTRL2
        lda CIA2_PRA             // VIC-bank 0
        ora #$03
        sta CIA2_PRA
        lda #$1e                 // scherm $0400, charset $3800
        sta VIC_MEM
        lda #13                  // cursor-pointer terug (bank 0)
        sta $07f8
        lda TH_deskbg
        sta BG_COL0
        lda TH_border
        sta BORDER_COL
        rts

//--------------------------------------------------------
// paint_DrawPalette - 4 stalen (8 dikke-pixels breed) onderaan +
//                     een witte scheidingslijn erboven.
//--------------------------------------------------------
paint_DrawPalette:
        // scheidingslijn (kleur 1 = wit) op py = PN_PALTOP-1
        lda #PN_PALTOP-1
        sta pnPy
        lda #0
        sta pnFx
!ln:    lda #1
        sta pnCurrent
        jsr paint_Plot
        inc pnFx
        lda pnFx
        cmp #160
        bne !ln-
        // 4 stalen: staal s beslaat fatx s*8..s*8+7, py PN_PALTOP..199
        lda #0
        sta pnPalSw
swloop: lda pnPalSw
        cmp #4
        bcs swdone
        lda #PN_PALTOP
        sta pnPy
pyloop: lda pnPalSw          // fatx-basis = sw*8
        asl
        asl
        asl
        sta pnPalFx0
        lda #0
        sta pnPalDx
fxloop: lda pnPalFx0
        clc
        adc pnPalDx
        sta pnFx
        lda pnPalSw
        sta pnCurrent
        jsr paint_Plot
        inc pnPalDx
        lda pnPalDx
        cmp #8
        bne fxloop
        inc pnPy
        lda pnPy
        cmp #200
        bne pyloop
        inc pnPalSw
        jmp swloop
swdone: rts

//--------------------------------------------------------
// paint_Click - klik (EVT_MOUSEDOWN): kleur kiezen of pixel zetten.
//--------------------------------------------------------
paint_Click:
        jsr paint_CursorToFat
        lda pnPy
        cmp #PN_PALTOP
        bcs pickColor
        jmp paint_Plot
pickColor:
        lda pnFx
        lsr
        lsr
        lsr                      // fatx / 8 = staalnummer
        cmp #4
        bcs pcDone
        sta pnCurrent
pcDone: rts

//--------------------------------------------------------
// paint_Live - elke lus (alleen als Paint actief is): teken zolang
//              de knop ingedrukt is (sleep-tekenen).
//--------------------------------------------------------
paint_Live:
        lda crsBtn
        beq plDone
        jsr paint_CursorToFat
        lda pnPy
        cmp #PN_PALTOP
        bcs plDone               // niet over het palet tekenen
        jmp paint_Plot
plDone: rts

//--------------------------------------------------------
// paint_CursorToFat - reken cursor (crsX/crsY, sprite-pixels) om naar
//                     dikke-pixel (pnFx 0-159) en py (pnPy 0-199).
//--------------------------------------------------------
paint_CursorToFat:
        lda crsXlo               // (crsX - 24) / 2
        sec
        sbc #24
        sta pnT0
        lda crsXhi
        sbc #0
        sta pnT1
        lsr pnT1
        ror pnT0
        lda pnT0
        sta pnFx
        lda crsY                 // crsY - 50
        sec
        sbc #50
        sta pnPy
        rts

//--------------------------------------------------------
// paint_Plot - zet de dikke-pixel (pnFx,pnPy) op kleur pnCurrent.
//   addr = BITMAP + (py>>3)*320 + (fatx>>2)*8 + (py&7)
//   bitpaar = 3-(fatx&3), shift = bitpaar*2
//--------------------------------------------------------
paint_Plot:
        // basis = BITMAP + rowOffset[py>>3]
        lda pnPy
        lsr
        lsr
        lsr
        tax
        lda #<BITMAP
        clc
        adc rowLo,x
        sta pnPtr
        lda #>BITMAP
        adc rowHi,x
        sta pnPtr+1
        // + (fatx>>2)*8 = (fatx & $fc) * 2   (16-bit)
        lda pnFx
        and #$fc
        sta pnT0
        lda #0
        sta pnT1
        asl pnT0
        rol pnT1
        lda pnPtr
        clc
        adc pnT0
        sta pnPtr
        lda pnPtr+1
        adc pnT1
        sta pnPtr+1
        // + (py & 7)
        lda pnPy
        and #7
        clc
        adc pnPtr
        sta pnPtr
        lda pnPtr+1
        adc #0
        sta pnPtr+1
        // bitpaar-index = fatx & 3 ; shift = shiftTab[idx]
        lda pnFx
        and #3
        tax
        // waarde = pnCurrent << shift
        lda pnCurrent
        ldy shiftTab,x
        beq !vdone+
!vs:    asl
        dey
        bne !vs-
!vdone: sta pnVal
        // masker
        lda maskTab,x
        eor #$ff
        sta pnT0                 // inverse masker
        ldy #0
        lda (pnPtr),y
        and pnT0
        ora pnVal
        sta (pnPtr),y
        rts

//--------------------------------------------------------
// Tabellen
//--------------------------------------------------------
rowLo:    .fill 25, <(i*320)
rowHi:    .fill 25, >(i*320)
shiftTab: .byte 6, 4, 2, 0       // fatx&3 -> aantal bits schuiven
maskTab:  .byte $c0, $30, $0c, $03

pnCurrent: .byte 1
pnFx:      .byte 0
pnPy:      .byte 0
pnVal:     .byte 0
pnT0:      .byte 0
pnT1:      .byte 0
pnPalSw:   .byte 0
pnPalFx0:  .byte 0
pnPalDx:   .byte 0
