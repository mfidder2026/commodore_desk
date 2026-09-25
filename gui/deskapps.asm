#importonce
//========================================================
// gui/deskapps.asm - bureaublad-launcher: gebruikersprogramma's
// Commodore Desk 64
//
// Het bureaublad toont de vaste ingebouwde apps (EDITOR/PAINT/CALC) en
// daarna een lijst gebruikersprogramma's die je zelf kunt TOEVOEGEN,
// BEWERKEN en VERWIJDEREN via het uitklapmenu. De lijst wordt bewaard in
// "DESK.APPS" op de D71 en overleeft een herstart.
//
// De records staan op een vast adres ($C100) buiten het overlay-gebied,
// zodat ze een app-overlay ($8000), de Paint-bitmap ($4000) en het laden
// van een PRG ($0801..) overleven.
//
// Recordlayout (28 bytes):
//   +0  icoon-index (0..NUM_USERICONS-1)
//   +1  kleur (0..15)
//   +2..14  weergavenaam (screencodes, $ff-afgesloten, <=12 tekens)
//   +15 PRG-naamlengte
//   +16..27 PRG-naam (petscii, <=12 tekens)
//========================================================

.const REC_STRIDE    = 28
.const DESK_MAXUSER  = 12
.const NUM_USERICONS = 20
.label DA_count = $c100
.label DA_recs  = $c101
.const DA_end   = DA_recs + DESK_MAXUSER*REC_STRIDE

.const REC_ICON = 0
.const REC_COL  = 1
.const REC_DISP = 2
.const REC_PLEN = 15
.const REC_PRG  = 16

.const DA_VISROWS = 5
.const DA_VIS     = DA_VISROWS*2

//--------------------------------------------------------
// da_recPtr - A = user-index -> $fb/$fc wijst naar het record.
//--------------------------------------------------------
da_recPtr:
        sta daTmp
        lda #<DA_recs
        sta $fb
        lda #>DA_recs
        sta $fc
        ldx daTmp
        beq !done+
!lp:    lda $fb
        clc
        adc #REC_STRIDE
        sta $fb
        bcc !nc+
        inc $fc
!nc:    dex
        bne !lp-
!done:  rts

// da_total - A = biCount + DA_count (totaal aantal entries).
da_total:
        lda biCount
        clc
        adc DA_count
        rts

//========================================================
// Tekenen
//========================================================
da_DrawEntries:
        jsr da_clampScroll
        lda #0
        sta daSlot
!lp:    lda daSlot
        cmp #DA_VIS
        bcs !bars+
        clc
        adc daScroll
        sta daEnt
        jsr da_total
        cmp daEnt
        beq !bars+
        bcc !bars+
        lda daSlot
        and #1
        beq !left+
        lda #21
        jmp !setx+
!left:  lda #3
!setx:  sta deCol
        lda daSlot
        lsr
        sta deRow
        asl
        clc
        adc deRow
        clc
        adc #3
        sta deRow
        jsr da_drawOne
        inc daSlot
        jmp !lp-
!bars:  jmp da_drawScrollbar

// da_drawOne - teken entry daEnt op (deCol,deRow).
da_drawOne:
        lda daEnt
        cmp biCount
        bcs !user+
        tax
        lda biIcon,x
        sta deIcon
        lda biIcoCol,x
        sta deIcoC
        jsr da_draw2x2
        ldx daEnt
        lda biNameLo,x
        sta r0
        lda biNameHi,x
        sta r0+1
        jmp da_drawLabel
!user:  sec
        sbc biCount
        jsr da_recPtr
        ldy #REC_ICON
        lda ($fb),y
        tax
        lda userIconGlyphs,x
        sta a2
        ldy #REC_COL
        lda ($fb),y
        sta a3
        lda deCol
        sta a0
        lda deRow
        sta a1
        jsr gfx_PutChar
        lda $fb
        clc
        adc #REC_DISP
        sta r0
        lda $fc
        adc #0
        sta r0+1
        jmp da_drawLabel

// da_draw2x2 - 2x2-icoon deIcon/deIcoC op (deCol,deRow).
da_draw2x2:
        lda deCol
        sta a0
        lda deRow
        sta a1
        lda deIcon
        sta a2
        lda deIcoC
        sta a3
        jsr gfx_PutChar
        lda deCol
        clc
        adc #1
        sta a0
        lda deRow
        sta a1
        lda deIcon
        clc
        adc #1
        sta a2
        lda deIcoC
        sta a3
        jsr gfx_PutChar
        lda deCol
        sta a0
        lda deRow
        clc
        adc #1
        sta a1
        lda deIcon
        clc
        adc #2
        sta a2
        lda deIcoC
        sta a3
        jsr gfx_PutChar
        lda deCol
        clc
        adc #1
        sta a0
        lda deRow
        clc
        adc #1
        sta a1
        lda deIcon
        clc
        adc #3
        sta a2
        lda deIcoC
        sta a3
        jmp gfx_PutChar

// da_drawLabel - label (r0) op (deCol+3, deRow) in TH_text.
da_drawLabel:
        lda deCol
        clc
        adc #3
        sta a0
        lda deRow
        sta a1
        lda TH_text
        sta a2
        jmp gfx_DrawText

// Scrollbalk van het bureaubladvenster: kolom 37, pijlen op rij 2 en 18.
.const DA_SCR_COL = 37
.const DA_SCR_TOP = 2
.const DA_SCR_BOT = 18

// da_maxRow - A = hoogste eerste zichtbare rij (0 = alles past).
da_maxRow:
        jsr da_total
        clc
        adc #1
        lsr                      // aantal rijen = (totaal+1)/2
        sec
        sbc #DA_VISROWS
        bcs !m+
        lda #0
!m:     rts

// da_clampScroll - daScroll binnen bereik houden (bv. na verwijderen).
da_clampScroll:
        jsr da_maxRow
        asl                      // max in entries (2 per rij)
        cmp daScroll
        bcs !ok+
        sta daScroll
!ok:    rts

// da_drawScrollbar - Win95-scrollbalk rechts in het venster.
da_drawScrollbar:
        jsr da_maxRow
        sta a4
        lda daScroll
        lsr
        sta a3
        lda #DA_SCR_COL
        sta a0
        lda #DA_SCR_TOP
        sta a1
        lda #DA_SCR_BOT
        sta a2
        jmp scr_Draw

// da_Redraw - alleen de vensterinhoud opnieuw tekenen (geen flikkering
//             van titelbalk/dock).
da_Redraw:
        lda #2
        sta a0
        lda #2
        sta a1
        lda #35
        sta a2
        lda #17
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        jmp drawDesktopContent

//========================================================
// Klik-afhandeling
//========================================================
da_Click:
        lda evtA
        cmp #DA_SCR_COL
        beq da_scrollClick       // scrollbalk-kolom
        jmp da_gridClick

// da_scrollClick - pijl = 1 rij, track boven/onder de thumb = 1 pagina.
da_scrollClick:
        jsr scr_Hit
        cmp #1
        beq !up+
        cmp #2
        beq !dn+
        cmp #3
        beq !pu+
        cmp #4
        beq !pd+
        rts
!up:    lda daScroll
        beq !r+
        sec
        sbc #2
        jmp !st+
!dn:    lda daScroll
        clc
        adc #2
        jmp !cl+
!pu:    lda daScroll
        sec
        sbc #DA_VIS
        bcs !st+
        lda #0
        jmp !st+
!pd:    lda daScroll
        clc
        adc #DA_VIS
!cl:    sta daScroll
        jsr da_clampScroll
        jmp da_Redraw
!st:    sta daScroll
        jmp da_Redraw
!r:     rts

da_gridClick:
        jsr da_hitEntry
        bcc !r+
        cmp biCount
        bcs !user+
        tax
        lda biApp,x
        jmp openApp
!user:  sec
        sbc biCount
        jmp da_Launch
!r:     rts

//--------------------------------------------------------
// da_hitEntry - reken (evtA,evtB) om naar een entry-index.
//               Uit: A=entry, carry=1 geldig, carry=0 buiten het raster.
//--------------------------------------------------------
da_hitEntry:
        // Ruim klikgebied: hele linker-/rechterhelft telt (grens kol 20).
        lda evtA
        cmp #20
        bcc !lc+
        lda #1
        jmp !cp+
!lc:    lda #0
!cp:    sta deCol
        lda evtB
        sec
        sbc #3
        bcc !no+
        sta deRow
        ldx #0
!dl:    lda deRow
        cmp #3
        bcc !rem+
        sec
        sbc #3
        sta deRow
        inx
        jmp !dl-
!rem:   lda deRow
        cmp #2
        beq !no+
        txa
        asl
        clc
        adc deCol
        clc
        adc daScroll
        sta daEnt
        jsr da_total
        cmp daEnt
        bcc !no+
        beq !no+
        lda daEnt
        sec
        rts
!no:    clc
        rts

//--------------------------------------------------------
// da_Launch - start gebruikersrecord A.
//--------------------------------------------------------
da_Launch:
        jsr da_recPtr
        ldy #REC_PLEN
        lda ($fb),y
        sta $03bf
        beq !bad+
        ldx #0
!cp:    txa
        clc
        adc #REC_PRG
        tay
        lda ($fb),y
        sta $03c0,x
        inx
        cpx $03bf
        bne !cp-
        jmp launchCommon
!bad:   jmp shell_NotFound

//========================================================
// Persistentie (DESK.APPS)
//========================================================
da_Save: {
        jsr cfg_io_begin
        lda #[nEnd-nm]
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #0
        ldx #8
        ldy #0
        jsr K_SETLFS
        lda #<DA_count
        sta $fb
        lda #>DA_count
        sta $fc
        lda #$fb
        ldx #<DA_end
        ldy #>DA_end
        jsr K_SAVE
        jsr cfg_io_end
        rts
nm:     .encoding "petscii_upper"
        .text "@0:DESK.APPS"
nEnd:   .encoding "screencode_upper"
}

da_Load: {
        jsr cfg_io_begin
        lda #[nEnd-nm]
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #1
        lda #0
        ldx #<DA_count
        ldy #>DA_count
        jsr K_LOAD
        jsr cfg_io_end
        bcs !seed+
        lda DA_count
        cmp #DESK_MAXUSER+1
        bcc !ok+
!seed:  jsr da_Seed
        jsr da_Save
!ok:    rts
nm:     .encoding "petscii_upper"
        .text "DESK.APPS"
nEnd:   .encoding "screencode_upper"
}

//--------------------------------------------------------
// da_Seed - standaardlijst (COWBOY + SCRSAVER).
//--------------------------------------------------------
da_Seed:
        lda #0
        sta daU
!lp:    lda daU
        cmp #2
        bcs !done+
        lda daU
        jsr da_recPtr
        ldx daU
        lda seedIcon,x
        ldy #REC_ICON
        sta ($fb),y
        ldx daU
        lda seedCol,x
        ldy #REC_COL
        sta ($fb),y
        ldx daU
        lda seedDispLo,x
        sta r0
        lda seedDispHi,x
        sta r0+1
        jsr da_setDisp
        ldx daU
        lda seedPrgLo,x
        sta r0
        lda seedPrgHi,x
        sta r0+1
        jsr da_setPrg
        inc daU
        jmp !lp-
!done:  lda #2
        sta DA_count
        rts

//--------------------------------------------------------
// da_setDisp - kopieer $ff-string (r0) naar record ($fb)+REC_DISP,
//              maximaal 12 tekens, inclusief de $ff.
//--------------------------------------------------------
da_setDisp:
        lda $fb
        clc
        adc #REC_DISP
        sta $fd
        lda $fc
        adc #0
        sta $fe
        ldy #0
!lp:    lda (r0),y
        sta ($fd),y
        cmp #$ff
        beq !done+
        iny
        cpy #12
        bne !lp-
        lda #$ff
        sta ($fd),y
!done:  rts

//--------------------------------------------------------
// da_setPrg - kopieer $ff-string (r0) naar record ($fb)+REC_PRG,
//             maximaal 12 tekens; zet REC_PLEN = lengte.
//--------------------------------------------------------
da_setPrg:
        lda $fb
        clc
        adc #REC_PRG
        sta $fd
        lda $fc
        adc #0
        sta $fe
        ldy #0
!lp:    lda (r0),y
        cmp #$ff
        beq !done+
        sta ($fd),y
        iny
        cpy #12
        bne !lp-
!done:  tya
        ldy #REC_PLEN
        sta ($fb),y
        rts

//========================================================
// Modale invoer: tekstveld, iconenkiezer, kleurenkiezer
//========================================================
// da_TextInput - modaal 1-regel tekstveld. Caller zet vooraf: daTX/daTY
//   (positie), daMax (max tekens), daLen (0 of voorgevuld) en inBuf.
//   Vult inBuf met screencodes + $ff. Uit: carry=0 OK (RETURN),
//   carry=1 geannuleerd (RUN/STOP).
//--------------------------------------------------------
da_TextInput:
        jsr da_tiDraw
!wait:  jsr evt_Poll
        cmp #EVT_MOUSEDOWN       // klik op de sluitknop = annuleren
        bne !nk+
        jsr dlg_HitClose
        bcs !cancel+
        jmp !wait-
!nk:    cmp #EVT_KEY
        bne !wait-
        lda evtA
        cmp #$80                 // RETURN
        beq !ok+
        cmp #$82                 // RUN/STOP
        beq !cancel+
        cmp #$81                 // DEL
        beq !del+
        jsr da_tiPrintable
        bcc !wait-
        ldx daLen
        cpx daMax
        bcs !wait-
        sta inBuf,x
        inc daLen
        jsr da_tiDraw
        jmp !wait-
!del:   lda daLen
        beq !wait-
        dec daLen
        jsr da_tiDraw
        jmp !wait-
!ok:    ldx daLen
        lda #$ff
        sta inBuf,x
        clc
        rts
!cancel:
        sec
        rts

// da_tiPrintable - A=screencode -> carry=1 als aanvaardbaar (behoudt A).
da_tiPrintable:
        cmp #$01
        bcc !no+
        cmp #$1b                 // $01..$1a = letters
        bcc !yes+
        cmp #$20                 // spatie
        beq !yes+
        cmp #$2d                 // '-'
        beq !yes+
        cmp #$2e                 // '.'
        beq !yes+
        cmp #$30
        bcc !no+
        cmp #$3a                 // '0'..'9'
        bcc !yes+
!no:    clc
        rts
!yes:   sec
        rts

// da_tiDraw - teken het veld (spaties + inBuf + cursorblok).
da_tiDraw:
        lda daMax
        clc
        adc #1
        sta daTmp                // veldbreedte
        ldx #0
!fl:    stx daK
        txa
        clc
        adc daTX
        sta a0
        lda daTY
        sta a1
        lda #$20
        sta a2
        lda TH_text
        sta a3
        jsr gfx_PutChar
        ldx daK
        inx
        cpx daTmp
        bne !fl-
        ldx #0
!dc:    cpx daLen
        beq !cur+
        stx daK
        txa
        clc
        adc daTX
        sta a0
        lda daTY
        sta a1
        ldx daK
        lda inBuf,x
        sta a2
        lda TH_text
        sta a3
        jsr gfx_PutChar
        ldx daK
        inx
        jmp !dc-
!cur:   lda daLen
        clc
        adc daTX
        sta a0
        lda daTY
        sta a1
        lda #$a0                 // cursorblok
        sta a2
        lda TH_select
        sta a3
        jmp gfx_PutChar

//--------------------------------------------------------
// da_askText - teken een invoervenster met prompt (r0) en lees tekst.
//   Caller zet daMax en daLen (0 of voorgevuld). Uit: carry uit invoer.
//--------------------------------------------------------
da_askText:
        lda r0                   // prompt bewaren; titel = daTitle
        sta daPr
        lda r0+1
        sta daPr+1
        lda daTitle
        sta r0
        lda daTitle+1
        sta r0+1
        lda #3
        sta a0
        lda #7
        sta a1
        lda #34
        sta a2
        lda #6
        sta a3
        jsr dlg_Draw             // rijen 7-12
        lda daPr
        sta r0
        lda daPr+1
        sta r0+1
        lda #5
        sta a0
        lda #9
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText         // prompt
        lda #5
        sta daTX
        lda #10
        sta daTY
        jmp da_TextInput

//--------------------------------------------------------
// da_IconPick - kies 1 van de 20 iconen. Uit: daIcon = index.
//   RUN/STOP behoudt de huidige daIcon.
//--------------------------------------------------------
da_IconPick:
        lda #<sTIcon
        sta r0
        lda #>sTIcon
        sta r0+1
        lda #3
        sta a0
        lda #5
        sta a1
        lda #34
        sta a2
        lda #8
        sta a3
        jsr dlg_Draw             // rijen 5-12
        lda #<sPickIcon
        sta r0
        lda #>sPickIcon
        sta r0+1
        lda #5
        sta a0
        lda #6
        sta a1
        lda TH_title
        sta a2
        jsr gfx_DrawText
        lda #0
        sta daK
!lp:    lda daK
        cmp #NUM_USERICONS
        bcs !wait+
        // kol = 6 + (i mod 10)*2 ; rij = 8 + (i/10)*2
        lda daK
        cmp #10
        bcc !r0+
        sbc #10
        sta daTmp
        lda #10
        jmp !rr+
!r0:    sta daTmp
        lda #8
!rr:    sta a1                   // rij
        lda daTmp
        asl
        clc
        adc #6
        sta a0                   // kol
        ldx daK
        lda userIconGlyphs,x
        sta a2
        lda #WHITE
        sta a3
        jsr gfx_PutChar
        inc daK
        jmp !lp-
!wait:  jsr da_pollClick
        bcs !cancel+
        // rij 8 of 10?
        lda evtB
        cmp #8
        beq !row0+
        cmp #10
        beq !row1+
        jmp !wait-
!row0:  lda #0
        jmp !base+
!row1:  lda #10
!base:  sta daTmp                // base
        lda evtA
        sec
        sbc #6
        bcc !wait-
        lsr                      // (kol-6)/2 = k
        cmp #10
        bcs !wait-
        clc
        adc daTmp
        cmp #NUM_USERICONS
        bcs !wait-
        sta daIcon
!cancel:
        rts

//--------------------------------------------------------
// da_ColorPick - kies 1 van de 16 kleuren. Uit: daColor.
//--------------------------------------------------------
da_ColorPick:
        lda #<sTColor
        sta r0
        lda #>sTColor
        sta r0+1
        lda #3
        sta a0
        lda #12
        sta a1
        lda #34
        sta a2
        lda #5
        sta a3
        jsr dlg_Draw             // rijen 12-16
        lda #<sPickCol
        sta r0
        lda #>sPickCol
        sta r0+1
        lda #5
        sta a0
        lda #13
        sta a1
        lda TH_title
        sta a2
        jsr gfx_DrawText
        lda #0
        sta daK
!lp:    lda daK
        cmp #16
        bcs !wait+
        lda daK
        asl
        clc
        adc #4
        sta a0
        lda #14
        sta a1
        lda #$a0
        sta a2
        lda daK
        sta a3
        jsr gfx_PutChar
        inc daK
        jmp !lp-
!wait:  jsr da_pollClick
        bcs !cancel+
        lda evtB
        cmp #14
        bne !wait-
        lda evtA
        sec
        sbc #4
        bcc !wait-
        lsr
        cmp #16
        bcs !wait-
        sta daColor
!cancel:
        rts

//--------------------------------------------------------
// da_pollClick - wacht op een klik (of spatie/return op cursorpositie).
//   Uit: evtA/evtB gezet, carry=0. RUN/STOP -> carry=1.
//--------------------------------------------------------
da_pollClick:
!w:     jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        beq !ok+
        cmp #EVT_KEY
        bne !w-
        lda evtA
        cmp #$20
        beq !kc+
        cmp #$80
        beq !kc+
        cmp #$82
        beq !cancel+
        jmp !w-
!kc:    jsr cursorToCell
!ok:    jsr dlg_HitClose         // sluitknop van de dialoog = annuleren
        bcs !cancel+
        jsr sid_Click
        clc
        rts
!cancel:
        sec
        rts

//--------------------------------------------------------
// da_getPrg - PRG-naam bepalen: eerst de disk laten bladeren; kiest de
//   gebruiker niets (RUN/STOP) dan handmatig typen. Vult prgTmp
//   ($ff-afgesloten petscii). Uit: carry=0 OK, carry=1 geannuleerd.
//--------------------------------------------------------
da_getPrg:
        jsr da_PrgPick
        bcc !ok+                 // een bestand gekozen -> prgTmp gevuld
        // terugval: handmatig typen
        lda #0
        sta daLen
        lda #<sPrg
        sta r0
        lda #>sPrg
        sta r0+1
        lda #11
        sta daMax
        jsr da_askText
        bcs !cancel+
        jsr da_savePrg
!ok:    clc
        rts
!cancel:
        sec
        rts

//--------------------------------------------------------
// da_PrgPick - toon de PRG-bestanden op de disk in een scrollbare lijst.
//   Klik er een -> prgTmp gevuld (petscii,$ff), carry=0. RUN/STOP -> carry=1
//   (val terug op typen). Geen bestanden -> carry=1.
//--------------------------------------------------------
// Win95-dialoog (4,2,32,17): titel rij 2, hint rij 3, lijst rijen 5-16,
// scrollbalk kol 34 (pijlen op rij 4 en 17, track naast de lijst).
.const DP_VIS = 12
.const DP_ROW = 5
.const DP_SCR = 34
da_PrgPick:
        jsr dir_Read             // dirCount + dirPtrLo/Hi (screencode-namen)
        // entry 0 = disk-header -> overslaan; dpN = aantal echte bestanden
        lda dirCount
        sec
        sbc #1
        sta dpN
        bne !have+
        sec                      // alleen de header -> geen bestanden
        rts
!have:  lda #0
        sta dpTop
        lda #<sPrgPick
        sta r0
        lda #>sPrgPick
        sta r0+1
        lda #4
        sta a0
        lda #2
        sta a1
        lda #32
        sta a2
        lda #17
        sta a3
        jsr dlg_Draw             // rijen 2-18
        lda #<sPrgHint
        sta r0
        lda #>sPrgHint
        sta r0+1
        lda #6
        sta a0
        lda #3
        sta a1
        lda TH_title
        sta a2
        jsr gfx_DrawText
da_ppList:
        lda #0                   // lijst (item = dpTop+dpI, dir-index = item+1)
        sta dpI
!lp:    lda dpI
        cmp #DP_VIS
        bcs !sb+
        clc
        adc #DP_ROW
        sta daTY
        lda #5                   // regel wissen (kol 5-33)
        sta a0
        lda daTY
        sta a1
        lda #29
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda dpTop
        clc
        adc dpI
        cmp dpN
        bcs !nx+
        clc
        adc #1                   // sla de header over
        tax
        lda dirPtrLo,x
        sta r0
        lda dirPtrHi,x
        sta r0+1
        lda #6
        sta a0
        lda daTY
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
!nx:    inc dpI
        jmp !lp-
!sb:    jsr dp_Max               // scrollbalk
        sta a4
        lda dpTop
        sta a3
        lda #DP_SCR
        sta a0
        lda #DP_ROW-1
        sta a1
        lda #DP_ROW+DP_VIS
        sta a2
        jsr scr_Draw
!wait:  jsr da_pollClick         // ESC of sluitknop -> zelf typen
        bcc !clk+
        sec
        rts
!clk:   lda evtA
        cmp #DP_SCR
        bne !list+
        jsr scr_Hit
        cmp #1
        beq !up+
        cmp #2
        beq !dn+
        cmp #3
        beq !pu+
        cmp #4
        beq !pd+
        jmp !wait-
!up:    lda dpTop
        beq !wait-
        dec dpTop
        jmp da_ppList
!dn:    jsr dp_Max
        cmp dpTop
        beq !wait-
        bcc !wait-
        inc dpTop
        jmp da_ppList
!pu:    lda dpTop
        sec
        sbc #DP_VIS
        bcs !st+
        lda #0
!st:    sta dpTop
        jmp da_ppList
!pd:    lda dpTop
        clc
        adc #DP_VIS
        sta dpTop
        jsr dp_Max
        cmp dpTop
        bcs !pl+
        sta dpTop
!pl:    jmp da_ppList
!w2:    jmp !wait-               // (tussenstap: !wait ligt te ver weg)
!list:  lda evtB
        cmp #DP_ROW
        bcc !w2-
        cmp #DP_ROW+DP_VIS
        bcs !w2-
        lda evtA
        cmp #5
        bcc !w2-
        cmp #DP_SCR
        bcs !w2-
        lda evtB
        sec
        sbc #DP_ROW
        clc
        adc dpTop
        cmp dpN
        bcs !w2-
        clc
        adc #1                   // header overslaan -> echte dir-index
        sta dpItem
        jsr da_prgFromDir
        clc
        rts
!cancel:
        sec
        rts

// dp_Max - A = hoogste dpTop (0 = alles past).
dp_Max:
        lda dpN
        sec
        sbc #DP_VIS
        bcs !m+
        lda #0
!m:     rts

//--------------------------------------------------------
// da_prgFromDir - kopieer directory-entry dpItem (screencode) naar prgTmp
//   (petscii, $ff). Letters $01..$1a -> +$40; rest gelijk.
//--------------------------------------------------------
da_prgFromDir:
        ldx dpItem
        lda dirPtrLo,x
        sta r0
        lda dirPtrHi,x
        sta r0+1
        ldy #0
        ldx #0
!lp:    lda (r0),y
        cmp #$ff
        beq !end+
        cmp #$1b
        bcs !keep+
        clc
        adc #$40
!keep:  sta prgTmp,x
        inx
        iny
        cpx #12
        bne !lp-
!end:   lda #$ff
        sta prgTmp,x
        rts

//========================================================
// Toevoegen / Bewerken / Verwijderen
//========================================================
// da_AddProgram - nieuw gebruikersprogramma toevoegen.
da_AddProgram:
        lda DA_count
        cmp #DESK_MAXUSER
        bcc !ok+
        jmp da_showFull
!ok:    lda #<oAdd               // dialoogtitel "ADD PROGRAM"
        sta daTitle
        lda #>oAdd
        sta daTitle+1
        lda #0
        sta daLen                // leeg beginnen
        lda #<sName
        sta r0
        lda #>sName
        sta r0+1
        lda #11
        sta daMax
        jsr da_askText
        bcs !abort+
        jsr da_saveDisp
        jsr da_getPrg            // disk bladeren of typen
        bcs !abort+
        jsr da_defaultName       // lege naam? -> gebruik de PRG-naam
        lda #0
        sta daIcon
        jsr da_IconPick
        lda #WHITE
        sta daColor
        jsr da_ColorPick
        // record aanmaken op positie DA_count
        lda DA_count
        jsr da_recPtr
        jsr da_writeRec
        inc DA_count
        jsr da_Save
!abort: jmp shell_DrawAll

// da_EditProgram - bestaand programma kiezen en aanpassen.
da_EditProgram:
        lda DA_count
        bne !ok+
        jmp shell_DrawAll        // niets om te bewerken
!ok:    lda #<oEditP             // dialoogtitel "EDIT PROGRAM"
        sta daTitle
        lda #>oEditP
        sta daTitle+1
        jsr da_hintEdit
        jsr da_pickUser
        bcs !done+
        // naam voorvullen
        lda daU
        jsr da_recPtr
        jsr da_preDisp
        lda #<sName
        sta r0
        lda #>sName
        sta r0+1
        lda #11
        sta daMax
        jsr da_askText
        bcs !done+
        jsr da_saveDisp
        // prg: disk bladeren of typen
        jsr da_getPrg
        bcs !done+
        // huidige icoon/kleur als startwaarde
        lda daU
        jsr da_recPtr
        ldy #REC_ICON
        lda ($fb),y
        sta daIcon
        ldy #REC_COL
        lda ($fb),y
        sta daColor
        jsr da_IconPick
        jsr da_ColorPick
        lda daU
        jsr da_recPtr
        jsr da_writeRec
        jsr da_Save
!done:  jmp shell_DrawAll

// da_DeleteProgram - programma kiezen en verwijderen.
da_DeleteProgram:
        lda DA_count
        bne !ok+
        jmp shell_DrawAll
!ok:    jsr da_hintDelete
        jsr da_pickUser
        bcs !done+
        jsr da_confirm           // bevestiging vragen
        bcs !done+
        jsr da_removeRec
        dec DA_count
        jsr da_Save
!done:  jmp shell_DrawAll

//--------------------------------------------------------
// da_confirm - JA/NEE-bevestiging. Uit: carry=0 = JA (Y), carry=1 = NEE.
//--------------------------------------------------------
da_confirm:
        lda #<oDel               // Win95-dialoog: titel, vraag, JA/NEE-knoppen
        sta r0
        lda #>oDel
        sta r0+1
        lda #6
        sta a0
        lda #9
        sta a1
        lda #28
        sta a2
        lda #7
        sta a3
        jsr dlg_Draw             // rijen 9-15
        lda #<sConfirm
        sta r0
        lda #>sConfirm
        sta r0+1
        lda #9
        sta a0
        lda #11
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        lda #<sBtnYes            // knoppen: YES (11,13,5) en NO (22,13,4)
        sta r0
        lda #>sBtnYes
        sta r0+1
        lda #11
        sta a0
        lda #13
        sta a1
        lda #5
        sta a2
        lda TH_menubg
        sta a3
        jsr btn_Draw
        lda #<sBtnNo
        sta r0
        lda #>sBtnNo
        sta r0+1
        lda #22
        sta a0
        lda #13
        sta a1
        lda #4
        sta a2
        lda TH_menubg
        sta a3
        jsr btn_Draw
!w:     jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        bne !key+
        jsr dlg_HitClose         // sluitknop = NEE
        bcs !no+
        lda #11
        sta a0
        lda #13
        sta a1
        lda #5
        sta a2
        jsr btn_HitTest
        bcs !yes+
        lda #22
        sta a0
        lda #13
        sta a1
        lda #4
        sta a2
        jsr btn_HitTest
        bcs !no+
        jmp !w-
!key:   cmp #EVT_KEY
        bne !w-
        lda evtA
        cmp #$19                 // 'Y'
        beq !yes+
        cmp #$0e                 // 'N'
        beq !no+
        cmp #$82                 // RUN/STOP
        beq !no+
        jmp !w-
!yes:   clc
        rts
!no:    sec
        rts

//--------------------------------------------------------
// da_defaultName - is dispTmp leeg? Vul 'm met de PRG-naam (prgTmp),
//                  petscii -> screencode.
//--------------------------------------------------------
da_defaultName:
        lda dispTmp
        cmp #$ff
        bne !done+               // er staat al een naam
        ldx #0
!lp:    lda prgTmp,x
        cmp #$ff
        beq !end+
        cmp #$41
        bcc !keep+
        cmp #$5b
        bcs !keep+
        sec
        sbc #$40                 // petscii-letter -> screencode
!keep:  sta dispTmp,x
        inx
        cpx #12
        bne !lp-
!end:   lda #$ff
        sta dispTmp,x
!done:  rts

//--------------------------------------------------------
// da_writeRec - schrijf daIcon/daColor/dispTmp/prgTmp naar record ($fb).
//--------------------------------------------------------
da_writeRec:
        lda daIcon
        ldy #REC_ICON
        sta ($fb),y
        lda daColor
        ldy #REC_COL
        sta ($fb),y
        lda #<dispTmp
        sta r0
        lda #>dispTmp
        sta r0+1
        jsr da_setDisp
        lda #<prgTmp
        sta r0
        lda #>prgTmp
        sta r0+1
        jmp da_setPrg

//--------------------------------------------------------
// da_pickUser - wacht tot er op een GEBRUIKERSrecord geklikt wordt.
//   Uit: carry=0 en daU=index, of carry=1 (RUN/STOP of ongeldig).
//--------------------------------------------------------
da_pickUser:
!w:     jsr da_pollClick
        bcs !cancel+
        jsr da_hitEntry
        bcc !w-
        cmp biCount
        bcc !w-                  // ingebouwde app -> negeren
        sec
        sbc biCount
        sta daU
        clc
        rts
!cancel:
        sec
        rts

//--------------------------------------------------------
// da_removeRec - verwijder record daU (schuif de rest naar beneden).
//--------------------------------------------------------
da_removeRec:
        lda daU
        sta daTmp
!lp:    lda daTmp
        clc
        adc #1
        cmp DA_count
        bcs !done+
        lda daTmp
        jsr da_recPtr            // dst
        lda $fb
        sta $fd
        lda $fc
        sta $fe
        lda daTmp
        clc
        adc #1
        jsr da_recPtr            // src
        ldy #0
!cp:    lda ($fb),y
        sta ($fd),y
        iny
        cpy #REC_STRIDE
        bne !cp-
        inc daTmp
        jmp !lp-
!done:  rts

//--------------------------------------------------------
// da_saveDisp - inBuf (screencode,$ff) -> dispTmp.
//--------------------------------------------------------
da_saveDisp:
        ldx #0
!lp:    lda inBuf,x
        sta dispTmp,x
        cmp #$ff
        beq !end+
        inx
        cpx #12
        bne !lp-
        lda #$ff
        sta dispTmp,x
!end:   rts

//--------------------------------------------------------
// da_savePrg - inBuf (screencode,$ff) -> prgTmp (petscii,$ff).
//   Letters $01..$1a -> +$40; rest blijft gelijk.
//--------------------------------------------------------
da_savePrg:
        ldx #0
!lp:    lda inBuf,x
        cmp #$ff
        beq !end+
        cmp #$1b
        bcs !keep+
        clc
        adc #$40
!keep:  sta prgTmp,x
        inx
        cpx #12
        bne !lp-
!end:   lda #$ff
        sta prgTmp,x
        rts

//--------------------------------------------------------
// da_preDisp - record disp ($fb+REC_DISP) -> inBuf, zet daLen.
//--------------------------------------------------------
da_preDisp:
        ldy #REC_DISP
        ldx #0
!lp:    lda ($fb),y
        cmp #$ff
        beq !end+
        sta inBuf,x
        inx
        iny
        cpx #12
        bne !lp-
!end:   stx daLen
        rts

//--------------------------------------------------------
// da_prePrg - record prg ($fb+REC_PRG, petscii) -> inBuf (screencode),
//             zet daLen. Petscii-letters $41..$5a -> -$40.
//--------------------------------------------------------
da_prePrg:
        ldy #REC_PLEN
        lda ($fb),y
        sta daTmp                // lengte
        ldy #REC_PRG
        ldx #0
!lp:    cpx daTmp
        beq !end+
        lda ($fb),y
        cmp #$41
        bcc !keep+
        cmp #$5b
        bcs !keep+
        sec
        sbc #$40
!keep:  sta inBuf,x
        inx
        iny
        jmp !lp-
!end:   stx daLen
        rts

//--------------------------------------------------------
// Kleine meldingen/hints.
//--------------------------------------------------------
da_hintDelete:
        lda #<sDelHint
        sta r0
        lda #>sDelHint
        sta r0+1
        jmp da_hintDraw
da_hintEdit:
        lda #<sEditHint
        sta r0
        lda #>sEditHint
        sta r0+1
        jmp da_hintDraw
// da_hintDraw - hint (r0) in de statusregel van het venster (rij 18).
//               Er staat geen dialoog open: sluitknop-positie vergeten.
da_hintDraw:
        lda #$ff
        sta dlgY
        lda r0
        sta daPr
        lda r0+1
        sta daPr+1
        lda #2
        sta a0
        lda #18
        sta a1
        lda #34
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda daPr
        sta r0
        lda daPr+1
        sta r0+1
        lda #3
        sta a0
        lda #18
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText

// da_showFull - Win95-melding "lijst vol" met OK-knop.
da_showFull:
        lda #<nDesk
        sta r0
        lda #>nDesk
        sta r0+1
        lda #6
        sta a0
        lda #8
        sta a1
        lda #28
        sta a2
        lda #7
        sta a3
        jsr dlg_Draw             // rijen 8-14
        lda #<sFull
        sta r0
        lda #>sFull
        sta r0+1
        lda #10
        sta a0
        lda #10
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        lda #18
        sta a0
        lda #12
        sta a1
        jsr dlg_OkButton
        jsr dlg_WaitClose
        jmp shell_DrawAll

//--------------------------------------------------------
// Data (scratch + seed)
//--------------------------------------------------------
daSlot:  .byte 0
daEnt:   .byte 0
daScroll:.byte 0
daTmp:   .byte 0
daU:     .byte 0
daOff:   .byte 0
daLen:   .byte 0
daIcon:  .byte 0
daColor: .byte 0
daTX:    .byte 0
daTY:    .byte 0
daMax:   .byte 0
daK:     .byte 0
dpTop:   .byte 0
dpI:     .byte 0
dpItem:  .byte 0
dpN:     .byte 0
daTitle: .word oAdd              // titel van de invoerdialoog (ADD/EDIT)
daPr:    .word 0
inBuf:   .fill 14, 0
dispTmp: .fill 14, 0
prgTmp:  .fill 14, 0

.encoding "screencode_upper"
sName:     .text "ENTER NAME:"
           .byte $ff
sPrg:      .text "ENTER PRG FILE:"
           .byte $ff
sPrgPick:  .text "PICK A PRG FILE"
           .byte $ff
sPrgHint:  .text "ESC = TYPE THE NAME"
           .byte $ff
sTIcon:    .text "PICK AN ICON"
           .byte $ff
sTColor:   .text "PICK A COLOR"
           .byte $ff
sPickIcon: .text "CLICK ONE  (ESC = KEEP)"
           .byte $ff
sPickCol:  .text "CLICK ONE  (ESC = KEEP)"
           .byte $ff
sDelHint:  .text "CLICK A PROGRAM TO DELETE (ESC)"
           .byte $ff
sEditHint: .text "CLICK A PROGRAM TO EDIT (ESC)"
           .byte $ff
sFull:     .text "PROGRAM LIST IS FULL"
           .byte $ff
sConfirm:  .text "DELETE THIS PROGRAM?"
           .byte $ff
sBtnYes:   .text "YES"
           .byte $ff
sBtnNo:    .text "NO"
           .byte $ff

seedIcon: .byte 3, 7
seedCol:  .byte YELLOW, PURPLE
seedDispLo: .byte <sdCow, <sdScr
seedDispHi: .byte >sdCow, >sdScr
seedPrgLo:  .byte <spCow, <spScr
seedPrgHi:  .byte >spCow, >spScr
.encoding "screencode_upper"
sdCow:  .text "COWBOY"
        .byte $ff
sdScr:  .text "SCRSAVER"
        .byte $ff
.encoding "petscii_upper"
spCow:  .text "COWBOY"
        .byte $ff
spScr:  .text "SCRSAVER"
        .byte $ff
.encoding "screencode_upper"
