#importonce
//========================================================
// apps/bbs/bbs_session.asm - verbinden + terminal (bouwplan Increment 2)
// Commodore Desk 64
//
// CONNECT: host van de default BBS -> IP (direct of via DNS), ARP, TCP.
// Op een Ultimate doet de firmware TCP en DNS (ut_ConnectFe).
// Daarna een volledig-scherm terminal: rijen 0-23 tekst, rij 24 status.
// De ROM-charset wordt gebruikt (PETSCII-graphics, hoofd/kleine letters);
// bij het verlaten zet tm_Leave de VIC terug en tekent de shell alles.
//
// Ontvangen bytes gaan direct naar het scherm (tcpRxVec = tm_Rx), in
// PETSCII-modus met kleuren, RVS en cursorbesturing; in ASCII-modus
// met CR/LF/BS/TAB en ANSI-reeksen die worden overgeslagen. Telnet-
// onderhandeling volgt in Increment 3.
//
// Toetsen: gewone toetsen gaan naar de BBS (lokale echo als BC_ECHO);
// RUN/STOP opent het sessiemenu op de statusregel (wordt nooit verstuurd).
//========================================================

.const TM_ROWS   = 24            // terminalregels; rij 24 = statusregel
.const TM_STAT   = 24
.const TM_FG     = LIGHT_GREY    // standaard tekstkleur
.const TM_STATFG = LIGHT_BLUE
.const TM_TXMAX  = 16
.const PC_N      = 16            // PETSCII-kleurcodes
.label tmScr = r3                // zeropage: scherm- en kleurpointer
.label tmClr = r6

//--------------------------------------------------------
// bb_Connect - verbinden met de default BBS en de terminal draaien.
//--------------------------------------------------------
bb_Connect: {
        ldx BC_DEFAULT
        lda bbFlags,x
        and #BF_CONNECT
        bne c1
        ldx #<sBbDirOnly
        ldy #>sBbDirOnly
        jmp bb_SetMsg
c1:     lda bbHostLo,x           // host -> feBuf/feLen, poort -> tcpRPort
        sta r0
        lda bbHostHi,x
        sta r0+1
        lda bbPortHi,x           // (tcpRPort is big-endian)
        sta tcpRPort
        lda bbPortLo,x
        sta tcpRPort+1
        ldy #0
hc:     lda (r0),y
        cmp #$ff
        beq he
        sta feBuf,y
        iny
        cpy #32
        bne hc
he:     sty feLen
        lda bbMode,x             // ASCII of PETSCII (AUTO = PETSCII)
        ldy #0
        cmp #BM_ASCII
        bne md
        iny
md:     sty tmAscii
        lda #1                   // start in de kleine-letterset (upper/lower)
        sta tmLower
        lda #0
        sta netAbort
        sta netNoKeys
        jsr tm_Enter
        jsr tm_Intro             // "CONNECTING TO" / naam / host:poort
        lda netPlatform
        cmp #NET_PLAT_ULTIMATE
        bne rr
        // --- Ultimate: de firmware doet DNS + TCP
        ldx #<sTmConn
        ldy #>sTmConn
        jsr tm_Line
        jsr ut_ConnectFe
        bcc uf
        jmp ok
uf:     ldx #<sBbNoConn
        ldy #>sBbNoConn
        jmp fail
rr:     cmp #NET_PLAT_RRNET
        beq hw
        ldx #<sBbNoHw
        ldy #>sBbNoHw
        jmp fail
hw:     lda csReady
        bne hwOk
        jsr cs_Init
        bcs ci
        ldx #<sPgChip
        ldy #>sPgChip
        jmp fail
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
name:   ldx #<sTmResolve
        ldy #>sTmResolve
        jsr tm_Line
        jsr name_Resolve         // (feBuf/feLen) -> dnsIp, anders X/Y
        bcs dn
        jmp fail
dn:     ldx #3
cd:     lda dnsIp,x
        sta ipDst,x
        dex
        bpl cd
arp:    ldx #<sTmConn
        ldy #>sTmConn
        jsr tm_Line
        jsr ip_NextHop
        jsr arp_Resolve
        bcs a1
        ldx #<sPgNoArp
        ldy #>sPgNoArp
        jmp fail
a1:     lda #<tm_Rx              // data kan direct na de SYN-ACK komen
        sta tcpRxVec
        lda #>tm_Rx
        sta tcpRxVec+1
        jsr tcp_Connect
        bcc tf
        jmp ok
tf:
        ldx #<sPgStop
        ldy #>sPgStop
        lda netAbort
        bne fail
        ldx #<sBbRefused
        ldy #>sBbRefused
        lda tcpRst
        bne fail
        ldx #<sBbNoConn
        ldy #>sBbNoConn
fail:   stx bbMsg
        sty bbMsg+1
        jsr tm_Leave
        jmp shell_DrawAll
ok:     lda #<tm_Rx
        sta tcpRxVec
        lda #>tm_Rx
        sta tcpRxVec+1
        ldx #<sTmOnline
        ldy #>sTmOnline
        jsr tm_Line
        jsr tm_Nl
        jmp bb_Term
}

//--------------------------------------------------------
// bb_Term - de sessie: toetsen -> BBS, BBS -> scherm.
//--------------------------------------------------------
bb_Term: {
        lda #1
        sta netNoKeys
        lda #0
        sta tmTxLen
        sta tmMenu
        jsr tm_StatOnline
        jsr tm_CurOn
lp:     jsr evt_Poll
        cmp #EVT_KEY
        bne net
        lda evtA
        ldx tmMenu               // sessiemenu open?
        bne menu
        cmp #$82                 // RUN/STOP: sessiemenu (lokaal)
        bne key
        lda #1
        sta tmMenu
        jsr tm_StatMenu
        jmp lp
key:    jsr tm_Key               // -> tmTx
        jmp lp                   // eerst alle wachtende toetsen
menu:   ldx #0
        stx tmMenu
        cmp #$04                 // D = verbreken
        beq disc
        cmp #$11                 // Q = verbreken + desktop
        beq quit
        jsr tm_StatOnline        // al het andere: verder
        jmp lp
net:    lda tmTxLen              // verzamelde toetsen versturen
        beq rx
        jsr tm_Flush
        bcs rx
        ldx #<sBbLost
        ldy #>sBbLost
        jmp gone
rx:     lda netPlatform
        cmp #NET_PLAT_ULTIMATE
        beq ut
        jsr net_Poll
        lda tcpRst
        bne closed
        lda tcpFin
        bne closed
        jmp lp
ut:     lda frameLo              // de Ultimate één keer per beeld vragen
        cmp tmLastF
        beq lp2
        sta tmLastF
        jsr ut_Read
        cmp #1
        beq closed
        cmp #$ff
        beq closed
lp2:    jmp lp
disc:   jsr tm_Close
        ldx #<sBbDiscd
        ldy #>sBbDiscd
        jmp leave
quit:   jsr tm_Close
        jsr tm_Leave
        jmp exitToDesktop
closed: jsr tm_Close             // de BBS heeft opgehangen
        ldx #<sBbRemote
        ldy #>sBbRemote
gone:   stx bbMsg
        sty bbMsg+1
        jsr tm_CurOff
        ldx #<sTmClosed          // "... PRESS RETURN"
        ldy #>sTmClosed
        jsr tm_Stat
w:      jsr evt_Poll
        cmp #EVT_KEY
        bne w
        lda evtA
        cmp #$80
        beq bk
        cmp #$82
        bne w
bk:     jmp back
leave:  stx bbMsg
        sty bbMsg+1
back:   jsr tm_Leave
        jmp shell_DrawAll
}

// tm_Close - verbinding sluiten (RR-Net: FIN; Ultimate: handle dicht).
tm_Close:
        lda #0
        sta netNoKeys
        lda netPlatform
        cmp #NET_PLAT_ULTIMATE
        bne !+
        jmp ut_Close
!:      jmp tcp_Close

// tm_Flush - tmTx (tmTxLen bytes) versturen. Carry=1 gelukt.
tm_Flush: {
        lda #<tmTx
        sta tcpDataPtr
        lda #>tmTx
        sta tcpDataPtr+1
        lda tmTxLen
        sta tcpDataLen
        lda #0
        sta tcpDataLen+1
        sta tmTxLen
        lda netPlatform
        cmp #NET_PLAT_ULTIMATE
        bne rr
        jmp ut_Write
rr:     jmp tcp_Send
}

//--------------------------------------------------------
// tm_Key - toets (evtA-code) -> byte voor de BBS in tmTx.
//--------------------------------------------------------
tm_Key: {
        cmp #$80                 // RETURN
        bne k1
        lda #$0d
        jmp put
k1:     cmp #$81                 // DEL
        bne k2
        lda #$14
        ldx tmAscii
        beq put
        lda #$08
        jmp put
k2:     cmp #$1b                 // letters $01-$1A
        bcs k3
        tax
        beq no
        ora #$40                 // PETSCII: A-Z = $41-$5A
        ldx tmAscii
        beq put
        ora #$20                 // ASCII: a-z
        jmp put
k3:     bne k4                   // [ (SHIFT+:)
        lda #$5b
        jmp put
k4:     cmp #$1d                 // ] (SHIFT+;)
        bne k5
        lda #$5d
        jmp put
k5:     cmp #$20                 // spatie, cijfers, leestekens
        bcc no
        cmp #$40
        bcc put
        cmp #$41                 // SHIFT+letter: $41-$5A
        bcc no
        cmp #$5b
        bcs no
        ldx tmAscii
        bne put                  // ASCII: hoofdletter
        ora #$80                 // PETSCII: SHIFT-letter $C1-$DA
put:    ldx tmTxLen
        cpx #TM_TXMAX
        bcs no
        sta tmTx,x
        inc tmTxLen
        ldx BC_ECHO              // lokale echo
        beq no
        jmp tm_Rx
no:     rts
}

//--------------------------------------------------------
// Scherm: in- en uitgaan.
//--------------------------------------------------------
tm_Enter: {
        lda VIC_MEM
        sta tmSave
        lda BORDER_COL
        sta tmSave+1
        lda BG_COL0
        sta tmSave+2
        lda SPR_ENABLE           // muispijl uit
        and #$fe
        sta SPR_ENABLE
        lda #BLACK
        sta BORDER_COL
        sta BG_COL0
        lda #0
        sta tmRev
        sta tmEsc
        sta tmCurVis
        jsr tm_Charset
        lda #TM_FG
        sta tmFg
        jsr tm_Cls
        ldx #<sTmBlank
        ldy #>sTmBlank
        jmp tm_Stat
}

tm_Leave: {
        jsr tm_CurOff
        lda tmSave
        sta VIC_MEM
        lda tmSave+1
        sta BORDER_COL
        lda tmSave+2
        sta BG_COL0
        lda #0
        sta netNoKeys
        lda SPR_ENABLE
        ora #$01
        sta SPR_ENABLE
        rts
}

// tm_Charset - ROM-charset: $1000 (hoofdletters/graphics) of $1800
//              (kleine letters), scherm blijft op $0400.
tm_Charset:
        lda tmLower
        asl
        ora #$14
        sta VIC_MEM
        rts

// tm_Intro - verbindingsscherm (bouwplan §13).
tm_Intro: {
        ldx #<sTmConnTo
        ldy #>sTmConnTo
        jsr tm_Line
        jsr tm_Nl
        ldx BC_DEFAULT
        lda bbNameLo,x
        ldy bbNameHi,x
        tax
        jsr tm_Line
        jsr tm_Nl
        ldx #0                   // host:poort
hl:     cpx feLen
        beq hp
        stx tmI
        lda feBuf,x
        jsr tm_Local
        ldx tmI
        inx
        bne hl
hp:     lda #$3a
        jsr tm_Local
        ldx BC_DEFAULT
        lda bbPortLo,x
        sta tmNum
        lda bbPortHi,x
        sta tmNum+1
        ldx #0
        stx tmAny
dg:     lda #0
        sta tmDig
sb:     lda tmNum
        sec
        sbc bbD16Lo,x
        tay
        lda tmNum+1
        sbc bbD16Hi,x
        bcc pd
        sta tmNum+1
        sty tmNum
        inc tmDig
        jmp sb
pd:     lda tmDig
        ora tmAny
        bne pr
        cpx #4
        bne nx
pr:     stx tmI
        lda tmDig
        ora #$30
        jsr tm_Local
        ldx tmI
        inc tmAny
nx:     inx
        cpx #5
        bne dg
        jsr tm_Nl
        jmp tm_Nl
}

// tm_Line - lokale tekst X/Y (schermcodes, $ff) + nieuwe regel.
tm_Line: {
        stx r4
        sty r4+1
        ldy #0
lp:     lda (r4),y
        cmp #$ff
        beq done
        sty tmI
        jsr tm_Local
        ldy tmI
        iny
        bne lp
done:   jmp tm_Nl
}

// tm_Local - lokale schermcode (hoofdletterset) in de terminal zetten.
tm_Local:
        jsr tm_Upper
        jmp tm_Put

// tm_Upper - schermcode uit de hoofdletterset: in de kleine-letterset
//            worden letters $01-$1A de hoofdletters $41-$5A.
tm_Upper:
        ldx tmLower
        beq !r+
        cmp #$01
        bcc !r+
        cmp #$1b
        bcs !r+
        ora #$40
!r:     rts

//--------------------------------------------------------
// Statusregel (rij 24, reverse).
//--------------------------------------------------------
tm_StatOnline:
        ldx #<sTmOnStat
        ldy #>sTmOnStat
        jsr tm_Stat
        ldx BC_DEFAULT           // naam van de BBS links
        lda bbNameLo,x
        ldy bbNameHi,x
        tax
        lda #1
        jmp tm_StatAt
tm_StatMenu:
        ldx #<sTmMenu
        ldy #>sTmMenu
// tm_Stat - statusregel wissen en tekst X/Y vanaf kolom 1 tonen.
tm_Stat: {
        stx tmP
        sty tmP+1
        ldy #39
cl:     lda #$a0                 // reverse spatie
        sta SCREEN_RAM+TM_STAT*40,y
        lda #TM_STATFG
        sta COLOR_RAM+TM_STAT*40,y
        dey
        bpl cl
        ldx tmP
        ldy tmP+1
        lda #1
}
// tm_StatAt - tekst X/Y op de statusregel vanaf kolom A.
tm_StatAt: {
        stx r4
        sty r4+1
        sta tmI
        ldy #0
lp:     lda (r4),y
        cmp #$ff
        beq done
        jsr tm_Upper
        ora #$80
        ldx tmI
        cpx #40
        bcs done
        sta SCREEN_RAM+TM_STAT*40,x
        inc tmI
        iny
        bne lp
done:   rts
}

//--------------------------------------------------------
// tm_Rx - één ontvangen byte (callback van TCP/UCI) naar het scherm.
//--------------------------------------------------------
tm_Rx:
        pha
        jsr tm_CurOff
        pla
        ldx tmAscii
        bne !a+
        jsr tm_Pet
        jmp tm_CurOn
!a:     jsr tm_Asc
        jmp tm_CurOn

// tm_Pet - PETSCII.
tm_Pet: {
        cmp #$20
        bcc ctl
        cmp #$80
        bcc lo
        cmp #$a0
        bcc ctl
        cmp #$ff                 // pi
        bne h1
        lda #$5e
        jmp out
h1:     cmp #$c0
        bcs h2
        sbc #$3f                 // $A0-$BF -> $60-$7F (carry=0: -$40)
        jmp out
h2:     and #$7f                 // $C0-$FE -> $40-$7E
        jmp out
lo:     cmp #$40                 // $20-$3F blijft
        bcc out
        cmp #$60
        bcs l6
        and #$3f                 // $40-$5F -> $00-$1F
        jmp out
l6:     sbc #$20                 // $60-$7F -> $40-$5F (carry=1)
out:    ora tmRev
        jmp tm_Put
ctl:    ldx #PC_N-1              // kleurcode?
cc:     cmp pcCode,x
        beq col
        dex
        bpl cc
        cmp #$0d
        beq cr
        cmp #$8d
        beq cr
        cmp #$93
        beq cls
        cmp #$13
        beq home
        cmp #$14
        beq del
        cmp #$11
        beq down
        cmp #$91
        beq up
        cmp #$1d
        beq right
        cmp #$9d
        beq left
        cmp #$12
        beq rvsOn
        cmp #$92
        beq rvsOff
        cmp #$0e
        beq lower
        cmp #$8e
        beq upper
        rts
col:    lda pcCol,x
        sta tmFg
        rts
cr:     lda #0                   // RETURN zet RVS uit (zoals de C64)
        sta tmRev
        jmp tm_Nl
cls:    jmp tm_Cls
home:   lda #0
        sta tmX
        sta tmY
        rts
del:    jsr tm_Left
        lda #$20
        jsr tm_Put
        jmp tm_Left
down:   jmp tm_Down
up:     lda tmY
        beq r
        dec tmY
r:      rts
right:  jmp tm_Adv
left:   jmp tm_Left
rvsOn:  lda #$80
        sta tmRev
        rts
rvsOff: lda #0
        sta tmRev
        rts
lower:  lda #1
        sta tmLower
        jmp tm_Charset
upper:  lda #0
        sta tmLower
        jmp tm_Charset
}
pcCode: .byte $90, $05, $1c, $9f, $9c, $1e, $1f, $9e
        .byte $81, $95, $96, $97, $98, $99, $9a, $9b
pcCol:  .byte BLACK, WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW
        .byte ORANGE, BROWN, LIGHT_RED, DARK_GREY, GREY, LIGHT_GREEN, LIGHT_BLUE, LIGHT_GREY

// tm_Asc - ASCII (kleine-letterset); ANSI-reeksen worden overgeslagen,
//          alleen ESC[..J (wissen) en ESC[..H (home) doen iets.
tm_Asc: {
        ldx tmEsc
        bne esc
        cmp #$1b
        bne a1
        lda #1
        sta tmEsc
        rts
a1:     cmp #$20
        bcc ctl
        cmp #$7f
        bcs no
        cmp #$40                 // $20-$3F blijft
        bcc out
        beq at
        cmp #$5b                 // A-Z blijft ($41-$5A)
        bcc out
        cmp #$60
        bcc sy
        cmp #$7b
        bcs sy2
        and #$1f                 // a-z -> $01-$1A
        jmp out
sy:     and #$1f                 // [ \ ] ^ _ -> $1B-$1F
        jmp out
sy2:    sbc #$20                 // { | } ~ -> $5B-$5E (carry=1)
        jmp out
at:     lda #0
out:    jmp tm_Put
ctl:    cmp #$0d
        bne c1
        lda #0
        sta tmX
        rts
c1:     cmp #$0a
        bne c2
        jmp tm_Down
c2:     cmp #$08
        bne c3
        jmp tm_Left
c3:     cmp #$0c
        bne c4
        jmp tm_Cls
c4:     cmp #$09
        bne no
        lda tmX                  // TAB: volgende veelvoud van 8
        ora #7
        sta tmX
        jmp tm_Adv
no:     rts
esc:    cpx #1
        bne csi
        ldx #0                   // ESC x: alleen ESC [ gaat verder
        cmp #$5b
        bne e0
        ldx #2
e0:     stx tmEsc
        rts
csi:    cmp #$40                 // parameters/tussentekens: overslaan
        bcc no
        ldx #0
        stx tmEsc
        cmp #$4a                 // J
        bne e1
        jmp tm_Cls
e1:     cmp #$48                 // H
        bne no
        stx tmX
        stx tmY
        rts
}

//--------------------------------------------------------
// Tekenen.
//--------------------------------------------------------
// tm_Put - schermcode A op de cursor (kleur tmFg), cursor verder.
tm_Put:
        pha
        jsr tm_Ptr
        pla
        sta (tmScr),y
        lda tmFg
        sta (tmClr),y
// tm_Adv - cursor één naar rechts (regelomslag).
tm_Adv:
        inc tmX
        lda tmX
        cmp #40
        bcc !r+
// tm_Nl - begin van de volgende regel (scrollt onderaan).
tm_Nl:
        lda #0
        sta tmX
// tm_Down - regel omlaag (scrollt onderaan).
tm_Down:
        inc tmY
        lda tmY
        cmp #TM_ROWS
        bcc !r+
        dec tmY
        jmp tm_Scroll
!r:     rts

// tm_Left - cursor één naar links (naar de vorige regel).
tm_Left:
        lda tmX
        beq !+
        dec tmX
        rts
!:      lda tmY
        beq !r+
        dec tmY
        lda #39
        sta tmX
!r:     rts

// tm_Ptr - tmScr/tmClr = begin van regel tmY, Y = tmX.
tm_Ptr:
        ldy tmY
        lda tmRowLo,y
        sta tmScr
        sta tmClr
        lda tmRowHi,y
        sta tmScr+1
        clc
        adc #>[COLOR_RAM-SCREEN_RAM]
        sta tmClr+1
        ldy tmX
        rts

// tm_Scroll - regels 1-23 één omhoog, onderste regel leeg.
tm_Scroll: {
        ldx #0
lp:     lda tmRowLo+1,x          // bron = regel x+1 (r0), doel = regel x (r1)
        sta r0
        lda tmRowHi+1,x
        sta r0+1
        lda tmRowLo,x
        sta r1
        lda tmRowHi,x
        sta r1+1
        ldy #39
cs:     lda (r0),y
        sta (r1),y
        dey
        bpl cs
        lda r0+1
        clc
        adc #>[COLOR_RAM-SCREEN_RAM]
        sta r0+1
        lda r1+1
        clc
        adc #>[COLOR_RAM-SCREEN_RAM]
        sta r1+1
        ldy #39
cc:     lda (r0),y
        sta (r1),y
        dey
        bpl cc
        inx
        cpx #TM_ROWS-1
        bne lp
        lda #TM_ROWS-1
        jmp tm_ClrRow
}

// tm_Cls - terminalgebied wissen, cursor linksboven.
tm_Cls: {
        lda #TM_ROWS-1
        sta tmK
lp:     lda tmK
        jsr tm_ClrRow
        dec tmK
        bpl lp
        lda #0
        sta tmX
        sta tmY
        rts
}

// tm_ClrRow - regel A wissen (tmY blijft).
tm_ClrRow: {
        ldx tmY
        stx tmK2
        sta tmY
        jsr tm_Ptr
        ldy #39
lp:     lda #$20
        sta (tmScr),y
        lda tmFg
        sta (tmClr),y
        dey
        bpl lp
        lda tmK2
        sta tmY
        rts
}

// cursor: reverse op de cursorpositie (aan/uit).
tm_CurOn:
        lda tmCurVis
        bne !r+
        inc tmCurVis
        jmp tmCurFlip
tm_CurOff:
        lda tmCurVis
        beq !r+
        dec tmCurVis
tmCurFlip:
        jsr tm_Ptr
        lda (tmScr),y
        eor #$80
        sta (tmScr),y
        lda tmFg
        sta (tmClr),y
!r:     rts

tmRowLo: .fill 25, <[SCREEN_RAM+i*40]
tmRowHi: .fill 25, >[SCREEN_RAM+i*40]

//--------------------------------------------------------
tmX:      .byte 0
tmY:      .byte 0
tmFg:     .byte TM_FG
tmRev:    .byte 0
tmLower:  .byte 0
tmAscii:  .byte 0
tmEsc:    .byte 0
tmCurVis: .byte 0
tmMenu:   .byte 0
tmLastF:  .byte 0
tmI:      .byte 0
tmK:      .byte 0
tmK2:     .byte 0
tmDig:    .byte 0
tmAny:    .byte 0
tmNum:    .word 0
tmP:      .word 0
tmSave:   .fill 3, 0
tmTxLen:  .byte 0
tmTx:     .fill TM_TXMAX, 0

.encoding "screencode_upper"
sTmConnTo:  .text "CONNECTING TO"
            .byte $ff
sTmResolve: .text "RESOLVING HOST..."
            .byte $ff
sTmConn:    .text "CONNECTING..."
            .byte $ff
sTmOnline:  .text "CONNECTED"
            .byte $ff
sTmBlank:   .byte $ff
sTmOnStat:  .fill 30, $20
            .text "STOP=MENU"
            .byte $ff
sTmMenu:    .text "D=DISCONNECT Q=DESKTOP OTHER=RESUME"
            .byte $ff
sTmClosed:  .text "CONNECTION CLOSED - PRESS RETURN"
            .byte $ff
sBbNoConn:  .text "NO CONNECTION TO THE BBS"
            .byte $ff
sBbRefused: .text "CONNECTION REFUSED"
            .byte $ff
sBbNoHw:    .text "NO NETWORK (SEE NETWORK)"
            .byte $ff
sBbLost:    .text "CONNECTION LOST"
            .byte $ff
sBbRemote:  .text "CLOSED BY THE REMOTE HOST"
            .byte $ff
sBbDiscd:   .text "DISCONNECTED"
            .byte $ff
