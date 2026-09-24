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

.const UI_GLYPH_COUNT = 31    // FR_* (6) + 1-cel iconen (5) + 2x2-iconen (20)

// font_Init - kopieer de ingesloten System-charset naar $3000,
//             overlay de UI-glyphs, en richt de VIC op $3000
//             ($D018 = $1C). Geen char-ROM-afhankelijkheid, dus
//             identiek bruikbaar op disk én cartridge.
// Klobbert: A,X
font_Init:
        jsr font_Base
        jsr font_OverlayUI
        // VIC: scherm $0400 (bits 4-7=1), charset $3800 (bits 1-3=7) -> $1E.
        lda #$1e
        sta VIC_MEM
        rts

//--------------------------------------------------------
// font_Apply - pas het gekozen font (CFG_fontId) toe: kopieer de
//              basis-charset, vervorm hem (Bold/Classic) en overlay
//              opnieuw de UI-glyphs. Aanroepen na cfg_Load en bij een
//              fontwissel in Settings.
//--------------------------------------------------------
font_Apply:
        lda CFG_fontId
        cmp #FONT_BOLD
        beq !bold+
        cmp #FONT_CLASSIC
        beq !classic+
        cmp #FONT_LOWER
        beq !lower+
        cmp #FONT_TINY
        beq !tiny+
        jsr font_Base            // System
        jmp font_OverlayUI
!bold:  jsr font_Base
        jsr font_Bold
        jmp font_OverlayUI
!classic:
        jsr font_Base
        jsr font_Classic
        jmp font_OverlayUI
!lower: jmp font_Lower
!tiny:  jmp font_Tiny

//--------------------------------------------------------
// font_Lower - System-charset + kleine letters (a-z) uit de C64-ROM
//              over code 1-26.
//--------------------------------------------------------
font_Lower:
        jsr font_Base
        ldx #0
!lp:    lda lowerChars,x
        sta CHARSET_BASE + 8,x       // code 1 = a
        inx
        cpx #208                     // 26 letters * 8
        bne !lp-
        jmp font_OverlayUI

//--------------------------------------------------------
// font_Tiny - System-charset + eigen 3x5 micro-font over A-Z (code
//             1-26) en 0-9 (code 48-57).
//--------------------------------------------------------
font_Tiny:
        jsr font_Base
        ldx #0
!lp:    lda tinyChars,x              // A-Z -> code 1
        sta CHARSET_BASE + 8,x
        inx
        cpx #208
        bne !lp-
        ldx #0
!lp:    lda tinyChars + 208,x        // 0-9 -> code 48
        sta CHARSET_BASE + [48*8],x
        inx
        cpx #80
        bne !lp-
        jmp font_OverlayUI

//--------------------------------------------------------
// font_Base - kopieer de ingesloten System-charset (2 KB) naar RAM.
//--------------------------------------------------------
font_Base:
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
        rts

//--------------------------------------------------------
// font_OverlayUI - overlay de eigen UI-glyphs (kaders + iconen) op
//                  code 96 e.v. (identiek in alle fonts).
//--------------------------------------------------------
font_OverlayUI:
        ldx #0
!lp:    lda frameGlyphs,x
        sta CHARSET_BASE + [96*8],x
        inx
        cpx #[UI_GLYPH_COUNT*8]
        bne !lp-
        rts

//--------------------------------------------------------
// font_Bold - verzwaar de streken: b = b | (b>>1). Alleen de normale
//             set (code 0-127); de reverse-set (128-255, o.a. de
//             balk-blok $a0) blijft ongemoeid zodat balken vol blijven.
//--------------------------------------------------------
font_Bold:
        ldx #0
!lp:    lda CHARSET_BASE + $000,x
        sta fTmp
        lsr
        ora fTmp
        sta CHARSET_BASE + $000,x
        lda CHARSET_BASE + $100,x
        sta fTmp
        lsr
        ora fTmp
        sta CHARSET_BASE + $100,x
        lda CHARSET_BASE + $200,x
        sta fTmp
        lsr
        ora fTmp
        sta CHARSET_BASE + $200,x
        lda CHARSET_BASE + $300,x
        sta fTmp
        lsr
        ora fTmp
        sta CHARSET_BASE + $300,x
        inx
        bne !lp-
        rts

//--------------------------------------------------------
// font_Classic - schuine (italic) stijl: de bovenste 4 rijen van elke
//                glyph 1 pixel naar rechts. Alleen de normale set
//                (code 0-127), zodat de reverse-balken vol blijven.
//--------------------------------------------------------
font_Classic:
        lda #<CHARSET_BASE
        sta r4
        lda #>CHARSET_BASE
        sta r4+1
        ldx #0
!ch:    ldy #0
        lda (r4),y
        lsr
        sta (r4),y
        iny
        lda (r4),y
        lsr
        sta (r4),y
        iny
        lda (r4),y
        lsr
        sta (r4),y
        iny
        lda (r4),y
        lsr
        sta (r4),y
        lda r4
        clc
        adc #8
        sta r4
        bcc !+
        inc r4+1
!:      inx
        cpx #128
        bne !ch-
        rts

fTmp:   .byte 0

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

        // ---- INET 2x2-icoon (globe), codes 102-105 (TL,TR,BL,BR) ----
        .byte $07,$18,$24,$44,$44,$84,$ff,$84   // 102 TL
        .byte $e0,$18,$24,$22,$22,$21,$ff,$21   // 103 TR
        .byte $84,$44,$44,$24,$18,$07,$00,$00   // 104 BL
        .byte $21,$22,$22,$24,$18,$e0,$00,$00   // 105 BR
        .byte $00,$00,$00,$00,$00,$00,$00,$00   // 106 (reserve)

        // ---- 2x2 dock-iconen (codes 107-126), volgorde TL,TR,BL,BR per icoon ----
        // FILES (map)  107-110
        .byte $00,$00,$78,$fc,$ff,$c0,$c0,$c0   // TL
        .byte $00,$00,$00,$00,$fc,$04,$04,$04   // TR
        .byte $c0,$c0,$c0,$c0,$ff,$00,$00,$00   // BL
        .byte $04,$04,$04,$04,$fc,$00,$00,$00   // BR
        // EDIT (document) 111-114
        .byte $00,$7f,$40,$40,$5e,$40,$5e,$40
        .byte $00,$f0,$10,$10,$10,$10,$10,$10
        .byte $5e,$40,$5f,$40,$7f,$00,$00,$00
        .byte $10,$10,$10,$10,$f0,$00,$00,$00
        // PAINT (kwast) 115-118
        .byte $00,$00,$00,$00,$00,$00,$01,$03
        .byte $06,$0f,$1e,$3c,$78,$f0,$e0,$c0
        .byte $07,$0f,$1e,$3e,$7e,$7c,$38,$00
        .byte $80,$00,$00,$00,$00,$00,$00,$00
        // CALC (rekenmachine) 119-122
        .byte $00,$7f,$40,$5f,$40,$49,$40,$49
        .byte $00,$fc,$04,$f4,$04,$24,$04,$24
        .byte $40,$49,$40,$49,$40,$7f,$00,$00
        .byte $04,$24,$04,$24,$04,$fc,$00,$00
        // SETUP (tandwiel) 123-126
        .byte $01,$11,$19,$0f,$7f,$70,$30,$f0
        .byte $80,$88,$98,$f0,$fe,$0e,$0c,$0f
        .byte $f0,$30,$70,$7f,$0f,$19,$11,$01
        .byte $0f,$0c,$0e,$fe,$f0,$98,$88,$80

//--------------------------------------------------------
// System-charset (2 KB, hoofdletter/grafiek-set uit de C64 char-ROM),
// ingesloten zodat we niet van de char-ROM afhankelijk zijn.
//--------------------------------------------------------
sysChars:
        .import binary "data/chargen.bin"

// Kleine letters a-z (uit de C64-ROM, 26 glyphs) - overlay voor FONT_LOWER.
lowerChars:
        .import binary "data/lower.bin"

// Eigen 3x5 micro-font: A-Z (26) + 0-9 (10) - overlay voor FONT_TINY.
tinyChars:
        .import binary "data/tiny.bin"
