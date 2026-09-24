#importonce
//========================================================
// apps/paint.asm - Paint (multicolor-bitmap, 16 kleuren)
// Commodore Desk 64
//
// Paint is een VOLLEDIG-SCHERM multicolor-bitmapmodus. Zolang de app
// open is schakelt de VIC naar VIC-bank 1 ($4000-$7FFF) - vrij RAM
// boven de OS-image - met de bitmap op $6000 en de video-matrix op
// $4000. Bij het verlaten (ESC) schakelt alles terug naar char-mode.
//
// 160x200 "dikke pixels". Achtergrond (bitpaar 00) is BLAUW en gedeeld
// over het hele scherm. Per 8x8-cel zijn er daarnaast 3 vrije kleur-
// slots (matrix hoge nibble = 01, lage nibble = 10, kleuren-RAM = 11),
// die Paint automatisch toewijst als je tekent. Zo is het HELE 16-
// kleurenpalet beschikbaar (max 3 niet-blauwe kleuren per cel).
//
// BELANGRIJK: schrijf $D011/$D016 met VASTE waarden, nooit via
// read-modify-write - een gelezen $D011 bevat in bit 7 de rasterregel
// en zou de raster-IRQ (en dus alle input) kunnen slopen.
//========================================================

.label BITMAP  = $6000           // 8000 bytes bitmap (VIC-bank 1 + $2000)
.label VMATRIX = $4000           // video-matrix (kleurparen per cel)
.label pnPtr   = $3c             // zeropage-pointer (bitmap)
.label pnMPtr  = $fb             // zeropage-pointer (matrix)
.label pnCPtr  = $fd             // zeropage-pointer (kleuren-RAM)

.const PN_BG     = BLUE          // gedeelde achtergrond (bitpaar 00)
.const PN_MINIT  = [BLUE<<4]|BLUE // matrix-init: beide slots = achtergrond
.const PN_PALTOP = 184           // py >= dit = palet-strook

//--------------------------------------------------------
// paint_Enter - schakel naar multicolor-bitmap en teken canvas+palet.
//--------------------------------------------------------
paint_Enter:
        // 1) bitmap wissen ($6000-$7FFF = 32 pagina's) -> alles achtergrond
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
        // 2) video-matrix $4000-$43FF: beide slots = achtergrond
        lda #PN_MINIT
        ldx #0
!m:     sta VMATRIX + $000,x
        sta VMATRIX + $100,x
        sta VMATRIX + $200,x
        sta VMATRIX + $300,x
        inx
        bne !m-
        // 3) kleuren-RAM (slot 11) = achtergrond
        lda #PN_BG
        ldx #0
!c:     sta COLOR_RAM + $000,x
        sta COLOR_RAM + $100,x
        sta COLOR_RAM + $200,x
        sta COLOR_RAM + $300,x
        inx
        bne !c-
        // 4) achtergrond blauw, rand zwart
        lda #PN_BG
        sta BG_COL0
        lda #BLACK
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
        // 8) bitmap + multicolor AAN, met VASTE waarden (bit7 nooit terugschrijven)
        lda #$3b                 // bitmapmodus, DEN, 25 rijen, yscroll 3
        sta VIC_CTRL1
        lda #$d8                 // multicolor aan, 40 kolommen
        sta VIC_CTRL2
        // 9) palet tekenen + startkleur WIT
        jsr paint_DrawPalette
        lda #WHITE
        sta pnCurrent
        rts

//--------------------------------------------------------
// paint_Exit - terug naar char-mode desktop (VASTE $D011/$D016!).
//--------------------------------------------------------
paint_Exit:
        lda #$1b                 // char-mode, DEN, 25 rijen, yscroll 3
        sta VIC_CTRL1
        lda #$c8                 // multicolor uit, 40 kolommen
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
// paint_DrawPalette - 16 stalen (elk 8 dikke-pixels) op de onderste
//                     twee rijen (py 184-199).
//--------------------------------------------------------
paint_DrawPalette:
        lda #0
        sta pnPalSw              // kleurindex 0..15
psw:    lda pnPalSw
        cmp #16
        bcs pdone
        lda #PN_PALTOP
        sta pnPy
ppy:    lda pnPalSw              // fatx-basis = index*8
        asl
        asl
        asl
        sta pnPalFx0
        lda #0
        sta pnPalDx
pfx:    lda pnPalFx0
        clc
        adc pnPalDx
        sta pnFx
        lda pnPalSw
        sta pnCurrent
        jsr paint_Plot
        inc pnPalDx
        lda pnPalDx
        cmp #8
        bne pfx
        inc pnPy
        lda pnPy
        cmp #200
        bne ppy
        inc pnPalSw
        jmp psw
pdone:  rts

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
        lsr                      // fatx / 8 = staalnummer (0..15)
        cmp #16
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
// paint_CursorToFat - cursor (crsX/crsY) -> dikke-pixel (pnFx 0-159)
//                     en py (pnPy 0-199).
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
// paint_Plot - zet dikke-pixel (pnFx,pnPy) op kleur pnCurrent (0-15).
//--------------------------------------------------------
paint_Plot:
        // cellrij / cellkolom
        lda pnPy
        lsr
        lsr
        lsr
        sta pnCellRow
        lda pnFx
        lsr
        lsr
        sta pnCellCol
        // bitmap-pointer = BITMAP + rowLo/Hi[cellrij] + cellcol*8 + (py&7)
        ldx pnCellRow
        lda #<BITMAP
        clc
        adc rowLo,x
        sta pnPtr
        lda #>BITMAP
        adc rowHi,x
        sta pnPtr+1
        lda pnCellCol            // cellcol*8 (16-bit)
        sta pnT0
        lda #0
        sta pnT1
        asl pnT0
        rol pnT1
        asl pnT0
        rol pnT1
        asl pnT0
        rol pnT1
        lda pnPtr
        clc
        adc pnT0
        sta pnPtr
        lda pnPtr+1
        adc pnT1
        sta pnPtr+1
        lda pnPy
        and #7
        clc
        adc pnPtr
        sta pnPtr
        lda pnPtr+1
        adc #0
        sta pnPtr+1
        // matrix-pointer = VMATRIX + mrowLo/Hi[cellrij] + cellcol
        ldx pnCellRow
        lda #<VMATRIX
        clc
        adc mrowLo,x
        sta pnMPtr
        lda #>VMATRIX
        adc mrowHi,x
        sta pnMPtr+1
        lda pnMPtr
        clc
        adc pnCellCol
        sta pnMPtr
        lda pnMPtr+1
        adc #0
        sta pnMPtr+1
        // kleuren-RAM-pointer = matrix-pointer + $9800 (D800-4000)
        lda pnMPtr
        sta pnCPtr
        lda pnMPtr+1
        clc
        adc #$98
        sta pnCPtr+1
        // bepaal bitpaar-code (0..3) voor pnCurrent in deze cel
        jsr pnColorCode
        // waarde = code << shift ; shift uit fatx&3
        lda pnFx
        and #3
        tax
        lda pnCode
        ldy shiftTab,x
        beq !vd+
!vs:    asl
        dey
        bne !vs-
!vd:    sta pnVal
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
// pnColorCode - kies/registreer een bitpaar-code voor pnCurrent in de
//               huidige cel (pnMPtr = matrix, pnCPtr = kleuren-RAM).
//               Resultaat in pnCode (0=bg,1=slot01,2=slot10,3=slot11).
//--------------------------------------------------------
pnColorCode:
        lda pnCurrent
        cmp #PN_BG
        bne !nb+
        lda #0                   // achtergrond
        sta pnCode
        rts
!nb:    ldy #0
        lda (pnMPtr),y
        sta pnMByte
        lsr
        lsr
        lsr
        lsr
        sta pnS01                // slot 01 = hoge nibble
        lda pnMByte
        and #$0f
        sta pnS10                // slot 10 = lage nibble
        ldy #0
        lda (pnCPtr),y
        and #$0f
        sta pnS11                // slot 11 = kleuren-RAM
        // al aanwezig?
        lda pnCurrent
        cmp pnS01
        bne !k2+
        lda #1
        sta pnCode
        rts
!k2:    cmp pnS10
        bne !k3+
        lda #2
        sta pnCode
        rts
!k3:    cmp pnS11
        bne !as+
        lda #3
        sta pnCode
        rts
        // toewijzen aan een vrije (=achtergrond) slot, anders slot 11
!as:    lda pnS01
        cmp #PN_BG
        bne !as2+
        lda pnMByte
        and #$0f
        sta pnT0
        lda pnCurrent
        asl
        asl
        asl
        asl
        ora pnT0
        ldy #0
        sta (pnMPtr),y
        lda #1
        sta pnCode
        rts
!as2:   lda pnS10
        cmp #PN_BG
        bne !as3+
        lda pnMByte
        and #$f0
        ora pnCurrent
        ldy #0
        sta (pnMPtr),y
        lda #2
        sta pnCode
        rts
!as3:   lda pnCurrent            // slot 11 (leeg of overschrijven)
        ldy #0
        sta (pnCPtr),y
        lda #3
        sta pnCode
        rts

//--------------------------------------------------------
// Tabellen
//--------------------------------------------------------
rowLo:    .fill 25, <(i*320)
rowHi:    .fill 25, >(i*320)
mrowLo:   .fill 25, <(i*40)
mrowHi:   .fill 25, >(i*40)
shiftTab: .byte 6, 4, 2, 0       // fatx&3 -> aantal bits schuiven
maskTab:  .byte $c0, $30, $0c, $03

pnCurrent: .byte WHITE
pnFx:      .byte 0
pnPy:      .byte 0
pnVal:     .byte 0
pnCode:    .byte 0
pnCellRow: .byte 0
pnCellCol: .byte 0
pnMByte:   .byte 0
pnS01:     .byte 0
pnS10:     .byte 0
pnS11:     .byte 0
pnT0:      .byte 0
pnT1:      .byte 0
pnPalSw:   .byte 0
pnPalFx0:  .byte 0
pnPalDx:   .byte 0
