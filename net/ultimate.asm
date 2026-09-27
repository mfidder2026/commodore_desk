#importonce
//========================================================
// net/ultimate.asm - TCP via het Ultimate Command Interface (UCI)
// Commodore Desk 64
//
// Op een Ultimate 64 / 1541 Ultimate-II+ doet de Ultimate zelf TCP/IP
// (en DNS). De C64 geeft opdrachten aan de "network target" ($03):
//   $07 open TCP   <poort LSB,MSB> <host> 0     -> handle
//   $10 read       <handle> <len LSB,MSB>       -> <aantal LE> <data>
//   $11 write      <handle> <data...>
//   $09 close      <handle>
//   $05 get IP     <interface>                  -> ip, mask, gw
// De statustekst begint met een code: 00 = goed/data, 01 = de andere
// kant heeft gesloten (eenmalig), 02 = nog geen data.
//
// Grenzen (gemeten op echte hardware, ultimate-uci-sdk): lees hoogstens
// 512 bytes per keer (769-1023 laat het netwerk vastlopen), een opdracht
// is hoogstens 895 bytes, en het control-register nooit lezen-wijzigen-
// schrijven. Niet te testen in VICE (geen UCI-emulatie).
//========================================================

.label UC_CTRL = $df1c           // schrijven: control, lezen: status
.label UC_CMD  = $df1d           // opdrachtbytes
.label UC_RESP = $df1e           // antwoorddata
.label UC_STAT = $df1f           // statustekst
.const UC_PUSH   = $01           // control
.const UC_ACC    = $02
.const UC_ABORT  = $04
.const UC_CLRERR = $08
.const UC_STATE  = $30           // status: 00 idle, 10 busy, 20 last, 30 more
.const UC_BUSY   = $10
.const UC_ERROR  = $08
.const UC_STATAV = $40
.const UC_DATAAV = $80
.const UT_READ   = 512           // max. per leesopdracht
.const UT_CHUNK  = 512           // max. data per schrijfopdracht
.const UC_RESPMAX = 600          // antwoordbuffer (NET_RXBUF)

// -----------------------------------------------------
// uc_Exec - opdracht ucCmd (ucHdr bytes) + optioneel ucDataLen bytes
//           vanaf ucDataPtr uitvoeren. Antwoord in NET_RXBUF (ucResp
//           bytes), statustekst in ucStat, code in ucCode.
//           Uit: carry=1 uitgevoerd, carry=0 time-out/fout.
// -----------------------------------------------------
uc_Exec: {
        lda #100                 // wachten op idle (2 s)
        ldx #0
        jsr ucTimer
wi:     lda UC_CTRL
        and #UC_STATE
        beq idle
        jsr ucTimeout
        bcc wi
        jmp fail
idle:   ldx #0                   // opdrachtkop
hd:     lda ucCmd,x
        sta UC_CMD
        inx
        cpx ucHdr
        bne hd
        lda ucDataLen            // data erachter
        ora ucDataLen+1
        beq push
        lda ucDataPtr
        sta netPtr
        lda ucDataPtr+1
        sta netPtr+1
        lda ucDataLen
        sta ucCnt
        lda ucDataLen+1
        sta ucCnt+1
        ldy #0
dl:     lda (netPtr),y
        sta UC_CMD
        inc netPtr
        bne d1
        inc netPtr+1
d1:     lda ucCnt
        bne d2
        dec ucCnt+1
d2:     dec ucCnt
        lda ucCnt
        ora ucCnt+1
        bne dl
push:   lda #UC_PUSH
        sta UC_CTRL
        lda UC_CTRL
        and #UC_ERROR
        beq ok
        lda #UC_CLRERR           // gepusht terwijl niet idle
        sta UC_CTRL
        jmp fail
ok:     lda #0
        sta ucResp
        sta ucResp+1
        sta ucStatN
        lda #<NET_RXBUF
        sta ck2
        lda #>NET_RXBUF
        sta ck2+1
wait:   lda #<500                // wachten tot niet meer busy (10 s)
        ldx #>500
        jsr ucTimer
wb:     lda UC_CTRL
        and #UC_STATE
        cmp #UC_BUSY
        bne data
        jsr ucTimeout
        bcc wb
        jmp fail
data:   lda UC_CTRL              // antwoord lezen
        bpl stat
        lda UC_RESP
        ldy ucResp+1             // niet voorbij de buffer
        cpy #>UC_RESPMAX
        bcc st
        ldy ucResp
        cpy #<UC_RESPMAX
        bcs skip
st:     ldy #0
        sta (ck2),y
        inc ck2
        bne sk
        inc ck2+1
sk:     inc ucResp
        bne data
        inc ucResp+1
        jmp data
skip:   jmp data
stat:   lda UC_CTRL              // statustekst lezen
        and #UC_STATAV
        beq acc
        lda UC_STAT
        ldx ucStatN
        cpx #31
        bcs stat
        sta ucStat,x
        inc ucStatN
        jmp stat
acc:    ldx ucStatN
        lda #0
        sta ucStat,x
        lda #UC_ACC              // blok vrijgeven
        sta UC_CTRL
        lda #50
        ldx #0
        jsr ucTimer
wa:     lda UC_CTRL
        and #UC_ACC
        beq accd
        jsr ucTimeout
        bcc wa
        jmp fail
accd:   lda UC_CTRL              // nog een blok (data-more)?
        and #UC_STATE
        beq code
        jmp wait
code:   lda #$ff                 // code = eerste twee cijfers
        sta ucCode
        lda ucStatN
        cmp #2
        bcc done
        lda ucStat
        sec
        sbc #$30
        cmp #10
        bcs done
        sta ucCode
        asl                      // *10
        asl
        adc ucCode
        asl
        sta ucCode
        lda ucStat+1
        sec
        sbc #$30
        cmp #10
        bcs done
        clc
        adc ucCode
        sta ucCode
done:   jsr lg_Uci
        sec
        rts
fail:   lda #UC_ABORT
        sta UC_CTRL
        jsr lg_UciFail
        clc
        rts
}

// ucTimer - time-out over A (lo) / X (hi) beelden (16-bit frameteller).
ucTimer:
        clc
        adc frameLo
        sta ucEnd
        txa
        adc frameHi
        sta ucEnd+1
        rts
// ucTimeout - carry=1 als de tijd om is.
ucTimeout:
        lda frameLo
        sec
        sbc ucEnd
        lda frameHi
        sbc ucEnd+1
        bmi !no+
        sec
        rts
!no:    clc
        rts

// -----------------------------------------------------
// ut_Connect - TCP naar NC_HOST (IP of naam; de Ultimate lost namen
//              zelf op) op poort tcpRPort. Uit: carry=1 -> utSock.
// -----------------------------------------------------
ut_Connect: {
        lda #$03
        sta ucCmd
        lda #$07
        sta ucCmd+1
        lda tcpRPort+1           // poort LSB, MSB (tcpRPort is big-endian)
        sta ucCmd+2
        lda tcpRPort
        sta ucCmd+3
        ldx #0
        ldy #4
hl:     lda NC_HOST,x
        cmp #$ff
        beq he
        jsr sc2ascii
        sta ucCmd,y
        iny
        inx
        cpx #32
        bne hl
he:     lda #0
        sta ucCmd,y
        iny
        sty ucHdr
        lda #0
        sta ucDataLen
        sta ucDataLen+1
        sta utOpen
        jsr uc_Exec
        bcc fail
        lda ucCode
        bne fail
        lda ucResp               // handle in het eerste antwoordbyte
        ora ucResp+1
        beq fail
        lda NET_RXBUF
        sta utSock
        lda #1
        sta utOpen
        sec
        rts
fail:   clc
        rts
}

// ut_Write - tcpDataLen bytes vanaf tcpDataPtr sturen (per 512).
ut_Write: {
        lda tcpDataPtr
        sta ucDataPtr
        lda tcpDataPtr+1
        sta ucDataPtr+1
        lda tcpDataLen
        sta utLeft
        lda tcpDataLen+1
        sta utLeft+1
lp:     lda utLeft
        ora utLeft+1
        bne more
        sec
        rts
more:   lda utLeft+1             // stuk = min(rest, 512)
        cmp #>UT_CHUNK
        bcc small
        lda #<UT_CHUNK
        sta ucDataLen
        lda #>UT_CHUNK
        sta ucDataLen+1
        jmp go
small:  lda utLeft
        sta ucDataLen
        lda utLeft+1
        sta ucDataLen+1
go:     lda #$03
        sta ucCmd
        lda #$11
        sta ucCmd+1
        lda utSock
        sta ucCmd+2
        lda #3
        sta ucHdr
        jsr uc_Exec
        bcc fail
        lda ucCode
        bne fail
        clc                      // ptr += stuk, rest -= stuk
        lda ucDataPtr
        adc ucDataLen
        sta ucDataPtr
        lda ucDataPtr+1
        adc ucDataLen+1
        sta ucDataPtr+1
        sec
        lda utLeft
        sbc ucDataLen
        sta utLeft
        lda utLeft+1
        sbc ucDataLen+1
        sta utLeft+1
        jmp lp
fail:   clc
        rts
}

// -----------------------------------------------------
// ut_Read - één keer lezen; data gaat byte voor byte naar tcpRxVec.
//           Uit: A = 0 data, 1 gesloten, 2 nog niets, $ff fout.
// -----------------------------------------------------
ut_Read: {
        lda #$03
        sta ucCmd
        lda #$10
        sta ucCmd+1
        lda utSock
        sta ucCmd+2
        lda #<UT_READ
        sta ucCmd+3
        lda #>UT_READ
        sta ucCmd+4
        lda #5
        sta ucHdr
        lda #0
        sta ucDataLen
        sta ucDataLen+1
        jsr uc_Exec
        bcs ex
        lda #$ff
        rts
ex:     lda ucCode
        cmp #1
        bne nc
        lda #0                   // gesloten: de firmware heeft de handle
        sta utOpen               // al vrijgegeven (niet meer sluiten)
        lda #1
        rts
nc:     cmp #0
        beq have
        lda #2                   // 02 (of onbekend): nog niets
        rts
have:   lda NET_RXBUF            // aantal (LE); $FFFF = nog niets
        sta utCnt
        lda NET_RXBUF+1
        sta utCnt+1
        and utCnt
        cmp #$ff
        beq none
        lda utCnt
        ora utCnt+1
        beq none
        lda #<[NET_RXBUF+2]
        sta utP
        lda #>[NET_RXBUF+2]
        sta utP+1
dl:     lda utP                  // (de callback mag netPtr gebruiken)
        sta netPtr
        lda utP+1
        sta netPtr+1
        ldy #0
        lda (netPtr),y
        jsr deliver
        inc utP
        bne d1
        inc utP+1
d1:     lda utCnt
        bne d2
        dec utCnt+1
d2:     dec utCnt
        lda utCnt
        ora utCnt+1
        bne dl
        lda #0
        rts
none:   lda #2
        rts
deliver:
        jmp (tcpRxVec)
}

// ut_Close - handle sluiten (niet na "01": die is al vrijgegeven).
ut_Close:
        lda utOpen
        beq !r+
        lda #$03
        sta ucCmd
        lda #$09
        sta ucCmd+1
        lda utSock
        sta ucCmd+2
        lda #3
        sta ucHdr
        lda #0
        sta ucDataLen
        sta ucDataLen+1
        sta utOpen
        jmp uc_Exec
!r:     rts

// ut_GetIp - IP-configuratie van de Ultimate (interface 0) -> utIp.
//            Carry=1 gelukt.
ut_GetIp: {
        lda #$03
        sta ucCmd
        lda #$05
        sta ucCmd+1
        lda #0
        sta ucCmd+2
        sta ucDataLen
        sta ucDataLen+1
        lda #3
        sta ucHdr
        jsr uc_Exec
        bcc fail
        lda ucCode
        bne fail
        lda ucResp
        cmp #4
        bcc fail
        ldx #3
cp:     lda NET_RXBUF,x
        sta utIp,x
        dex
        bpl cp
        sec
        rts
fail:   clc
        rts
}

//--------------------------------------------------------
ucCmd:     .fill 40, 0           // opdrachtkop (max. 4 + host 32 + 0)
ucHdr:     .byte 0
ucDataPtr: .word 0
ucDataLen: .word 0
ucCnt:     .word 0
ucResp:    .word 0               // aantal antwoordbytes
ucStat:    .fill 32, 0           // statustekst (0-afgesloten)
ucStatN:   .byte 0
ucCode:    .byte 0               // 0-99 uit de statustekst, $ff = geen
ucEnd:     .word 0
utSock:    .byte 0
utOpen:    .byte 0
utLeft:    .word 0
utCnt:     .word 0
utP:       .word 0
utIp:      .fill 4, 0
