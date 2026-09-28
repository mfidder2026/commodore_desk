#importonce
//========================================================
// gui/help.asm - F1: contextgevoelige hulp, overal
// Commodore Desk 64
//
// F1 wordt centraal in evt_Poll opgevangen (kernel/events.asm), dus in de
// hoofdlus en in elke dialoog- of menulus. Het scherm eronder wordt bewaard
// en daarna precies teruggezet: een open dialoog blijft gewoon staan.
//
// De teksten staan in HELPTEXT (gui/help.txt -> tools/make_help.py), die
// bij het opstarten naar $D000 gaat (RAM onder de I/O, zie help_Load).
// Context = helpCtx als een scherm die zet (bv. het BBS-adresboek), anders
// activeApp + 1 (0 = bureaublad).
// Geen hulp in Paint (bitmapmodus) en waar helpOff aan staat (BBS-terminal:
// daar gaat F1 naar de BBS).
//========================================================

.label HELP_BASE = $d000         // HELPTEXT (max 4 KB, RAM onder de I/O)
.label HELP_BUF  = $7000         // tekst van de context (werkkopie)
.label HELP_SCR  = $7800         // bewaard scherm (1000) + kleuren (1000)
.const HELP_MAXB = 600           // hoogstens zoveel bytes per context

// help_Load - HELPTEXT laden (bij het opstarten): via $4000 naar $D000.
help_Load: {
        lda #0
        sta helpOk
        jsr cfg_io_begin
        lda #[nEnd-nm]
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #0
        jsr K_SETLFS
        lda #0
        ldx #<$4000
        ldy #>$4000
        jsr K_LOAD
        php
        jsr cfg_io_end
        plp
        bcs r
        sei                      // 4 KB naar $D000 (I/O uit)
        lda $01
        pha
        lda #$34
        sta $01
        ldx #0
lp:
    .for (var p=0; p<16; p++) {
        lda $4000 + p*$100,x
        sta HELP_BASE + p*$100,x
    }
        inx
        bne lp
        pla
        sta $01
        cli
        inc helpOk
r:      rts
nm:     .encoding "petscii_upper"
        .text "HELPTEXT"
nEnd:   .encoding "screencode_upper"
}

// help_Show - hulp voor de huidige context (scherm wordt bewaard).
help_Show: {
        lda helpOk
        bne ok
        rts
ok:     inc helpBusy
        lda helpCtx              // context kiezen
        bne c1
        ldx activeApp
        inx
        txa
c1:     sta hCtx
        // tekst van de context naar HELP_BUF (I/O even uit)
        sei
        lda $01
        pha
        lda #$34
        sta $01
        lda hCtx
        cmp HELP_BASE            // bestaat de context?
        bcc c2
        lda #0
c2:     asl
        tax
        lda HELP_BASE+1,x
        sta r4
        lda HELP_BASE+2,x
        sta r4+1
        ora r4
        bne c3
        lda HELP_BASE+1          // geen tekst: die van het bureaublad
        sta r4
        lda HELP_BASE+2
        sta r4+1
c3:     lda r4                   // r4 = HELP_BASE + offset
        clc
        adc #<HELP_BASE
        sta r4
        lda r4+1
        adc #>HELP_BASE
        sta r4+1
        lda #<HELP_BUF
        sta r5
        lda #>HELP_BUF
        sta r5+1
        ldy #0
        ldx #>HELP_MAXB+1
cp:     lda (r4),y
        sta (r5),y
        cmp #$ff
        beq cd
        iny
        bne cp
        inc r4+1
        inc r5+1
        dex
        bne cp
cd:     pla
        sta $01
        cli
        jsr hs_Save              // scherm bewaren
        // titel = eerste regel
        lda #<HELP_BUF
        sta hP
        lda #>HELP_BUF
        sta hP+1
        jsr hLine                // -> hTxt, hP naar de volgende regel
        lda #<hTxt
        sta r0
        lda #>hTxt
        sta r0+1
        lda #2
        sta a0
        lda #3
        sta a1
        lda #36
        sta a2
        lda #19
        sta a3
        jsr dlg_Draw             // rijen 3-21
        lda #5
        sta hRow
ln:     lda hEnd                 // regels tot $ff
        bne okb
        jsr hLine
        lda #<hTxt
        sta r0
        lda #>hTxt
        sta r0+1
        lda #4
        sta a0
        lda hRow
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        inc hRow
        lda hRow
        cmp #19
        bcc ln
okb:    lda #18                  // OK-knop
        sta a0
        lda #20
        sta a1
        jsr dlg_OkButton
        jsr dlg_WaitClose
        jsr hs_Restore
        dec helpBusy
        rts
// hLine - regel vanaf hP naar hTxt ($ff); hEnd = 1 als het de laatste was.
hLine:  lda hP
        sta r4
        lda hP+1
        sta r4+1
        ldy #0
        sty hEnd
hl:     lda (r4),y
        cmp #$fe
        beq he
        cmp #$ff
        beq hx
        sta hTxt,y
        iny
        cpy #34
        bne hl
he:     lda #$ff
        sta hTxt,y
        iny                      // hP achter de $FE
        tya
        clc
        adc hP
        sta hP
        bcc hr
        inc hP+1
hr:     rts
hx:     inc hEnd
        jmp he
}

// save_Begin / save_End - om elke SAVE van instellingen heen: tijdens het
//   schrijven staan de interrupts uit (ook de muis), dus eerst een venster
//   "SETTINGS ARE BEING SAVED / PLEASE WAIT". save_End zet het scherm
//   terug en laat de carry (fout van de SAVE) staan.
save_Begin:
        jsr hs_Save
        gfxDrawBoxM(5, 10, 30, 4, TH_text)     // rijen 10-13
        lda #<sSaving
        sta r0
        lda #>sSaving
        sta r0+1
        lda #7
        sta a0
        lda #11
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        lda #<sWait
        sta r0
        lda #>sWait
        sta r0+1
        lda #7
        sta a0
        lda #12
        sta a1
        lda TH_text
        sta a2
        jmp gfx_DrawText
save_End:
        php
        jsr hs_Restore
        plp
        rts
sSaving: .text "SETTINGS ARE BEING SAVED"
        .byte $ff

// hs_Save / hs_Restore - scherm + kleuren-RAM naar/van HELP_SCR.
hs_Save:
        ldx #0
!:      lda SCREEN_RAM,x
        sta HELP_SCR,x
        lda SCREEN_RAM+$100,x
        sta HELP_SCR+$100,x
        lda SCREEN_RAM+$200,x
        sta HELP_SCR+$200,x
        lda SCREEN_RAM+$2e8,x
        sta HELP_SCR+$2e8,x
        lda COLOR_RAM,x
        sta HELP_SCR+1000,x
        lda COLOR_RAM+$100,x
        sta HELP_SCR+1000+$100,x
        lda COLOR_RAM+$200,x
        sta HELP_SCR+1000+$200,x
        lda COLOR_RAM+$2e8,x
        sta HELP_SCR+1000+$2e8,x
        inx
        bne !-
        rts
hs_Restore:
        ldx #0
!:      lda HELP_SCR,x
        sta SCREEN_RAM,x
        lda HELP_SCR+$100,x
        sta SCREEN_RAM+$100,x
        lda HELP_SCR+$200,x
        sta SCREEN_RAM+$200,x
        lda HELP_SCR+$2e8,x
        sta SCREEN_RAM+$2e8,x
        lda HELP_SCR+1000,x
        sta COLOR_RAM,x
        lda HELP_SCR+1000+$100,x
        sta COLOR_RAM+$100,x
        lda HELP_SCR+1000+$200,x
        sta COLOR_RAM+$200,x
        lda HELP_SCR+1000+$2e8,x
        sta COLOR_RAM+$2e8,x
        inx
        bne !-
        rts

//--------------------------------------------------------
helpOk:   .byte 0                // HELPTEXT geladen
helpBusy: .byte 0                // hulp staat open (geen tweede)
helpOff:  .byte 0                // 1 = F1 niet opvangen (BBS-terminal)
helpCtx:  .byte 0                // 0 = activeApp + 1, anders deze context
hCtx:     .byte 0
hRow:     .byte 0
hEnd:     .byte 0
hP:       .word 0
hTxt:     .fill 35, $ff
