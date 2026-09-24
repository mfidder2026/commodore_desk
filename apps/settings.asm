#importonce
//========================================================
// apps/settings.asm - Settings (Fase 9)
// Commodore Desk 64
//
// Pas de thema-kleuren aan (rand, bureaublad, menubalk, accent,
// selectie) en sla ze op naar CD64.CFG op de D71. Elke rol wijst
// naar een TH_*-runtime-variabele; een klik op een kleurstaal zet
// de kleur en past hem meteen toe.
//========================================================

// set_Init - beginrol.
set_Init:
        lda #0
        sta selRole
        rts

//--------------------------------------------------------
// set_Draw - rollen + kleurenkiezer + SAVE.
//--------------------------------------------------------
set_Draw: {
        lda #0
        sta setI
rloop:  lda setI
        cmp #5
        bcc rgo
        jmp rpalette
rgo:    lda setI
        clc
        adc #5
        sta setRow
        // naam
        ldx setI
        lda roleLo,x
        sta r0
        lda roleHi,x
        sta r0+1
        lda #4
        sta a0
        lda setRow
        sta a1
        lda setI
        cmp selRole
        bne notSel
        lda TH_accent            // geselecteerde rol geaccentueerd
        jmp setCol
notSel: lda #THEME_TEXT
setCol: sta a2
        jsr gfx_DrawText
        // kleurstaal van de rol
        lda #18
        sta a0
        lda setRow
        sta a1
        lda #3
        sta a2
        lda #1
        sta a3
        lda #$a0
        sta a4
        ldx setI
        lda TH_border,x
        sta a5
        jsr gfx_FillRect
        inc setI
        jmp rloop
rpalette:
        lda #<sKies
        sta r0
        lda #>sKies
        sta r0+1
        lda #4
        sta a0
        lda #11
        sta a1
        lda #THEME_TEXT
        sta a2
        jsr gfx_DrawText
        // 16 kleurstalen (2 breed) op rij 12
        lda #0
        sta setI
ploop:  lda setI
        cmp #16
        bcc pgo
        jmp pdone
pgo:    lda setI
        asl
        clc
        adc #4
        sta a0
        lda #12
        sta a1
        lda #2
        sta a2
        lda #1
        sta a3
        lda #$a0
        sta a4
        lda setI
        sta a5
        jsr gfx_FillRect
        inc setI
        jmp ploop
pdone:  lda #<sSave
        sta r0
        lda #>sSave
        sta r0+1
        lda #4
        sta a0
        lda #15
        sta a1
        lda #6
        sta a2
        lda #LIGHT_GREY
        sta a3
        jsr btn_Draw
        lda #<sSaveHint
        sta r0
        lda #>sSaveHint
        sta r0+1
        lda #12
        sta a0
        lda #15
        sta a1
        lda #GREY
        sta a2
        jsr gfx_DrawText
        rts
}

//--------------------------------------------------------
// set_Click - rol kiezen / kleur zetten / opslaan.
//--------------------------------------------------------
set_Click: {
        // rollen (rijen 5-9, kol 4-20)
        lda evtB
        cmp #5
        bcc chkPal
        cmp #10
        bcs chkPal
        lda evtA
        cmp #4
        bcc chkPal
        cmp #21
        bcs chkPal
        lda evtB
        sec
        sbc #5
        sta selRole
        jsr set_Draw
        rts
chkPal: // kleurenkiezer (rij 12, kol 4-35)
        lda evtB
        cmp #12
        bne chkSave
        lda evtA
        cmp #4
        bcc done
        cmp #36
        bcs done
        sec
        sbc #4
        lsr
        ldx selRole
        sta TH_border,x
        jsr theme_Apply
        jsr shell_DrawAll
        rts
chkSave: // SAVE-knop (4,15,6)
        lda evtB
        cmp #15
        bne done
        lda #4
        sta a0
        lda #15
        sta a1
        lda #6
        sta a2
        jsr btn_HitTest
        bcc done
        jsr cfg_Save
        lda #<sSaved
        sta r0
        lda #>sSaved
        sta r0+1
        lda #12
        sta a0
        lda #15
        sta a1
        lda #LIGHT_GREEN
        sta a2
        jsr gfx_DrawText
done:   rts
}

//--------------------------------------------------------
selRole: .byte 0
setI:    .byte 0
setRow:  .byte 0

roleLo: .byte <rRand, <rDesk, <rMenu, <rAcc, <rSel
roleHi: .byte >rRand, >rDesk, >rMenu, >rAcc, >rSel

.encoding "screencode_upper"
rRand: .text "RAND"
       .byte $ff
rDesk: .text "BUREAUBLAD"
       .byte $ff
rMenu: .text "MENUBALK"
       .byte $ff
rAcc:  .text "ACCENT"
       .byte $ff
rSel:  .text "SELECTIE"
       .byte $ff
sKies: .text "KIES EEN KLEUR:"
       .byte $ff
sSave: .text "SAVE"
       .byte $ff
sSaveHint: .text "-> CD64.CFG"
           .byte $ff
sSaved: .text "OPGESLAGEN "
        .byte $ff
