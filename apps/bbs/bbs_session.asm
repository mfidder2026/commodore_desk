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
// Ontvangen bytes gaan via de Telnet-parser (bbs_telnet.asm) naar het
// scherm (tcpRxVec = tm_Rx): in PETSCII-modus met kleuren, RVS en
// cursorbesturing; in ASCII-modus met CR/LF/BS/TAB en ANSI-reeksen die
// worden overgeslagen.
//
// Toetsen: gewone toetsen gaan naar de BBS (lokale echo als BC_ECHO);
// F7 opent het sessiemenu op de statusregel (wordt nooit verstuurd).
// Het toetsenbord staat dan in de ruwe modus (kbRaw): cursortoetsen,
// F-toetsen, CLR/HOME, INST, CTRL/C=-kleuren en C=-graphics gaan als
// PETSCII naar de BBS; RUN/STOP stuurt $03 (lijst afbreken).
//========================================================

.const TM_ROWS   = 24            // terminalregels; rij 24 = statusregel
.const TM_STAT   = 24
.const TM_FG     = LIGHT_GREY    // standaard tekstkleur
.const TM_STATFG = LIGHT_BLUE
.const TM_TXMAX  = 64            // toetsen + Telnet-antwoorden
.const PC_N      = 16            // PETSCII-kleurcodes
.const SK_N      = 13            // speciale toetsen (skCode)
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
        jsr tn_Reset             // Telnet: alle opties uit
        lda #0
        sta tmTxLen
        ldx #tmCntEnd-tmCnt-1    // RX/TX-tellers en verbindingstijd
!:      sta tmCnt,x
        dex
        bpl !-
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
        lda #0                   // (tmTx kan al Telnet-antwoorden bevatten)
        sta tmMenu
        jsr tm_StatOnline
        jsr tm_CurOn
lp:     lda frameLo              // klok: elke 50 beelden = 1 seconde
        cmp tmFrLast
        beq lp0
        sta tmFrLast
        inc tmFr
        lda tmFr
        cmp #50
        bcc lp0
        lda #0
        sta tmFr
        inc tmSecs
        bne !+
        inc tmSecs+1
!:      lda tmMenu
        bne lp0
        jsr tm_StatInfo
lp0:    jsr evt_Poll
        cmp #EVT_KEY
        bne net
        lda evtA
        ldx tmMenu               // sessiemenu open?
        bne menu
        cmp #KEY_F7              // F7: sessiemenu (lokaal, nooit verstuurd)
        bne key
        lda #1
        sta tmMenu
        jsr tm_StatMenu
        jmp lp
key:    ldx evtB                 // SHIFT/CTRL/C= (ruwe toetsenbordmodus)
        stx tmMods
        jsr tm_Key               // -> tmTx
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
//            Eerst naar tmSend gekopieerd: tijdens het wachten op de ACK
//            kunnen er nieuwe Telnet-antwoorden in tmTx komen.
tm_Flush: {
        ldx #0
cp:     lda tmTx,x
        sta tmSend,x
        inx
        cpx tmTxLen
        bne cp
        stx tcpDataLen
        txa                      // TX-teller
        clc
        adc tmTxN
        sta tmTxN
        bcc !+
        inc tmTxN+1
        bne !+
        inc tmTxN+2
!:      lda #<tmSend
        sta tcpDataPtr
        lda #>tmSend
        sta tcpDataPtr+1
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
        sta tmKey
        ldx #SK_N-1              // RETURN, DEL, STOP, F-toetsen, cursor ...
sk:     cmp skCode,x
        beq spec
        dex
        bpl sk
        lda tmMods
        and #KM_CTRL
        beq nc
        lda tmKey                // CTRL + letter = stuurcode $01-$1A
        cmp #$1b
        bcs cdig
        jmp put
cdig:   ldx tmAscii              // CTRL + cijfer = kleur / RVS (PETSCII)
        bne none
        sec
        sbc #$30
        cmp #10
        bcs none
        tax
        lda ctrlDig,x
        jmp put
none:   rts
nc:     lda tmMods
        and #KM_CBM
        beq plain
        ldx tmAscii
        bne plain
        lda tmKey
        cmp #$1b                 // C= + letter = graphics links op de toets
        bcs cd
        tax
        lda cbmTab-1,x
        jmp put
cd:     sec                      // C= + 1-8 = de lichte kleuren
        sbc #$31
        cmp #8
        bcs plain
        tax
        lda cbmDig,x
        jmp put
spec:   lda tmMods
        and #KM_SHIFT
        ldy tmAscii
        bne sa
        cmp #0
        bne ss
        lda skPet,x
        jmp chk
ss:     lda skPetS,x
chk:    beq no
        jmp put
sa:     cmp #0
        bne sas
        lda skAsc,x
        jmp ach
sas:    lda skAscS,x
ach:    beq no
        bpl put
        pha                      // bit 7: ANSI-reeks ESC [ x (zonder echo)
        lda #$1b
        jsr tm_TxPut
        lda #$5b
        jsr tm_TxPut
        pla
        and #$7f
        jmp tm_TxPut
plain:  lda tmKey
        cmp #$1b                 // letters $01-$1A
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
put:    jsr tm_TxPut
        ldx BC_ECHO              // lokale echo (niet als de server echoot)
        beq no
        ldx tnHim+TO_ECHO
        bne no
        jmp tm_Show              // (buiten de Telnet-parser om)
no:     rts
}
// speciale toetsen: code, PETSCII, PETSCII+SHIFT, ASCII, ASCII+SHIFT
// (0 = niets sturen; ASCII met bit 7 = ANSI-reeks ESC [ x)
skCode: .byte KEY_RETURN, KEY_DEL, KEY_STOP, KEY_F1, KEY_F3, KEY_F5
        .byte KEY_CRSR_R, KEY_CRSR_D, KEY_HOME, KEY_AT, KEY_POUND, KEY_UPARROW, KEY_LARROW
skPet:  .byte $0d, $14, $03, $85, $86, $87, $1d, $11, $13, $40, $5c, $5e, $5f
skPetS: .byte $8d, $94, $03, $89, $8a, $8b, $9d, $91, $93, $ba, $a9, $de, $df
skAsc:  .byte $0d, $08, $03, 0,   0,   0,   $c3, $c2, $c8, $40, $5c, $5e, $5f
skAscS: .byte $0d, $08, $03, 0,   0,   0,   $c4, $c1, $0c, $40, $7c, $7e, $60
// CTRL + 0-9: RVS UIT, ZWART, WIT, ROOD, CYAAN, PAARS, GROEN, BLAUW, GEEL, RVS AAN
ctrlDig: .byte $92, $90, $05, $1c, $9f, $9c, $1e, $1f, $9e, $12
// C= + 1-8: ORANJE, BRUIN, LICHTROOD, DONKERGRIJS, GRIJS, LICHTGROEN, LICHTBLAUW, LICHTGRIJS
cbmDig:  .byte $81, $95, $96, $97, $98, $99, $9a, $9b
// C= + A-Z (graphics links op de toets, zoals de KERNAL-tabel)
cbmTab:  .byte $b0, $bf, $bc, $ac, $b1, $bb, $a5, $b4, $a2, $b5, $a1, $b6, $a7
         .byte $aa, $b9, $af, $ab, $b2, $ae, $a3, $b8, $be, $b3, $bd, $b7, $ad

// tm_TxPut - byte A achter in de zendrij (vol: weggooien). X/Y blijven.
tm_TxPut:
        stx tmXs
        ldx tmTxLen
        cpx #TM_TXMAX
        bcs !+
        sta tmTx,x
        inc tmTxLen
!:      ldx tmXs
        rts

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
        lda #1                   // toetsenbord: ruwe modus
        sta kbRaw
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
        sta kbRaw
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
        ldx BC_DEFAULT           // naam van de BBS links (de info erna
        lda bbNameLo,x           // overschrijft een te lange naam)
        ldy bbNameHi,x
        tax
        lda #1
        jsr tm_StatAt
// tm_StatInfo - "RX 12K TX 1K  03:12 F7=MENU" vanaf kolom 13 (bouwplan §32).
tm_StatInfo: {
        lda #0
        sta tmSl
        lda #$20                 // spatie na de naam
        jsr put
        lda #$12                 // R
        jsr put
        lda #$18                 // X
        jsr put
        lda tmRxN+1              // kB = teller / 1024
        ldx tmRxN+2
        jsr kb
        lda #$20
        jsr put
        lda #$14                 // T
        jsr put
        lda #$18                 // X
        jsr put
        lda tmTxN+1
        ldx tmTxN+2
        jsr kb
        lda #$20
        jsr put
        lda tmSecs               // mm:ss
        sta tmV
        lda tmSecs+1
        sta tmV+1
        lda #0
        sta tmMin
mn:     lda tmV+1                // minuten = seconden / 60
        bne sub60
        lda tmV
        cmp #60
        bcc mdone
sub60:  lda tmV
        sec
        sbc #60
        sta tmV
        bcs !+
        dec tmV+1
!:      inc tmMin
        jmp mn
mdone:  lda tmMin
        cmp #100
        bcc !+
        lda #99
!:      jsr two
        lda #$3a                 // :
        jsr put
        lda tmV
        jsr two
        ldx #<sTmF7
        ldy #>sTmF7
        lda #33
        jmp tm_StatAt
// kb - (X:A) / 4 = kB (tellerbytes 1 en 2), 0-999 + "K"
kb:     stx tmV+1
        lsr tmV+1
        ror
        lsr tmV+1
        ror
        sta tmV
        lda tmV+1                // > 999: 999
        cmp #>1000
        bcc k1
        bne k9
        lda tmV
        cmp #<1000
        bcc k1
k9:     lda #<999
        sta tmV
        lda #>999
        sta tmV+1
k1:     lda #0
        sta tmAny
        ldx #0
kd:     lda #0
        sta tmDig
ks:     lda tmV
        sec
        sbc kTabLo,x
        tay
        lda tmV+1
        sbc kTabHi,x
        bcc kp
        sta tmV+1
        sty tmV
        inc tmDig
        jmp ks
kp:     lda tmDig
        ora tmAny
        bne kpr
        cpx #2
        bne kn
kpr:    lda tmDig
        ora #$30
        stx tmKx                 // (put gebruikt X)
        jsr put
        ldx tmKx
        inc tmAny
kn:     inx
        cpx #3
        bne kd
        lda #$0b                 // K
        jmp put
// two - A (0-99) als twee cijfers
two:    ldx #$2f
t1:     inx
        sec
        sbc #10
        bcs t1
        adc #10
        pha
        txa
        jsr put
        pla
        ora #$30
// put - teken A (hoofdletterset-schermcode) reverse op de statusregel
put:    ldx tmSl
        cpx #20
        bcs pr
        jsr tm_Upper
        ora #$80
        ldx tmSl
        sta SCREEN_RAM+TM_STAT*40+13,x
        inc tmSl
pr:     rts
kTabLo: .byte <100, <10, <1
kTabHi: .byte >100, >10, >1
}
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
        inc tmRxN                // RX-teller (24 bit)
        bne !+
        inc tmRxN+1
        bne !+
        inc tmRxN+2
!:      jsr tn_Byte              // Telnet-commando's eruit
        bcs tm_Show
        rts
// tm_Show - databyte A tonen (PETSCII of ASCII).
tm_Show:
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
        cmp #$94
        beq ins
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
ins:    jsr tm_Ptr               // INST: rest van de regel naar rechts
        ldy #38
il:     cpy tmX
        bcc ie
        lda (tmScr),y
        iny
        sta (tmScr),y
        dey
        lda (tmClr),y
        iny
        sta (tmClr),y
        dey
        dey
        bpl il
ie:     ldy tmX
        lda #$20
        sta (tmScr),y
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
tmSend:   .fill TM_TXMAX, 0
tmXs:     .byte 0
// tellers voor de statusregel (bij het verbinden op nul)
tmCnt:
tmRxN:    .fill 3, 0
tmTxN:    .fill 3, 0
tmSecs:   .word 0
tmFr:     .byte 0
tmCntEnd:
tmFrLast: .byte 0
tmSl:     .byte 0
tmMin:    .byte 0
tmV:      .word 0
tmKx:     .byte 0
tmKey:    .byte 0
tmMods:   .byte 0

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
sTmOnStat:  .byte $ff
sTmF7:      .text "F7=MENU"
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
