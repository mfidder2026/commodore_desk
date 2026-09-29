#importonce
//========================================================
// apps/printer_drv.asm - printerdriver (Epson, Star, HP LaserJet)
// Commodore Desk 64
//
// Een macro: EDITOR, PAINT en DESKTOOL zijn aparte overlays en krijgen
// elk een eigen kopie met eigen labels:  edPr: PrinterDriver()
// en dan  jsr edPr.pr_Open  enzovoort.
//
// Instelling: CFG_printer (SETTINGS via het PRINT-icoon op het bureaublad)
//   bit 0-1  0 = EPSON (ESC/P), 1 = STAR (native), 2 = HP LASERJET (PCL)
//   bit 7    0 = serieel, device 4 (secundair adres PR_SA)
//            1 = userport (Centronics-kabel: PB0-7 data, PA2 STROBE,
//                FLAG2 <- ACK)
//
// pr_Open            printer openen + reset. Carry=1: X/Y = melding.
// pr_Byte  (A)       een byte. Carry=1: fout of RUN/STOP (X/Y = melding).
// pr_Line  (r6, Y)   Y schermcodes vanaf (r6) als tekstregel + CR LF.
// pr_Picture         160x184 dikke pixels via de callback prPixV:
//                    prX (0-159), prY (0-183) -> carry=1 = inkt.
// pr_Close           pagina uitwerpen en sluiten (ook na een fout).
//========================================================

.macro PrinterDriver() {
.const PR_SA   = 5               // secundair adres: "transparant" op de
                                 // gangbare interfaces (Xetec e.d.)
.const PR_ESC  = $1b             // (tekens als hexwaarden: ASCII)

pr_Open:
        lda CFG_printer
        and #3
        cmp #3
        bcc !t+
        lda #0
!t:     sta prType
        lda CFG_printer
        and #$80
        sta prPort
        lda #0
        sta prOpen
        jsr cfg_io_begin         // (IRQ uit, KERNAL aan)
        lda prPort
        bne !up+
        lda #0                   // serieel: OPEN 4,4,PR_SA
        jsr K_SETNAM
        lda #4
        ldx #4
        ldy #PR_SA
        jsr K_SETLFS
        lda #0
        sta $90
        jsr K_OPEN
        bcs !nf+
        ldx #4
        jsr K_CHKOUT             // hier pas praat de bus: geen device =
        bcs !nf+                 // DEVICE NOT PRESENT
        lda #1
        sta prOpen
        jmp !in+
!nf:    jsr pr_Shut
        ldx #<sPrNotFound
        ldy #>sPrNotFound
        sec
        rts
!up:    lda #$ff                 // userport: PB = uitgang, PA2 = STROBE
        sta $dd03
        lda $dd02
        ora #$04
        sta $dd02
        lda $dd00
        ora #$04
        sta $dd00
        lda $dd0d                // (FLAG wissen)
        lda #1
        sta prOpen
!in:    ldx prType               // reset: ESC @ (Epson/Star), ESC E (HP)
        lda #PR_ESC
        jsr pr_Byte
        bcs !r+
        ldx prType
        lda #$40
        cpx #2
        bne !b+
        lda #$45
!b:     jmp pr_Byte
!r:     rts

// pr_Byte - A naar de printer. Carry=1: X/Y = melding.
pr_Byte:
        sta prB
        lda #$7f                 // RUN/STOP (toetsenbordkolom 7, rij 7)
        sta $dc00
        lda $dc01
        and #$80
        bne !go+
        ldx #<sPrStopped
        ldy #>sPrStopped
        sec
        rts
!go:    lda prPort
        bne !up+
        lda prB
        jsr K_CHROUT
        lda $90                  // bit 7: device weg
        bmi !nf+
        clc
        rts
!nf:    ldx #<sPrNotFound
        ldy #>sPrNotFound
        sec
        rts
!up:    lda prB                  // Centronics: data, STROBE-puls, op ACK
        sta $dd01                // (FLAG2) wachten
        lda $dd00
        and #$fb
        sta $dd00
        ora #$04
        sta $dd00
        lda #8                   // ~1,5 s
        sta prTo
        ldx #0
        ldy #0
!w:     lda $dd0d
        and #$10
        bne !ok+
        dex
        bne !w-
        dey
        bne !w-
        dec prTo
        bne !w-
        ldx #<sPrNotReady
        ldy #>sPrNotReady
        sec
        rts
!ok:    clc
        rts

// pr_Str - $00-afgesloten reeks bytes (X/Y) naar de printer.
pr_Str:
        stx r5                   // (r5: zeropage)
        sty r5+1
        lda #0
        sta prI
!l:     ldy prI
        lda (r5),y
        beq !d+
        jsr pr_Byte
        bcs !r+
        inc prI
        bne !l-
!d:     clc
!r:     rts

// pr_Line - Y schermcodes vanaf (r6) + CR LF (ASCII).
pr_Line:
        sty prN
        lda #0
        sta prI
!l:     ldy prI
        cpy prN
        bcs !e+
        lda (r6),y
        jsr pr_Asc
        jsr pr_Byte
        bcs !r+
        inc prI
        bne !l-
!e:     lda #$0d
        jsr pr_Byte
        bcs !r+
        lda #$0a
        jmp pr_Byte
!r:     rts

// pr_Asc - schermcode -> ASCII (hoofdletters, SHIFT-letters -> klein).
pr_Asc:
        cmp #$00
        bne !a+
        lda #$40
        rts
!a:     cmp #$1b
        bcs !b+
        ora #$40                 // 1-26 -> A-Z
        rts
!b:     cmp #$40
        bcc !r+                  // spatie, cijfers, leestekens
        cmp #$41
        bcc !q+
        cmp #$5b
        bcs !c+
        ora #$20                 // $41-$5A -> a-z
        rts
!c:     cmp #$64
        bne !q+
        lda #$5f
        rts
!q:     lda #$3f
!r:     rts

// pr_Close - pagina uit (FF; HP ook reset) en sluiten.
pr_Close:
        lda #$0c
        jsr pr_Byte
        bcs pr_Shut
        lda prType
        cmp #2
        bne pr_Shut
        lda #PR_ESC
        jsr pr_Byte
        bcs pr_Shut
        lda #$45
        jsr pr_Byte
// pr_Shut - kanaal dicht / userport terug (zonder nog iets te sturen).
pr_Shut:
        php                      // (carry en X/Y van een melding blijven)
        txa
        pha
        tya
        pha
        lda prPort
        bne !up+
        jsr K_CLRCHN
        lda #4
        jsr K_CLOSE
        jmp !e+
!up:    lda #0                   // PB weer ingang
        sta $dd03
!e:     jsr cfg_io_end
        pla
        tay
        pla
        tax
        plp
        rts

//--------------------------------------------------------
// pr_Picture - 160x184 dikke pixels (2 punten breed) als grafiek.
//--------------------------------------------------------
pr_Picture:
        lda prType
        cmp #2
        bne !esc+
        jmp pr_PicHP
!esc:   ldx #<pr_EscSp           // regelafstand 8/72": ESC A 8 (Epson ook
        ldy #>pr_EscSp           // ESC 2 om die te gebruiken; bij een Star
        jsr pr_Str               // is ESC 2 juist 1/6")
        bcs !r+
        lda prType
        bne !bd+
        lda #PR_ESC
        jsr pr_Byte
        bcs !r+
        lda #$32
        jsr pr_Byte
        bcs !r+
!bd:    lda #0                   // 23 banden van 8 rijen
        sta prBand
!bl:    ldx #<pr_EscK            // ESC K 320: 320 kolommen van 8 punten
        ldy #>pr_EscK
        jsr pr_Str
        bcs !r+
        lda #0
        sta prX
!cl:    jsr pr_Col               // kolombyte van dikke pixel prX
        lda prC
        jsr pr_Byte              // 2x: dikke pixel = 2 punten
        bcs !r+
        lda prC
        jsr pr_Byte
        bcs !r+
        inc prX
        lda prX
        cmp #160
        bne !cl-
        lda #$0d
        jsr pr_Byte
        bcs !r+
        lda #$0a
        jsr pr_Byte
        bcs !r+
        inc prBand
        lda prBand
        cmp #23
        bne !bl-
        clc
!r:     rts

// pr_Col - prC = 8 punten van kolom prX in band prBand (bit 7 = boven).
pr_Col:
        lda #0
        sta prC
        lda prBand
        asl
        asl
        asl
        sta prY
        ldx #8
!l:     stx prK
        jsr pr_Pix
        rol prC
        inc prY
        ldx prK
        dex
        bne !l-
        rts

pr_Pix: jmp (prPixV)

// pr_PicHP - PCL-raster, 75 dpi: per rij ESC *b40W + 40 bytes.
pr_PicHP:
        ldx #<pr_HpStart
        ldy #>pr_HpStart
        jsr pr_Str
        bcs !r+
        lda #0
        sta prY
!rl:    ldx #<pr_HpRow
        ldy #>pr_HpRow
        jsr pr_Str
        bcs !r+
        lda #0
        sta prX
!bl:    lda #0                   // 1 byte = 4 dikke pixels = 8 punten
        sta prC
        ldx #4
!px:    stx prK
        jsr pr_Pix
        php
        rol prC
        plp
        rol prC
        inc prX
        ldx prK
        dex
        bne !px-
        lda prC
        jsr pr_Byte
        bcs !r+
        lda prX
        cmp #160
        bne !bl-
        inc prY
        lda prY
        cmp #184
        bne !rl-
        ldx #<pr_HpEnd
        ldy #>pr_HpEnd
        jmp pr_Str
!r:     rts

pr_EscSp:   .byte PR_ESC, $41, 8, 0
pr_EscK:    .byte PR_ESC, $4b, <320, >320, 0
pr_HpStart: .byte PR_ESC, $2a, $74, $37, $35, $52, PR_ESC, $2a, $72, $31, $41, 0
pr_HpRow:   .byte PR_ESC, $2a, $62, $34, $30, $57, 0
pr_HpEnd:   .byte PR_ESC, $2a, $72, $42, 0

prType:  .byte 0
prPort:  .byte 0
prOpen:  .byte 0
prB:     .byte 0
prTo:    .byte 0
prI:     .byte 0
prN:     .byte 0
prK:     .byte 0
prC:     .byte 0
prX:     .byte 0
prY:     .byte 0
prBand:  .byte 0
prPixV:  .word 0
.encoding "screencode_upper"
sPrNotFound: .text "NO PRINTER ON DEVICE 4"
             .byte $ff
sPrNotReady: .text "USERPORT PRINTER NOT READY"
             .byte $ff
sPrStopped:  .text "PRINTING STOPPED"
             .byte $ff
}
