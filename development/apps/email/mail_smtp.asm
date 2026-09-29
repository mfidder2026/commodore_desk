#importonce
//========================================================
// apps/email/mail_smtp.asm - SMTP: het opgestelde bericht versturen
// Commodore Desk 64
//
// EHLO, AUTH PLAIN (base64 van \0gebruiker\0wachtwoord), MAIL FROM,
// RCPT TO, DATA. Het bericht (headers + tekst, CRLF, punt-verdubbeling)
// wordt eerst in SENDBUF gezet en dan in één keer verstuurd.
// Geen TLS: poort 587 (submission) of 25.
//========================================================

// sm_Line - regelverwerker: "250-..." loopt door, "250 ..." = klaar.
sm_Line: {
        lda mnCont
        bne r
        lda mnLine
        sta mnCode
        lda mnLen
        cmp #4
        bcc dn
        lda mnLine+3
        cmp #$2d
        beq r
dn:     lda #1
        sta mnDone
r:      rts
}

// sm_Cmd - opdracht sturen; carry=1 als het antwoord met A ('2'/'3')
//          begint. Anders X/Y = melding (sm_Err als het antwoord fout is).
sm_Cmd: {
        sta smWant
        jsr mn_Cmd
        bcc r
        lda mnCode
        cmp smWant
        beq ok
        ldx smErr
        ldy smErr+1
        clc
r:      rts
ok:     sec
        rts
}

// sm_Send - cpTo/cpSubj/CP_BODY versturen. Carry=1 gelukt, anders X/Y.
sm_Send: {
        lda #<sm_Line
        sta mnLineVec
        lda #>sm_Line
        sta mnLineVec+1
        ldx #<sEmConn
        ldy #>sEmConn
        jsr em_Progress
        lda #<mcSmtH             // SMTP-server (leeg: de POP3-server)
        sta r3
        lda #>mcSmtH
        sta r3+1
        lda mcSmtH
        cmp #$ff
        bne h
        lda #<mcPopH
        sta r3
        lda #>mcPopH
        sta r3+1
h:      lda #<mcSmtP
        sta r6
        lda #>mcSmtP
        sta r6+1
        jsr mn_Open
        bcs c
        rts
c:      lda #<sSmSrv
        sta smErr
        lda #>sSmSrv
        sta smErr+1
        jsr mn_Wait              // begroeting 220
        bcs fb4324_4
        jmp f
fb4324_4:
        lda mnCode
        cmp #$32
        beq fb4324_5
        jmp srv
fb4324_5:
        jsr mc_Start             // EHLO
        ldx #<aEhlo
        ldy #>aEhlo
        jsr mc_Str
        lda #$32
        jsr sm_Cmd
        bcs fb4324_6
        jmp f
fb4324_6:
        ldx #<sEmLogin
        ldy #>sEmLogin
        jsr em_Progress
        jsr sm_Auth
        lda #<sEmBadLogin
        sta smErr
        lda #>sEmBadLogin
        sta smErr+1
        lda #$32
        jsr sm_Cmd
        bcs fb4324_7
        jmp f
fb4324_7:
        lda #<sSmFrom
        sta smErr
        lda #>sSmFrom
        sta smErr+1
        jsr mc_Start             // MAIL FROM:<adres>
        ldx #<aFrom
        ldy #>aFrom
        jsr mc_Str
        ldx #<mcAddr
        ldy #>mcAddr
        jsr mc_Sc
        lda #$3e
        jsr mc_Chr
        lda #$32
        jsr sm_Cmd
        bcc f
        lda #<sSmRcpt
        sta smErr
        lda #>sSmRcpt
        sta smErr+1
        jsr mc_Start             // RCPT TO:<adres>
        ldx #<aRcpt
        ldy #>aRcpt
        jsr mc_Str
        ldx #<cpTo
        ldy #>cpTo
        jsr mc_Sc
        lda #$3e
        jsr mc_Chr
        lda #$32
        jsr sm_Cmd
        bcc f
        lda #<sSmData
        sta smErr
        lda #>sSmData
        sta smErr+1
        jsr mc_Start             // DATA -> 354
        ldx #<aData
        ldy #>aData
        jsr mc_Str
        lda #$33
        jsr sm_Cmd
        bcc f
        ldx #<sSmSend
        ldy #>sSmSend
        jsr em_Progress
        jsr sb_Build
        lda #0
        sta mnDone
        lda #<SENDBUF
        sta tcpDataPtr
        lda #>SENDBUF
        sta tcpDataPtr+1
        lda sbLen
        sta tcpDataLen
        lda sbLen+1
        sta tcpDataLen+1
        jsr mn_Send
        bcs sent
        ldx #<sMnLost
        ldy #>sMnLost
f:      jmp pp_Fail
srv:    ldx #<sSmSrv
        ldy #>sSmSrv
        jmp pp_Fail
sent:   jsr mn_Wait              // 250 = aangenomen
        bcc f
        lda mnCode
        cmp #$32
        beq ok
        ldx #<sSmData
        ldy #>sSmData
        jmp pp_Fail
ok:     jsr mc_Start
        ldx #<aQuit
        ldy #>aQuit
        jsr mc_Str
        lda #$32
        jsr sm_Cmd
        jsr mn_Close
        sec
        rts
}

// sm_Auth - "AUTH PLAIN " + base64(\0gebruiker\0wachtwoord) in mnCmd.
sm_Auth: {
        lda #0
        sta smN
        jsr put                  // \0
        jsr em_User
        jsr cp
        lda #0
        jsr put
        ldx #<mcPass
        ldy #>mcPass
        jsr cp
        jsr mc_Start
        ldx #<aAuth
        ldy #>aAuth
        jsr mc_Str
        lda #<smBuf
        sta r6
        lda #>smBuf
        sta r6+1
        lda smN
        jmp b64_Enc
cp:     stx r6                   // schermcodes ($ff) -> ASCII
        sty r6+1
        ldy #0
cl:     lda (r6),y
        cmp #$ff
        beq cr
        jsr sc2ascii
        jsr put
        iny
        bne cl
cr:     rts
put:    ldx smN
        sta smBuf,x
        inc smN
        rts
}

//--------------------------------------------------------
// sb_Build - headers + tekst in SENDBUF (sbLen bytes), eindigt op ".".
//--------------------------------------------------------
sb_Build: {
        lda #<SENDBUF
        sta r3
        lda #>SENDBUF
        sta r3+1
        lda #0
        sta sbLen
        sta sbLen+1
        ldx #<hFrom              // From: Naam <adres>
        ldy #>hFrom
        jsr sb_Str
        lda mcName
        cmp #$ff
        beq na
        ldx #<mcName
        ldy #>mcName
        jsr sb_Sc
        lda #$20
        jsr sb_Chr
        lda #$3c
        jsr sb_Chr
        ldx #<mcAddr
        ldy #>mcAddr
        jsr sb_Sc
        lda #$3e
        jsr sb_Chr
        jmp n2
na:     ldx #<mcAddr
        ldy #>mcAddr
        jsr sb_Sc
n2:     jsr sb_Crlf
        ldx #<hTo
        ldy #>hTo
        jsr sb_Str
        ldx #<cpTo
        ldy #>cpTo
        jsr sb_Sc
        jsr sb_Crlf
        ldx #<hSubj
        ldy #>hSubj
        jsr sb_Str
        ldx #<cpSubj
        ldy #>cpSubj
        jsr sb_Sc
        jsr sb_Crlf
        jsr sb_Date
        ldx #<hMime
        ldy #>hMime
        jsr sb_Str
        // tekst: tot en met de laatste niet-lege regel
        ldx #CP_LINES
        stx sbLast
fl:     dec sbLast
        bmi body
        lda sbLast
        jsr cp_Line              // r6 = regel, Y = lengte zonder spaties
        cpy #0
        beq fl
body:   inc sbLast               // aantal regels
        lda #0
        sta sbI
bl:     lda sbI
        cmp sbLast
        bcs end
        jsr cp_Line
        sty sbN
        ldy #0
        lda (r6),y
        cmp #$2e                 // "." vooraan -> ".."
        bne ch
        lda #$2e
        jsr sb_Chr
ch:     cpy sbN
        bcs le
        lda (r6),y
        jsr sc2ascii
        jsr sb_Chr
        iny
        bne ch
le:     jsr sb_Crlf
        inc sbI
        jmp bl
end:    lda #$2e                 // "." = einde
        jsr sb_Chr
        jmp sb_Crlf
}

// sb_Date - "Date: 27 Sep 2026 14:05:00 +0200" uit de CD64-klok.
sb_Date: {
        ldx #<hDate
        ldy #>hDate
        jsr sb_Str
        lda clkDay
        jsr sb_Bcd
        lda #$20
        jsr sb_Chr
        lda clkMon               // BCD -> 0-11
        cmp #$10
        bcc m
        sbc #6
m:      sec
        sbc #1
        sta smN
        asl
        adc smN                  // *3
        tax
        lda mon,x
        jsr sb_Chr
        lda mon+1,x
        jsr sb_Chr
        lda mon+2,x
        jsr sb_Chr
        lda #$20
        jsr sb_Chr
        lda clkYearHi
        jsr sb_Bcd
        lda clkYearLo
        jsr sb_Bcd
        lda #$20
        jsr sb_Chr
        lda clkHour
        jsr sb_Bcd
        lda #$3a
        jsr sb_Chr
        lda clkMin
        jsr sb_Bcd
        ldx #<tSec
        ldy #>tSec
        jsr sb_Str
        ldx #<mcTz
        ldy #>mcTz
        jsr sb_Sc
        jmp sb_Crlf
.encoding "ascii"
mon:    .text "JanFebMarAprMayJunJulAugSepOctNovDec"
tSec:   .text ":00 "
        .byte 0
.encoding "screencode_upper"
}

// sb_Bcd - BCD-byte A als twee cijfers.
sb_Bcd:
        pha
        lsr
        lsr
        lsr
        lsr
        ora #$30
        jsr sb_Chr
        pla
        and #$0f
        ora #$30
        jmp sb_Chr

sb_Crlf:
        lda #$0d
        jsr sb_Chr
        lda #$0a
// sb_Chr - byte A in SENDBUF (X/Y blijven). Vol: weggooien.
sb_Chr: {
        pha
        lda sbLen+1
        cmp #>[SEND_MAX-8]
        bcc ok
        lda sbLen
        cmp #<[SEND_MAX-8]
        bcc ok
        pla                      // (ruimte voor ".\r\n" blijft)
        rts
ok:     sty sbY
        ldy #0
        pla
        sta (r3),y
        inc r3
        bne n
        inc r3+1
n:      inc sbLen
        bne m
        inc sbLen+1
m:      ldy sbY
        rts
}

// sb_Str - ASCII (0-afgesloten) X/Y; sb_Sc - schermcodes ($ff) X/Y.
sb_Str: {
        stx r6
        sty r6+1
        ldy #0
lp:     lda (r6),y
        beq r
        jsr sb_Chr
        iny
        bne lp
r:      rts
}
sb_Sc: {
        stx r6
        sty r6+1
        ldy #0
lp:     lda (r6),y
        cmp #$ff
        beq r
        jsr sc2ascii
        jsr sb_Chr
        iny
        bne lp
r:      rts
}

//--------------------------------------------------------
smErr:  .word 0
sbLen:  .word 0
smWant: .byte 0
smN:    .byte 0
sbLast: .byte 0
sbI:    .byte 0
sbN:    .byte 0
sbY:    .byte 0

.encoding "ascii"
aEhlo:  .text "EHLO commodore-desk"
        .byte 0
aAuth:  .text "AUTH PLAIN "
        .byte 0
aFrom:  .text "MAIL FROM:<"
        .byte 0
aRcpt:  .text "RCPT TO:<"
        .byte 0
aData:  .text "DATA"
        .byte 0
hFrom:  .text "From: "
        .byte 0
hTo:    .text "To: "
        .byte 0
hSubj:  .text "Subject: "
        .byte 0
hDate:  .text "Date: "
        .byte 0
hMime:  .text "MIME-Version: 1.0"
        .byte 13, 10
        .text "Content-Type: text/plain; charset=us-ascii"
        .byte 13, 10
        .text "Content-Transfer-Encoding: 7bit"
        .byte 13, 10
        .text "X-Mailer: Commodore Desk 64"
        .byte 13, 10, 13, 10, 0
.encoding "screencode_upper"
sSmSrv:  .text "THE SMTP SERVER SAYS NO"
         .byte $ff
sSmFrom: .text "SENDER REFUSED (EMAIL ADDR)"
         .byte $ff
sSmRcpt: .text "RECIPIENT REFUSED"
         .byte $ff
sSmData: .text "THE SERVER REFUSED THE MESSAGE"
         .byte $ff
sSmSend: .text "SENDING..."
         .byte $ff
