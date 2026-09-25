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
!loop:  lda activeApp           // Paint = volledig-scherm bitmap: geen balken
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
// Win95-layout (40x25):
//   rij 0      menubalk (klapt uit) / anders grijze desktop
//   rij 1      titelbalk van het venster, sluitknop op kol 37
//   rij 2-18   vensterinhoud (kol 2-37), kader op kol 1 en 38
//   rij 19     onderrand van het venster
//   rij 20     grijze desktop (hier wisselt de raster-split de achtergrond)
//   rij 21-24  dock-plank (kol DOCK_L..DOCK_R) op lichtgrijs
.const WIN_CLOSE_COL = 38
.const DOCK_L = 10
.const DOCK_R = 30

shell_DrawAll:
        lda TH_deskbg
        sta a2
        jsr gfx_Cls
        jsr drawDesktopBg        // grijze desktop + dock-plank
        jsr win_Main             // venster: titelbalk, sluitknop, kader
        jsr drawContent
        jsr drawDock             // dock is statisch (macOS-stijl): altijd zichtbaar
        lda menuShown            // alleen de bovenste menubalk klapt in/uit
        beq !nm+
        jsr drawMenubar
!nm:    lda #13
        sta $07f8                // sprite 0 pointer herstellen
        rts

//--------------------------------------------------------
// drawDesktopBg - grijze desktop rond het venster + de dock-plank.
//--------------------------------------------------------
drawDesktopBg:
        lda #0                   // rij 0 en rij 20 volledig grijs
        sta a0
        lda TH_desktop
        sta a2
        jsr gfx_BarRow
        lda #20
        sta a0
        lda TH_desktop
        sta a2
        jsr gfx_BarRow
        ldx #1                   // kolom 0 en 39, rijen 1-19
!lp:    stx dbI
        lda #0
        sta a0
        stx a1
        lda #$a0
        sta a2
        lda TH_desktop
        sta a3
        jsr gfx_PutChar
        lda #39
        sta a0
        lda dbI
        sta a1
        lda #$a0
        sta a2
        lda TH_desktop
        sta a3
        jsr gfx_PutChar
        ldx dbI
        inx
        cpx #20
        bne !lp-
        ldx #21                  // dock-rijen: links/rechts van de plank grijs
!dr:    stx dbI
        lda #0
        sta a0
        stx a1
        lda #DOCK_L
        sta a2
        lda #1
        sta a3
        lda #$a0
        sta a4
        lda TH_desktop
        sta a5
        jsr gfx_FillRect
        lda #DOCK_R+1
        sta a0
        lda dbI
        sta a1
        lda #[39-DOCK_R]
        sta a2
        lda #1
        sta a3
        lda #$a0
        sta a4
        lda TH_desktop
        sta a5
        jsr gfx_FillRect
        ldx dbI
        inx
        cpx #25
        bne !dr-
        lda #DOCK_L              // witte bovenrand van de plank (rij 21)
        sta a0
        lda #21
        sta a1
        lda #[DOCK_R-DOCK_L+1]
        sta a2
        lda #1
        sta a3
        lda #GL_HILITE
        sta a4
        lda #WHITE
        sta a5
        jmp gfx_FillRect

//--------------------------------------------------------
// win_Main - het hoofdvenster: titel = naam van de actieve app. Het
//            bureaublad (Program Manager) heeft geen sluitknop.
//--------------------------------------------------------
win_Main:
        lda activeApp
        cmp #$ff
        bne !app+
        lda #1
        sta dlgNoClose
!app:   ldx activeApp
        inx
        lda nameLo,x
        sta r0
        lda nameHi,x
        sta r0+1
        lda #1
        sta a0
        lda #1
        sta a1
        lda #38
        sta a2
        lda #19
        sta a3
        jsr dlg_Draw
        lda #0
        sta dlgNoClose
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

clearRow0:                       // verborgen menubalk = grijze desktop
        lda #0
        sta a0
        lda TH_desktop
        sta a2
        jmp gfx_BarRow

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
        // De app-naam staat in de titelbalk (win_Main); hier alleen de inhoud.
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

// drawDesktopContent - launcher-raster (ingebouwde apps + gebruikers-
// programma's) uit deskapps.asm, plus de hint-regel.
drawDesktopContent:
        jmp da_DrawEntries

//--------------------------------------------------------
// desk_Click - klik op het bureaublad -> launcher (deskapps.asm).
//--------------------------------------------------------
desk_Click:
        jmp da_Click

// retStubSrc: RESTORE-terugkeerhandler, geassembleerd voor $C000 (een
// gebied dat gewone PRG's met rust laten). De launcher kopieert dit hierheen
// en wijst de NMI-vector $0318/$0319 erop, VOORDAT het PRG start. Een net
// PRG draait met de KERNAL ingebankt, dus RESTORE -> $FE43 -> jmp ($0318) ->
// deze handler, die CD64 herlaadt. Zo keert elk PRG terug ZONDER code-aanpassing.
retStubSrc:
.pseudopc $c000 {
retStub:
        sei
        lda #$37                 // KERNAL+BASIC+I/O inbanken voor LOAD
        sta $01
        lda #$00
        sta $9d                  // KERNAL-laadmeldingen uit
        lda #retNameEnd-retName
        ldx #<retName
        ldy #>retName
        jsr $ffbd                // SETNAM "CD64"
        lda #1
        ldx #8
        ldy #1
        jsr $ffba                // SETLFS 1,8,1
        lda #0
        jsr $ffd5                // LOAD CD64 -> $0801 (raakt $C000 niet)
        jmp $0810                // start bureaublad (kernel_Init)
.encoding "petscii_upper"
retName:    .text "CD64"
retNameEnd:
.encoding "screencode_upper"
}
.const retStubLen = * - retStubSrc

// run-stub: geassembleerd voor $0334. Laadt de PRG en start 'm (SYS 2061),
// of valt bij mislukking netjes terug in de OS (shell_NotFound).
// sysRunSrc: SYS-adresparser, geassembleerd voor $C040 (veilig RAM). Leest
// de SYS-instructie uit de BASIC-regel van het geladen PRG op $0801 en
// springt daarheen. Zo hoeft de launcher het startadres niet te hardcoden
// (cowboy = SYS 2062, scrsaver kan anders zijn, enz.).
sysRunSrc:
.pseudopc $c040 {
sysRun: ldx #0
!fs:    lda $0801,x              // SYS-token ($9E) zoeken
        cmp #$9e
        beq !gs+
        inx
        cpx #$10
        bne !fs-
        jmp $080d                // geen SYS -> standaardingang
!gs:    inx
!sd:    lda $0801,x              // eerste cijfer zoeken
        cmp #$30
        bcc !sk+
        cmp #$3a
        bcc !gd+
!sk:    inx
        cpx #$20
        bne !sd-
        jmp $080d
!gd:    lda #0                   // decimaal adres -> $fb/$fc
        sta $fb
        sta $fc
!pl:    lda $0801,x
        cmp #$30
        bcc !run+
        cmp #$3a
        bcs !run+
        sec
        sbc #$30
        pha                      // cijfer bewaren
        lda $fb                  // addr *= 10  (x4 + x1, dan x2)
        sta $fd
        lda $fc
        sta $fe
        asl $fb
        rol $fc
        asl $fb
        rol $fc
        lda $fb
        clc
        adc $fd
        sta $fb
        lda $fc
        adc $fe
        sta $fc
        asl $fb
        rol $fc
        pla                      // + cijfer
        clc
        adc $fb
        sta $fb
        lda $fc
        adc #0
        sta $fc
        inx
        jmp !pl-
!run:   jmp ($00fb)              // spring naar het geparste SYS-adres
}
.const sysRunLen = * - sysRunSrc

// run-stub: klein, geassembleerd voor $0334. Laadt de PRG en geeft de
// besturing aan de SYS-parser op $C040, of valt bij mislukking netjes
// terug in de OS (shell_NotFound).
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
        jmp sysRun               // SYS-adres parsen en starten ($C040)
!fail:  jsr cfg_io_end           // OS-toestand herstellen
        jsr spr_CursorInit       // cursor-sprite terug ($0340 overschreven)
        jmp shell_NotFound
}
.const rpStubLen = * - rpStubSrc

//--------------------------------------------------------
// launchCommon - start het PRG waarvan de naam al op $03C0 (petscii) en
//                de lengte op $03BF staat. Installeert de RESTORE-
//                terugkeerhandler ($C000) + SYS-parser ($C040), kopieert
//                de run-stub naar $0334 en start die. Lukt het laden niet,
//                dan valt de stub terug op shell_NotFound.
//--------------------------------------------------------
launchCommon:
        lda #0
        sta $d015                // cursor-sprite uit (geen garbage over het PRG)
        // RESTORE-terugkeerhandler naar $C000 kopiëren en NMI-vector erop wijzen
        ldx #0
!rc:    lda retStubSrc,x
        sta $c000,x
        inx
        cpx #retStubLen
        bne !rc-
        // SYS-adresparser naar $C040 kopiëren
        ldx #0
!pc:    lda sysRunSrc,x
        sta $c040,x
        inx
        cpx #sysRunLen
        bne !pc-
        lda #<$c000
        sta $0318                // NMI (RESTORE)  -> retStub
        lda #>$c000
        sta $0319
        ldx #0
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
        lda #<nDesk              // Win95-melding: titel, tekst, OK-knop
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
        lda #<sNotFound
        sta r0
        lda #>sNotFound
        sta r0+1
        lda #11
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

drawStub:
        rts

//--------------------------------------------------------
// showLoading - "LOADING <app> / PLEASE WAIT" tijdens het laden van
//               een app-overlay van disk. In: X = app index (0-4).
//--------------------------------------------------------
showLoading:
        txa
        pha
        gfxDrawBoxM(9, 10, 22, 4, TH_text)     // rijen 10-13 (2 tekstregels)
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
        lda dockTmp              // label (base+1, 24) in balktekstkleur
        clc
        adc #1
        sta a0
        lda #24
        sta a1
        lda TH_bartext
        sta a2
        ldx dApp
        lda labelLo,x
        sta r0
        lda labelHi,x
        sta r0+1
        lda dApp                 // actieve app: label gemarkeerd (reverse)
        cmp activeApp
        bne !notact+
        jsr gfx_DrawTextRev
        jmp !nx+
!notact:
        jsr gfx_DrawText
!nx:    inc dockI
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
        lda TH_text
        sta menuTxtCol
        lda activeApp
        cmp #$ff
        bne !app+
        // ---- bureaublad-menu: TOEVOEGEN/BEWERKEN/VERWIJDEREN + rest ----
        lda #1
        sta menuDesk
        gfxDrawBoxM(1, 1, 18, 8, TH_text)       // rijen 1-8, kol 1-18
        lda #6
        sta menuN
        jmp !draw+
!app:   lda #0
        sta menuDesk
        gfxDrawBoxM(1, 1, 14, 6, TH_text)       // rijen 1-6, kol 1-14
        lda #4
        sta menuN
!draw:  lda #0
        sta menuI
!lp:    ldx menuI
        lda menuDesk
        beq !ap+
        lda dmLo,x
        sta r0
        lda dmHi,x
        sta r0+1
        jmp !p+
!ap:    lda amLo,x
        sta r0
        lda amHi,x
        sta r0+1
!p:     lda #3
        sta a0
        lda menuI
        clc
        adc #2
        sta a1
        lda menuTxtCol
        sta a2
        jsr gfx_DrawText
        inc menuI
        lda menuI
        cmp menuN
        bne !lp-
        rts

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
        lda evtA                 // buiten de menukolommen -> sluiten
        cmp #1
        bcc close
        cmp #19
        bcs close
        lda menuDesk
        beq appDisp
        // bureaublad: rij 2..7 -> item 0..5
        lda evtB
        sec
        sbc #2
        bcc close
        cmp #0
        beq mAdd
        cmp #1
        beq mEdit
        cmp #2
        beq mDel
        cmp #3
        beq doHelp
        cmp #4
        beq doAbout
        cmp #5
        beq doReset
        jmp close
appDisp:
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
mAdd:   ldx #0
        jmp tool_Run
mEdit:  ldx #1
        jmp tool_Run
mDel:   ldx #2
        jmp tool_Run
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
// tool_Run - launcher-beheer (overlay DESKTOOL) laden en starten.
//            X = 0 toevoegen, 1 bewerken, 2 verwijderen.
//--------------------------------------------------------
tool_Run:
        stx toolFn
        ldx #6
        jsr showLoading          // "LOADING TOOLS"
        ldx #6
        jsr loadApp              // DESKTOOL -> $8000
        bcc !ok+
        jmp shell_DrawAll        // laden mislukt
!ok:    jsr da_Redraw            // laadvenster weg
        lda toolFn
        beq !add+
        cmp #1
        beq !edit+
        jmp da_DeleteProgram
!add:   jmp da_AddProgram
!edit:  jmp da_EditProgram
toolFn: .byte 0

// menukeuze-tabellen
dmLo: .byte <oAdd, <oEditP, <oDel, <oHelp, <oAbout, <oReset
dmHi: .byte >oAdd, >oEditP, >oDel, >oHelp, >oAbout, >oReset
amLo: .byte <oHelp, <oDesk, <oAbout, <oReset
amHi: .byte >oHelp, >oDesk, >oAbout, >oReset

//--------------------------------------------------------
// about_Show - "over deze OS"-dialoog (Win95-stijl: titelbalk, sluitknop,
//              OK-knop; ESC/SPATIE/RETURN sluiten ook).
//--------------------------------------------------------
about_Show:
        lda #<oAbout
        sta r0
        lda #>oAbout
        sta r0+1
        lda #7
        sta a0
        lda #7
        sta a1
        lda #26
        sta a2
        lda #9
        sta a3
        jsr dlg_Draw             // rijen 7-15
        lda #<aLine1
        sta r0
        lda #>aLine1
        sta r0+1
        lda #11
        sta a0
        lda #9
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        lda #<aLine2
        sta r0
        lda #>aLine2
        sta r0+1
        lda #11
        sta a0
        lda #11
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        lda #18
        sta a0
        lda #13
        sta a1
        jsr dlg_OkButton
        jsr dlg_WaitClose
        jmp shell_DrawAll

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
        cmp #1                   // titelbalk: alleen de sluitknop doet iets
        bne !nt+
        lda evtA
        cmp #WIN_CLOSE_COL
        bne !rt+
        lda activeApp
        cmp #$ff
        beq !rt+                 // bureaublad heeft geen sluitknop
        jmp exitToDesktop
!nt:    cmp #21
        bcs !dock+
        cmp #19                  // onderrand + grijze rij 20: niets
        bcs !rt+
        jmp !widget+
!dock:  // dock-plank: 3 slots (kol 11-16, 17-22, 23-29) -> app via dockApp
        lda evtA
        cmp #11
        bcc !rt+
        cmp #30
        bcs !rt+
        ldx #0
        cmp #17
        bcc !hit+
        inx
        cmp #23
        bcc !hit+
        inx
!hit:   lda dockApp,x
        jmp openApp              // laadt/opent de app (tekent zelf)
!rt:    rts
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
        bne !w4+
        jmp set_Click
!w4:    cmp #5
        bne !done+
        jmp inet_Click
!done:  rts

//--------------------------------------------------------
// openApp - open app-id A (0-5). Laadt de overlay van disk,
//           initialiseert en tekent. Paint gaat naar bitmapmodus.
//--------------------------------------------------------
openApp:
        sta activeApp
        tax                      // overlay van disk laden
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
!na3:   cmp #4                   // Settings
        bne !na4+
        jsr set_Init
        jmp !drawit+
!na4:   jsr inet_Init            // #5 INET: netwerkhardware zoeken
!drawit:
        jmp shell_DrawAll

//--------------------------------------------------------
// Data
//--------------------------------------------------------
activeApp:   .byte $ff
cartMode:    .byte 0             // 1 = cart-build (I/O-ruimte niet aanraken)
dockI:       .byte 0
dockTmp:     .byte 0
dApp:        .byte 0
deI:         .byte 0
deCol:       .byte 0
deRow:       .byte 0
deIcon:      .byte 0
deIcoC:      .byte 0

// ---- bureaublad-launcher: vaste ingebouwde apps (EDITOR/PAINT/CALC) ----
// De gebruikersprogramma's staan als records in deskapps.asm.
biCount:    .byte 3
biNameLo:   .byte <dnEdit, <dnPaint, <dnCalc
biNameHi:   .byte >dnEdit, >dnPaint, >dnCalc
biIcon:     .byte 111, 115, 119        // 2x2 TL-glyph
biIcoCol:   .byte WHITE, LIGHT_RED, CYAN
biApp:      .byte 1, 2, 3              // overlay-app-id
// 20 kies-iconen: eigen 8x8-iconen op charset-codes 64..83 (zie font.asm)
userIconGlyphs:
        .byte 64, 65, 66, 67, 68, 69, 70, 71, 72, 73
        .byte 74, 75, 76, 77, 78, 79, 80, 81, 82, 83
menuShown:   .byte 0
cbRow:       .byte 0
menuTxtCol:  .byte 0
menuI:       .byte 0
menuN:       .byte 0
menuDesk:    .byte 0
// gedeelde scratch-vars (o.a. File Manager-lijst)
lvI:         .byte 0
lvItem:      .byte 0
lvRow:       .byte 0

menuLo: .byte <mDesk, <mFiles, <mEdit, <mPaint, <mCalc, <mSet, <mInet
menuHi: .byte >mDesk, >mFiles, >mEdit, >mPaint, >mCalc, >mSet, >mInet
nameLo: .byte <nDesk, <nFiles, <nEdit, <nPaint, <nCalc, <nSet, <nInet
nameHi: .byte >nDesk, >nFiles, >nEdit, >nPaint, >nCalc, >nSet, >nInet

// dock: 3 statische slots. dockApp = welke app-id per slot (FILES, INET, SETUP).
// Mac-achtige dock-plank (kol DOCK_L..DOCK_R): iconen op base+2/+3,
// label op base+1. Klikzones: kol 11-16, 17-22, 23-29.
dockBase:  .byte 11, 17, 23
dockApp:   .byte 0, 5, 4
// per app-id (0=files 1=edit 2=paint 3=calc 4=setup 5=inet); goed
// zichtbaar op de lichtgrijze plank:
iconColor: .byte ORANGE, WHITE, LIGHT_RED, CYAN, DARK_GREY, BLUE
dbI:       .byte 0
// 2x2 dock-iconen: glyphcodes per kwadrant (TL/TR/BL/BR)
icon2TL:   .byte 107, 111, 115, 119, 123, 102
icon2TR:   .byte 108, 112, 116, 120, 124, 103
icon2BL:   .byte 109, 113, 117, 121, 125, 104
icon2BR:   .byte 110, 114, 118, 122, 126, 105
labelLo:   .byte <lFiles, <lEdit, <lPaint, <lCalc, <lSet, <lInet, <lTool
labelHi:   .byte >lFiles, >lEdit, >lPaint, >lCalc, >lSet, >lInet, >lTool

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

dnEdit:    .text "EDITOR"
           .byte $ff
dnPaint:   .text "PAINT"
           .byte $ff
dnCalc:    .text "CALC"
           .byte $ff
sNotFound: .text "PROGRAM NOT FOUND"
           .byte $ff
sLoad:     .text "LOADING"
           .byte $ff
sWait:     .text "PLEASE WAIT"
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
lTool:  .text "TOOLS"
        .byte $ff

// uitklapmenu + about
oAdd:   .text "ADD PROGRAM"
        .byte $ff
oEditP: .text "EDIT PROGRAM"
        .byte $ff
oDel:   .text "DELETE PROGRAM"
        .byte $ff
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
aLine2: .text "VERSION 1.0"
        .byte $ff
aClose: .text "SPACE = CLOSE"
        .byte $ff
