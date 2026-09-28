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
// GEOS-stijl: 24x24-iconen (GEOSICON, tools/make_geosicons.py) op codes
// 128-253, 9 per icoon; de ingebouwde programma's hebben icoon 0-8 in de
// volgorde van biIcon, daarna deze:
.const GI_BASE     = 128
.const GI_APP      = 9
.const GI_DRIVE    = 10
.const GI_PRINTER  = 11
.const GI_TRASH    = 12
.const GI_TRASHF   = 13
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
        php                      // glyph-data ligt onder de I/O ($DC00)
        sei
        lda $01
        pha
        lda #$34
        sta $01
        jsr fo_Ov
        pla
        sta $01
        plp
        jmp geos_Icons           // GEOS-stijl: de grote iconen erover
fo_Ov:
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
        lda stGeos               // GEOS: dunner vensterkader (91-95)
        beq tr
        ldx #39
tf:     lda thinFrame,x
        sta CHARSET_BASE+W_L*8,x
        dex
        bpl tf
tr:     rts
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

// geos_Icons - in de GEOS-stijl GEOSICON laden: codes 128-253.
geos_Icons: {
        lda stGeos
        beq r
        jsr cfg_io_begin
        lda #nmE-nm
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #1
        jsr K_SETLFS
        lda #0
        jsr K_LOAD
        jsr cfg_io_end
r:      rts
.encoding "petscii_upper"
nm:     .text "GEOSICON"
nmE:
.encoding "screencode_upper"
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

// De glyph-data (kaders, iconen, bronnen van de bureaublad-iconen) staat
// in gfx/uiglyphs.asm: segment UiGlyphs op $DC00, RAM onder de I/O, mee
// geladen met HELPTEXT (tools/make_help.py). font_OverlayUI leest hem
// daarom met de I/O even uit.
