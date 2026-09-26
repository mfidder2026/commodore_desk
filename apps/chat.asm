#importonce
//========================================================
// apps/chat.asm - CHAT (INET-menu): OpenAI-compatibele AI-chat
// Commodore Desk 64
//
// Zit in de INET-overlay. Server/poort/key/model komen uit NETWORK
// (NETCFG). Plain HTTP (geen TLS): bedoeld voor Ollama op het eigen
// netwerk, die zelf ook cloudmodellen kan doorgeven.
//
//   POST /v1/chat/completions HTTP/1.0   ("stream":true)
//   -> Server-Sent Events; uit elk stukje wordt alleen "content":"..."
//      gehaald en meteen (met woordterugloop) op het scherm gezet.
//
// Het gesprek staat in een schaduwbuffer ($F000/$F300, RAM onder de
// KERNAL) zodat het na een hertekening terugkomt.
//========================================================

.const CO_L = 3                  // uitvoervak: kol 3-36, rij 3-19
.const CO_W = 34
.const CO_T = 3
.const CO_H = 17
.const CI_ROW = 21               // invoerregel
.const CI_COL = 5
.const CI_VIS = 32
.const CI_MAX = 160
.label SH_CH  = $f000            // schaduw: tekens
.label SH_COL = $f300            //          kleuren
.label REQ    = $ec00            // HTTP-verzoek (max 1 KB)
.label BODY   = $f600            // JSON-body (max 512)
.label shPtr  = r6               // zeropage-pointers (vrij in de ABI)
.label rqPtr  = r3

//--------------------------------------------------------
chat_Init: {
        jsr nc_Load
        jsr net_Detect
        lda chatInited
        bne done
        lda #1
        sta chatInited
        jsr co_Clear
        lda #0
        sta ciLen
done:   rts
}

//--------------------------------------------------------
chat_Draw: {
        // rij 2: model @ host:poort
        lda #0
        sta lbX
        ldx #NC_MODEL-NETCFG
        jsr lb_Cfg
        lda #$20
        jsr lb_Chr
        lda #$00                 // @
        jsr lb_Chr
        lda #$20
        jsr lb_Chr
        ldx #NC_HOST-NETCFG
        jsr lb_Cfg
        lda #$3a
        jsr lb_Chr
        ldx #NC_PORT-NETCFG
        jsr lb_Cfg
        lda lbX                  // maximaal 34 tekens
        cmp #CO_W
        bcc sh
        lda #CO_W
        sta lbX
sh:     ldx lbX
        lda #$ff
        sta lineBuf,x
        lda #<lineBuf
        sta r0
        lda #>lineBuf
        sta r0+1
        lda #CO_L
        sta a0
        lda #2
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        jsr co_Blit
        jsr ci_Draw
        lda #<sChHint
        sta r0
        lda #>sChHint
        sta r0+1
        lda #CO_L
        sta a0
        lda #CI_ROW+1
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
}

// lb_Cfg - NETCFG-tekstveld (offset X) achter de regelbuffer.
lb_Cfg: {
lp:     lda NETCFG,x
        cmp #$ff
        beq done
        jsr lb_Chr
        inx
        bne lp
done:   rts
}

chat_Click:
        rts

//--------------------------------------------------------
// chat_Key - typen in de invoerregel; RETURN = vraag versturen.
//--------------------------------------------------------
chat_Key: {
        lda evtA
        cmp #$80
        beq send
        cmp #$81
        beq del
        cmp #$60                 // alleen letters, cijfers, leestekens, spatie
        bcs out
        cmp #0
        beq out
        ldx ciLen
        cpx #CI_MAX
        bcs out
        sta ciBuf,x
        inc ciLen
        jmp ci_Draw
del:    lda ciLen
        beq out
        dec ciLen
        jmp ci_Draw
send:   lda ciLen
        beq out
        jmp chat_Ask
out:    rts
}

// ci_Draw - "> " + laatste CI_VIS-1 tekens + cursorblok.
ci_Draw: {
        lda #0
        sta lbX
        lda #$3e                 // >
        jsr lb_Chr
        lda #$20
        jsr lb_Chr
        lda ciLen
        sec
        sbc #CI_VIS-1
        bcs st
        lda #0
st:     tax
lp:     cpx ciLen
        beq cur
        lda ciBuf,x
        jsr lb_Chr
        inx
        bne lp
cur:    lda #$a0
        jsr lb_Chr
pad:    lda lbX
        cmp #CI_VIS+2
        bcs show
        lda #$20
        jsr lb_Chr
        jmp pad
show:   ldx lbX
        lda #$ff
        sta lineBuf,x
        lda #<lineBuf
        sta r0
        lda #>lineBuf
        sta r0+1
        lda #CO_L
        sta a0
        lda #CI_ROW
        sta a1
        lda TH_text
        sta a2
        jmp gfx_DrawText
}

//--------------------------------------------------------
// http_Do - verzoek in REQ (rqLen) naar HOST:PORT sturen en het antwoord
//           byte voor byte door chat_RxByte laten verwerken (httpMode,
//           zoekpatroon en outVec bepalen wat er met de tekst gebeurt).
//           Uit: carry=1 klaar, carry=0 -> X/Y = foutmelding.
//--------------------------------------------------------
http_Do: {
        lda #0
        sta netAbort
        // hardware + server
        lda netPlatform
        cmp #NET_PLAT_RRNET
        beq hw
        ldx #<sChNoHw
        ldy #>sChNoHw
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
hwOk:   jsr host_Parse           // HOST moet (nog) een IP zijn
        bcs hp
        ldx #<sChHost
        ldy #>sChHost
        jmp fail
hp:     jsr ip_NextHop
        jsr arp_Resolve
        bcs arp
        ldx #<sPgNoArp
        ldy #>sPgNoArp
        jmp fail
arp:    lda #<chat_RxByte
        sta tcpRxVec
        lda #>chat_RxByte
        sta tcpRxVec+1
        lda #0                   // parser-toestand
        sta hState
        sta hCrlf
        sta hSp
        sta hDig
        sta pm
        sta afterKey
        sta inStr
        sta esc
        sta uni
        sta u8need
        sta gotText
        jsr tcp_Connect
        bcs con
        ldx #<sChConn
        ldy #>sChConn
        jmp fail
con:    lda #<REQ
        sta tcpDataPtr
        lda #>REQ
        sta tcpDataPtr+1
        lda rqLen
        sta tcpDataLen
        lda rqLen+1
        sta tcpDataLen+1
        jsr tcp_Send
        bcs sent
        jsr tcp_Close
        ldx #<sChSend
        ldy #>sChSend
        jmp fail
sent:   jsr idleReset
        // antwoord ontvangen tot FIN / RST / ESC / 90 s stilte
rx:     jsr evt_Poll
        cmp #EVT_KEY
        bne r1
        lda evtA
        cmp #$82
        bne r1
        jsr tcp_Close
        ldx #<sPgStop
        ldy #>sPgStop
        jmp fail
r1:     lda #0
        sta tcpGotData
        jsr net_Poll
        lda tcpGotData
        beq r2
        jsr idleReset
r2:     lda tcpFin
        bne fin
        lda tcpRst
        bne rst
        jsr idleCheck
        bcc rx
        jsr tcp_Close
        ldx #<sChTime
        ldy #>sChTime
        jmp fail
rst:    lda hState               // antwoord al (deels) binnen?
        cmp #2
        beq end
        ldx #<sChRst
        ldy #>sChRst
        jmp fail
fin:    jsr tcp_Close
end:    lda hState               // geen HTTP-antwoord gezien?
        cmp #2
        beq ok
        ldx #<sChNoAns
        ldy #>sChNoAns
fail:   clc
        rts
ok:     sec
        rts
}

//--------------------------------------------------------
// chat_Ask - vraag tonen, verzoek bouwen, verbinden, antwoord streamen.
//--------------------------------------------------------
chat_Ask: {
        jsr co_Flush             // vraag in het gesprek zetten
        lda coCol
        beq q0
        jsr co_Nl
q0:     lda TH_accent
        sta coColor
        ldx #0
q1:     cpx ciLen
        beq q2
        stx chI
        lda ciBuf,x
        jsr co_Char
        ldx chI
        inx
        bne q1
q2:     jsr co_Flush
        jsr co_Nl
        lda TH_text
        sta coColor
        jsr rq_Build             // (gebruikt ciBuf, dus eerst bouwen)
        lda #0
        sta ciLen
        jsr ci_Draw
        lda #0                   // CHAT-modus: "content"-strings tonen
        sta httpMode
        ldx #<patContent
        ldy #>patContent
        jsr pat_Set
        lda #<as_Chat
        sta outVec
        lda #>as_Chat
        sta outVec+1
        jsr http_Do
        bcc err
        jsr co_Flush
        lda coCol
        beq e3
        jsr co_Nl
e3:     jmp co_Nl                // lege regel tussen de vragen
err:    stx r0                   // foutregel in het gesprek (rood)
        sty r0+1
        jsr co_Flush
        lda coCol
        beq e4
        jsr co_Nl
e4:     lda #LIGHT_RED
        sta coColor
        ldy #0
el:     lda (r0),y
        cmp #$ff
        beq ee
        sty chI
        jsr co_Char
        ldy chI
        iny
        bne el
ee:     jsr co_Flush
        jsr co_Nl
        lda TH_text
        sta coColor
        jmp co_Nl
}

// idle-timer op de 16-bit frameteller (90 s = 4500 frames)
idleReset:
        lda frameLo
        sta idleLo
        lda frameHi
        sta idleHi
        rts
idleCheck: {                     // carry=1 = te lang stil
        lda frameLo
        sec
        sbc idleLo
        tax
        lda frameHi
        sbc idleHi
        cmp #>4500
        bcc no
        bne yes
        cpx #<4500
        bcs yes
no:     clc
        rts
yes:    sec
        rts
}

// host_Parse - NC_HOST als IP -> ipDst; poort -> tcpRPort. Carry=1 ok.
host_Parse: {
        ldx #0
cp:     lda NC_HOST,x
        cmp #$ff
        beq pe
        sta feBuf,x
        inx
        cpx #32
        bne cp
pe:     stx feLen
        jsr ip_Parse
        bcc bad
        ldx #3
ci:     lda ipTmp,x
        sta ipDst,x
        dex
        bpl ci
        lda #0                   // poort: decimaal -> 16 bit
        sta tcpRPort
        sta tcpRPort+1
        ldx #0
pl:     lda NC_PORT,x
        cmp #$ff
        beq pd
        and #$0f
        pha
        lda tcpRPort+1           // *10 (hi = tcpRPort, lo = tcpRPort+1)
        sta ptLo
        lda tcpRPort
        sta ptHi
        asl tcpRPort+1
        rol tcpRPort
        asl tcpRPort+1
        rol tcpRPort
        clc
        lda tcpRPort+1
        adc ptLo
        sta tcpRPort+1
        lda tcpRPort
        adc ptHi
        sta tcpRPort
        asl tcpRPort+1
        rol tcpRPort
        pla
        clc
        adc tcpRPort+1
        sta tcpRPort+1
        bcc nc
        inc tcpRPort
nc:     inx
        cpx #5
        bne pl
pd:     lda tcpRPort
        ora tcpRPort+1
        beq bad
        sec
        rts
bad:    clc
        rts
}

//--------------------------------------------------------
// rq_Build - HTTP-verzoek in REQ, lengte rqLen.
//--------------------------------------------------------
rq_Build: {
        // body
        lda #<BODY
        sta rqPtr
        lda #>BODY
        sta rqPtr+1
        lda #0
        sta rqLen
        sta rqLen+1
        ldx #<aB1
        ldy #>aB1
        jsr rq_Str               // {"model":"
        ldx #NC_MODEL-NETCFG
        jsr rq_Cfg
        ldx #<aB2
        ldy #>aB2
        jsr rq_Str               // ","stream":true,"messages":[{..system..},{"role":"user","content":"
        ldx #0
q:      cpx ciLen
        beq qe
        lda ciBuf,x
        jsr sc2ascii
        cmp #$22                 // " en \ escapen
        beq qx
        cmp #$5c
        bne qc
qx:     pha
        lda #$5c
        jsr rq_Chr
        pla
qc:     jsr rq_Chr
        inx
        bne q
qe:     ldx #<aB3
        ldy #>aB3
        jsr rq_Str               // "}]}
        lda rqLen
        sta bodyLen
        lda rqLen+1
        sta bodyLen+1
        // kop
        lda #<REQ
        sta rqPtr
        lda #>REQ
        sta rqPtr+1
        lda #0
        sta rqLen
        sta rqLen+1
        ldx #<aH1
        ldy #>aH1
        jsr rq_Str               // POST ... Host:
        ldx #NC_HOST-NETCFG
        jsr rq_Cfg
        ldx #<aH2
        ldy #>aH2
        jsr rq_Str               // \r\nContent-Type... Content-Length:
        lda bodyLen
        ldx bodyLen+1
        jsr rq_Dec16
        lda NC_KEY               // Authorization alleen met een key
        cmp #$ff
        beq nokey
        ldx #<aH3
        ldy #>aH3
        jsr rq_Str
        ldx #NC_KEY-NETCFG
        jsr rq_Cfg
nokey:  ldx #<aH4
        ldy #>aH4
        jsr rq_Str               // \r\n\r\n
        lda #<BODY               // body erachter
        sta netPtr
        lda #>BODY
        sta netPtr+1
        lda rqPtr
        sta ck2
        lda rqPtr+1
        sta ck2+1
        lda bodyLen
        sta ckLen
        lda bodyLen+1
        sta ckLen+1
        jsr copyBlk
        clc
        lda rqLen
        adc bodyLen
        sta rqLen
        lda rqLen+1
        adc bodyLen+1
        sta rqLen+1
        rts
}

// rq_BuildGet - "GET /v1/models" in REQ, lengte rqLen.
rq_BuildGet: {
        lda #<REQ
        sta rqPtr
        lda #>REQ
        sta rqPtr+1
        lda #0
        sta rqLen
        sta rqLen+1
        ldx #<aG1
        ldy #>aG1
        jsr rq_Str
        ldx #NC_HOST-NETCFG
        jsr rq_Cfg
        lda NC_KEY
        cmp #$ff
        beq nokey
        ldx #<aH3
        ldy #>aH3
        jsr rq_Str
        ldx #NC_KEY-NETCFG
        jsr rq_Cfg
nokey:  ldx #<aH4
        ldy #>aH4
        jmp rq_Str
}

// mdl_Char - teken van een "id"-string naar het huidige lijst-item.
mdl_Char: {
        jsr a2sc
        bcs out
        ldy mdLen
        cpy #MD_NAME
        bcs over                 // te lang: dit model overslaan
        sta (rqPtr),y
        inc mdLen
out:    rts
over:   lda #$ff
        sta mdLen
        rts
}
// mdl_End - einde van een "id": item afsluiten, volgende.
mdl_End: {
        ldy mdLen
        beq none
        cpy #$ff
        beq none                 // te lang geweest
        lda mdCount
        cmp #MD_MAX
        bcs none
        lda #$ff
        sta (rqPtr),y
        inc mdCount
        lda rqPtr
        clc
        adc #MD_STRIDE
        sta rqPtr
        bcc none
        inc rqPtr+1
none:   lda #0
        sta mdLen
        rts
}

rq_Chr: {                        // A -> (rqPtr)++, bewaart X/Y
        sty rqY
        ldy #0
        sta (rqPtr),y
        inc rqPtr
        bne a
        inc rqPtr+1
a:      inc rqLen
        bne b
        inc rqLen+1
b:      ldy rqY
        rts
}
rq_Str: {                        // X/Y = ASCII-tekst, 0-afgesloten
        stx ck2
        sty ck2+1
        ldy #0
lp:     lda (ck2),y
        beq done
        jsr rq_Chr               // (bewaart Y)
        iny
        bne lp
        inc ck2+1                // langer dan 256 tekens
        jmp lp
done:   rts
}
rq_Cfg: {                        // NETCFG-veld (offset X) als ASCII
lp:     lda NETCFG,x
        cmp #$ff
        beq done
        jsr sc2ascii
        jsr rq_Chr
        inx
        bne lp
done:   rts
}
rq_Dec16: {                      // A (lo) / X (hi) decimaal
        sta msLo
        stx msHi
        ldx #0
        stx msAny
dg:     lda #0
        sta msDig
sb:     lda msLo
        sec
        sbc d16Lo,x
        tay
        lda msHi
        sbc d16Hi,x
        bcc put
        sta msHi
        sty msLo
        inc msDig
        jmp sb
put:    lda msDig
        bne pr
        lda msAny
        bne pr
        cpx #4
        bne nx
pr:     lda msDig
        ora #$30
        jsr rq_Chr
        inc msAny
nx:     inx
        cpx #5
        bne dg
        rts
}

// sc2ascii - schermcode -> ASCII (letters klein: modelnamen e.d.).
sc2ascii: {
        cmp #0
        bne n0
        lda #$40                 // @
        rts
n0:     cmp #27
        bcs n1
        ora #$60                 // 1-26 -> a-z
        rts
n1:     cmp #$1b
        bne n2
        lda #$5b                 // [
        rts
n2:     cmp #$1d
        bne n4
        lda #$5d                 // ]
        rts
n4:     cmp #$64
        bne n3
        lda #$5f                 // _
n3:     rts                      // $20-$3f = ASCII
}

//--------------------------------------------------------
// chat_RxByte - elk ontvangen byte (TCP-callback).
//   hState 0/1: HTTP-kop (statuscode, tot CRLFCRLF), 2: body.
//--------------------------------------------------------
chat_RxByte: {
        ldx hState
        cpx #2
        bne head
        jmp body
head:   sta hB
        cmp #$0d                 // einde kop = 4x CR/LF op rij
        beq cr
        cmp #$0a
        beq cr
        lda #0
        sta hCrlf
        lda hSp                  // statuscode: 3 cijfers na de 1e spatie
        bne sd
        lda hB
        cmp #$20
        bne out
        inc hSp
        rts
sd:     ldx hDig
        cpx #3
        bcs out
        lda hB
        sta hCode,x
        inc hDig
out:    rts
cr:     inc hCrlf
        lda hCrlf
        cmp #4
        bne out
        lda #2
        sta hState
        lda hCode                // "200"?
        cmp #$32
        bne notOk
        lda hCode+1
        cmp #$30
        bne notOk
        lda hCode+2
        cmp #$30
        bne notOk
        lda #1
        sta httpOk
        rts
notOk:  lda #0                   // fout: "HTTP nnn" en daarna de body zelf
        sta httpOk
        lda httpMode
        beq nk
        rts
nk:
        lda #LIGHT_RED
        sta coColor
        ldx #0
hc:     lda sHttp,x
        cmp #$ff
        beq hc2
        stx chI
        jsr co_Char
        ldx chI
        inx
        bne hc
hc2:    ldx #0
hc3:    lda hCode,x
        stx chI
        jsr co_Char              // cijfers: ASCII = schermcode
        ldx chI
        inx
        cpx #3
        bne hc3
        jsr co_Flush
        jmp co_Nl
body:   ldx httpOk
        bne sse
        jmp u8_Byte              // fout-body letterlijk tonen
sse:    ldx inStr
        bne str
        ldx afterKey             // na "content": spaties/: overslaan tot "
        beq find
        cmp #$20
        beq o2
        cmp #$3a
        beq o2
        ldx #0
        stx afterKey
        cmp #$22
        bne o2                   // (bv. null)
        inc inStr
        rts
find:   ldx pm                   // zoeken naar "content"
        cmp pat,x
        bne miss
        inx
        stx pm
        cpx patLen
        bne o2
        lda #1
        sta afterKey
        lda #0
        sta pm
o2:     rts
miss:   ldx #0
        cmp pat
        bne m2
        inx
m2:     stx pm
        rts
str:    ldx esc
        beq noEsc
        ldx #0
        stx esc
        cmp #$6e                 // \n
        bne e1
        jmp co_NlText
e1:     cmp #$74                 // \t
        bne e2
        lda #$20
        jmp as_Out
e2:     cmp #$75                 // \uXXXX
        bne e3
        lda #4
        sta uni
        lda #0
        sta cpLo
        sta cpHi
        rts
e3:     jmp as_Out               // \" \\ \/ e.d.: het teken zelf
noEsc:  ldx uni
        beq noUni
        jsr hexVal               // cp = cp*16 + cijfer
        ldx #4
sh:     asl cpLo
        rol cpHi
        dex
        bne sh
        ora cpLo
        sta cpLo
        dec uni
        bne o3
        jmp cp_Out
o3:     rts
noUni:  cmp #$5c
        bne nb
        lda #1
        sta esc
        rts
nb:     cmp #$22
        bne u8_Byte
        lda #0                   // einde van de string
        sta inStr
        lda httpMode
        beq nbc
        jmp mdl_End
nbc:
        rts
}
pat:    .fill 9, 0               // actief zoekpatroon (pat_Set)
patLen: .byte 0
patContent: .byte 9, $22, $63, $6f, $6e, $74, $65, $6e, $74, $22   // "content"
patId:      .byte 4, $22, $69, $64, $22                             // "id"

// pat_Set - X/Y = patroon (lengte + bytes) -> pat/patLen.
pat_Set: {
        stx ck2
        sty ck2+1
        ldy #0
        lda (ck2),y
        sta patLen
        tax
lp:     iny
        lda (ck2),y
        sta pat-1,y
        dex
        bne lp
        rts
}

hexVal: {                        // ASCII-hexcijfer -> 0-15
        cmp #$41
        bcc d
        and #$07
        adc #8                   // (carry=1) 'a'/'A' -> 10
        and #$0f
        rts
d:      and #$0f
        rts
}

// u8_Byte - UTF-8 decoderen naar een codepunt.
u8_Byte: {
        cmp #$80
        bcs hiB
        jmp as_Out
hiB:
        cmp #$c0
        bcc cont
        ldx #1
        and #$3f                 // 110xxxxx / 1110xxxx / 11110xxx
        cmp #$20
        bcc lead
        inx
        and #$1f
        cmp #$10
        bcc lead
        inx
        and #$07
lead:   stx u8need
        sta cpLo
        lda #0
        sta cpHi
        rts
cont:   ldx u8need
        beq out
        and #$3f
        pha
        ldx #6
sh:     asl cpLo
        rol cpHi
        dex
        bne sh
        pla
        ora cpLo
        sta cpLo
        dec u8need
        bne out
        jmp cp_Out
out:    rts
}

// cp_Out - codepunt cpHi/cpLo tonen (ASCII of een benadering, anders ?).
cp_Out: {
        lda cpHi
        bne hi
        lda cpLo
        bmi lat1
        jmp as_Out
lat1:   cmp #$c0                 // À-ÿ: letter zonder accent
        bcc l2
        tax
        lda latin-$c0,x
        jmp as_Out
l2:     cmp #$a0                 // harde spatie
        bne q
        lda #$20
        jmp as_Out
hi:     cmp #$20
        bne q
        lda cpLo
        cmp #$18                 // ' '
        beq ap
        cmp #$19
        beq ap
        cmp #$1c                 // “ ”
        beq qu
        cmp #$1d
        beq qu
        cmp #$13                 // – —
        beq da
        cmp #$14
        beq da
        cmp #$26                 // …
        bne q
        lda #$2e
        jsr as_Out
        lda #$2e
        jsr as_Out
        lda #$2e
        jmp as_Out
ap:     lda #$27
        jmp as_Out
qu:     lda #$22
        jmp as_Out
da:     lda #$2d
        jmp as_Out
q:      lda #$3f
        jmp as_Out
}

// Latin-1 $C0-$FF -> ASCII zonder accent ('?' waar geen letter past)
.encoding "ascii"
latin:  .text "AAAAAAACEEEEIIIIDNOOOOOxOUUUUYTs"
        .text "aaaaaaaceeeeiiiidnooooo/ouuuuyty"
.encoding "screencode_upper"

// as_Out - ASCII-teken -> schermcode -> gesprek.
as_Out: jmp (outVec)            // CHAT: as_Chat, modellen: mdl_Char

// as_Chat - ASCII-teken in het gesprek zetten.
as_Chat: {
        ldx #1
        stx gotText
        cmp #$0a
        bne n
        jmp co_NlText
n:      jsr a2sc
        bcs out
        jmp co_Char
out:    rts
}

// a2sc - ASCII A -> schermcode A (carry=0), of carry=1 = niet te tonen.
a2sc: {
        cmp #$20
        bcc no                   // stuurtekens
        cmp #$40
        bcc ok                   // spatie, cijfers, leestekens
        bne n40
        lda #0                   // @
        clc
        rts
n40:    cmp #$5b
        bcc up
        cmp #$61
        bcc sym
        cmp #$7b
        bcc lo
        tax                      // { | } ~
        lda symHi-$7b,x
        clc
        rts
lo:     sec
        sbc #$60
        clc
        rts
up:     sec
        sbc #$40
        clc
        rts
sym:    tax                      // [ \ ] ^ _ `
        lda symLo-$5b,x
ok:     clc
        rts
no:     sec
        rts
}
symLo:  .byte $1b, $2f, $1d, $1e, $64, $27     // [ \ ] ^ _ `
symHi:  .byte $28, $5d, $29, $2d, $20          // { | } ~ DEL

//--------------------------------------------------------
// Gesprek (uitvoervak met woordterugloop + schaduwbuffer)
//--------------------------------------------------------
// co_NlText - nieuwe regel uit de tekst (woord eerst afmaken).
co_NlText:
        jsr co_Flush
        jmp co_Nl

// co_Char - schermcode A; spatie breekt woorden.
co_Char: {
        cmp #$20
        beq sp
        ldx coWLen
        sta coWord,x
        inx
        stx coWLen
        cpx #CO_W
        bcs co_Flush
        rts
sp:     jsr co_Flush
        lda coCol                // geen spatie aan het begin van een regel
        beq out
        lda #$20
        jmp co_Put
out:    rts
}

// co_Flush - woord uitschrijven (eerst naar de volgende regel als het
//            niet meer past).
co_Flush: {
        lda coWLen
        beq out
        clc
        adc coCol
        cmp #CO_W+1
        bcc fits
        lda coCol
        beq fits
        jsr co_Nl
fits:   ldx #0
lp:     stx coWI
        lda coWord,x
        jsr co_Put
        ldx coWI
        inx
        cpx coWLen
        bne lp
        lda #0
        sta coWLen
out:    rts
}

// co_Put - één teken op de cursor (schaduw + scherm), cursor verder.
co_Put: {
        sta coC
        jsr shAddr
        ldy coCol
        lda coC
        sta (shPtr),y
        lda shPtr+1              // kleur staat $300 verder
        clc
        adc #3
        sta shPtr+1
        lda coColor
        sta (shPtr),y
        lda coCol
        clc
        adc #CO_L
        sta a0
        lda coRow
        clc
        adc #CO_T
        sta a1
        lda coC
        sta a2
        lda coColor
        sta a3
        jsr gfx_PutChar
        inc coCol
        lda coCol
        cmp #CO_W
        bcc out
        jmp co_Nl
out:    rts
}

// co_Nl - volgende regel; onderaan: alles een regel omhoog.
co_Nl: {
        lda #0
        sta coCol
        lda coRow
        cmp #CO_H-1
        bcs scr
        inc coRow
        rts
scr:    lda #>SH_CH              // schaduw: rij 1..16 -> 0..15
        jsr shift
        lda #>SH_COL
        jsr shift
        ldy #CO_W-1              // laatste rij leeg
cl:     lda #$20
        sta SH_CH+CO_W*(CO_H-1),y
        lda coColor
        sta SH_COL+CO_W*(CO_H-1),y
        dey
        bpl cl
        jmp co_Blit
shift:  sta ck2+1                // A = hi van de buffer (lo = 0)
        sta netPtr+1
        lda #0
        sta ck2
        lda #CO_W
        sta netPtr
        lda #<[CO_W*(CO_H-1)]
        sta ckLen
        lda #>[CO_W*(CO_H-1)]
        sta ckLen+1
        jmp copyBlk
}

// shAddr - shPtr = SH_CH + coRow*CO_W.
shAddr: {
        ldx coRow
        lda shRowLo,x
        sta shPtr
        lda shRowHi,x
        sta shPtr+1
        rts
}
shRowLo: .fill CO_H, <[SH_CH + i*CO_W]
shRowHi: .fill CO_H, >[SH_CH + i*CO_W]

// co_Blit - schaduw -> scherm (hele uitvoervak).
co_Blit: {
        lda #0
        sta coBr
row:    ldx coBr
        lda shRowLo,x
        sta shPtr
        lda shRowHi,x
        sta shPtr+1
        txa
        clc
        adc #CO_T
        tax
        lda screenLo,x           // scherm-/kleuradres van deze rij
        clc
        adc #CO_L
        sta r4
        sta r5
        lda screenHi,x
        adc #0
        sta r4+1
        clc
        adc #$d4
        sta r5+1
        ldy #CO_W-1
col:    lda (shPtr),y
        sta (r4),y
        dey
        bpl col
        lda shPtr+1
        clc
        adc #3
        sta shPtr+1
        ldy #CO_W-1
cc:     lda (shPtr),y
        sta (r5),y
        dey
        bpl cc
        inc coBr
        lda coBr
        cmp #CO_H
        bne row
        rts
}

// co_Clear - leeg gesprek.
co_Clear: {
        ldx #0
lp:     lda #$20
        sta SH_CH,x
        sta SH_CH+$100,x
        sta SH_CH+$200,x
        lda TH_text
        sta SH_COL,x
        sta SH_COL+$100,x
        sta SH_COL+$200,x
        inx
        bne lp
        lda #0
        sta coCol
        sta coRow
        sta coWLen
        lda TH_text
        sta coColor
        rts
}

//--------------------------------------------------------
chatInited: .byte 0
httpMode: .byte 0                // 0 = CHAT, 1 = modellenlijst
mdCount:  .byte 0
mdLen:    .byte 0
.align 2                         // jmp (outVec) mag niet op $xxFF staan
outVec:   .word as_Chat
ciLen:    .byte 0
ciBuf:    .fill CI_MAX, 0
chI:      .byte 0
coCol:    .byte 0
coRow:    .byte 0
coColor:  .byte 0
coWLen:   .byte 0
coWI:     .byte 0
coC:      .byte 0
coCnt:    .byte 0
coBr:     .byte 0
coWord:   .fill CO_W, 0
rqLen:    .word 0
bodyLen:  .word 0
rqY:      .byte 0
ptLo:     .byte 0
ptHi:     .byte 0
idleLo:   .byte 0
idleHi:   .byte 0
hState:   .byte 0
hCrlf:    .byte 0
hSp:      .byte 0
hDig:     .byte 0
hB:       .byte 0
hCode:    .fill 3, 0
httpOk:   .byte 0
pm:       .byte 0
inStr:    .byte 0
afterKey: .byte 0
esc:      .byte 0
uni:      .byte 0
u8need:   .byte 0
cpLo:     .byte 0
cpHi:     .byte 0
gotText:  .byte 0

// ASCII-teksten van het verzoek (0-afgesloten)
.encoding "ascii"
aB1:    .text @"{\"model\":\""
        .byte 0
aB2:    .text @"\",\"stream\":true,\"messages\":[{\"role\":\"system\",\"content\":\"You run on a Commodore 64 with a 34 column screen. Answer briefly in plain text, no markdown.\"},{\"role\":\"user\",\"content\":\""
        .byte 0
aB3:    .text @"\"}]}"
        .byte 0
aG1:    .text @"GET /v1/models HTTP/1.0\r\nHost: "
        .byte 0
aH1:    .text @"POST /v1/chat/completions HTTP/1.0\r\nHost: "
        .byte 0
aH2:    .text @"\r\nContent-Type: application/json\r\nContent-Length: "
        .byte 0
aH3:    .text @"\r\nAuthorization: Bearer "
        .byte 0
aH4:    .text @"\r\n\r\n"
        .byte 0

.encoding "screencode_upper"
sChHint:  .text "RETURN = SEND   ESC = CLOSE"
          .byte $ff
sChNoHw:  .text "NO RR-NET FOUND (SEE NETWORK)"
          .byte $ff
sChHost:  .text "HOST MUST BE AN IP ADDRESS"
          .byte $ff
sChConn:  .text "NO CONNECTION TO THE SERVER"
          .byte $ff
sChSend:  .text "SENDING FAILED"
          .byte $ff
sChTime:  .text "NO ANSWER WITHIN 90 SECONDS"
          .byte $ff
sChRst:   .text "CONNECTION REFUSED"
          .byte $ff
sChNoAns: .text "NO ANSWER FROM THE SERVER"
          .byte $ff
sHttp:    .text "HTTP "
          .byte $ff
