#importonce
//========================================================
// apps/paint.asm - Paint (Fase 9, char-mode)
// Commodore Desk 64
//
// Eenvoudige "blok-paint": een 32x10 canvas van cellen die je met
// de gekozen kleur vult (klik). Onderaan een 16-kleuren-palet.
// (Een echte hi-res/multicolor bitmap-paint is een latere upgrade.)
//========================================================

.const PNW = 32
.const PNH = 11
.label pnPtr = $3c

// paint_Init - canvas leeg ($ff), witte kleur.
paint_Init:
        lda #1
        sta pnCurrent
        ldx #0
!lp:    lda #$ff
        sta paintBuf,x
        sta paintBuf + 96,x      // paintBuf[0..351] = 352 cellen (32x11)
        inx
        bne !lp-
        rts

//--------------------------------------------------------
// paint_Draw - canvas + palet.
//--------------------------------------------------------
paint_Draw: {
        gfxDrawBox(2, 4, 36, 13, LIGHT_GREY)
        lda #0
        sta pnRowIdx
prow:   lda pnRowIdx
        cmp #PNH
        bcc prowGo
        jmp palette
prowGo: lda #0
        sta pnColIdx
pcol:   lda pnColIdx
        cmp #PNW
        bcc pcolGo
        inc pnRowIdx
        jmp prow
pcolGo: lda pnColIdx
        sta pnDCol
        lda pnRowIdx
        sta pnDRow
        jsr paint_DrawCell
        inc pnColIdx
        jmp pcol
palette:
        lda #0
        sta pnColIdx
ploop:  lda pnColIdx
        cmp #16
        bcc pgo
        jmp pdone
pgo:    lda pnColIdx
        asl
        clc
        adc #4
        sta a0
        lda #17
        sta a1
        lda #2
        sta a2
        lda #1
        sta a3
        lda #$a0
        sta a4
        lda pnColIdx
        sta a5
        jsr gfx_FillRect
        inc pnColIdx
        jmp ploop
pdone:  lda #<sKleur
        sta r0
        lda #>sKleur
        sta r0+1
        lda #4
        sta a0
        lda #18
        sta a1
        lda #THEME_TEXT
        sta a2
        jsr gfx_DrawText
        jsr drawCurrent
        rts
}

// drawCurrent - blokje van de huidige kleur.
drawCurrent:
        lda #11
        sta a0
        lda #18
        sta a1
        lda #3
        sta a2
        lda #1
        sta a3
        lda #$a0
        sta a4
        lda pnCurrent
        sta a5
        jmp gfx_FillRect

//--------------------------------------------------------
// paint_DrawCell - teken canvas-cel (pnDCol,pnDRow).
//--------------------------------------------------------
paint_DrawCell:
        lda pnDRow
        jsr pnSetPtr
        ldy pnDCol
        lda (pnPtr),y
        cmp #$ff
        beq empty
        sta pnColor
        lda pnDCol
        clc
        adc #3
        sta a0
        lda pnDRow
        clc
        adc #5
        sta a1
        lda #$a0
        sta a2
        lda pnColor
        sta a3
        jmp gfx_PutChar
empty:  lda pnDCol
        clc
        adc #3
        sta a0
        lda pnDRow
        clc
        adc #5
        sta a1
        lda #$20
        sta a2
        lda TH_deskbg
        sta a3
        jmp gfx_PutChar

// pnSetPtr - pnPtr = paintBuf + row*32 (row in A).
pnSetPtr:
        sta pnTmp
        lda #0
        sta pnPtr+1
        lda pnTmp
        asl
        rol pnPtr+1
        asl
        rol pnPtr+1
        asl
        rol pnPtr+1
        asl
        rol pnPtr+1
        asl
        rol pnPtr+1
        sta pnPtr
        lda pnPtr
        clc
        adc #<paintBuf
        sta pnPtr
        lda pnPtr+1
        adc #>paintBuf
        sta pnPtr+1
        rts

//--------------------------------------------------------
// paint_Click - canvas verven / kleur kiezen.
//--------------------------------------------------------
paint_Click: {
        // canvas (kol 3-34, rij 5-15)
        lda evtB
        cmp #5
        bcc chkPal
        cmp #16
        bcs chkPal
        lda evtA
        cmp #3
        bcc chkPal
        cmp #35
        bcs chkPal
        lda evtB
        sec
        sbc #5
        sta pnDRow
        lda evtA
        sec
        sbc #3
        sta pnDCol
        lda pnDRow
        jsr pnSetPtr
        ldy pnDCol
        lda pnCurrent
        sta (pnPtr),y
        jsr paint_DrawCell
        rts
chkPal: // palet (rij 17, kol 4-35)
        lda evtB
        cmp #17
        bne done
        lda evtA
        cmp #4
        bcc done
        cmp #36
        bcs done
        sec
        sbc #4
        lsr
        sta pnCurrent
        jsr drawCurrent
done:   rts
}

//--------------------------------------------------------
pnCurrent: .byte 1
pnColor:   .byte 0
pnDCol:    .byte 0
pnDRow:    .byte 0
pnRowIdx:  .byte 0
pnColIdx:  .byte 0
pnTmp:     .byte 0

.encoding "screencode_upper"
sKleur:    .text "COLOR:"
           .byte $ff

paintBuf:  .fill PNW * PNH, $ff
