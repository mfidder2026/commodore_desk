#importonce
//========================================================
// kernel/kernel.asm - kernelkern: init + start van de shell
// Commodore Desk 64  (Fase 1-5)
//
// kernel_Init zet de machine op (VIC, font, OS-vars, events, cursor,
// input), start de desktop-shell en installeert de raster-IRQ. Daarna
// draait de shell-hoofdlus; de IRQ pollt input en genereert events.
//========================================================

kernel_Init:
        sei
        // CIA-IRQ's meteen uit: in het boot-venster (KERNAL soms uitgebankt
        // + tussentijdse cli in disk-I/O) zou een CIA-IRQ naar RAM-rommel
        // springen. De raster-IRQ komt pas in irq_Install.
        lda #$7f
        sta CIA1_ICR
        sta CIA2_ICR
        bit CIA1_ICR
        bit CIA2_ICR
        jsr vic_Init
        jsr font_Init            // System-font naar RAM + UI-glyphs
        jsr osvars_Init          // runtime-defaults
        jsr drv_Init             // 1571: dubbelzijdig (kant 2 van de D71)
        jsr help_Load            // F1-teksten naar $D000
        jsr cfg_Load             // CD64.CFG (indien aanwezig) overschrijft ze
        jsr profile_Derive       // Win95-structuurkleuren bij het profiel
        jsr da_Load              // DESK.APPS (gebruikersprogramma's) of defaults
        jsr font_Apply           // gekozen font toepassen (na cfg_Load)
        jsr sid_Init
        jsr clk_Init             // klok (CIA-TOD) + datum
        // (bootscherm wordt door het aparte BOOT-laadprogramma getoond)
        jsr evt_Init
        jsr spr_CursorInit       // pijl-sprite (data + enable)
        jsr input_Init
        jsr irq_Install          // bankt ROMs uit, zet IRQ aan, cli
        jsr shell_Init           // teken het bureaublad (IRQ draait al)
        jsr theme_Apply          // rand/achtergrond -> VIC
        lda #$1b                 // bureaublad klaar -> scherm aan (DEN)
        sta VIC_CTRL1
        jsr time_Boot
        jmp shell_Run            // hoofdlus (keert niet terug)

// theme_Apply - rand- en achtergrondkleur naar de VIC schrijven.
theme_Apply:
        lda TH_border
        sta BORDER_COL
        lda TH_deskbg
        sta BG_COL0
        lda TH_mouse             // muispijl (Settings: MOUSE)
        sta SPR0_COL
        rts

//--------------------------------------------------------
// osvars_Init - runtime layout- en uiterlijk-variabelen vullen.
//--------------------------------------------------------
osvars_Init:
        lda #DEFAULT_DOCK_MODE
        sta LAY_dockMode
        lda #L_MENUBAR_ROW
        sta LAY_menubarRow
        lda #L_CONTENT_TOP
        sta LAY_contentTop
        lda #L_CONTENT_BOTTOM
        sta LAY_contentBottom
        lda #L_STATUS_ROW
        sta LAY_statusRow
        lda #L_DOCK_ICON_ROW
        sta LAY_dockIconRow
        lda #L_DOCK_LABEL_ROW
        sta LAY_dockLabelRow
        lda #DEFAULT_FONT
        sta CFG_fontId
        lda #DEFAULT_MENUFILL
        sta CFG_menuFill
        lda #DEFAULT_PROFILE
        sta CFG_profile
        lda #DEFAULT_SOUND
        sta CFG_sound
        // thema-kleuren defaults (die van DEFAULT_PROFILE)
        lda profBorder+DEFAULT_PROFILE
        sta TH_border
        lda profDesk+DEFAULT_PROFILE
        sta TH_deskbg
        lda profMenu+DEFAULT_PROFILE
        sta TH_menubg
        lda profAccent+DEFAULT_PROFILE
        sta TH_accent
        lda profSelect+DEFAULT_PROFILE
        sta TH_select
        lda profText+DEFAULT_PROFILE
        sta TH_text
        lda #$ff                 // muiskleur: nog niet gezet (zie profile_Derive)
        sta TH_mouse
        sta CFG_ntp              // tijdserver: standaard (pool.ntp.org)
        lda #TZ_DEFAULT
        sta CFG_tz
        lda #DEFAULT_STRIP       // (oudere CD64.CFG: blijft zo staan)
        sta CFG_strip
        lda #0                   // printer: EPSON op device 4
        sta CFG_printer
        lda #0
        sta CFG_timeAuto
        rts

//--------------------------------------------------------
// profile_Apply - pas kleurprofiel CFG_profile toe (6 TH_*-kleuren),
//                 daarna rand/achtergrond naar de VIC.
//--------------------------------------------------------
profile_Apply:
        ldx CFG_profile
        lda profBorder,x
        sta TH_border
        lda profDesk,x
        sta TH_deskbg
        lda profMenu,x
        sta TH_menubg
        lda profAccent,x
        sta TH_accent
        lda profSelect,x
        sta TH_select
        lda profText,x
        sta TH_text
        lda profMouse,x
        sta TH_mouse
        jsr profile_Derive
        jmp theme_Apply

// profile_Derive - Win95-structuurkleuren (desktop, titelbalk, balktekst)
//                  uit het profiel afleiden. Ook na cfg_Load aanroepen.
profile_Derive:
        ldx CFG_profile
        cpx #NUM_PROFILES
        bcc !ok+
        ldx #0
!ok:    lda profDesktop,x
        sta TH_desktop
        lda profTitle,x
        sta TH_title
        txa                      // stijl: vullingen + omgekeerde tekens
        pha
        ldy #0
        cpx #PROFILE_STONE        // STONE en DESK64: STONE-stijl
        bcc !st+
        ldy #ST_N
!st:    ldx #0
!sl:    lda stTab,y
        sta stBarFill,x
        iny
        inx
        cpx #ST_N
        bne !sl-
        pla
        tax
        lda TH_mouse             // geen (geldige) muiskleur opgeslagen:
        cmp #16                  // die van het profiel
        bcc !r+
        lda profMouse,x
        sta TH_mouse
!r:     rts

// Venster = TH_deskbg ($D021), balken = TH_menubg (menubalk + statusbalk),
// desktop = grijs eromheen.
// Fremen = grijze tinten: donkergrijs op lichtgrijs
// (balktekst = achtergrondkleur, dus donkere balken voor het contrast).
// STONE = een klassieke 8-bit desktop-look: lichtgrijs, zwarte tekst zonder
// balken, gestreepte titels en een geruit bureaublad (zie stTab).
// DESK64 = de STONE-indeling in de kleuren van het bootscherm: blauwe vensters
// met witte tekst en lijnen, lichtgrijs bureaublad (stippen omgekeerd, zie
// icon_Build: de stippen zijn dan blauw).
//          C64/Win95     Matrix       Paper        Fremen       STONE         DESK64
profBorder:  .byte LIGHT_BLUE, BLACK,       GREY,        DARK_GREY,   BLACK,       BLACK
profDesk:    .byte BLUE,       BLACK,       WHITE,       LIGHT_GREY,  LIGHT_GREY,  BLUE
profMenu:    .byte LIGHT_GREY, GREEN,       GREY,        DARK_GREY,   BLACK,       WHITE
profAccent:  .byte YELLOW,     LIGHT_GREEN, BLUE,        BLACK,       BLUE,        YELLOW
profSelect:  .byte CYAN,       DARK_GREY,   LIGHT_BLUE,  GREY,        BLUE,        CYAN
profText:    .byte WHITE,      GREEN,       BLACK,       DARK_GREY,   BLACK,       WHITE
profDesktop: .byte GREY,       DARK_GREY,   LIGHT_GREY,  GREY,        DARK_GREY,   LIGHT_GREY
profTitle:   .byte LIGHT_BLUE, GREEN,       BLUE,        DARK_GREY,   BLACK,       WHITE
profMouse:   .byte WHITE,      LIGHT_GREEN, BLACK,       WHITE,       BLUE,        YELLOW

// Stijl per profiel (Win95 / STONE): vulteken van de balken (menu, status),
// van titelbalken, van knoppen en van de desktoprand, en het masker voor
// de "omgekeerde" tekens (128-255). STONE: niet omgekeerd, dus tekst op
// balken en knoppen wordt gewone donkere tekst op de lichte achtergrond.
// (laatste waarde: 1 = STONE-indeling van het bureaublad en de menubalk)
// (en de waarde die gfx_DrawTextRev bij de tekens optelt: in STONE staan
// op 128-253 de 24x24-iconen, dus daar gewone tekens)
stTab:  .byte $a0, $a0,      $a0,     $a0,      $ff, 0, $80
        .byte $20, GL_STRIPE, GL_DOTS, GL_TRACK, $00, 1, $00
stBarFill:   .byte $a0
stTitleFill: .byte $a0
stBtnFill:   .byte $a0
stDeskFill:  .byte $a0
stRevMask:   .byte $ff
stStone:      .byte 0
stRevOr:     .byte $80
