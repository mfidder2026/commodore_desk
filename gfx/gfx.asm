#importonce
//========================================================
// gfx/gfx.asm - teken-primitieven (char-mode)
// Commodore Desk 64  (Fase 2)
//
// Coördinaten in cellen (kol 0-39, rij 0-24). Kleur = index 0-15.
// Scherm-RAM $0400, kleuren-RAM $D800 (scherm-hi + $D4).
// Vereist FR_* uit gfx/font.asm (dus font.asm eerder importeren).
//========================================================

//--------------------------------------------------------
// Handige macro's.
//--------------------------------------------------------
.macro gfxCls(color) {
        lda #color
        sta a2
        jsr gfx_Cls
}
.macro gfxDrawText(strAddr, col, row, color) {
        lda #<strAddr
        sta r0
        lda #>strAddr
        sta r0+1
        lda #col
        sta a0
        lda #row
        sta a1
        lda #color
        sta a2
        jsr gfx_DrawText
}
.macro gfxDrawBox(col, row, w, h, color) {
        lda #col
        sta a0
        lda #row
        sta a1
        lda #w
        sta a2
        lda #h
        sta a3
        lda #color
        sta a4
        jsr gfx_DrawBox
}
.macro gfxFillRect(col, row, w, h, ch, color) {
        lda #col
        sta a0
        lda #row
        sta a1
        lda #w
        sta a2
        lda #h
        sta a3
        lda #ch
        sta a4
        lda #color
        sta a5
        jsr gfx_FillRect
}
.macro gfxBar(row, color) {
        lda #row
        sta a0
        lda #color
        sta a2
        jsr gfx_BarRow
}
.macro gfxDrawTextRev(strAddr, col, row, color) {
        lda #<strAddr
        sta r0
        lda #>strAddr
        sta r0+1
        lda #col
        sta a0
        lda #row
        sta a1
        lda #color
        sta a2
        jsr gfx_DrawTextRev
}

//--------------------------------------------------------
// Rij-adrestabellen (scherm-RAM begin per rij).
//--------------------------------------------------------
screenLo: .fill 25, <[$0400 + i*40]
screenHi: .fill 25, >[$0400 + i*40]

//--------------------------------------------------------
// gfx_PutChar - schrijf één cel.
// In: a0=kol, a1=rij, a2=screencode, a3=kleur
// Klobbert: A,X,Y, r4, r5
//--------------------------------------------------------
gfx_PutChar:
        ldx a1
        lda screenLo,x
        clc
        adc a0
        sta r4
        lda screenHi,x
        adc #0
        sta r4+1
        lda r4
        sta r5
        lda r4+1
        clc
        adc #$d4                 // scherm-hi -> kleuren-RAM-hi
        sta r5+1
        ldy #0
        lda a2
        sta (r4),y
        lda a3
        sta (r5),y
        rts

//--------------------------------------------------------
// gfx_DrawText - string ($ff-getermineerd, screencodes).
// In: r0=pointer, a0=kol, a1=rij, a2=kleur
// Klobbert: A,X,Y, r4, r5
//--------------------------------------------------------
gfx_DrawText:
        ldx a1
        lda screenLo,x
        clc
        adc a0
        sta r4
        lda screenHi,x
        adc #0
        sta r4+1
        lda r4
        sta r5
        lda r4+1
        clc
        adc #$d4
        sta r5+1
        ldy #0
!lp:    lda (r0),y
        cmp #$ff
        beq !done+
        sta (r4),y
        lda a2
        sta (r5),y
        iny
        bne !lp-
!done:
        rts

//--------------------------------------------------------
// gfx_BarRow - vul een hele rij met een gekleurd blok ($A0).
// In: a0=rij, a2=kleur.  Klobbert: A,X,Y, r4, r5
//--------------------------------------------------------
gfx_BarRow:
        ldx a0
        lda screenLo,x
        sta r4
        lda screenHi,x
        sta r4+1
        lda r4
        sta r5
        lda r4+1
        clc
        adc #$d4
        sta r5+1
        ldy #0
!lp:    lda #$a0
        sta (r4),y
        lda a2
        sta (r5),y
        iny
        cpy #40
        bne !lp-
        rts

//--------------------------------------------------------
// gfx_DrawTextRev - reverse-tekst (glyph in achtergrondkleur op
// een gekleurd blok). Voor menubalk/statusbalk/knoppen.
// In: r0=pointer, a0=kol, a1=rij, a2=kleur (van het blok)
// Klobbert: A,X,Y, r4, r5
//--------------------------------------------------------
gfx_DrawTextRev:
        ldx a1
        lda screenLo,x
        clc
        adc a0
        sta r4
        lda screenHi,x
        adc #0
        sta r4+1
        lda r4
        sta r5
        lda r4+1
        clc
        adc #$d4
        sta r5+1
        ldy #0
!lp:    lda (r0),y
        cmp #$ff
        beq !done+
        ora #$80                 // reverse-video
        sta (r4),y
        lda a2
        sta (r5),y
        iny
        bne !lp-
!done:
        rts

//--------------------------------------------------------
// gfx_Cls - wis scherm (spaties), vul kleuren-RAM.
// In: a2 = kleur.  Klobbert: A,X
//--------------------------------------------------------
gfx_Cls:
        lda #$20
        ldx #0
!lp:    sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $0700,x
        inx
        bne !lp-
        lda a2
        ldx #0
!lp:    sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $db00,x
        inx
        bne !lp-
        rts

//--------------------------------------------------------
// gfx_FillRect - rechthoek vullen met teken + kleur.
// In: a0=kol, a1=rij, a2=breedte, a3=hoogte, a4=teken, a5=kleur
// Klobbert: A,X,Y, r4, r5, tmp0-tmp7
//--------------------------------------------------------
gfx_FillRect:
        lda a2
        sta tmp0                 // breedte
        lda a3
        sta tmp1                 // hoogte
        lda a4
        sta tmp2                 // teken
        lda a5
        sta tmp3                 // kleur
        lda a0
        sta tmp4                 // x0
        lda a1
        sta tmp5                 // y0
        lda #0
        sta tmp6                 // rij-index
!row:   lda tmp6
        cmp tmp1
        bcs !done+
        lda #0
        sta tmp7                 // kol-index
!col:   lda tmp7
        cmp tmp0
        bcs !nextrow+
        lda tmp4
        clc
        adc tmp7
        sta a0
        lda tmp5
        clc
        adc tmp6
        sta a1
        lda tmp2
        sta a2
        lda tmp3
        sta a3
        jsr gfx_PutChar
        inc tmp7
        jmp !col-
!nextrow:
        inc tmp6
        jmp !row-
!done:
        rts

//--------------------------------------------------------
// gfx_DrawBox - kader met de UI-lijnglyphs (w,h >= 2).
// In: a0=kol, a1=rij, a2=breedte, a3=hoogte, a4=kleur
// Klobbert: A,X,Y, r4, r5, tmp0-tmp7
//--------------------------------------------------------
gfx_DrawBox:
        lda a0
        sta tmp0                 // x0
        lda a1
        sta tmp1                 // y0
        lda a2
        sta tmp2                 // w
        lda a3
        sta tmp3                 // h
        lda a4
        sta tmp4                 // kleur
        // xR = x0 + w - 1
        lda tmp0
        clc
        adc tmp2
        sec
        sbc #1
        sta tmp5
        // yB = y0 + h - 1
        lda tmp1
        clc
        adc tmp3
        sec
        sbc #1
        sta tmp6

        lda tmp4
        sta a3                   // kleur voor alle PutChar-calls

        // hoeken
        lda tmp0
        sta a0
        lda tmp1
        sta a1
        lda #FR_TL
        sta a2
        jsr gfx_PutChar
        lda tmp5
        sta a0
        lda tmp1
        sta a1
        lda #FR_TR
        sta a2
        jsr gfx_PutChar
        lda tmp0
        sta a0
        lda tmp6
        sta a1
        lda #FR_BL
        sta a2
        jsr gfx_PutChar
        lda tmp5
        sta a0
        lda tmp6
        sta a1
        lda #FR_BR
        sta a2
        jsr gfx_PutChar

        // boven- en onderrand (kolommen x0+1 .. xR-1)
        lda tmp0
        clc
        adc #1
        sta tmp7
!h:     lda tmp7
        cmp tmp5
        bcs !hdone+
        lda tmp4
        sta a3
        lda #FR_H
        sta a2
        lda tmp7
        sta a0
        lda tmp1
        sta a1
        jsr gfx_PutChar
        lda #FR_H
        sta a2
        lda tmp4
        sta a3
        lda tmp7
        sta a0
        lda tmp6
        sta a1
        jsr gfx_PutChar
        inc tmp7
        jmp !h-
!hdone:
        // linker- en rechterrand (rijen y0+1 .. yB-1)
        lda tmp1
        clc
        adc #1
        sta tmp7
!v:     lda tmp7
        cmp tmp6
        bcs !vdone+
        lda tmp4
        sta a3
        lda #FR_V
        sta a2
        lda tmp0
        sta a0
        lda tmp7
        sta a1
        jsr gfx_PutChar
        lda #FR_V
        sta a2
        lda tmp4
        sta a3
        lda tmp5
        sta a0
        lda tmp7
        sta a1
        jsr gfx_PutChar
        inc tmp7
        jmp !v-
!vdone:
        // Bij FILLED: binnenkant wissen naar de achtergrond, zodat de box
        // ondoorzichtig is (je ziet niet meer wat erachter staat).
        lda CFG_menuFill
        beq !nofill+
        lda tmp0
        clc
        adc #1
        sta a0                   // x0+1
        lda tmp1
        clc
        adc #1
        sta a1                   // y0+1
        lda tmp2
        sec
        sbc #2
        sta a2                   // w-2
        lda tmp3
        sec
        sbc #2
        sta a3                   // h-2
        lda #$20
        sta a4
        lda TH_deskbg
        sta a5
        jsr gfx_FillRect
!nofill:
        rts
