#importonce
//========================================================
// apps/filemanager.asm - File Manager (Fase 7, Win95-stijl)
// Commodore Desk 64
//
// Leest de directory (hal/disk.asm) en toont de bestanden in een lijst
// over de hele vensterbreedte, met rechts een werkende Win95-scrollbalk
// (pijlen = 1 regel, track = 1 pagina). Klik een bestand om te selecteren.
// De disk-header (directory-regel 0) is geen bestand en wordt overgeslagen.
//========================================================

.const FM_VISIBLE = WIN_BODY_BOT-1 // lijstrijen 2..22
.const FM_TOP     = 2
.const FM_COL     = 2            // lijst kol 2..35
.const FM_W       = 34
.const FM_SCR     = 37           // scrollbalk-kolom

// fm_Load - directory (her)lezen; selectie/scroll resetten.
fm_Load:
        jsr dir_Read
        lda #0
        sta fmTop
        sta fmSel
        lda dirCount             // aantal echte bestanden (zonder header)
        beq !z+
        sec
        sbc #1
!z:     sta fmN
        rts

// fm_Max - A = hoogste fmTop (0 = alles past).
fm_Max:
        lda fmN
        sec
        sbc #FM_VISIBLE
        bcs !m+
        lda #0
!m:     rts

//--------------------------------------------------------
// fm_Draw - lijst + scrollbalk tekenen (alleen de vensterinhoud).
//--------------------------------------------------------
fm_Draw:
        lda #0
        sta fmI
!row:   lda fmI
        cmp #FM_VISIBLE
        bcc !go+
        jmp !sb+
!go:    clc
        adc #FM_TOP
        sta fmRow
        // regel wissen
        lda #FM_COL
        sta a0
        lda fmRow
        sta a1
        lda #FM_W
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda fmI                  // item = fmTop + i
        clc
        adc fmTop
        sta fmItem
        cmp fmN
        bcs !next+
        // naam-pointer (dir-index = item + 1, header overslaan)
        ldx fmItem
        inx
        lda dirPtrLo,x
        sta r0
        lda dirPtrHi,x
        sta r0+1
        lda fmItem
        cmp fmSel
        bne !norm+
        // geselecteerd: gekleurde balk + reverse tekst
        lda #FM_COL
        sta a0
        lda fmRow
        sta a1
        lda #FM_W
        sta a2
        lda #1
        sta a3
        lda #$a0
        sta a4
        lda TH_select
        sta a5
        jsr gfx_FillRect
        ldx fmItem
        inx
        lda dirPtrLo,x
        sta r0
        lda dirPtrHi,x
        sta r0+1
        lda #FM_COL+1
        sta a0
        lda fmRow
        sta a1
        lda TH_select
        sta a2
        jsr gfx_DrawTextRev
        jmp !next+
!norm:  lda #FM_COL+1
        sta a0
        lda fmRow
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
!next:  inc fmI
        jmp !row-
!sb:    lda fmN                  // lege disk?
        bne !bar+
        lda #<sEmpty
        sta r0
        lda #>sEmpty
        sta r0+1
        lda #FM_COL+1
        sta a0
        lda #FM_TOP
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
!bar:   jsr fm_Max
        sta a4
        lda fmTop
        sta a3
        lda #FM_SCR
        sta a0
        lda #FM_TOP
        sta a1
        lda #FM_TOP+FM_VISIBLE-1
        sta a2
        jmp scr_Draw

//--------------------------------------------------------
// fm_Click - klik afhandelen (evtA=kol, evtB=rij).
//--------------------------------------------------------
fm_Click:
        lda evtA
        cmp #FM_SCR
        bne !list+
        jsr scr_Hit              // scrollbalk
        cmp #1
        beq !up+
        cmp #2
        beq !dn+
        cmp #3
        beq !pu+
        cmp #4
        beq !pd+
        rts
!up:    lda fmTop
        beq !r+
        dec fmTop
        jmp fm_Draw
!dn:    jsr fm_Max
        cmp fmTop
        beq !r+
        bcc !r+
        inc fmTop
        jmp fm_Draw
!pu:    lda fmTop
        sec
        sbc #FM_VISIBLE
        bcs !s+
        lda #0
!s:     sta fmTop
        jmp fm_Draw
!pd:    lda fmTop
        clc
        adc #FM_VISIBLE
        sta fmTop
        jsr fm_Max
        cmp fmTop
        bcs !d+
        sta fmTop
!d:     jmp fm_Draw
!list:  lda evtB                 // lijst-item (rijen 2..22, kol 2..35)
        cmp #FM_TOP
        bcc !r+
        cmp #FM_TOP+FM_VISIBLE
        bcs !r+
        lda evtA
        cmp #FM_COL
        bcc !r+
        cmp #FM_COL+FM_W
        bcs !r+
        lda evtB
        sec
        sbc #FM_TOP
        clc
        adc fmTop
        cmp fmN
        bcs !r+
        sta fmSel
        jmp fm_Draw
!r:     rts

//--------------------------------------------------------
fmTop:  .byte 0
fmSel:  .byte 0
fmN:    .byte 0
fmI:    .byte 0
fmRow:  .byte 0
fmItem: .byte 0
.encoding "screencode_upper"
sEmpty: .text "NO FILES"
        .byte $ff
