#importonce
//========================================================
// net/tcp.asm - minimale TCP-client (één verbinding) op de CS8900
// Commodore Desk 64
//
// Genoeg voor een HTTP-verzoek: verbinden (SYN), één blok data zenden
// (met herhaling tot het bevestigd is), in volgorde ontvangen (elk
// byte gaat naar de callback tcpRxVec) en netjes sluiten (FIN).
// Segmenten die niet in volgorde komen worden weggegooid; de server
// stuurt ze opnieuw na onze dubbele ACK. Venster 1024, MSS 1024.
// 32-bit volgnummers staan big-endian (netwerkvolgorde).
//
// TCP-kop in het frame (vanaf 34): 34 src-poort, 36 dst-poort, 38 seq,
// 42 ack, 46 data-offset, 47 vlaggen, 48 venster, 50 checksum, 52 urg.
//========================================================

.const TCP_FIN = $01
.const TCP_SYN = $02
.const TCP_RST = $04
.const TCP_PSH = $08
.const TCP_ACK = $10

.const TS_CLOSED  = 0
.const TS_SYNSENT = 1
.const TS_EST     = 2

// -----------------------------------------------------
// tcp_Connect - verbind met ipDst:tcpRPort (arpMac moet al bekend zijn).
//               Uit: carry=1 verbonden.
// -----------------------------------------------------
tcp_Connect: {
        lda frameLo              // lokale poort $C0xx, ISN uit de klok
        sta tcpLPort+1
        lda #$c0
        sta tcpLPort
        lda frameHi
        sta tcpIsn
        lda frameLo
        sta tcpIsn+1
        lda #$64
        sta tcpIsn+2
        sta tcpIsn+3
        ldx #3
cp:     lda tcpIsn,x             // na de SYN is snd = ISN+1
        sta tcpSnd,x
        dex
        bpl cp
        jsr inc32Snd
        lda #0
        sta tcpRst
        sta tcpFin
        sta tcpGotData
        lda #TS_SYNSENT
        sta tcpState
        lda #3
        sta tcpTry
again:  ldx #3
ci:     lda tcpIsn,x
        sta tcpSeqOut,x
        dex
        bpl ci
        lda #0
        sta tcpDataLen
        sta tcpDataLen+1
        lda #TCP_SYN
        jsr tcp_Out
        lda #0
        sta netFlag
        lda #100                 // 2 s
        jsr net_Wait
        lda tcpState
        cmp #TS_EST
        beq ok
        lda tcpRst
        ora netAbort
        bne fail
        dec tcpTry
        bne again
fail:   lda #TS_CLOSED
        sta tcpState
        clc
        rts
ok:     sec
        rts
}

// -----------------------------------------------------
// tcp_Send - tcpDataLen bytes vanaf tcpDataPtr zenden en wachten tot
//            ze bevestigd zijn (5x 1 s). Uit: carry=1 bevestigd.
// -----------------------------------------------------
tcp_Send: {
        ldx #3
cp:     lda tcpSnd,x             // una = snd; snd += len
        sta tcpUna,x
        dex
        bpl cp
        clc
        lda tcpSnd+3
        adc tcpDataLen
        sta tcpSnd+3
        lda tcpSnd+2
        adc tcpDataLen+1
        sta tcpSnd+2
        bcc nc
        inc tcpSnd+1
        bne nc
        inc tcpSnd
nc:     lda #0
        sta tcpAcked
        lda #5
        sta tcpTry
again:  ldx #3
cs:     lda tcpUna,x
        sta tcpSeqOut,x
        dex
        bpl cs
        lda #TCP_PSH|TCP_ACK
        jsr tcp_Out
        lda #0
        sta netFlag
        lda #50
        jsr net_Wait
        lda tcpAcked
        bne ok
        lda tcpRst
        ora netAbort
        bne fail
        lda tcpState
        cmp #TS_EST
        bne fail
        dec tcpTry
        bne again
fail:   clc
        rts
ok:     sec
        rts
}

// tcp_Close - FIN|ACK sturen (niet op het antwoord wachten).
tcp_Close:
        lda tcpState
        beq !r+
        jsr seqFromSnd
        lda #0
        sta tcpDataLen
        sta tcpDataLen+1
        lda #TCP_FIN|TCP_ACK
        jsr tcp_Out
        lda #TS_CLOSED
        sta tcpState
!r:     rts

// tcp_SendAck - kale ACK met snd/rcv.
tcp_SendAck:
        jsr seqFromSnd
        lda #0
        sta tcpDataLen
        sta tcpDataLen+1
        lda #TCP_ACK
        jmp tcp_Out

seqFromSnd:
        ldx #3
!cp:    lda tcpSnd,x
        sta tcpSeqOut,x
        dex
        bpl !cp-
        rts

inc32Snd:
        inc tcpSnd+3
        bne !r+
        inc tcpSnd+2
        bne !r+
        inc tcpSnd+1
        bne !r+
        inc tcpSnd
!r:     rts

inc32Rcv:
        inc tcpRcv+3
        bne !r+
        inc tcpRcv+2
        bne !r+
        inc tcpRcv+1
        bne !r+
        inc tcpRcv
!r:     rts

// -----------------------------------------------------
// tcp_Out - segment met vlaggen A, seq = tcpSeqOut, ack = tcpRcv en
//           tcpDataLen bytes vanaf tcpDataPtr. SYN krijgt de MSS-optie.
// -----------------------------------------------------
tcp_Out: {
        sta tcpFlOut
        ldy #0
        lda #>ETH_IP
        ldx #<ETH_IP
        jsr eth_Hdr
        lda #20                  // TCP-koplengte
        ldx tcpFlOut
        cpx #TCP_SYN
        bne h20
        lda #24
h20:    sta tcpHl
        lda tcpLPort             // poorten
        sta TX+34
        lda tcpLPort+1
        sta TX+35
        lda tcpRPort
        sta TX+36
        lda tcpRPort+1
        sta TX+37
        ldx #3
sq:     lda tcpSeqOut,x
        sta TX+38,x
        lda tcpRcv,x
        sta TX+42,x
        dex
        bpl sq
        lda tcpFlOut             // bij SYN nog geen ack
        cmp #TCP_SYN
        bne ak
        lda #0
        sta TX+42
        sta TX+43
        sta TX+44
        sta TX+45
ak:     lda tcpHl
        asl
        asl
        sta TX+46                // (hl/4) << 4
        lda tcpFlOut
        sta TX+47
        lda #>1024               // venster
        sta TX+48
        lda #<1024
        sta TX+49
        lda #0
        sta TX+50
        sta TX+51
        sta TX+52
        sta TX+53
        lda tcpHl
        cmp #24
        bne data
        lda #2                   // MSS = 1024
        sta TX+54
        lda #4
        sta TX+55
        lda #>1024
        sta TX+56
        lda #<1024
        sta TX+57
data:   lda tcpDataLen           // payload kopiëren
        ora tcpDataLen+1
        beq nod
        lda tcpDataPtr
        sta netPtr
        lda tcpDataPtr+1
        sta netPtr+1
        lda #<[TX+54]
        sta ck2
        lda #>[TX+54]
        sta ck2+1
        lda tcpDataLen
        sta ckLen
        lda tcpDataLen+1
        sta ckLen+1
        jsr copyBlk
nod:    // tcp-lengte = hl + data
        lda tcpHl
        clc
        adc tcpDataLen
        sta tcpLen+1
        lda tcpDataLen+1
        adc #0
        sta tcpLen
        // pseudokop op TX+22..33: src, dst, 0, 6, lengte
        ldx #3
ps:     lda NC_IP,x
        sta TX+22,x
        lda ipDst,x
        sta TX+26,x
        dex
        bpl ps
        lda #0
        sta TX+30
        lda #6
        sta TX+31
        lda tcpLen
        sta TX+32
        lda tcpLen+1
        sta TX+33
        lda #<[TX+22]
        sta netPtr
        lda #>[TX+22]
        sta netPtr+1
        lda tcpLen+1
        clc
        adc #12
        sta ckLen
        lda tcpLen
        adc #0
        sta ckLen+1
        jsr ck_Sum
        lda ckRes
        sta TX+50
        lda ckRes+1
        sta TX+51
        // echte IP-kop
        lda #$45
        sta TX+14
        lda #0
        sta TX+15
        sta TX+18
        sta TX+20
        sta TX+21
        lda frameLo
        sta TX+19                // id
        lda tcpLen+1             // totlen = 20 + tcp
        clc
        adc #20
        sta TX+17
        lda tcpLen
        adc #0
        sta TX+16
        lda #64
        sta TX+22
        lda #6
        sta TX+23
        ldx #3
ih:     lda NC_IP,x
        sta TX+26,x
        lda ipDst,x
        sta TX+30,x
        dex
        bpl ih
        jsr ip_Csum
        lda TX+17                // frame = 14 + totlen
        clc
        adc #14
        sta netTxLen
        lda TX+16
        adc #0
        sta netTxLen+1
        jmp cs_Send
}

// copyBlk - ckLen bytes van (netPtr) naar (ck2).
copyBlk: {
        ldy #0
lp:     lda ckLen
        ora ckLen+1
        beq done
        lda (netPtr),y
        sta (ck2),y
        inc netPtr
        bne a
        inc netPtr+1
a:      inc ck2
        bne b
        inc ck2+1
b:      lda ckLen
        bne c
        dec ckLen+1
c:      dec ckLen
        jmp lp
done:   rts
}

// -----------------------------------------------------
// tcp_Input - TCP-segment in RX (aan ons IP) verwerken.
// -----------------------------------------------------
tcp_Input: {
        lda tcpState
        bne go
out:    rts
go:     lda RX+34                // poorten + afzender moeten kloppen
        cmp tcpRPort
        bne out
        lda RX+35
        cmp tcpRPort+1
        bne out
        lda RX+36
        cmp tcpLPort
        bne out
        lda RX+37
        cmp tcpLPort+1
        bne out
        ldx #3
ip:     lda RX+26,x
        cmp ipDst,x
        bne out
        dex
        bpl ip
        lda RX+47
        sta tcpFlIn
        and #TCP_RST
        beq noRst
        lda #TS_CLOSED
        sta tcpState
        lda #1
        sta tcpRst
        sta netFlag
        rts
noRst:  lda tcpState
        cmp #TS_SYNSENT
        bne est
        lda tcpFlIn              // SYN+ACK met ack = ISN+1?
        and #TCP_SYN|TCP_ACK
        cmp #TCP_SYN|TCP_ACK
        bne out
        ldx #3
sa:     lda RX+42,x
        cmp tcpSnd,x
        bne out
        dex
        bpl sa
        ldx #3
sr:     lda RX+38,x
        sta tcpRcv,x
        dex
        bpl sr
        jsr inc32Rcv
        lda #TS_EST
        sta tcpState
        lda #1
        sta netFlag
        jmp tcp_SendAck
est:    lda #0
        sta tcpNeedAck
        lda tcpFlIn              // ACK: alles bevestigd?
        and #TCP_ACK
        beq noAck
        ldx #3
ac:     lda RX+42,x
        cmp tcpSnd,x
        bne noAck
        dex
        bpl ac
        lda tcpAcked
        bne noAck
        lda #1
        sta tcpAcked
        sta netFlag
noAck:  lda tcpFlIn              // SYN-ACK nog eens (onze ACK kwijt)
        and #TCP_SYN
        beq noSyn
        jmp tcp_SendAck
noSyn:  lda RX+46                // koplengte in bytes
        lsr
        lsr
        and #$3c
        sta tcpHlIn
        lda RX+17                // payload = totlen - 20 - hl
        sec
        sbc #20
        sta tcpPl
        lda RX+16
        sbc #0
        sta tcpPl+1
        lda tcpPl
        sec
        sbc tcpHlIn
        sta tcpPl
        lda tcpPl+1
        sbc #0
        sta tcpPl+1
        ora tcpPl
        bne hasData
        jmp noData
hasData:
        ldx #3                   // in volgorde?
sq:     lda RX+38,x
        cmp tcpRcv,x
        bne dup
        dex
        bpl sq
        lda #<[RX+34]            // bytes afleveren
        clc
        adc tcpHlIn
        sta tcpRxPtr
        lda #>[RX+34]
        adc #0
        sta tcpRxPtr+1
        lda tcpPl
        sta tcpCnt
        lda tcpPl+1
        sta tcpCnt+1
dl:     lda tcpRxPtr
        sta netPtr
        lda tcpRxPtr+1
        sta netPtr+1
        ldy #0
        lda (netPtr),y
        jsr deliver
        inc tcpRxPtr
        bne d2
        inc tcpRxPtr+1
d2:     lda tcpCnt
        bne d3
        dec tcpCnt+1
d3:     dec tcpCnt
        lda tcpCnt
        ora tcpCnt+1
        bne dl
        clc                      // rcv += payload
        lda tcpRcv+3
        adc tcpPl
        sta tcpRcv+3
        lda tcpRcv+2
        adc tcpPl+1
        sta tcpRcv+2
        bcc r2
        inc tcpRcv+1
        bne r2
        inc tcpRcv
r2:     lda #1
        sta tcpGotData
        sta tcpNeedAck
        jmp fin
dup:    jmp tcp_SendAck          // niet in volgorde: dubbele ACK
noData: ldx #3                   // alleen FIN telt als seq klopt
nd:     lda RX+38,x
        cmp tcpRcv,x
        bne ackQ
        dex
        bpl nd
fin:    lda tcpFlIn
        and #TCP_FIN
        beq ackQ
        jsr inc32Rcv
        lda #1
        sta tcpFin
        sta netFlag
        sta tcpNeedAck
ackQ:   lda tcpNeedAck
        beq done
        jmp tcp_SendAck
done:   rts
deliver:
        jmp (tcpRxVec)
}

//--------------------------------------------------------
tcpState:   .byte 0
tcpLPort:   .word 0              // big-endian
tcpRPort:   .word 0              // big-endian
tcpIsn:     .fill 4, 0
tcpSnd:     .fill 4, 0
tcpUna:     .fill 4, 0
tcpRcv:     .fill 4, 0
tcpSeqOut:  .fill 4, 0
tcpDataPtr: .word 0
tcpDataLen: .word 0
.align 2                         // jmp (vector) mag niet op $xxFF staan
tcpRxVec:   .word 0              // callback: A = ontvangen byte
tcpRxPtr:   .word 0
tcpCnt:     .word 0
tcpPl:      .word 0
tcpLen:     .word 0              // big-endian (hi, lo)
tcpHl:      .byte 0
tcpHlIn:    .byte 0
tcpFlOut:   .byte 0
tcpFlIn:    .byte 0
tcpTry:     .byte 0
tcpAcked:   .byte 0
tcpRst:     .byte 0
tcpFin:     .byte 0
tcpGotData: .byte 0
tcpNeedAck: .byte 0
