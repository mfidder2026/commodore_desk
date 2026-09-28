#importonce
//========================================================
// apps/bbs/bbs_xmodem.asm - XMODEM-download (bouwplan §57)
// Commodore Desk 64
//
// In de terminal: F7 en dan X. Eerst de bestandsnaam (statusregel), dan
// ontvangt de C64 het bestand dat de BBS met XMODEM stuurt en schrijft
// het als PRG naar drive 8.
//   - XMODEM-CRC ('C'); na 3 keer zonder antwoord gewone checksum (NAK)
//   - blokken van 128 (SOH) en 1024 bytes (STX, XMODEM-1K)
//   - "stop and wait": elk blok staat op disk voordat de ACK weggaat, dus
//     disk en netwerk zitten elkaar nooit in de weg
//   - het laatste blok wordt pas bij EOT geschreven, zonder de opvulling
//     met $1A (CP/M-einde)
//   - RUN/STOP breekt af (CAN CAN CAN)
// Ontvangen bytes komen via tm_Rx binnen; alleen als de BBS echt Telnet
// spreekt (tnSeen) gaan ze eerst door de Telnet-parser (IAC IAC = $FF).
// Buffers: XM_BUF (pakket) en XM_HOLD (vorig blok) op $C500-$CD0F.
//========================================================

.const XM_SOH = $01
.const XM_STX = $02
.const XM_EOT = $04
.const XM_ACK = $06
.const XM_NAK = $15
.const XM_CAN = $18
.const XM_C   = $43              // "C" (ASCII): CRC-modus
.label XM_BUF  = $c500           // 3 + 1024 + 2
.label XM_HOLD = $c910           // 1024
.const XM_LFN  = 5               // kanaal voor het bestand
.label xmP     = r5              // zeropage (alleen binnen deze routines)

//--------------------------------------------------------
// xm_Start - naam vragen, bestand openen, eerste 'C' sturen.
//            Uit: xmOn = 1 als de download loopt.
//--------------------------------------------------------
xm_Start: {
        lda #0
        sta xmOn
        ldx #<sXmName            // "SAVE AS:"
        ldy #>sXmName
        jsr tm_Stat
        lda #<xmName
        sta r3
        lda #>xmName
        sta r3+1
        lda #16
        sta liMax
        lda #9
        sta liCol
        lda #TM_STAT
        sta liRow
        lda #16
        sta liVis
        lda #$ff
        sta xmName
        jsr li_Edit
        lda xmName               // leeg = niets doen
        cmp #$ff
        bne op
        rts
op:     ldx #0                   // "0:NAAM,P,W" (PETSCII)
        lda #$30
        sta xmCmd
        lda #$3a
        sta xmCmd+1
        ldy #2
nm:     lda xmName,x
        cmp #$ff
        beq ne
        cmp #$1b                 // letters 1-26 -> PETSCII $41-$5A
        bcs nl
        ora #$40
nl:     sta xmCmd,y
        inx
        iny
        bne nm
ne:     ldx #0
tl:     lda xmTail,x
        sta xmCmd,y
        iny
        inx
        cpx #4
        bne tl
        sty xmCmdLen
        // eerst het opdrachtkanaal (blijft open: sluiten ervan sluit op de
        // 1541/1571 ALLE bestanden), dan het bestand, dan de status lezen
        jsr cfg_io_begin
        lda #0
        jsr K_SETNAM
        lda #15
        ldx #8
        ldy #15
        jsr K_SETLFS
        jsr K_OPEN
        lda xmCmdLen
        ldx #<xmCmd
        ldy #>xmCmd
        jsr K_SETNAM
        lda #XM_LFN
        ldx #8
        ldy #XM_LFN
        jsr K_SETLFS
        jsr K_OPEN
        ldx #15                  // "00, OK,00,00" / "63,FILE EXISTS,.."
        jsr K_CHKIN
        ldy #0
rs:     sty xmI
        jsr K_CHRIN
        ldy xmI
        cmp #$0d
        beq re
        jsr petscii2screen
        cpy #38
        bcs rn
        sta xmLine,y
        iny
rn:     lda $90
        beq rs
re:     lda #$ff
        sta xmLine,y
        jsr K_CLRCHN
        jsr cfg_io_end
        lda xmLine               // code < 20: goed
        cmp #$32
        bcc ok
        jsr xm_CloseFile
        ldx #<xmLine
        ldy #>xmLine
        jmp tm_Stat
ok:     lda #1
        sta xmOn
        sta xmCrc
        sta xmExp
        lda #0
        sta xmSt
        sta xmPkt
        sta xmHeld
        sta xmHeld+1
        sta xmBlocks
        sta xmBlocks+1
        sta xmTries
        jsr xm_Ask               // 'C'
        jmp xm_Show
}

// xm_Ask - om (de volgende poging van) het eerste blok vragen.
xm_Ask:
        lda #XM_C
        ldx xmCrc
        bne !+
        lda #XM_NAK
!:      jsr tm_TxPut
xm_Timer:
        lda frameLo
        sta xmT0
        rts

// xm_Byte - ontvangen databyte A (vanuit tm_Rx).
xm_Byte: {
        ldx xmPkt                // vorig pakket nog niet verwerkt
        bne r
        ldx frameLo              // er komt data: time-out opnieuw
        stx xmT0
        ldx xmSt
        bne st
        cmp #XM_EOT              // kop
        beq ev
        cmp #XM_CAN
        beq ev
        ldx #<[3+128]
        ldy #>[3+128]
        cmp #XM_SOH
        beq hd
        ldx #<[3+1024]
        ldy #>[3+1024]
        cmp #XM_STX
        bne r                    // (ruis tussen de blokken)
hd:     pha                      // (de kop hoort ook in het pakket)
        stx xmNeed
        sty xmNeed+1
        ldx xmCrc                // + 2 bytes CRC of 1 checksum
        inx
        txa
        clc
        adc xmNeed
        sta xmNeed
        bcc h1
        inc xmNeed+1
h1:     ldx #<XM_BUF
        stx wr+1
        ldx #>XM_BUF
        stx wr+2
        ldx #1
        stx xmSt
        pla
st:
wr:     sta $ffff
        inc wr+1
        bne w1
        inc wr+2
w1:     lda wr+1                 // alles binnen?
        sec
        sbc #<XM_BUF
        tax
        lda wr+2
        sbc #>XM_BUF
        cpx xmNeed
        bne r
        cmp xmNeed+1
        bne r
        lda #0
        sta xmSt
        inc xmPkt
r:      rts
ev:     sta XM_BUF               // EOT / CAN
        inc xmPkt
        rts
}

//--------------------------------------------------------
// xm_Tick - vanuit de terminal-lus: pakket verwerken of time-outs.
//--------------------------------------------------------
xm_Tick: {
        lda xmPkt
        bne proc
        lda frameLo              // hoe lang al stil?
        sec
        sbc xmT0
        ldx xmSt
        beq hw
        cmp #50                  // midden in een blok: 1 s -> NAK
        bcc r
        lda #0
        sta xmSt
        jmp nak
hw:     cmp #150                 // 3 s wachten op een blok
        bcc r
        inc xmTries
        lda xmTries
        cmp #10
        bcc rt
        ldx #<sXmNoAns
        ldy #>sXmNoAns
        jmp xm_Abort
rt:     lda xmBlocks             // nog geen blok: na 3x 'C' checksum
        ora xmBlocks+1
        bne nak
        lda xmTries
        cmp #3
        bne as
        lda #0
        sta xmCrc
as:     jmp xm_Ask
r:      rts
proc:   lda #0
        sta xmPkt
        jsr xm_Timer
        lda XM_BUF
        cmp #XM_EOT
        bne n1
        jmp xm_Eot
n1:     cmp #XM_CAN
        bne n2
        ldx #<sXmCan
        ldy #>sXmCan
        jmp xm_End
n2:     lda XM_BUF+1             // bloknummer + complement
        eor XM_BUF+2
        cmp #$ff
        bne nak
        jsr xm_Check             // CRC / checksum
        bne nak
        lda XM_BUF+1
        cmp xmExp
        beq new
        clc                      // het vorige nog eens: alleen bevestigen
        adc #1
        cmp xmExp
        beq ack
nak:    lda #XM_NAK
        jmp tm_TxPut
new:    jsr xm_WriteHeld         // vorig blok naar disk, dit bewaren
        bcs ok
        ldx #<sXmDisk
        ldy #>sXmDisk
        jmp xm_Abort
ok:     jsr xm_Keep
        inc xmExp
        inc xmBlocks
        bne s1
        inc xmBlocks+1
s1:     lda #0
        sta xmTries
        jsr xm_Show
ack:    lda #XM_ACK
        jmp tm_TxPut
}

// xm_Size - A/X = grootte van het blok in XM_BUF (128 of 1024).
xm_Size:
        lda XM_BUF
        cmp #XM_STX
        beq !+
        lda #128
        ldx #0
        rts
!:      lda #0
        ldx #4
        rts

// xm_Check - CRC-16 (poly $1021) of checksum over de data. Z=1 goed.
xm_Check: {
        jsr xm_Size
        sta xmN
        stx xmN+1
        lda #<[XM_BUF+3]
        sta xmP
        lda #>[XM_BUF+3]
        sta xmP+1
        lda #0
        sta xmCk
        sta xmCk+1
        ldy #0
lp:     lda xmN
        ora xmN+1
        beq end
        lda (xmP),y
        ldx xmCrc
        bne crc
        clc                      // checksum
        adc xmCk
        sta xmCk
        jmp nx
crc:    eor xmCk+1               // CRC: hoog byte ^= data, 8 schuiven
        sta xmCk+1
        ldx #8
b:      asl xmCk
        rol xmCk+1
        bcc b1
        lda xmCk+1
        eor #$10
        sta xmCk+1
        lda xmCk
        eor #$21
        sta xmCk
b1:     dex
        bne b
nx:     inc xmP
        bne n1
        inc xmP+1
n1:     lda xmN
        bne n2
        dec xmN+1
n2:     dec xmN
        jmp lp
end:    lda xmCrc                // (xmP wijst nu naar de controlebytes)
        bne ec
        lda (xmP),y
        cmp xmCk
        rts
ec:     lda (xmP),y
        cmp xmCk+1
        bne er
        iny
        lda (xmP),y
        cmp xmCk
er:     rts
}

// xm_Keep - data van dit blok naar XM_HOLD (wordt bij het volgende blok
//           of bij EOT geschreven).
xm_Keep: {
        jsr xm_Size
        sta xmHeld
        stx xmHeld+1
        ldy #0
        ldx #4                   // altijd 1 KB kopieren (eenvoudig)
lp:     lda XM_BUF+3,y
        sta XM_HOLD,y
        lda XM_BUF+3+$100,y
        sta XM_HOLD+$100,y
        lda XM_BUF+3+$200,y
        sta XM_HOLD+$200,y
        lda XM_BUF+3+$300,y
        sta XM_HOLD+$300,y
        iny
        bne lp
        rts
}

// xm_WriteHeld - bewaard blok (xmHeld bytes) naar het bestand. Carry=1 goed.
xm_WriteHeld: {
        lda xmHeld
        ora xmHeld+1
        bne go
        sec
        rts
go:     lda #<XM_HOLD
        sta xmP
        lda #>XM_HOLD
        sta xmP+1
        jsr cfg_io_begin
        ldx #XM_LFN
        jsr K_CHKOUT
        bcs f
        ldy #0
lp:     lda xmHeld
        ora xmHeld+1
        beq dn
        lda (xmP),y
        jsr K_CHROUT
        inc xmP
        bne l1
        inc xmP+1
l1:     lda xmHeld
        bne l2
        dec xmHeld+1
l2:     dec xmHeld
        jmp lp
dn:     jsr K_CLRCHN
        jsr cfg_io_end
        lda $90
        and #$83                 // time-out / apparaat weg
        bne f2
        sec
        rts
f:      jsr K_CLRCHN
        jsr cfg_io_end
f2:     clc
        rts
}

// xm_Eot - klaar: ACK, laatste blok zonder $1A-opvulling, bestand dicht.
xm_Eot: {
        lda #XM_ACK
        jsr tm_TxPut
        lda xmHeld               // opvulling eraf
        ora xmHeld+1
        beq wr
        lda #<XM_HOLD
        clc
        adc xmHeld
        sta xmP
        lda #>XM_HOLD
        adc xmHeld+1
        sta xmP+1
st:     lda xmP                  // xmP = einde; zolang de byte ervoor $1A is
        bne s1
        dec xmP+1
s1:     dec xmP
        ldy #0
        lda (xmP),y
        cmp #$1a
        bne wr
        lda xmHeld
        bne s2
        dec xmHeld+1
s2:     dec xmHeld
        lda xmHeld
        ora xmHeld+1
        bne st
wr:     jsr xm_WriteHeld
        ldx #<sXmDone
        ldy #>sXmDone
        jmp xm_End
}

// xm_Abort - CAN CAN CAN sturen, dan xm_End met melding X/Y.
xm_Abort:
        lda #XM_CAN
        jsr tm_TxPut
        jsr tm_TxPut
        jsr tm_TxPut
// xm_End - bestand dicht, download uit, melding X/Y + aantal blokken.
xm_End: {
        stx xmMsg
        sty xmMsg+1
        lda #0
        sta xmOn
        jsr xm_CloseFile
        lda xmMsg                // melding + " (12 BLOCKS)"
        sta xmP
        lda xmMsg+1
        sta xmP+1
        ldy #0
cp:     lda (xmP),y
        cmp #$ff
        beq ce
        sta xmLine,y
        iny
        bne cp
ce:     sty xmI
        jsr xm_Count
        ldx #<xmLine
        ldy #>xmLine
        jmp tm_Stat
}

xm_CloseFile:                    // bestand dicht, dan het opdrachtkanaal
        jsr cfg_io_begin
        lda #XM_LFN
        jsr K_CLOSE
        lda #15
        jsr K_CLOSE
        jmp cfg_io_end

// xm_Show - "XMODEM: 12 BLOCKS  RUN/STOP = CANCEL" op de statusregel.
xm_Show: {
        ldy #0
cp:     lda sXmRun,y
        cmp #$ff
        beq ce
        sta xmLine,y
        iny
        bne cp
ce:     sty xmI
        jsr xm_Count
        ldx #<xmLine
        ldy #>xmLine
        jmp tm_Stat
}

// xm_Count - " 12 BLOCKS" (xmBlocks decimaal) achter xmLine vanaf xmI.
xm_Count: {
        ldy xmI
        lda #$20
        sta xmLine,y
        iny
        lda xmBlocks
        sta xmN
        lda xmBlocks+1
        sta xmN+1
        ldx #0
        stx xmAny
dg:     lda #0
        sta xmDig
sb:     lda xmN
        sec
        sbc dLo,x
        pha
        lda xmN+1
        sbc dHi,x
        bcc nd
        sta xmN+1
        pla
        sta xmN
        inc xmDig
        bne sb
nd:     pla
        lda xmDig
        ora xmAny
        bne pr
        cpx #4
        bne nx
pr:     lda xmDig
        ora #$30
        sta xmLine,y
        iny
        inc xmAny
nx:     inx
        cpx #5
        bne dg
        ldx #0
bl:     lda sXmBlocks,x
        sta xmLine,y
        iny
        inx
        cmp #$ff
        bne bl
        rts
dLo:    .byte <10000, <1000, <100, <10, <1
dHi:    .byte >10000, >1000, >100, >10, >1
}

//--------------------------------------------------------
xmOn:     .byte 0
xmCrc:    .byte 1
xmExp:    .byte 1
xmSt:     .byte 0
xmPkt:    .byte 0
xmTries:  .byte 0
xmT0:     .byte 0
xmI:      .byte 0
xmAny:    .byte 0
xmDig:    .byte 0
xmCmdLen: .byte 0
xmNeed:   .word 0
xmN:      .word 0
xmCk:     .word 0
xmHeld:   .word 0
xmBlocks: .word 0
xmMsg:    .word 0
xmName:   .fill 17, $ff
xmCmd:    .fill 24, 0
xmLine:   .fill 41, $ff
.encoding "petscii_upper"
xmTail:   .text ",P,W"
.encoding "screencode_upper"
sXmName:  .text "SAVE AS:"
          .byte $ff
sXmRun:   .text "XMODEM (RUN/STOP=CANCEL):"
          .byte $ff
sXmBlocks: .text " BLOCKS"
          .byte $ff
sXmDone:  .text "DOWNLOAD COMPLETE,"
          .byte $ff
sXmCan:   .text "CANCELLED BY THE BBS,"
          .byte $ff
sXmStop:  .text "DOWNLOAD CANCELLED,"
          .byte $ff
sXmNoAns: .text "NO XMODEM FROM THE BBS,"
          .byte $ff
sXmDisk:  .text "DISK ERROR,"
          .byte $ff
