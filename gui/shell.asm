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

// drawDesktopContent - launcher-grid met programma-iconen (2x2 + label).
drawDesktopContent:
        lda #0
        sta deI
!lp:    lda deI
        cmp deskCount
        bcc !go+
        jmp !hint+
!go:    lda deI                  // basiskolom = 4 + entry*8
        asl
        asl
        asl
        clc
        adc #4
        sta deCol
        ldx deI
        lda deskIcon,x
        sta deIcon
        lda deskIcoCol,x
        sta deIcoC
        lda deCol                // TL (col+1, rij 4)
        clc
        adc #1
        sta a0
        lda #4
        sta a1
        lda deIcon
        sta a2
        lda deIcoC
        sta a3
        jsr gfx_PutChar
        lda deCol                // TR (col+2, rij 4)
        clc
        adc #2
        sta a0
        lda #4
        sta a1
        lda deIcon
        clc
        adc #1
        sta a2
        lda deIcoC
        sta a3
        jsr gfx_PutChar
        lda deCol                // BL (col+1, rij 5)
        clc
        adc #1
        sta a0
        lda #5
        sta a1
        lda deIcon
        clc
        adc #2
        sta a2
        lda deIcoC
        sta a3
        jsr gfx_PutChar
        lda deCol                // BR (col+2, rij 5)
        clc
        adc #2
        sta a0
        lda #5
        sta a1
        lda deIcon
        clc
        adc #3
        sta a2
        lda deIcoC
        sta a3
        jsr gfx_PutChar
        lda deCol                // label (col, rij 6)
        sta a0
        lda #6
        sta a1
        lda TH_text
        sta a2
        ldx deI
        lda deskNameLo,x
        sta r0
        lda deskNameHi,x
        sta r0+1
        jsr gfx_DrawText
        inc deI
        jmp !lp-
!hint:  lda #<sDeskHint
        sta r0
        lda #>sDeskHint
        sta r0+1
        lda #2
        sta a0
        lda #19
        sta a1
        lda #GREY
        sta a2
        jmp gfx_DrawText

//--------------------------------------------------------
// desk_Click - klik op een launcher-icoon (rij 4-6) -> start het.
//--------------------------------------------------------
desk_Click:
        lda evtB
        cmp #4
        bcc !ret+
        cmp #7
        bcs !ret+
        lda evtA
        sec
        sbc #4
        bcc !ret+
        lsr
        lsr
        lsr                      // /8 -> entry
        cmp deskCount
        bcs !ret+
        tax
        lda deskKind,x
        bne !stand+
        lda deskParam,x          // overlay-app-id
        jmp openApp
!stand: lda deskParam,x          // standalone PRG-index
        jmp desk_RunPrg
!ret:   rts

// run-stub: geassembleerd voor $0334. Laadt de PRG en start 'm (SYS 2061),
// of valt bij mislukking netjes terug in de OS (shell_NotFound).
rpStubSrc:
.pseudopc $0334 {
rpStub: jsr cfg_io_begin
        lda $03bf                // naam-lengte
        ldx #$c0                 // naam op $03C0
        ldy #$03
        jsr $ffbd                // SETNAM
        lda #1
        ldx #8
        ldy #1                   // sa=1 -> laadadres uit bestand ($0801)
        jsr $ffba                // SETLFS
        lda #0
        jsr $ffd5                // LOAD
        bcs !fail+
        lda #$37                 // BASIC+KERNAL+I/O voor de PRG
        sta $01
        cli
        jmp $080d                // start (SYS 2061)
!fail:  jsr cfg_io_end           // OS-toestand herstellen
        jsr spr_CursorInit       // cursor-sprite terug ($0340 overschreven)
        jmp shell_NotFound
}
.const rpStubLen = * - rpStubSrc

//--------------------------------------------------------
// desk_RunPrg - start een standalone PRG (A = prg-index). De PRG laadt
//               op $0801 over de OS heen; lukt het niet, dan PROGRAM NOT
//               FOUND en terug naar het bureaublad. Naam -> $03C0 (petscii),
//               lengte -> $03BF; de keten-stub op $0334 doet de LOAD.
//--------------------------------------------------------
desk_RunPrg:
        tax
        lda deskPrgLen,x
        sta $03bf
        lda deskPrgLo,x
        sta $fb
        lda deskPrgHi,x
        sta $fc
        ldy #0
!cn:    cpy $03bf
        beq !cd+
        lda ($fb),y
        sta $03c0,y
        iny
        bne !cn-
!cd:    ldx #0
!cs:    lda rpStubSrc,x
        sta $0334,x
        inx
        cpx #rpStubLen
        bne !cs-
        jmp $0334

//--------------------------------------------------------
// shell_NotFound - melding als een PRG niet geladen kon worden.
//--------------------------------------------------------
shell_NotFound:
        gfxDrawBox(6, 10, 28, 5, TH_accent)
        lda #<sNotFound
        sta r0
        lda #>sNotFound
        sta r0+1
        lda #9
        sta a0
        lda #11
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
        lda #13
        sta a1
        lda TH_select
        sta a2
        jsr gfx_DrawText
!w:     jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        beq !close+
        cmp #EVT_KEY
        bne !w-
        lda evtA
        cmp #$20
        bne !w-
!close: jmp shell_DrawAll

drawStub:
        rts

//--------------------------------------------------------
// showLoading - "LOADING <app> / PLEASE WAIT" tijdens het laden van
//               een app-overlay van disk. In: X = app index (0-4).
//--------------------------------------------------------
showLoading:
        txa
        pha
        gfxDrawBox(9, 9, 22, 5, LIGHT_GREY)      // rijen 9-13
        lda #<sLoad
        sta r0
        lda #>sLoad
        sta r0+1
        lda #11
        sta a0
        lda #11
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        pla
        tax
        lda labelLo,x
        sta r0
        lda labelHi,x
        sta r0+1
        lda #19
        sta a0
        lda #11
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        lda #<sWait
        sta r0
        lda #>sWait
        sta r0+1
        lda #11
        sta a0
        lda #12
        sta a1
        lda TH_text
        sta a2
        jmp gfx_DrawText

//--------------------------------------------------------
// drawDock - 3 statische iconen (FILES, INET, SETUP) op rij 22-24.
//            dockApp[slot] = app-id; icon/label/kleur zijn per app-id.
//--------------------------------------------------------
.const DOCK_SLOTS = 3
drawDock:
        lda #0
        sta dockI
!lp:    lda dockI
        cmp #DOCK_SLOTS
        bcc !go+
        jmp !done+
!go:    ldx dockI
        lda dockApp,x            // app-id voor dit slot
        sta dApp
        lda dockBase,x
        sta dockTmp
        clc                      // TL (base+2, 22)
        adc #2
        sta a0
        lda #22
        sta a1
        ldx dApp
        lda icon2TL,x
        sta a2
        lda iconColor,x
        sta a3
        jsr gfx_PutChar
        lda dockTmp              // TR (base+3, 22)
        clc
        adc #3
        sta a0
        lda #22
        sta a1
        ldx dApp
        lda icon2TR,x
        sta a2
        lda iconColor,x
        sta a3
        jsr gfx_PutChar
        lda dockTmp              // BL (base+2, 23)
        clc
        adc #2
        sta a0
        lda #23
        sta a1
        ldx dApp
        lda icon2BL,x
        sta a2
        lda iconColor,x
        sta a3
        jsr gfx_PutChar
        lda dockTmp              // BR (base+3, 23)
        clc
        adc #3
        sta a0
        lda #23
        sta a1
        ldx dApp
        lda icon2BR,x
        sta a2
        lda iconColor,x
        sta a3
        jsr gfx_PutChar
        lda dockTmp              // label (base+1, 24)
        clc
        adc #1
        sta a0
        lda #24
        sta a1
        lda dApp
        cmp activeApp
        bne !notact+
        lda TH_select
        jmp !setc+
!notact:
        lda TH_text
!setc:  sta a2
        ldx dApp
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
        // gfxDrawBox maakt de box ondoorzichtig bij FILLED; tekst in themakleur
        gfxDrawBox(1, 1, 14, 6, TH_accent)       // rijen 1-6, kol 1-14
        lda TH_text
        sta menuTxtCol
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
        jsr gfx_DrawText
        lda #<oReset
        sta r0
        lda #>oReset
        sta r0+1
        lda #3
        sta a0
        lda #5
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
        cmp #5
        beq doReset
close:  jmp shell_DrawAll
doHelp: jmp help_Show            // tekent zelf het scherm opnieuw
doDesk: jmp exitToDesktop
doAbout:jmp about_Show
doReset:
        sei
        lda #$37                 // BASIC+KERNAL+I/O inbanken
        sta $01
        jmp ($fffc)             // KERNAL-reset -> terug naar BASIC
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
        // dock: 3 slots (grenzen 14, 26) -> app via dockApp
        lda evtA
        ldx #0
        cmp #14
        bcc !hit+
        inx
        cmp #26
        bcc !hit+
        inx
!hit:   lda dockApp,x
        jmp openApp              // laadt/opent de app (tekent zelf)
!widget:
        // klik in het werkgebied
        lda activeApp
        cmp #$ff
        bne !app+
        jmp desk_Click           // bureaublad -> launcher-icoon
!app:   cmp #0
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
// openApp - open app-id A (0-5). Laadt de overlay (of resident INET),
//           initialiseert en tekent. Paint gaat naar bitmapmodus.
//--------------------------------------------------------
openApp:
        sta activeApp
        cmp #5                   // INET is resident (geen overlay)
        beq !drawit+
        tax                      // apps 0-4: overlay van disk laden
        jsr showLoading
        ldx activeApp
        jsr loadApp
        bcc !loaded+
        lda #$ff                 // laden mislukt -> terug naar desktop
        sta activeApp
        jmp shell_DrawAll
!loaded:
        lda activeApp
        cmp #0                   // File Manager -> directory lezen
        bne !na0+
        jsr fm_Load
        jmp !drawit+
!na0:   cmp #1                   // Editor
        bne !na1+
        jsr ed_Init
        jmp !drawit+
!na1:   cmp #2                   // Paint -> eigen bitmapmodus
        bne !na2+
        jmp paint_Enter          // geen char-redraw
!na2:   cmp #3                   // Calculator
        bne !na3+
        jsr calc_Init
        jmp !drawit+
!na3:   jsr set_Init             // #4 Settings
!drawit:
        jmp shell_DrawAll

//--------------------------------------------------------
// Data
//--------------------------------------------------------
activeApp:   .byte $ff
dockI:       .byte 0
dockTmp:     .byte 0
dApp:        .byte 0
deI:         .byte 0
deCol:       .byte 0
deIcon:      .byte 0
deIcoC:      .byte 0

// ---- bureaublad-launcher: standaard-entries ----
// kind 0 = overlay-app (param = app-id); kind 1 = standalone PRG (param = prg-index)
deskCount:  .byte 4
deskNameLo: .byte <dnEdit, <dnPaint, <dnCalc, <dnCow
deskNameHi: .byte >dnEdit, >dnPaint, >dnCalc, >dnCow
deskKind:   .byte 0, 0, 0, 1
deskParam:  .byte 1, 2, 3, 0
deskIcon:   .byte 111, 115, 119, 107   // 2x2 TL-glyph (edit,paint,calc,folder)
deskIcoCol: .byte WHITE, LIGHT_RED, CYAN, YELLOW
// standalone-PRG-namen (petscii, voor de LOAD)
deskPrgLo:  .byte <pnCow
deskPrgHi:  .byte >pnCow
deskPrgLen: .byte 6
.encoding "petscii_upper"
pnCow:      .text "COWBOY"
.encoding "screencode_upper"
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

// dock: 3 statische slots. dockApp = welke app-id per slot (FILES, INET, SETUP).
dockBase:  .byte 6, 18, 30
dockApp:   .byte 0, 5, 4
// per app-id (0=files 1=edit 2=paint 3=calc 4=setup 5=inet):
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

nDesk:  .text "COMMODORE DESK 64"
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

sDeskHint: .text "CLICK AN ICON TO START AN APP"
           .byte $ff
dnEdit:    .text "EDITOR"
           .byte $ff
dnPaint:   .text "PAINT"
           .byte $ff
dnCalc:    .text "CALC"
           .byte $ff
dnCow:     .text "COWBOY"
           .byte $ff
sNotFound: .text "PROGRAM NOT FOUND"
           .byte $ff
sLoad:     .text "LOADING"
           .byte $ff
sWait:     .text "PLEASE WAIT"
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
oReset: .text "RESET"
        .byte $ff
aLine1: .text "COMMODORE DESK 64"
        .byte $ff
aLine2: .text "VERSION 0.9"
        .byte $ff
aClose: .text "SPACE = CLOSE"
        .byte $ff
