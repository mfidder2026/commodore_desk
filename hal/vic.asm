#importonce
//========================================================
// hal/vic.asm - VIC-II initialisatie
// Commodore Desk 64
//========================================================

// vic_Init - zet de VIC in hi-res char-mode, VIC-bank 0,
//            scherm $0400, charset $1000 (char-ROM voorlopig),
//            thema-kleuren voor rand en achtergrond.
// Klobbert: A
vic_Init:
        // VIC-bank 0 ($0000-$3FFF) via CIA2 poort A, bits 0-1 = %11.
        lda CIA2_DDRA
        ora #$03
        sta CIA2_DDRA
        lda CIA2_PRA
        ora #$03
        sta CIA2_PRA
        // Scherm-RAM $0400, charset $1000 (Fase 2 vervangt dit door eigen font).
        lda #$15
        sta VIC_MEM
        // Tekstmodus: DEN aan, 25 rijen, y-scroll 3.
        lda #$1b
        sta VIC_CTRL1
        // 40 kolommen, multicolor uit.
        lda #$c8
        sta VIC_CTRL2
        // Sprites uit.
        lda #0
        sta SPR_ENABLE
        // Thema-kleuren.
        lda #THEME_BORDER
        sta BORDER_COL
        lda #THEME_DESKTOP_BG
        sta BG_COL0
        rts
