#importonce
//========================================================
// gui/widgets.asm - herbruikbare GUI-widgets (Fase 6)
// Commodore Desk 64
//
// Knop, checkbox en modale dialoog. De scrollbare lijst zit in
// shell.asm (gebruikt dezelfde primitieven). Alle widgets werken
// met celcoördinaten en de cursor via evtA/evtB.
//
// Widget-routines bewaren hun parameters in w*-variabelen omdat de
// gfx-routines a0-a5/tmp0-7/r4-r5 vernietigen (r0 blijft intact).
//========================================================

// Schermcodes
.const SC_LBRACK = $1b   // [
.const SC_RBRACK = $1d   // ]
.const SC_X      = $18   // X
.const SC_SPACE  = $20

//--------------------------------------------------------
// btn_Draw - knop: gekleurd blok + reverse-label.
// In: a0=kol, a1=rij, a2=breedte, a3=blokkleur, r0=label
//--------------------------------------------------------
btn_Draw:
        lda a0
        sta wCol
        lda a1
        sta wRow
        lda a2
        sta wW
        lda a3
        sta wColor
        // blok vullen
        lda wCol
        sta a0
        lda wRow
        sta a1
        lda wW
        sta a2
        lda #1
        sta a3
        lda #$a0
        sta a4
        lda wColor
        sta a5
        jsr gfx_FillRect
        // label (reverse) op kol+1
        lda wCol
        clc
        adc #1
        sta a0
        lda wRow
        sta a1
        lda wColor
        sta a2
        jsr gfx_DrawTextRev      // r0 = label (nog intact)
        rts

//--------------------------------------------------------
// btn_HitTest - zit (evtA,evtB) op de knop (a0=kol,a1=rij,a2=br)?
// Uit: carry=1 = raak.
//--------------------------------------------------------
btn_HitTest:
        lda evtB
        cmp a1
        bne !no+
        lda evtA
        cmp a0
        bcc !no+
        lda a0
        clc
        adc a2
        sta wTmp
        lda evtA
        cmp wTmp
        bcs !no+
        sec
        rts
!no:    clc
        rts

//--------------------------------------------------------
// Widget-scratch (niet-gedeeld met gfx tmp's).
//--------------------------------------------------------
wCol:   .byte 0
wRow:   .byte 0
wW:     .byte 0
wColor: .byte 0
wTmp:   .byte 0
