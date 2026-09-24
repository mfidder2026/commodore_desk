#importonce
//========================================================
// apps/filemanager.asm - File Manager (Fase 7)
// Commodore Desk 64
//
// Leest de directory (hal/disk.asm) en toont hem in een scrollbare
// lijst met UP/DN-knoppen. Klik een bestand om te selecteren.
//========================================================

.const FM_VISIBLE = 11

// fm_Load - directory (her)lezen; selectie/scroll resetten.
fm_Load:
        jsr dir_Read
        lda #0
        sta fmTop
        sta fmSel
        rts

//--------------------------------------------------------
// fm_Draw - lijst + knoppen tekenen (zonder Cls).
//--------------------------------------------------------
fm_Draw: {
        gfxDrawBox(2, 5, 28, 13, LIGHT_GREY)
        lda dirCount
        bne haveFiles
        lda #<sEmpty
        sta r0
        lda #>sEmpty
        sta r0+1
        lda #4
        sta a0
        lda #7
        sta a1
        lda #THEME_WARN
        sta a2
        jsr gfx_DrawText
        jmp buttons
haveFiles:
        lda #0
        sta lvI
loop:   lda lvI
        cmp #FM_VISIBLE
        bcc lp1
        jmp listDone
lp1:    lda #6
        clc
        adc lvI
        sta lvRow
        lda fmTop
        clc
        adc lvI
        sta lvItem
        lda lvItem
        cmp dirCount
        bcc drawRow
        // lege regel
        jsr fillBlank
        jmp next
drawRow:
        lda lvItem
        cmp fmSel
        beq doHi
        jmp normal
doHi:
        // geselecteerd -> highlight
        lda #3
        sta a0
        lda lvRow
        sta a1
        lda #26
        sta a2
        lda #1
        sta a3
        lda #$a0
        sta a4
        lda #THEME_SELECT
        sta a5
        jsr gfx_FillRect
        ldx lvItem
        lda dirPtrLo,x
        sta r0
        lda dirPtrHi,x
        sta r0+1
        lda #4
        sta a0
        lda lvRow
        sta a1
        lda #THEME_SELECT
        sta a2
        jsr gfx_DrawTextRev
        jmp next
normal:
        jsr fillBlank
        ldx lvItem
        lda dirPtrLo,x
        sta r0
        lda dirPtrHi,x
        sta r0+1
        lda #4
        sta a0
        lda lvRow
        sta a1
        lda #THEME_TEXT
        sta a2
        jsr gfx_DrawText
next:   inc lvI
        jmp loop
listDone:
buttons:
        lda #<sUp2
        sta r0
        lda #>sUp2
        sta r0+1
        lda #32
        sta a0
        lda #6
        sta a1
        lda #5
        sta a2
        lda #LIGHT_GREY
        sta a3
        jsr btn_Draw
        lda #<sDn2
        sta r0
        lda #>sDn2
        sta r0+1
        lda #32
        sta a0
        lda #8
        sta a1
        lda #5
        sta a2
        lda #LIGHT_GREY
        sta a3
        jsr btn_Draw
        lda #<sFiles2
        sta r0
        lda #>sFiles2
        sta r0+1
        lda #32
        sta a0
        lda #10
        sta a1
        lda #THEME_TEXT
        sta a2
        jsr gfx_DrawText
        lda #<[SCREEN_RAM + 11*40 + 32]
        sta r4
        lda #>[SCREEN_RAM + 11*40 + 32]
        sta r4+1
        lda dirCount
        jsr num2dec
        rts

// fillBlank - wis de lijstregel (cols3-28) van rij lvRow.
fillBlank:
        lda #3
        sta a0
        lda lvRow
        sta a1
        lda #26
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda #THEME_DESKTOP_BG
        sta a5
        jmp gfx_FillRect         // rts van FillRect keert terug naar aanroeper

sEmpty:  .encoding "screencode_upper"
         .text "NO FILES"
         .byte $ff
sUp2:    .text "UP"
         .byte $ff
sDn2:    .text "DN"
         .byte $ff
sFiles2: .text "FILES:"
         .byte $ff
}

//--------------------------------------------------------
// fm_Click - klik afhandelen (evtA=kol, evtB=rij).
//--------------------------------------------------------
fm_Click: {
        // UP (32,6,5)
        lda #32
        sta a0
        lda #6
        sta a1
        lda #5
        sta a2
        jsr btn_HitTest
        bcc c1
        lda fmTop
        beq done
        dec fmTop
        jmp redraw
c1:     // DN (32,8,5)
        lda #32
        sta a0
        lda #8
        sta a1
        lda #5
        sta a2
        jsr btn_HitTest
        bcc c2
        lda fmTop
        clc
        adc #FM_VISIBLE
        cmp dirCount
        bcs done
        inc fmTop
        jmp redraw
c2:     // lijst-item (rows6-16, cols3-28)
        lda evtB
        cmp #6
        bcc done
        cmp #17
        bcs done
        lda evtA
        cmp #3
        bcc done
        cmp #29
        bcs done
        lda evtB
        sec
        sbc #6
        clc
        adc fmTop
        cmp dirCount
        bcs done
        sta fmSel
        jmp redraw
redraw:
        jsr fm_Draw
done:   rts
}

//--------------------------------------------------------
fmTop: .byte 0
fmSel: .byte 0
