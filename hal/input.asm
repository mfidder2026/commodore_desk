#importonce
//========================================================
// hal/input.asm - input-HAL: muis / joystick / toetsenbord
// Commodore Desk 64  (Fase 3)
//
// Eén virtuele cursor (crsX 16-bit sprite-X, crsY sprite-Y, crsBtn).
// input_Poll draait in de raster-IRQ: leest alle bronnen, verplaatst
// de cursor, klemt op het scherm en werkt sprite + debug bij.
//
// LET OP (nog interactief te verifiëren):
//  - 1351-muis wordt op POORT 1 verwacht; POT-poortselectie via
//    CIA1 PRA bits 6-7. Staat de muis op poort 2, wissel MOUSE_SEL.
//  - Muis-Y-richting kan geïnverteerd zijn afhankelijk van hardware.
//========================================================

.const CURSOR_SPEED = 3
.const CRS_XMIN = 24
.const CRS_XMAX = 340             // tot de rechterrand (dock-slot 5)
.const CRS_YMIN = 50
.const CRS_YMAX = 246             // tot onderin (dock-labels rij 24)
.const MOUSE_SEL = $40           // CIA1 PRA bits 6-7 -> poort 1 POT

//--------------------------------------------------------
input_Init:
        lda #160
        sta crsXlo
        lda #0
        sta crsXhi
        lda #130
        sta crsY
        lda #0
        sta crsBtn
        sta inSrc
        // muis-referentiewaarden
        lda #MOUSE_SEL
        sta CIA1_PRA
        lda POT_X
        sta mOldX
        lda POT_Y
        sta mOldY
        rts

//--------------------------------------------------------
// input_Poll - één keer per frame (vanuit de IRQ).
//--------------------------------------------------------
input_Poll:
        lda #0
        sta crsBtn               // knop elke frame opnieuw bepalen
        jsr rdMouse
        jsr rdJoystick
        jsr rdKeyboard
        jsr kbd_Scan
        jsr clampCursor
        jsr spr_CursorUpdate
        jsr evt_GenMouse
        rts

//--------------------------------------------------------
// kbd_Scan - volledige matrix-scan; genereert EVT_KEY op de
//            neergaande flank van een toets (geen auto-repeat).
//            Cursortoetsen en modifiers geven code 0 (genegeerd).
//--------------------------------------------------------
kbd_Scan:
        lda #$ff
        sta CIA1_DDRA
        lda #$ff
        sta kbFound
        ldx #0
!col:   lda colMask,x
        sta CIA1_PRA
        lda CIA1_PRB
        ldy #0
!row:   lsr
        bcs !nextrow+
        // ingedrukt: keycode = kol*8 + rij
        stx kbTmp
        txa
        asl
        asl
        asl
        sta kbCode
        tya
        ora kbCode
        sta kbFound
        jmp !scandone+
!nextrow:
        iny
        cpy #8
        bne !row-
        inx
        cpx #8
        bne !col-
!scandone:
        // flank-detectie
        lda kbFound
        cmp kbLast
        beq !done+
        sta kbLast
        cmp #$ff
        beq !done+               // losgelaten
        tax
        lda keyTab,x
        beq !done+               // 0 = negeren
        sta pushCol
        lda #0
        sta pushRow
        lda #EVT_KEY
        jsr evt_Push
!done:  rts

//--------------------------------------------------------
// cursorToCell - reken de cursorpositie om naar cel (evtA,evtB).
//--------------------------------------------------------
cursorToCell:
        lda crsXlo
        sec
        sbc #24
        sta t0
        lda crsXhi
        sbc #0
        sta t1
        lsr t1
        ror t0
        lsr t1
        ror t0
        lsr t1
        ror t0
        lda t0
        sta evtA
        lda crsY
        sec
        sbc #50
        lsr
        lsr
        lsr
        sta evtB
        rts

//--------------------------------------------------------
// evt_GenMouse - genereer MOUSEDOWN/MOUSEUP op knop-flanken,
//                met de cursorpositie omgerekend naar cel (kol,rij).
//--------------------------------------------------------
evt_GenMouse:
        lda crsBtn
        cmp lastBtn
        beq !done+
        sta lastBtn
        // kol = (crsX - 24) / 8
        lda crsXlo
        sec
        sbc #24
        sta t0
        lda crsXhi
        sbc #0
        sta t1
        lsr t1
        ror t0
        lsr t1
        ror t0
        lsr t1
        ror t0
        lda t0
        sta pushCol
        // rij = (crsY - 50) / 8
        lda crsY
        sec
        sbc #50
        lsr
        lsr
        lsr
        sta pushRow
        // type op basis van de nieuwe knopstaat
        lda crsBtn
        beq !up+
        lda #EVT_MOUSEDOWN
        jmp !push+
!up:
        lda #EVT_MOUSEUP
!push:
        jsr evt_Push
!done:
        rts

//--------------------------------------------------------
// Bewegingsprimitieven (klemmen gebeurt daarna in clampCursor).
//--------------------------------------------------------
moveLeft:
        lda crsXlo
        sec
        sbc #CURSOR_SPEED
        sta crsXlo
        lda crsXhi
        sbc #0
        sta crsXhi
        rts
moveRight:
        lda crsXlo
        clc
        adc #CURSOR_SPEED
        sta crsXlo
        lda crsXhi
        adc #0
        sta crsXhi
        rts
moveUp:
        lda crsY
        sec
        sbc #CURSOR_SPEED
        sta crsY
        rts
moveDown:
        lda crsY
        clc
        adc #CURSOR_SPEED
        sta crsY
        rts

//--------------------------------------------------------
// rdJoystick - poort 2 ($DC00), actief-laag.
//--------------------------------------------------------
rdJoystick:
        lda #$00
        sta CIA1_DDRA            // poort A als input
        lda CIA1_PRA
        sta joyRaw
        and #$01                 // up
        bne !+
        jsr moveUp
!:      lda joyRaw
        and #$02                 // down
        bne !+
        jsr moveDown
!:      lda joyRaw
        and #$04                 // left
        bne !+
        jsr moveLeft
!:      lda joyRaw
        and #$08                 // right
        bne !+
        jsr moveRight
!:      lda joyRaw
        and #$10                 // fire
        bne !+
        lda #$01
        sta crsBtn
!:      rts

//--------------------------------------------------------
// rdKeyboard - cursortoetsen (+ shift) en spatie (klik).
//   CRSR RECHTS/LINKS = kol0 rij2 ; CRSR OMLAAG/OMHOOG = kol0 rij7
//   SHIFT-links = kol1 rij7 ; SPATIE = kol7 rij4
//--------------------------------------------------------
rdKeyboard:
        lda #$ff
        sta CIA1_DDRA            // poort A als output (kolommen)
        // shift-status: LINKER (kol1 rij7) OF RECHTER (kol6 rij4) shift.
        // VICE stuurt host-pijltjes als shift+CRSR met de RECHTER shift,
        // dus beide moeten meetellen.
        lda #%11111101          // kolom 1
        sta CIA1_PRA
        lda CIA1_PRB
        and #$80                // rij 7 = shift-links (0 = ingedrukt)
        beq !shiftOn+
        lda #%10111111          // kolom 6
        sta CIA1_PRA
        lda CIA1_PRB
        and #$10                // rij 4 = shift-rechts (0 = ingedrukt)
        beq !shiftOn+
        lda #$ff                // geen shift
        sta kbShift
        jmp !shiftDone+
!shiftOn:
        lda #$00                // shift ingedrukt
        sta kbShift
!shiftDone:
        // kolom 0 (cursortoetsen)
        lda #%11111110
        sta CIA1_PRA
        lda CIA1_PRB
        sta kbCol0
        // rechts/links (rij 2)
        lda kbCol0
        and #$04
        bne !noRL+
        lda kbShift
        beq !doLeft+
        jsr moveRight
        jmp !noRL+
!doLeft:
        jsr moveLeft
!noRL:
        // omlaag/omhoog (rij 7)
        lda kbCol0
        and #$80
        bne !noUD+
        lda kbShift
        beq !doUp+
        jsr moveDown
        jmp !noUD+
!doUp:
        jsr moveUp
!noUD:
        lda paintSpace           // Paint: spatie ingedrukt = pen op papier
        beq !r+
        lda #%01111111           // kolom 7
        sta CIA1_PRA
        lda CIA1_PRB
        and #$10                 // rij 4 = spatie (0 = ingedrukt)
        bne !r+
        lda #1
        sta crsBtn
!r:     rts

//--------------------------------------------------------
// rdMouse - 1351 op poort 1 via POT_X/POT_Y (delta-tracking).
//--------------------------------------------------------
rdMouse:
        lda #$c0
        sta CIA1_DDRA            // bits 6-7 output voor POT-selectie
        lda #MOUSE_SEL
        sta CIA1_PRA

        // ---- X ----
        lda POT_X
        sec
        sbc mOldX
        pha                      // ruwe delta bewaren voor mOldX-update
        and #$7f
        cmp #$40
        bcc !+
        ora #$80                 // teken uitbreiden
!:      cmp #$80                 // teken -> carry
        ror                      // gedeeld door 2 (rekenkundig)
        beq !xdone+              // geen beweging
        // 16-bit teken-uitbreiding en optellen bij crsX
        tax
        ldy #0
        cpx #$80
        bcc !+
        ldy #$ff
!:      txa
        clc
        adc crsXlo
        sta crsXlo
        tya
        adc crsXhi
        sta crsXhi
!xdone:
        pla                      // ruwe delta
        clc
        adc mOldX
        sta mOldX                // = huidige POT_X

        // ---- Y ----
        lda POT_Y
        sec
        sbc mOldY
        pha
        and #$7f
        cmp #$40
        bcc !+
        ora #$80
!:      cmp #$80
        ror
        beq !ydone+
        // Y omlaag = crsY groter; POT loopt omgekeerd -> aftrekken
        sta tmpDy
        lda crsY
        sec
        sbc tmpDy
        sta crsY
!ydone:
        pla
        clc
        adc mOldY
        sta mOldY
        rts

//--------------------------------------------------------
// clampCursor - crsX in [24,320], crsY in [50,229].
//--------------------------------------------------------
clampCursor:
        // X-min
        lda crsXhi
        bne !chkMaxX+
        lda crsXlo
        cmp #CRS_XMIN
        bcs !chkMaxX+
        lda #CRS_XMIN
        sta crsXlo
        lda #0
        sta crsXhi
!chkMaxX:
        lda crsXhi
        cmp #>CRS_XMAX
        bcc !doneX+
        bne !setMaxX+
        lda crsXlo
        cmp #<CRS_XMAX
        bcc !doneX+
!setMaxX:
        lda #<CRS_XMAX
        sta crsXlo
        lda #>CRS_XMAX
        sta crsXhi
!doneX:
        // Y-min
        lda crsY
        cmp #CRS_YMIN
        bcs !chkMaxY+
        lda #CRS_YMIN
        sta crsY
!chkMaxY:
        lda crsY
        cmp #CRS_YMAX+1
        bcc !doneY+
        lda #CRS_YMAX
        sta crsY
!doneY:
        rts

//--------------------------------------------------------
// Cursorstaat + scratch (RAM in de geladen PRG).
//--------------------------------------------------------
crsXlo:  .byte 0
crsXhi:  .byte 0
crsY:    .byte 0
crsBtn:  .byte 0
paintSpace: .byte 0              // 1 = spatie is de pen (alleen in Paint)
inSrc:   .byte 0
joyRaw:  .byte 0
kbCol0:  .byte 0
kbShift: .byte 0
mOldX:   .byte 0
mOldY:   .byte 0
tmpDy:   .byte 0
lastBtn: .byte 0
t0:      .byte 0
t1:      .byte 0
kbFound: .byte $ff
kbLast:  .byte $ff
kbCode:  .byte 0
kbTmp:   .byte 0

// Kolom-selectiemaskers (bit X = 0 selecteert kolom X).
colMask: .byte $fe, $fd, $fb, $f7, $ef, $df, $bf, $7f

// Keycode (kol*8+rij) -> schermcode. 0 = negeren, $80 = RETURN, $81 = DEL.
keyTab:
        .byte $81,$80,$00,$00,$83,$00,$00,$00   // kol0: DEL RET CRSR-R F7 F1($83=HELP) F3 F5 CRSR-D
        .byte $33,$17,$01,$34,$1a,$13,$05,$00   // kol1: 3 W A 4 Z S E LSHIFT
        .byte $35,$12,$04,$36,$03,$06,$14,$18   // kol2: 5 R D 6 C F T X
        .byte $37,$19,$07,$38,$02,$08,$15,$16   // kol3: 7 Y G 8 B H U V
        .byte $39,$09,$0a,$30,$0d,$0b,$0f,$0e   // kol4: 9 I J 0 M K O N
        .byte $2b,$10,$0c,$2d,$2e,$3a,$00,$2c   // kol5: + P L - . : @ ,
        .byte $00,$2a,$3b,$00,$00,$3d,$00,$2f   // kol6: PND * ; HOME RSHIFT = UP /
        .byte $31,$00,$00,$32,$20,$00,$11,$82   // kol7: 1 <- CTRL 2 SPACE C= Q STOP($82=EXIT)
