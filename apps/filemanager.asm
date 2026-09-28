#importonce
//========================================================
// apps/filemanager.asm - File Manager (twee vensters, zoals Norton Commander)
// Commodore Desk 64
//
// Elk venster toont de directory van een drive. Drives 8-15 worden
// gezocht (DRIVES / F7 zoekt opnieuw en vraagt het type op met "UI").
//   RUN  / RETURN   PRG starten (op elke drive), .SID in de SID PLAYER,
//                   SEQ/USR en .CFG/.INI/.TXT in de editor
//   EDIT / F3       bestand in de editor openen
//   COPY / F5       naar de drive van het andere venster kopieren
//   DEL  / F8       wissen (vraagt eerst Y/N)
// Cursor op/neer = selectie, links/rechts = ander venster. Klik op de kop
// van een venster = volgende drive; klik nog eens op een bestand = RUN.
// Fouten van de drive worden als melding getoond.
//
// Geheugen: vensters op $C500/$CA00 (niet in het PRG), kopieerbuffer
// $4000-$6FFF.
//========================================================

.const FM_MAX   = 60             // bestanden per venster
.const FM_ENT   = 20             // naam 16, lengte, type, blokken (2)
.const FE_LEN   = 16
.const FE_TYPE  = 17
.const FE_BLK   = 18
.const PN_DEV   = 0              // venster-kop
.const PN_CNT   = 1
.const PN_TOP   = 2
.const PN_SEL   = 3
.const PN_FREE  = 4              // 2 bytes
.const PN_NLEN  = 7
.const PN_NAME  = 8              // disknaam 16
.const PN_ENT   = 32
.label PANE0    = $c500
.label PANE1    = $ca00
.label FM_BUF   = $4000
.const FM_BUFSZ = $3000
.const FM_TOPR  = 4              // eerste bestandsrij
.const FM_VIS   = 15
.const FM_FREER = 19
.const FM_BTNR  = 20
.const FM_KEYR  = 21
.const FM_MSGR  = 22
.label fmP = r3                  // zeropage: venster, entry
.label fmE = r6

// fm_Load - bij het openen: drives zoeken, beide vensters lezen.
fm_Load: {
        lda #0
        sta fmMsg+1
        sta fmAct
        lda fmScanned            // (eenmaal per keer dat de overlay laadt)
        bne rd
        inc fmScanned
        jsr fm_Scan
rd:     jsr fm_ReadBoth
        lda #0                   // scanmelding weg
        sta fmMsg+1
        rts
}

// fm_Scan - drives 8-15 zoeken (+ type via "UI"), vensters erop zetten.
fm_Scan: {
        ldx #<sFmScan
        ldy #>sFmScan
        jsr fm_Say
        lda #0
        sta drvCnt
        lda #8
        sta fmI
lp:     lda #2                   // "UI": reset, antwoord "73,..DOS.. 1571,00,00"
        sta dsCmdLen
        lda #$55
        sta dsCmd
        lda #$49
        sta dsCmd+1
        lda fmI
        jsr dsk_Cmd
        bcs nx                   // geen drive
        ldx drvCnt
        lda fmI
        sta drvDev,x
        jsr fm_Type              // type uit dsText -> drvTyp
        inc drvCnt
nx:     inc fmI
        lda fmI
        cmp #16
        bne lp
        lda drvCnt               // vensters: eerste en tweede drive
        bne s1
        lda #8                   // (niets gevonden: toch 8)
        sta PANE0+PN_DEV
        sta PANE1+PN_DEV
        rts
s1:     lda drvDev
        sta PANE0+PN_DEV
        sta PANE1+PN_DEV
        lda drvCnt
        cmp #2
        bcc r
        lda drvDev+1
        sta PANE1+PN_DEV
r:      rts
}

// fm_Type - laatste woord voor de eerste komma na "73," (bv. "1571")
//           -> drvTyp[drvCnt] (6 tekens).
fm_Type: {
        ldy #3
fc:     lda dsText,y             // eerste komma na de code
        cmp #$ff
        beq none
        cmp #$2c
        beq got
        iny
        cpy #38
        bne fc
none:   ldy #3
got:    sty fmJ                  // (einde van het woord)
        tya
        tax
bs:     dex                      // terug tot een spatie
        cpx #3
        bcc st
        lda dsText,x
        cmp #$20
        bne bs
st:     inx
        txa
        tay                      // y = begin van het woord
        lda drvCnt
        asl
        asl
        asl
        tax
        lda #6
        sta fmK
c1:     cpy fmJ
        bcs pad
        lda dsText,y
        sta drvTyp,x
        inx
        iny
        dec fmK
        bne c1
        rts
pad:    lda #$20
        sta drvTyp,x
        inx
        dec fmK
        bne pad
        rts
}

// fm_ReadBoth - beide vensters (opnieuw) lezen.
fm_ReadBoth:
        lda #0
        jsr fm_Read
        lda #1
        jmp fm_Read

// fm_PaneP - fmP = venster A.
fm_PaneP:
        tax
        lda paneLo,x
        sta fmP
        lda paneHi,x
        sta fmP+1
        rts

// fm_EntP - fmE = entry A van venster fmP.
fm_EntP: {
        sta fmT
        lda #0
        sta fmT+1
        lda fmT                  // *20 = *16 + *4
        asl
        asl
        sta fmT2
        asl
        asl
        rol fmT+1
        clc
        adc fmT2
        sta fmE
        lda fmT+1
        adc #0
        sta fmE+1
        lda fmE
        clc
        adc #PN_ENT
        sta fmE
        lda fmE+1
        adc #0
        sta fmE+1
        lda fmE
        clc
        adc fmP
        sta fmE
        lda fmE+1
        adc fmP+1
        sta fmE+1
        rts
}

//--------------------------------------------------------
// fm_Read - directory van venster A lezen.
//--------------------------------------------------------
fm_Read: {
        sta fmPn
        jsr fm_PaneP
        ldy #PN_CNT
        lda #0
        sta (fmP),y
        ldy #PN_TOP
        sta (fmP),y
        ldy #PN_SEL
        sta (fmP),y
        ldy #PN_NLEN
        sta (fmP),y
        ldy #PN_FREE
        sta (fmP),y
        iny
        sta (fmP),y
        ldy #PN_DEV
        lda (fmP),y
        sta fmDev
        jsr cfg_io_begin
        lda #1
        ldx #<dl
        ldy #>dl
        jsr K_SETNAM
        lda #2
        ldx fmDev
        ldy #0
        jsr K_SETLFS
        lda #0
        sta $90
        jsr K_OPEN
        bcc fb4932_0
        jmp end
fb4932_0:
        ldx #2
        jsr K_CHKIN
        bcc fb4932_1
        jmp end
fb4932_1:
        jsr K_CHRIN              // laadadres
        jsr K_CHRIN
        lda #0
        sta fmLine
line:   jsr K_CHRIN              // link
        sta fmT
        lda $90
        beq fb4932_2
        jmp end
fb4932_2:
        jsr K_CHRIN
        ora fmT
        beq end
        jsr K_CHRIN              // blokken
        sta fmBlk
        jsr K_CHRIN
        sta fmBlk+1
        lda #0
        sta fmQ
        sta fmNL
        sta fmTy
        sta fmSplat
ch:     jsr K_CHRIN
        sta fmT
        lda $90
        bne end
        lda fmT
        beq eol
        ldx fmQ
        bne q1
        cmp #$22                 // naam begint
        bne ch
        inc fmQ
        jmp ch
q1:     cpx #1
        bne q2
        cmp #$22                 // naam klaar
        beq cq
        ldx fmNL
        cpx #16
        bcs ch
        sta fmTmp,x
        inc fmNL
        jmp ch
cq:     inc fmQ
        jmp ch
q2:     cpx #2                   // na de naam: * (niet gesloten) en type
        bne ch
        cmp #$20
        beq ch
        cmp #$2a
        bne ty
        inc fmSplat
        jmp ch
ty:     sta fmTy                 // eerste letter: P S U R D
        inc fmQ
        jmp ch
eol:    jsr keep
        inc fmLine
        jmp line
end:    jsr K_CLRCHN
        lda #2
        jsr K_CLOSE
        jmp cfg_io_end
dl:     .byte $24

keep:   lda fmQ                  // regel zonder naam: "BLOCKS FREE"
        bne k1
        ldy #PN_FREE
        lda fmBlk
        sta (fmP),y
        iny
        lda fmBlk+1
        sta (fmP),y
        rts
k1:     lda fmLine               // eerste regel = disknaam
        bne k2
        ldy #PN_NLEN
        lda fmNL
        sta (fmP),y
        ldx #0
        ldy #PN_NAME
kn:     cpx fmNL
        bcs kr
        lda fmTmp,x
        sta (fmP),y
        inx
        iny
        bne kn
kr:     rts
k2:     ldy #PN_CNT
        lda (fmP),y
        cmp #FM_MAX
        bcs kr
        jsr fm_EntP
        ldy #0
kc:     cpy fmNL
        bcs kl
        lda fmTmp,y
        sta (fmE),y
        iny
        bne kc
kl:     ldy #FE_LEN
        lda fmNL
        sta (fmE),y
        ldy #FE_TYPE
        lda fmTy
        and #$7f
        ldx fmSplat
        beq kt
        ora #$80                 // bit 7: niet gesloten (*)
kt:     sta (fmE),y
        ldy #FE_BLK
        lda fmBlk
        sta (fmE),y
        iny
        lda fmBlk+1
        sta (fmE),y
        ldy #PN_CNT
        lda (fmP),y
        clc
        adc #1
        sta (fmP),y
        rts
}

//--------------------------------------------------------
// fm_Draw - beide vensters, knoppen, toetsen, melding.
//--------------------------------------------------------
fm_Draw: {
        lda #1                   // cursortoetsen / F-toetsen
        sta kbRaw
        lda #0
        jsr fm_DrawPane
        lda #1
        jsr fm_DrawPane
        lda #19                  // scheidingslijn tussen de vensters
        sta fmI
sl:     lda #19
        sta a0
        lda fmI
        sta a1
        lda #FR_V
        sta a2
        lda TH_text
        sta a3
        jsr gfx_PutChar
        dec fmI
        lda fmI
        cmp #1
        bne sl
        ldx #0
bl:     stx fmI
        lda fbLo,x
        sta r0
        lda fbHi,x
        sta r0+1
        lda fbCol,x
        sta a0
        lda #FM_BTNR
        sta a1
        lda fbW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx fmI
        inx
        cpx #5
        bne bl
        lda #<sFmKeys
        sta r0
        lda #>sFmKeys
        sta r0+1
        lda #2
        sta a0
        lda #FM_KEYR
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        jmp fm_ShowMsg
}

// fm_DrawPane - venster A tekenen.
fm_DrawPane: {
        sta fmPn
        jsr fm_PaneP
        ldx fmPn
        lda paneCol,x
        sta fmCol
        lda #2                   // kop: "8:1571" (accent = actief)
        sta a1
        lda fmCol
        sta a0
        lda #17
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        ldy #PN_DEV
        lda (fmP),y
        jsr fm_DevText           // -> fmLine buffer (schermcodes)
        lda #<fmLbuf
        sta r0
        lda #>fmLbuf
        sta r0+1
        lda fmCol
        sta a0
        lda #2
        sta a1
        lda TH_text
        ldx fmPn
        cpx fmAct
        bne h1
        lda TH_accent
h1:     sta a2
        ldx fmPn
        cpx fmAct
        bne h2
        jsr gfx_DrawTextRev
        jmp h3
h2:     jsr gfx_DrawText
h3:     ldy #PN_NLEN             // disknaam
        lda (fmP),y
        sta fmK
        ldx #0
        ldy #PN_NAME
dn:     cpx fmK
        bcs de
        lda (fmP),y
        and #$7f
        jsr petscii2screen
        sta fmLbuf,x
        inx
        iny
        bne dn
de:     lda #$ff
        sta fmLbuf,x
        lda #<fmLbuf
        sta r0
        lda #>fmLbuf
        sta r0+1
        lda fmCol
        sta a0
        lda #3
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        lda #0                   // bestanden
        sta fmRow
rl:     lda fmRow
        clc
        ldy #PN_TOP
        adc (fmP),y
        sta fmIdx
        jsr fm_EntryLine         // fmLbuf (17 tekens)
        lda fmRow
        clc
        adc #FM_TOPR
        sta a1
        lda fmCol
        sta a0
        lda #<fmLbuf
        sta r0
        lda #>fmLbuf
        sta r0+1
        lda TH_text
        sta a2
        ldy #PN_SEL              // geselecteerd?
        lda (fmP),y
        cmp fmIdx
        bne nsel
        ldy #PN_CNT
        lda (fmP),y
        beq nsel
        lda fmPn
        cmp fmAct
        bne selx
        lda TH_select
        sta a2
        jsr gfx_DrawTextRev
        jmp nx
selx:   lda TH_accent
        sta a2
nsel:   jsr gfx_DrawText
nx:     inc fmRow
        lda fmRow
        cmp #FM_VIS
        bcc rl
        ldy #PN_FREE             // "664 BLOCKS FREE"
        lda (fmP),y
        sta fmV
        iny
        lda (fmP),y
        sta fmV+1
        ldx #0
        jsr fm_Dec
        ldy #0
fr:     lda sFmFree,y
        sta fmLbuf,x
        cmp #$ff
        beq fd
        inx
        iny
        bne fr
fd:     lda #<fmLbuf
        sta r0
        lda #>fmLbuf
        sta r0+1
        lda fmCol
        sta a0
        lda #FM_FREER
        sta a1
        lda TH_text
        sta a2
        jmp gfx_DrawText
}

// fm_EntryLine - regel voor entry fmIdx van venster fmP -> fmLbuf
//                (naam 16, type-letter op 17; leeg als er geen entry is).
fm_EntryLine: {
        ldx #0
        lda #$20
cl:     sta fmLbuf,x
        inx
        cpx #17
        bne cl
        lda #$ff
        sta fmLbuf,x
        ldy #PN_CNT
        lda fmIdx
        cmp (fmP),y
        bcs r
        lda fmIdx
        jsr fm_EntP
        ldy #FE_LEN
        lda (fmE),y
        sta fmK
        ldy #0
nm:     cpy fmK
        bcs ty
        lda (fmE),y
        and #$7f
        jsr petscii2screen
        sta fmLbuf,y
        iny
        bne nm
ty:     ldy #FE_TYPE
        lda (fmE),y
        pha
        and #$7f
        jsr petscii2screen
        sta fmLbuf+16
        pla
        bpl r
        lda #$2a                 // * = niet gesloten
        sta fmLbuf+15
r:      rts
}

// fm_DevText - "8:1571" (device A) in fmLbuf.
fm_DevText: {
        sta fmV
        ldx #0
        cmp #10
        bcc one
        lda #$31
        sta fmLbuf
        inx
        lda fmV
        sec
        sbc #10
        jmp dg
one:    lda fmV
dg:     ora #$30
        sta fmLbuf,x
        inx
        lda #$3a
        sta fmLbuf,x
        inx
        ldy #0                   // type uit de drivetabel
fd:     cpy drvCnt
        bcs nt
        lda drvDev,y
        cmp fmV
        beq ft
        iny
        bne fd
nt:     ldy #0
dr:     lda sFmDrive,y
        sta fmLbuf,x
        cmp #$ff
        beq r
        inx
        iny
        bne dr
ft:     tya
        asl
        asl
        asl
        tay
        lda #6
        sta fmK
tc:     lda drvTyp,y
        sta fmLbuf,x
        inx
        iny
        dec fmK
        bne tc
        lda #$ff
        sta fmLbuf,x
r:      rts
}

// fm_Dec - 16-bit fmV decimaal naar fmLbuf,x (x erachter).
fm_Dec: {
        ldy #0
        sty fmAny
dg:     lda #0
        sta fmDig
sb:     lda fmV
        sec
        sbc d16Lo,y
        pha
        lda fmV+1
        sbc d16Hi,y
        bcc pd
        sta fmV+1
        pla
        sta fmV
        inc fmDig
        jmp sb
pd:     pla
        lda fmDig
        ora fmAny
        bne pr
        cpy #4
        bne nx
pr:     lda fmDig
        ora #$30
        sta fmLbuf,x
        inx
        inc fmAny
nx:     iny
        cpy #5
        bne dg
        rts
d16Lo:  .byte <10000, <1000, <100, <10, <1
d16Hi:  .byte >10000, >1000, >100, >10, >1
}

// fm_ShowMsg / fm_Say - meldingsregel.
fm_Say:
        stx fmMsg
        sty fmMsg+1
fm_ShowMsg: {
        lda #2
        sta a0
        lda #FM_MSGR
        sta a1
        lda #36
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda fmMsg+1
        beq r
        sta r0+1
        lda fmMsg
        sta r0
        lda #2
        sta a0
        lda #FM_MSGR
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
r:      rts
}

//--------------------------------------------------------
// fm_Click - venster, kop, knoppen.
//--------------------------------------------------------
fm_Click: {
        ldx #0
bl:     stx fmI
        lda fbCol,x
        sta a0
        lda #FM_BTNR
        sta a1
        lda fbW,x
        sta a2
        jsr btn_HitTest
        bcs btn
        ldx fmI
        inx
        cpx #5
        bne bl
        ldx #0                   // welk venster?
        lda evtA
        cmp #19
        beq r
        bcc p
        inx
p:      stx fmK
        lda evtB
        cmp #2                   // kop: volgende drive
        bne fl
        lda fmK
        sta fmAct
        jmp fm_NextDrive
fl:     sec                      // bestand
        sbc #FM_TOPR
        bcc r
        cmp #FM_VIS
        bcs r
        sta fmRow
        lda fmK
        jsr fm_PaneP
        ldy #PN_TOP
        lda (fmP),y
        clc
        adc fmRow
        ldy #PN_CNT
        cmp (fmP),y
        bcs act
        ldx fmK                  // nog eens op het geselecteerde = RUN
        cpx fmAct
        bne sel
        ldy #PN_SEL
        cmp (fmP),y
        beq run
sel:    ldy #PN_SEL
        sta (fmP),y
act:    lda fmK
        sta fmAct
        lda #0
        sta fmMsg+1
        jmp fm_Redraw
run:    jmp fm_Run
r:      rts
btn:    lda #0
        sta fmMsg+1
        lda fmI
        bne b1
        jmp fm_Run
b1:     cmp #1
        bne b2
        jmp fm_Edit
b2:     cmp #2
        bne b3
        jmp fm_Copy
b3:     cmp #3
        bne b4
        jmp fm_Delete
b4:     jmp fm_Drives
}

fm_Redraw:
        jmp shell_DrawAll

// fm_NextDrive - actief venster naar de volgende gevonden drive.
fm_NextDrive: {
        lda fmAct
        jsr fm_PaneP
        lda drvCnt
        beq r
        ldy #PN_DEV
        lda (fmP),y
        ldx #0
f:      cmp drvDev,x
        beq g
        inx
        cpx drvCnt
        bne f
        ldx #$ff
g:      inx
        cpx drvCnt
        bcc s
        ldx #0
s:      lda drvDev,x
        ldy #PN_DEV
        sta (fmP),y
        lda fmAct
        jsr fm_Read
r:      jmp fm_Redraw
}

// fm_Drives - opnieuw zoeken en lezen (andere diskettes, andere drives).
fm_Drives:
        jsr fm_Scan
        jsr fm_ReadBoth
        ldx #<sFmUpd
        ldy #>sFmUpd
        stx fmMsg
        sty fmMsg+1
        jmp fm_Redraw

//--------------------------------------------------------
// fm_Key - toetsen (ruwe modus, evtA/evtB).
//--------------------------------------------------------
fm_Key: {
        lda evtB
        sta fmMods
        lda evtA
        cmp #KEY_CRSR_D
        bne k1
        lda fmMods
        and #KM_SHIFT
        bne up
        jmp fm_Down
up:     jmp fm_Up
k1:     cmp #KEY_CRSR_R          // links/rechts: ander venster
        bne k2
        lda fmAct
        eor #1
        sta fmAct
        jmp fm_Redraw
k2:     cmp #KEY_RETURN
        bne k3
        jmp fm_Run
k3:     cmp #KEY_F3
        bne k4
        jmp fm_Edit
k4:     cmp #KEY_F5
        bne k5
        jmp fm_Copy
k5:     cmp #KEY_F7              // F7 = drives, SHIFT+F7 (F8) = wissen
        bne r
        lda fmMods
        and #KM_SHIFT
        bne del
        jmp fm_Drives
del:    jmp fm_Delete
r:      rts
}

fm_Down: {
        lda fmAct
        jsr fm_PaneP
        ldy #PN_SEL
        lda (fmP),y
        clc
        adc #1
        ldy #PN_CNT
        cmp (fmP),y
        bcs r
        ldy #PN_SEL
        sta (fmP),y
        sec                      // onder de zichtbare rijen: scrollen
        ldy #PN_TOP
        sbc (fmP),y
        cmp #FM_VIS
        bcc d
        lda (fmP),y
        clc
        adc #1
        sta (fmP),y
d:      jmp fm_Redraw
r:      rts
}

fm_Up: {
        lda fmAct
        jsr fm_PaneP
        ldy #PN_SEL
        lda (fmP),y
        beq r
        sec
        sbc #1
        sta (fmP),y
        ldy #PN_TOP
        cmp (fmP),y
        bcs d
        sta (fmP),y
d:      jmp fm_Redraw
r:      rts
}

// fm_Cur - geselecteerd bestand van het actieve venster: fmE, naam in
//          fileName/fileLen, fileDev. Carry=0 als er geen is.
fm_Cur: {
        lda fmAct
        jsr fm_PaneP
        ldy #PN_CNT
        lda (fmP),y
        bne h
        ldx #<sFmNone
        ldy #>sFmNone
        clc
        rts
h:      ldy #PN_SEL
        lda (fmP),y
        jsr fm_EntP
        ldy #PN_DEV
        lda (fmP),y
        sta fileDev
        ldy #FE_LEN
        lda (fmE),y
        sta fileLen
        ldy #0
cp:     cpy fileLen
        bcs d
        lda (fmE),y
        sta fileName,y
        iny
        bne cp
d:      ldy #FE_TYPE
        lda (fmE),y
        sta fmTy
        sec
        rts
}

// fm_Ext - eindigt de naam op de extensie X (3 letters in fmExt*)? Z=1 ja.
fm_Ext: {
        lda fileLen
        cmp #5
        bcc no
        tay
        lda fileName-4,y
        cmp #$2e                 // .
        bne no
        lda fileName-3,y
        and #$7f
        cmp extA,x
        bne no
        lda fileName-2,y
        and #$7f
        cmp extB,x
        bne no
        lda fileName-1,y
        and #$7f
        cmp extC,x
no:     rts
//              SID  CFG  INI  TXT
extA:   .byte $53, $43, $49, $54
extB:   .byte $49, $46, $4e, $58
extC:   .byte $44, $47, $49, $54
}

//--------------------------------------------------------
// fm_Run - starten / afspelen / openen, afhankelijk van het bestand.
//--------------------------------------------------------
fm_Run: {
        jsr fm_Cur
        bcs h
        jmp fm_Say
h:      lda fmTy
        bmi bad                  // niet gesloten
        cmp #$53                 // SEQ
        beq edit
        cmp #$55                 // USR
        beq edit
        cmp #$50                 // PRG
        bne bad
        ldx #0                   // .SID -> SID PLAYER
        jsr fm_Ext
        beq sid
        ldx #1                   // .CFG / .INI / .TXT -> editor
        jsr fm_Ext
        beq edit
        ldx #2
        jsr fm_Ext
        beq edit
        ldx #3
        jsr fm_Ext
        beq edit
        // PRG starten: naam naar $03C0, lengte $03BF, drive $03BE
        ldx #0
cp:     lda fileName,x
        sta $03c0,x
        inx
        cpx fileLen
        bne cp
        stx $03bf
        lda fileDev
        sta $03be
        ldx #0                   // naam voor het laadscherm
nm:     lda fileName,x
        and #$7f
        jsr petscii2screen
        sta fmLbuf,x
        inx
        cpx fileLen
        bne nm
        lda #$ff
        sta fmLbuf,x
        lda #<fmLbuf
        sta r0
        lda #>fmLbuf
        sta r0+1
        jsr launch_Screen
        jmp launchCommon
sid:    lda #1
        sta fileReq
        lda #11                  // SID PLAYER
        jmp openApp
edit:   jmp fm_Edit
bad:    ldx #<sFmCant
        ldy #>sFmCant
        jsr fm_Say
        rts
}

// fm_Edit - bestand in de editor openen (PRG: laadadres overslaan).
fm_Edit: {
        jsr fm_Cur
        bcs h
        jmp fm_Say
h:      lda #0
        ldx fmTy
        cpx #$50
        bne s
        lda #1
s:      sta fileSkip
        lda #1
        sta fileReq
        lda #1                   // TEXT EDITOR
        jmp openApp
}

//--------------------------------------------------------
// fm_Copy - naar de drive van het andere venster (zelfde naam en type).
//--------------------------------------------------------
fm_Copy: {
        jsr fm_Cur
        bcs h
        jmp fm_Say
h:      lda fmTy
        bmi bad
        cmp #$52                 // REL niet
        beq bad
        lda fmAct                // doel = ander venster
        eor #1
        jsr fm_PaneP
        ldy #PN_DEV
        lda (fmP),y
        sta fmDst
        cmp fileDev
        bne go
        ldx #<sFmSame
        ldy #>sFmSame
        jmp fm_Say
bad:    ldx #<sFmCant
        ldy #>sFmCant
        jmp fm_Say
go:     ldx #<sFmCopying
        ldy #>sFmCopying
        jsr fm_Say
        // naam,T,R en naam,T,W
        ldx #0
n1:     lda fileName,x
        sta fmNameR,x
        sta fmNameW,x
        inx
        cpx fileLen
        bne n1
        lda #$2c
        sta fmNameR,x
        sta fmNameW,x
        lda fmTy
        and #$7f
        sta fmNameR+1,x
        sta fmNameW+1,x
        lda #$2c
        sta fmNameR+2,x
        sta fmNameW+2,x
        lda #$52                 // R
        sta fmNameR+3,x
        lda #$57                 // W
        sta fmNameW+3,x
        txa
        clc
        adc #4
        sta fmNLen
        jsr cfg_io_begin
        lda fmNLen               // bron openen (kanaal 2)
        ldx #<fmNameR
        ldy #>fmNameR
        jsr K_SETNAM
        lda #2
        ldx fileDev
        ldy #2
        jsr K_SETLFS
        jsr K_OPEN
        lda fmNLen               // doel openen (kanaal 3)
        ldx #<fmNameW
        ldy #>fmNameW
        jsr K_SETNAM
        lda #3
        ldx fmDst
        ldy #3
        jsr K_SETLFS
        jsr K_OPEN
        lda #0
        sta fmEof
blk:    ldx #2                   // stuk lezen (tot 12 KB)
        jsr K_CHKIN
        bcs fin
        lda #<FM_BUF
        sta fmE
        lda #>FM_BUF
        sta fmE+1
        lda #0
        sta fmN
        sta fmN+1
rd:     jsr K_CHRIN
        ldy #0
        sta (fmE),y
        inc fmE
        bne r1
        inc fmE+1
r1:     inc fmN
        bne r2
        inc fmN+1
r2:     lda $90
        bne eof
        lda fmN+1
        cmp #>FM_BUFSZ
        bcc rd
        jmp wr
eof:    inc fmEof
wr:     jsr K_CLRCHN
        ldx #3                   // stuk schrijven
        jsr K_CHKOUT
        bcs fin
        lda #<FM_BUF
        sta fmE
        lda #>FM_BUF
        sta fmE+1
wl:     lda fmN
        ora fmN+1
        beq wd
        ldy #0
        lda (fmE),y
        jsr K_CHROUT
        inc fmE
        bne w1
        inc fmE+1
w1:     lda fmN
        bne w2
        dec fmN+1
w2:     dec fmN
        jmp wl
wd:     jsr K_CLRCHN
        lda fmEof
        bne fin
        jmp blk
fin:    jsr K_CLRCHN
        lda #3
        jsr K_CLOSE
        lda #2
        jsr K_CLOSE
        jsr cfg_io_end
        lda fmDst                // status van het doel
        jsr dsk_Status
        lda dsCode
        cmp #20
        bcc ok
        ldx #<dsText
        ldy #>dsText
        jsr fm_Say
        jmp rr
ok:     ldx #<sFmCopied
        ldy #>sFmCopied
        jsr fm_Say
rr:     lda fmAct                // doelvenster opnieuw lezen
        eor #1
        jsr fm_Read
        jmp fm_Redraw
}

//--------------------------------------------------------
// fm_Delete - na Y: "S0:naam" naar de drive.
//--------------------------------------------------------
fm_Delete: {
        jsr fm_Cur
        bcs h
        jmp fm_Say
h:      ldx #<sFmSure
        ldy #>sFmSure
        jsr fm_Say
w:      jsr evt_Poll             // Y = wissen, al het andere = niet
        cmp #EVT_MOUSEDOWN
        beq no
        cmp #EVT_KEY
        bne w
        lda evtA
        cmp #$19                 // Y
        bne no
        lda #$53                 // S0:
        sta dsCmd
        lda #$30
        sta dsCmd+1
        lda #$3a
        sta dsCmd+2
        ldx #0
c:      lda fileName,x
        sta dsCmd+3,x
        inx
        cpx fileLen
        bne c
        txa
        clc
        adc #3
        sta dsCmdLen
        lda fileDev
        jsr dsk_Cmd              // antwoord "01,FILES SCRATCHED,01,00"
        ldx #<dsText
        ldy #>dsText
        jsr fm_Say
        lda fmAct
        jsr fm_Read
        jmp fm_Redraw
no:     lda #0
        sta fmMsg+1
        jmp fm_ShowMsg
}

//--------------------------------------------------------
fmScanned: .byte 0
fmAct:    .byte 0                // actief venster (0 links, 1 rechts)
fmPn:     .byte 0
fmCol:    .byte 0
fmRow:    .byte 0
fmIdx:    .byte 0
fmDev:    .byte 0
fmDst:    .byte 0
fmMods:   .byte 0
fmI:      .byte 0
fmJ:      .byte 0
fmK:      .byte 0
fmQ:      .byte 0
fmNL:     .byte 0
fmTy:     .byte 0
fmSplat:  .byte 0
fmLine:   .byte 0
fmAny:    .byte 0
fmDig:    .byte 0
fmEof:    .byte 0
fmNLen:   .byte 0
fmT:      .word 0
fmT2:     .byte 0
fmV:      .word 0
fmN:      .word 0
fmBlk:    .word 0
fmMsg:    .word 0
fmTmp:    .fill 16, 0
fmLbuf:   .fill 40, $ff
fmNameR:  .fill 22, 0
fmNameW:  .fill 22, 0
drvCnt:   .byte 0
drvDev:   .fill 8, 0
drvTyp:   .fill 8*8, $20
paneLo:   .byte <PANE0, <PANE1
paneHi:   .byte >PANE0, >PANE1
paneCol:  .byte 2, 20
fbLo:     .byte <sFbRun, <sFbEdit, <sFbCopy, <sFbDel, <sFbDrv
fbHi:     .byte >sFbRun, >sFbEdit, >sFbCopy, >sFbDel, >sFbDrv
fbCol:    .byte 2, 8, 15, 22, 28
fbW:      .byte 5, 6, 6, 5, 8

.encoding "screencode_upper"
sFbRun:   .text "RUN"
          .byte $ff
sFbEdit:  .text "EDIT"
          .byte $ff
sFbCopy:  .text "COPY"
          .byte $ff
sFbDel:   .text "DEL"
          .byte $ff
sFbDrv:   .text "DRIVES"
          .byte $ff
sFmKeys:  .text "RET RUN F3 EDT F5 CPY F7 DRV F8 DEL"
          .byte $ff
sFmFree:  .text " BLOCKS FREE"
          .byte $ff
sFmDrive: .text "DRIVE"
          .byte $ff
sFmScan:  .text "LOOKING FOR DRIVES..."
          .byte $ff
sFmUpd:   .text "DRIVES AND DISKS READ AGAIN"
          .byte $ff
sFmNone:  .text "NO FILE SELECTED"
          .byte $ff
sFmCant:  .text "THIS FILE CANNOT BE STARTED"
          .byte $ff
sFmSame:  .text "BOTH PANELS SHOW THE SAME DRIVE"
          .byte $ff
sFmCopying: .text "COPYING..."
          .byte $ff
sFmCopied: .text "COPIED"
          .byte $ff
sFmSure:  .text "DELETE THIS FILE? PRESS Y"
          .byte $ff
