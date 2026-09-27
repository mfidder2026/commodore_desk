#importonce
//========================================================
// apps/email/mail_pop.asm - POP3: postvak ophalen en een bericht lezen
// Commodore Desk 64
//
// Berichten blijven op de server (geen DELE). pp_Fetch haalt van de
// nieuwste MB_MAX berichten alleen de headers (TOP n 0); pp_Read haalt
// één bericht (RETR n) en zet de tekst in MSGBUF:
//   - MIME multipart: het eerste text/*-deel (ook genest, bv.
//     multipart/alternative in multipart/mixed); text/html zonder tags
//   - quoted-printable en base64 worden gedecodeerd, UTF-8 -> letters
//   - is de tekst binnen (of MSGBUF vol) dan stopt het downloaden
//     (verbinding dicht, bijlagen worden niet opgehaald)
//========================================================

// pp_Line - regelverwerker (mnLineVec) voor POP3.
pp_Line: {
        lda ppMode
        cmp #PM_DATA
        beq data
        lda mnCont               // statusregel: alleen het begin telt
        bne r
        lda mnLine
        cmp #$2b                 // +OK
        beq ok
        lda #0
        sta mnOk
        jmp dn
ok:     lda #1
        sta mnOk
        lda ppMode
        cmp #PM_MULTI
        bne st
        lda #PM_DATA             // multi-line: nu de data
        sta ppMode
        rts
st:     jsr pp_Stat
dn:     lda #1
        sta mnDone
r:      rts
data:   lda mnCont
        bne dv
        lda mnLine
        cmp #$2e                 // "." = einde, ".." = een punt
        bne dv
        lda mnLen
        cmp #1
        bne stuff
        lda mnPart
        bne stuff
        lda #1
        sta mnDone
        rts
stuff:  inc mnOff
dv:     jmp (ppDataVec)
}

// pp_Stat - "+OK n ..." -> ppCount.
pp_Stat: {
        lda #0
        sta ppCount
        sta ppCount+1
        ldy #4
lp:     cpy mnLen
        bcs r
        lda mnLine,y
        cmp #$30
        bcc r
        cmp #$3a
        bcs r
        and #$0f
        pha
        lda ppCount              // *10
        ldx ppCount+1
        asl ppCount
        rol ppCount+1
        asl ppCount
        rol ppCount+1
        clc
        adc ppCount
        sta ppCount
        txa
        adc ppCount+1
        sta ppCount+1
        asl ppCount
        rol ppCount+1
        pla
        clc
        adc ppCount
        sta ppCount
        bcc nc
        inc ppCount+1
nc:     iny
        bne lp
r:      rts
}

pp_Cmd:
        lda #PM_SINGLE
        sta ppMode
        jmp mn_Cmd
pp_CmdMulti:
        lda #PM_MULTI
        sta ppMode
        jmp mn_Cmd

// pp_Fail - verbinding dicht, melding X/Y teruggeven (carry=0).
pp_Fail:
        stx ppErr
        sty ppErr+1
        jsr mn_Close
        ldx ppErr
        ldy ppErr+1
        clc
        rts

// pp_Open - verbinden met de POP3-server en inloggen (USER/PASS).
//           Carry=1 gelukt, anders X/Y melding.
pp_Open: {
        lda #<pp_Line            // (de begroeting kan al tijdens het
        sta mnLineVec            //  verbinden binnenkomen)
        lda #>pp_Line
        sta mnLineVec+1
        lda #PM_SINGLE
        sta ppMode
        lda #0
        sta ppAbort
        ldx #<sEmConn
        ldy #>sEmConn
        jsr em_Progress
        lda #<mcPopH
        sta r3
        lda #>mcPopH
        sta r3+1
        lda #<mcPopP
        sta r6
        lda #>mcPopP
        sta r6+1
        jsr mn_Open
        bcs c
        rts
c:      jsr mn_Wait              // begroeting "+OK"
        bcc f
        lda mnOk
        beq srv
        ldx #<sEmLogin
        ldy #>sEmLogin
        jsr em_Progress
        jsr mc_Start
        ldx #<aUser
        ldy #>aUser
        jsr mc_Str
        jsr em_User
        jsr mc_Sc
        jsr pp_Cmd
        bcc f
        lda mnOk
        beq bad
        jsr mc_Start
        ldx #<aPass
        ldy #>aPass
        jsr mc_Str
        ldx #<mcPass
        ldy #>mcPass
        jsr mc_Sc
        jsr pp_Cmd
        bcc f
        lda mnOk
        beq bad
        sec
        rts
srv:    ldx #<sEmSrv
        ldy #>sEmSrv
        jmp pp_Fail
bad:    ldx #<sEmBadLogin
        ldy #>sEmBadLogin
f:      jmp pp_Fail
}

// em_User - X/Y = gebruikersnaam (leeg: het e-mailadres).
em_User:
        ldx #<mcUser
        ldy #>mcUser
        lda mcUser
        cmp #$ff
        bne !+
        ldx #<mcAddr
        ldy #>mcAddr
!:      rts

// pp_Quit - QUIT en verbinding dicht.
pp_Quit:
        jsr mc_Start
        ldx #<aQuit
        ldy #>aQuit
        jsr mc_Str
        jsr pp_Cmd
        jmp mn_Close

//--------------------------------------------------------
// pp_Fetch - postvak: headers van de nieuwste MB_MAX berichten.
//            Carry=1 gelukt (mbCount), anders X/Y melding.
//--------------------------------------------------------
pp_Fetch: {
        lda #0
        sta mbCount
        jsr pp_Open
        bcs o
        rts
o:      jsr mc_Start
        ldx #<aStat
        ldy #>aStat
        jsr mc_Str
        jsr pp_Cmd
        bcc f
        lda mnOk
        bne s
        ldx #<sEmSrv
        ldy #>sEmSrv
f:      jmp pp_Fail
s:      lda ppCount
        sta ppNum
        sta mbTotal
        lda ppCount+1
        sta ppNum+1
        sta mbTotal+1
        lda #<MB_BASE
        sta ppSlot
        lda #>MB_BASE
        sta ppSlot+1
lp:     lda ppNum
        ora ppNum+1
        beq done
        lda mbCount
        cmp #MB_MAX
        bcs done
        ldx #<sEmHdrs            // "READING MESSAGE LIST..."
        ldy #>sEmHdrs
        jsr em_Progress
        jsr hv_Clear
        lda #$ff
        sta ppHdrCur
        lda #0
        sta ppHdrEnd
        lda #<pp_Hdr
        sta ppDataVec
        lda #>pp_Hdr
        sta ppDataVec+1
        jsr mc_Start             // TOP n 0
        ldx #<aTop
        ldy #>aTop
        jsr mc_Str
        lda ppNum
        sta mnNum
        lda ppNum+1
        sta mnNum+1
        jsr mc_Dec
        ldx #<aTop0
        ldy #>aTop0
        jsr mc_Str
        jsr pp_CmdMulti
        bcc f
        lda mnOk
        beq nx
        jsr pp_Slot              // headers -> record
        inc mbCount
        lda ppSlot
        clc
        adc #MB_REC
        sta ppSlot
        bcc nx
        inc ppSlot+1
nx:     lda ppNum                // vorige (oudere) bericht
        bne d1
        dec ppNum+1
d1:     dec ppNum
        jmp lp
done:   jsr pp_Quit
        sec
        rts
}

// pp_Hdr - headerregels van TOP (alleen From/Subject zijn nodig).
pp_Hdr: {
        lda ppHdrEnd
        bne r
        lda mnCont
        bne fold
        ldy mnOff
        cpy mnLen
        beq end
        lda mnLine,y
        cmp #$20
        beq fold
        cmp #$09
        beq fold
        jsr hd_Name
        stx ppHdrCur
        cpx #HV_SUBJ+1
        bcs r
        jmp hv_Append
fold:   ldx ppHdrCur
        cpx #HV_SUBJ+1
        bcs r
        jmp hv_Append
end:    lda #1
        sta ppHdrEnd
r:      rts
}

// pp_Slot - From/Subject naar het record op ppSlot (+ berichtnummer).
pp_Slot: {
        ldy #MB_NUM
        lda ppSlot
        sta r3
        lda ppSlot+1
        sta r3+1
        lda ppNum
        sta (r3),y
        iny
        lda ppNum+1
        sta (r3),y
        jsr fr_Split
        lda frNa
        sta hvA
        lda frNb
        sta hvB
        lda r3
        clc
        adc #MB_FROM
        sta r6
        lda r3+1
        adc #0
        sta r6+1
        ldx #HV_FROM
        lda #MB_FROMMAX
        jsr hv_Render
        ldx #HV_SUBJ
        jsr hv_Range
        lda r3
        clc
        adc #MB_SUBJ
        sta r6
        lda r3+1
        adc #0
        sta r6+1
        ldx #HV_SUBJ
        lda #MB_SUBJMAX
        jmp hv_Render
}

// hd_Name - headernaam vanaf mnOff? X = 0 From, 1 Subject, 2 Date,
//           3 Content-Type, 4 Content-Transfer-Encoding, $ff anders.
//           mnOff staat daarna achter de dubbele punt.
hd_Name: {
        ldx #0
nx:     stx hnI
        lda hnLo,x
        sta r6
        lda hnHi,x
        sta r6+1
        ldy #0
cm:     lda (r6),y
        beq match
        tya
        clc
        adc mnOff
        tax
        cpx mnLen
        bcs no
        lda mnLine,x
        ora #$20
        cmp (r6),y
        bne no
        iny
        bne cm
match:  tya
        clc
        adc mnOff
        sta mnOff
        ldx hnI
        rts
no:     ldx hnI
        inx
        cpx #5
        bne nx
        ldx #$ff
        rts
}

//--------------------------------------------------------
// pp_Read - bericht mbSel lezen (RETR) -> MSGBUF + rdFrom/rdAddr/
//           rdSubj/rdDate. Carry=1 gelukt, anders X/Y melding.
//--------------------------------------------------------
pp_Read: {
        jsr pp_Open
        bcs o
        rts
o:      jsr hv_Clear
        jsr tw_Reset
        lda #MS_HDR
        sta mmState
        lda #0
        sta mmMulti
        sta mmEnc
        lda #$ff
        sta ppHdrCur
        lda #<rd_Data
        sta ppDataVec
        lda #>rd_Data
        sta ppDataVec+1
        ldx #<sEmLoad
        ldy #>sEmLoad
        jsr em_Progress
        jsr mc_Start
        ldx #<aRetr
        ldy #>aRetr
        jsr mc_Str
        jsr mb_Ptr               // r3 = record mbSel
        ldy #MB_NUM
        lda (r3),y
        sta mnNum
        iny
        lda (r3),y
        sta mnNum+1
        jsr mc_Dec
        jsr pp_CmdMulti
        bcc f
        lda mnOk
        bne ok
        ldx #<sEmGone
        ldy #>sEmGone
f:      jmp pp_Fail
ok:     lda ppAbort              // tekst compleet: niet alles downloaden
        beq q
        jsr mn_Close
        jmp fin
q:      jsr pp_Quit
fin:    jsr tw_End
        jsr rd_Headers
        sec
        rts
}

// rd_Headers - From/Subject/Date naar de leesvelden.
rd_Headers: {
        jsr fr_Split
        lda frNa
        sta hvA
        lda frNb
        sta hvB
        lda #<rdFrom
        sta r6
        lda #>rdFrom
        sta r6+1
        ldx #HV_FROM
        lda #30
        jsr hv_Render
        ldx frAa                 // adres als ASCII (voor REPLY)
        ldy #0
ac:     cpx frAb
        bcs ae
        cpy #60
        bcs ae
        lda hvBuf0,x
        cmp #$20
        beq an
        sta rdAddr,y
        iny
an:     inx
        bne ac
ae:     lda #0
        sta rdAddr,y
        ldx #HV_SUBJ
        jsr hv_Range
        lda #<rdSubj
        sta r6
        lda #>rdSubj
        sta r6+1
        ldx #HV_SUBJ
        lda #36
        jsr hv_Render
        ldx #HV_DATE
        jsr hv_Range
        lda #<rdDate
        sta r6
        lda #>rdDate
        sta r6+1
        ldx #HV_DATE
        lda #30
        jsr hv_Render
        lda twLine
        sta rdLines
        lda #0
        sta rdTop
        rts
}

// rd_Data - dataregels van RETR: headers, MIME, tekst.
rd_Data: {
        lda mmState
        cmp #MS_HDR
        beq hdr
        cmp #MS_PHDR
        beq hdr
        cmp #MS_SEEK
        beq seek
        cmp #MS_BODY
        beq body
ab:     lda #1                   // klaar: niet verder downloaden
        sta ppAbort
        sta mnDone
        rts
hdr:    jmp rh_Line
seek:   lda mnCont
        bne r
        jsr is_Bnd
        bcc r
        lda #MS_PHDR             // nieuw deel: eigen headers
        sta mmState
        lda #0
        sta hvLens+HV_CT
        sta mmEnc
        lda #$ff
        sta ppHdrCur
r:      rts
body:   lda twFull
        bne ab
        lda mmMulti
        beq bd
        lda mnCont
        bne bd
        jsr is_Bnd
        bcc bd
        lda #MS_SKIP             // einde van het tekstdeel
        sta mmState
        jmp ab
bd:     jmp rd_Body
}

// is_Bnd - begint de regel met "--" + boundary? Carry=1 ja.
is_Bnd: {
        ldx mnOff
        lda mnLine,x
        cmp #$2d
        bne no
        lda mnLine+1,x
        cmp #$2d
        bne no
        inx
        inx
        ldy #0
lp:     cpy mmBndLen
        bcs yes
        cpx mnLen
        bcs no
        lda mnLine,x
        cmp mmBnd,y
        bne no
        inx
        iny
        bne lp
yes:    sec
        rts
no:     clc
        rts
}

// rh_Line - headerregel (bericht of deel).
rh_Line: {
        lda mnCont
        bne fold
        ldy mnOff
        cpy mnLen
        beq end
        lda mnLine,y
        cmp #$20
        beq fold
        cmp #$09
        beq fold
        jsr hd_Name
        stx ppHdrCur
        cpx #$ff
        beq r
        cpx #4
        beq cte
        lda mmState              // in een deel telt alleen Content-Type
        cmp #MS_PHDR
        bne ap
        cpx #HV_CT
        beq ap
        lda #$ff
        sta ppHdrCur
        rts
ap:     jmp hv_Append
fold:   ldx ppHdrCur
        cpx #4
        bcs r
        jmp hv_Append
end:    jmp rh_End
cte:    lda #$ff
        sta ppHdrCur
        ldy mnOff
sp:     cpy mnLen
        bcs r
        lda mnLine,y
        iny
        cmp #$21
        bcc sp
        ora #$20
        ldx #ENC_QP
        cmp #$71                 // q(uoted-printable)
        beq se
        ldx #ENC_B64
        cmp #$62                 // b(ase64)
        beq se
        ldx #ENC_PLAIN
se:     stx mmEnc
r:      rts
}

// rh_End - einde van de headers: multipart? tekst? welk deel tonen?
rh_End: {
        ldx #<cMulti
        ldy #>cMulti
        jsr ci_Find
        bcc nm
        ldx #<cBnd
        ldy #>cBnd
        jsr ci_Find
        bcs fb4324_3
        jmp sk
fb4324_3:
        ldx hvI                  // boundary kopiëren (evt. tussen "")
        lda #0
        sta ppQ
        lda hvBuf3,x
        cmp #$22
        bne bs
        inc ppQ
        inx
bs:     ldy #0
bl:     cpx hvLens+HV_CT
        bcs be
        lda hvBuf3,x
        pha
        lda ppQ
        beq nq
        pla                      // tussen "": tot het slot-"
        cmp #$22
        beq be
        jmp bc
nq:     pla                      // zonder "": tot ; of spatie
        cmp #$3b
        beq be
        cmp #$21
        bcc be
bc:     sta mmBnd,y
        inx
        iny
        cpy #70
        bcc bl
be:     sty mmBndLen
        lda #1
        sta mmMulti
        lda #MS_SEEK
        sta mmState
        rts
nm:     lda hvLens+HV_CT         // geen Content-Type = text/plain
        beq txt
        ldx #<cText
        ldy #>cText
        jsr ci_Find
        bcc notx
txt:    ldx #<cHtml
        ldy #>cHtml
        jsr ci_Find
        lda #0
        rol
        sta twHtml
        lda mmEnc
        sta mmBodyEnc
        jsr b64_Reset
        lda #<tw_Byte
        sta b64Vec
        lda #>tw_Byte
        sta b64Vec+1
        lda #MS_BODY
        sta mmState
        rts
notx:   lda mmMulti              // ander deel (bijlage e.d.): volgende
        beq sk
        lda #MS_SEEK
        sta mmState
        rts
sk:     lda #MS_SKIP
        sta mmState
        rts
}

// rd_Body - één (stuk van een) tekstregel decoderen naar tw_Byte.
rd_Body: {
        ldy mnOff
        lda mmBodyEnc
        cmp #ENC_B64
        beq b64
        cmp #ENC_QP
        beq qp
pl:     cpy mnLen                // gewone tekst
        bcs pe
        lda mnLine,y
        sty rdY
        jsr tw_Byte
        ldy rdY
        iny
        bne pl
pe:     lda mnPart
        bne r
        lda #$0a
        jmp tw_Byte
b64:    cpy mnLen
        bcs r
        lda mnLine,y
        sty rdY
        jsr b64_Char
        ldy rdY
        iny
        bne b64
r:      rts
qp:     cpy mnLen                // quoted-printable
        bcs pe
        lda mnLine,y
        cmp #$3d
        bne qo
        iny
        cpy mnLen
        bcs r                    // "=" aan het eind: zachte regelafbreking
        lda mnLine,y
        jsr hexVal
        bcc qb
        asl
        asl
        asl
        asl
        sta rdT
        lda mnLine+1,y
        jsr hexVal
        bcc qb
        ora rdT
        iny
        jmp qo
qb:     dey
        lda #$3d
qo:     sty rdY
        jsr tw_Byte
        ldy rdY
        iny
        jmp qp
}

// mb_Ptr - r3 = record mbSel.
mb_Ptr: {
        lda #<MB_BASE
        sta r3
        lda #>MB_BASE
        sta r3+1
        ldx mbSel
        beq r
lp:     lda r3
        clc
        adc #MB_REC
        sta r3
        bcc nc
        inc r3+1
nc:     dex
        bne lp
r:      rts
}

//--------------------------------------------------------
.align 2
ppDataVec: .word 0
ppCount:  .word 0
ppNum:    .word 0
ppSlot:   .word 0
ppErr:    .word 0
mbTotal:  .word 0
ppMode:   .byte 0
ppAbort:  .byte 0
ppHdrCur: .byte 0
ppHdrEnd: .byte 0
ppQ:      .byte 0
hnI:      .byte 0
mbCount:  .byte 0
mbSel:    .byte 0
mmState:  .byte 0
mmMulti:  .byte 0
mmEnc:    .byte 0
mmBodyEnc: .byte 0
mmBndLen: .byte 0
rdY:      .byte 0
rdT:      .byte 0
rdLines:  .byte 0
rdTop:    .byte 0

hnLo:   .byte <hnFrom, <hnSubj, <hnDate, <hnCt, <hnCte
hnHi:   .byte >hnFrom, >hnSubj, >hnDate, >hnCt, >hnCte
.encoding "ascii"
hnFrom: .text "from:"
        .byte 0
hnSubj: .text "subject:"
        .byte 0
hnDate: .text "date:"
        .byte 0
hnCt:   .text "content-type:"
        .byte 0
hnCte:  .text "content-transfer-encoding:"
        .byte 0
cMulti: .text "multipart/"
        .byte 0
cBnd:   .text "boundary="
        .byte 0
cText:  .text "text/"
        .byte 0
cHtml:  .text "text/html"
        .byte 0
aUser:  .text "USER "
        .byte 0
aPass:  .text "PASS "
        .byte 0
aStat:  .text "STAT"
        .byte 0
aTop:   .text "TOP "
        .byte 0
aTop0:  .text " 0"
        .byte 0
aRetr:  .text "RETR "
        .byte 0
aQuit:  .text "QUIT"
        .byte 0
.encoding "screencode_upper"
sEmConn:     .text "CONNECTING..."
             .byte $ff
sEmLogin:    .text "LOGGING IN..."
             .byte $ff
sEmHdrs:     .text "READING THE MESSAGE LIST..."
             .byte $ff
sEmLoad:     .text "LOADING THE MESSAGE..."
             .byte $ff
sEmSrv:      .text "THE MAIL SERVER SAYS NO"
             .byte $ff
sEmBadLogin: .text "LOGIN FAILED (USER/PASSWORD)"
             .byte $ff
sEmGone:     .text "MESSAGE NOT FOUND - FETCH AGAIN"
             .byte $ff
