#importonce
//========================================================
// gui/shell.asm - desktop-shell + widget-demo (Fase 5 + 6)
// Commodore Desk 64
//
// Bureaublad met contextuele menubalk, statusbalk en dock. Het
// werkgebied toont een widget-demo (knop-teller, checkbox, scrollbare
// lijst, modale dialoog) om de herbruikbare widgets te tonen.
//========================================================

.const LIST_COUNT   = 8
.const LIST_VISIBLE = 5

// shell_Init - begintoestand.
shell_Init:
        lda #$ff
        sta activeApp
        lda #0                   // menubalk begint verborgen (dock is statisch)
        sta menuShown
        jsr shell_DrawAll
        rts

// shell_Run - hoofdlus.
shell_Run:
!loop:  lda activeApp            // Paint = volledig-scherm bitmap: geen balken
        cmp #2
        bne !bars+
        jsr paint_Live           // sleep-tekenen zolang de knop ingedrukt is
        jmp !ev+
!bars:  jsr checkBars
!ev:    jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        bne !k+
        jsr sid_Click
        jsr onMouseDown
        jmp !loop-
!k:     cmp #EVT_KEY
        bne !loop-
        lda evtA
        cmp #$82                 // RUN/STOP = back to desktop (works in any app)
        bne !notExit+
        jsr exitToDesktop
        jmp !loop-
!notExit:
        lda evtA
        cmp #$83                 // F1 = context help (space closes it)
        bne !nothelp+
        lda activeApp            // geen F1-help in Paint (bitmap-modus)
        cmp #2
        beq !loop-
        jsr help_Show
        jmp !loop-
!nothelp:
        lda activeApp
        cmp #1                   // editor gets the key (space types there)
        bne !notEd+
        jsr ed_Key
        jmp !loop-
!notEd: lda evtA                 // SPACE or RETURN elsewhere = click at cursor
        cmp #$20
        beq !click+
        cmp #$80
        bne !loop-
!click: jsr cursorToCell
        jsr onMouseDown
        jmp !loop-

//--------------------------------------------------------
shell_DrawAll:
        lda TH_deskbg
        sta a2
        jsr gfx_Cls
        jsr drawContent
        jsr drawDock             // dock is statisch (macOS-stijl): altijd zichtbaar
        lda menuShown            // alleen de bovenste menubalk klapt in/uit
        beq !nm+
        jsr drawMenubar
!nm:    lda #13
        sta $07f8                // sprite 0 pointer herstellen
        rts

//--------------------------------------------------------
// checkBars - alleen de bovenste menubalk klapt in/uit op basis van
//             de cursorpositie. De dock staat statisch onderaan.
//--------------------------------------------------------
checkBars:
        lda crsY
        sec
        sbc #50
        lsr
        lsr
        lsr
        sta cbRow                // cursorrij 0-24
        lda cbRow                // menubalk: rij 0
        bne !topHide+
        lda menuShown
        bne !done+
        lda #1
        sta menuShown
        jsr drawMenubar
        rts
!topHide:
        lda menuShown
        beq !done+
        lda #0
        sta menuShown
        jsr clearRow0
!done:  rts

clearRow0:
        lda #0
        sta a0
        sta a1
        lda #40
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_deskbg
        sta a5
        jmp gfx_FillRect

//--------------------------------------------------------
drawMenubar:
        lda #0
        sta a0
        lda TH_menubg
        sta a2
        jsr gfx_BarRow
        ldx activeApp
        inx
        lda menuLo,x
        sta r0
        lda menuHi,x
        sta r0+1
        lda #1
        sta a0
        lda #0
        sta a1
        lda TH_menubg
        sta a2
        jsr gfx_DrawTextRev
        rts

//--------------------------------------------------------
drawContent:
        // Geen buitenkader meer: apps gebruiken het hele middenvak.
        // App-naam bovenaan (rij 1); de menubalk verschijnt evt. op rij 0.
        ldx activeApp
        inx
        lda nameLo,x
        sta r0
        lda nameHi,x
        sta r0+1
        lda #2
        sta a0
        lda #1
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        // inhoud per app
        lda activeApp
        cmp #$ff
        bne !a+
        jmp drawDesktopContent
!a:     cmp #0
        bne !b+
        jmp fm_Draw
!b:     cmp #1
        bne !c+
        jmp ed_Draw
!c:     cmp #2                   // Paint draait in eigen bitmapmodus
        bne !d+
        jmp drawStub
!d:     cmp #3
        bne !e+
        jmp calc_Draw
!e:     cmp #4
        bne !e2+
        jmp set_Draw
!e2:    cmp #5
        bne !f+
        jmp inet_Draw
!f:     jmp drawStub

//--------------------------------------------------------
// inet_Draw - placeholder-pagina voor de internet-apps.
//--------------------------------------------------------
inet_Draw:
        lda #<sInet1
        sta r0
        lda #>sInet1
        sta r0+1
        lda #6
        sta a0
        lda #8
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        lda #<sInet2
        sta r0
        lda #>sInet2
        sta r0+1
        lda #6
        sta a0
        lda #10
        sta a1
        lda TH_text
        sta a2
        jmp gfx_DrawText

drawDesktopContent:
        lda #<sDeskHint
        sta r0
        lda #>sDeskHint
        sta r0+1
        lda #2
        sta a0
        lda #10
        sta a1
        lda #GREY
        sta a2
        jmp gfx_DrawText

drawStub:
        rts

//--------------------------------------------------------
// drawDock - 6 iconen (rij 22-23) + labels (rij 24).
//--------------------------------------------------------
drawDock:
        lda #0
        sta dockI
!lp:    lda dockI
        cmp #6
        bcc !go+
        jmp !done+
!go:    ldx dockI                // slotBase uit tabel
        lda dockBase,x
        sta dockTmp
        // TL (base+2, 22)
        clc
        adc #2
        sta a0
        lda #22
        sta a1
        ldx dockI
        lda icon2TL,x
        sta a2
        lda iconColor,x
        sta a3
        jsr gfx_PutChar
        // TR (base+3, 22)
        lda dockTmp
        clc
        adc #3
        sta a0
        lda #22
        sta a1
        ldx dockI
        lda icon2TR,x
        sta a2
        lda iconColor,x
        sta a3
        jsr gfx_PutChar
        // BL (base+2, 23)
        lda dockTmp
        clc
        adc #2
        sta a0
        lda #23
        sta a1
        ldx dockI
        lda icon2BL,x
        sta a2
        lda iconColor,x
        sta a3
        jsr gfx_PutChar
        // BR (base+3, 23)
        lda dockTmp
        clc
        adc #3
        sta a0
        lda #23
        sta a1
        ldx dockI
        lda icon2BR,x
        sta a2
        lda iconColor,x
        sta a3
        jsr gfx_PutChar
        // label (base+1, 24)
        lda dockTmp
        clc
        adc #1
        sta a0
        lda #24
        sta a1
        lda dockI
        cmp activeApp
        bne !notact+
        lda TH_select
        jmp !setc+
!notact:
        lda TH_text
!setc:  sta a2
        ldx dockI
        lda labelLo,x
        sta r0
        lda labelHi,x
        sta r0+1
        jsr gfx_DrawText
        inc dockI
        jmp !lp-
!done:  rts

//--------------------------------------------------------
// num2dec - A (0-255) als 3 decimale schermcodes op (r4).
//--------------------------------------------------------
num2dec:
        ldy #0
!h:     cmp #100
        bcc !hd+
        sbc #100
        iny
        jmp !h-
!hd:    pha
        tya
        ora #$30
        ldy #0
        sta (r4),y
        pla
        ldy #0
!t:     cmp #10
        bcc !td+
        sbc #10
        iny
        jmp !t-
!td:    pha
        tya
        ora #$30
        ldy #1
        sta (r4),y
        pla
        ora #$30
        ldy #2
        sta (r4),y
        rts

//--------------------------------------------------------
// exitToDesktop - active app sluiten, terug naar bureaublad.
//--------------------------------------------------------
exitToDesktop:
        lda activeApp            // Paint: eerst char-mode herstellen
        cmp #2
        bne !np+
        jsr paint_Exit
!np:    lda #$ff
        sta activeApp
        jmp shell_DrawAll

//--------------------------------------------------------
// menu_Open - uitklapmenu onder de menubalk (systeemmenu).
//             Modale lus: klik een item, of klik ernaast om te
//             sluiten. IRQ blijft de cursor pollen.
//--------------------------------------------------------
menu_Draw:
        gfxDrawBox(1, 1, 14, 5, LIGHT_GREY)      // rijen 1-5, kol 1-14
        lda CFG_menuFill                         // gevuld?
        beq !clear+
        lda #2                                   // interieur vullen (kol 2-13, rij 2-4)
        sta a0
        lda #2
        sta a1
        lda #12
        sta a2
        lda #3
        sta a3
        lda #$a0
        sta a4
        lda #LIGHT_GREY
        sta a5
        jsr gfx_FillRect
        lda #BLACK                               // zwarte tekst op gevuld paneel
        jmp !setc+
!clear: lda TH_text                          // witte tekst (doorzichtig)
!setc:  sta menuTxtCol
        lda #<oHelp
        sta r0
        lda #>oHelp
        sta r0+1
        lda #3
        sta a0
        lda #2
        sta a1
        lda menuTxtCol
        sta a2
        jsr gfx_DrawText
        lda #<oDesk
        sta r0
        lda #>oDesk
        sta r0+1
        lda #3
        sta a0
        lda #3
        sta a1
        lda menuTxtCol
        sta a2
        jsr gfx_DrawText
        lda #<oAbout
        sta r0
        lda #>oAbout
        sta r0+1
        lda #3
        sta a0
        lda #4
        sta a1
        lda menuTxtCol
        sta a2
        jmp gfx_DrawText

menu_Open: {
        jsr menu_Draw
wait:   jsr evt_Poll
        cmp #EVT_MOUSEDOWN        // muis/joystick-klik
        beq doClick
        cmp #EVT_KEY             // toetsenbord
        bne wait
        lda evtA
        cmp #$20                 // spatie = klik op cursorpositie
        beq keyClick
        cmp #$80                 // return = klik
        beq keyClick
        cmp #$82                 // ESC/RUN-STOP = sluiten
        beq close
        jmp wait
keyClick:
        jsr cursorToCell         // cursor -> evtA (kol), evtB (rij)
doClick:
        lda evtA                 // buiten kolommen 1-14 -> sluiten
        cmp #1
        bcc close
        cmp #15
        bcs close
        lda evtB
        cmp #2
        beq doHelp
        cmp #3
        beq doDesk
        cmp #4
        beq doAbout
close:  jmp shell_DrawAll
doHelp: jmp help_Show            // tekent zelf het scherm opnieuw
doDesk: jmp exitToDesktop
doAbout:jmp about_Show
}

//--------------------------------------------------------
// about_Show - "over deze OS"-venster (modaal, spatie sluit).
//--------------------------------------------------------
about_Show: {
        gfxDrawBox(6, 8, 28, 8, LIGHT_GREY)      // rijen 8-15
        lda #<aLine1
        sta r0
        lda #>aLine1
        sta r0+1
        lda #9
        sta a0
        lda #10
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        lda #<aLine2
        sta r0
        lda #>aLine2
        sta r0+1
        lda #9
        sta a0
        lda #12
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        lda #<aClose
        sta r0
        lda #>aClose
        sta r0+1
        lda #9
        sta a0
        lda #14
        sta a1
        lda TH_select
        sta a2
        jsr gfx_DrawText
wait:   jsr evt_Poll
        cmp #EVT_KEY
        bne wait
        lda evtA
        cmp #$20
        bne wait
        jmp shell_DrawAll
}

//--------------------------------------------------------
// onMouseDown - klik afhandelen (evtA=kol, evtB=rij).
//--------------------------------------------------------
onMouseDown:
        lda activeApp            // in Paint gaat elke klik naar het canvas
        cmp #2
        bne !np+
        jmp paint_Click
!np:    lda evtB
        bne !nomenu+
        lda menuShown            // klik op rij 0 = menubalk -> uitklapmenu
        beq !ret+
        jmp menu_Open
!ret:   rts
!nomenu:
        cmp #22
        bcc !widget+
        // dock -> app wisselen (6 slots, grenzen 7/13/20/26/32)
        lda evtA
        ldx #0
        cmp #7
        bcc !hit+
        inx
        cmp #13
        bcc !hit+
        inx
        cmp #20
        bcc !hit+
        inx
        cmp #26
        bcc !hit+
        inx
        cmp #32
        bcc !hit+
        inx
!hit:   txa
        cmp activeApp
        beq !done+
        sta activeApp
        cmp #0                   // File Manager -> directory lezen
        bne !na0+
        jsr fm_Load
        jmp !drawit+
!na0:   cmp #1                   // Editor
        bne !na1+
        jsr ed_Init
        jmp !drawit+
!na1:   cmp #2                   // Paint -> eigen bitmapmodus (geen char-redraw)
        bne !na2+
        jsr paint_Enter
        rts
!na2:   cmp #3                   // Calculator
        bne !na3+
        jsr calc_Init
        jmp !drawit+
!na3:   cmp #4                   // Settings
        bne !drawit+
        jsr set_Init
!drawit:
        jsr shell_DrawAll
        rts
!widget:
        // klik in het werkgebied -> naar de actieve app
        lda activeApp
        cmp #0
        bne !w1+
        jmp fm_Click
!w1:    cmp #2
        bne !w2+
        jmp paint_Click
!w2:    cmp #3
        bne !w3+
        jmp calc_Click
!w3:    cmp #4
        bne !done+
        jmp set_Click
!done:  rts

//--------------------------------------------------------
// Data
//--------------------------------------------------------
activeApp:   .byte $ff
dockI:       .byte 0
dockTmp:     .byte 0
menuShown:   .byte 0
cbRow:       .byte 0
menuTxtCol:  .byte 0
// gedeelde scratch-vars (o.a. File Manager-lijst)
lvI:         .byte 0
lvItem:      .byte 0
lvRow:       .byte 0

menuLo: .byte <mDesk, <mFiles, <mEdit, <mPaint, <mCalc, <mSet, <mInet
menuHi: .byte >mDesk, >mFiles, >mEdit, >mPaint, >mCalc, >mSet, >mInet
nameLo: .byte <nDesk, <nFiles, <nEdit, <nPaint, <nCalc, <nSet, <nInet
nameHi: .byte >nDesk, >nFiles, >nEdit, >nPaint, >nCalc, >nSet, >nInet

// dock: startkolom per slot (6 iconen over 40 kolommen)
dockBase:  .byte 1, 7, 13, 20, 26, 32
iconColor: .byte ORANGE, WHITE, LIGHT_RED, CYAN, LIGHT_GREEN, LIGHT_BLUE
// 2x2 dock-iconen: glyphcodes per kwadrant (TL/TR/BL/BR)
icon2TL:   .byte 107, 111, 115, 119, 123, 102
icon2TR:   .byte 108, 112, 116, 120, 124, 103
icon2BL:   .byte 109, 113, 117, 121, 125, 104
icon2BR:   .byte 110, 114, 118, 122, 126, 105
labelLo:   .byte <lFiles, <lEdit, <lPaint, <lCalc, <lSet, <lInet
labelHi:   .byte >lFiles, >lEdit, >lPaint, >lCalc, >lSet, >lInet

.encoding "screencode_upper"
mDesk:  .text "CD64   FILE   EDIT   VIEW   SYSTEM"
        .byte $ff
mFiles: .text "FILES   FILE   EDIT   DISK   VIEW"
        .byte $ff
mEdit:  .text "EDITOR   FILE   EDIT   SEARCH"
        .byte $ff
mPaint: .text "PAINT   FILE   EDIT   TOOLS   COLORS"
        .byte $ff
mCalc:  .text "CALC   FILE   EDIT"
        .byte $ff
mSet:   .text "SETTINGS   FILE   EDIT   VIEW"
        .byte $ff
mInet:  .text "INTERNET   MAIL   CHAT   RSS   FTP"
        .byte $ff

nDesk:  .text "DESKTOP"
        .byte $ff
nFiles: .text "FILE MANAGER"
        .byte $ff
nEdit:  .text "TEXT EDITOR"
        .byte $ff
nPaint: .text "PAINT"
        .byte $ff
nCalc:  .text "CALCULATOR"
        .byte $ff
nSet:   .text "SETTINGS"
        .byte $ff
nInet:  .text "INTERNET"
        .byte $ff

sDeskHint: .text "CLICK A DOCK ICON  -  TOP EDGE = MENU"
           .byte $ff
sInet1:    .text "INTERNET APPS"
           .byte $ff
sInet2:    .text "COMING SOON"
           .byte $ff
lFiles: .text "FILES"
        .byte $ff
lEdit:  .text "EDIT"
        .byte $ff
lPaint: .text "PAINT"
        .byte $ff
lCalc:  .text "CALC"
        .byte $ff
lSet:   .text "SETUP"
        .byte $ff
lInet:  .text "INET"
        .byte $ff

// uitklapmenu + about
oHelp:  .text "HELP"
        .byte $ff
oDesk:  .text "DESKTOP"
        .byte $ff
oAbout: .text "ABOUT"
        .byte $ff
aLine1: .text "COMMODORE DESK 64"
        .byte $ff
aLine2: .text "VERSION 0.9"
        .byte $ff
aClose: .text "SPACE = CLOSE"
        .byte $ff
