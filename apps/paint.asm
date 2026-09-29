#importonce
//========================================================
// apps/paint.asm - Paint (multicolor-bitmap, 16 kleuren)
// Commodore Desk 64
//
// Paint is een VOLLEDIG-SCHERM multicolor-bitmapmodus. Zolang de app
// open is schakelt de VIC naar VIC-bank 1 ($4000-$7FFF) - vrij RAM
// boven de OS-image - met de bitmap op $6000 en de video-matrix op
// $4000. Bij het verlaten (ESC) schakelt alles terug naar char-mode.
//
// 160x200 "dikke pixels". Achtergrond (bitpaar 00) is WIT en gedeeld
// over het hele scherm. Per 8x8-cel zijn er daarnaast 3 vrije kleur-
// slots (matrix hoge nibble = 01, lage nibble = 10, kleuren-RAM = 11),
// die Paint automatisch toewijst als je tekent. Zo is het HELE 16-
// kleurenpalet beschikbaar (max 3 niet-blauwe kleuren per cel).
//
// BELANGRIJK: schrijf $D011/$D016 met VASTE waarden, nooit via
// read-modify-write - een gelezen $D011 bevat in bit 7 de rasterregel
// en zou de raster-IRQ (en dus alle input) kunnen slopen.
//========================================================

.label BITMAP  = $6000           // 8000 bytes bitmap (VIC-bank 1 + $2000)
.label VMATRIX = $4000           // video-matrix (kleurparen per cel)
.label pnPtr   = $3c             // zeropage-pointer (bitmap)
.label pnMPtr  = $fb             // zeropage-pointer (matrix)
.label pnCPtr  = $fd             // zeropage-pointer (kleuren-RAM)

.const PN_BG     = WHITE         // gedeelde achtergrond (bitpaar 00)
.const PN_MINIT  = [PN_BG<<4]|PN_BG // matrix-init: beide slots = achtergrond
.const PN_PALTOP = 184           // py >= dit = palet-strook

//--------------------------------------------------------
// paint_Enter - schakel naar multicolor-bitmap en teken canvas+palet.
//--------------------------------------------------------
paint_Enter:
        lda #1                   // spatie = pen
        sta paintSpace
        lda #0
        sta plValid
        ldx #<COLOR_RAM          // lege tekening (kleuren direct in het
        ldy #>COLOR_RAM          // kleuren-RAM)
        jsr pn_Clear
        jsr pn_Video             // multicolor-bitmapmodus aan
        // 9) palet + gum-knop tekenen, startkleur ZWART
        jsr paint_DrawPalette
        jsr paint_DrawEraser
        jsr paint_DrawMenuBtn
        lda #BLACK
        sta pnCurrent
        rts

//--------------------------------------------------------
// paint_Exit - terug naar char-mode desktop (VASTE $D011/$D016!).
//--------------------------------------------------------
paint_Exit:
        lda #0
        sta paintSpace
        lda #$1b                 // char-mode, DEN, 25 rijen, yscroll 3
        sta VIC_CTRL1
        lda #$c8                 // multicolor uit, 40 kolommen
        sta VIC_CTRL2
        lda CIA2_PRA             // VIC-bank 0
        ora #$03
        sta CIA2_PRA
        lda #$1e                 // scherm $0400, charset $3800
        sta VIC_MEM
        lda #13                  // cursor-pointer terug (bank 0)
        sta $07f8
        lda TH_mouse             // cursor weer in de ingestelde kleur
        sta SPR0_COL
        lda TH_deskbg
        sta BG_COL0
        lda TH_border
        sta BORDER_COL
        rts

//--------------------------------------------------------
// paint_DrawPalette - 16 stalen (elk 8 dikke-pixels) op de onderste
//                     twee rijen (py 184-199).
//--------------------------------------------------------
paint_DrawPalette:
        lda #0
        sta pnPalSw              // kleurindex 0..15
psw:    lda pnPalSw
        cmp #16
        bcs pdone
        lda #PN_PALTOP
        sta pnPy
ppy:    lda pnPalSw              // fatx-basis = index*8
        asl
        asl
        asl
        sta pnPalFx0
        lda #0
        sta pnPalDx
pfx:    lda pnPalFx0
        clc
        adc pnPalDx
        sta pnFx
        lda pnPalSw
        sta pnCurrent
        jsr paint_Plot
        inc pnPalDx
        lda pnPalDx
        cmp #8
        bne pfx
        inc pnPy
        lda pnPy
        cmp #200
        bne ppy
        inc pnPalSw
        jmp psw
pdone:  rts

//--------------------------------------------------------
// paint_Click - klik (EVT_MOUSEDOWN): kleur kiezen of pixel zetten.
//--------------------------------------------------------
paint_Click:
        jsr paint_CursorToFat
        lda pnPy
        cmp #PN_PALTOP
        bcs pickColor
        jmp paint_Plot
pickColor:
        lda pnFx
        cmp #136
        bcc pkColors
        cmp #152
        bcs pcMenu               // rechts: MENU (NEW / LOAD / SAVE / PRINT)
        lda #PN_BG               // gum-vakje -> wis (teken achtergrond)
        sta pnCurrent
        rts
pkColors:
        lsr
        lsr
        lsr                      // fatx / 8 = staalnummer (0..15)
        cmp #16
        bcs pcDone
        sta pnCurrent
pcDone: rts
pcMenu: jmp paint_Menu

//--------------------------------------------------------
// paint_DrawEraser - duidelijk gum-vakje (lichtgrijs blok + zwart
//                    kruis) rechts in de palet-balk (fatx 136-151).
//--------------------------------------------------------
paint_DrawEraser:
        lda #PN_PALTOP           // lichtgrijs blok
        sta pnPy
er_y:   lda #136
        sta pnFx
er_x:   lda #LIGHT_GREY
        sta pnCurrent
        jsr paint_Plot
        inc pnFx
        lda pnFx
        cmp #152
        bne er_x
        inc pnPy
        lda pnPy
        cmp #200
        bne er_y
        lda #0                   // zwart kruis (twee diagonalen)
        sta pnPalSw              // d = 0..15
er_d:   lda pnPalSw              // (136+d, 184+d)
        clc
        adc #136
        sta pnFx
        lda pnPalSw
        clc
        adc #PN_PALTOP
        sta pnPy
        lda #BLACK
        sta pnCurrent
        jsr paint_Plot
        lda #151                 // (151-d, 184+d)
        sec
        sbc pnPalSw
        sta pnFx
        lda pnPalSw
        clc
        adc #PN_PALTOP
        sta pnPy
        lda #BLACK
        sta pnCurrent
        jsr paint_Plot
        inc pnPalSw
        lda pnPalSw
        cmp #16
        bne er_d
        rts

//--------------------------------------------------------
// paint_Live - elke lus (alleen als Paint actief is): teken zolang
//              de knop ingedrukt is (sleep-tekenen).
//--------------------------------------------------------
paint_Live:
        lda crsBtn               // pen van het papier?
        beq plUp
        jsr paint_CursorToFat
        lda pnPy
        cmp #PN_PALTOP
        bcs plUp                 // niet over het palet tekenen
        lda plValid
        bne plLine               // al aan het tekenen: lijn doortrekken
        lda #1
        sta plValid
        lda pnFx
        sta plX
        lda pnPy
        sta plY
        jmp paint_Plot
plUp:   lda #0
        sta plValid
        rts

// plLine - lijn (Bresenham) van (plX,plY) naar (pnFx,pnPy); het
//          beginpunt staat er al. De cursor beweegt meerdere pixels per
//          beeld, zonder lijn zou de streep gaten hebben.
plLine: {
        lda pnFx
        cmp plX
        bne go
        lda pnPy
        cmp plY
        bne go
        rts
go:     lda pnFx                 // dx = |tx - x|, sx = +1/-1
        sec
        sbc plX
        ldx #1
        bcs px
        eor #$ff
        adc #1
        ldx #$ff
px:     sta plDx
        stx plSx
        lda pnPy                 // dy, sy
        sec
        sbc plY
        ldx #1
        bcs py
        eor #$ff
        adc #1
        ldx #$ff
py:     sta plDy
        stx plSy
        lda plDx
        cmp plDy
        bcc ymaj
        sta plCnt                // x-hoofdrichting
        lsr
        sta plErr
xl:     lda plX
        clc
        adc plSx
        sta plX
        lda plErr
        clc
        adc plDy
        bcs xo
        cmp plDx
        bcc xn
xo:     sec
        sbc plDx
        sta plErr
        lda plY
        clc
        adc plSy
        sta plY
        jmp xp
xn:     sta plErr
xp:     jsr plDot
        dec plCnt
        bne xl
        rts
ymaj:   lda plDy                 // y-hoofdrichting
        sta plCnt
        lsr
        sta plErr
yl:     lda plY
        clc
        adc plSy
        sta plY
        lda plErr
        clc
        adc plDx
        bcs yo
        cmp plDy
        bcc yn
yo:     sec
        sbc plDy
        sta plErr
        lda plX
        clc
        adc plSx
        sta plX
        jmp yp
yn:     sta plErr
yp:     jsr plDot
        dec plCnt
        bne yl
        rts
plDot:  lda plX
        sta pnFx
        lda plY
        sta pnPy
        jmp paint_Plot
}

//--------------------------------------------------------
// paint_CursorToFat - cursor (crsX/crsY) -> dikke-pixel (pnFx 0-159)
//                     en py (pnPy 0-199).
//--------------------------------------------------------
paint_CursorToFat:
        lda crsXlo               // (crsX - 24) / 2
        sec
        sbc #24
        sta pnT0
        lda crsXhi
        sbc #0
        sta pnT1
        lsr pnT1
        ror pnT0
        lda pnT0
        sta pnFx
        lda crsY                 // crsY - 50
        sec
        sbc #50
        sta pnPy
        rts

//--------------------------------------------------------
// paint_Plot - zet dikke-pixel (pnFx,pnPy) op kleur pnCurrent (0-15).
//--------------------------------------------------------
paint_Plot:
        // cellrij / cellkolom
        lda pnPy
        lsr
        lsr
        lsr
        sta pnCellRow
        lda pnFx
        lsr
        lsr
        sta pnCellCol
        // bitmap-pointer = BITMAP + rowLo/Hi[cellrij] + cellcol*8 + (py&7)
        ldx pnCellRow
        lda #<BITMAP
        clc
        adc rowLo,x
        sta pnPtr
        lda #>BITMAP
        adc rowHi,x
        sta pnPtr+1
        lda pnCellCol            // cellcol*8 (16-bit)
        sta pnT0
        lda #0
        sta pnT1
        asl pnT0
        rol pnT1
        asl pnT0
        rol pnT1
        asl pnT0
        rol pnT1
        lda pnPtr
        clc
        adc pnT0
        sta pnPtr
        lda pnPtr+1
        adc pnT1
        sta pnPtr+1
        lda pnPy
        and #7
        clc
        adc pnPtr
        sta pnPtr
        lda pnPtr+1
        adc #0
        sta pnPtr+1
        // matrix-pointer = VMATRIX + mrowLo/Hi[cellrij] + cellcol
        ldx pnCellRow
        lda #<VMATRIX
        clc
        adc mrowLo,x
        sta pnMPtr
        lda #>VMATRIX
        adc mrowHi,x
        sta pnMPtr+1
        lda pnMPtr
        clc
        adc pnCellCol
        sta pnMPtr
        lda pnMPtr+1
        adc #0
        sta pnMPtr+1
        // kleuren-RAM-pointer = matrix-pointer + $9800 (D800-4000)
        lda pnMPtr
        sta pnCPtr
        lda pnMPtr+1
        clc
        adc #$98
        sta pnCPtr+1
        // bepaal bitpaar-code (0..3) voor pnCurrent in deze cel
        jsr pnColorCode
        // waarde = code << shift ; shift uit fatx&3
        lda pnFx
        and #3
        tax
        lda pnCode
        ldy shiftTab,x
        beq !vd+
!vs:    asl
        dey
        bne !vs-
!vd:    sta pnVal
        lda maskTab,x
        eor #$ff
        sta pnT0                 // inverse masker
        ldy #0
        lda (pnPtr),y
        and pnT0
        ora pnVal
        sta (pnPtr),y
        rts

//--------------------------------------------------------
// pnColorCode - kies/registreer een bitpaar-code voor pnCurrent in de
//               huidige cel (pnMPtr = matrix, pnCPtr = kleuren-RAM).
//               Resultaat in pnCode (0=bg,1=slot01,2=slot10,3=slot11).
//--------------------------------------------------------
pnColorCode:
        lda pnCurrent
        cmp #PN_BG
        bne !nb+
        lda #0                   // achtergrond
        sta pnCode
        rts
!nb:    ldy #0
        lda (pnMPtr),y
        sta pnMByte
        lsr
        lsr
        lsr
        lsr
        sta pnS01                // slot 01 = hoge nibble
        lda pnMByte
        and #$0f
        sta pnS10                // slot 10 = lage nibble
        ldy #0
        lda (pnCPtr),y
        and #$0f
        sta pnS11                // slot 11 = kleuren-RAM
        // al aanwezig?
        lda pnCurrent
        cmp pnS01
        bne !k2+
        lda #1
        sta pnCode
        rts
!k2:    cmp pnS10
        bne !k3+
        lda #2
        sta pnCode
        rts
!k3:    cmp pnS11
        bne !as+
        lda #3
        sta pnCode
        rts
        // toewijzen aan een vrije (=achtergrond) slot, anders slot 11
!as:    lda pnS01
        cmp #PN_BG
        bne !as2+
        lda pnMByte
        and #$0f
        sta pnT0
        lda pnCurrent
        asl
        asl
        asl
        asl
        ora pnT0
        ldy #0
        sta (pnMPtr),y
        lda #1
        sta pnCode
        rts
!as2:   lda pnS10
        cmp #PN_BG
        bne !as3+
        lda pnMByte
        and #$f0
        ora pnCurrent
        ldy #0
        sta (pnMPtr),y
        lda #2
        sta pnCode
        rts
!as3:   lda pnCurrent            // slot 11 (leeg of overschrijven)
        ldy #0
        sta (pnCPtr),y
        lda #3
        sta pnCode
        rts

//--------------------------------------------------------
// Tabellen
//--------------------------------------------------------
rowLo:    .fill 25, <(i*320)
rowHi:    .fill 25, >(i*320)
mrowLo:   .fill 25, <(i*40)
mrowHi:   .fill 25, >(i*40)
shiftTab: .byte 6, 4, 2, 0       // fatx&3 -> aantal bits schuiven
maskTab:  .byte $c0, $30, $0c, $03

pnCurrent: .byte BLACK
plValid:   .byte 0               // 1 = pen staat op het papier
plX:       .byte 0
plY:       .byte 0
plDx:      .byte 0
plDy:      .byte 0
plSx:      .byte 0
plSy:      .byte 0
plErr:     .byte 0
plCnt:     .byte 0
pnFx:      .byte 0
pnPy:      .byte 0
pnVal:     .byte 0
pnCode:    .byte 0
pnCellRow: .byte 0
pnCellCol: .byte 0
pnMByte:   .byte 0
pnS01:     .byte 0
pnS10:     .byte 0
pnS11:     .byte 0
pnT0:      .byte 0
pnT1:      .byte 0
pnPalSw:   .byte 0
pnPalFx0:  .byte 0
pnPalDx:   .byte 0

//--------------------------------------------------------
// paint_DrawMenuBtn - MENU-knop rechts in de paletbalk (fatx 152-159):
//                     lichtgrijs vlak met drie zwarte streepjes.
//--------------------------------------------------------
paint_DrawMenuBtn: {
        lda #PN_PALTOP
        sta pnPy
y:      lda #152
        sta pnFx
x:      lda #LIGHT_GREY
        ldy pnPy
        cpy #PN_PALTOP+4
        beq ln
        cpy #PN_PALTOP+8
        beq ln
        cpy #PN_PALTOP+12
        bne pl
ln:     ldy pnFx                 // streepje: fatx 153-158
        cpy #153
        bcc pl
        cpy #159
        bcs pl
        lda #BLACK
pl:     sta pnCurrent
        jsr paint_Plot
        inc pnFx
        lda pnFx
        cmp #160
        bne x
        inc pnPy
        lda pnPy
        cmp #200
        bne y
        rts
}

// paint_Key - toets in Paint: M = menu. Carry=1 = afgehandeld.
paint_Key:
        lda evtA
        cmp #13                  // M (toetscodes = schermcodes)
        bne !n+
        jsr paint_Menu
        sec
        rts
!n:     clc
        rts

//--------------------------------------------------------
// paint_Menu - NEW / LOAD / SAVE / PRINT in een gewoon CD64-venster.
//              De tekening blijft in het geheugen staan; alleen het
//              kleuren-RAM (slot 11) moet opzij ($5000), want het
//              tekstscherm gebruikt het ook.
//--------------------------------------------------------
.label PN_CBUF = $5000           // 1000 bytes kleuren-RAM van de tekening
.const PM_ROW  = 7               // knoppenrij
.const PM_NROW = 9               // naamveld
.const PM_MROW = 11              // melding
.const PM_BROW = 14              // BACK

paint_Menu: {
        ldx #0                   // kleuren-RAM opzij
cs:     lda COLOR_RAM,x
        sta PN_CBUF,x
        lda COLOR_RAM+$100,x
        sta PN_CBUF+$100,x
        lda COLOR_RAM+$200,x
        sta PN_CBUF+$200,x
        lda COLOR_RAM+$300,x
        sta PN_CBUF+$300,x
        inx
        bne cs
        jsr paint_Exit           // tekstscherm (paintSpace = 0)
        lda #0
        sta pnMsg+1
draw:   jsr pm_Draw
        jmp wait
bk:     jmp back
wait:   jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        beq click
        cmp #EVT_KEY
        bne wait
        lda evtA
        cmp #$82                 // ESC / RUN/STOP = terug naar de tekening
        beq bk
        cmp #$20
        beq kc
        cmp #$80
        bne wait
kc:     jsr cursorToCell
click:  lda evtB
        cmp #5                   // sluitknop van het venster
        bne nc
        lda evtA
        cmp #35
        beq bk
nc:     ldx #0                   // NEW, LOAD, SAVE, PRINT
bl:     stx pmI
        lda pmCol,x
        sta a0
        lda #PM_ROW
        sta a1
        lda pmW,x
        sta a2
        jsr btn_HitTest
        bcs btn
        ldx pmI
        inx
        cpx #4
        bne bl
        lda #6                   // BACK
        sta a0
        lda #PM_BROW
        sta a1
        lda #6
        sta a2
        jsr btn_HitTest
        bcs bk
        lda evtB                 // naamveld
        cmp #PM_NROW
        bne wait
        lda evtA
        cmp #11
        bcc wait
        jsr pm_NameField
        jsr li_Edit
        bcc wait
        jmp click
btn:    lda #0
        sta pnMsg+1
        lda pmI
        bne b1
        jsr pn_New               // NEW
        ldx #<sPmNew
        ldy #>sPmNew
        jmp msg
b1:     cmp #3
        beq pr
        lda pnName               // LOAD / SAVE: eerst een naam
        cmp #$ff
        bne hn
        ldx #<sPmAsk
        ldy #>sPmAsk
        stx pnMsg
        sty pnMsg+1
        jsr pm_Msg
        jsr pm_NameField
        jsr li_Edit
        lda #0
        sta pnMsg+1
        lda pnName
        cmp #$ff
        bne hn
        jmp draw
hn:     lda pmI
        cmp #1
        bne sv
        jsr pn_Load
        jmp msg
sv:     jsr pn_Save
        jmp msg
pr:     ldx #<sPmPrinting        // PRINT
        ldy #>sPmPrinting
        stx pnMsg
        sty pnMsg+1
        jsr pm_Msg
        jsr pn_Print
msg:    stx pnMsg
        sty pnMsg+1
        jmp draw
back:   ldx #0                   // paletbalk (rij 23-24) leeg: een geladen
        lda #0                   // plaatje heeft daar eigen kleuren
cb:     sta BITMAP+7360,x        // bitmap 7360-7999 (640 bytes)
        sta BITMAP+7360+256,x
        inx
        bne cb
        ldx #127
cc:     sta BITMAP+7360+512,x
        dex
        bpl cc
        ldx #79                  // matrix en kleuren: cel 920-999
cm:     lda #PN_MINIT
        sta VMATRIX+920,x
        lda #PN_BG
        sta PN_CBUF+920,x
        dex
        bpl cm
        ldx #0                   // kleuren-RAM terug, bitmapmodus aan
cr:     lda PN_CBUF,x
        sta COLOR_RAM,x
        lda PN_CBUF+$100,x
        sta COLOR_RAM+$100,x
        lda PN_CBUF+$200,x
        sta COLOR_RAM+$200,x
        lda PN_CBUF+$300,x
        sta COLOR_RAM+$300,x
        inx
        bne cr
        jsr pn_Video
        jsr paint_DrawPalette    // (na NEW / LOAD: de balk opnieuw)
        jsr paint_DrawEraser
        jsr paint_DrawMenuBtn
        lda #1
        sta paintSpace
        lda #0
        sta plValid
        lda #BLACK
        sta pnCurrent
        rts
}

// pm_Draw - het menuvenster.
pm_Draw: {
        lda TH_deskbg
        sta a2
        jsr gfx_Cls
        lda #<sPmTitle
        sta r0
        lda #>sPmTitle
        sta r0+1
        lda #4
        sta a0
        lda #5
        sta a1
        lda #32
        sta a2
        lda #12
        sta a3
        jsr dlg_Draw             // rijen 5-16
        ldx #0
bl:     stx pmI
        lda pmLo,x
        sta r0
        lda pmHi,x
        sta r0+1
        lda pmCol,x
        sta a0
        lda #PM_ROW
        sta a1
        lda pmW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx pmI
        inx
        cpx #4
        bne bl
        lda #<sPmBack
        sta r0
        lda #>sPmBack
        sta r0+1
        lda #6
        sta a0
        lda #PM_BROW
        sta a1
        lda #6
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sPmName
        sta r0
        lda #>sPmName
        sta r0+1
        lda #6
        sta a0
        lda #PM_NROW
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        lda #<sPmHint
        sta r0
        lda #>sPmHint
        sta r0+1
        lda #13
        sta a0
        lda #PM_BROW
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        jsr pm_NameField
        lda #0
        sta liOn
        jsr li_Show
        jmp pm_Msg
}

pm_NameField:
        lda #<pnName
        sta r3
        lda #>pnName
        sta r3+1
        lda #16
        sta liMax
        sta liVis
        lda #11
        sta liCol
        lda #PM_NROW
        sta liRow
        rts

// pm_Msg - meldingsregel (pnMsg, 0 = leeg).
pm_Msg: {
        lda #6
        sta a0
        lda #PM_MROW
        sta a1
        lda #28
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda pnMsg+1
        beq r
        sta r0+1
        lda pnMsg
        sta r0
        lda #6
        sta a0
        lda #PM_MROW
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
r:      rts
}

//--------------------------------------------------------
// pn_Clear - lege tekening: bitmap, matrix en (bewaard) kleuren-RAM.
//            X/Y wijzen naar het kleuren-RAM of naar PN_CBUF.
//--------------------------------------------------------
pn_Clear: {
        stx pnCPtr
        sty pnCPtr+1
        lda #<BITMAP
        sta pnPtr
        lda #>BITMAP
        sta pnPtr+1
        ldx #$20
        lda #0
        ldy #0
pg:     sta (pnPtr),y
        iny
        bne pg
        inc pnPtr+1
        dex
        bne pg
        ldx #4
m:      lda #PN_MINIT            // matrix en kleuren (4 pagina's)
        sta VMATRIX-$400+$400,y
        sta VMATRIX+$100,y
        sta VMATRIX+$200,y
        sta VMATRIX+$300,y
        lda #PN_BG
        sta (pnCPtr),y
        iny
        bne m
        inc pnCPtr+1
        dex
        bne m
        rts
}

// pn_New - lege tekening (vanuit het menu: kleuren in PN_CBUF).
pn_New:
        ldx #<PN_CBUF
        ldy #>PN_CBUF
        jmp pn_Clear

// pn_Video - multicolor-bitmapmodus aan (tekening staat al klaar).
pn_Video:
        lda #PN_BG
        sta BG_COL0
        lda #BLACK
        sta BORDER_COL
        ldx #0                   // cursor-sprite in bank 1: $4400 (blok 16)
!sp:    lda arrowData,x
        sta $4400,x
        inx
        cpx #63
        bne !sp-
        lda #16
        sta $43f8
        lda #BLACK
        sta SPR0_COL
        lda CIA2_PRA             // VIC-bank 1 ($4000-$7FFF)
        and #$fc
        ora #%10
        sta CIA2_PRA
        lda #$08                 // matrix $4000, bitmap $6000
        sta VIC_MEM
        lda #$3b                 // bitmap, DEN, 25 rijen (VASTE waarden)
        sta VIC_CTRL1
        lda #$d8                 // multicolor aan, 40 kolommen
        sta VIC_CTRL2
        rts

//--------------------------------------------------------
// Bestanden: Koala Painter (PRG, laadadres $6000, 10003 bytes):
//   8000 bitmap, 1000 matrix, 1000 kleuren-RAM, 1 achtergrond.
// SAVE schrijft de paletbalk (rij 23-24) als lege achtergrond.
//--------------------------------------------------------
pn_Save: {
        jsr pn_NameP
        ldx #0                   // "@0:" + naam + ",P,W"
        ldy #0
p1:     lda pre,x
        sta pnCmd,y
        iny
        inx
        cpx #3
        bne p1
        ldx #0
p2:     cpx pnPLen
        bcs p3
        lda pnPName,x
        sta pnCmd,y
        iny
        inx
        bne p2
p3:     ldx #0
p4:     lda suf,x
        sta pnCmd,y
        iny
        inx
        cpx #4
        bne p4
        tya
        ldx #<pnCmd
        ldy #>pnCmd
        jsr pn_OpenF
        bcs out
        ldx #2
        jsr K_CHKOUT
        bcs out
        lda #$00                 // laadadres $6000
        jsr K_CHROUT
        lda #$60
        jsr K_CHROUT
        lda #<BITMAP             // bitmap: 7360 echt, rest (palet) leeg
        ldx #>BITMAP
        jsr pn_SetP
        lda #<7360
        ldx #>7360
        ldy #<8000
        jsr pn_SetN
        lda #>8000
        sta pnTot+1
        lda #0
        jsr pn_Out
        lda #<VMATRIX            // matrix: 920 echt
        ldx #>VMATRIX
        jsr pn_SetP
        lda #<920
        ldx #>920
        ldy #<1000
        jsr pn_SetN
        lda #>1000
        sta pnTot+1
        lda #PN_MINIT
        jsr pn_Out
        lda #<PN_CBUF            // kleuren: 920 echt
        ldx #>PN_CBUF
        jsr pn_SetP
        lda #<920
        ldx #>920
        ldy #<1000
        jsr pn_SetN
        lda #>1000
        sta pnTot+1
        lda #PN_BG
        jsr pn_Out
        lda #PN_BG               // achtergrond
        jsr K_CHROUT
out:    jsr pn_CloseF
        lda #$ff
        sta pnSaved
        jmp pn_Result
pre:    .byte $40, $30, $3a      // @0:
suf:    .byte $2c, $50, $2c, $57 // ,P,W
}

pn_Load: {
        jsr pn_NameP
        lda pnPLen
        ldx #<pnPName
        ldy #>pnPName
        jsr pn_OpenF
        bcs out
        ldx #2
        jsr K_CHKIN
        bcs out
        jsr K_CHRIN              // laadadres overslaan
        jsr K_CHRIN
        lda #<BITMAP
        ldx #>BITMAP
        jsr pn_SetP
        lda #<8000
        ldx #>8000
        jsr pn_In
        bcs short
        lda #<VMATRIX
        ldx #>VMATRIX
        jsr pn_SetP
        lda #<1000
        ldx #>1000
        jsr pn_In
        bcs short
        lda #<PN_CBUF
        ldx #>PN_CBUF
        jsr pn_SetP
        lda #<1000
        ldx #>1000
        jsr pn_In
        bcs short
out:    jsr pn_CloseF
        lda #0
        sta pnSaved
        jmp pn_Result
short:  jsr pn_CloseF            // te kort: geen Koala-plaatje (of fout)
        lda pnDev
        jsr dsk_Status
        bcs nk
        lda dsCode
        cmp #20
        bcc nk
        ldx #<dsText
        ldy #>dsText
        rts
nk:     ldx #<sPmNoKoala
        ldy #>sPmNoKoala
        rts
}

// pn_OpenF - bestand (A = lengte, X/Y = naam) openen als kanaal 2.
pn_OpenF:
        pha
        txa
        pha
        tya
        pha
        jsr cfg_io_begin
        pla
        tay
        pla
        tax
        pla
        jsr K_SETNAM
        lda #2
        ldx pnDev
        ldy #2
        jsr K_SETLFS
        lda #0
        sta $90
        jmp K_OPEN

pn_CloseF:
        jsr K_CLRCHN
        lda #2
        jsr K_CLOSE
        jmp cfg_io_end

pn_SetP:
        sta pnPtr
        stx pnPtr+1
        rts
// pn_SetN - pnKeep = A/X (echte bytes), pnTot = Y/(pnTot+1 los).
pn_SetN:
        sta pnKeep
        stx pnKeep+1
        sty pnTot
        rts

// pn_Out - pnTot bytes: de eerste pnKeep uit (pnPtr), daarna A.
pn_Out: {
        sta pnFill
        lda #0
        sta pnCnt
        sta pnCnt+1
lp:     lda pnCnt
        cmp pnTot
        lda pnCnt+1
        sbc pnTot+1
        bcs r
        lda pnCnt
        cmp pnKeep
        lda pnCnt+1
        sbc pnKeep+1
        lda pnFill
        bcs o
        ldy #0
        lda (pnPtr),y
o:      jsr K_CHROUT
        inc pnPtr
        bne i
        inc pnPtr+1
i:      inc pnCnt
        bne lp
        inc pnCnt+1
        jmp lp
r:      rts
}

// pn_In - A/X bytes lezen naar (pnPtr). Carry=1: bestand te kort / fout.
pn_In: {
        sta pnTot
        stx pnTot+1
lp:     lda pnTot
        ora pnTot+1
        beq ok
        lda $90
        bne bad
        jsr K_CHRIN
        ldy #0
        sta (pnPtr),y
        inc pnPtr
        bne d
        inc pnPtr+1
d:      lda pnTot
        bne d2
        dec pnTot+1
d2:     dec pnTot
        jmp lp
ok:     clc
        rts
bad:    sec
        rts
}

// pn_Result - melding na LOAD / SAVE (X/Y).
pn_Result: {
        lda pnDev
        jsr dsk_Status
        bcs nodrv
        lda dsCode
        cmp #20
        bcs err
        ldx #<sPmLoaded
        ldy #>sPmLoaded
        lda pnSaved
        beq r
        ldx #<sPmSaved
        ldy #>sPmSaved
r:      rts
err:    ldx #<dsText
        ldy #>dsText
        rts
nodrv:  ldx #<sPmNoDrv
        ldy #>sPmNoDrv
        rts
}

// pn_NameP - pnName (schermcodes) -> pnPName (PETSCII), pnPLen.
pn_NameP: {
        ldx #0
lp:     lda pnName,x
        cmp #$ff
        beq e
        cmp #$00
        bne nl
        lda #$40
        bne s
nl:     cmp #$1b
        bcs s
        ora #$40                 // A-Z
s:      sta pnPName,x
        inx
        cpx #16
        bne lp
e:      stx pnPLen
        rts
}

//--------------------------------------------------------
// pn_Print - de tekening (zonder paletbalk) naar de printer.
//--------------------------------------------------------
pn_Print: {
        lda #<pn_Ink
        sta pnPr.prPixV
        lda #>pn_Ink
        sta pnPr.prPixV+1
        jsr pnPr.pr_Open
        bcs r
        jsr pnPr.pr_Picture
        bcs fail
        jsr pnPr.pr_Close
        bcs r
        ldx #<sPmPrinted
        ldy #>sPmPrinted
r:      rts
fail:   jmp pnPr.pr_Shut
}

// pn_Ink - dikke pixel (prX, prY) is inkt (carry=1) als hij niet de
//          achtergrondkleur heeft. Kleuren-RAM uit PN_CBUF.
pn_Ink: {
        lda pnPr.prY
        lsr
        lsr
        lsr
        tay                      // celrij
        lda pnPr.prX             // bitmap: rij*320 + (x/4)*8 + (y&7)
        and #$fc
        asl
        sta pnPtr
        lda #0
        rol
        sta pnPtr+1
        lda pnPtr
        clc
        adc rowLo,y
        sta pnPtr
        lda pnPtr+1
        adc rowHi,y
        sta pnPtr+1
        lda pnPtr
        clc
        adc #<BITMAP
        sta pnPtr
        lda pnPtr+1
        adc #>BITMAP
        sta pnPtr+1
        lda pnPr.prY
        and #7
        sta pnIy
        lda pnPr.prX
        and #3
        tax
        lda shiftTab,x
        tax
        sty pnIr
        ldy pnIy
        lda (pnPtr),y
sh:     cpx #0
        beq sd
        lsr
        dex
        jmp sh
sd:     and #3
        beq no                   // 00 = achtergrond
        sta pnIc
        ldy pnIr                 // cel = rij*40 + x/4
        lda pnPr.prX
        lsr
        lsr
        clc
        adc mrowLo,y
        sta pnIx
        lda mrowHi,y
        adc #0
        sta pnIx+1
        lda pnIc
        cmp #3
        beq cr
        lda pnIx                 // matrix
        clc
        adc #<VMATRIX
        sta pnMPtr
        lda pnIx+1
        adc #>VMATRIX
        sta pnMPtr+1
        ldy #0
        lda (pnMPtr),y
        ldx pnIc
        cpx #1
        bne lo
        lsr
        lsr
        lsr
        lsr
lo:     and #$0f
        jmp cmpc
cr:     lda pnIx                 // kleuren-RAM (bewaard)
        clc
        adc #<PN_CBUF
        sta pnMPtr
        lda pnIx+1
        adc #>PN_CBUF
        sta pnMPtr+1
        ldy #0
        lda (pnMPtr),y
        and #$0f
cmpc:   cmp #PN_BG
        beq no
        sec
        rts
no:     clc
        rts
}

pmI:      .byte 0
pnMsg:    .word 0
pnDev:    .byte 8
pnSaved:  .byte 0
pnPLen:   .byte 0
pnKeep:   .word 0
pnTot:    .word 0
pnCnt:    .word 0
pnFill:   .byte 0
pnIx:     .word 0
pnIy:     .byte 0
pnIr:     .byte 0
pnIc:     .byte 0
pnName:   .fill 17, $ff
pnPName:  .fill 16, 0
pnCmd:    .fill 24, 0
pmLo:     .byte <sPmNew0, <sPmLoad, <sPmSave, <sPmPrint
pmHi:     .byte >sPmNew0, >sPmLoad, >sPmSave, >sPmPrint
pmCol:    .byte 6, 12, 19, 26
pmW:      .byte 5, 6, 6, 7

pnPr: PrinterDriver()

.encoding "screencode_upper"
sPmTitle:   .text "PAINT"
            .byte $ff
sPmNew0:    .text "NEW"
            .byte $ff
sPmLoad:    .text "LOAD"
            .byte $ff
sPmSave:    .text "SAVE"
            .byte $ff
sPmPrint:   .text "PRINT"
            .byte $ff
sPmBack:    .text "BACK"
            .byte $ff
sPmName:    .text "NAME"
            .byte $ff
sPmHint:    .text "(KEY M = MENU)"
            .byte $ff
sPmAsk:     .text "TYPE A FILE NAME, THEN RETURN"
            .byte $ff
sPmNew:     .text "NEW PICTURE"
            .byte $ff
sPmSaved:   .text "SAVED (KOALA PAINTER)"
            .byte $ff
sPmLoaded:  .text "LOADED"
            .byte $ff
sPmNoKoala: .text "NOT A KOALA PICTURE"
            .byte $ff
sPmNoDrv:   .text "NO DRIVE"
            .byte $ff
sPmPrinting: .text "PRINTING... (RUN/STOP = STOP)"
            .byte $ff
sPmPrinted: .text "PRINTED"
            .byte $ff
