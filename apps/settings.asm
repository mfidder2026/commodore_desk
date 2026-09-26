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

.const CLK_ROW = 17
.const CLK_COL = 11

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
notSel: lda TH_text
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
        lda TH_text
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
        lda TH_accent            // accentkleur -> leesbaar op elk thema
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
        // FONT-keuze (rij 13) - klik om te wisselen
        lda #<sFont
        sta r0
        lda #>sFont
        sta r0+1
        lda #4
        sta a0
        lda #13
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        ldx CFG_fontId
        lda fontNameLo,x
        sta r0
        lda fontNameHi,x
        sta r0+1
        lda #10
        sta a0
        lda #13
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        // MENU-stijl (rij 14) - klik om te wisselen
        lda #<sMenu
        sta r0
        lda #>sMenu
        sta r0+1
        lda #4
        sta a0
        lda #14
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        ldx CFG_menuFill
        lda menuNameLo,x
        sta r0
        lda menuNameHi,x
        sta r0+1
        lda #10
        sta a0
        lda #14
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        // THEME-profiel (rij 3) - klik om te wisselen
        lda #<sProf
        sta r0
        lda #>sProf
        sta r0+1
        lda #4
        sta a0
        lda #3
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        ldx CFG_profile
        lda profNameLo,x
        sta r0
        lda profNameHi,x
        sta r0+1
        lda #11
        sta a0
        lda #3
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        // SOUND (rij 4) - klik om te wisselen
        lda #<sSound
        sta r0
        lda #>sSound
        sta r0+1
        lda #4
        sta a0
        lda #4
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        ldx CFG_sound
        lda soundNameLo,x
        sta r0
        lda soundNameHi,x
        sta r0+1
        lda #11
        sta a0
        lda #4
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        jmp clk_Row
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
        bcs !+
        jmp done
!:      cmp #36
        bcc !+
        jmp done
!:      sec
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
        bne chkFont
        lda #4
        sta a0
        lda #15
        sta a1
        lda #6
        sta a2
        jsr btn_HitTest
        bcs !+
        jmp done
!:      jsr cfg_Save
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
        rts
chkFont: // FONT-regel (rij 13, kol 4-20) -> open keuzelijst
        lda evtB
        cmp #13
        bne chkMenu
        lda evtA
        cmp #4
        bcs !+
        rts
!:      cmp #21
        bcc !+
        rts
!:      jsr font_Pick            // modale keuzelijst; laadt pas bij keuze
        jsr shell_DrawAll        // alles opnieuw tekenen met het nieuwe font
        rts
chkMenu: // MENU-regel (rij 14, kol 4-20) -> stijl wisselen
        lda evtB
        cmp #14
        bne chkProf
        lda evtA
        cmp #4
        bcs !+
        rts
!:      cmp #21
        bcc !+
        rts
!:
        lda CFG_menuFill
        eor #1
        sta CFG_menuFill
        jsr set_Draw
        rts
chkProf: // THEME-regel (rij 3, kol 4-20) -> volgend profiel
        lda evtB
        cmp #3
        bne chkSound
        lda evtA
        cmp #4
        bcs !+
        rts
!:      cmp #21
        bcc !+
        rts
!:
        lda CFG_profile
        clc
        adc #1
        cmp #NUM_PROFILES
        bcc !+
        lda #0
!:      sta CFG_profile
        jsr profile_Apply
        jsr shell_DrawAll
        rts
chkSound: // SOUND-regel (rij 4, kol 4-20) -> aan/uit
        lda evtB
        cmp #CLK_ROW             // CLOCK-regel -> datum/tijd typen
        bne !+
        jmp clk_Edit
!:      cmp #4
        bne done
        lda evtA
        cmp #4
        bcs !+
        rts
!:      cmp #21
        bcc !+
        rts
!:
        lda CFG_sound
        eor #1
        sta CFG_sound
        jsr sid_Click            // klik-feedback met de nieuwe stand
        jsr set_Draw
done:   rts
}

//--------------------------------------------------------
// font_Pick - modale keuzelijst met alle fonts. Bladeren zonder te
//             laden; pas bij een keuze wordt het font toegepast.
//--------------------------------------------------------
font_Pick: {
        gfxDrawBoxM(3, 4, 18, 12, TH_text)      // cols 3-20, rijen 4-15
        lda #0
        sta fpI
draw:   lda fpI
        cmp #NUM_FONTS
        bcs wait
        ldx fpI
        lda fontNameLo,x
        sta r0
        lda fontNameHi,x
        sta r0+1
        lda #5
        sta a0
        lda fpI
        clc
        adc #5
        sta a1
        lda fpI                  // huidige keuze gemarkeerd
        cmp CFG_fontId
        bne norm
        lda TH_select
        jmp col
norm:   lda TH_text
col:    sta a2
        jsr gfx_DrawText
        inc fpI
        jmp draw
wait:   jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        beq click
        cmp #EVT_KEY
        bne wait
        lda evtA
        cmp #$20
        beq key
        cmp #$80
        beq key
        cmp #$82                 // ESC = annuleren
        beq done
        jmp wait
key:    jsr cursorToCell
click:  lda evtA                 // binnen de box-kolommen?
        cmp #4
        bcc done
        cmp #21
        bcs done
        lda evtB
        sec
        sbc #5                   // rij -> index
        cmp #NUM_FONTS
        bcs done                 // buiten de lijst
        sta CFG_fontId
        jsr font_Apply
done:   rts
}
fpI:    .byte 0

//--------------------------------------------------------
// CLOCK-regel: "CLOCK: DD-MM-YYYY HH:MM". Klik -> cijfers typen
// (DEL = terug), RETURN = instellen, ESC of klik = annuleren.
//--------------------------------------------------------

// clk_Row - label + huidige datum/tijd (cijfers uit ckDig).
clk_Row:
        jsr ck_Load
        lda #$ff
        sta ckPos                // geen cursor
ck_Show: {
        lda #<sClock
        sta r0
        lda #>sClock
        sta r0+1
        lda #4
        sta a0
        lda #CLK_ROW
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        ldx #0                   // sjabloon met cijfers vullen
        ldy #0
lp:     lda ckTpl,x
        cmp #$ff
        beq show
        cmp #$23                 // '#' = cijferplek
        bne put
        lda ckDig,y
        ora #$30
        cpy ckPos
        bne nrm
        ora #$80                 // cursor = reverse
nrm:    iny
put:    sta ckLine,x
        inx
        bne lp
show:   sta ckLine,x
        lda #<ckLine
        sta r0
        lda #>ckLine
        sta r0+1
        lda #CLK_COL
        sta a0
        lda #CLK_ROW
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
}

// ck_Load - huidige datum/tijd -> 12 cijfers (DDMMYYYYHHMM).
ck_Load: {
        jsr clk_Read
        ldx #0
        lda clkDay
        jsr two
        lda clkMon
        jsr two
        lda clkYearHi
        jsr two
        lda clkYearLo
        jsr two
        lda clkHour
        jsr two
        lda clkMin
two:    pha
        lsr
        lsr
        lsr
        lsr
        sta ckDig,x
        inx
        pla
        and #$0f
        sta ckDig,x
        inx
        rts
}

// clk_Edit - modale invoer op de CLOCK-regel.
clk_Edit: {
        jsr ck_Load
        lda #0
        sta ckPos
        beq draw
cancel: jmp clk_Row
draw:   jsr ck_Show
wait:   jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        beq cancel
        cmp #EVT_KEY
        bne wait
        lda evtA
        cmp #$82                 // ESC
        beq cancel
        cmp #$80                 // RETURN
        beq ok
        cmp #$81                 // DEL
        beq back
        cmp #$30
        bcc wait
        cmp #$3a
        bcs wait
        and #$0f
        ldx ckPos
        sta ckDig,x
        cpx #11
        beq draw                 // laatste cijfer: blijven staan
        inc ckPos
        jmp draw
back:   lda ckPos
        beq wait
        dec ckPos
        jmp draw
ok:     // BCD samenstellen en controleren
        ldx #0
        jsr pair
        sta ckDay
        jsr pair
        sta ckMon
        jsr pair
        sta ckYH
        jsr pair
        sta ckYL
        jsr pair
        sta ckHr
        jsr pair
        sta ckMn
        lda ckDay
        beq bad
        cmp #$32
        bcs bad
        lda ckMon
        beq bad
        cmp #$13
        bcs bad
        lda ckHr
        cmp #$24
        bcs bad
        lda ckMn
        cmp #$60
        bcs bad
        lda ckDay
        sta clkDay
        lda ckMon
        sta clkMon
        lda ckYH
        sta clkYearHi
        lda ckYL
        sta clkYearLo
        jsr clk_DaysInMonth      // 31-02 e.d. -> laatste dag van de maand
        cmp clkDay
        bcs dOk
        sta clkDay
dOk:    lda ckHr
        ldx ckMn
        jsr clk_SetTime
        jsr drawStatus           // statusbalk meteen bijwerken
        jmp clk_Row
bad:    jsr sid_Click            // ongeldig: blijven typen
        jmp wait
pair:   lda ckDig,x              // 2 cijfers -> BCD
        asl
        asl
        asl
        asl
        inx
        ora ckDig,x
        inx
        rts
}

selRole: .byte 0
setI:    .byte 0
setRow:  .byte 0
ckPos:   .byte 0
ckDig:   .fill 12, 0
ckLine:  .fill 17, 0
ckDay:   .byte 0
ckMon:   .byte 0
ckYH:    .byte 0
ckYL:    .byte 0
ckHr:    .byte 0
ckMn:    .byte 0

roleLo: .byte <rRand, <rDesk, <rMenu, <rAcc, <rSel
roleHi: .byte >rRand, >rDesk, >rMenu, >rAcc, >rSel

fontNameLo: .byte <fSystem, <fClassic, <fBold, <fLower, <fTiny, <fFremen, <fSerif, <fMono, <fCasual, <fHeavy
fontNameHi: .byte >fSystem, >fClassic, >fBold, >fLower, >fTiny, >fFremen, >fSerif, >fMono, >fCasual, >fHeavy

menuNameLo: .byte <mClear, <mFilled
menuNameHi: .byte >mClear, >mFilled

profNameLo: .byte <pC64, <pMatrix, <pPaper
profNameHi: .byte >pC64, >pMatrix, >pPaper

soundNameLo: .byte <sNo, <sYes
soundNameHi: .byte >sNo, >sYes

.encoding "screencode_upper"
rRand: .text "BORDER"
       .byte $ff
rDesk: .text "WINDOW"
       .byte $ff
rMenu: .text "BARS"
       .byte $ff
rAcc:  .text "ACCENT"
       .byte $ff
rSel:  .text "SELECT"
       .byte $ff
sKies: .text "PICK A COLOR:"
       .byte $ff
sSave: .text "SAVE"
       .byte $ff
sSaveHint: .text "-> CD64.CFG"
           .byte $ff
sSaved: .text "SAVED      "
        .byte $ff
sFont:  .text "FONT:"
        .byte $ff
fSystem:  .text "SYSTEM "
          .byte $ff
fClassic: .text "CLASSIC"
          .byte $ff
fBold:    .text "BOLD   "
          .byte $ff
fLower:   .text "LOWER  "
          .byte $ff
fTiny:    .text "TINY   "
          .byte $ff
fFremen:  .text "FREMEN "
          .byte $ff
fSerif:   .text "SERIF  "
          .byte $ff
fMono:    .text "MONO   "
          .byte $ff
fCasual:  .text "CASUAL "
          .byte $ff
fHeavy:   .text "HEAVY  "
          .byte $ff
sMenu:  .text "MENU:"
        .byte $ff
mClear:  .text "CLEAR "
         .byte $ff
mFilled: .text "FILLED"
         .byte $ff
sProf:  .text "THEME:"
        .byte $ff
pC64:    .text "C64    "
         .byte $ff
pMatrix: .text "MATRIX "
         .byte $ff
pPaper:  .text "PAPER  "
         .byte $ff
sSound:  .text "SOUND:"
         .byte $ff
sClock:  .text "CLOCK:"
         .byte $ff
ckTpl:   .text "##-##-#### ##:##"
         .byte $ff
sNo:     .text "NO "
         .byte $ff
sYes:    .text "YES"
         .byte $ff
