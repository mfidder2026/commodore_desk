#importonce
//========================================================
// net/cs8900.asm - CS8900a via RR-Net (Milestone 1: detectie)
// Commodore Desk 64
//
// Zet de clockport aan en leest PacketPage $0000 (product-ID
// $630E) en $0002 (revisie in bits 12-8).
//========================================================

// -----------------------------------------------------
// cs_Detect
// In:  -
// Uit: carry=1 gevonden (csRev = revisie), carry=0 niet
// Klobbert: A
// -----------------------------------------------------
cs_Detect: {
        lda #$01                 // Retro Replay: clockport aan. Alleen
        sta RR_CTRL              // schrijven: in VICE is $DE01 ook het ISQ-
                                 // register en lezen laat VICE hangen.
        lda #$00                 // PacketPage $0000: product-ID
        sta CS_PPPTR
        sta CS_PPPTR+1
        lda CS_PPDATA
        cmp #CS_PRODUCT_LO
        bne none
        lda CS_PPDATA+1
        cmp #CS_PRODUCT_HI
        bne none
        lda #$02                 // PacketPage $0002: product/revisie
        sta CS_PPPTR
        lda #$00
        sta CS_PPPTR+1
        lda CS_PPDATA+1
        and #$1f
        sta csRev
        sec
        rts
none:   clc
        rts
}

csRev:  .byte 0

// PacketPage-registers
.const PP_RXCFG   = $0102
.const PP_RXCTL   = $0104
.const PP_LINECTL = $0112
.const PP_SELFCTL = $0114
.const PP_RXEVENT = $0124
.const PP_SELFST  = $0136
.const PP_BUSST   = $0138
.const PP_IA      = $0158        // MAC-adres (3 woorden)

// pp_Ptr - PacketPage-pointer := A (lo) / X (hi).
pp_Ptr:
        sta CS_PPPTR
        stx CS_PPPTR+1
        rts

// -----------------------------------------------------
// cs_Init - soft reset, MAC instellen, ontvangst (eigen MAC +
//           broadcast) en zenden aan. Uit: carry=1 ok, 0 = time-out.
// -----------------------------------------------------
cs_Init: {
        lda #<PP_SELFCTL         // soft reset
        ldx #>PP_SELFCTL
        jsr pp_Ptr
        lda #$55                 // RESET (bit 6) + registernummer
        sta CS_PPDATA
        lda #$00
        sta CS_PPDATA+1
        ldy #0                   // wachten op INITD (SelfST bit 7)
        ldx #0
w:      lda #<PP_SELFST
        sta CS_PPPTR
        lda #>PP_SELFST
        sta CS_PPPTR+1
        lda CS_PPDATA
        bmi ok
        dex
        bne w
        dey
        bne w
        clc
        rts
ok:     lda #<PP_IA              // MAC: 3 woorden, laag byte eerst
        ldx #>PP_IA
        jsr pp_Ptr
        ldy #0
mac:    lda netMac,y
        sta CS_PPDATA
        lda netMac+1,y
        sta CS_PPDATA+1
        iny
        iny
        cpy #6
        beq macOk
        tya
        clc
        adc #<PP_IA
        ldx #>PP_IA
        jsr pp_Ptr
        jmp mac
macOk:  lda #<PP_RXCTL           // RxOKA + IndividualA + BroadcastA
        ldx #>PP_RXCTL
        jsr pp_Ptr
        lda #$05
        sta CS_PPDATA
        lda #$0d
        sta CS_PPDATA+1
        lda #<PP_LINECTL         // SerRxON + SerTxON
        ldx #>PP_LINECTL
        jsr pp_Ptr
        lda #$d3
        sta CS_PPDATA
        lda #$00
        sta CS_PPDATA+1
        sec
        rts
}

// -----------------------------------------------------
// cs_Send - frame NET_TXBUF, lengte netTxLen (min. 60 wordt aangevuld).
//           Uit: carry=1 verzonden, 0 = chip niet klaar (time-out).
// -----------------------------------------------------
cs_Send: {
        lda netTxLen+1
        bne big
        lda netTxLen
        cmp #60
        bcs big
        lda #60                  // korte frames aanvullen (padding = rommel)
        sta netTxLen
big:    lda #$c0                 // TxCMD: start na het hele frame
        sta CS_TXCMD
        lda #$00
        sta CS_TXCMD+1
        lda netTxLen
        sta CS_TXLEN
        lda netTxLen+1
        sta CS_TXLEN+1
        ldy #0                   // wachten op Rdy4TxNOW (BusST bit 8)
        ldx #0
w:      lda #<PP_BUSST
        sta CS_PPPTR
        lda #>PP_BUSST
        sta CS_PPPTR+1
        lda CS_PPDATA+1
        and #$01
        bne rdy
        dex
        bne w
        dey
        bne w
        clc
        rts
rdy:    lda #<NET_TXBUF
        sta netPtr
        lda #>NET_TXBUF
        sta netPtr+1
        lda netTxLen             // aantal woorden = (len+1)/2
        clc
        adc #1
        sta csCnt
        lda netTxLen+1
        adc #0
        lsr
        sta csCnt+1
        ror csCnt
        ldy #0
lp:     lda (netPtr),y
        sta CS_RXTX
        iny
        lda (netPtr),y
        sta CS_RXTX+1
        iny
        bne nc
        inc netPtr+1
nc:     lda csCnt
        bne dl
        dec csCnt+1
dl:     dec csCnt
        lda csCnt
        ora csCnt+1
        bne lp
        sec
        rts
}

// -----------------------------------------------------
// cs_Recv - als er een frame binnen is: naar NET_RXBUF, lengte in
//           netRxLen, carry=1. Anders carry=0.
// -----------------------------------------------------
cs_Recv: {
        lda #<PP_RXEVENT
        sta CS_PPPTR
        lda #>PP_RXEVENT
        sta CS_PPPTR+1
        lda CS_PPDATA+1          // RxOK = bit 8
        and #$01
        bne have
        clc
        rts
have:   lda CS_RXTX+1            // RxStatus (genegeerd)
        lda CS_RXTX
        lda CS_RXTX+1            // RxLength: hoog byte eerst
        sta netRxLen+1
        lda CS_RXTX
        sta netRxLen
        lda #<NET_RXBUF
        sta netPtr
        lda #>NET_RXBUF
        sta netPtr+1
        lda netRxLen             // woorden = (len+1)/2
        clc
        adc #1
        sta csCnt
        lda netRxLen+1
        adc #0
        lsr
        sta csCnt+1
        ror csCnt
        ldy #0
lp:     lda csCnt
        ora csCnt+1
        beq done
        lda CS_RXTX
        jsr put
        lda CS_RXTX+1
        jsr put
        lda csCnt
        bne dl
        dec csCnt+1
dl:     dec csCnt
        jmp lp
done:   lda netRxLen+1           // groter dan de buffer: weggooien
        cmp #>[NET_RXBUF_SIZE]
        bcs bad
        sec
        rts
bad:    clc
        rts
put:    ldx netPtr+1             // niet voorbij de buffer schrijven
        cpx #>[NET_RXBUF+NET_RXBUF_SIZE]
        bcs skip
        sta (netPtr),y
skip:   iny
        bne pr
        inc netPtr+1
pr:     rts
}

csCnt:    .word 0
netTxLen: .word 0
netRxLen: .word 0
