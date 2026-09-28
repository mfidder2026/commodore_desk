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
// Pokéball (groot 2x2-icoon, POKEMON RED): in de reverse-helft, op de
// codes van de omgekeerde iconen 120-123 (die worden nooit reverse getoond).
// Bureaublad-iconen (16x16) worden 2 breed x 3 hoog getekend, 4 pixels
// omlaag geschoven: zo staat het label (1 rij) precies naast het midden.
// icon_Build maakt die 6 glyphs per icoon uit de 2x2-tekeningen, in de
// reverse-helft (codes 192-245: de omgekeerde UI-glyphs zijn nooit nodig).
.const ICON3_BASE = 192
.const ICON3_N    = 10
.const ICO_EDIT   = ICON3_BASE + 0*6
.const ICO_PAINT  = ICON3_BASE + 1*6
.const ICO_CALC   = ICON3_BASE + 2*6
.const ICO_PING   = ICON3_BASE + 3*6
.const ICO_CHAT   = ICON3_BASE + 4*6
.const ICO_BBS    = ICON3_BASE + 5*6
.const MAIL_GLYPH = ICON3_BASE + 6*6   // envelop (EMAIL)
.const ICO_CITY   = ICON3_BASE + 7*6
.const POKE_GLYPH = ICON3_BASE + 8*6   // Pokéball
.const ICO_SID    = ICON3_BASE + 9*6   // muzieknoot (SID PLAYER), t/m 251
// RADIO: net als de andere 2x3, maar op codes 252-255 (boven, midden) en
// 80-81 (onder): 80-83 zijn alleen de bron van het BBS-icoon en worden
// bij elke font-wissel eerst teruggezet (font_OverlayUI). Op het
// bureaublad staat ICO_RADIO_D (zie da_draw2x2 in deskapps.asm).
.const ICO_RADIO   = 252
.const ICO_RADIO_B = 80          // onderste rij
.const ICO_RADIO_D = ICO_RADIO - 2
// GEOS-stijl: titelstrepen en knoppenpatroon, na icon_Build op 82-83
// (net als 80-81 alleen bron van het BBS-icoon)
.const GL_STRIPE   = 82
.const GL_DOTS     = 83
.const OVL_GLYPHS = 32   // 20 iconen + 12 Win95-glyphs = codes 64..95 (256 bytes)

// font_Init - de System-charset staat al op $3800 (cd64.prg laadt hem
//             daar direct; de cart kopieert hem uit ROM). Bewaar een
//             schone kopie in RAM onder I/O ($D000) voor latere
//             fontwissels, overlay de UI-glyphs en richt de VIC op $3800.
// Klobbert: A,X
// (De System-charset = de karakter-ROM: font_Base kopieert hem uit de ROM;
//  het RAM onder de I/O op $D000 is voor de F1-teksten, zie gui/help.asm.)
font_Init:
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
// font_Base - schone System-charset (2 KB) uit de karakter-ROM ($D000,
//             met $01 = $33) naar $3800; interrupts uit tijdens het kopieren.
//--------------------------------------------------------
font_Base:
        php
        sei
        lda $01
        pha
        lda #$33                 // karakter-ROM zichtbaar op $D000 (geen I/O)
        sta $01
        ldx #0
!lp:
    .for (var p=0; p<8; p++) {
        lda $d000 + p*$100,x
        sta CHARSET_BASE + p*$100,x
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
        // Reverse-helft (codes 128-255) = de omgekeerde normale helft, voor
        // elk font opnieuw: menubalk, titels en statusbalk (reverse tekst)
        // volgen zo altijd het gekozen font (Tiny/Lower hadden daar nog
        // de System-letters).
        ldx #0
!rv:
    .for (var p=0; p<4; p++) {
        lda CHARSET_BASE + p*$100,x
        eor stRevMask            // GEOS-stijl: niet omgekeerd
        sta CHARSET_BASE + $400 + p*$100,x
    }
        inx
        bne !rv-
        ldx #7                   // GL_SOLID: altijd een vol blok
        lda #$ff                 // (kleurvlakken, cursor)
!sb:    sta CHARSET_BASE + GL_SOLID*8,x
        dex
        bpl !sb-
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
        jmp icon_Build
.assert "userIcons moet 256 bytes zijn", OVL_GLYPHS*8, 256

//--------------------------------------------------------
// icon_Build - bureaublad-iconen 2x2 -> 2x3 (4 pixels omlaag), zie
//              ICON3_BASE. Bron: TL, TR, BL, BR (32 bytes) per icoon.
//--------------------------------------------------------
icon_Build: {
        lda #<[CHARSET_BASE + ICON3_BASE*8]
        sta r5
        lda #>[CHARSET_BASE + ICON3_BASE*8]
        sta r5+1
        ldx #0
ic:     stx ibI
        lda ibSrcLo,x
        sta r4
        lda ibSrcHi,x
        sta r4+1
        ldx #0
by:     ldy ibMap,x              // bronbyte (of $ff = leeg)
        lda #0
        cpy #$ff
        beq st
        lda (r4),y
st:     pha
        txa
        tay
        pla
        sta (r5),y
        inx
        cpx #48
        bne by
        lda r5                   // volgende 6 glyphs
        clc
        adc #48
        sta r5
        bcc nc
        inc r5+1
nc:     ldx ibI
        inx
        cpx #ICON3_N
        bne ic
        ldx #0                   // RADIO: zelfde omzetting, andere codes
rg:     ldy ibMap,x
        lda #0
        cpy #$ff
        beq rs
        lda radioGlyphs,y
rs:     cpx #32
        bcs rb
        sta CHARSET_BASE+ICO_RADIO*8,x
        bcc rn
rb:     sta CHARSET_BASE+ICO_RADIO_B*8-32,x
rn:     inx
        cpx #48
        bne rg
        ldx #15                  // strepen + stippen (GEOS-stijl)
sg:     lda styleGlyphs,x
        sta CHARSET_BASE+GL_STRIPE*8,x
        dex
        bpl sg
        rts
// 6 glyphs x 8 rijen: TL', TR', midden-L, midden-R, BL', BR'
ibMap:  .byte $ff,$ff,$ff,$ff, 0, 1, 2, 3        // TL': 4 leeg + TL 0-3
        .byte $ff,$ff,$ff,$ff, 8, 9,10,11        // TR'
        .byte  4, 5, 6, 7, 16,17,18,19           // ML: TL 4-7 + BL 0-3
        .byte 12,13,14,15, 24,25,26,27           // MR: TR 4-7 + BR 0-3
        .byte 20,21,22,23, $ff,$ff,$ff,$ff       // BL': BL 4-7 + 4 leeg
        .byte 28,29,30,31, $ff,$ff,$ff,$ff       // BR'
// bron per icoon (volgorde = ICO_*): charset-glyphs of eigen tabellen
ibSrcLo: .byte <[CHARSET_BASE+111*8], <[CHARSET_BASE+115*8], <[CHARSET_BASE+119*8]
         .byte <[CHARSET_BASE+107*8], <[CHARSET_BASE+102*8], <[CHARSET_BASE+80*8]
         .byte <mailGlyphs, <[CHARSET_BASE+123*8], <pokeGlyphs, <sidGlyphs
ibSrcHi: .byte >[CHARSET_BASE+111*8], >[CHARSET_BASE+115*8], >[CHARSET_BASE+119*8]
         .byte >[CHARSET_BASE+107*8], >[CHARSET_BASE+102*8], >[CHARSET_BASE+80*8]
         .byte >mailGlyphs, >[CHARSET_BASE+123*8], >pokeGlyphs, >sidGlyphs
}
ibI:    .byte 0

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

// GEOS-stijl: strepen (titelbalk) en een licht stippenpatroon (knoppen).
styleGlyphs:
        .byte $ff,$00,$ff,$00,$ff,$00,$ff,$00
        .byte $00,$44,$00,$11,$00,$44,$00,$11
// Radio met antenne 16x16 (TL, TR, BL, BR): SID RADIO.
radioGlyphs:
        .byte $00,$00,$00,$7f,$80,$be,$aa,$be   // TL
        .byte $10,$20,$40,$fe,$01,$7d,$45,$7d   // TR
        .byte $aa,$be,$80,$80,$7f,$20,$00,$00   // BL
        .byte $01,$6d,$6d,$01,$fe,$04,$00,$00   // BR
// Muzieknoot 16x16 (TL, TR, BL, BR): SID PLAYER.
sidGlyphs:
        .byte $00,$07,$07,$04,$04,$04,$04,$04   // TL
        .byte $00,$fe,$fe,$02,$02,$02,$02,$02   // TR
        .byte $04,$04,$3c,$7c,$7c,$38,$00,$00   // BL
        .byte $02,$02,$1e,$3e,$3e,$1c,$00,$00   // BR
// Envelop 16x16 (TL, TR, BL, BR) direct gevolgd door de Pokéball.
mailGlyphs:
        .byte $00,$00,$7f,$60,$50,$48,$44,$42   // TL
        .byte $00,$00,$fe,$06,$0a,$12,$22,$42   // TR
        .byte $41,$40,$40,$40,$40,$7f,$00,$00   // BL
        .byte $82,$02,$02,$02,$02,$fe,$00,$00   // BR
// Pokéball 16x16 (TL, TR, BL, BR): bovenhelft vol, knop in het midden.
pokeGlyphs:
        .byte $07,$1f,$3f,$7f,$7f,$fc,$fb,$04   // TL
        .byte $e0,$f8,$fc,$fe,$fe,$3f,$df,$20   // TR
        .byte $84,$83,$80,$40,$40,$20,$18,$07   // BL
        .byte $21,$c1,$01,$02,$02,$04,$18,$e0   // BR

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
// BBS-icoon (2x2: CRT met >_ en netwerkindicator), codes 80-83
        .byte $7f,$40,$5f,$50,$54,$52,$55,$50   // 80 TL
        .byte $fe,$02,$fa,$0a,$0a,$0a,$ca,$0a   // 81 TR
        .byte $5f,$40,$7f,$03,$0f,$00,$00,$00   // 82 BL
        .byte $fa,$02,$fe,$c4,$f5,$05,$09,$00   // 83 BR
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
