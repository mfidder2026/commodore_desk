#importonce
//========================================================
// gfx/font.asm - System-font + eigen UI-glyphs
// Commodore Desk 64  (Fase 2)
//
// System-font = de char-ROM (schone, leesbare set) naar RAM
// gekopieerd op CHARSET_BASE ($3000). Daarna overschrijven we het
// gedeelde UI-glyphblok (kaderlijnen) met eigen bitmaps. Classic
// en Bold (fase latere) worden volledig eigen charsets die HETZELFDE
// UI-blok delen.
//========================================================

// Kader-glyphs (screencodes, in het UI-blok vanaf UI_GLYPH_FIRST=96).
.const FR_TL = 96    // hoek linksboven
.const FR_TR = 97    // hoek rechtsboven
.const FR_BL = 98    // hoek linksonder
.const FR_BR = 99    // hoek rechtsonder
.const FR_H  = 100   // horizontale lijn
.const FR_V  = 101   // verticale lijn

// Dock-icoon-glyphs (aansluitend op de kaders).
.const ICON_FILES = 102
.const ICON_EDIT  = 103
.const ICON_PAINT = 104
.const ICON_CALC  = 105
.const ICON_SETUP = 106

.const UI_GLYPH_COUNT = 11    // FR_* (6) + iconen (5)

// font_Init - kopieer de ingesloten System-charset naar $3000,
//             overlay de UI-glyphs, en richt de VIC op $3000
//             ($D018 = $1C). Geen char-ROM-afhankelijkheid, dus
//             identiek bruikbaar op disk én cartridge.
// Klobbert: A,X
font_Init:
        ldx #0
!lp:    lda sysChars + $000,x
        sta CHARSET_BASE + $000,x
        lda sysChars + $100,x
        sta CHARSET_BASE + $100,x
        lda sysChars + $200,x
        sta CHARSET_BASE + $200,x
        lda sysChars + $300,x
        sta CHARSET_BASE + $300,x
        lda sysChars + $400,x
        sta CHARSET_BASE + $400,x
        lda sysChars + $500,x
        sta CHARSET_BASE + $500,x
        lda sysChars + $600,x
        sta CHARSET_BASE + $600,x
        lda sysChars + $700,x
        sta CHARSET_BASE + $700,x
        inx
        bne !lp-

        // Overlay de eigen UI-glyphs (kaders + iconen) vanaf code 96.
        ldx #0
!lp:    lda frameGlyphs,x
        sta CHARSET_BASE + [96*8],x
        inx
        cpx #[UI_GLYPH_COUNT*8]
        bne !lp-

        // VIC: scherm $0400 (bits 4-7=1), charset $3800 (bits 1-3=7) -> $1E.
        lda #$1e
        sta VIC_MEM
        rts

//--------------------------------------------------------
// Kader-glyphs: dunne enkele lijn, uitgelijnd op rij 3 / kolom 3-4
// zodat aangrenzende cellen aansluiten. Volgorde = FR_TL..FR_V.
//--------------------------------------------------------
frameGlyphs:
        // FR_TL
        .byte %00000000,%00000000,%00000000,%00011111,%00011000,%00011000,%00011000,%00011000
        // FR_TR
        .byte %00000000,%00000000,%00000000,%11111000,%00011000,%00011000,%00011000,%00011000
        // FR_BL
        .byte %00011000,%00011000,%00011000,%00011111,%00000000,%00000000,%00000000,%00000000
        // FR_BR
        .byte %00011000,%00011000,%00011000,%11111000,%00000000,%00000000,%00000000,%00000000
        // FR_H
        .byte %00000000,%00000000,%00000000,%11111111,%00000000,%00000000,%00000000,%00000000
        // FR_V
        .byte %00011000,%00011000,%00011000,%00011000,%00011000,%00011000,%00011000,%00011000

        // ---- Dock-iconen (aansluitend, worden mee-gekopieerd) ----
        // ICON_FILES (map)
        .byte %00000000,%00111000,%01111100,%01000100,%01000100,%01000100,%01111100,%00000000
        // ICON_EDIT (document met regels)
        .byte %00000000,%01111000,%01001100,%01111100,%01011100,%01011100,%01111100,%00000000
        // ICON_PAINT (kwast)
        .byte %00000011,%00000110,%00001100,%00011000,%00110000,%01111000,%01111000,%00110000
        // ICON_CALC (toetsenraster)
        .byte %00000000,%01111100,%01010100,%01111100,%01010100,%01111100,%01010100,%00000000
        // ICON_SETUP (tandwiel)
        .byte %00010000,%01010100,%00111000,%11101110,%00111000,%01010100,%00010000,%00000000

//--------------------------------------------------------
// System-charset (2 KB, hoofdletter/grafiek-set uit de C64 char-ROM),
// ingesloten zodat we niet van de char-ROM afhankelijk zijn.
//--------------------------------------------------------
sysChars:
        .import binary "data/chargen.bin"
