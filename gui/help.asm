#importonce
//========================================================
// gui/help.asm - F1 contextgevoelig HELP-scherm
// Commodore Desk 64
//
// F1 opent een help-paneel met tekst die afhangt van de actieve app.
// De spatiebalk sluit het weer (modale lus, IRQ blijft input pollen).
//========================================================

help_Show: {
        gfxDrawBox(3, 7, 34, 9, LIGHT_GREY)      // rijen 7-15
        // titel
        lda #<hTitle
        sta r0
        lda #>hTitle
        sta r0+1
        lda #5
        sta a0
        lda #8
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        // contextregels op basis van de actieve app (+1: 0=bureaublad)
        ldx activeApp
        inx
        lda help1Lo,x
        sta r0
        lda help1Hi,x
        sta r0+1
        lda #5
        sta a0
        lda #10
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
        lda #11
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        // sluit-hint
        lda #<hClose
        sta r0
        lda #>hClose
        sta r0+1
        lda #5
        sta a0
        lda #13
        sta a1
        lda TH_select
        sta a2
        jsr gfx_DrawText
        // modaal: wachten op spatie
wait:   jsr evt_Poll
        cmp #EVT_KEY
        bne wait
        lda evtA
        cmp #$20
        bne wait
        jmp shell_DrawAll        // sluiten + scherm herstellen
}

//--------------------------------------------------------
help1Lo: .byte <hd1, <hf1, <he1, <hp1, <hc1, <hs1, <hi1
help1Hi: .byte >hd1, >hf1, >he1, >hp1, >hc1, >hs1, >hi1
help2Lo: .byte <hd2, <hf2, <he2, <hp2, <hc2, <hs2, <hi2
help2Hi: .byte >hd2, >hf2, >he2, >hp2, >hc2, >hs2, >hi2

.encoding "screencode_upper"
hTitle: .text "HELP"
        .byte $ff
hClose: .text "SPACE = CLOSE"
        .byte $ff

hd1: .text "CLICK A DOCK ICON TO OPEN"
     .byte $ff
hd2: .text "AN APP.  PRESS F1 FOR HELP."
     .byte $ff
hf1: .text "CLICK A FILE TO SELECT."
     .byte $ff
hf2: .text "UP/DN SCROLL. ESC EXITS."
     .byte $ff
he1: .text "TYPE TO EDIT TEXT."
     .byte $ff
he2: .text "PRESS ESC TO EXIT."
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
hi1: .text "INTERNET APPS - COMING SOON."
     .byte $ff
hi2: .text "MAIL, CHAT, RSS, FTP, PING."
     .byte $ff
