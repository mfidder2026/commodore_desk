#importonce
//========================================================
// gui/help.asm - F1 contextgevoelig HELP-scherm
// Commodore Desk 64
//
// F1 opent een help-paneel met tekst die afhangt van de actieve app.
// De spatiebalk sluit het weer (modale lus, IRQ blijft input pollen).
//========================================================

help_Show: {
        // Win95-dialoog met titelbalk + sluitknop (rijen 7-15)
        lda #<hTitle
        sta r0
        lda #>hTitle
        sta r0+1
        lda #3
        sta a0
        lda #7
        sta a1
        lda #34
        sta a2
        lda #9
        sta a3
        jsr dlg_Draw
        // contextregels op basis van de actieve app (+1: 0=bureaublad)
        ldx activeApp
        inx
        lda help1Lo,x
        sta r0
        lda help1Hi,x
        sta r0+1
        lda #5
        sta a0
        lda #9
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        ldx activeApp
        inx
        lda help2Lo,x
        sta r0
        lda help2Hi,x
        sta r0+1
        lda #5
        sta a0
        lda #10
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        lda #<hClose             // hoe sluiten
        sta r0
        lda #>hClose
        sta r0+1
        lda #5
        sta a0
        lda #12
        sta a1
        lda TH_title
        sta a2
        jsr gfx_DrawText
        lda #18                  // OK-knop
        sta a0
        lda #13
        sta a1
        jsr dlg_OkButton
        jsr dlg_WaitClose
        jmp shell_DrawAll        // sluiten + scherm herstellen
}

//--------------------------------------------------------
help1Lo: .byte <hd1, <hf1, <he1, <hp1, <hc1, <hs1, <hi1, <hg1, <ht1
help1Hi: .byte >hd1, >hf1, >he1, >hp1, >hc1, >hs1, >hi1, >hg1, >ht1
help2Lo: .byte <hd2, <hf2, <he2, <hp2, <hc2, <hs2, <hi2, <hg2, <ht2
help2Hi: .byte >hd2, >hf2, >he2, >hp2, >hc2, >hs2, >hi2, >hg2, >ht2

.encoding "screencode_upper"
hTitle: .text "HELP"
        .byte $ff
hClose: .text "ESC OR THE X BUTTON CLOSES"
        .byte $ff

hd1: .text "CLICK AN ICON TO START IT."
     .byte $ff
hd2: .text "MENU: ADD/EDIT/DELETE PRG."
     .byte $ff
hf1: .text "CLICK A FILE TO SELECT."
     .byte $ff
hf2: .text "SCROLL WITH THE RIGHT BAR."
     .byte $ff
he1: .text "TYPE TO EDIT TEXT."
     .byte $ff
he2: .text "ESC OR X CLOSES THE WINDOW."
     .byte $ff
hp1: .text "PICK A COLOR, CLICK CANVAS."
     .byte $ff
hp2: .text "ESC EXITS."
     .byte $ff
hc1: .text "CLICK KEYS TO CALCULATE."
     .byte $ff
hc2: .text "C CLEARS. ESC EXITS."
     .byte $ff
hs1: .text "CLICK A ROLE, THEN A COLOR."
     .byte $ff
hs2: .text "SAVE WRITES CD64.CFG."
     .byte $ff
hi1: .text "CLICK A VALUE TO CHANGE IT."
     .byte $ff
hi2: .text "SAVE WRITES NET.CFG."
     .byte $ff
hg1: .text "CLICK TARGET TO CHANGE IT."
     .byte $ff
hg2: .text "START SENDS 4 PINGS."
     .byte $ff
ht1: .text "TYPE A QUESTION, PRESS RETURN."
     .byte $ff
ht2: .text "SERVER: SEE INET - NETWORK."
     .byte $ff
