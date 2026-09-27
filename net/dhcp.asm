#importonce
//========================================================
// net/dhcp.asm - DHCP-client voor de RR-Net
// Commodore Desk 64
//
// DISCOVER (broadcast) -> OFFER -> REQUEST -> ACK. Uit het ACK komen
// IP, MASK, GATEWAY en DNS in NETCFG; SAVE bewaart ze. De Ultimate
// regelt zijn IP zelf en heeft dit niet nodig.
//
// BOOTP-bericht in het frame (vanaf 42): 42 op, 43 htype, 44 hlen,
// 46 xid, 52 flags, 58 yiaddr, 70 chaddr, 278 magic cookie,
// 282 opties. Het bericht wordt aangevuld tot 300 bytes.
//========================================================

#if DHCPTEST
.const DHCP_SRV = 6767           // testbuild: hoge poorten (testserver in WSL
.const DHCP_CLI = 6868           // zonder root-rechten)
#else
.const DHCP_SRV = 67
.const DHCP_CLI = 68
#endif
.const BOOTP = 42                // begin van het BOOTP-bericht
.const BOOTP_LEN = 300

// -----------------------------------------------------
// dhcp_Run - adres opvragen. Uit: carry=1 -> NETCFG bijgewerkt,
//            carry=0 -> X/Y = melding.
// -----------------------------------------------------
dhcp_Run: {
        lda #0
        sta netAbort
        lda frameHi              // transactie-id
        sta dhXid
        lda frameLo
        sta dhXid+1
        lda #$c6
        sta dhXid+2
        lda #$4d
        sta dhXid+3
        lda #1                   // wachten op een OFFER
        sta dhState
        lda #3
        sta dhTry
dis:    lda #1                   // DISCOVER
        jsr dh_Send
        lda #0
        sta netFlag
        lda #100
        jsr net_Wait
        lda dhState
        cmp #2
        beq req
        lda netAbort
        bne stop
        dec dhTry
        bne dis
        ldx #<sDhNone
        ldy #>sDhNone
        jmp fail
req:    lda #3
        sta dhTry
rq:     lda #3                   // REQUEST
        jsr dh_Send
        lda #0
        sta netFlag
        lda #100
        jsr net_Wait
        lda dhState
        cmp #3
        beq ack
        cmp #4
        beq nak
        lda netAbort
        bne stop
        dec dhTry
        bne rq
        ldx #<sDhNone
        ldy #>sDhNone
        jmp fail
nak:    ldx #<sDhNak
        ldy #>sDhNak
        jmp fail
stop:   ldx #<sPgStop
        ldy #>sPgStop
fail:   lda #0
        sta dhState
        clc
        rts
ack:    ldx #3                   // overnemen in NETCFG
cp:     lda dhIp,x
        sta NC_IP,x
        lda dhMask,x
        sta NC_MASK,x
        lda dhGw,x
        sta NC_GW,x
        lda dhDns,x
        sta NC_DNS,x
        dex
        bpl cp
        lda #0
        sta dhState
        sta arpValid             // ander netwerk: ARP-cache ongeldig
        sec
        rts
}

// -----------------------------------------------------
// dh_Send - DHCP-bericht A (1 = DISCOVER, 3 = REQUEST) broadcasten.
// -----------------------------------------------------
dh_Send: {
        sta dhType
        ldy #1                   // Ethernet-broadcast
        lda #>ETH_IP
        ldx #<ETH_IP
        jsr eth_Hdr
        lda #<[TX+BOOTP]         // BOOTP-deel wissen
        sta ck2
        lda #>[TX+BOOTP]
        sta ck2+1
        ldx #>BOOTP_LEN+1
        ldy #0
        tya
clr:    sta (ck2),y
        iny
        bne clr
        inc ck2+1
        dex
        bne clr
        lda #1                   // op = request, Ethernet, MAC 6 lang
        sta TX+BOOTP
        sta TX+BOOTP+1
        lda #6
        sta TX+BOOTP+2
        ldx #3
xi:     lda dhXid,x
        sta TX+BOOTP+4,x
        dex
        bpl xi
        lda #$80                 // antwoord als broadcast (wij hebben nog geen IP)
        sta TX+BOOTP+10
        ldx #5
mc:     lda netMac,x
        sta TX+BOOTP+28,x        // chaddr
        dex
        bpl mc
        ldx #3
mg:     lda dhMagic,x
        sta TX+BOOTP+236,x
        dex
        bpl mg
        ldy #0                   // opties vanaf TX+BOOTP+240 (> 255: via ck2)
        lda #<[TX+BOOTP+240]
        sta ck2
        lda #>[TX+BOOTP+240]
        sta ck2+1
        lda #53                  // berichttype
        jsr put
        lda #1
        jsr put
        lda dhType
        jsr put
        lda dhType
        cmp #3
        bne prl
        lda #50                  // REQUEST: gevraagd IP + server
        jsr put
        lda #4
        jsr put
        ldx #0
r1:     lda dhIp,x
        jsr put
        inx
        cpx #4
        bne r1
        lda #54
        jsr put
        lda #4
        jsr put
        ldx #0
r2:     lda dhSrv,x
        jsr put
        inx
        cpx #4
        bne r2
prl:    lda #55                  // gevraagd: mask, router, DNS
        jsr put
        lda #3
        jsr put
        lda #1
        jsr put
        lda #3
        jsr put
        lda #6
        jsr put
        lda #255                 // einde
        jsr put
        // UDP 68 -> 67, lengte 8 + 300
        lda #>DHCP_CLI
        sta TX+34
        lda #<DHCP_CLI
        sta TX+35
        lda #>DHCP_SRV
        sta TX+36
        lda #<DHCP_SRV
        sta TX+37
        lda #>[8+BOOTP_LEN]
        sta TX+38
        lda #<[8+BOOTP_LEN]
        sta TX+39
        lda #0
        sta TX+40
        sta TX+41
        // IP 0.0.0.0 -> 255.255.255.255
        lda #$45
        sta TX+14
        lda #0
        sta TX+15
        sta TX+18
        sta TX+20
        sta TX+21
        lda frameLo
        sta TX+19
        lda #>[28+BOOTP_LEN]
        sta TX+16
        lda #<[28+BOOTP_LEN]
        sta TX+17
        lda #64
        sta TX+22
        lda #17
        sta TX+23
        ldx #3
ia:     lda #0
        sta TX+26,x
        lda #$ff
        sta TX+30,x
        dex
        bpl ia
        jsr ip_Csum
        lda #<[14+28+BOOTP_LEN]
        sta netTxLen
        lda #>[14+28+BOOTP_LEN]
        sta netTxLen+1
        jmp cs_Send
put:    sta (ck2),y
        iny
        rts
}
dhMagic: .byte 99, 130, 83, 99

// -----------------------------------------------------
// dhcp_Input - UDP naar poort 68: OFFER / ACK / NAK voor ons?
//              Uit: carry=1 als het een DHCP-pakket was.
// -----------------------------------------------------
dhcp_Input: {
        lda RX+36
        cmp #>DHCP_CLI
        bne no
        lda RX+37
        cmp #<DHCP_CLI
        beq go
no:     clc
        rts
go:     lda dhState
        bne !+
        jmp yes                  // we vragen niets: negeren
!:
        lda RX+BOOTP             // op = reply, zelfde xid
        cmp #2
        beq !+
        jmp yes
!:
        ldx #3
xi:     lda RX+BOOTP+4,x
        cmp dhXid,x
        beq !+
        jmp yes
!:
        dex
        bpl xi
        lda #0
        sta dhMsg
        lda #<[RX+BOOTP+240]     // opties lezen
        sta ck2
        lda #>[RX+BOOTP+240]
        sta ck2+1
        ldy #0
op:     lda (ck2),y
        beq pad
        cmp #255
        beq done
        sta dhCode
        iny
        lda (ck2),y              // lengte
        sta dhLen
        iny
        lda dhCode
        cmp #53
        bne o1
        lda (ck2),y
        sta dhMsg
        jmp skip
o1:     cmp #54
        bne o2
        ldx #<dhSrv
        jmp cp4
o2:     cmp #1
        bne o3
        ldx #<dhMask
        jmp cp4
o3:     cmp #3
        bne o4
        ldx #<dhGw
        jmp cp4
o4:     cmp #6
        bne skip
        ldx #<dhDns
cp4:    stx dhDst                // eerste 4 bytes naar dhSrv/Mask/Gw/Dns
        sty dhY
        ldx #0
c4:     lda (ck2),y
        sta dhBase,x             // (dhDst - dhBase) + x
        iny
        inx
        cpx #4
        bne c4
        jsr place
        ldy dhY
skip:   tya                      // y += lengte
        clc
        adc dhLen
        tay
        bcs done                 // (buiten de 256 bytes: stoppen)
        jmp op
pad:    iny
        bne op
done:   lda dhMsg
        cmp #2
        bne nOf
        lda dhState              // OFFER
        cmp #1
        beq !+
        jmp yes
!:
        ldx #3
yi:     lda RX+BOOTP+16,x        // yiaddr
        sta dhIp,x
        dex
        bpl yi
        lda #2
        sta dhState
        sta netFlag
        jmp yes
nOf:    cmp #5
        bne nAck
        lda dhState              // ACK
        cmp #2
        beq !+
        jmp yes
!:
        ldx #3
ya:     lda RX+BOOTP+16,x
        sta dhIp,x
        dex
        bpl ya
        lda #3
        sta dhState
        sta netFlag
        jmp yes
nAck:   cmp #6
        beq !+
        jmp yes
!:
        lda #4                   // NAK
        sta dhState
        sta netFlag
yes:    sec
        rts
place:  lda dhDst                // dhBase -> doel (dhSrv/Mask/Gw/Dns)
        sec
        sbc #<dhBase
        tax
        ldy #0
pl:     lda dhBase,y
        sta dhBase,x
        inx
        iny
        cpy #4
        bne pl
        rts
}

dhState: .byte 0                 // 0 uit, 1 wacht OFFER, 2 wacht ACK, 3 klaar, 4 NAK
dhType:  .byte 0
dhTry:   .byte 0
dhMsg:   .byte 0
dhCode:  .byte 0
dhLen:   .byte 0
dhY:     .byte 0
dhDst:   .byte 0
dhXid:   .fill 4, 0
// (dhBase..dhDns in één pagina: place rekent met de lage bytes)
dhBase:  .fill 4, 0              // scratch
dhIp:    .fill 4, 0
dhSrv:   .fill 4, 0
dhMask:  .fill 4, 0
dhGw:    .fill 4, 0
dhDns:   .fill 4, 0
.assert "dhBase..dhDns in één pagina", >dhBase, >[dhDns+3]

.encoding "screencode_upper"
sDhNone: .text "NO DHCP SERVER ANSWERED"
         .byte $ff
sDhNak:  .text "DHCP SERVER REFUSED (NAK)"
         .byte $ff
