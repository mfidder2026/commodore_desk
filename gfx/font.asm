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

// Win95-glyphs (codes 84-89, direct na de 20 launcher-iconen 64-83).
// Gezette pixels = celkleur, lege pixels = achtergrond ($D021).
.const GL_CLOSE  = 84    // sluitknop: grijze knop met kruisje
.const GL_UP     = 85    // scrollknop omhoog
.const GL_DOWN   = 86    // scrollknop omlaag
.const GL_TRACK  = 87    // scroll-track (dither)
.const GL_THUMB  = 88    // scroll-thumb (massief)
.const GL_HILITE = 89    // dock: witte bovenrand
.const GL_THUMBEND = 90  // scroll-thumb, onderste rij (met schaduw)
// vensterkader met de lijn tegen de BUITENrand van de cel (zoals het bootscherm)
.const W_L  = 91         // linkerrand
.const W_R  = 92         // rechterrand
.const W_B  = 93         // onderrand
.const W_BL = 94         // hoek linksonder
.const W_BR = 95         // hoek rechtsonder
.const OVL_GLYPHS = 32   // 20 iconen + 12 Win95-glyphs = codes 64..95 (256 bytes)

// font_Init - de System-charset staat al op $3800 (cd64.prg laadt hem
//             daar direct; de cart kopieert hem uit ROM). Bewaar een
//             schone kopie in RAM onder I/O ($D000) voor latere
//             fontwissels, overlay de UI-glyphs en richt de VIC op $3800.
// Klobbert: A,X
.label CS_SAVE = $d000              // schone System-charset (RAM onder I/O)
font_Init:
        jsr font_SaveBase
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
        cmp #FONT_FREMEN         // id 5+ = van disk geladen font
        bcs !disk+
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
!disk:  sec                      // charset van disk naar $3800
        sbc #FONT_FREMEN         // disk-font-index
        tax
        jsr loadCharset
        bcs !dfail+              // mislukt -> terugvallen op System
        jmp font_OverlayUI
!dfail: jsr font_Base
        jmp font_OverlayUI
!bold:  jsr font_Base
        jsr font_Bold
        jmp font_OverlayUI
!classic:
        jsr font_Base
        jsr font_Classic
        jmp font_OverlayUI
// LOWER en TINY zijn complete charsets op disk (lower.prg / tiny.prg,
// disk-fontindex 5 en 6), net als Fremen e.d.: scheelt ~550 bytes Core.
!lower: ldx #5
        jmp !ld+
!tiny:  ldx #6
!ld:    jsr loadCharset
        bcs !dfail-
        jmp font_OverlayUI

//--------------------------------------------------------
// font_Base     - schone System-charset (2 KB) terugzetten: $D000 -> $3800.
// font_SaveBase - schone kopie maken bij het opstarten:   $3800 -> $D000.
// $D000-$D7FF is RAM onder de I/O; tijdens het kopiëren staat $01 op
// $34 (alles RAM) met interrupts uit.
//--------------------------------------------------------
font_Base:
        php
        sei
        lda $01
        pha
        lda #$34
        sta $01
        ldx #0
!lp:
    .for (var p=0; p<8; p++) {
        lda CS_SAVE + p*$100,x
        sta CHARSET_BASE + p*$100,x
    }
        inx
        bne !lp-
        pla
        sta $01
        plp
        rts

font_SaveBase:
        php
        sei
        lda $01
        pha
        lda #$34
        sta $01
        ldx #0
!lp:
    .for (var p=0; p<8; p++) {
        lda CHARSET_BASE + p*$100,x
        sta CS_SAVE + p*$100,x
    }
        inx
        bne !lp-
        pla
        sta $01
        plp
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
        // launcher-iconen + Win95-glyphs: codes 64..95 = precies 256 bytes
        ldx #0
!ic:    lda userIcons,x
        sta CHARSET_BASE + [64*8],x
        inx
        bne !ic-
        rts
.assert "userIcons moet 256 bytes zijn", OVL_GLYPHS*8, 256

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
        // Win95-stijl: de lijn (2 px) ligt tegen de BUITENrand van de cel.
        // Bovenrand = FR_H, linkerrand = FR_V; onder- en rechterrand zijn
        // W_B / W_R (codes 93/92), zie gfx_DrawBox.
        // FR_TL
        .byte %11111111,%11111111,%11000000,%11000000,%11000000,%11000000,%11000000,%11000000
        // FR_TR
        .byte %11111111,%11111111,%00000011,%00000011,%00000011,%00000011,%00000011,%00000011
        // FR_BL
        .byte %11000000,%11000000,%11000000,%11000000,%11000000,%11000000,%11111111,%11111111
        // FR_BR
        .byte %00000011,%00000011,%00000011,%00000011,%00000011,%00000011,%11111111,%11111111
        // FR_H (bovenrand)
        .byte %11111111,%11111111,%00000000,%00000000,%00000000,%00000000,%00000000,%00000000
        // FR_V (linkerrand)
        .byte %11000000,%11000000,%11000000,%11000000,%11000000,%11000000,%11000000,%11000000

        // ---- CHAT 2x2-icoon (tekstballon met ...), codes 102-105 ----
        .byte $00,$3f,$60,$c0,$80,$80,$99,$99   // 102 TL
        .byte $00,$fc,$06,$03,$01,$01,$99,$99   // 103 TR
        .byte $80,$80,$c0,$60,$39,$0a,$0c,$08   // 104 BL
        .byte $01,$01,$03,$06,$fc,$00,$00,$00   // 105 BR
        .byte $00,$00,$00,$00,$00,$00,$00,$00   // 106 (reserve)

        // ---- 2x2 dock-iconen (codes 107-126), volgorde TL,TR,BL,BR per icoon ----
        // PING (radiogolven + echo) 107-110
        .byte $07,$18,$60,$87,$18,$20,$07,$08   // TL
        .byte $e0,$18,$06,$e1,$18,$04,$e0,$10   // TR
        .byte $00,$03,$07,$07,$03,$00,$00,$00   // BL
        .byte $00,$c0,$e0,$e0,$c0,$00,$00,$00   // BR
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
        // CITY (skyline, groot icoon voor gebruikersprogramma's) 123-126
        .byte $00,$01,$03,$02,$03,$72,$53,$72   // TL
        .byte $00,$00,$80,$80,$9c,$94,$9c,$94   // TR
        .byte $53,$72,$53,$72,$53,$ff,$00,$00   // BL
        .byte $9c,$94,$9c,$94,$9c,$ff,$00,$00   // BR

//--------------------------------------------------------
// userIcons - 20 launcher-iconen (1 cel, 8x8) op charset-codes 64..83.
// Elk 8 bytes; bit7 = linkerpixel, byte0 = bovenste rij.
//--------------------------------------------------------
userIcons:
        .byte $fe,$c6,$c6,$fe,$82,$ba,$82,$fe   // 0  floppy disk
        .byte $00,$78,$fc,$84,$84,$84,$fc,$00   // 1  folder
        .byte $7c,$44,$7c,$54,$44,$54,$7c,$00   // 2  document
        .byte $18,$5a,$3c,$e7,$e7,$3c,$5a,$18   // 3  gear
        .byte $18,$18,$db,$7e,$7e,$db,$18,$18   // 4  sparkle/star
        .byte $66,$ff,$ff,$ff,$7e,$3c,$18,$00   // 5  heart
        .byte $3c,$7e,$ff,$ff,$ff,$ff,$7e,$3c   // 6  ball
        .byte $18,$18,$18,$3c,$7e,$ff,$81,$ff   // 7  joystick
        .byte $e0,$e0,$70,$38,$1c,$0e,$07,$07   // 8  tool
        .byte $3c,$42,$99,$bd,$bd,$99,$42,$3c   // 9  globe
        .byte $00,$ff,$c3,$a5,$99,$81,$ff,$00   // 10 envelope
        .byte $3c,$42,$92,$92,$9e,$82,$42,$3c   // 11 clock
        .byte $1e,$12,$12,$12,$32,$76,$e4,$40   // 12 music note
        .byte $18,$18,$3c,$3c,$7e,$ff,$ff,$7e   // 13 paint drop
        .byte $18,$18,$18,$ff,$ff,$18,$18,$18   // 14 cross
        .byte $40,$60,$70,$78,$78,$70,$60,$40   // 15 play arrow
        .byte $3c,$42,$a5,$81,$a5,$99,$42,$3c   // 16 smiley
        .byte $38,$44,$44,$38,$10,$10,$18,$14   // 17 key
        .byte $c0,$fc,$cc,$fc,$c0,$c0,$c0,$c0   // 18 flag
        .byte $00,$ff,$81,$b1,$8d,$b1,$9f,$ff   // 19 terminal
// Win95-glyphs (codes 84-89)
// knoppen: 7x7 vlak + 1 pixel schaduw rechts/onder (= achtergrond) -> 3D
        .byte $fe,$ba,$d6,$ee,$d6,$ba,$fe,$00   // 84 sluitknop (kruisje uitgespaard)
        .byte $fe,$fe,$ee,$c6,$82,$fe,$fe,$00   // 85 pijl omhoog (uitgespaard)
        .byte $fe,$fe,$82,$c6,$ee,$fe,$fe,$00   // 86 pijl omlaag (uitgespaard)
        .byte $aa,$55,$aa,$55,$aa,$55,$aa,$55   // 87 scroll-track (dither)
        .byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe   // 88 scroll-thumb (midden)
        .byte $ff,$00,$00,$00,$00,$00,$00,$00   // 89 dock-bovenrand
        .byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$00   // 90 scroll-thumb (onderkant)
// vensterkader tegen de buitenrand (2 pixels dik)
        .byte $c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0   // 91 linkerrand
        .byte $03,$03,$03,$03,$03,$03,$03,$03   // 92 rechterrand
        .byte $00,$00,$00,$00,$00,$00,$ff,$ff   // 93 onderrand
        .byte $c0,$c0,$c0,$c0,$c0,$c0,$ff,$ff   // 94 hoek linksonder
        .byte $03,$03,$03,$03,$03,$03,$ff,$ff   // 95 hoek rechtsonder

// (De System-charset zelf zit niet meer in de Core: disk_main.asm laadt
//  hem als eigen segment op $3800, main_cart.asm kopieert hem uit ROM.
//  LOWER en TINY zijn eigen charset-bestanden op disk: zie disk_main.asm.)
