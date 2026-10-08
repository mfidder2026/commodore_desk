#importonce
//========================================================
// gui/shell.asm - desktop-shell + widget-demo (Fase 5 + 6)
// Commodore Desk 64
//
// Bureaublad in Win95-stijl: vaste menubalk met uitklapmenu's en app-
// knoppen, één groot venster en een statusbalk met datum en tijd.
//========================================================

.const LIST_COUNT   = 8
.const LIST_VISIBLE = 5

// shell_Init - begintoestand.
shell_Init:
        lda #$ff
        sta activeApp
        jsr shell_DrawAll
        rts

// shell_Run - hoofdlus.
shell_Run:
!loop:  lda activeApp           // Paint = volledig-scherm bitmap: geen balken
        cmp #2
        bne !bars+
        jsr paint_Live           // sleep-tekenen zolang de knop ingedrukt is
        jmp !ev+
!bars:  jsr clk_Poll             // statusbalk: datum/tijd bijwerken
        jsr ss_Poll              // screensaver
        jsr ov_Idle              // app-PRG: animatie e.d. (ovIdle)
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
!notExit:                        // (F1 = hulp: al in evt_Poll afgehandeld)
        jsr appKey               // editor/chat typen zelf (ook spatie)
        bcs !loop-
!notEd: lda evtA                 // SPACE or RETURN elsewhere = click at cursor
        cmp #$20
        beq !click+
        cmp #$80
        bne !loop-
!click: jsr cursorToCell
        jsr onMouseDown
        jmp !loop-

//--------------------------------------------------------
// Win95-layout (40x25), zie WIN_* in layout.inc:
//   rij 0      menubalk: CD64 en DESKTOP klappen uit, FILES/INET/SETUP
//   rij 1      titelbalk van het venster, sluitknop op kol 38
//   rij 2-22   vensterinhoud (kol 2-37), kader op kol 1 en 38
//   rij 23     onderrand van het venster
//   rij 24     statusbalk met datum en tijd
.const WIN_CLOSE_COL = 38
// BBS-overlay (apart geassembleerd, bbs_main.asm): sprongtabel op $8000
.label BBS_INIT  = $8000
.label BBS_DRAW  = $8003
.label BBS_CLICK = $8006
.label BBS_KEY   = $8009
// EMAIL-overlay (email_main.asm): zelfde sprongtabel, app 9 en 10
.label EMAIL_INIT  = $8000
.label EMAIL_DRAW  = $8003
.label EMAIL_CLICK = $8006
.label EMAIL_KEY   = $8009
// TIME-overlay (time_main.asm): zelfde sprongtabel, app 12, plus AUTO
.label TIME_AUTO   = $800c
// CALENDAR-overlay (calendar_main.asm): app 16, plus REMIND
.label CAL_REMIND  = $800c
// SYSTEM-uitklapmenu: globale itemnummers (zie miLo)
.const MI_SETTINGS  = 7
.const MI_NETWORK   = 8
.const MI_EMAIL     = 9
.const MI_TIME      = 10

shell_DrawAll:
        lda TH_deskbg
        sta a2
        jsr gfx_Cls
        jsr drawDesktopBg        // grijze desktop naast het venster
        jsr win_Main             // venster: titelbalk, sluitknop, kader
        jsr drawContent
        jsr drawMenubar
        jsr drawStatus
        lda #13
        sta $07f8                // sprite 0 pointer herstellen
        rts

//--------------------------------------------------------
// drawDesktopBg - grijze kolommen 0 en 39 naast het venster.
//--------------------------------------------------------
drawDesktopBg:
        ldx #1
!lp:    stx dbI
        lda #0
        sta a0
        stx a1
        lda stDeskFill           // (STONE-stijl: ruitjes)
        sta a2
        lda TH_desktop
        sta a3
        jsr gfx_PutChar
        lda #39
        sta a0
        jsr gfx_PutChar          // a1-a3 zijn nog intact
        ldx dbI
        inx
        cpx #STATUS_ROW
        bne !lp-
        lda activeApp            // STONE-bureaublad: de strook rechts
        cmp #$ff
        bne !r+
        lda CFG_strip            // (iconen aan in SETTINGS)
        and #7
        beq !r+
        jmp da_Strip
!r:     rts

// drawStatus - statusbalk (rij 24) met datum en tijd rechts.
drawStatus:
        lda #STATUS_ROW
        sta a0
        lda TH_menubg
        sta a2
        jsr gfx_BarRow
        lda helpOk               // "F1=HELP" links als er hulp is
        beq !+
        lda #<sF1Help
        sta r0
        lda #>sF1Help
        sta r0+1
        lda #1
        sta a0
        lda #STATUS_ROW
        sta a1
        lda TH_menubg
        sta a2
        jsr gfx_DrawTextRev
!:
        jsr clk_Read
        jmp clk_Draw

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
        ldx #38                  // STONE-bureaublad: smaller, rechts de
        lda activeApp            // iconen DRIVE/PRINTER/TRASH
        cmp #$ff
        bne !w+
        lda CFG_strip
        and #7
        beq !w+
        ldx #33
!w:     stx a2
        lda #WIN_FRAME_BOT
        sta a3
        jsr dlg_Draw
        lda #0
        sta dlgNoClose
        rts

//--------------------------------------------------------
// drawMenubar - vaste menubalk. De knop van het actieve venster staat
//               "ingedrukt" (niet-reverse: vensterkleur achter de tekst).
//--------------------------------------------------------
.const MB_ITEMS = 4
drawMenubar:
        lda #0
        sta a0
        lda TH_menubg
        sta a2
        jsr gfx_BarRow
        ldx #0
!lp:    stx menuI
        lda mbStrLo,x
        sta r0
        lda mbStrHi,x
        sta r0+1
        lda mbCol,x
        sta a0
        lda #0
        sta a1
        lda TH_menubg
        sta a2
        lda mbApp,x              // "ingedrukt" als een van de twee
        cmp activeApp            // apps van deze knop open is
        beq !act+
        lda mbApp2,x
        cmp activeApp
        beq !act+
        jsr gfx_DrawTextRev
        jmp !nx+
!act:   jsr gfx_DrawText
!nx:    ldx menuI
        inx
        cpx #MB_ITEMS
        bne !lp-
        lda stStone               // STONE: lijntjes tussen de menu's
        beq !r+
        ldx #0
!sp:    stx menuI
        lda mbEnd,x
        sec
        sbc #1
        sta a0
        lda #0
        sta a1
        lda #FR_V
        sta a2
        lda TH_menubg
        sta a3
        jsr gfx_PutChar
        ldx menuI
        inx
        cpx #MB_ITEMS-1
        bne !sp-
!r:     rts

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
        bne !e3+
        jmp inet_Draw
!e3:    cmp #6
        bne !e4+
        jmp ping_Draw
!e4:    cmp #7
        bne !e5+
        jmp chat_Draw
!e5:    cmp #8
        bne !e6+
        jmp BBS_DRAW
!e6:    jsr ovJT                 // EMAIL, TIME, RADIO, ...: sprongtabel $8000
        bcc !e7+
        jmp EMAIL_DRAW
!e7:    cmp #11                  // SID PLAYER
        bne !f+
        jmp sp_Draw
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
// (het ene PRG heeft SYS 2061, een ander SYS 2062, enz.).
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
!run:   jsr !go+                 // als subroutine: een RTS van het
        jmp $c000                // programma brengt ons terug naar CD64
!go:    jmp ($00fb)              // spring naar het geparste SYS-adres
}
.const sysRunLen = * - sysRunSrc
.assert "SYS-parser blijft onder $C0B4 (daarboven Core-buffers)", $c040 + sysRunLen <= $c0b4, true

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
        ldx $03be                // device (8, of de drive uit de File Manager)
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
        jmp rpFail               // (verder in de Core: zie daar)
}
.const rpStubLen = * - rpStubSrc

// rpFail - laden mislukt: cursor-sprite terug ($0340 is overschreven), onze
//          tekenset weer aan, het bureaublad (launch_Screen wiste het) en de
//          melding. Niet in de stub zelf: die staat op $0334-, en
//          spr_CursorInit schrijft over $0340- heen (dan liep de C64 vast).
rpFail: jsr spr_CursorInit
        lda #$1e                 // scherm $0400, charset $3800 (font_Init)
        sta VIC_MEM
        jsr shell_DrawAll
        jmp shell_NotFound

//--------------------------------------------------------
// launch_Screen - leeg scherm in de achtergrondkleur van het thema met in
//   het midden "LOADING <naam> please wait" (naam in r0) in de gewone
//   Commodore-letters (ROM-set, hoofd/kleine letters). Het PRG dat daarna
//   laadt, overschrijft onze charset op $3800: zo blijft het scherm rustig.
//--------------------------------------------------------
launch_Screen: {
        lda #0
        sta $d015                // muispijl uit
        ldx #0
cl:     lda #$20
        sta SCREEN_RAM,x
        sta SCREEN_RAM+$100,x
        sta SCREEN_RAM+$200,x
        sta SCREEN_RAM+$2e8,x
        lda TH_text
        sta COLOR_RAM,x
        sta COLOR_RAM+$100,x
        sta COLOR_RAM+$200,x
        sta COLOR_RAM+$2e8,x
        inx
        bne cl
        lda TH_border
        sta BORDER_COL
        lda TH_deskbg
        sta BG_COL0
        lda #$17                 // ROM-tekenset met kleine letters
        sta VIC_MEM
        ldx #0                   // regel opbouwen: LOADING + naam + please wait
        ldy #0
l1:     lda lsLoad,y
        beq nm
        sta lsBuf,x
        inx
        iny
        bne l1
nm:     ldy #0
n1:     lda (r0),y
        cmp #$ff
        beq pw
        cmp #$01                 // letters -> hoofdletters in de kleine-letterset
        bcc n2
        cmp #$1b
        bcs n2
        ora #$40
n2:     sta lsBuf,x
        inx
        iny
        cpy #12
        bne n1
pw:     ldy #0
p1:     lda lsWait,y
        beq ce
        sta lsBuf,x
        inx
        iny
        bne p1
ce:     stx lsLen                // gecentreerd op rij 12
        lda #40
        sec
        sbc lsLen
        lsr
        tay
        ldx #0
wr:     lda lsBuf,x
        sta SCREEN_RAM+12*40,y
        iny
        inx
        cpx lsLen
        bne wr
        rts
.encoding "screencode_mixed"
lsLoad: .text "LOADING "
        .byte 0
lsWait: .text " please wait"
        .byte 0
.encoding "screencode_upper"
}
lsLen:  .byte 0
.label lsBuf = $c490            // 40 bytes (vrij RAM, niet in de Core)

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
        lda #$17                 // ROM-tekenset (hoofd/kleine letters): het PRG
        sta $d018                // overschrijft vaak onze RAM-set op $3800
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
        sta $0302                // BASIC-hoofdlus (IMAIN) -> retStub: een
        lda #>$c000              // programma dat naar READY springt komt
        sta $0319                // zo ook terug in CD64
        sta $0303
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
        lda #<sNotFound
        sta r0
        lda #>sNotFound
        sta r0+1
// msg_Show - Win95-melding: titel, tekst (r0), OK-knop.
msg_Show:
        lda r0
        sta msgPtr
        lda r0+1
        sta msgPtr+1
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
        lda msgPtr
        sta r0
        lda msgPtr+1
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
        lda labelLo,x
        sta r0
        lda labelHi,x
        sta r0+1
// showLoadName - idem met de naam in r0 (bv. een gebruikersprogramma).
showLoadName:
        lda r0
        pha
        lda r0+1
        pha
        lda #4                   // rijen 10-13 (2 tekstregels)
        sta a0
        lda #10
        sta a1
        lda CFG_strip            // strook: binnen het smallere venster
        and #7                   // (da_Redraw wist het dan weer)
        beq !w+
        lda #28
        .byte $2c                // (slaat lda #32 over)
!w:     lda #32
        sta a2
        lda #4
        sta a3
        lda TH_text
        sta a4
        jsr gfx_DrawBox
        lda #<sLoad
        sta r0
        lda #>sLoad
        sta r0+1
        lda #6
        sta a0
        lda #11
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        pla
        sta r0+1
        pla
        sta r0
        lda #14
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
        lda #6
        sta a0
        lda #12
        sta a1
        lda TH_text
        sta a2
        jmp gfx_DrawText

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

// appKey - toets naar de editor of CHAT. Carry=1 = afgehandeld.
appKey:
        lda activeApp
        bne !e+                  // FILE MANAGER: eigen toetsen
        jsr fm_Key
        sec
        rts
!e:     cmp #1
        bne !p+
        jsr ed_Key
        sec
        rts
!p:     cmp #2                   // PAINT: M = menu (carry van paint_Key)
        bne !c+
        jmp paint_Key
!c:     cmp #7
        bne !m+
        jsr chat_Key
        sec
        rts
!m:     jsr ovJT                 // sprongtabel-overlays: eigen toetsen
        bcc !n+
        lda evtA
        jmp EMAIL_KEY
!n:     clc
        rts

// ovJT - carry=1 als app A een overlay met sprongtabel op $8000 is: EMAIL
//        (9), EMAIL SETTINGS (10), TIME (12), RADIO (13) en elke nieuwe app
//        vanaf 14. Niet: 11 (SID PLAYER) en $ff (bureaublad). A blijft.
ovJT:   cmp #11
        beq !n+
        cmp #$ff
        beq !n+
        cmp #9                   // (carry = A >= 9)
        rts
!n:     clc
        rts

//--------------------------------------------------------
// exitToDesktop - active app sluiten, terug naar bureaublad.
//--------------------------------------------------------
exitToDesktop:
        jsr ov_Exit              // app-PRG ruimt op (ovExit)
        lda activeApp            // Paint: eerst char-mode herstellen
        cmp #2
        bne !np+
        jsr paint_Exit
!np:    lda #0
        sta helpCtx
        sta kbRaw
        lda #$ff
        sta activeApp
        jmp shell_DrawAll

//--------------------------------------------------------
// menu_Open - uitklapmenu X (0 = CD64, 1 = DESKTOP) onder de menubalk.
//             Modale lus: klik een item, klik ernaast of ESC = sluiten.
//             Een klik op een andere menubalkknop opent die meteen.
//--------------------------------------------------------
menu_Open: {
        stx menuId
        lda mnX,x
        sta a0
        clc
        adc #2
        sta menuTxtCol
        lda #1
        sta a1
        lda mnW,x
        sta a2
        lda mnN,x
        sta menuN
        clc
        adc #2
        sta a3
        lda TH_text
        sta a4
        jsr gfx_DrawBox
        lda #0
        sta menuI
dlp:    lda menuI
        ldx menuId
        clc
        adc mnFirst,x
        tax
        lda miLo,x
        sta r0
        lda miHi,x
        sta r0+1
        lda menuTxtCol
        sta a0
        lda menuI
        clc
        adc #2
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        inc menuI
        lda menuI
        cmp menuN
        bne dlp
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
        lda evtB
        bne item
        jsr mb_Zone              // menubalk: andere knop -> die openen
        lda mbMenu,x
        cmp menuId
        beq close                // zelfde knop = dichtklappen
        jsr shell_DrawAll
        jmp menuBarClick
item:   ldx menuId
        lda evtA                 // binnen de menukolommen?
        cmp mnX,x
        bcc close
        sec
        sbc mnX,x
        cmp mnW,x
        bcs close
        lda evtB
        sec
        sbc #2
        bcc close
        cmp menuN
        bcs close
        clc
        adc mnFirst,x            // globaal itemnummer
        beq doHelp
        cmp #1
        beq doReset
        cmp #2
        beq doExit
        cmp #3
        beq doAbout
        cmp #MI_SETTINGS
        beq doSet
        cmp #MI_NETWORK
        beq doNet
        cmp #MI_EMAIL
        beq doMail
        cmp #MI_TIME
        beq doTime
        pha                      // 4-6: launcher-beheer op het bureaublad
        jsr exitToDesktop        // (tekent ook opnieuw: het menu gaat weg)
        pla
        sec
        sbc #4
        tax
        jmp tool_Run
close:  jmp shell_DrawAll
doSet:  lda #4                   // SETTINGS
        .byte $2c                // (bit abs: sla lda #5 over)
doNet:  lda #5                   // NETWORK
        .byte $2c
doMail: lda #10                  // EMAIL SETTINGS
        .byte $2c
doTime: lda #12                  // TIME
        cmp activeApp
        beq close
        jmp openApp
doHelp: jmp help_Show            // tekent zelf het scherm opnieuw
doAbout:jsr shell_DrawAll        // menu weg, dan "VERSION 1.1"
        lda #<aLine2
        sta r0
        lda #>aLine2
        sta r0+1
        jmp msg_Show
doReset:
        sei
        lda #$37                 // BASIC+KERNAL+I/O inbanken
        sta $01
        jmp ($fffc)              // KERNAL-reset
doExit: // CD64 netjes verlaten naar BASIC (zonder reset)
        sei
        lda #0
        sta VIC_IRQ_EN           // raster-IRQ uit
        sta $d015                // cursor-sprite uit
        lda #$37
        sta $01
        jsr $fd15                // RESTOR: KERNAL-vectoren
        jsr $fda3                // IOINIT: CIA's, IRQ-timer
        jsr $ff5b                // CINT: VIC + scherm (ROM-charset)
        cli
        jmp ($a000)              // BASIC koude start
}

// mb_Zone - X = menubalkknop onder kolom evtA (0-4).
mb_Zone:
        lda evtA
        ldx #0
!lp:    cmp mbEnd,x
        bcc !r+
        inx
        cpx #MB_ITEMS-1
        bne !lp-
!r:     rts

// menuBarClick - klik op rij 0: uitklapmenu of app openen.
menuBarClick:
        jsr mb_Zone
        lda mbMenu,x
        bmi !app+
        tax
        jmp menu_Open
!app:   lda mbApp,x
        cmp activeApp
        beq !r+                  // staat al open
        jmp openApp
!r:     rts

//--------------------------------------------------------
// tool_Run - launcher-beheer (overlay DESKTOOL) laden en starten.
//            X = 0 toevoegen, 1 bewerken, 2 verwijderen; STONE-strook:
//            3 naar de prullenbak (toolArg = programma), 4 printer,
//            5 prullenbak openen, 6 "ingebouwd programma".
//--------------------------------------------------------
// ss_Poll - screensaver: CFG_saver minuten geen muis of toets (ssIdle telt
//           de minuten in clk_Poll) en het bureaublad zelf staat open ->
//           SCRSAVER starten (via DESKTOOL, zoals een klik op het icoon).
//           In een programma, menu of dialoog nooit: niets gaat verloren.
ss_Poll:
        lda crsXlo               // muis bewogen?
        eor crsY
        cmp ssPos
        sta ssPos
        bne !act+
        lda evtHead              // toets of klik?
        cmp evtTail
        bne !act+
        lda CFG_saver
        beq !r+
        cmp ssIdle
        beq !go+
        bcs !r+
!go:    lda activeApp            // alleen het bureaublad ($ff)
        bpl !r+
        lda #0
        sta ssIdle
        ldx #7
        jmp tool_Run
!act:   lda #0
        sta ssIdle
!r:     rts
ssIdle: .byte 0
ssPos:  .byte 0

// ov_Idle / ov_Exit - haken voor een app-PRG (sprongtabel op $8000): de
//          app zet ovIdle (elke ronde van de hoofdlus aangeroepen) en ovExit
//          (eenmaal bij het sluiten of wisselen; daarna zijn beide weer 0).
ov_Idle:
        lda ovIdle+1
        beq !r+
        jmp (ovIdle)
ov_Exit:
        lda ovExit+1
        beq !r+
        jsr !x+
        lda #0
        sta ovExit+1
        sta ovIdle+1
!r:     rts
!x:     jmp (ovExit)
ovIdle: .word 0
ovExit: .word 0

tool_Run:
        stx toolFn
        ldx #17
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
        cmp #3
        bcc !del+
        jmp da_ToolMore
!del:   jmp da_DeleteProgram
!add:   jmp da_AddProgram
!edit:  jmp da_EditProgram
toolFn: .byte 0
toolArg: .byte 0

// menubalk: knoppen, kolommen, klikzones (einde, exclusief) en app-id
mbStrLo: .byte <mbCd, <oDesk, <lFiles, <mbSys
mbStrHi: .byte >mbCd, >oDesk, >lFiles, >mbSys
mbCol:   .byte 1, 8, 18, 26
mbEnd:   .byte 7, 17, 25
mbApp:   .byte $fe, $ff, 0, 4         // $fe = nooit "ingedrukt"
mbApp2:  .byte $fe, $ff, 0, 5         // tweede app van dezelfde knop
mbMenu:  .byte 0, 1, $ff, 2           // uitklapmenu per knop ($ff = app)
// uitklapmenu's: 0 = CD64, 1 = DESKTOP, 2 = SYSTEM
mnX:     .byte 0, 7, 25
mnW:     .byte 10, 18, 12
mnN:     .byte 4, 3, 4
mnFirst: .byte 0, 4, 7
miLo:    .byte <oHelp, <oReset, <oExit, <oAbout, <oAdd, <oEditP, <oDel
         .byte <nSet, <oNet, <oMail, <oTime
miHi:    .byte >oHelp, >oReset, >oExit, >oAbout, >oAdd, >oEditP, >oDel
         .byte >nSet, >oNet, >oMail, >oTime

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
        jmp menuBarClick         // rij 0 = menubalk
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
!nt:    cmp #STATUS_ROW          // statusbalk (klok): niets; instellingen
        beq !rt+                 // gaan alleen via SYSTEM
        cmp #WIN_FRAME_BOT       // onderrand: niets
        bcc !widget+
!rt:    rts
!widget:
        // klik in het werkgebied
        lda activeApp
        cmp #$ff
        bne !app+
        jmp desk_Click           // bureaublad -> launcher-icoon
!app:   cmp #0
        bne !w0+
        jmp fm_Click
!w0:    cmp #1
        bne !w1+
        jmp ed_Click
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
        bne !w5+
        jmp inet_Click
!w5:    cmp #6
        bne !w6+
        jmp ping_Click
!w6:    cmp #7
        bne !w7+
        jmp chat_Click
!w7:    cmp #8
        bne !w8+
        jmp BBS_CLICK
!w8:    jsr ovJT                 // EMAIL, TIME, RADIO, ...
        bcc !w9+
        jmp EMAIL_CLICK
!w9:    cmp #11                  // SID PLAYER
        bne !done+
        jmp sp_Click
!done:  rts

//--------------------------------------------------------
// openApp - open app-id A (0-5). Laadt de overlay van disk,
//           initialiseert en tekent. Paint gaat naar bitmapmodus.
//--------------------------------------------------------
openApp:
        pha
        jsr ov_Exit              // vorige app-PRG ruimt eerst op
        pla
        sta activeApp
        ldx #0                   // hulpcontext: die van de app
        stx helpCtx
        stx kbRaw                // toetsenbord normaal (apps zetten zelf ruw)
        tax                      // overlay van deze app
        lda appOvl,x
        cmp ovlLoaded            // staat hij al in $8000? (NETWORK <-> PING)
        beq !loaded+
        pha
        jsr showLoading          // X = app-id -> "LOADING <naam van de app>"
        pla
        tax
        jsr loadApp
        bcc !loaded+
        lda #$ff                 // laden mislukt -> melding, terug naar desktop
        sta activeApp
        jmp shell_NotFound
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
!na4:   cmp #5                   // NETWORK
        bne !na5+
        jsr inet_Init
        jmp !drawit+
!na5:   cmp #6                   // PING
        bne !na6+
        jsr ping_Init
        jmp !drawit+
!na6:   cmp #7                   // CHAT
        bne !na7+
        jsr chat_Init
        jmp !drawit+
!na7:   cmp #8
        bne !na8+
        jsr BBS_INIT             // #8 BBS (sprongtabel $8000)
        jmp !drawit+
!na8:   cmp #11
        bne !na9+
        jsr sp_Init              // #11 SID PLAYER
        jmp !drawit+
!na9:   jsr EMAIL_INIT           // #9 EMAIL / #10 EMAIL SETTINGS
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
biCount:    .byte 12
biNameLo:   .byte <dnEdit, <dnPaint, <dnCalc, <oPing, <oChat, <dnBbs, <oMail, <nSid, <oRadio, <nWeather, <nWeb, <nCal
biNameHi:   .byte >dnEdit, >dnPaint, >dnCalc, >oPing, >oChat, >dnBbs, >oMail, >nSid, >oRadio, >nWeather, >nWeb, >nCal
biIcon:     .byte ICO_EDIT, ICO_PAINT, ICO_CALC, ICO_PING, ICO_CHAT, ICO_BBS, MAIL_GLYPH, ICO_SID, ICO_RADIO_D, ICO_WEATHER, ICO_WEB, ICO_CAL  // 2x3
biIcoCol:   .byte WHITE, LIGHT_RED, CYAN, LIGHT_GREEN, YELLOW, LIGHT_GREY, WHITE, LIGHT_BLUE, GREEN, YELLOW, LIGHT_BLUE, LIGHT_RED
biApp:      .byte 1, 2, 3, 6, 7, 8, 9, 11, 13, 14, 15, 16  // app-id
// 20 kies-iconen: eigen 8x8-iconen op charset-codes 64..83 (zie font.asm):
// kies-icoon K = code 64 + K (geen tabel meer: Core-ruimte)
menuTxtCol:  .byte 0
menuI:       .byte 0
menuN:       .byte 0
menuId:      .byte 0
msgPtr:      .word 0
// gedeelde scratch-vars (o.a. File Manager-lijst)
lvI:         .byte 0
lvItem:      .byte 0
lvRow:       .byte 0

nameLo: .byte <nDesk, <nFiles, <nEdit, <nPaint, <nCalc, <nSet, <nInet, <oPing, <oChat, <nBbs, <oMail, <nMailS, <nSid, <nTime, <nRadio, <nWeather, <nWeb, <nCal
nameHi: .byte >nDesk, >nFiles, >nEdit, >nPaint, >nCalc, >nSet, >nInet, >oPing, >oChat, >nBbs, >oMail, >nMailS, >nSid, >nTime, >nRadio, >nWeather, >nWeb, >nCal
// overlay (loadApp-index) per app-id: PING zit in de INET-overlay
appOvl: .byte 0, 1, 2, 3, 4, 5, 5, 5, 7, 8, 8, 9, 10, 11, 12, 13, 14

dbI:       .byte 0
// laadvenster-namen per app-id (17 = launcher-beheer)
labelLo:   .byte <lFiles, <lEdit, <lPaint, <lCalc, <lSet, <lInet, <oPing, <oChat, <nBbs, <oMail, <nMailS, <nSid, <oTime, <nRadio, <nWeather, <nWeb, <nCal, <lTool
labelHi:   .byte >lFiles, >lEdit, >lPaint, >lCalc, >lSet, >lInet, >oPing, >oChat, >nBbs, >oMail, >nMailS, >nSid, >oTime, >nRadio, >nWeather, >nWeb, >nCal, >lTool

.encoding "screencode_upper"
mbCd:   .text "CD64"
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
nInet:  .text "NETWORK"
        .byte $ff

dnEdit:    .text "EDITOR"
           .byte $ff
dnPaint:   .text "PAINT"
           .byte $ff
dnCalc:    .text "CALC"
           .byte $ff
dnBbs:     .text "BBS"
           .byte $ff
nBbs:      .text "BBS CLIENT"
           .byte $ff
sNotFound: .text "NOT ON THIS DISK"   // (D64: op de andere kant)
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
lSet:   .text "SETTINGS"
        .byte $ff
lInet:  .text "NETWORK SETTINGS"
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
oExit:  .text "EXIT"
        .byte $ff
oNet:   .text "NETWORK"
        .byte $ff
oPing:  .text "PING"
        .byte $ff
oChat:  .text "CHAT"
        .byte $ff
oMail:  .text "EMAIL"
        .byte $ff
nMailS: .text "EMAIL SETTINGS"
        .byte $ff
nSid:   .text "SID PLAYER"
        .byte $ff
oTime:  .text "TIME"
        .byte $ff
nTime:  .text "DATE AND TIME"
        .byte $ff
nWeather: .text "WEATHER"
        .byte $ff
nWeb:   .text "WEB"
        .byte $ff
nCal:   .text "CALENDAR"
        .byte $ff
oRadio: .text "RADIO"
        .byte $ff
nRadio: .text "SID RADIO"
        .byte $ff
sF1Help: .text "F1=HELP"
        .byte $ff
mbSys:  .text "SYSTEM"
        .byte $ff
aLine2: .text "VERSION 1.1"
        .byte $ff
aClose: .text "SPACE = CLOSE"
        .byte $ff
