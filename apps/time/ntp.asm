#importonce
//========================================================
// apps/time/ntp.asm - NTP-client (SNTP, RFC 4330)
// Commodore Desk 64
//
// Eén vraag van 48 bytes naar poort 123 (eerste byte $1B: versie 3,
// client); het antwoord bevat de "transmit timestamp" op offset 40:
// seconden sinds 1-1-1900 (UTC, big-endian).
//   RR-Net:   UDP via de eigen stack (ntp_Input via udpVec in ip.asm).
//   Ultimate: UDP-socket van de firmware (opdracht $08, zie ultimate.asm).
//   WiC64:    geen UDP: TIME-protocol (RFC 868, TCP-poort 37) bij
//             time.nist.gov (ntp_Wic).
//========================================================

.const NTP_LEN = 48
.const NTP_MSG = 42              // begin van het NTP-bericht in het frame

// -----------------------------------------------------
// ntp_Get - tijd vragen aan de server in feBuf/feLen (naam of IP).
//           Uit: carry=1 -> ntpSec, carry=0 -> X/Y = melding.
// -----------------------------------------------------
ntp_Get: {
        jsr net_Fw               // Ultimate of WiC64
        bne n1
        jmp ntp_Ult
n1:     cmp #NET_PLAT_RRNET
        beq hw
        ldx #<sNtpNoNet
        ldy #>sNtpNoNet
        clc
        rts
hw:     lda csReady
        bne hwOk
        jsr cs_Init
        bcs ci
        ldx #<sPgChip
        ldy #>sPgChip
        clc
        rts
ci:     lda #1
        sta csReady
hwOk:   jsr ip_Parse             // IP-adres of naam?
        bcc name
        ldx #3
cp:     lda ipTmp,x
        sta ipDst,x
        dex
        bpl cp
        jmp arp
name:   jsr name_Resolve         // -> dnsIp, anders X/Y
        bcs dn
        rts
dn:     ldx #3
cd:     lda dnsIp,x
        sta ipDst,x
        dex
        bpl cd
arp:    jsr ip_NextHop
        jsr arp_Resolve
        bcs a1
        ldx #<sPgNoArp
        ldy #>sPgNoArp
        clc
        rts
a1:     lda #<ntp_Input          // UDP-antwoorden naar ntp_Input
        sta udpVec
        lda #>ntp_Input
        sta udpVec+1
        lda frameLo              // lokale poort
        sta ntpLPort+1
        lda #$d1
        sta ntpLPort
        lda #3
        sta ntpTry
again:  jsr ntp_Query
        lda #0
        sta netFlag
        sta ntpDone
        lda #100                 // 2 s
        jsr net_Wait
        lda ntpDone
        bne ok
        lda netAbort
        bne stop
        dec ntpTry
        bne again
        ldx #<sNtpNoAns
        ldy #>sNtpNoAns
        clc
        rts
stop:   ldx #<sPgStop
        ldy #>sPgStop
        clc
        rts
ok:     sec
        rts
}

// ntp_Query - UDP-vraag naar ipDst:123.
ntp_Query: {
        ldy #0                   // Ethernet (naar arpMac)
        lda #>ETH_IP
        ldx #<ETH_IP
        jsr eth_Hdr
        ldx #NTP_LEN-1
        lda #0
cl:     sta TX+NTP_MSG,x
        dex
        bpl cl
        lda #$1b                 // LI 0, versie 3, modus 3 (client)
        sta TX+NTP_MSG
        lda ntpLPort             // UDP-kop
        sta TX+34
        lda ntpLPort+1
        sta TX+35
        lda #0
        sta TX+36
        sta TX+38
        sta TX+40                // geen checksum
        sta TX+41
        lda #123
        sta TX+37
        lda #8+NTP_LEN
        sta TX+39
        lda #$45                 // IP-kop
        sta TX+14
        lda #0
        sta TX+15
        sta TX+16
        sta TX+18
        sta TX+20
        sta TX+21
        lda frameLo
        sta TX+19
        lda #20+8+NTP_LEN
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
        lda #14+20+8+NTP_LEN
        sta netTxLen
        lda #0
        sta netTxLen+1
        jmp cs_Send
}

// -----------------------------------------------------
// ntp_Input - UDP-pakket in RX: ons NTP-antwoord? Carry=1 = verwerkt.
// -----------------------------------------------------
ntp_Input: {
        lda RX+34                // van poort 123 naar onze poort
        bne no
        lda RX+35
        cmp #123
        bne no
        lda RX+36
        cmp ntpLPort
        bne no
        lda RX+37
        cmp ntpLPort+1
        bne no
        lda RX+NTP_MSG           // modus 4 = server
        and #7
        cmp #4
        bne no
        lda RX+NTP_MSG+1         // stratum 0 = "kiss of death": geen tijd
        beq no
        ldx #3
cp:     lda RX+NTP_MSG+40,x
        sta ntpSec,x
        dex
        bpl cp
        lda #1
        sta ntpDone
        sta netFlag
        sec
        rts
no:     clc
        rts
}

// -----------------------------------------------------
// ntp_Ult - dezelfde vraag via de Ultimate (UDP-socket, niet te testen
//           in VICE).
// -----------------------------------------------------
ntp_Ult: {
        lda netPlatform
        cmp #NET_PLAT_WIC64
        bne u
        jmp ntp_Wic
u:      lda #0                   // poort 123 (big-endian)
        sta tcpRPort
        lda #123
        sta tcpRPort+1
        lda #$08                 // UDP
        sta utProto
        jsr ut_ConnectFe
        lda #$07
        sta utProto
        bcs op
        ldx #<sNtpNoAns
        ldy #>sNtpNoAns
        clc
        rts
op:     ldx #NTP_LEN-1
        lda #0
cl:     sta ntpBuf,x
        dex
        bpl cl
        lda #$1b
        sta ntpBuf
        lda #<ntpBuf
        sta tcpDataPtr
        lda #>ntpBuf
        sta tcpDataPtr+1
        lda #NTP_LEN
        sta tcpDataLen
        lda #0
        sta tcpDataLen+1
        sta ntpCnt
        jsr ut_Write
        bcc fail
        lda #<ntp_UtByte
        sta tcpRxVec
        lda #>ntp_UtByte
        sta tcpRxVec+1
        lda frameLo
        sta ntpT0
rl:     jsr ut_Read
        lda ntpCnt
        cmp #NTP_LEN
        bcs got
        lda frameLo              // 3 s
        sec
        sbc ntpT0
        cmp #150
        bcc rl
fail:   jsr ut_Close
        ldx #<sNtpNoAns
        ldy #>sNtpNoAns
        clc
        rts
got:    jsr ut_Close
        lda ntpBuf+1             // stratum 0: geen tijd
        beq fail
        ldx #3
cs:     lda ntpBuf+40,x
        sta ntpSec,x
        dex
        bpl cs
        sec
        rts
}
// -----------------------------------------------------
// ntp_Wic - de WiC64 heeft geen UDP (en zijn eigen klok rekent met een
//   vaste zomertijd). Daarom het TIME-protocol (RFC 868) via TCP: de
//   server stuurt 4 bytes, seconden sinds 1900 (UTC, big-endian) - net
//   als NTP - en sluit de verbinding.
// -----------------------------------------------------
ntp_Wic: {
        ldx #0
cs:     lda sNtpTcp,x
        sta feBuf,x
        inx
        cpx #sNtpTcpE-sNtpTcp
        bne cs
        stx feLen
        lda #0                   // poort 37 (big-endian)
        sta tcpRPort
        lda #37
        sta tcpRPort+1
        jsr wc_ConnectFe
        bcc fail
        lda #<ntp_UtByte
        sta tcpRxVec
        lda #>ntp_UtByte
        sta tcpRxVec+1
        lda #0
        sta ntpCnt
        lda frameLo
        sta ntpT0
rl:     jsr wc_Read
        ldx ntpCnt
        cpx #4
        bcs got
        cmp #1                   // gesloten zonder 4 bytes
        beq cl
        lda frameLo              // 3 s
        sec
        sbc ntpT0
        cmp #150
        bcc rl
cl:     jsr wc_Close
fail:   ldx #<sNtpNoAns
        ldy #>sNtpNoAns
        clc
        rts
got:    lda frameLo              // de server sluit zelf: daarop wachten
        sta ntpT0                // (max. 1 s), dan pas zelf sluiten
gw:     lda utOpen
        beq gc
        jsr wc_Read
        lda frameLo
        sec
        sbc ntpT0
        cmp #50
        bcc gw
gc:     jsr wc_Close
        ldx #3
cp:     lda ntpBuf,x
        sta ntpSec,x
        dex
        bpl cp
        sec
        rts
}
.encoding "screencode_upper"
sNtpTcp:  .text "TIME.NIST.GOV"
sNtpTcpE:

ntp_UtByte:
        ldx ntpCnt
        cpx #NTP_LEN
        bcs !+
        sta ntpBuf,x
        inc ntpCnt
!:      rts

ntpSec:    .fill 4, 0            // seconden sinds 1900 (big-endian)
ntpLPort:  .word 0               // big-endian
ntpTry:    .byte 0
ntpDone:   .byte 0
ntpCnt:    .byte 0
ntpT0:     .byte 0
ntpBuf:    .fill NTP_LEN, 0

.encoding "screencode_upper"
sNtpNoNet: .text "NO NETWORK (SEE SYSTEM - NETWORK)"
           .byte $ff
sNtpNoAns: .text "NO ANSWER FROM THE TIME SERVER"
           .byte $ff
