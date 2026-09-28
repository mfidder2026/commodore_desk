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
.const NUM_USERICONS = 16        // kiesbare 1-cel-iconen (codes 64-79)
.const BIG_ICON_BASE = 20        // icoon >= 20 = groot 2x2-icoon (bigIcon)
.const NUM_SEED      = 3         // standaard-programma's (SCRSAVER, C64 CITY, POKEMON RED)
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
        jsr da_Style
        jsr da_clampScroll
        lda #0
        sta daSlot
!lp:    lda daSlot
        cmp daVis
        bcs !bars+
        clc
        adc daScroll
        sta daEnt
        jsr da_total
        cmp daEnt
        beq !bars+
        bcc !bars+
        lda daSlot               // kolom = slot mod n, rij = slot div n
        jsr da_div
        stx deRow
        clc                      // kolom-x uit de tabel van de stijl
        adc daColOff
        tax
        lda daColX,x
        sta deCol
        lda #0                   // rij-y = rij * hoogte + eerste rij
        ldx deRow
!m:     beq !md+
        clc
        adc daRowH
        dex
        jmp !m-
!md:    clc
        adc daRow0
        sta deRow
        jsr da_drawOne
        inc daSlot
        jmp !lp-
!bars:  jmp da_drawScrollbar

// da_Style - indeling van de stijl (stGeos): Win95 2 kolommen met het
//            label ernaast, GEOS 3 kolommen met het label eronder.
da_Style:
        ldx stGeos
        lda dsCols,x
        sta daCols
        lda dsRowH,x
        sta daRowH
        lda dsVisR,x
        sta daVisR
        lda dsVis,x
        sta daVis
        lda dsRow0,x
        sta daRow0
        lda dsColOff,x
        sta daColOff
        cpx daLastSt             // andere stijl: bovenaan beginnen
        beq !+
        stx daLastSt
        lda #0
        sta daScroll
!:      rts
dsCols:   .byte 2, 3
dsRowH:   .byte 3, 5
dsVisR:   .byte 7, 4
dsVis:    .byte 14, 12
dsRow0:   .byte 3, 4
dsColOff: .byte 0, 2
daColX:   .byte 3, 21, 6, 17, 28 // Win95: kol 3/21; GEOS: iconen op 6/17/28

// da_div - A / daCols -> X = quotient, A = rest.
da_div:
        ldx #0
!d:     cmp daCols
        bcc !r+
        sbc daCols
        inx
        bne !d-
!r:     rts

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
        cmp #BIG_ICON_BASE       // groot icoon (2x2)?
        bcc !small+
        sbc #BIG_ICON_BASE
        tax
        lda bigIcon,x
        sta deIcon
        ldy #REC_COL
        lda ($fb),y
        sta deIcoC
        jsr da_draw2x2
        jmp !lbl+
!small: cmp #NUM_USERICONS       // (vroegere iconen 16-19: diskette)
        bcc !sm+
        lda #0
!sm:    tax
        lda userIconGlyphs,x
        sta a2
        ldy #REC_COL
        lda ($fb),y
        jsr da_icoCol
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

// da_icoCol - icoonkleur A leesbaar maken op de vensterachtergrond: een
//             licht icoon op een lichte achtergrond (of donker op donker)
//             krijgt zijn tegenhanger (geel -> bruin, blauw -> lichtblauw).
da_icoCol:
        tax
        lda icClass,x
        beq !ok+                 // middentint: altijd zichtbaar
        ldy TH_deskbg
        cmp icClass,y
        bne !ok+
        lda icAlt,x
        rts
!ok:    txa
        rts
// helderheid: 0 = midden, 1 = licht, 2 = donker (VIC-II-kleuren 0-15)
icClass: .byte 2, 1, 2, 1, 0, 0, 2, 1, 0, 2, 0, 2, 0, 1, 0, 1
icAlt:   .byte LIGHT_GREY, DARK_GREY, LIGHT_RED, BLUE, PURPLE, GREEN, LIGHT_BLUE, BROWN
         .byte ORANGE, ORANGE, LIGHT_RED, LIGHT_GREY, GREY, GREEN, LIGHT_BLUE, DARK_GREY

// da_draw2x2 - groot icoon deIcon/deIcoC: 2 breed, 3 hoog (rijen deRow-1
//              .. deRow+1, zie icon_Build): het label op deRow staat zo
//              naast het midden van het icoon.
da_draw2x2:
        lda deIcoC               // zelfde kleur als de achtergrond (bv. een
        jsr da_icoCol            // lichtgrijs icoon op FREMEN): tekstkleur
        sta deIcoC
        ldx #0
!lp:    stx daIc
        txa
        and #1
        clc
        adc deCol
        sta a0
        txa
        lsr
        clc
        adc deRow
        sec
        sbc #1
        sta a1
        lda deIcon               // RADIO: 252-255, dan 80-81 (zie font.asm)
        cmp #ICO_RADIO_D
        bne !n+
        txa
        cmp #4
        bcs !b+
        adc #ICO_RADIO
        bne !s+
!b:     adc #ICO_RADIO_B-4-1     // (carry=1)
        bne !s+
!n:     txa
        clc
        adc deIcon
!s:     sta a2
        lda deIcoC
        sta a3
        jsr gfx_PutChar
        ldx daIc
        inx
        cpx #6
        bne !lp-
        rts

// da_drawLabel - label (r0) op (deCol+3, deRow) in TH_text.
da_drawLabel:
        lda deCol
        clc
        adc #3
        sta a0
        lda deRow
        sta a1
        lda stGeos               // GEOS: gecentreerd onder het icoon
        beq !w+
        ldy #0
!l:     lda (r0),y
        cmp #$ff
        beq !le+
        iny
        cpy #11
        bne !l-
!le:    sty daTmp                // kolom = cel + (11 - lengte) / 2
        lda #11
        sec
        sbc daTmp
        lsr
        clc
        adc deCol
        sec
        sbc #4
        sta a0
        lda deRow
        clc
        adc #2
        sta a1
!w:     lda TH_text
        sta a2
        jmp gfx_DrawText

// Scrollbalk van het bureaubladvenster: kolom 37, pijlen op rij 2 en 22.
.const DA_SCR_COL = 37
.const DA_SCR_TOP = 2
.const DA_SCR_BOT = WIN_BODY_BOT

// da_maxRow - A = hoogste eerste zichtbare rij (0 = alles past).
da_maxRow:
        jsr da_total             // aantal rijen = (totaal+n-1)/n
        clc
        adc daCols
        sec
        sbc #1
        jsr da_div
        txa
        sec
        sbc daVisR
        bcs !m+
        lda #0
!m:     rts

// da_clampScroll - daScroll binnen bereik houden (bv. na verwijderen).
da_clampScroll:
        jsr da_maxRow            // max in entries (n per rij)
        tax
        lda #0
!m:     cpx #0
        beq !md+
        clc
        adc daCols
        dex
        jmp !m-
!md:    cmp daScroll
        bcs !ok+
        sta daScroll
!ok:    rts

// da_drawScrollbar - Win95-scrollbalk rechts in het venster.
da_drawScrollbar:
        jsr da_maxRow
        sta a4
        lda daScroll             // rij van de bovenste entry
        jsr da_div
        stx a3
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
        sbc daCols
        jmp !st+
!dn:    lda daScroll
        clc
        adc daCols
        jmp !cl+
!pu:    lda daScroll
        sec
        sbc daVis
        bcs !st+
        lda #0
        jmp !st+
!pd:    lda daScroll
        clc
        adc daVis
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
        jsr da_Style
        lda stGeos
        bne !g+
        // Win95: hele linker-/rechterhelft telt (grens kol 20).
        lda evtA
        cmp #20
        bcc !lc+
        lda #1
        jmp !cp+
!lc:    lda #0
        beq !cp+
!g:     lda evtA                 // GEOS: kolommen van 11 vanaf kol 2
        sec
        sbc #2
        bcc !no+
        ldx #0
!gc:    cmp #11
        bcc !gd+
        sbc #11
        inx
        bne !gc-
!gd:    cpx #3
        bcs !no+
        txa
!cp:    sta deCol
        lda evtB                 // entry-rij: (rij - (eerste-1)) / hoogte
        clc
        adc #1
        sec
        sbc daRow0
        bcc !no+
        sta deRow
        ldx #0
!dl:    lda deRow
        cmp daRowH
        bcc !rem+
        sec
        sbc daRowH
        sta deRow
        inx
        jmp !dl-
!rem:   lda #0                   // rij * n + kolom
!rm:    cpx #0
        beq !rd+
        clc
        adc daCols
        dex
        jmp !rm-
!rd:    clc
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
        lda #8                   // bureaublad-programma's staan op drive 8
        sta $03be
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
        lda $fb                  // "LOADING <naam> please wait" op een
        clc                      // leeg scherm in de ROM-letters: het
        adc #REC_DISP            // PRG overschrijft onze charset ($3800)
        sta r0
        lda $fc
        adc #0
        sta r0+1
        jsr launch_Screen
        jmp launchCommon
!bad:   jmp shell_NotFound

//========================================================
// Persistentie (DESK.APPS)
//========================================================
da_Save: {
        jsr save_Begin           // "SETTINGS ARE BEING SAVED"
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
        php
        jsr cfg_io_end
        plp
        jmp save_End             // scherm terug (carry blijft)
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
// da_Seed - standaardlijst (SCRSAVER, C64 CITY, POKEMON RED).
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
daCols:  .byte 2                 // indeling (da_Style)
daRowH:  .byte 3
daVisR:  .byte 7
daVis:   .byte 14
daRow0:  .byte 3
daColOff:.byte 0
daLastSt:.byte 0
daU:     .byte 0
daOff:   .byte 0
daLen:   .byte 0
daIcon:  .byte 0
daColor: .byte 0
daIc:    .byte 0

.encoding "screencode_upper"

seedIcon: .byte 7, BIG_ICON_BASE+0, BIG_ICON_BASE+1   // CITY: skyline, POKEMON: Pokéball
seedCol:  .byte PURPLE, ORANGE, RED
seedDispLo: .byte <sdScr, <sdCity, <sdPoke
seedDispHi: .byte >sdScr, >sdCity, >sdPoke
seedPrgLo:  .byte <spScr, <spCity, <spPoke
seedPrgHi:  .byte >spScr, >spCity, >spPoke
// grote (2x2) iconen voor gebruikersprogramma's: TL-glyph per nummer
bigIcon:  .byte ICO_CITY, POKE_GLYPH     // 0 = CITY, 1 = Pokéball (2x3)
.encoding "screencode_upper"
sdScr:  .text "SCRSAVER"
        .byte $ff
sdCity: .text "C64 CITY"
        .byte $ff
sdPoke: .text "POKEMON RED"
        .byte $ff
.encoding "petscii_upper"
spScr:  .text "SCRSAVER"
        .byte $ff
spCity: .text "C64CDESK"
        .byte $ff
spPoke: .text "C64RDESK"
        .byte $ff
.encoding "screencode_upper"
