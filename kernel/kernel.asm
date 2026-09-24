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
        jsr cfg_Load             // CD64.CFG (indien aanwezig) overschrijft ze
        jsr font_Apply           // gekozen font toepassen (na cfg_Load)
        jsr theme_Apply          // rand/achtergrond naar de VIC
        jsr sid_Init
        // (bootscherm wordt door het aparte BOOT-laadprogramma getoond)
        jsr evt_Init
        jsr spr_CursorInit       // pijl-sprite (data + enable)
        jsr input_Init
        jsr irq_Install          // bankt ROMs uit, zet IRQ aan, cli
        jsr shell_Init           // teken het bureaublad (IRQ draait al)
        jmp shell_Run            // hoofdlus (keert niet terug)

// theme_Apply - rand- en achtergrondkleur naar de VIC schrijven.
theme_Apply:
        lda TH_border
        sta BORDER_COL
        lda TH_deskbg
        sta BG_COL0
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
        // thema-kleuren defaults
        lda #THEME_BORDER
        sta TH_border
        lda #THEME_DESKTOP_BG
        sta TH_deskbg
        lda #THEME_MENUBAR_BG
        sta TH_menubg
        lda #THEME_ACCENT
        sta TH_accent
        lda #THEME_SELECT
        sta TH_select
        rts
