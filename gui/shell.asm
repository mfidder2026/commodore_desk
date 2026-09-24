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
        lda #0
        sta wCounter
        sta wSound
        sta wListTop
        sta wListSel
        lda #$ff
        sta wDlgResult
        lda #0                   // balken standaard verborgen
        sta menuShown
        sta dockShown
        jsr shell_DrawAll
        rts

// shell_Run - hoofdlus.
shell_Run:
!loop:  jsr checkBars
        jsr evt_Poll
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
        jsr drawStatus           // statusbalk blijft altijd zichtbaar
        lda menuShown
        beq !nm+
        jsr drawMenubar
!nm:    lda dockShown
        beq !nd+
        jsr drawDock
!nd:    lda #13
        sta $07f8                // sprite 0 pointer herstellen
        rts

//--------------------------------------------------------
// checkBars - toon/verberg de menubalk (bovenrand) en de dock
//             (onderrand) op basis van de cursorpositie.
//--------------------------------------------------------
checkBars:
        lda crsY
        sec
        sbc #50
        lsr
        lsr
        lsr
        sta cbRow                // cursorrij 0-24
        // menubalk: rij 0
        lda cbRow
        bne !topHide+
        lda menuShown
        bne !bottom+
        lda #1
        sta menuShown
        jsr drawMenubar
        jmp !bottom+
!topHide:
        lda menuShown
        beq !bottom+
        lda #0
        sta menuShown
        jsr clearRow0
!bottom:
        // dock: rij 22-24
        lda cbRow
        cmp #22
        bcc !dockHide+
        lda dockShown
        bne !done+
        lda #1
        sta dockShown
        jsr drawDock
        jmp !done+
!dockHide:
        lda dockShown
        beq !done+
        lda #0
        sta dockShown
        jsr clearDock
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

clearDock:
        lda #0
        sta a0
        lda #22
        sta a1
        lda #40
        sta a2
        lda #3
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
drawStatus:
        lda #21
        sta a0
        lda TH_menubg
        sta a2
        jsr gfx_BarRow
        lda #<sReady
        sta r0
        lda #>sReady
        sta r0+1
        lda #1
        sta a0
        lda #21
        sta a1
        lda TH_menubg
        sta a2
        jsr gfx_DrawTextRev
        lda #<sFree
        sta r0
        lda #>sFree
        sta r0+1
        lda #31
        sta a0
        lda #21
        sta a1
        lda TH_menubg
        sta a2
        jsr gfx_DrawTextRev
        rts

//--------------------------------------------------------
drawContent:
        gfxDrawBox(1, 2, 38, 18, LIGHT_GREY)
        ldx activeApp
        inx
        lda nameLo,x
        sta r0
        lda nameHi,x
        sta r0+1
        lda #3
        sta a0
        lda #3
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
!c:     cmp #2
        bne !d+
        jmp paint_Draw
!d:     cmp #3
        bne !e+
        jmp calc_Draw
!e:     cmp #4
        bne !f+
        jmp set_Draw
!f:     jmp drawStub

drawDesktopContent:
        lda #<sDeskHint
        sta r0
        lda #>sDeskHint
        sta r0+1
        lda #8
        sta a0
        lda #10
        sta a1
        lda #GREY
        sta a2
        jmp gfx_DrawText

drawStub:
        lda #<sStub
        sta r0
        lda #>sStub
        sta r0+1
        lda #10
        sta a0
        lda #10
        sta a1
        lda #GREY
        sta a2
        jmp gfx_DrawText

//--------------------------------------------------------
// drawWidgets - de widget-demo (zonder Cls; ook los aanroepbaar).
//--------------------------------------------------------
drawWidgets:
        // knop TEL OP
        lda #<sTelOp
        sta r0
        lda #>sTelOp
        sta r0+1
        lda #3
        sta a0
        lda #5
        sta a1
        lda #9
        sta a2
        lda #LIGHT_GREY
        sta a3
        jsr btn_Draw
        // teller-label + waarde
        lda #<sAantal
        sta r0
        lda #>sAantal
        sta r0+1
        lda #14
        sta a0
        lda #5
        sta a1
        lda #THEME_TEXT
        sta a2
        jsr gfx_DrawText
        lda #<[SCREEN_RAM + 5*40 + 22]
        sta r4
        lda #>[SCREEN_RAM + 5*40 + 22]
        sta r4+1
        lda wCounter
        jsr num2dec
        // checkbox
        lda #<sGeluid
        sta r0
        lda #>sGeluid
        sta r0+1
        lda #3
        sta a0
        lda #7
        sta a1
        lda wSound
        sta a2
        jsr cb_Draw
        // lijst
        jsr drawList
        // UP / DOWN
        lda #<sUp
        sta r0
        lda #>sUp
        sta r0+1
        lda #24
        sta a0
        lda #9
        sta a1
        lda #4
        sta a2
        lda #LIGHT_GREY
        sta a3
        jsr btn_Draw
        lda #<sDn
        sta r0
        lda #>sDn
        sta r0+1
        lda #24
        sta a0
        lda #11
        sta a1
        lda #4
        sta a2
        lda #LIGHT_GREY
        sta a3
        jsr btn_Draw
        // KEUZE-label + waarde
        lda #<sKeuze
        sta r0
        lda #>sKeuze
        sta r0+1
        lda #24
        sta a0
        lda #13
        sta a1
        lda #THEME_TEXT
        sta a2
        jsr gfx_DrawText
        lda #31
        sta a0
        lda #13
        sta a1
        lda wListSel
        clc
        adc #$30
        sta a2
        lda #THEME_ACCENT
        sta a3
        jsr gfx_PutChar
        // knop DIALOOG
        lda #<sDialoog
        sta r0
        lda #>sDialoog
        sta r0+1
        lda #3
        sta a0
        lda #17
        sta a1
        lda #11
        sta a2
        lda #LIGHT_GREY
        sta a3
        jsr btn_Draw
        jsr drawDlgResult
        rts

//--------------------------------------------------------
// drawList - scrollbare lijst (box 3,9 20x7; 5 zichtbaar).
//--------------------------------------------------------
drawList:
        gfxDrawBox(3, 9, 20, 7, LIGHT_GREY)
        lda #0
        sta lvI
!lp:    lda lvI
        cmp #LIST_VISIBLE
        bcc !cont+
        jmp !done+
!cont:  lda wListTop
        clc
        adc lvI
        sta lvItem
        lda #10
        clc
        adc lvI
        sta lvRow
        lda lvItem
        cmp wListSel
        bne !normal+
        // highlight
        lda #4
        sta a0
        lda lvRow
        sta a1
        lda #18
        sta a2
        lda #1
        sta a3
        lda #$a0
        sta a4
        lda #THEME_SELECT
        sta a5
        jsr gfx_FillRect
        ldx lvItem
        lda itemLo,x
        sta r0
        lda itemHi,x
        sta r0+1
        lda #5
        sta a0
        lda lvRow
        sta a1
        lda #THEME_SELECT
        sta a2
        jsr gfx_DrawTextRev
        jmp !next+
!normal:
        // regel eerst wissen (oude highlight-blokken weg)
        lda #4
        sta a0
        lda lvRow
        sta a1
        lda #18
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda #THEME_DESKTOP_BG
        sta a5
        jsr gfx_FillRect
        ldx lvItem
        lda itemLo,x
        sta r0
        lda itemHi,x
        sta r0+1
        lda #5
        sta a0
        lda lvRow
        sta a1
        lda #THEME_TEXT
        sta a2
        jsr gfx_DrawText
!next:  inc lvI
        jmp !lp-
!done:  rts

//--------------------------------------------------------
drawDlgResult:
        lda #<sDlg
        sta r0
        lda #>sDlg
        sta r0+1
        lda #16
        sta a0
        lda #17
        sta a1
        lda #THEME_TEXT
        sta a2
        jsr gfx_DrawText
        lda wDlgResult
        cmp #$ff
        bne !c1+
        lda #<sResNone
        sta r0
        lda #>sResNone
        sta r0+1
        jmp !draw+
!c1:    cmp #1
        bne !c0+
        lda #<sResOk
        sta r0
        lda #>sResOk
        sta r0+1
        jmp !draw+
!c0:    lda #<sResCancel
        sta r0
        lda #>sResCancel
        sta r0+1
!draw:  lda #21
        sta a0
        lda #17
        sta a1
        lda #THEME_SELECT
        sta a2
        jsr gfx_DrawText
        rts

//--------------------------------------------------------
// drawDock - 5 iconen (rij 22) + labels (rij 23).
//--------------------------------------------------------
drawDock:
        lda #0
        sta dockI
!lp:    lda dockI
        cmp #5
        bcs !done+
        lda dockI
        asl
        asl
        asl
        sta dockTmp
        clc
        adc #3
        sta a0
        lda #22
        sta a1
        ldx dockI
        lda iconGlyph,x
        sta a2
        lda iconColor,x
        sta a3
        jsr gfx_PutChar
        lda dockTmp
        clc
        adc #1
        sta a0
        lda #23
        sta a1
        lda dockI
        cmp activeApp
        bne !notact+
        lda TH_select
        jmp !setc+
!notact:
        lda #THEME_TEXT
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
        lda #$ff
        sta activeApp
        jmp shell_DrawAll

//--------------------------------------------------------
// onMouseDown - klik afhandelen (evtA=kol, evtB=rij).
//--------------------------------------------------------
onMouseDown:
        lda evtB
        cmp #22
        bcc !widget+
        // dock -> app wisselen
        lda evtA
        lsr
        lsr
        lsr
        cmp #5
        bcs !done+
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
!na1:   cmp #2                   // Paint
        bne !na2+
        jsr paint_Init
        jmp !drawit+
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
// handleWidgetClick - klik-afhandeling voor de widgets.
//--------------------------------------------------------
handleWidgetClick:
        // TEL OP
        lda #3
        sta a0
        lda #5
        sta a1
        lda #9
        sta a2
        jsr btn_HitTest
        bcc !n1+
        inc wCounter
        jmp !redraw+
!n1:    // checkbox
        lda #3
        sta a0
        lda #7
        sta a1
        jsr cb_HitTest
        bcc !n2+
        lda wSound
        eor #1
        sta wSound
        jmp !redraw+
!n2:    // UP
        lda #24
        sta a0
        lda #9
        sta a1
        lda #4
        sta a2
        jsr btn_HitTest
        bcc !n3+
        lda wListTop
        beq !done+
        dec wListTop
        jmp !redraw+
!n3:    // DOWN
        lda #24
        sta a0
        lda #11
        sta a1
        lda #4
        sta a2
        jsr btn_HitTest
        bcc !n4+
        lda wListTop
        cmp #[LIST_COUNT-LIST_VISIBLE]
        bcs !done+
        inc wListTop
        jmp !redraw+
!n4:    // lijst-item (cols4-21, rows10-14)
        lda evtB
        cmp #10
        bcc !n5+
        cmp #15
        bcs !n5+
        lda evtA
        cmp #4
        bcc !n5+
        cmp #22
        bcs !n5+
        lda evtB
        sec
        sbc #10
        clc
        adc wListTop
        cmp #LIST_COUNT
        bcs !n5+
        sta wListSel
        jmp !redraw+
!n5:    // DIALOOG
        lda #3
        sta a0
        lda #17
        sta a1
        lda #11
        sta a2
        jsr btn_HitTest
        bcc !done+
        jsr dlg_Show
        sta wDlgResult
        jsr shell_DrawAll        // dialoog overschreef het scherm
        rts
!redraw:
        jsr drawWidgets
!done:  rts

//--------------------------------------------------------
// Data
//--------------------------------------------------------
activeApp:   .byte $ff
dockI:       .byte 0
dockTmp:     .byte 0
menuShown:   .byte 0
dockShown:   .byte 0
cbRow:       .byte 0
wCounter:    .byte 0
wSound:      .byte 0
wListTop:    .byte 0
wListSel:    .byte 0
wDlgResult:  .byte $ff
lvI:         .byte 0
lvItem:      .byte 0
lvRow:       .byte 0

menuLo: .byte <mDesk, <mFiles, <mEdit, <mPaint, <mCalc, <mSet
menuHi: .byte >mDesk, >mFiles, >mEdit, >mPaint, >mCalc, >mSet
nameLo: .byte <nDesk, <nFiles, <nEdit, <nPaint, <nCalc, <nSet
nameHi: .byte >nDesk, >nFiles, >nEdit, >nPaint, >nCalc, >nSet

iconGlyph: .byte ICON_FILES, ICON_EDIT, ICON_PAINT, ICON_CALC, ICON_SETUP
iconColor: .byte ORANGE, WHITE, LIGHT_RED, CYAN, LIGHT_GREEN
labelLo:   .byte <lFiles, <lEdit, <lPaint, <lCalc, <lSet
labelHi:   .byte >lFiles, >lEdit, >lPaint, >lCalc, >lSet

itemLo: .byte <it1,<it2,<it3,<it4,<it5,<it6,<it7,<it8
itemHi: .byte >it1,>it2,>it3,>it4,>it5,>it6,>it7,>it8

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

sReady: .text "READY"
        .byte $ff
sFree:  .text "38K FREE"
        .byte $ff
sDeskHint: .text "TOP EDGE=MENU  BOTTOM=DOCK"
           .byte $ff
sStub:     .text "UNDER CONSTRUCTION"
           .byte $ff

sTelOp:  .text "TEL OP"
         .byte $ff
sAantal: .text "AANTAL: 000"
         .byte $ff
sGeluid: .text "GELUID"
         .byte $ff
sUp:     .text "UP"
         .byte $ff
sDn:     .text "DN"
         .byte $ff
sKeuze:  .text "KEUZE:"
         .byte $ff
sDialoog:.text "DIALOOG"
         .byte $ff
sDlg:    .text "DLG:"
         .byte $ff
sResNone:   .text "-       "
            .byte $ff
sResOk:     .text "OK      "
            .byte $ff
sResCancel: .text "ANNULEER"
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

it1: .text "ITEM 1"
     .byte $ff
it2: .text "ITEM 2"
     .byte $ff
it3: .text "ITEM 3"
     .byte $ff
it4: .text "ITEM 4"
     .byte $ff
it5: .text "ITEM 5"
     .byte $ff
it6: .text "ITEM 6"
     .byte $ff
it7: .text "ITEM 7"
     .byte $ff
it8: .text "ITEM 8"
     .byte $ff
