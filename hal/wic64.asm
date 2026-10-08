#importonce
//========================================================
// hal/wic64.asm - WiC64 (WLAN-module op de userport), firmware 2.x
// Commodore Desk 64
//
// Protocol "R" (zie github.com/WiC64-Team/wic64-library, README):
//   verzoek:  "R", opdracht, grootte (LE, 2), payload
//   antwoord: status, grootte (LE, 2), payload
// Byte voor byte over CIA2 poort B ($DD01). PA2 ($DD00 bit 2) geeft de
// richting aan (hoog = de C64 zendt), de WiC64 bevestigt elke byte via
// FLAG2 ($DD0D bit 4); lezen of schrijven van $DD01 geeft PC2 als
// handshake terug. De interrupts blijven aan (muis en klok lopen door);
// de WiC64 wacht tot 1 s per byte.
// Staat in de Core zodat alle netwerk-overlays hem delen; de TCP-laag
// erbovenop zit in net/wic64net.asm.
//========================================================

.const WC_TMO = 6                // ~6,6 s: ook voor trage servers

// -----------------------------------------------------
// wc_Req - opdracht A met payload wcPtr/wcLen. Elke antwoordbyte gaat
//          naar (wcVec) in A (X/Y mogen stuk).
//          Uit: carry=1 time-out (geen WiC64), anders A = status (Z=1 = 0,
//          goed) en wcSize = grootte van het antwoord.
// -----------------------------------------------------
wc_Req: {
        sta wcHdr+1
        lda #$52                 // "R"
        sta wcHdr
        lda wcLen
        sta wcHdr+2
        sta wcN
        lda wcLen+1
        sta wcHdr+3
        sta wcN+1
        lda wcPtr
        sta src+1
        lda wcPtr+1
        sta src+2
        lda $dd0d                // FLAG2 wissen
        lda $dd02                // PA2 = uitgang, hoog: de C64 zendt
        ora #$04
        sta $dd02
        lda $dd00
        ora #$04
        sta $dd00
        lda #$ff
        sta $dd03
        ldx #0
hd:     lda wcHdr,x
        jsr put
        bcs to
        inx
        cpx #4
        bne hd
pl:     lda wcN                  // payload
        ora wcN+1
        beq rx
src:    lda $ffff
        jsr put
        bcs to
        inc src+1
        bne p1
        inc src+2
p1:     jsr cnt
        jmp pl
rx:     lda #0                   // omdraaien: de WiC64 zendt
        sta $dd03
        lda $dd00
        and #$fb
        sta $dd00
        jsr wait                 // bevestiging (ook: klaar met het werk)
        bcs to
        lda $dd01
        ldx #0
rh:     jsr get                  // status + grootte
        bcs to
        sta wcRsp,x
        inx
        cpx #3
        bne rh
        lda wcRsp+1
        sta wcSize
        sta wcN
        lda wcRsp+2
        sta wcSize+1
        sta wcN+1
rd:     lda wcN
        ora wcN+1
        beq done
        jsr get
        bcs to
        jsr call
        jsr cnt
        jmp rd
done:   jsr fin
        clc
        lda wcRsp
        rts
to:     jsr fin
        sec
        rts
fin:    lda #0                   // poort weer ingang
        sta $dd03
        lda $dd0d
        rts
put:    sta $dd01
        jmp wait
get:    jsr wait
        bcs gr
        lda $dd01
gr:     rts
cnt:    lda wcN
        bne d1
        dec wcN+1
d1:     dec wcN
        rts
call:   jmp (wcVec)
// wait - op FLAG2 wachten; carry=1 na wcTmo x ~1,1 s.
wait:   lda #$10
        bit $dd0d
        bne ok
        lda wcTmo
        sta wcC+2
        lda wcC1
        sta wcC+1
        lda #0
        sta wcC
w:      lda #$10
        bit $dd0d
        bne ok
        dec wcC
        bne w
        dec wcC+1
        bne w
        dec wcC+2
        bne w
        sec
        rts
ok:     clc
        rts
}

// -----------------------------------------------------
// wc_Detect - WiC64 met firmware 2.x aanwezig? Carry=1 ja. Kort wachten
//             (~0,2 s), want zonder WiC64 komt er nooit een handshake.
// -----------------------------------------------------
wc_Detect: {
        lda #1
        sta wcTmo
        lda #$30
        sta wcC1
        lda #0
        sta wcLen
        sta wcLen+1
        jsr wc_NoRx
        lda #$00                 // GET_VERSION_STRING
        jsr wc_Req
        php
        pha
        lda #WC_TMO
        sta wcTmo
        lda #0
        sta wcC1
        pla
        plp
        bcs no                   // geen antwoord
        bne no                   // (oude firmware: niet ondersteund)
        sec
        rts
no:     clc
        rts
}

// wc_NoRx - antwoordbytes weggooien.
wc_NoRx:
        lda #<wcDrop
        sta wcVec
        lda #>wcDrop
        sta wcVec+1
wcDrop: rts

.label wcHdr = $c0e4             // (vrij RAM, niet in de Core)
.label wcRsp = $c0e8
wcPtr:  .word 0
wcLen:  .word 0
wcN:    .word 0
wcSize: .word 0
.align 2                         // jmp (wcVec) niet op $xxFF
wcVec:  .word wcDrop
wcTmo:  .byte WC_TMO
wcC1:   .byte 0                  // 0 = 256 (lang), kleiner bij het zoeken
.label wcC = $c0eb
