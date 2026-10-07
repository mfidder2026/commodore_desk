#importonce
//========================================================
// apps/weather/weather_net.asm - het weer ophalen bij wttr.in
// Commodore Desk 64
//
// HTTP/1.0 (de server sluit na het antwoord, geen chunked), via de TCP-
// laag van EMAIL (mail_net.asm): RR-Net, Ultimate en WiC64.
//   GET /<plaats>?format=%l|%x|...&m&lang=en HTTP/1.0
// Lege plaats = "AUTO": wttr.in kiest de plaats bij het IP-adres.
// Antwoord: 200 + een regel (zie we_Parse); een onbekende plaats geeft
// 500 met "location not found".
//========================================================
.const WE_TMO = 1000             // 20 s zonder data: opgeven

// we_Fetch - ophalen en ontleden. Carry=1 gelukt, anders X/Y = melding.
we_Fetch: {
        jsr nc_Load              // netwerk (NET.CFG) + hardware
        jsr net_Detect
        lda #0
        sta netAbort
        lda #<weHost
        sta r3
        lda #>weHost
        sta r3+1
        lda #<wePort
        sta r6
        lda #>wePort
        sta r6+1
        jsr mn_Open
        bcs op
        rts
op:     lda #<we_Rx              // het antwoord zelf verwerken
        sta tcpRxVec
        lda #>we_Rx
        sta tcpRxVec+1
        lda #0
        sta weSt
        sta weLn
        sta weNr
        sta weOk
        sta weRawN
        jsr mc_Start             // GET /<plaats>?format=... HTTP/1.0
        ldx #<sWeGet
        ldy #>sWeGet
        jsr mc_Str
        ldy #0
pl:     lda weLoc,y
        cmp #$ff
        beq pe
        cmp #$20                 // spatie -> +
        bne pc
        lda #$2b
        bne pp
pc:     jsr sc2ascii
pp:     jsr mc_Chr
        iny
        cpy #31
        bne pl
pe:     ldx #<sWeQry
        ldy #>sWeQry
        jsr mc_Str
        lda #<mnCmd
        sta tcpDataPtr
        lda #>mnCmd
        sta tcpDataPtr+1
        lda mnCmdLen
        sta tcpDataLen
        lda #0
        sta tcpDataLen+1
        jsr mn_Send
        bcs wt
        jsr mn_Close
        ldx #<sMnLost
        ldy #>sMnLost
        clc
        rts
wt:     lda #0                   // tot de server sluit
        sta weTicks
        sta weTicks+1
        lda frameLo
        sta weFl
lp:     lda mnClosed
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
        ldx #<sPgStop
        ldy #>sPgStop
        clc
        rts
np:     jsr mn_Poll
        lda frameLo
        cmp weFl
        beq lp
        sta weFl
        inc weTicks
        bne t1
        inc weTicks+1
t1:     lda weTicks+1            // (terug naar 0 bij elke byte)
        cmp #>WE_TMO
        bcc lp
        lda weTicks
        cmp #<WE_TMO
        bcc lp
        jsr mn_Close
        ldx #<sMnTime
        ldy #>sMnTime
        clc
        rts
dn:     jsr mn_Close
        ldx weRawN               // antwoord afsluiten
        lda #0
        sta WE_RAW,x
        lda weOk
        bne ok
        lda WE_RAW               // "location not found ..."
        cmp #$6c
        bne se
        ldx #<sWeNoPlace
        ldy #>sWeNoPlace
        clc
        rts
se:     ldx #<sWeSvc
        ldy #>sWeSvc
        clc
        rts
ok:     lda weRawN
        bne o2
        ldx #<sMnClosed
        ldy #>sMnClosed
        clc
        rts
o2:     lda #<WE_RAW
        sta weS
        lda #>WE_RAW
        sta weS+1
        jsr we_Parse
        jsr we_Type
        jsr we_Stamp
        sec
        rts
}

// we_Rx - een byte van de server (tcpRxVec): statusregel en kop, daarna
//         de body naar WE_RAW (max. 255 bytes).
we_Rx: {
        ldx #0                   // er komt data: time-out opnieuw
        stx weTicks
        stx weTicks+1
        ldx weSt
        bne body
        cmp #$0d
        beq r
        cmp #$0a
        beq eol
        ldx weLn
        cpx #16
        bcs r
        sta weHl,x
        inc weLn
r:      rts
eol:    lda weLn
        bne ln
        lda #1                   // lege regel: nu de body
        sta weSt
        rts
ln:     lda weNr                 // eerste regel: "HTTP/1.0 200 OK"?
        bne nx
        lda weHl+9
        cmp #$32
        bne nx
        lda weHl+10
        cmp #$30
        bne nx
        lda weHl+11
        cmp #$30
        bne nx
        inc weOk
nx:     inc weNr
        lda #0
        sta weLn
        rts
body:   ldx weRawN
        cpx #255
        bcs r
        sta WE_RAW,x
        inc weRawN
        rts
}

// we_Stamp - "UPDATED HH:MM" (klok van de C64, BCD) in weUpd.
we_Stamp: {
        lda clkHour
        ldx #0
        jsr two
        lda #$3a                 // :
        sta weUpd,x
        inx
        lda clkMin
        jsr two
        lda #$ff
        sta weUpd,x
        rts
two:    pha
        lsr
        lsr
        lsr
        lsr
        ora #$30
        sta weUpd,x
        inx
        pla
        and #$0f
        ora #$30
        sta weUpd,x
        inx
        rts
}

weSt:    .byte 0
weLn:    .byte 0
weNr:    .byte 0
weOk:    .byte 0
weRawN:  .byte 0
weFl:    .byte 0
weTicks: .word 0
weHl:    .fill 16, 0
.encoding "screencode_upper"
weHost:  .text "WTTR.IN"        // (ruimte voor een andere server: de
         .byte $ff               //  testserver, tools/weather_test_server.py)
         .fill 24, $ff
wePort:  .text "80"
         .byte $ff
         .fill 3, $ff
sWeNoPlace: .text "PLACE NOT FOUND"
         .byte $ff
sWeSvc:  .text "WEATHER SERVICE ERROR"
         .byte $ff
sWeBusy: .text "FETCHING THE WEATHER (RUN/STOP)"
         .byte $ff
.encoding "ascii"
sWeGet:  .text "GET /"
         .byte 0
sWeQry:  .text "?format=%l|%x|%t|%f|%C|%w|%h|%p|%P|%S|%s|%T&m&lang=en HTTP/1.0"
         .byte $0d, $0a
         .text "Host: wttr.in"
         .byte $0d, $0a
         .text "User-Agent: CD64-Weather"
         .byte $0d, $0a, $0d, $0a, 0
.encoding "screencode_upper"
