#importonce
//========================================================
// net/dns.asm - UDP + DNS-client (A-record opvragen)
// Commodore Desk 64
//
// dns_Resolve vraagt de DNS-server uit NETWORK (NC_DNS) naar het IPv4-
// adres van NC_HOST. Eén vraag tegelijk, 3 pogingen van 2 s. Het
// antwoord wordt in dns_Input (vanuit net_Handle) gelezen: de vraag
// wordt overgeslagen en het eerste A-record (type 1, lengte 4) telt.
//
// UDP-kop in het frame (vanaf 34): 34 src-poort, 36 dst-poort,
// 38 lengte, 40 checksum (0 = geen). DNS-bericht vanaf 42.
//========================================================

.const DNS_HDR = 42              // begin van het DNS-bericht in het frame

// -----------------------------------------------------
// dns_Resolve - NC_HOST -> dnsIp. Uit: carry=1 gevonden,
//               carry=0 -> X/Y = foutmelding.
// -----------------------------------------------------
dns_Resolve: {
        ldx #3                   // eerst de DNS-server bereikbaar maken
cs:     lda NC_DNS,x
        sta ipDst,x
        dex
        bpl cs
        jsr ip_NextHop
        jsr arp_Resolve
        bcs arp
        ldx #<sPgNoArp
        ldy #>sPgNoArp
        clc
        rts
arp:    lda frameLo              // lokale poort en vraag-id
        sta dnsLPort+1
        sta dnsId+1
        lda frameHi
        sta dnsId
        lda #$d0
        sta dnsLPort
        lda #3
        sta dnsTry
again:  jsr lg_DnsAsk
        jsr dns_Query
        lda #0
        sta netFlag
        sta dnsDone
        lda #100                 // 2 s
        jsr net_Wait
        lda dnsDone
        cmp #1
        beq ok
        cmp #2
        beq nf
        lda netAbort
        bne stop
        dec dnsTry
        bne again
        ldx #<sDnsNoAns
        ldy #>sDnsNoAns
        clc
        rts
stop:   ldx #<sPgStop
        ldy #>sPgStop
        clc
        rts
nf:     jsr lg_DnsNf
        ldx #<sDnsNf
        ldy #>sDnsNf
        clc
        rts
ok:     jsr lg_DnsGot
        sec
        rts
}

// -----------------------------------------------------
// name_Resolve - feBuf/feLen (schermcodes) is een hostnaam? Dan via DNS
//                opzoeken. Uit: carry=1 -> dnsIp, carry=0 -> X/Y melding.
// -----------------------------------------------------
name_Resolve: {
        ldx feLen
        beq bad
        lda #$ff
        sta dnsName,x
chk:    dex
        lda feBuf,x
        sta dnsName,x
        beq bad                  // (@ hoort niet in een naam)
        cmp #27                  // letters
        bcc ok
        cmp #$2d                 // - .
        beq ok
        cmp #$2e
        beq ok
        cmp #$30                 // cijfers
        bcc bad
        cmp #$3a
        bcc ok
        cmp #$41                 // hoofdletters (SHIFT)
        bcc bad
        cmp #$5b
        bcs bad
ok:     cpx #0
        bne chk
        jmp dns_Resolve
bad:    ldx #<sChHost
        ldy #>sChHost
        clc
        rts
}

// -----------------------------------------------------
// dns_Query - UDP-vraag (A-record voor NC_HOST) naar ipDst:53.
// -----------------------------------------------------
dns_Query: {
        ldy #0                   // Ethernet (naar arpMac)
        lda #>ETH_IP
        ldx #<ETH_IP
        jsr eth_Hdr
        // DNS-kop: id, flags $0100 (recursie gewenst), 1 vraag
        lda dnsId
        sta TX+DNS_HDR
        lda dnsId+1
        sta TX+DNS_HDR+1
        ldx #9
hz:     lda dnsHdr,x
        sta TX+DNS_HDR+2,x
        dex
        bpl hz
        // naam: "ollama.com" -> 6 ollama 3 com 0 (letters klein)
        ldx #0                   // X = bron (NC_HOST)
        ldy #0                   // Y = doel vanaf TX+DNS_HDR+12
        sty dnsLenPos
        iny
        lda #0
        sta dnsCnt
nm:     lda dnsName,x
        cmp #$ff
        beq nEnd
        cmp #$2e                 // punt: labellengte invullen
        bne ch
        lda dnsCnt
        sty dnsTmp
        ldy dnsLenPos
        sta TX+DNS_HDR+12,y
        ldy dnsTmp
        sty dnsLenPos
        iny
        lda #0
        sta dnsCnt
        inx
        jmp nm
ch:     jsr sc2ascii
        sta TX+DNS_HDR+12,y
        iny
        inc dnsCnt
        inx
        cpx #32
        bne nm
nEnd:   lda dnsCnt
        sty dnsTmp
        ldy dnsLenPos
        sta TX+DNS_HDR+12,y
        ldy dnsTmp
        lda #0                   // naam-einde, type A (1), klasse IN (1)
        sta TX+DNS_HDR+12,y
        sta TX+DNS_HDR+13,y
        sta TX+DNS_HDR+15,y
        lda #1
        sta TX+DNS_HDR+14,y
        sta TX+DNS_HDR+16,y
        tya                      // DNS-lengte = 12 + naam(y+1) + 4
        clc
        adc #12+1+4
        sta dnsLen
        // UDP-kop
        lda dnsLPort
        sta TX+34
        lda dnsLPort+1
        sta TX+35
        lda #0
        sta TX+36
        lda #53
        sta TX+37
        lda #0
        sta TX+38
        sta TX+40                // geen checksum
        sta TX+41
        lda dnsLen
        clc
        adc #8
        sta TX+39
        // IP-kop
        lda #$45
        sta TX+14
        lda #0
        sta TX+15
        sta TX+16
        sta TX+18
        sta TX+20
        sta TX+21
        lda frameLo
        sta TX+19
        lda TX+39                // totlen = 20 + UDP
        clc
        adc #20
        sta TX+17
        lda #64
        sta TX+22
        lda #17
        sta TX+23
        ldx #3
ih:     lda NC_IP,x
        sta TX+26,x
        lda ipDst,x
        sta TX+30,x
        dex
        bpl ih
        jsr ip_Csum
        lda TX+17
        clc
        adc #14
        sta netTxLen
        lda #0
        sta netTxLen+1
        jmp cs_Send
}
dnsHdr: .byte $01, $00, $00, $01, $00, $00, $00, $00, $00, $00

// -----------------------------------------------------
// dns_Input - UDP-pakket in RX: is het ons DNS-antwoord?
// -----------------------------------------------------
dns_Input: {
        lda RX+34                // van poort 53 naar onze poort
        bne out
        lda RX+35
        cmp #53
        bne out
        lda RX+36
        cmp dnsLPort
        bne out
        lda RX+37
        cmp dnsLPort+1
        bne out
        lda RX+DNS_HDR           // zelfde id?
        cmp dnsId
        bne out
        lda RX+DNS_HDR+1
        cmp dnsId+1
        bne out
        lda #1
        sta netFlag
        lda RX+DNS_HDR+3         // rcode (laagste 4 bits): 0 = goed
        and #$0f
        bne nf
        lda RX+DNS_HDR+7         // aantal antwoorden
        sta dnsCnt
        beq nf
        lda #<[RX+DNS_HDR+12]    // vraag overslaan
        sta ck2
        lda #>[RX+DNS_HDR+12]
        sta ck2+1
        jsr skipName
        lda #4                   // type + klasse
        jsr ptrAdd
rr:     jsr skipName             // antwoordrecord
        ldy #0
        lda (ck2),y              // type hoog
        bne skip
        iny
        lda (ck2),y              // type laag = 1 (A)?
        cmp #1
        bne skip
        ldy #8                   // rdlength = 4?
        lda (ck2),y
        bne skip
        iny
        lda (ck2),y
        cmp #4
        bne skip
        ldy #10                  // gevonden
        ldx #0
cp:     lda (ck2),y
        sta dnsIp,x
        iny
        inx
        cpx #4
        bne cp
        lda #1
        sta dnsDone
out:    rts
skip:   ldy #9                   // 10 + rdlength verder
        lda (ck2),y
        clc
        adc #10
        jsr ptrAdd
        ldy #8
        lda (ck2),y              // (rdlength hoog: pagina's)
        beq nx
        jsr ptrAddHi
nx:     dec dnsCnt
        bne rr
nf:     lda #2                   // geen A-record: naam onbekend
        sta dnsDone
        rts
}

// skipName - ck2 voorbij een DNS-naam (labels of 2-byte pointer).
skipName: {
lp:     ldy #0
        lda (ck2),y
        beq end1
        cmp #$c0
        bcs ptr
        clc
        adc #1                   // lengte + het lengtebyte
        jsr ptrAdd
        jmp lp
end1:   lda #1
        jmp ptrAdd
ptr:    lda #2
        jmp ptrAdd
}
ptrAdd:
        clc
        adc ck2
        sta ck2
        bcc !+
        inc ck2+1
!:      rts
ptrAddHi:                        // A = aantal pagina's erbij (na ptrAdd)
        clc
        adc ck2+1
        sta ck2+1
        rts

dnsName:   .fill 33, $ff         // de op te zoeken naam (schermcodes)
dnsId:     .word 0
dnsLPort:  .word 0               // big-endian
dnsIp:     .fill 4, 0
dnsTry:    .byte 0
dnsDone:   .byte 0               // 1 = gevonden, 2 = onbekend
dnsCnt:    .byte 0
dnsLen:    .byte 0
dnsLenPos: .byte 0
dnsTmp:    .byte 0

.encoding "screencode_upper"
sDnsNoAns: .text "NO ANSWER FROM THE DNS SERVER"
           .byte $ff
sDnsNf:    .text "HOST NAME NOT FOUND"
           .byte $ff
