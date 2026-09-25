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

//========================================================
// Scrollbalk (Win95-stijl): pijl omhoog, track met thumb, pijl omlaag.
//========================================================
.const SCR_THUMB = 2             // thumb-hoogte in rijen

// scr_Draw - teken een verticale scrollbalk.
// In: a0 = kolom, a1 = rij pijl-omhoog, a2 = rij pijl-omlaag,
//     a3 = huidige positie (0..max), a4 = max (0 = niets te scrollen).
// De parameters blijven bewaard voor scr_Hit.
scr_Draw:
        lda a0
        sta scrCol
        lda a1
        sta scrTop
        lda a2
        sta scrBot
        lda a3
        sta scrPos
        lda a4
        sta scrMax
        jsr scr_Geom
        lda scrCol
        sta a0
        lda scrTop
        sta a1
        lda #GL_UP
        sta a2
        lda TH_menubg
        sta a3
        jsr gfx_PutChar
        lda scrCol
        sta a0
        lda scrBot
        sta a1
        lda #GL_DOWN
        sta a2
        lda TH_menubg
        sta a3
        jsr gfx_PutChar
        ldx scrTop
        inx
!lp:    cpx scrBot
        bcs !done+
        stx scrI
        lda #GL_TRACK
        cpx scrThTop
        bcc !pt+
        cpx scrThEnd
        bcs !pt+
        lda #GL_THUMB            // thumb; onderste rij met schaduw
        inx
        cpx scrThEnd
        bne !pt+
        lda #GL_THUMBEND
!pt:    ldx scrI
        sta a2
        lda scrCol
        sta a0
        stx a1
        lda TH_menubg
        sta a3
        jsr gfx_PutChar
        ldx scrI
        inx
        jmp !lp-
!done:  rts

// scr_Geom - thumb-positie berekenen: scrThTop .. scrThEnd-1.
//   offset = pos * (tracklengte - thumb) / max
scr_Geom:
        lda scrBot
        sec
        sbc scrTop
        sec
        sbc #1
        sta scrLen               // tracklengte
        lda scrMax
        bne !scroll+
        lda #0                   // niets te scrollen: geen thumb (Win95:
        sta scrThTop             // alleen de lege track)
        sta scrThEnd
        rts
!scroll:
        lda #SCR_THUMB
        cmp scrLen
        bcc !tl+
        lda scrLen
!tl:    sta scrThLen
        lda scrLen
        sec
        sbc scrThLen
        sta scrSpan
        lda #0
        sta scrPLo
        sta scrPHi
        ldx scrPos
        beq !div+
!m:     lda scrPLo
        clc
        adc scrSpan
        sta scrPLo
        bcc !n+
        inc scrPHi
!n:     dex
        bne !m-
!div:   ldx #0
!d:     lda scrPLo
        sec
        sbc scrMax
        tay
        lda scrPHi
        sbc #0
        bcc !q+
        sta scrPHi
        sty scrPLo
        inx
        jmp !d-
!q:     cpx scrSpan
        bcc !ok+
        ldx scrSpan
!ok:    txa
        clc
        adc scrTop
        clc
        adc #1
        sta scrThTop
        clc
        adc scrThLen
        sta scrThEnd
        rts

// scr_Hit - klik (evtA,evtB) op de laatst getekende scrollbalk?
// Uit: A = 0 niets, 1 regel omhoog, 2 regel omlaag,
//          3 pagina omhoog, 4 pagina omlaag.
scr_Hit:
        lda evtA
        cmp scrCol
        bne !none+
        lda evtB
        cmp scrTop
        beq !up+
        cmp scrBot
        beq !dn+
        bcs !none+
        cmp scrTop
        bcc !none+
        lda scrMax
        beq !none+
        jsr scr_Geom
        lda evtB
        cmp scrThTop
        bcc !pu+
        cmp scrThEnd
        bcs !pd+
!none:  lda #0
        rts
!up:    lda #1
        rts
!dn:    lda #2
        rts
!pu:    lda #3
        rts
!pd:    lda #4
        rts

//========================================================
// Dialoogvenster (Win95-stijl): titelbalk met sluitknop + kader.
//========================================================
// dlg_Draw - In: a0 = x, a1 = y, a2 = breedte, a3 = hoogte, r0 = titel.
//            Titelbalk op rij y, sluitknop rechtsboven, binnenkant leeg.
dlg_Draw:
        lda #$ff                 // (nog) geen OK-knop
        sta dlgOkY
        lda a0
        sta dlgX
        lda a1
        sta dlgY
        lda a2
        sta dlgW
        lda a3
        sta dlgH
        lda r0
        sta dlgT
        lda r0+1
        sta dlgT+1
        // titelbalk
        lda dlgX
        sta a0
        lda dlgY
        sta a1
        lda dlgW
        sta a2
        lda #1
        sta a3
        lda #$a0
        sta a4
        lda TH_title
        sta a5
        jsr gfx_FillRect
        lda dlgT
        sta r0
        lda dlgT+1
        sta r0+1
        lda dlgX
        clc
        adc #1
        sta a0
        lda dlgY
        sta a1
        lda TH_title
        sta a2
        jsr gfx_DrawTextRev
        // sluitknop (niet bij dlgNoClose, bv. het bureaubladvenster)
        lda dlgX
        clc
        adc dlgW
        sec
        sbc #1
        sta dlgCX
        lda dlgNoClose
        bne !nc+
        lda dlgCX
        sta a0
        lda dlgY
        sta a1
        lda #GL_CLOSE
        sta a2
        lda TH_menubg
        sta a3
        jsr gfx_PutChar
!nc:    // binnenkant + kader (onder de titelbalk)
        lda dlgX
        sta a0
        lda dlgY
        clc
        adc #1
        sta a1
        lda dlgW
        sta a2
        lda dlgH
        sec
        sbc #1
        sta a3
        lda TH_text
        sta a4
        jmp win_Frame

// win_Frame - kader zonder bovenrand (die is de titelbalk) + lege binnenkant.
// In: a0 = x, a1 = eerste rij onder de titelbalk, a2 = breedte,
//     a3 = aantal rijen (incl. onderrand), a4 = kaderkleur.
win_Frame:
        lda a0
        sta wfX
        lda a1
        sta wfY
        lda a2
        sta wfW
        lda a3
        sta wfH
        lda a4
        sta wfC
        // binnenkant leegmaken
        lda wfX
        clc
        adc #1
        sta a0
        lda wfY
        sta a1
        lda wfW
        sec
        sbc #2
        sta a2
        lda wfH
        sec
        sbc #1
        sta a3
        lda #$20
        sta a4
        lda wfC
        sta a5
        jsr gfx_FillRect
        // zijkanten
        ldx #0
!v:     stx wfI
        txa
        clc
        adc wfY
        sta wfRow
        cpx wfH
        bcs !vd+
        lda wfX
        sta a0
        lda wfRow
        sta a1
        lda #W_L
        sta a2
        lda wfC
        sta a3
        jsr gfx_PutChar
        lda wfX
        clc
        adc wfW
        sec
        sbc #1
        sta a0
        lda wfRow
        sta a1
        lda #W_R
        sta a2
        lda wfC
        sta a3
        jsr gfx_PutChar
        ldx wfI
        inx
        jmp !v-
!vd:    // onderrand (laatste rij)
        lda wfY
        clc
        adc wfH
        sec
        sbc #1
        sta wfRow
        lda wfX
        sta a0
        lda wfRow
        sta a1
        lda wfW
        sta a2
        lda #1
        sta a3
        lda #W_B
        sta a4
        lda wfC
        sta a5
        jsr gfx_FillRect
        lda wfX
        sta a0
        lda wfRow
        sta a1
        lda #W_BL
        sta a2
        lda wfC
        sta a3
        jsr gfx_PutChar
        lda wfX
        clc
        adc wfW
        sec
        sbc #1
        sta a0
        lda wfRow
        sta a1
        lda #W_BR
        sta a2
        lda wfC
        sta a3
        jmp gfx_PutChar

// dlg_HitClose - staat (evtA,evtB) op de sluitknop van de laatste dialoog?
// Uit: carry = 1 = raak.
dlg_HitClose:
        lda evtB
        cmp dlgY
        bne !no+
        lda evtA
        cmp dlgCX
        bne !no+
        sec
        rts
!no:    clc
        rts

// dlg_OkButton - Win95 "OK"-knop in de laatste dialoog. In: a0 = x, a1 = y.
dlg_OkButton:
        lda a0
        sta dlgOkX
        lda a1
        sta dlgOkY
        lda #<sDlgOk
        sta r0
        lda #>sDlgOk
        sta r0+1
        lda dlgOkX
        sta a0
        lda dlgOkY
        sta a1
        lda #4
        sta a2
        lda TH_menubg
        sta a3
        jmp btn_Draw

// dlg_WaitClose - modaal wachten tot de dialoog gesloten wordt:
//   klik op de sluitknop of de OK-knop, of ESC (RUN/STOP), SPATIE, RETURN.
dlg_WaitClose:
!w:     jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        beq !click+
        cmp #EVT_KEY
        bne !w-
        lda evtA
        cmp #$82
        beq !x+
        cmp #$20
        beq !x+
        cmp #$80
        beq !x+
        jmp !w-
!click: jsr dlg_HitClose
        bcs !x+
        lda dlgOkY               // OK-knop aanwezig?
        cmp #$ff
        beq !w-
        lda dlgOkX
        sta a0
        lda dlgOkY
        sta a1
        lda #4
        sta a2
        jsr btn_HitTest
        bcc !w-
!x:     jsr sid_Click
        rts

//--------------------------------------------------------
// Widget-scratch (niet-gedeeld met gfx tmp's).
//--------------------------------------------------------
scrCol:   .byte 0
scrTop:   .byte 0
scrBot:   .byte 0
scrPos:   .byte 0
scrMax:   .byte 0
scrI:     .byte 0
scrLen:   .byte 0
scrThLen: .byte 0
scrSpan:  .byte 0
scrThTop: .byte 0
scrThEnd: .byte 0
scrPLo:   .byte 0
scrPHi:   .byte 0
dlgX:     .byte 0
dlgY:     .byte 0
dlgW:     .byte 0
dlgH:     .byte 0
dlgCX:    .byte 0
dlgNoClose: .byte 0
dlgOkX:   .byte 0
dlgOkY:   .byte $ff
.encoding "screencode_upper"
sDlgOk:   .text "OK"
          .byte $ff
dlgT:     .word 0
wfX:      .byte 0
wfY:      .byte 0
wfW:      .byte 0
wfH:      .byte 0
wfC:      .byte 0
wfI:      .byte 0
wfRow:    .byte 0
wCol:   .byte 0
wRow:   .byte 0
wW:     .byte 0
wColor: .byte 0
wTmp:   .byte 0
