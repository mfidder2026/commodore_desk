#importonce
//========================================================
// gfx/uiglyphs.asm - glyph-data van de UI (segment UiGlyphs, $DC00)
// Commodore Desk 64
//
// Staat niet in de Core maar in de RAM onder de I/O: build_disk.bat zet
// deze data in HELPTEXT (offset $0C00), help_Load kopieert het geheel naar
// $D000. font_OverlayUI kopieert hieruit met $01 = $34 (I/O uit).
//========================================================

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

// GEOS-stijl: dun vensterkader (1 pixel) voor 91-95.
thinFrame:
        .byte $80,$80,$80,$80,$80,$80,$80,$80   // 91 linkerrand
        .byte $01,$01,$01,$01,$01,$01,$01,$01   // 92 rechterrand
        .byte $00,$00,$00,$00,$00,$00,$00,$ff   // 93 onderrand
        .byte $80,$80,$80,$80,$80,$80,$80,$ff   // 94 hoek linksonder
        .byte $01,$01,$01,$01,$01,$01,$01,$ff   // 95 hoek rechtsonder
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
