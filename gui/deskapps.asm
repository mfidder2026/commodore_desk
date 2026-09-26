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
.const NUM_SEED      = 3         // standaard-programma's (COWBOY, SCRSAVER, C64 CITY)
.label DA_count = $c100
.label DA_recs  = $c101
.const DA_end   = DA_recs + DESK_MAXUSER*REC_STRIDE

.const REC_ICON = 0
.const REC_COL  = 1
.const REC_DISP = 2
.const REC_PLEN = 15
.const REC_PRG  = 16

.const DA_VISROWS = 7            // entry-rijen 3,6,..,21 (2 hoog)
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
        cmp #NUM_USERICONS       // groot icoon (2x2)?
        bcc !small+
        sbc #NUM_USERICONS
        tax
        lda bigIcon,x
        sta deIcon
        ldy #REC_COL
        lda ($fb),y
        sta deIcoC
        jsr da_draw2x2
        jmp !lbl+
!small: tax
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
!lbl:   lda $fb
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

// Scrollbalk van het bureaubladvenster: kolom 37, pijlen op rij 2 en 22.
.const DA_SCR_COL = 37
.const DA_SCR_TOP = 2
.const DA_SCR_BOT = WIN_BODY_BOT

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
        lda #WIN_BODY_BOT-1
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
        lda $fb                  // "LOADING <naam> / PLEASE WAIT": laden
        clc                      // duurt op een echte drive lang
        adc #REC_DISP
        sta r0
        lda $fc
        adc #0
        sta r0+1
        jsr showLoadName
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
        cmp #NUM_SEED
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
!done:  lda #NUM_SEED
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

.encoding "screencode_upper"

seedIcon: .byte 3, 7, NUM_USERICONS+0     // C64 CITY: groot skyline-icoon
seedCol:  .byte YELLOW, PURPLE, ORANGE
seedDispLo: .byte <sdCow, <sdScr, <sdCity
seedDispHi: .byte >sdCow, >sdScr, >sdCity
seedPrgLo:  .byte <spCow, <spScr, <spCity
seedPrgHi:  .byte >spCow, >spScr, >spCity
// grote (2x2) iconen voor gebruikersprogramma's: TL-glyph per nummer
bigIcon:  .byte 123                       // 0 = CITY
.encoding "screencode_upper"
sdCow:  .text "COWBOY"
        .byte $ff
sdScr:  .text "SCRSAVER"
        .byte $ff
sdCity: .text "C64 CITY"
        .byte $ff
.encoding "petscii_upper"
spCow:  .text "COWBOY"
        .byte $ff
spScr:  .text "SCRSAVER"
        .byte $ff
spCity: .text "C64CITY"
        .byte $ff
.encoding "screencode_upper"
