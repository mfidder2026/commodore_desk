#importonce
//========================================================
// net/ip.asm - Ethernet II, ARP, IPv4 en ICMP-echo (Milestone 2-4)
// Commodore Desk 64
//
// Werkt op de CS8900 (RR-Net). Eén ARP-cache-entry, geen fragmentatie.
// Terwijl er gewacht wordt (net_Wait) beantwoordt de stack ARP-
// verzoeken voor ons IP en ping-verzoeken (ICMP echo) aan ons.
//
// Frame-offsets (RX en TX identiek):
//   0 dst-MAC, 6 src-MAC, 12 EtherType
//   ARP : 14 htype, 16 ptype, 18 hlen/plen, 20 op, 22 sha, 28 spa, 32 tha, 38 tpa
//   IPv4: 14 ver/ihl, 16 totlen, 18 id, 22 ttl, 23 proto, 24 csum, 26 src, 30 dst
//   ICMP: 34 type, 35 code, 36 csum, 38 id, 40 seq, 42 data
//========================================================

.const ETH_ARP  = $0806
.const ETH_IP   = $0800
.const ICMP_ID  = $4344          // "CD"
.const PING_DATA = 32

.label RX = NET_RXBUF
.label TX = NET_TXBUF

// -----------------------------------------------------
// eth_Hdr - TX-kop: dst = arpMac (Y=0) of broadcast (Y<>0), src = ons,
//           EtherType A (hi) / X (lo).
// -----------------------------------------------------
eth_Hdr: {
        sta TX+12
        stx TX+13
        ldx #5
lp:     lda #$ff
        cpy #0
        bne bc
        lda arpMac,x
bc:     sta TX,x
        lda netMac,x
        sta TX+6,x
        dex
        bpl lp
        rts
}

// -----------------------------------------------------
// ip_NextHop - arpIp := doel (zelfde subnet) of gateway. Doel in ipDst.
// -----------------------------------------------------
ip_NextHop: {
        ldx #3
lp:     lda ipDst,x
        eor NC_IP,x
        and NC_MASK,x
        bne gw
        dex
        bpl lp
        ldx #3
cp:     lda ipDst,x
        sta arpIp,x
        dex
        bpl cp
        rts
gw:     ldx #3
cg:     lda NC_GW,x
        sta arpIp,x
        dex
        bpl cg
        rts
}

// -----------------------------------------------------
// arp_Resolve - MAC van arpIp opzoeken (cache of 3x vragen, 1 s elk).
//               Uit: carry=1 -> arpMac geldig.
// -----------------------------------------------------
arp_Resolve: {
        lda arpValid             // cache: zelfde IP al bekend?
        beq ask
        ldx #3
cl:     lda arpIp,x
        cmp arpCacheIp,x
        bne ask
        dex
        bpl cl
        sec
        rts
ask:    lda #0
        sta arpValid
        lda #3
        sta arpTry
again:  jsr arp_Request
        lda #0
        sta netFlag
        lda #50
        jsr net_Wait
        bcs got
        lda netAbort
        bne fail
        dec arpTry
        bne again
fail:   clc
        rts
got:    ldx #3
sv:     lda arpIp,x
        sta arpCacheIp,x
        dex
        bpl sv
        lda #1
        sta arpValid
        sec
        rts
}

// arp_Request - broadcast "wie heeft arpIp?".
arp_Request: {
        ldy #1                   // broadcast
        lda #>ETH_ARP
        ldx #<ETH_ARP
        jsr eth_Hdr
        ldx #7
hd:     lda arpHdr,x             // htype/ptype/hlen/plen/op=1
        sta TX+14,x
        dex
        bpl hd
        ldx #5
m:      lda netMac,x             // sha = wij, tha = 0
        sta TX+22,x
        lda #0
        sta TX+32,x
        dex
        bpl m
        ldx #3
i:      lda NC_IP,x              // spa = ons IP, tpa = gezocht IP
        sta TX+28,x
        lda arpIp,x
        sta TX+38,x
        dex
        bpl i
        lda #42
        sta netTxLen
        lda #0
        sta netTxLen+1
        jmp cs_Send
}
arpHdr: .byte $00, $01, $08, $00, 6, 4, $00, $01

// -----------------------------------------------------
// net_Wait - A = max. frames (50 = 1 s). Ontvangt en verwerkt frames
//            tot netFlag<>0 (carry=1) of de tijd om is / ESC (carry=0,
//            netAbort=1 bij ESC).
// -----------------------------------------------------
net_Wait: {
        clc
        adc frameLo
        sta nwEnd
lp:     lda netFlag
        bne yes
        jsr evt_Poll             // ESC = afbreken
        cmp #EVT_KEY
        bne rx
        lda evtA
        cmp #$82
        bne rx
        lda #1
        sta netAbort
        clc
        rts
rx:     jsr net_Poll
tm:     lda frameLo              // (frameLo - einde) < 0 -> doorgaan
        sec
        sbc nwEnd
        bmi lp
        lda netFlag
        bne yes
        clc
        rts
yes:    sec
        rts
}

// -----------------------------------------------------
// net_Poll - hoogstens één keer per beeld (50 Hz) de CS8900 uitlezen en
//            dan alle wachtende frames verwerken. Continu pollen maakt
//            VICE (Npcap) extreem traag; op echte hardware scheelt het
//            hoogstens 20 ms.
// -----------------------------------------------------
net_Poll: {
        lda frameLo
        cmp npLast
        beq out
        sta npLast
lp:     jsr cs_Recv
        bcc out
        jsr net_Handle
        jmp lp
out:    rts
}
npLast: .byte 0

// -----------------------------------------------------
// net_Handle - verwerk het frame in RX.
// -----------------------------------------------------
net_Handle: {
        lda RX+12
        cmp #>ETH_ARP
        bne ipChk
        lda RX+13
        cmp #<ETH_ARP
        beq arp
        cmp #<ETH_IP
        bne out
        jmp ip
ipChk:  jmp out
arp:    ldx #3                   // gaat het over ons IP (tpa)?
ta:     lda RX+38,x
        cmp NC_IP,x
        bne out
        dex
        bpl ta
        lda RX+21                // op
        cmp #1
        beq arpReq
        cmp #2
        bne out
        ldx #3                   // antwoord: komt het van arpIp?
sp:     lda RX+28,x
        cmp arpIp,x
        bne out
        dex
        bpl sp
        ldx #5
cm:     lda RX+22,x
        sta arpMac,x
        dex
        bpl cm
        lda #1
        sta netFlag
out:    rts
arpReq: ldx #5                   // ARP-antwoord: wij zijn het
rm:     lda RX+22,x
        sta TX,x                 // dst = vrager
        sta TX+32,x              // tha
        lda netMac,x
        sta TX+6,x
        sta TX+22,x              // sha
        dex
        bpl rm
        lda #>ETH_ARP
        sta TX+12
        lda #<ETH_ARP
        sta TX+13
        ldx #6
ah:     lda arpHdr,x
        sta TX+14,x
        dex
        bpl ah
        lda #2                   // op = antwoord
        sta TX+21
        ldx #3
ri:     lda NC_IP,x
        sta TX+28,x
        lda RX+28,x
        sta TX+38,x
        dex
        bpl ri
        lda #42
        sta netTxLen
        lda #0
        sta netTxLen+1
        jmp cs_Send

ip:     ldx #3                   // IPv4 aan ons, ICMP?
di:     lda RX+30,x
        cmp NC_IP,x
        bne out2
        dex
        bpl di
        lda RX+14
        cmp #$45                 // alleen 20-byte-kop
        bne out2
        lda RX+23
        cmp #6                   // TCP -> tcp.asm
        bne icmp
        jmp tcp_Input
icmp:   cmp #1
        bne out2
        lda RX+34                // ICMP-type
        beq reply
        cmp #8
        beq echoReq
out2:   rts
reply:  lda RX+38                // echo reply: onze id + seq + van het doel?
        cmp #>ICMP_ID
        bne out2
        lda RX+39
        cmp #<ICMP_ID
        bne out2
        lda RX+41
        cmp pingSeq
        bne out2
        ldx #3
rs:     lda RX+26,x
        cmp ipDst,x
        bne out2
        dex
        bpl rs
        lda RX+22                // TTL bewaren voor de weergave
        sta pingTtl
        lda #1
        sta netFlag
        rts
echoReq:                         // iemand pingt ons: antwoord met dezelfde data
        lda RX+16                // lengte = IP-totlen + 14
        sta netTxLen+1
        lda RX+17
        clc
        adc #14
        sta netTxLen
        bcc nc
        inc netTxLen+1
nc:     lda netTxLen+1           // niet groter dan de buffer
        cmp #>NET_RXBUF_SIZE
        bcs out2
        jsr rx2tx                // kopie van het frame
        ldx #5
sw:     lda RX+6,x               // MAC's omdraaien
        sta TX,x
        lda netMac,x
        sta TX+6,x
        dex
        bpl sw
        ldx #3
si:     lda RX+26,x              // IP's omdraaien
        sta TX+30,x
        lda NC_IP,x
        sta TX+26,x
        dex
        bpl si
        lda #64
        sta TX+22                // TTL
        lda #0
        sta TX+34                // type 0 = echo reply
        jsr ip_Csum
        lda netTxLen             // ICMP-lengte = totlen - 20
        sec
        sbc #34
        sta ckLen
        lda netTxLen+1
        sbc #0
        sta ckLen+1
        jsr icmp_Csum
        jmp cs_Send
}

// rx2tx - kopieer netTxLen bytes van RX naar TX.
rx2tx: {
        lda #<RX
        sta netPtr
        lda #>RX
        sta netPtr+1
        lda #<TX
        sta ck2
        lda #>TX
        sta ck2+1
        lda netTxLen
        sta ckLen
        lda netTxLen+1
        sta ckLen+1
        ldy #0
lp:     lda ckLen
        ora ckLen+1
        beq done
        lda (netPtr),y
        sta (ck2),y
        iny
        bne dc
        inc netPtr+1
        inc ck2+1
dc:     lda ckLen
        bne d2
        dec ckLen+1
d2:     dec ckLen
        jmp lp
done:   rts
}

// -----------------------------------------------------
// ping_Send - ICMP echo request (seq = pingSeq) naar ipDst via arpMac.
// -----------------------------------------------------
ping_Send: {
        ldy #0
        lda #>ETH_IP
        ldx #<ETH_IP
        jsr eth_Hdr
        ldx #9
ih:     lda ipHdr,x              // 45 00 | totlen | id | 00 00 | ttl proto
        sta TX+14,x
        dex
        bpl ih
        lda pingSeq
        sta TX+19                // IP-id = seq
        ldx #3
ad:     lda NC_IP,x
        sta TX+26,x
        lda ipDst,x
        sta TX+30,x
        dex
        bpl ad
        lda #8                   // echo request
        sta TX+34
        lda #0
        sta TX+35
        sta TX+40
        lda #>ICMP_ID
        sta TX+38
        lda #<ICMP_ID
        sta TX+39
        lda pingSeq
        sta TX+41
        ldx #PING_DATA-1         // data: "ABCD..."
dt:     txa
        and #$1f
        clc
        adc #$41
        sta TX+42,x
        dex
        bpl dt
        jsr ip_Csum
        lda #8+PING_DATA
        sta ckLen
        lda #0
        sta ckLen+1
        jsr icmp_Csum
        lda #14+20+8+PING_DATA
        sta netTxLen
        lda #0
        sta netTxLen+1
        jmp cs_Send
}
ipHdr:  .byte $45, $00, 0, 20+8+PING_DATA, $00, $00, $00, $00, 64, 1

// ip_Csum - IP-kopchecksum van TX opnieuw uitrekenen.
ip_Csum:
        lda #0
        sta TX+24
        sta TX+25
        lda #<[TX+14]
        sta netPtr
        lda #>[TX+14]
        sta netPtr+1
        lda #20
        sta ckLen
        lda #0
        sta ckLen+1
        jsr ck_Sum
        lda ckRes
        sta TX+24
        lda ckRes+1
        sta TX+25
        rts

// icmp_Csum - ICMP-checksum over ckLen bytes vanaf TX+34.
icmp_Csum:
        lda #0
        sta TX+36
        sta TX+37
        lda #<[TX+34]
        sta netPtr
        lda #>[TX+34]
        sta netPtr+1
        jsr ck_Sum
        lda ckRes
        sta TX+36
        lda ckRes+1
        sta TX+37
        rts

// -----------------------------------------------------
// ck_Sum - internet-checksum (one's complement) over ckLen bytes vanaf
//          netPtr. Uit: ckRes (hi), ckRes+1 (lo), al geïnverteerd.
// -----------------------------------------------------
ck_Sum: {
        lda #0
        sta ckHi
        sta ckLo
        ldy #0
lp:     lda ckLen
        ora ckLen+1
        beq fin
        lda (netPtr),y           // hoog byte van het woord
        sta ckB
        jsr adv
        lda #0                   // oneven lengte: laag byte = 0
        sta ckC
        lda ckLen
        ora ckLen+1
        beq add
        lda (netPtr),y
        sta ckC
        jsr adv
add:    clc
        lda ckLo
        adc ckC
        sta ckLo
        lda ckHi
        adc ckB
        sta ckHi
        bcc lp
        inc ckLo                 // end-around carry
        bne lp
        inc ckHi
        bne lp
        inc ckLo
        jmp lp
fin:    lda ckHi
        eor #$ff
        sta ckRes
        lda ckLo
        eor #$ff
        sta ckRes+1
        rts
adv:    inc netPtr
        bne a2
        inc netPtr+1
a2:     lda ckLen
        bne a3
        dec ckLen+1
a3:     dec ckLen
        rts
}

//--------------------------------------------------------
ipDst:      .fill 4, 0           // doel van de ping
arpIp:      .fill 4, 0           // IP waarvan we de MAC zoeken
arpMac:     .fill 6, 0
arpCacheIp: .fill 4, 0
arpValid:   .byte 0
arpTry:     .byte 0
netFlag:    .byte 0              // gezet door net_Handle: antwoord binnen
netAbort:   .byte 0              // ESC tijdens net_Wait
nwEnd:      .byte 0
pingSeq:    .byte 0
pingTtl:    .byte 0
ckLen:      .word 0
ckRes:      .word 0
ckHi:       .byte 0
ckLo:       .byte 0
ckB:        .byte 0
ckC:        .byte 0
