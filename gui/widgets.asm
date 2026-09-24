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
// cb_Draw - checkbox "[X] label" of "[ ] label".
// In: a0=kol, a1=rij, a2=aangevinkt (0/1), r0=label
//--------------------------------------------------------
cb_Draw:
        lda a0
        sta wCol
        lda a1
        sta wRow
        lda a2
        sta wChk
        // '['
        lda wCol
        sta a0
        lda wRow
        sta a1
        lda #SC_LBRACK
        sta a2
        lda TH_text
        sta a3
        jsr gfx_PutChar
        // X of spatie
        lda wCol
        clc
        adc #1
        sta a0
        lda wRow
        sta a1
        lda wChk
        beq !empty+
        lda #SC_X
        jmp !setch+
!empty: lda #SC_SPACE
!setch: sta a2
        lda TH_accent
        sta a3
        jsr gfx_PutChar
        // ']'
        lda wCol
        clc
        adc #2
        sta a0
        lda wRow
        sta a1
        lda #SC_RBRACK
        sta a2
        lda TH_text
        sta a3
        jsr gfx_PutChar
        // label op kol+4
        lda wCol
        clc
        adc #4
        sta a0
        lda wRow
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        rts

//--------------------------------------------------------
// cb_HitTest - klik op het vakje (a0=kol,a1=rij, 3 breed)?
//--------------------------------------------------------
cb_HitTest:
        lda evtB
        cmp a1
        bne !no+
        lda evtA
        cmp a0
        bcc !no+
        lda a0
        clc
        adc #3
        sta wTmp
        lda evtA
        cmp wTmp
        bcs !no+
        sec
        rts
!no:    clc
        rts

//--------------------------------------------------------
// dlg_Show - modale OK/ANNULEER-dialoog.
// Uit: A = 1 (OK) of 0 (ANNULEER).
//--------------------------------------------------------
.const DLG_COL = 9
.const DLG_ROW = 7
.const DLG_W   = 22
.const DLG_H   = 9
.const DLG_OKCOL  = 12
.const DLG_OKROW  = 13
.const DLG_OKW    = 6
.const DLG_CANCOL = 21
.const DLG_CANROW = 13
.const DLG_CANW   = 9

dlg_Show:
        jsr dlg_Draw
!loop:  jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        bne !loop-
        // OK?
        lda #DLG_OKCOL
        sta a0
        lda #DLG_OKROW
        sta a1
        lda #DLG_OKW
        sta a2
        jsr btn_HitTest
        bcc !chkCancel+
        lda #1
        rts
!chkCancel:
        lda #DLG_CANCOL
        sta a0
        lda #DLG_CANROW
        sta a1
        lda #DLG_CANW
        sta a2
        jsr btn_HitTest
        bcc !loop-
        lda #0
        rts

dlg_Draw:
        gfxDrawBox(DLG_COL, DLG_ROW, DLG_W, DLG_H, LIGHT_GREY)
        // titelbalk
        lda #DLG_ROW
        sta a0
        lda #THEME_MENUBAR_BG
        sta a2
        // (alleen de dialoogbreedte als balk: teken reverse-titel)
        lda #<dlgTitle
        sta r0
        lda #>dlgTitle
        sta r0+1
        lda #[DLG_COL+2]
        sta a0
        lda #DLG_ROW
        sta a1
        lda #THEME_MENUBAR_BG
        sta a2
        jsr gfx_DrawTextRev
        // bericht
        lda #<dlgMsg
        sta r0
        lda #>dlgMsg
        sta r0+1
        lda #[DLG_COL+2]
        sta a0
        lda #[DLG_ROW+3]
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        // OK-knop
        lda #<sOK
        sta r0
        lda #>sOK
        sta r0+1
        lda #DLG_OKCOL
        sta a0
        lda #DLG_OKROW
        sta a1
        lda #DLG_OKW
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        // ANNULEER-knop
        lda #<sCancel
        sta r0
        lda #>sCancel
        sta r0+1
        lda #DLG_CANCOL
        sta a0
        lda #DLG_CANROW
        sta a1
        lda #DLG_CANW
        sta a2
        lda #LIGHT_GREY
        sta a3
        jsr btn_Draw
        rts

//--------------------------------------------------------
.encoding "screencode_upper"
dlgTitle: .text "BEVESTIGEN"
          .byte $ff
dlgMsg:   .text "WEET JE HET ZEKER?"
          .byte $ff
sOK:      .text " OK "
          .byte $ff
sCancel:  .text " ANNULEER "
          .byte $ff

//--------------------------------------------------------
// Widget-scratch (niet-gedeeld met gfx tmp's).
//--------------------------------------------------------
wCol:   .byte 0
wRow:   .byte 0
wW:     .byte 0
wColor: .byte 0
wChk:   .byte 0
wTmp:   .byte 0
