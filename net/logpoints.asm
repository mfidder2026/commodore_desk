#importonce
//========================================================
// net/logpoints.asm - de logregels van de netwerklog (§38)
// Commodore Desk 64
//
// Eén jsr per plek in de drivers; elke routine doet niets als de log
// uit staat (log_Begin zet logOn). Wordt als laatste in de INET-overlay
// geassembleerd, zodat alle labels van de drivers bekend zijn.
//========================================================

.macro LOGS(txt) {
        ldx #<txt
        ldy #>txt
        jsr log_Str
}
.macro LOGIP(adr) {
        ldx #<adr
        ldy #>adr
        jsr log_Ip
}

lg_ArpAsk:
        jsr log_Begin
        LOGS(tArpQ)
        LOGIP(arpIp)
        jmp log_End
lg_ArpGot:
        jsr log_Begin
        LOGS(tArp)
        LOGIP(arpIp)
        jsr log_Sp
        ldx #0
!m:     stx logX2
        lda arpMac,x
        jsr log_Hex
        ldx logX2
        inx
        cpx #6
        bne !m-
        jmp log_End
lg_ArpFrom:
        jsr log_Begin
        LOGS(tArpFrom)
        LOGIP(RX+28)
        jmp log_End
lg_PingOut:
        jsr log_Begin
        LOGS(tPingOut)
        lda pingSeq
        jsr log_Dec
        jmp log_End
lg_PingIn:
        jsr log_Begin
        LOGS(tPingIn)
        lda pingSeq
        jsr log_Dec
        LOGS(tTtl)
        lda pingTtl
        jsr log_Dec
        jmp log_End
lg_PingedBy:
        jsr log_Begin
        LOGS(tPingedBy)
        LOGIP(RX+26)
        jmp log_End
lg_TcpOut:
        jsr log_Begin
        LOGS(tTcpOut)
        lda tcpFlOut
        jsr lgFlags
        LOGS(tSeq)
        lda tcpSeqOut+2
        jsr log_Hex
        lda tcpSeqOut+3
        jsr log_Hex
        LOGS(tLen)
        lda tcpOutLen+1
        jsr log_Hex
        lda tcpOutLen
        jsr log_Hex
        jmp log_End
lg_TcpIn:
        jsr log_Begin
        LOGS(tTcpIn)
        lda RX+47
        jsr lgFlags
        LOGS(tSeq)
        lda RX+40
        jsr log_Hex
        lda RX+41
        jsr log_Hex
        LOGS(tAck)
        lda RX+44
        jsr log_Hex
        lda RX+45
        jsr log_Hex
        jmp log_End
lg_TcpRst:
        jsr log_Begin
        LOGS(tTcpRst)
        jmp log_End
lg_TcpRetry:
        jsr log_Begin
        LOGS(tTcpRetry)
        jmp log_End
lg_DnsAsk:
        jsr log_Begin
        LOGS(tDnsQ)
        LOGS(dnsName)
        jmp log_End
lg_DnsGot:
        jsr log_Begin
        LOGS(tDns)
        LOGIP(dnsIp)
        jmp log_End
lg_DnsNf:
        jsr log_Begin
        LOGS(tDnsNf)
        jmp log_End
lg_DhSend:
        jsr log_Begin
        LOGS(tDhcp)
        ldx #<tDisc
        ldy #>tDisc
        lda dhType
        cmp #1
        beq !+
        ldx #<tReq
        ldy #>tReq
!:      jsr log_Str
        jmp log_End
lg_DhIn:
        jsr log_Begin
        LOGS(tDhcp)
        lda dhMsg
        ldx #<tOffer
        ldy #>tOffer
        cmp #2
        beq !+
        ldx #<tAckD
        ldy #>tAckD
        cmp #5
        beq !+
        ldx #<tNak
        ldy #>tNak
        cmp #6
        beq !+
        ldx #<tOther
        ldy #>tOther
!:      jsr log_Str
        jsr log_Sp
        LOGIP(RX+BOOTP+16)
        jmp log_End
lg_Uci:
        jsr log_Begin
        LOGS(tUci)
        lda ucCmd+1
        jsr log_Hex
        LOGS(tSt)
        lda ucStat               // statuscode: ASCII-cijfers = schermcodes
        jsr log_Chr
        lda ucStat+1
        jsr log_Chr
        LOGS(tN)
        lda ucResp+1
        jsr log_Hex
        lda ucResp
        jsr log_Hex
        jmp log_End
lg_UciFail:
        jsr log_Begin
        LOGS(tUciFail)
        lda ucCmd+1
        jsr log_Hex
        jmp log_End

// lgFlags - TCP-vlaggen als letters (R F P A S).
lgFlags: {
        sta logF
        ldx #4
lp:     lda logF
        and flBit,x
        beq no
        stx logX2
        lda flChr,x
        jsr log_Chr
        ldx logX2
no:     dex
        bpl lp
        rts
flBit:  .byte TCP_RST, TCP_FIN, TCP_PSH, TCP_ACK, TCP_SYN
flChr:  .byte $12, $06, $10, $01, $13
}
logF:   .byte 0
logX2:  .byte 0

.encoding "screencode_upper"
tArpQ:     .text "ARP? "
           .byte $ff
tArp:      .text "ARP "
           .byte $ff
tArpFrom:  .text "ARP FROM "
           .byte $ff
tPingOut:  .text "PING> SEQ "
           .byte $ff
tPingIn:   .text "PING< SEQ "
           .byte $ff
tTtl:      .text " TTL "
           .byte $ff
tPingedBy: .text "PINGED BY "
           .byte $ff
tTcpOut:   .text "TCP> "
           .byte $ff
tTcpIn:    .text "TCP< "
           .byte $ff
tSeq:      .text " SEQ "
           .byte $ff
tAck:      .text " ACK "
           .byte $ff
tLen:      .text " LEN "
           .byte $ff
tTcpRst:   .text "TCP RESET BY THE SERVER"
           .byte $ff
tTcpRetry: .text "TCP RETRY (NO ACK)"
           .byte $ff
tDnsQ:     .text "DNS? "
           .byte $ff
tDns:      .text "DNS "
           .byte $ff
tDnsNf:    .text "DNS: NAME NOT FOUND"
           .byte $ff
tDhcp:     .text "DHCP "
           .byte $ff
tDisc:     .text "DISCOVER"
           .byte $ff
tReq:      .text "REQUEST"
           .byte $ff
tOffer:    .text "OFFER"
           .byte $ff
tAckD:     .text "ACK"
           .byte $ff
tNak:      .text "NAK"
           .byte $ff
tOther:    .text "?"
           .byte $ff
tUci:      .text "UCI CMD "
           .byte $ff
tSt:       .text " ST "
           .byte $ff
tN:        .text " N "
           .byte $ff
tUciFail:  .text "UCI TIMEOUT CMD "
           .byte $ff
