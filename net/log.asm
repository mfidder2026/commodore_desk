#importonce
//========================================================
// net/log.asm - netwerklog / debugmodus (bouwplan §38)
// Commodore Desk 64
//
// Als de log aan staat (NETWORK -> DEBUG LOG) schrijven de drivers
// korte regels over wat er gebeurt: ARP, PING, DNS, DHCP, TCP (vlaggen,
// SEQ, lengtes), HTTP-status en UCI-opdrachten. De laatste LOG_LINES
// regels staan in een ringbuffer op $F600 en zijn te bekijken via VIEW.
//
// Gebruik:  jsr log_Begin  (niets als de log uit staat)
//           ldx #<tekst / ldy #>tekst / jsr log_Str, log_Hex, log_Dec, ...
//           jsr log_End
// Alle log-routines bewaren X en Y niet; ze raken alleen logPtr ($06).
//========================================================

.label LOG_BUF   = $f600
.const LOG_LINES = 15
.const LOG_W     = 34
.label logPtr    = $06           // (gedeeld met hPtr: beide zetten hem
                                 //  bij elke aanroep opnieuw)

// log_Begin - nieuwe regel (gewist). Uit: logOn = 1 als er gelogd wordt.
log_Begin: {
        lda netDebug
        sta logOn
        beq out
        lda #0
        sta logCol
        jsr ptr
        ldy #LOG_W-1
        lda #$20
cl:     sta (logPtr),y
        dey
        bpl cl
out:    rts
ptr:    ldx logHead
        lda logRowLo,x
        sta logPtr
        lda logRowHi,x
        sta logPtr+1
        rts
}

// log_End - regel klaar: volgende positie in de ring.
log_End: {
        lda logOn
        beq out
        inc logHead
        lda logHead
        cmp #LOG_LINES
        bcc n
        lda #0
        sta logHead
n:      lda logCount
        cmp #LOG_LINES
        bcs out
        inc logCount
out:    rts
}

// log_Chr - één schermcode achter de regel.
log_Chr: {
        ldx logOn
        beq out
        ldx logCol
        cpx #LOG_W
        bcs out
        pha
        ldx logHead
        lda logRowLo,x
        sta logPtr
        lda logRowHi,x
        sta logPtr+1
        pla
        ldy logCol
        sta (logPtr),y
        inc logCol
out:    rts
}

// log_Str - X/Y = tekst (schermcodes, $ff-afgesloten).
log_Str: {
        lda logOn
        beq out
        stx smc+1
        sty smc+2
        lda #0
        sta logI
lp:     ldy logI
smc:    lda $ffff,y              // (adres wordt hierboven ingevuld)
        cmp #$ff
        beq out
        jsr log_Chr
        inc logI
        bne lp
out:    rts
}

// log_Hex - A als 2 hex-cijfers.
log_Hex: {
        pha
        lsr
        lsr
        lsr
        lsr
        jsr nib
        pla
        and #$0f
nib:    cmp #10
        bcc dig
        sbc #9                   // A-F -> schermcode 1-6 (carry=1)
        jmp log_Chr
dig:    ora #$30
        jmp log_Chr
}

// log_Dec - A decimaal (zonder voorloopnullen).
log_Dec: {
        sta logN
        ldx #0
        stx logAny
dg:     lda #0
        sta logD
        lda logN
sb:     cmp logDec,x
        bcc put
        sbc logDec,x
        inc logD
        jmp sb
put:    sta logN
        lda logD
        bne pr
        lda logAny
        bne pr
        cpx #2
        bne nx
pr:     lda logD
        ora #$30
        stx logX
        jsr log_Chr
        ldx logX
        inc logAny
nx:     inx
        cpx #3
        bne dg
        rts
}
logDec: .byte 100, 10, 1

// log_Ip - 4 bytes op X/Y als a.b.c.d.
log_Ip: {
        lda logOn
        beq out
        stx smc+1
        sty smc+2
        lda #0
        sta logI
lp:     ldy logI
smc:    lda $ffff,y
        jsr log_Dec
        inc logI
        lda logI
        cmp #4
        beq out
        lda #$2e
        jsr log_Chr
        jmp lp
out:    rts
}

// log_Sp - spatie.
log_Sp:
        lda #$20
        jmp log_Chr

// log_Clear - log leegmaken.
log_Clear:
        lda #0
        sta logHead
        sta logCount
        rts

logRowLo: .fill LOG_LINES, <[LOG_BUF + i*LOG_W]
logRowHi: .fill LOG_LINES, >[LOG_BUF + i*LOG_W]
netDebug: .byte 0                // 1 = log aan (NETWORK -> DEBUG LOG)
logOn:    .byte 0
logHead:  .byte 0                // volgende regel in de ring
logCount: .byte 0
logCol:   .byte 0
logI:     .byte 0
logN:     .byte 0
logD:     .byte 0
logAny:   .byte 0
logX:     .byte 0
