#importonce
//========================================================
// net/wic64net.asm - TCP via de WiC64 (firmware doet DNS en TCP)
// Commodore Desk 64
//
// Dezelfde afspraken als de Ultimate-routines (ultimate.asm): ut_* springt
// hierheen als netPlatform = NET_PLAT_WIC64. De WiC64 heeft één TCP-
// verbinding tegelijk en geen UDP (de tijd komt uit zijn eigen klok, zie
// apps/time/ntp.asm). De overdracht zelf staat in de Core (hal/wic64.asm).
//   $21 open "host:poort"   $22 lezen   $23 schrijven   $2e sluiten
//   $06 IP-adres (tekst)
//========================================================

// wc_ConnectFe - TCP naar feBuf/feLen (schermcodes) : tcpRPort.
//                Uit: carry=1 open.
wc_ConnectFe: {
        ldx #0                   // "host:poort" (ASCII) in ucCmd
hl:     cpx feLen
        beq he
        lda feBuf,x
        jsr sc2ascii
        sta ucCmd,x
        inx
        bne hl
he:     lda #$3a
        sta ucCmd,x
        inx
        lda tcpRPort+1           // poort decimaal (tcpRPort is big-endian)
        sta wnV
        lda tcpRPort
        sta wnV+1
        ldy #0
        sty wnAny
dg:     lda #0
        sta wnD
sb:     lda wnV
        sec
        sbc wnTLo,y
        pha
        lda wnV+1
        sbc wnTHi,y
        bcc nd
        sta wnV+1
        pla
        sta wnV
        inc wnD
        bne sb
nd:     pla
        lda wnD
        ora wnAny
        bne pr
        cpy #4
        bne nx
pr:     lda wnD
        ora #$30
        sta ucCmd,x
        inx
        inc wnAny
nx:     iny
        cpy #5
        bne dg
        lda #<ucCmd
        ldy #>ucCmd
        jsr wn_Out
        lda #0
        sta utOpen
        jsr wc_NoRx
        lda #$21
        jsr wc_Req
        bcs f
        bne f
        lda #1
        sta utOpen
        sec
        rts
f:      clc
        rts
wnTLo:  .byte <10000, <1000, <100, <10, <1
wnTHi:  .byte >10000, >1000, >100, >10, >1
}

// wn_Out - payload A/Y (adres) met lengte X.
wn_Out:
        sta wcPtr
        sty wcPtr+1
        stx wcLen
        lda #0
        sta wcLen+1
        rts

// wc_Write - tcpDataLen bytes vanaf tcpDataPtr. Carry=1 gelukt.
wc_Write: {
        lda tcpDataPtr
        sta wcPtr
        lda tcpDataPtr+1
        sta wcPtr+1
        lda tcpDataLen
        sta wcLen
        lda tcpDataLen+1
        sta wcLen+1
        jsr wc_NoRx
        lda #$23
        jsr wc_Req
        bcs f
        bne f
        sec
        rts
f:      clc
        rts
}

// wc_Read - wat er binnen is naar tcpRxVec. A = 0 data, 1 gesloten,
//           2 nog niets, $ff fout (zoals ut_Read).
wc_Read: {
        lda tcpRxVec
        sta wcVec
        lda tcpRxVec+1
        sta wcVec+1
        lda #0
        sta wcLen
        sta wcLen+1
        lda #$22
        jsr wc_Req
        bcs err
        cmp #4                   // NETWORK_ERROR: verbinding gesloten
        beq cl
        cmp #0
        bne err
        lda wcSize
        ora wcSize+1
        beq none
        lda #0
        rts
none:   lda #2
        rts
cl:     lda #0
        sta utOpen
        lda #1
        rts
err:    lda #$ff
        rts
}

// wc_Close - verbinding sluiten.
wc_Close:
        lda utOpen
        beq !+
        lda #0
        sta utOpen
        sta wcLen
        sta wcLen+1
        jsr wc_NoRx
        lda #$2e
        jmp wc_Req
!:      rts

// wc_Text - opdracht A zonder payload; het antwoord (tekst) komt in
//           feBuf, wnAny = aantal bytes. Uit: zoals wc_Req.
wc_Text:
        pha
        lda #0
        sta wcLen
        sta wcLen+1
        sta wnAny
        lda #<wn_Byte
        sta wcVec
        lda #>wn_Byte
        sta wcVec+1
        pla
        jmp wc_Req

// wc_GetIp - IP-adres ("192.168.1.20") -> utIp. Carry=1 gelukt.
wc_GetIp: {
        lda #$06
        jsr wc_Text
        bcs f
        bne f
        ldx wnAny                // (zonder de afsluitende 0)
        beq f
        dex
        stx feLen
        jsr ip_Parse
        bcc f
        ldx #3
cp:     lda ipTmp,x
        sta utIp,x
        dex
        bpl cp
        sec
        rts
f:      clc
        rts
}

// wn_Byte - antwoord als tekst in feBuf (max. 47 tekens).
wn_Byte:
        ldx wnAny
        cpx #47
        bcs !+
        sta feBuf,x
        inc wnAny
!:      rts

wnV:    .word 0
wnD:    .byte 0
wnAny:  .byte 0
