#importonce
//========================================================
// gui/desktool.asm - launcher-beheer (OVERLAY, geladen op $8000)
// Commodore Desk 64
//
// Toevoegen / bewerken / verwijderen van gebruikersprogramma's met alle
// dialogen (tekstinvoer, iconen-/kleurkiezer, PRG-kiezer, bevestiging).
// Wordt alleen gebruikt via het bureaubladmenu en pas dan van disk
// geladen (DESKTOOL), zodat het geen resident geheugen kost. Het
// recordmodel, tekenen, klikken en opslaan staan resident in deskapps.asm.
//========================================================
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
        jsr key_Plain            // namen: geen hoofdletters
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
        lda #GL_SOLID                 // cursorblok
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
        lda daK                  // (kies-icoon K = code 64 + K)
        clc
        adc #64
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
        lda #GL_SOLID
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
        lda DA_count             // (de prullenbak telt mee)
        clc
        adc DA_trashN
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
        lda #<sConfirm           // bevestiging vragen
        sta daConfTxt
        lda #>sConfirm
        sta daConfTxt+1
        jsr da_confirm
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
        lda daConfTxt
        sta r0
        lda daConfTxt+1
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
        lda TH_accent
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
        lda TH_accent
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
da_removeRec:                    // (eigen teller: da_recPtr gebruikt daTmp)
        lda daU
        sta rmI
!lp:    lda rmI
        clc
        adc #1
        cmp DA_count
        bcs !done+
        lda rmI
        jsr da_recPtr            // dst
        lda $fb
        sta $fd
        lda $fc
        sta $fe
        lda rmI
        clc
        adc #1
        jsr da_recPtr            // src
        ldy #0
!cp:    lda ($fb),y
        sta ($fd),y
        iny
        cpy #REC_STRIDE
        bne !cp-
        inc rmI
        jmp !lp-
!done:  rts
rmI:    .byte 0

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
// da_hintDraw - hint (r0) in de statusregel van het venster (rij 22).
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
        lda #WIN_BODY_BOT
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
        lda #WIN_BODY_BOT
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


//========================================================
// STONE-strook: prullenbak, printer (tool_Run 3-6)
//========================================================
// da_ToolMore - A = toolFn: 3 naar de prullenbak (toolArg), 4 printer,
//               5 prullenbak openen, 6 ingebouwd programma.
da_ToolMore:
        cmp #3
        bne !n3+
        jmp da_TrashDrop
!n3:    cmp #5
        bne !n5+
        jmp da_TrashOpen
!n5:    cmp #4
        bne !n4+
        jmp da_Printer
!n4:    cmp #7
        bne !n7+
        jmp da_Saver
!n7:    ldx #<sBuiltIn
        ldy #>sBuiltIn
!m:     jmp da_Msg

// da_Saver - screensaver (ss_Poll): het eigen programma SCRSAVER starten
//            als het op het bureaublad staat EN op de disk, anders niets
//            doen (D64: SCRSAVER staat op kant B; dan geen melding).
//            Bestaat hij? "R0:SCRSAVER=SCRSAVER" geeft 63 (bestaat al) of
//            62 (niet gevonden), zonder iets te veranderen.
da_Saver: {
        lda #0
        sta svI
lp:     lda svI
        cmp DA_count
        bcs no
        jsr da_recPtr
        ldy #REC_PLEN
        lda ($fb),y
        cmp #8
        bne nx
        ldx #7
cp:     txa
        clc
        adc #REC_PRG
        tay
        lda ($fb),y
        cmp nm,x
        bne nx
        dex
        bpl cp
        ldx #rnE-rn-1
rc:     lda rn,x
        sta dsCmd,x
        dex
        bpl rc
        lda #rnE-rn
        sta dsCmdLen
        lda #8
        jsr dsk_Cmd
        bcs no
        lda dsCode
        cmp #62
        beq no
        lda svI
        jmp da_Launch
nx:     inc svI
        jmp lp
no:     rts
.encoding "petscii_upper"
nm:     .text "SCRSAVER"
rn:     .text "R0:SCRSAVER=SCRSAVER"
rnE:
.encoding "screencode_upper"
}
svI:    .byte 0

// da_TrashDrop - eigen programma toolArg naar de prullenbak: uit de lijst,
//                achteraan in de tabel (plek 11 - aantal in de prullenbak).
da_TrashDrop:
        lda toolArg
        jsr da_recPtr
        jsr trToBuf
        lda toolArg
        sta daU
        jsr da_removeRec
        dec DA_count
        lda #DESK_MAXUSER-1
        sec
        sbc DA_trashN
        jsr da_recPtr
        jsr trFromBuf
        inc DA_trashN
        jsr da_Save
        jmp shell_DrawAll

// da_TrashOpen - wat zit er in de prullenbak? RESTORE / EMPTY.
da_TrashOpen:
        lda DA_trashN
        bne !go+
        ldx #<sTrEmpty
        ldy #>sTrEmpty
        jmp da_Msg
!go:    lda #0
        sta trSel
!dr:    lda #<sgTrash
        sta r0
        lda #>sgTrash
        sta r0+1
        lda #3                   // (binnen het STONE-bureaubladvenster)
        sta a0
        lda #4
        sta a1
        lda #28
        sta a2
        lda #17
        sta a3
        jsr dlg_Draw             // rijen 4-20, kolom 3-30
        lda #0
        sta trK
!ls:    lda trK                  // namen, de gekozen in de selectiekleur
        cmp DA_trashN
        bcs !bt+
        lda #DESK_MAXUSER-1
        sec
        sbc trK
        jsr da_recPtr
        lda $fb
        clc
        adc #REC_DISP
        sta r0
        lda $fc
        adc #0
        sta r0+1
        lda #6
        sta a0
        lda trK
        clc
        adc #6
        sta a1
        lda TH_text
        sta a2
        lda trK
        cmp trSel
        bne !pl+
        lda TH_select
        sta a2
        jsr gfx_DrawTextRev
        jmp !nl+
!pl:    jsr gfx_DrawText
!nl:    inc trK
        jmp !ls-
!bt:    lda #<sBtnRestore
        sta r0
        lda #>sBtnRestore
        sta r0+1
        lda #5
        sta a0
        lda #18
        sta a1
        lda #9
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sBtnEmpty
        sta r0
        lda #>sBtnEmpty
        sta r0+1
        lda #16
        sta a0
        lda #18
        sta a1
        lda #7
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
!w:     jsr da_pollClick         // (sluitknop / ESC: carry=1)
        bcs !cl+
        lda evtB                 // een naam gekozen
        sec
        sbc #6
        bcc !b+
        cmp DA_trashN
        bcs !b+
        sta trSel
        jmp !dr-
!b:     lda #5
        sta a0
        lda #18
        sta a1
        lda #9
        sta a2
        jsr btn_HitTest
        bcs !rs+
        lda #16
        sta a0
        lda #7
        sta a2
        jsr btn_HitTest
        bcc !w-
        lda #<sEmptyQ            // EMPTY: eerst vragen
        sta daConfTxt
        lda #>sEmptyQ
        sta daConfTxt+1
        jsr da_confirm
        bcs !cl+
        lda #0
        sta DA_trashN
        jmp !sv+
!rs:    jsr trRestore
!sv:    jsr da_Save
!cl:    jmp shell_DrawAll

// trRestore - trSel uit de prullenbak terug achteraan in de lijst.
trRestore:
        lda #DESK_MAXUSER-1
        sec
        sbc trSel
        jsr da_recPtr
        jsr trToBuf
        lda trSel                // gat dichten: plek 11-j <- plek 10-j
        sta trK
!lp:    lda trK
        clc
        adc #1
        cmp DA_trashN
        bcs !d+
        lda #DESK_MAXUSER-1
        sec
        sbc trK
        jsr da_recPtr
        lda $fb
        sta $fd
        lda $fc
        sta $fe
        lda #DESK_MAXUSER-2
        sec
        sbc trK
        jsr da_recPtr
        ldy #REC_STRIDE-1
!cp:    lda ($fb),y
        sta ($fd),y
        dey
        bpl !cp-
        inc trK
        jmp !lp-
!d:     dec DA_trashN
        lda DA_count
        jsr da_recPtr
        jsr trFromBuf
        inc DA_count
        rts

// trToBuf / trFromBuf - record ($fb) <-> trBuf.
trToBuf:
        ldy #REC_STRIDE-1
!c:     lda ($fb),y
        sta trBuf,y
        dey
        bpl !c-
        rts
trFromBuf:
        ldy #REC_STRIDE-1
!c:     lda trBuf,y
        sta ($fb),y
        dey
        bpl !c-
        rts

// da_Msg - melding X/Y met OK (titel: COMMODORE DESK 64).
da_Msg:
        stx daMsgP
        sty daMsgP+1
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
        lda daMsgP
        sta r0
        lda daMsgP+1
        sta r0+1
        lda #9
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

trSel:   .byte 0
trK:     .byte 0
daMsgP:  .word 0
daConfTxt: .word sConfirm        // vraag van da_confirm
trBuf:   .fill REC_STRIDE, 0
.encoding "screencode_upper"
sBuiltIn: .text "THIS PROGRAM MUST STAY"
         .byte $ff
sTrEmpty: .text "THE TRASH IS EMPTY"
         .byte $ff
sEmptyQ: .text "EMPTY THE TRASH?"
         .byte $ff
sBtnRestore: .text "RESTORE"
         .byte $ff
sBtnEmpty: .text "EMPTY"
         .byte $ff

//========================================================
// PRINTER-venster (PRINT-icoon op het bureaublad): type en aansluiting,
// TEST drukt een proefregel af, OK bewaart in CD64.CFG.
//========================================================
.const DP_X = 3
.const DP_Y = 6

da_Printer: {
        lda CFG_printer
        sta dpOld
        lda #<sDpHint
        sta dpMsg
        lda #>sDpHint
        sta dpMsg+1
draw:   lda #<sDpTitle
        sta r0
        lda #>sDpTitle
        sta r0+1
        lda #DP_X
        sta a0
        lda #DP_Y
        sta a1
        lda #30
        sta a2
        lda #11
        sta a3
        jsr dlg_Draw             // rijen 6-16
        lda #<sDpType            // TYPE: ...
        ldx #>sDpType
        ldy #DP_Y+2
        jsr dp_Label
        lda CFG_printer
        and #3
        tax
        lda dpTLo,x
        ldy dpTHi,x
        tax
        lda #DP_Y+2
        jsr dp_Value
        lda #<sDpPort            // PORT: ...
        ldx #>sDpPort
        ldy #DP_Y+4
        jsr dp_Label
        ldx #<sDpSerial
        ldy #>sDpSerial
        lda CFG_printer
        bpl ps
        ldx #<sDpUser
        ldy #>sDpUser
ps:     lda #DP_Y+4
        jsr dp_Value
        lda dpMsg                // melding / uitleg
        sta r0
        lda dpMsg+1
        sta r0+1
        lda #DP_X+2
        sta a0
        lda #DP_Y+6
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        lda #<sDpTest            // TEST, OK
        sta r0
        lda #>sDpTest
        sta r0+1
        lda #DP_X+2
        sta a0
        lda #DP_Y+8
        sta a1
        lda #6
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sDpOk
        sta r0
        lda #>sDpOk
        sta r0+1
        lda #DP_X+10
        sta a0
        lda #DP_Y+8
        sta a1
        lda #4
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
wait:   jsr da_pollClick         // sluitknop / ESC: niets bewaren
        bcs cancel
        lda evtB
        cmp #DP_Y+2              // TYPE: EPSON -> STAR -> HP -> EPSON
        bne np
        lda CFG_printer
        and #3
        clc
        adc #1
        cmp #3
        bcc t
        lda #0
t:      sta dpT
        lda CFG_printer
        and #$fc
        ora dpT
        sta CFG_printer
        jmp hint
np:     cmp #DP_Y+4              // PORT: serieel <-> userport
        bne nb
        lda CFG_printer
        eor #$80
        sta CFG_printer
hint:   lda #<sDpHint
        sta dpMsg
        lda #>sDpHint
        sta dpMsg+1
        jmp draw
nb:     lda #DP_X+2              // TEST
        sta a0
        lda #DP_Y+8
        sta a1
        lda #6
        sta a2
        jsr btn_HitTest
        bcs test
        lda #DP_X+10             // OK
        sta a0
        lda #4
        sta a2
        jsr btn_HitTest
        bcc wait
        jsr cfg_Save
        jmp shell_DrawAll
cancel: lda dpOld
        sta CFG_printer
        jmp shell_DrawAll
test:   lda #<sDpBusy
        sta dpMsg
        lda #>sDpBusy
        sta dpMsg+1
        jsr dp_ClrMsg
        lda #<sDpBusy
        sta r0
        lda #>sDpBusy
        sta r0+1
        lda #DP_X+2
        sta a0
        lda #DP_Y+6
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        jsr dp_Test
        stx dpMsg
        sty dpMsg+1
        jmp draw
}

// dp_Test - proefpagina: kop, type, alfabet. Uit: X/Y = melding.
dp_Test: {
        jsr dtPr.pr_Open
        bcs r
        ldx #0
lp:     stx dpT
        lda dpLnLo,x
        sta r6
        lda dpLnHi,x
        sta r6+1
        ldy #0                   // lengte (tot $ff)
ln:     lda (r6),y
        cmp #$ff
        beq pr
        iny
        bne ln
pr:     jsr dtPr.pr_Line
        bcs fail
        ldx dpT
        inx
        cpx #4
        bne lp
        jsr dtPr.pr_Close
        bcs r
        ldx #<sDpDone
        ldy #>sDpDone
r:      rts
fail:   jmp dtPr.pr_Shut
}

dp_Label:                        // A/X = tekst, Y = rij (kolom DP_X+2)
        sta r0
        stx r0+1
        sty a1
        lda #DP_X+2
        sta a0
        lda TH_text
        sta a2
        jmp gfx_DrawText
dp_Value:                        // X/Y = tekst, A = rij (kolom DP_X+9)
        stx r0
        sty r0+1
        sta a1
        lda #DP_X+9
        sta a0
        lda TH_accent
        sta a2
        jmp gfx_DrawText
dp_ClrMsg:
        lda #DP_X+2
        sta a0
        lda #DP_Y+6
        sta a1
        lda #26
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jmp gfx_FillRect

dpOld:  .byte 0
dpT:    .byte 0
dpMsg:  .word 0
dpTLo:  .byte <sDpEpson, <sDpStar, <sDpHp
dpTHi:  .byte >sDpEpson, >sDpStar, >sDpHp
dpLnLo: .byte <sDpL0, <sDpL1, <sDpL2, <sDpL3
dpLnHi: .byte >sDpL0, >sDpL1, >sDpL2, >sDpL3

dtPr: PrinterDriver()

.encoding "screencode_upper"
sDpTitle:  .text "PRINTER"
           .byte $ff
sDpType:   .text "TYPE:"
           .byte $ff
sDpPort:   .text "PORT:"
           .byte $ff
sDpEpson:  .text "EPSON (ESC/P)     "
           .byte $ff
sDpStar:   .text "STAR              "
           .byte $ff
sDpHp:     .text "HP LASERJET (PCL) "
           .byte $ff
sDpSerial: .text "SERIAL, DEVICE 4  "
           .byte $ff
sDpUser:   .text "USERPORT (CABLE)  "
           .byte $ff
sDpHint:   .text "CLICK A LINE TO CHANGE IT"
           .byte $ff
sDpBusy:   .text "PRINTING TEST PAGE..."
           .byte $ff
sDpDone:   .text "TEST PAGE PRINTED"
           .byte $ff
sDpTest:   .text "TEST"
           .byte $ff
sDpOk:     .text "OK"
           .byte $ff
sDpL0:     .text "COMMODORE DESK 64 - PRINTER TEST"
           .byte $ff
sDpL1:     .text "--------------------------------"
           .byte $ff
sDpL2:     .text "ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789"
           .byte $ff
sDpL3:     .text "IF YOU CAN READ THIS, PRINTING WORKS."
           .byte $ff

//--------------------------------------------------------
// Data (alleen gebruikt door de overlay)
//--------------------------------------------------------
.encoding "screencode_upper"
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
