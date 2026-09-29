#importonce
//========================================================
// apps/editor.asm - Text Editor
// Commodore Desk 64
//
// Tekst van tot ED_MAXL regels van ED_W tekens (werkgeheugen $4000).
// Werkbalk: NEW, LOAD, SAVE, PRINT en de bestandsnaam (klik om te typen).
// PRINT gaat naar de printer van het PRINT-icoon (apps/printer_drv.asm).
// Typen voegt in; RETURN splitst de regel, DEL wist links van de cursor
// (aan het begin: regels samen), cursortoetsen, HOME / CLR (SHIFT).
// LOAD leest elk bestand als tekst (PETSCII, CR = nieuwe regel), SAVE
// schrijft een SEQ-bestand; fouten van de drive worden getoond.
// De File Manager kan een bestand klaarzetten (fileReq/fileDev/fileName).
//========================================================

.const ED_W    = 36              // regelbreedte (kolom 2-37)
.const ED_MAXL = 200
.const ED_VIS  = 19              // zichtbare regels (rij 3-21)
.const ED_TOP  = 3
.const ED_MSG  = 22
.const ED_NCOL = 31              // naamveld (7 zichtbaar, schuift)
.label ED_BUF  = $4000           // ED_MAXL * ED_W = 7200 bytes
.label edPtr   = $3a             // zeropage-pointers
.label edPtr2  = $3c

ed_Init: {
        lda #0
        sta edMsg+1
        lda fileReq              // bestand uit de File Manager?
        beq new
        lda #0
        sta fileReq
        lda fileDev
        sta edDev
        ldx #0                   // naam PETSCII -> schermcodes
nm:     cpx fileLen
        bcs ne
        lda fileName,x
        jsr ed_P2S
        sta edName,x
        inx
        cpx #16
        bne nm
ne:     lda #$ff
        sta edName,x
        jsr ed_Clear
        lda fileSkip
        sta edSkip
        jmp ed_Load
new:    lda #8
        sta edDev
        lda #$ff
        sta edName
        jmp ed_Clear
}

// ed_Clear - lege tekst, cursor linksboven.
ed_Clear: {
        lda #0
        sta edX
        sta edY
        sta edTop
        sta edSkip
        lda #<ED_BUF
        sta edPtr
        lda #>ED_BUF
        sta edPtr+1
        ldx #>[ED_MAXL*ED_W]+1
        ldy #0
        lda #$20
lp:     sta (edPtr),y
        iny
        bne lp
        inc edPtr+1
        dex
        bne lp
        rts
}

// ed_LinePtr - edPtr = regel A.
ed_LinePtr: {
        sta edT
        lda #0
        sta edPtr+1
        lda edT                  // *36 = *32 + *4
        asl
        rol edPtr+1
        asl
        rol edPtr+1
        sta edPtr
        lda edPtr+1
        sta edT+1
        lda edPtr                // (*4 bewaard in edT2)
        sta edT2
        asl
        rol edPtr+1
        asl
        rol edPtr+1
        asl
        rol edPtr+1
        clc
        adc edT2
        sta edPtr
        lda edPtr+1
        adc edT+1
        sta edPtr+1
        lda edPtr
        clc
        adc #<ED_BUF
        sta edPtr
        lda edPtr+1
        adc #>ED_BUF
        sta edPtr+1
        rts
}

// ed_LineLen - Y = lengte van regel A zonder spaties achteraan (edPtr gezet).
ed_LineLen: {
        jsr ed_LinePtr
        ldy #ED_W
lp:     dey
        bmi z
        lda (edPtr),y
        cmp #$20
        beq lp
        iny
        rts
z:      ldy #0
        rts
}

//--------------------------------------------------------
// ed_Draw - werkbalk, naam, tekst, melding.
//--------------------------------------------------------
ed_Draw: {
        lda #1                   // toetsenbord ruw: cursortoetsen, @
        sta kbRaw
        ldx #0
bl:     stx edI
        lda edBtnLo,x
        sta r0
        lda edBtnHi,x
        sta r0+1
        lda edBtnCol,x
        sta a0
        lda #2
        sta a1
        lda edBtnW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx edI
        inx
        cpx #4
        bne bl
        lda #<sEdName
        sta r0
        lda #>sEdName
        sta r0+1
        lda #ED_NCOL-5
        sta a0
        lda #2
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        jsr ed_NameField
        lda #0
        sta liOn
        jsr li_Show
        jsr ed_Lines
        jmp ed_ShowMsg
}

ed_NameField:
        lda #<edName
        sta r3
        lda #>edName
        sta r3+1
        lda #16
        sta liMax
        lda #ED_NCOL
        sta liCol
        lda #2
        sta liRow
        lda #7
        sta liVis
        rts

// ed_Lines - zichtbare regels + cursor tekenen.
ed_Lines: {
        lda edY                  // scrollen zodat de cursor zichtbaar is
        cmp edTop
        bcs la
        sta edTop
la:      lda edTop
        clc
        adc #ED_VIS-1
        cmp edY
        bcs lb
        lda edY
        sec
        sbc #ED_VIS-1
        sta edTop
lb:      lda #0
        sta edI
lp:     lda edI
        clc
        adc edTop
        jsr ed_LinePtr
        lda edI
        clc
        adc #ED_TOP
        tax
        lda screenLo,x           // schermregel, kolom 2
        clc
        adc #2
        sta edPtr2
        lda screenHi,x
        adc #0
        sta edPtr2+1
        ldy #ED_W-1
cp:     lda (edPtr),y
        jsr sc_Disp
        sta (edPtr2),y
        dey
        bpl cp
        lda edPtr2+1             // kleur
        clc
        adc #>[COLOR_RAM-SCREEN_RAM]
        sta edPtr2+1
        ldy #ED_W-1
        lda TH_text
cc:     sta (edPtr2),y
        dey
        bpl cc
        inc edI
        lda edI
        cmp #ED_VIS
        bcc lp
        lda edY                  // cursor
        jsr ed_LinePtr
        ldy edX
        lda (edPtr),y
        jsr sc_Disp
        jsr gfx_CurChar          // cursor (STONE: zonder omgekeerde tekens)
        sta a2
        lda edX
        clc
        adc #2
        sta a0
        lda edY
        sec
        sbc edTop
        clc
        adc #ED_TOP
        sta a1
        lda TH_accent
        sta a3
        jmp gfx_PutChar
}

// ed_ShowMsg - meldingsregel.
ed_ShowMsg: {
        lda #2
        sta a0
        lda #ED_MSG
        sta a1
        lda #ED_W
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda edMsg+1
        beq r
        sta r0+1
        lda edMsg
        sta r0
        lda #2
        sta a0
        lda #ED_MSG
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
r:      rts
}

//--------------------------------------------------------
// ed_Click - werkbalk, naamveld of tekst.
//--------------------------------------------------------
ed_Click: {
        ldx #0
bl:     stx edI
        lda edBtnCol,x
        sta a0
        lda #2
        sta a1
        lda edBtnW,x
        sta a2
        jsr btn_HitTest
        bcs btn
        ldx edI
        inx
        cpx #4
        bne bl
        lda evtB
        cmp #2
        bne tx
        lda evtA                 // naamveld
        cmp #ED_NCOL
        bcc r
        jsr ed_NameField
        jsr li_Edit
        bcc r
        jmp ed_Click
tx:     sec                      // in de tekst: cursor erheen
        sbc #ED_TOP
        bcc r
        cmp #ED_VIS
        bcs r
        clc
        adc edTop
        sta edY
        lda evtA
        sec
        sbc #2
        bcc r
        cmp #ED_W
        bcs r
        sta edX
        jmp ed_Lines
r:      rts
btn:    lda #0
        sta edMsg+1
        lda edI
        bne b1
        jsr ed_Clear             // NEW
        lda #$ff
        sta edName
        jmp shell_DrawAll
b1:     cmp #1
        bne b2
        lda edName               // LOAD: eerst een naam
        cmp #$ff
        bne ld
        jsr ed_AskName
        bcc r
ld:     jsr ed_Clear
        jsr ed_Load
        jmp shell_DrawAll
b2:     cmp #2
        bne b3
        lda edName               // SAVE
        cmp #$ff
        bne sv
        jsr ed_AskName
        bcc r
sv:     jsr ed_Save
        jmp shell_DrawAll
b3:     jsr ed_Print             // PRINT
        jmp shell_DrawAll
}

// ed_Print - de tekst (t/m de laatste niet-lege regel) naar de printer.
ed_Print: {
        ldx #<sEdPrinting
        ldy #>sEdPrinting
        stx edMsg
        sty edMsg+1
        jsr ed_ShowMsg
        lda #ED_MAXL             // laatste niet-lege regel
        sta edJ
fl:     dec edJ
        lda edJ
        cmp #$ff
        beq em
        jsr ed_LineLen
        cpy #0
        beq fl
em:     inc edJ
        jsr edPr.pr_Open
        bcs msg
        lda #0
        sta edI
ln:     lda edI
        cmp edJ
        bcs done
        jsr ed_LineLen
        lda edPtr
        sta r6
        lda edPtr+1
        sta r6+1
        jsr edPr.pr_Line
        bcs fail
        inc edI
        jmp ln
fail:   jsr edPr.pr_Shut
        jmp msg
done:   jsr edPr.pr_Close
        bcs msg
        ldx #<sEdPrinted
        ldy #>sEdPrinted
msg:    stx edMsg
        sty edMsg+1
        rts
}

// ed_AskName - naam laten typen. Carry=1 als er een naam is.
ed_AskName: {
        ldx #<sEdAsk
        ldy #>sEdAsk
        stx edMsg
        sty edMsg+1
        jsr ed_ShowMsg
        jsr ed_NameField
        jsr li_Edit
        lda #0
        sta edMsg+1
        jsr ed_ShowMsg
        lda edName
        cmp #$ff
        beq no
        sec
        rts
no:     clc
        rts
}

//--------------------------------------------------------
// ed_Key - toets (vanuit de shell, evtA/evtB).
//--------------------------------------------------------
ed_Key: {
        lda evtB
        sta edMods
        lda evtA
        cmp #KEY_RETURN
        bne k1
        jsr ed_Return
        jmp ed_Lines
k1:     cmp #KEY_DEL
        bne k2
        jsr ed_Del
        jmp ed_Lines
k2:     cmp #KEY_CRSR_R
        bne k3
        lda edMods
        and #KM_SHIFT
        bne left
        lda edX
        cmp #ED_W-1
        bcs r
        inc edX
        jmp ed_Lines
left:   lda edX
        beq r
        dec edX
        jmp ed_Lines
k3:     cmp #KEY_CRSR_D
        bne k4
        lda edMods
        and #KM_SHIFT
        bne up
        lda edY
        cmp #ED_MAXL-1
        bcs r
        inc edY
        jmp ed_Lines
up:     lda edY
        beq r
        dec edY
        jmp ed_Lines
k4:     cmp #KEY_HOME
        bne k5
        lda #0
        sta edX
        lda edMods
        and #KM_SHIFT
        beq hm
        lda #0
        sta edY
hm:     jmp ed_Lines
k5:     cmp #KEY_AT              // @
        bne k6
        lda #0
        jmp ins
k6:     cmp #KEY_LARROW          // _
        bne k7
        lda #$64
        jmp ins
k7:     cmp #$80                 // andere speciale toetsen: niets
        bcs r
        cmp #$1c
        beq r
        cmp #$1e
        bcc ins
        cmp #$20
        bcc r
        cmp #$40
        bcc ins
        beq r
        cmp #$5b
        bcs r
ins:    jsr ed_Ins
        jmp ed_Lines
r:      rts
}

// ed_Ins - teken A invoegen op de cursor.
ed_Ins: {
        pha
        lda edY
        jsr ed_LinePtr
        ldy #ED_W-1
sh:     cpy edX
        beq put
        dey
        lda (edPtr),y
        iny
        sta (edPtr),y
        dey
        jmp sh
put:    pla
        sta (edPtr),y
        inc edX
        lda edX
        cmp #ED_W
        bcc r
        lda edY                  // regel vol: volgende regel
        cmp #ED_MAXL-1
        bcs last
        inc edY
        lda #0
        sta edX
        rts
last:   dec edX
r:      rts
}

// ed_Del - teken links van de cursor weg; aan het begin: regels samen.
ed_Del: {
        lda edX
        beq join
        dec edX
        lda edY
        jsr ed_LinePtr
        ldy edX
sh:     cpy #ED_W-1
        bcs e
        iny
        lda (edPtr),y
        dey
        sta (edPtr),y
        iny
        jmp sh
e:      lda #$20
        sta (edPtr),y
        rts
join:   lda edY
        beq r
        sec
        sbc #1
        jsr ed_LineLen           // lengte vorige regel
        sty edJ
        lda edY
        jsr ed_LineLen
        tya
        clc
        adc edJ
        cmp #ED_W+1
        bcs mv                   // past niet: alleen de cursor
        lda edY                  // huidige regel achter de vorige
        jsr ed_LinePtr
        lda edPtr
        sta edPtr2
        lda edPtr+1
        sta edPtr2+1
        lda edY
        sec
        sbc #1
        jsr ed_LinePtr
        ldx edJ
        ldy #0
jc:     cpx #ED_W
        bcs jd
        lda (edPtr2),y
        sty edI
        pha
        txa
        tay
        pla
        sta (edPtr),y
        ldy edI
        inx
        iny
        bne jc
jd:     lda edY
        jsr ed_Remove
        dec edY
        lda edJ
        sta edX
        rts
mv:     dec edY
        lda edJ
        cmp #ED_W
        bcc m1
        lda #ED_W-1
m1:     sta edX
r:      rts
}

// ed_Return - regel splitsen op de cursor.
ed_Return: {
        lda edY
        cmp #ED_MAXL-1
        bcs r
        clc
        adc #1
        jsr ed_Insert            // lege regel eronder
        lda edY
        jsr ed_LinePtr
        lda edPtr
        sta edPtr2
        lda edPtr+1
        sta edPtr2+1
        lda edY
        clc
        adc #1
        jsr ed_LinePtr
        ldy edX
        ldx #0
cp:     cpy #ED_W
        bcs d
        lda (edPtr2),y
        pha
        lda #$20
        sta (edPtr2),y
        sty edI
        txa
        tay
        pla
        sta (edPtr),y
        ldy edI
        inx
        iny
        bne cp
d:      inc edY
        lda #0
        sta edX
r:      rts
}

// ed_Insert - lege regel A invoegen (de laatste valt weg).
ed_Insert: {
        sta edJ
        lda #ED_MAXL-1
        sta edI
lp:     lda edI
        cmp edJ
        beq clr
        sec
        sbc #1
        jsr ed_LinePtr           // bron = regel i-1
        lda edPtr
        sta edPtr2
        lda edPtr+1
        sta edPtr2+1
        lda edI
        jsr ed_LinePtr
        ldy #ED_W-1
c:      lda (edPtr2),y
        sta (edPtr),y
        dey
        bpl c
        dec edI
        jmp lp
clr:    lda edJ
        jsr ed_LinePtr
        ldy #ED_W-1
        lda #$20
cl:     sta (edPtr),y
        dey
        bpl cl
        rts
}

// ed_Remove - regel A verwijderen (onderaan een lege regel).
ed_Remove: {
        sta edI
lp:     lda edI
        cmp #ED_MAXL-1
        bcs clr
        clc
        adc #1
        jsr ed_LinePtr           // bron = regel i+1
        lda edPtr
        sta edPtr2
        lda edPtr+1
        sta edPtr2+1
        lda edI
        jsr ed_LinePtr
        ldy #ED_W-1
c:      lda (edPtr2),y
        sta (edPtr),y
        dey
        bpl c
        inc edI
        jmp lp
clr:    lda #ED_MAXL-1
        jsr ed_LinePtr
        ldy #ED_W-1
        lda #$20
cl:     sta (edPtr),y
        dey
        bpl cl
        rts
}

//--------------------------------------------------------
// ed_Load - bestand edName van edDev als tekst inlezen.
//--------------------------------------------------------
ed_Load: {
        jsr ed_NameP             // -> edPName/edPLen
        jsr cfg_io_begin
        lda edPLen
        ldx #<edPName
        ldy #>edPName
        jsr K_SETNAM
        lda #2
        ldx edDev
        ldy #2
        jsr K_SETLFS
        lda #0
        sta $90
        jsr K_OPEN
        bcc fb4340_0
        jmp fail
fb4340_0:
        ldx #2
        jsr K_CHKIN
        bcs fail
        lda #0
        sta edX
        sta edY
        lda edSkip               // PRG: laadadres overslaan
        beq rd
        jsr K_CHRIN
        jsr K_CHRIN
rd:     lda $90
        bne done
        jsr K_CHRIN
        ldx $90                  // status (EOF / fout) bewaren
        stx edSt
        cmp #$0d
        beq nl
        cmp #$0a
        beq nx
        jsr ed_P2S
        pha
        lda edY
        jsr ed_LinePtr
        pla
        ldy edX
        sta (edPtr),y
        inc edX
        lda edX
        cmp #ED_W
        bcc nx
nl:     lda #0
        sta edX
        inc edY
        lda edY
        cmp #ED_MAXL
        bcs full
nx:     lda edSt
        beq rd
done:   jsr close
        lda #0
        sta edX
        sta edY
        sta edTop
        jmp ed_Result
full:   jsr close
        lda #0
        sta edX
        sta edY
        sta edTop
        ldx #<sEdLong
        ldy #>sEdLong
        stx edMsg
        sty edMsg+1
        rts
fail:   jsr close
        jmp ed_Result
close:  jsr K_CLRCHN
        lda #2
        jsr K_CLOSE
        jmp cfg_io_end
}

// ed_Save - tekst als SEQ-bestand "@0:naam,S,W" op edDev.
ed_Save: {
        lda #ED_MAXL             // laatste niet-lege regel zoeken
        sta edJ
fl:     dec edJ
        lda edJ
        cmp #$ff
        beq em
        jsr ed_LineLen
        cpy #0
        beq fl
em:     inc edJ                  // aantal regels
        jsr ed_NameP
        ldx #0                   // "@0:" + naam + ",S,W"
        ldy #0
p1:     lda pre,x
        sta edCmd,y
        iny
        inx
        cpx #3
        bne p1
        ldx #0
p2:     cpx edPLen
        bcs p3
        lda edPName,x
        sta edCmd,y
        iny
        inx
        bne p2
p3:     ldx #0
p4:     lda suf,x
        sta edCmd,y
        iny
        inx
        cpx #4
        bne p4
        sty edT
        jsr cfg_io_begin
        lda edT
        ldx #<edCmd
        ldy #>edCmd
        jsr K_SETNAM
        lda #2
        ldx edDev
        ldy #2
        jsr K_SETLFS
        jsr K_OPEN
        bcs out
        ldx #2
        jsr K_CHKOUT
        bcs out
        lda #0
        sta edI
ln:     lda edI
        cmp edJ
        bcs out
        jsr ed_LineLen
        sty edT
        ldy #0
ch:     cpy edT
        bcs eol
        lda (edPtr),y
        jsr ed_S2P
        sty edK
        jsr K_CHROUT
        ldy edK
        iny
        bne ch
eol:    lda #$0d
        jsr K_CHROUT
        inc edI
        jmp ln
out:    jsr K_CLRCHN
        lda #2
        jsr K_CLOSE
        jsr cfg_io_end
        lda #$ff                 // (gelukt: "SAVED" i.p.v. "00, OK")
        sta edT
        jmp ed_Result
pre:    .byte $40, $30, $3a      // @0:
suf:    .byte $2c, $53, $2c, $57 // ,S,W
}

// ed_Result - status van de drive als melding (fout), of "SAVED"/"LOADED".
ed_Result: {
        lda edDev
        jsr dsk_Status
        bcs nodrv
        lda dsCode
        cmp #20
        bcs err
        ldx #<sEdLoaded
        ldy #>sEdLoaded
        lda edT
        cmp #$ff
        bne m
        ldx #<sEdSaved
        ldy #>sEdSaved
m:      stx edMsg
        sty edMsg+1
        rts
err:    ldx #<dsText             // "62,FILE NOT FOUND,00,00"
        ldy #>dsText
        jmp m
nodrv:  ldx #<sEdNoDrv
        ldy #>sEdNoDrv
        jmp m
}

// ed_NameP - edName (schermcodes) -> edPName (PETSCII), edPLen.
ed_NameP: {
        ldx #0
lp:     lda edName,x
        cmp #$ff
        beq e
        jsr ed_S2P
        sta edPName,x
        inx
        cpx #16
        bne lp
e:      stx edPLen
        rts
}

// ed_P2S - PETSCII -> schermcode (letters, SHIFT-letters, tekens).
ed_P2S: {
        cmp #$c1                 // SHIFT-letter -> $41-$5A
        bcc la
        cmp #$db
        bcs q
        and #$7f
        rts
la:      cmp #$a0
        bne lb
        lda #$20
        rts
lb:      cmp #$80
        bcs q
        cmp #$20
        bcc q
        jmp petscii2screen
q:      lda #$2e                 // onbekend teken -> .
        rts
}

// ed_S2P - schermcode -> PETSCII.
ed_S2P: {
        cmp #$00
        bne la
        lda #$40                 // @
        rts
la:      cmp #$1b
        bcs lb
        ora #$40                 // a-z (klein in de kleine-letterset)
        rts
lb:      cmp #$41
        bcc r
        cmp #$5b
        bcs lc
        ora #$80                 // SHIFT-letter
        rts
lc:      cmp #$64
        bne r
        lda #$a4                 // _
r:      rts
}

//--------------------------------------------------------
edX:      .byte 0
edY:      .byte 0
edTop:    .byte 0
edDev:    .byte 8
edSkip:   .byte 0
edMods:   .byte 0
edI:      .byte 0
edJ:      .byte 0
edK:      .byte 0
edSt:     .byte 0
edT:      .word 0
edT2:     .byte 0
edPLen:   .byte 0
edMsg:    .word 0
edName:   .fill 17, $ff
edPName:  .fill 16, 0
edCmd:    .fill 24, 0
edBtnLo:  .byte <sEdNew, <sEdLoad, <sEdSave, <sEdPrint
edBtnHi:  .byte >sEdNew, >sEdLoad, >sEdSave, >sEdPrint
edBtnCol: .byte 2, 7, 13, 19
edBtnW:   .byte 5, 6, 6, 7

edPr: PrinterDriver()

.encoding "screencode_upper"
sEdNew:    .text "NEW"
           .byte $ff
sEdLoad:   .text "LOAD"
           .byte $ff
sEdSave:   .text "SAVE"
           .byte $ff
sEdPrint:  .text "PRINT"
           .byte $ff
sEdPrinting: .text "PRINTING... (RUN/STOP = STOP)"
           .byte $ff
sEdPrinted: .text "PRINTED"
           .byte $ff
sEdName:   .text "NAME"
           .byte $ff
sEdAsk:    .text "TYPE A FILE NAME, THEN RETURN"
           .byte $ff
sEdSaved:  .text "SAVED"
           .byte $ff
sEdLoaded: .text "LOADED"
           .byte $ff
sEdLong:   .text "THE FILE IS LONGER THAN 200 LINES"
           .byte $ff
sEdNoDrv:  .text "NO DRIVE"
           .byte $ff
