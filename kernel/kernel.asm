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
        jsr theme_Apply          // rand/achtergrond naar de VIC
        jsr sid_Init
        jsr splash_Show          // opstartscherm + korte pauze
        jsr evt_Init
        jsr spr_CursorInit       // pijl-sprite (data + enable)
        jsr input_Init
        jsr irq_Install          // bankt ROMs uit, zet IRQ aan, cli
        jsr shell_Init           // teken het bureaublad (IRQ draait al)
        jmp shell_Run            // hoofdlus (keert niet terug)

//--------------------------------------------------------
// splash_Show - kort opstartscherm.
//--------------------------------------------------------
splash_Show:
        lda #BLACK
        sta BORDER_COL
        sta BG_COL0
        sta a2
        jsr gfx_Cls
        gfxDrawText(splTitle, 11, 10, CYAN)
        gfxDrawText(splVer,   15, 12, WHITE)
        gfxDrawText(splCopy,  10, 22, GREY)
        // pauze via een simpele tel-lus (geen VIC-afhankelijkheid)
        lda #6
        sta tmp0
!o:     ldx #0
!m:     ldy #0
!i:     dey
        bne !i-
        inx
        bne !m-
        dec tmp0
        bne !o-
        jsr theme_Apply          // rand/achtergrond terug
        rts

.encoding "screencode_upper"
splTitle: .text "COMMODORE DESK 64"
          .byte $ff
splVer:   .text "VERSION 0.9"
          .byte $ff
splCopy:  .text "(C) 2026 FREMEN.APP"
          .byte $ff

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
