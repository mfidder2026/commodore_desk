#importonce
//========================================================
// apps/web/web_net.asm - een pagina ophalen (HTTP/1.0)
// Commodore Desk 64
//
// Via de TCP-laag van EMAIL (mail_net.asm): RR-Net, Ultimate en WiC64.
// HTTP/1.0: geen chunked, de server sluit aan het eind. Het antwoord gaat
// byte voor byte door nt_Rx: statusregel, kopregels (Location,
// Content-Type), dan de inhoud naar ht_Byte. Het pagina-geheugen wordt
// pas leeggemaakt bij de eerste byte van de inhoud (nt_Start): mislukt
// het ophalen, of is het een doorverwijzing, dan blijft de oude pagina.
//========================================================
.const NT_TMO = 1000             // 20 s zonder data: opgeven

// nt_Fetch - WB_NEW ophalen (ur_Norm + ur_Parse gedaan). Carry=1: klaar
//            (ntCode "200", ntType 0 HTML / 1 tekst / 2 iets anders,
//            Location in WB_REQ); anders X/Y = melding. ntStarted = 1 als
//            de inhoud begonnen is (de pagina is dan vervangen).
nt_Fetch: {
        jsr nt_Req
        lda #0
        sta htFull               // (van de vorige pagina / het zoeken)
        sta htFound
        sta ntStarted
        sta ntType
        sta hdSt
        sta hdLen
        sta ntBytes
        sta ntBytes+1
        sta ntBytes+2
        sta ntShown
        lda #$30
        sta ntCode
        jsr nc_Load              // netwerk (NET.CFG) + hardware
        jsr net_Detect
        lda #0
        sta netAbort
        lda #<WB_HOST
        sta r3
        lda #>WB_HOST
        sta r3+1
        lda #<WB_PORT
        sta r6
        lda #>WB_PORT
        sta r6+1
        jsr mn_Open
        bcs op
        rts
op:     lda #<nt_Rx
        sta tcpRxVec
        lda #>nt_Rx
        sta tcpRxVec+1
        lda #<WB_REQ
        sta tcpDataPtr
        lda #>WB_REQ
        sta tcpDataPtr+1
        lda ntReqLen
        sta tcpDataLen
        lda ntReqLen+1
        sta tcpDataLen+1
        jsr mn_Send
        bcs wt
        jsr mn_Close
        ldx #<sMnLost
        ldy #>sMnLost
        clc
        rts
wt:     lda #0                   // (WB_REQ is nu vrij: Location)
        sta WB_REQ
        sta ntTicks
        sta ntTicks+1
        lda frameLo
        sta ntFl
lp:     lda mnClosed
        bne dn
        lda htFull               // pagina vol of link gevonden: genoeg
        ora htFound
        bne dn
        jsr evt_Poll
        cmp #EVT_KEY
        bne np
        lda evtA
        cmp #KEY_STOP
        bne np
        lda #1
        sta netAbort
        jsr mn_Close
        ldx #<sWbStop
        ldy #>sWbStop
        clc
        rts
np:     jsr mn_Poll
        lda ntBytes+1            // elke KB: de stand op de statusregel
        and #$fc
        cmp ntShown
        beq tm
        sta ntShown
        jsr wb_Loading
tm:     lda frameLo
        cmp ntFl
        beq lp
        sta ntFl
        inc ntTicks
        bne t1
        inc ntTicks+1
t1:     lda ntTicks+1            // (terug naar 0 bij elke byte)
        cmp #>NT_TMO
        bcc lp
        lda ntTicks
        cmp #<NT_TMO
        bcc lp
        jsr mn_Close
        ldx #<sMnTime
        ldy #>sMnTime
        clc
        rts
dn:     jsr mn_Close
        lda hdSt                 // nooit een antwoord?
        bne ok
        ldx #<sMnClosed
        ldy #>sMnClosed
        clc
        rts
ok:     sec
        rts
}

// nt_Req - het verzoek in WB_REQ: GET <pad> HTTP/1.0, Host, User-Agent.
nt_Req: {
        lda #<WB_REQ
        sta wD
        lda #>WB_REQ
        sta wD+1
        ldx #<rqGet
        ldy #>rqGet
        jsr rq_Str
        lda urSlash
        beq p
        lda #$2f
        jsr rq_Chr
p:      lda urPath               // het pad (spatie -> %20), tot 767 tekens
        clc
        adc #<WB_NEW
        sta wS
        lda #>WB_NEW
        adc #0
        sta wS+1
pl:     ldy #0
        lda (wS),y
        beq pe
        cmp #$20
        bne pc
        lda #$25
        jsr rq_Chr
        lda #$32
        jsr rq_Chr
        lda #$30
pc:     jsr rq_Chr
        inc wS
        bne pl
        inc wS+1
        bne pl
pe:     ldx #<rqHost
        ldy #>rqHost
        jsr rq_Str
        ldx urHost               // host (en :poort) uit het adres
hl:     cpx urHEnd
        beq he
        lda WB_NEW,x
        jsr rq_Chr
        inx
        bne hl
he:     lda urPortS
        beq h2
        lda #$3a
        jsr rq_Chr
        ldx urPortS
h1:     cpx urPortE
        beq h2
        lda WB_NEW,x
        jsr rq_Chr
        inx
        bne h1
h2:     ldx #<rqTail
        ldy #>rqTail
        jsr rq_Str
        lda wD                   // lengte
        sec
        sbc #<WB_REQ
        sta ntReqLen
        lda wD+1
        sbc #>WB_REQ
        sta ntReqLen+1
        rts
}
// rq_Chr - A achter het verzoek (X blijft); rq_Str - tekst X/Y (0).
rq_Chr: {
        ldy #0
        sta (wD),y
        inc wD
        bne r
        inc wD+1
r:      rts
}
rq_Str: {
        stx wS
        sty wS+1
        ldy #0
l:      lda (wS),y
        beq r
        sty rqY
        jsr rq_Chr
        ldy rqY
        iny
        bne l
r:      rts
}

//--------------------------------------------------------
// nt_Rx - een byte van de server (tcpRxVec).
//--------------------------------------------------------
nt_Rx: {
        ldx #0                   // er komt data: time-out opnieuw
        stx ntTicks
        stx ntTicks+1
        ldx hdSt
        cpx #2
        beq body
        cmp #$0d
        beq r
        cmp #$0a
        beq eol
        ldx hdLen
        cpx #95
        bcs r
        sta WB_HDR,x
        inc hdLen
r:      rts
eol:    ldx hdLen
        lda #0
        sta WB_HDR,x
        lda hdSt
        bne hl
        lda WB_HDR+9             // "HTTP/1.x 200 OK"
        sta ntCode
        lda WB_HDR+10
        sta ntCode+1
        lda WB_HDR+11
        sta ntCode+2
        lda #1
        sta hdSt
        lda #0
        sta hdLen
        rts
hl:     lda hdLen
        bne hh
        lda #2                   // lege regel: nu de inhoud
        sta hdSt
        rts
hh:     jsr nt_Header
        lda #0
        sta hdLen
        rts
body:   inc ntBytes
        bne b1
        inc ntBytes+1
        bne b1
        inc ntBytes+2
b1:     ldx ntCode               // doorverwijzing: inhoud niet nodig
        cpx #$33
        beq r
        ldx ntType               // geen tekst: niet tonen
        cpx #2
        beq r
        ldx ntStarted
        bne go
        pha
        jsr nt_Start
        pla
go:     jmp ht_Byte
}

// nt_Start - de inhoud begint: de oude pagina in de geschiedenis (ntPush)
//            en het pagina-geheugen leeg (niet in de zoekmodus).
nt_Start: {
        inc ntStarted
        lda htFind
        bne b
        lda ntPush
        beq n
        jsr hi_Push
n:      jsr pg_Reset
b:      lda ntType
        jmp ht_Begin
}

// nt_Header - kopregel WB_HDR: Location en Content-Type.
nt_Header: {
        ldx #0
        ldy #hdLoc-hdNames
        jsr hd_Is
        bne ct
        ldx #0                   // Location -> WB_REQ
l:      lda WB_HDR,y
        sta WB_REQ,x
        beq r
        iny
        inx
        bne l
        lda #0
        sta WB_REQ+255
r:      rts
ct:     ldy #hdType-hdNames
        jsr hd_Is
        bne r
        lda #0                   // text/html (of xhtml): 0
        sta ntType
        lda WB_HDR,y
        ora #$20
        cmp #$74                 // t(ext/...)
        bne ap
        lda WB_HDR+5,y
        ora #$20
        cmp #$68                 // text/h(tml)
        beq r
        lda #1                   // andere tekst: platte tekst
        sta ntType
        rts
ap:     lda WB_HDR+12,y          // application/x(html)
        ora #$20
        cmp #$78
        beq r
        lda #2
        sta ntType
        rts
}

// hd_Is - begint WB_HDR met naam hdNames+Y (klein, met :)? Z=1: ja,
//         Y = begin van de waarde (na de spaties).
hd_Is: {
        ldx #0
l:      lda hdNames,y
        beq m
        sta hdT
        lda WB_HDR,x
        jsr lower
        cmp hdT
        bne r
        inx
        iny
        bne l
m:      lda WB_HDR,x             // spaties overslaan
        cmp #$20
        bne e
        inx
        bne m
e:      txa
        tay
        lda #0                   // Z=1
r:      rts
}

.encoding "ascii"
rqGet:  .text "GET "
        .byte 0
rqHost: .text " HTTP/1.0"
        .byte $0d, $0a
        .text "Host: "
        .byte 0
rqTail: .byte $0d, $0a
        .text "User-Agent: CD64-Web/1.0 (Commodore 64)"
        .byte $0d, $0a
        .text "Accept: text/html, text/plain"
        .byte $0d, $0a, $0d, $0a, 0
hdNames:
hdLoc:  .text "location:"
        .byte 0
hdType: .text "content-type:"
        .byte 0
.encoding "screencode_upper"

ntCode:   .byte $30, $30, $30
ntType:   .byte 0
ntStarted: .byte 0
ntPush:   .byte 0
ntReqLen: .word 0
ntBytes:  .fill 3, 0
ntShown:  .byte 0
ntTicks:  .word 0
ntFl:     .byte 0
hdSt:     .byte 0
hdLen:    .byte 0
hdT:      .byte 0
rqY:      .byte 0
