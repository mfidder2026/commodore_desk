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
.const NUM_SEED      = 3         // standaard-programma's (SCRSAVER, C64 CITY, C64 RED)
.label DA_count = $c100
.label DA_recs  = $c101
.const DA_end   = DA_recs + DESK_MAXUSER*REC_STRIDE
// Prullenbak (STONE): de weggegooide records staan achteraan in de tabel
// (plek 11, 10, ...), hun aantal direct achter de tabel.
.label DA_trashN = DA_end

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

// da_Style - indeling van de stijl (stStone): Win95 2 kolommen met het
//            label ernaast, STONE 3 kolommen met het label eronder; met de
//            strook rechts (CFG_strip, daStrip) is het venster smaller.
da_Style:
        lda CFG_strip
        and #7
        beq !n+
        lda #1
!n:     sta daStrip
        lda stStone
        asl
        ora daStrip
        tax
        lda dsCellX,x
        sta daCellX
        lda dsCellW,x
        sta daCellW
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
        lda dsScrCol,x
        sta daScrCol
        lda dsClrW,x
        sta daClrW
        cpx daLastSt             // andere stijl: bovenaan beginnen
        beq !+
        stx daLastSt
        lda #0
        sta daScroll
!:      rts
//        Win95, Win95+strook, STONE, STONE+strook
dsCols:   .byte 2, 2, 3, 3
dsRowH:   .byte 3, 3, 5, 5
dsVisR:   .byte 7, 7, 4, 4
dsVis:    .byte 14, 14, 12, 12
dsRow0:   .byte 3, 3, 4, 4
dsColOff: .byte 0, 2, 4, 7
dsScrCol: .byte 37, 32, 37, 32   // scrollbalk (strook: smaller venster)
dsClrW:   .byte 35, 30, 35, 30   // breedte van de vensterinhoud
dsCellX:  .byte 0, 0, 2, 2       // klikzones: eerste kolom en breedte
dsCellW:  .byte 20, 18, 11, 10
daColX:   .byte 3, 21, 3, 18, 6, 17, 28, 5, 15, 25

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
        lda stStone               // STONE: 3x3-iconen, naam eronder
        beq !w95+
        jmp da_drawStone
!w95:   lda daEnt
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
!sm:    clc                      // de 20 kies-iconen staan op 64-83
        adc #64
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
        jsr da_code6
        sta a2
        lda deIcoC
        sta a3
        jsr gfx_PutChar
        ldx daIc
        inx
        cpx #6
        bne !lp-
        rts

// da_code6 - charset-code van cel X (0-5) van het 2x3-icoon deIcon.
da_code6:
        lda deIcon               // RADIO: 252-255, dan 80-81 (zie font.asm)
        cmp #ICO_CAL             // CALENDAR: zes losse codes
        bne !w+
        lda icon_Build.calW95,x
        rts
!w:     cmp #ICO_WEB             // WEB: cel 5 op 162
        bne !r+
        cpx #5
        bne !n+
        lda #ICO_WEB_5
        rts
!r:     cmp #ICO_RADIO_D
        bne !n+
        txa
        cmp #4
        bcs !b+
        adc #ICO_RADIO
        rts
!b:     adc #ICO_RADIO_B-4-1     // (carry=1)
        rts
!n:     txa
        clc
        adc deIcon
        rts

// da_drawLabel - label (r0) op (deCol+3, deRow) in TH_text.
da_drawLabel:
        lda deCol
        clc
        adc #3
        sta a0
        lda deRow
        sta a1
        lda stStone               // STONE: gecentreerd onder het icoon
        beq !w+
        ldy #0
!l:     lda (r0),y
        cmp #$ff
        beq !le+
        iny
        cpy #9                   // (max. 9: altijd ruimte tussen de namen)
        bne !l-
!le:    sty daTmp                // (naam afkappen op 10 tekens)
        lda #$ff
        sta daLbl,y
!lc:    dey
        bmi !lk+
        lda (r0),y
        sta daLbl,y
        jmp !lc-
!lk:    lda #<daLbl
        sta r0
        lda #>daLbl
        sta r0+1
                                 // kolom = cel + (10 - lengte) / 2
        lda #10
        sec
        sbc daTmp
        lsr
        clc
        adc deCol
        sec
        sbc #3
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
        lda daScrCol
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
        lda daClrW
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
        jsr da_Style
        lda evtA
        cmp daScrCol
        beq da_scrollClick       // scrollbalk-kolom
        lda daStrip              // de strook rechts
        beq !g+
        lda evtA
        cmp #34
        bcc !g+
        jsr da_StripHit
        bcc !r+
        jmp da_StripAct
!g:     jmp da_gridClick
!r:     rts

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
        ldx daStrip              // met de strook: slepen
        beq !open+
        sta daDrag
        jsr da_Ghost             // muispijl = het icoon
!w:     lda crsBtn               // tot de knop los is
        bne !w-
        lda #13
        sta $07f8
        lda evtTail              // (het MOUSEUP-bericht vergeten)
        sta evtHead
        jsr cursorToCell
        lda evtA
        cmp #34
        bcs !drop+
        jsr da_hitEntry          // losgelaten op hetzelfde icoon = starten
        bcc !r+
        cmp daDrag
        bne !r+
!open:  cmp biCount
        bcs !user+
        tax
        lda biApp,x
        jmp openApp
!user:  sec
        sbc biCount
        jmp da_Launch
!drop:  jsr da_StripHit          // op de strook losgelaten
        bcc !r+
        cpx #2
        bne !sa+
        lda daDrag               // prullenbak: alleen eigen programma's
        sec
        sbc biCount
        bcs !us+
        ldx #6
        jmp tool_Run
!us:    sta toolArg
        ldx #3
        jmp tool_Run
!sa:    jmp da_StripAct
!r:     rts

//--------------------------------------------------------
// da_hitEntry - reken (evtA,evtB) om naar een entry-index.
//               Uit: A=entry, carry=1 geldig, carry=0 buiten het raster.
//--------------------------------------------------------
da_hitEntry:
        jsr da_Style
        lda evtA                 // kolommen van daCellW vanaf daCellX
        sec
        sbc daCellX
        bcc !no+
        ldx #0
!gc:    cmp daCellW
        bcc !gd+
        sbc daCellW
        inx
        bne !gc-
!gd:    cpx daCols
        bcs !no+
        txa
        sta deCol
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

//========================================================
// STONE-stijl (stStone): 3x3-iconen, strook met DRIVE / PRINTER / TRASH,
// slepen naar de strook.
//========================================================
// da_drawStone - entry daEnt: icoon (deCol = linkerkolom, deRow = midden)
//               en de naam eronder.
da_drawStone:
        lda daEnt
        cmp biCount
        bcs !u+
        tax
        lda biIcoCol,x
        sta deIcoC
        lda biNameLo,x
        sta r0
        lda biNameHi,x
        sta r0+1
        cpx #7                   // SID PLAYER past niet in 9 tekens
        bne !sn+
        lda #<sgSid
        sta r0
        lda #>sgSid
        sta r0+1
!sn:    lda daEnt                // ingebouwd programma i = STONE-icoon i
        cmp #9                   // (WEATHER, WEB ...: 14, 15 ...)
        bcc !d+
        adc #GI_WEATHER-9-1      // (carry=1)
        jmp !d+
!u:     sec
        sbc biCount
        jsr da_recPtr
        ldy #REC_COL
        lda ($fb),y
        and #$0f
        sta deIcoC
        lda $fb
        clc
        adc #REC_DISP
        sta r0
        lda $fc
        adc #0
        sta r0+1
        lda #GI_APP
!d:     jsr da_giCode
        sta deIcon
        dec deRow
        jsr da_draw3x3
        inc deRow
        jmp da_drawLabel

// da_giCode - STONE-icoon A -> eerste charset-code (128 + 9*A).
da_giCode:
        cmp #GI_WEATHER          // WEATHER, WEB, CALENDAR: 102, 111, 120
        bcc !g+
        sbc #GI_WEATHER
        tax
        lda giBig,x
        rts
!g:     sta daT
        asl
        asl
        asl
        clc
        adc daT
        clc
        adc #GI_BASE
        rts

// da_code9 - charset-code van cel X (0-8) van het 3x3-icoon deIcon
//            (CALENDAR: de 9e cel op 254). X blijft niet altijd.
da_code9:
        txa
        clc
        adc deIcon
        cpx #8
        bne !r+
        ldx deIcon
        cpx #GI_CAL_CODE
        bne !r+
        lda #GI_CAL_9TH
!r:     rts
giBig:  .byte GI_WEATHER_CODE, GI_WEB_CODE, GI_CAL_CODE

// da_draw3x3 - icoon deIcon (9 codes) op kolom deCol, rij deRow en verder.
da_draw3x3:
        lda deIcoC
        jsr da_icoCol
        sta a3
        lda #0
        sta daIc
        lda deRow
        sta daR
!rl:    lda deCol
        sta daC
!cl:    lda daC
        sta a0
        lda daR
        sta a1
        ldx daIc
        jsr da_code9
        sta a2
        jsr gfx_PutChar
        inc daIc
        inc daC
        lda daC
        sec
        sbc deCol
        cmp #3
        bne !cl-
        inc daR
        lda daIc
        cmp #9
        bne !rl-
        rts

// da_Strip - rechts van het venster: geruit, met de iconen die aan staan
//            (CFG_strip): DRIVE, PRINTER, TRASH, van boven af.
da_Strip:
        lda #34
        sta a0
        lda #1
        sta a1
        lda #6                   // kol 34-39
        sta a2
        lda #23
        sta a3
        lda stDeskFill
        sta a4
        lda TH_desktop
        sta a5
        jsr gfx_FillRect
        lda #0
        sta daSN
        tax
!lp:    stx daSI
        lda CFG_strip
        and gsBit,x
        bne !on+
        jmp !nx+
!on:
        ldy daSN                 // volgende plek
        txa
        sta gsWhich,y
        lda gsRow,y
        sta deRow
        inc daSN
        cpx #2                   // volle prullenbak?
        bne !n+
        ldy DA_trashN
        beq !n+
        inx
!n:     lda #36                  // (kol 34: ruimte tot het venster)
        sta deCol
        lda TH_text
        sta deIcoC
        lda stStone
        beq !w+
        lda gsIco,x              // STONE: 3x3
        jsr da_giCode
        sta deIcon
        jsr da_draw3x3
        jmp !lb+
!w:     lda gsW95,x              // Win95: 2x3 (rijen deRow-1..deRow+1)
        sta deIcon
        inc deRow
        jsr da_draw2x2
        dec deRow
        lda daSI                 // volle prullenbak: de lege + eigen bovenrij
        cmp #2
        bne !lb+
        lda DA_trashN
        beq !lb+
        lda deCol
        sta a0
        lda deRow
        sta a1
        lda #GL_TRASHF
        sta a2
        lda deIcoC
        sta a3
        jsr gfx_PutChar
        inc a0
        inc a2
        jsr gfx_PutChar
!lb:    ldx daSI
        lda gsLo,x
        sta r0
        lda gsHi,x
        sta r0+1
        lda #35
        sta a0
        lda deRow
        clc
        adc #3
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
!nx:    ldx daSI
        inx
        cpx #3
        beq !r+
        jmp !lp-
!r:
        rts

// da_StripHit - (evtA,evtB) op de strook: X = 0 DRIVE, 1 PRINTER,
//               2 TRASH (carry=1), anders carry=0.
da_StripHit:
        ldy #0
!l:     cpy daSN
        bcs !no+
        lda evtB
        sec
        sbc gsRow,y
        bcc !nx+
        cmp #4
        bcs !nx+
        ldx gsWhich,y
        sec
        rts
!nx:    iny
        bne !l-
!no:    clc
        rts

// da_StripAct - klik op DRIVE (FILES), PRINTER of TRASH (X).
da_StripAct:
        cpx #0
        bne !p+
        lda #0                   // DRIVE = de File Manager
        jmp openApp
!p:     inx                      // 1 -> 4 (printer), 2 -> 5 (prullenbak)
        inx
        inx
        jmp tool_Run

// da_Ghost - muispijl = icoon van entry A (sprite-blok 14, $0380): eerst
//            de 3x3 cellen (ghC), dan de 24x21 pixels daaruit.
da_Ghost:
        sta daGE
        ldx #8
        lda #$20                 // lege cel = spatie
!c:     sta ghC,x
        dex
        bpl !c-
        lda stStone
        beq !w+
        lda daGE                 // STONE: 9 codes op een rij
        cmp biCount
        bcs !u+
        cmp #9                   // WEATHER, WEB ...: eigen iconen
        bcc !c+
        adc #GI_WEATHER-9-1      // (carry=1)
        bcc !c+
!u:     lda #GI_APP
!c:     jsr da_giCode
        sta deIcon
        ldx #0
!g:     stx daIc
        jsr da_code9
        ldx daIc
        sta ghC,x
        inx
        cpx #9
        bne !g-
        beq !mk+
!w:     lda daGE                 // Win95: 2x3-icoon of 1 cel
        cmp biCount
        bcs !u+
        tax
        lda biIcon,x
        jmp !i6+
!u:     sec
        sbc biCount
        jsr da_recPtr
        ldy #REC_ICON
        lda ($fb),y
        cmp #BIG_ICON_BASE
        bcc !sm+
        sbc #BIG_ICON_BASE
        tax
        lda bigIcon,x
!i6:    sta deIcon
        ldx #0
!s6:    stx daIc
        jsr da_code6
        ldx daIc
        ldy gh6,x
        sta ghC,y
        inx
        cpx #6
        bne !s6-
        beq !mk+
!sm:    cmp #NUM_USERICONS
        bcc !s1+
        lda #0
!s1:    clc
        adc #64
        sta ghC+4
!mk:    ldx #0
        stx daR
!rl:    lda daR                  // pixelrij r: cellen (r/8)*3 .. +2, rij r%8
        and #7
        sta daRr
        lda daR
        lsr
        lsr
        lsr
        sta daT
        asl
        adc daT
        sta daT
        lda #3
        sta daC
!cc:    stx daX
        ldy daT
        lda ghC,y                // $fb = charset + code*8
        sta $fb
        lda #0
        sta $fc
        asl $fb
        rol $fc
        asl $fb
        rol $fc
        asl $fb
        rol $fc
        lda $fb
        clc
        adc #<CHARSET_BASE
        sta $fb
        lda $fc
        adc #>CHARSET_BASE
        sta $fc
        ldy daRr
        lda ($fb),y
        ldx daX
        sta $0380,x
        inx
        inc daT
        dec daC
        bne !cc-
        inc daR
        lda daR
        cmp #21
        bne !rl-
        lda #14
        sta $07f8
        rts

gsRow:  .byte 3, 9, 15
gsBit:  .byte 1, 2, 4
gsIco:  .byte GI_DRIVE, GI_PRINTER, GI_TRASH, GI_TRASHF
gsW95:  .byte STRIP_BASE, STRIP_BASE+6, STRIP_BASE+12, STRIP_BASE+12
gsLo:   .byte <sgDrive, <sgPrint, <sgTrash
gsHi:   .byte >sgDrive, >sgPrint, >sgTrash
gh6:    .byte 0, 1, 3, 4, 6, 7   // 2x3-cel -> 3x3-cel
gsWhich: .byte 0, 0, 0
.label ghC = $c0d0               // 9 bytes (vrij RAM, niet in de Core)
daSN:   .byte 0
daGE:   .byte 0
daRr:   .byte 0
daX:    .byte 0
daStrip: .byte 0
daCellX: .byte 0
daCellW: .byte 20
.encoding "screencode_upper"
sgDrive: .text "DRIVE"
        .byte $ff
sgPrint: .text "PRINT"
        .byte $ff
sgTrash: .text "TRASH"
        .byte $ff
sgSid:  .text "SIDPLAYER"
        .byte $ff

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
        ldx #<[DA_end+1]         // (+ DA_trashN)
        ldy #>[DA_end+1]
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
        sta DA_trashN            // (oudere DESK.APPS: lege prullenbak)
        ldx #<DA_count
        ldy #>DA_count
        jsr K_LOAD
        jsr cfg_io_end
        bcs !seed+
        lda DA_count
        clc
        adc DA_trashN
        cmp #DESK_MAXUSER+1
        bcc !ok+
        lda #0
        sta DA_trashN
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
// da_Seed - standaardlijst (SCRSAVER, C64 CITY, C64 RED).
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
daScrCol:.byte 37
daClrW:  .byte 35
daDrag:  .byte 0
daR:     .byte 0
daC:     .byte 0
daT:     .byte 0
daSI:    .byte 0
.label daLbl = $c0d9             // 11 bytes (vrij RAM, niet in de Core)
daU:     .byte 0
daOff:   .byte 0
daLen:   .byte 0
daIcon:  .byte 0
daColor: .byte 0
daIc:    .byte 0

.encoding "screencode_upper"

seedIcon: .byte 7, BIG_ICON_BASE+0, BIG_ICON_BASE+1   // CITY: skyline, C64 RED: Pokéball
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
sdPoke: .text "C64 RED"
        .byte $ff
.encoding "petscii_upper"
spScr:  .text "SCRSAVER"
        .byte $ff
spCity: .text "C64CDESK"
        .byte $ff
spPoke: .text "C64RDESK"
        .byte $ff
.encoding "screencode_upper"
