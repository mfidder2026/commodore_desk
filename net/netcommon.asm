#importonce
//========================================================
// net/netcommon.asm - hulproutines die de netwerklaag gebruikt
// Commodore Desk 64
//
// Staat in elke overlay die de netwerklaag meeneemt (INET en BBS), zodat
// de drivers niet afhangen van een bepaalde app.
//========================================================

// schermcode -> ASCII (letters klein) voor hostnamen, modellen e.d.
sc2ascii: {
        cmp #0
        bne n0
        lda #$40                 // @
        rts
n0:     cmp #27
        bcs n1
        ora #$60                 // 1-26 -> a-z
        rts
n1:     cmp #$1b
        bne n2
        lda #$5b                 // [
        rts
n2:     cmp #$1d
        bne n4
        lda #$5d                 // ]
        rts
n4:     cmp #$64
        bne n3
        lda #$5f                 // _
n3:     rts                      // $20-$3f = ASCII
}

// ip_Parse - feBuf/feLen "a.b.c.d" -> ipTmp[4]. Carry=1 geldig.
ip_Parse: {
        ldx #0                   // X = positie in feBuf
        ldy #0                   // Y = octet
oct:    lda #0
        sta ipVal
        sta ipDig
dig:    cpx feLen
        beq endOct
        lda feBuf,x
        cmp #$2e
        beq endOct
        cmp #$30                 // alleen cijfers
        bcc bad
        cmp #$3a
        bcs bad
        and #$0f
        sta ipD
        lda ipVal                // val = val*10 + cijfer, max 255
        cmp #26
        bcs bad
        asl
        sta ipT
        asl
        asl
        adc ipT
        adc ipD
        bcs bad
        sta ipVal
        inx
        inc ipDig
        lda ipDig
        cmp #4
        bcs bad
        jmp dig
endOct: lda ipDig
        beq bad
        lda ipVal
        sta ipTmp,y
        iny
        cpy #4
        beq last
        cpx feLen                // na octet 1-3 moet een punt komen
        beq bad
        inx
        jmp oct
last:   cpx feLen                // na octet 4: klaar
        bne bad
        sec
        rts
bad:    clc
        rts
}

csReady:  .byte 0                // CS8900 is geinitialiseerd
feLen:    .byte 0
ipVal:    .byte 0
ipDig:    .byte 0
ipD:      .byte 0
ipT:      .byte 0
ipTmp:    .fill 4, 0
feBuf:    .fill 48, 0

.encoding "screencode_upper"
sPgNoArp: .text "NO ANSWER (ARP)"
          .byte $ff
sPgStop:  .text "STOPPED"
          .byte $ff
sPgChip:  .text "CS8900 INIT FAILED"
          .byte $ff
sChHost:  .text "INVALID HOST NAME"
          .byte $ff
sChPort:  .text "INVALID PORT"
          .byte $ff
