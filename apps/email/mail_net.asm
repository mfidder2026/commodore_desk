#importonce
//========================================================
// apps/email/mail_net.asm - TCP-verbinding + regels voor POP3/SMTP
// Commodore Desk 64
//
// mn_Open verbindt (RR-Net: DNS/ARP/TCP; Ultimate: via de firmware).
// Ontvangen bytes worden tot regels samengevoegd (CR weg, LF = einde);
// elke regel gaat naar (mnLineVec) met mnLine/mnLen. Te lange regels
// komen in stukken: mnPart = 1 -> dit stuk heeft nog geen regeleinde,
// mnCont = 1 -> dit stuk is het vervolg van het vorige.
// De regelverwerker zet mnDone als het antwoord compleet is; mn_Wait
// wacht daarop (RUN/STOP = stoppen, 30 s = time-out).
//========================================================

// mn_Open - host (schermcodes, $ff) op r3, poorttekst op r6.
//           Uit: carry=1 verbonden, carry=0 -> X/Y melding.
mn_Open: {
        ldy #0                   // host -> feBuf/feLen
hc:     lda (r3),y
        cmp #$ff
        beq he
        sta feBuf,y
        iny
        cpy #32
        bne hc
he:     sty feLen
        cpy #0
        bne hp
        ldx #<sMnNoHost
        ldy #>sMnNoHost
        clc
        rts
hp:     lda #0                   // poort: decimaal -> tcpRPort (big-endian)
        sta mnPort
        sta mnPort+1
        tay
pl:     lda (r6),y
        cmp #$30
        bcc pd
        cmp #$3a
        bcs pd
        and #$0f
        pha
        lda mnPort               // *10
        ldx mnPort+1
        asl mnPort
        rol mnPort+1
        asl mnPort
        rol mnPort+1
        clc
        adc mnPort
        sta mnPort
        txa
        adc mnPort+1
        sta mnPort+1
        asl mnPort
        rol mnPort+1
        pla
        clc
        adc mnPort
        sta mnPort
        bcc nc
        inc mnPort+1
nc:     iny
        cpy #5
        bne pl
pd:     lda mnPort
        ora mnPort+1
        bne pok
        ldx #<sChPort
        ldy #>sChPort
        clc
        rts
pok:    lda mnPort+1
        sta tcpRPort
        lda mnPort
        sta tcpRPort+1
        lda #0
        sta netAbort
        sta mnClosed
        sta mnLen
        sta mnCont
        sta mnDone
        lda #<mn_Rx
        sta tcpRxVec
        lda #>mn_Rx
        sta tcpRxVec+1
        lda netPlatform
        cmp #NET_PLAT_ULTIMATE
        bne rr
        jsr ut_ConnectFe         // Ultimate: DNS + TCP in de firmware
        bcs ok
        jmp nocon
rr:     cmp #NET_PLAT_RRNET
        beq hw
        ldx #<sMnNoHw
        ldy #>sMnNoHw
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
hwOk:   jsr ip_Parse
        bcc name
        ldx #3
cp:     lda ipTmp,x
        sta ipDst,x
        dex
        bpl cp
        jmp arp
name:   jsr name_Resolve         // X/Y = melding bij een fout
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
a1:     jsr tcp_Connect
        bcs ok
        ldx #<sPgStop
        ldy #>sPgStop
        lda netAbort
        bne f
        ldx #<sMnRefused
        ldy #>sMnRefused
        lda tcpRst
        bne f
nocon:  ldx #<sMnNoConn
        ldy #>sMnNoConn
f:      clc
        rts
ok:     sec
        rts
}

// mn_Close - verbinding sluiten.
mn_Close:
        lda netPlatform
        cmp #NET_PLAT_ULTIMATE
        bne !+
        jmp ut_Close
!:      jmp tcp_Close

// mn_Send - tcpDataLen bytes vanaf tcpDataPtr versturen. Carry=1 gelukt.
mn_Send:
        lda netPlatform
        cmp #NET_PLAT_ULTIMATE
        bne !+
        jmp ut_Write
!:      jmp tcp_Send

// mn_Cmd - opdracht mnCmd (mnCmdLen, CRLF erbij) sturen en op het
//          antwoord wachten. Carry=1 antwoord binnen, anders X/Y melding.
mn_Cmd: {
        lda #$0d
        jsr mc_Chr
        lda #$0a
        jsr mc_Chr
        lda #0
        sta mnDone               // (het antwoord kan al tijdens tcp_Send komen)
        lda #<mnCmd
        sta tcpDataPtr
        lda #>mnCmd
        sta tcpDataPtr+1
        lda mnCmdLen
        sta tcpDataLen
        lda #0
        sta tcpDataLen+1
        jsr mn_Send
        bcs mn_Wait
        ldx #<sMnLost
        ldy #>sMnLost
        rts
}

// mn_Wait - wachten tot mnDone. Carry=1 klaar, anders X/Y melding.
mn_Wait: {
        lda #0
        sta mnTicks
        sta mnTicks+1
        lda frameLo
        sta mnLastF
lp:     lda mnDone
        bne ok
        lda mnClosed
        bne cl
        jsr evt_Poll
        cmp #EVT_KEY
        bne np
        lda evtA
        cmp #KEY_STOP
        bne np
        ldx #<sPgStop
        ldy #>sPgStop
        clc
        rts
np:     jsr mn_Poll
        lda frameLo
        cmp mnLastF
        beq lp
        sta mnLastF
        inc mnTicks
        bne t
        inc mnTicks+1
t:      lda mnTicks+1
        cmp #>MN_TIMEOUT
        bcc lp
        lda mnTicks
        cmp #<MN_TIMEOUT
        bcc lp
        ldx #<sMnTime
        ldy #>sMnTime
        clc
        rts
cl:     ldx #<sMnClosed
        ldy #>sMnClosed
        clc
        rts
ok:     sec
        rts
}

// mn_Poll - ontvangen (RR-Net: frames; Ultimate: één keer per beeld).
mn_Poll: {
        lda netPlatform
        cmp #NET_PLAT_ULTIMATE
        beq ut
        jsr net_Poll
        lda tcpRst
        ora tcpFin
        beq r
        sta mnClosed
r:      rts
ut:     lda frameLo
        cmp mnUtF
        beq r
        sta mnUtF
        jsr ut_Read
        cmp #1
        beq c
        cmp #$ff
        bne r
c:      lda #1
        sta mnClosed
        rts
}

// mn_Rx - ontvangen byte (callback): regels samenstellen.
mn_Rx: {
        cmp #$0d
        beq out
        cmp #$0a
        beq eol
        ldx mnLen
        cpx #LB_MAX
        bcs full
        sta mnLine,x
        inc mnLen
out:    rts
full:   pha                      // vol: dit stuk afleveren, verder
        lda #1
        sta mnPart
        jsr dl
        lda #1
        sta mnCont
        pla
        sta mnLine
        lda #1
        sta mnLen
        rts
eol:    lda #0
        sta mnPart
        jsr dl
        lda #0
        sta mnCont
        sta mnLen
        rts
dl:     lda #0
        sta mnOff
        jmp (mnLineVec)
}

// Opdracht opbouwen in mnCmd.
mc_Start:
        lda #0
        sta mnCmdLen
        rts
// mc_Chr - byte A erachter.
mc_Chr:
        stx mnXs
        ldx mnCmdLen
        cpx #CMD_MAX
        bcs !+
        sta mnCmd,x
        inc mnCmdLen
!:      ldx mnXs
        rts
// mc_Str - ASCII-tekst X/Y (0-afgesloten) erachter.
mc_Str: {
        stx r6
        sty r6+1
        ldy #0
lp:     lda (r6),y
        beq done
        jsr mc_Chr
        iny
        bne lp
done:   rts
}
// mc_Sc - schermcodetekst X/Y ($ff) als ASCII erachter.
mc_Sc: {
        stx r6
        sty r6+1
        ldy #0
lp:     lda (r6),y
        cmp #$ff
        beq done
        jsr sc2ascii
        jsr mc_Chr
        iny
        bne lp
done:   rts
}
// mc_Dec - 16-bit getal mnNum decimaal erachter (zonder voorloopnullen).
mc_Dec: {
        ldx #0
        stx mnAny
dg:     lda #0
        sta mnDig
sb:     lda mnNum
        sec
        sbc d16Lo,x
        tay
        lda mnNum+1
        sbc d16Hi,x
        bcc pd
        sta mnNum+1
        sty mnNum
        inc mnDig
        jmp sb
pd:     lda mnDig
        ora mnAny
        bne pr
        cpx #4
        bne nx
pr:     lda mnDig
        ora #$30
        jsr mc_Chr
        inc mnAny
nx:     inx
        cpx #5
        bne dg
        rts
d16Lo:  .byte <10000, <1000, <100, <10, <1
d16Hi:  .byte >10000, >1000, >100, >10, >1
}

//--------------------------------------------------------
.align 2                         // jmp (vector) niet op $xxFF
mnLineVec: .word 0
mnPort:   .word 0
mnTicks:  .word 0
mnNum:    .word 0
mnLastF:  .byte 0
mnUtF:    .byte 0
mnClosed: .byte 0
mnDone:   .byte 0
mnOk:     .byte 0
mnCode:   .byte 0
mnLen:    .byte 0
mnOff:    .byte 0
mnPart:   .byte 0
mnCont:   .byte 0
mnXs:     .byte 0
mnAny:    .byte 0
mnDig:    .byte 0
mnCmdLen: .byte 0

.encoding "screencode_upper"
sMnNoHost:  .text "NO SERVER SET (SYSTEM -> EMAIL)"
            .byte $ff
sMnNoHw:    .text "NO NETWORK (SEE NETWORK)"
            .byte $ff
sMnNoConn:  .text "NO CONNECTION TO THE SERVER"
            .byte $ff
sMnRefused: .text "CONNECTION REFUSED"
            .byte $ff
sMnTime:    .text "NO ANSWER FROM THE SERVER"
            .byte $ff
sMnClosed:  .text "THE SERVER CLOSED THE CONNECTION"
            .byte $ff
sMnLost:    .text "SENDING FAILED"
            .byte $ff
