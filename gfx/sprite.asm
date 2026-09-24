#importonce
//========================================================
// gfx/sprite.asm - cursor-sprite (sprite 0)
// Commodore Desk 64  (Fase 3)
//
// De muispijl is hardware-sprite 0. Data staat op $0340 (vrije
// cassette-buffer), pointer op $07F8 (scherm + $3F8).
//========================================================

.label SPR_MC = $d01c            // sprite multicolor-register

// spr_CursorInit - laad de pijl, richt sprite 0 in en zet 'm aan.
// Aanroepen NA drawScreen/gfx_Cls (die de sprite-pointers zou wissen).
// Klobbert: A,X
spr_CursorInit:
        ldx #0
!lp:    lda arrowData,x
        sta $0340,x
        inx
        cpx #63
        bne !lp-
        lda #13                  // $0340 / 64 = 13
        sta $07f8                // sprite 0 pointer
        lda #WHITE
        sta SPR0_COL
        lda SPR_MC
        and #$fe                 // sprite 0 = hi-res
        sta SPR_MC
        lda SPR_YEXP
        and #$fe
        sta SPR_YEXP
        lda SPR_XEXP
        and #$fe
        sta SPR_XEXP
        lda SPR_ENABLE
        ora #$01                 // sprite 0 aan
        sta SPR_ENABLE
        jsr spr_CursorUpdate
        rts

// spr_CursorUpdate - zet sprite 0 op de virtuele cursorpositie
//                    (crsXlo/crsXhi = sprite-X, crsY = sprite-Y).
// Klobbert: A,X
spr_CursorUpdate:
        lda crsXlo
        sta SPR0_X
        lda SPR_MSB_X
        and #$fe
        ldx crsXhi
        beq !+
        ora #$01
!:      sta SPR_MSB_X
        lda crsY
        sta SPR0_Y
        rts

//--------------------------------------------------------
// Pijl-sprite (24x21, hi-res, 63 bytes). Tip linksboven.
//--------------------------------------------------------
arrowData:
        .byte %10000000,0,0
        .byte %11000000,0,0
        .byte %11100000,0,0
        .byte %11110000,0,0
        .byte %11111000,0,0
        .byte %11111100,0,0
        .byte %11111110,0,0
        .byte %11111111,0,0
        .byte %11111000,0,0
        .byte %11011000,0,0
        .byte %10001100,0,0
        .byte %00001100,0,0
        .byte %00000110,0,0
        .byte %00000110,0,0
        .byte %00000011,0,0
        .byte %00000000,0,0
        .byte %00000000,0,0
        .byte %00000000,0,0
        .byte %00000000,0,0
        .byte %00000000,0,0
        .byte %00000000,0,0
