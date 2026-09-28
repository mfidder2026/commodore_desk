#importonce
//========================================================
// apps/radio/radio.asm - SID RADIO (app 13, overlay RADIO)
// Commodore Desk 64
//
// Speelt tunes uit de High Voltage SID Collection (HVSC) van internet:
// een willekeurige tune uit RADIO.LST ophalen met HTTP (zonder TLS, dus
// een http-spiegel: standaard hvsc.brona.dk), naar $4000 zetten en met de
// SID-speler van SIDPLAY afspelen (radiomodus, zie apps/sidplay.asm).
// SPATIE of 3 minuten = volgende tune, RUN/STOP = radio uit.
//
// RADIO.LST (tekst, ook in de TEXT EDITOR te bewerken):
//   regel 1: server + basispad, bv. "hvsc.brona.dk/HVSC/C64Music/MUSICIANS/"
//   daarna:  een tune per regel, bv. "H/Hubbard_Rob/Commando.sid"
// PETSCII zoals de TEXT EDITOR: kleine letters $41-$5A, hoofdletters
// $C1-$DA, _ = $A4 (HTTP-paden zijn hoofdlettergevoelig).
// tools/make_radio_list.py maakt de standaardlijst, make_radio_seq.py
// zet hem om.
//
// Geheugen: lijst $C500-$CFFF, HTTP-regel/opdracht $F600-$F7FF (zie
// radio.inc), het bestand zelf op $4000-$7EFF (SP_STAGE).
//========================================================

.const RA_COL    = 3
.const RA_W      = 34
.const RA_R_BTN  = 18
.const RA_R_MSG  = 20
.const RA_HELP   = 18            // F1-context (gui/help.txt)
.const RA_NTXT   = 6             // vaste tekstregels in ra_Draw
.const RA_FAILS  = 4             // zoveel mislukte tunes achter elkaar: stoppen
.const RA_TMO    = 1000          // 20 s zonder data: opgeven
.label raP       = r5            // zeropage: lijst doorlopen

ra_Init:
        lda #RA_HELP
        sta helpCtx
        lda #0
        sta raMsg+1
        sta raLast+1
        jmp ra_Load

// ra_Key - geen eigen toetsen (SPATIE/RETURN = klik op de cursor).
ra_Key:
        clc
        rts

//--------------------------------------------------------
// ra_Load - RADIO.LST lezen: basisregel splitsen, tunes tellen.
//--------------------------------------------------------
ra_Load: {
        lda #0
        sta raCount
        sta raHostLen
        lda #<RL_BUF
        sta raP
        lda #>RL_BUF
        sta raP+1
        jsr cfg_io_begin
        lda #nmE-nm
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #2
        ldx #8
        ldy #2
        jsr K_SETLFS
        jsr K_OPEN
        bcs cl
        ldx #2
        jsr K_CHKIN
        bcs cl
rd:     jsr K_CHRIN
        tax
        lda $90
        and #$42                 // time-out/einde zonder data: fout
        cmp #$02
        beq cl
        txa
        cmp #$0d                 // regeleinde -> 0
        bne st
        lda #0
st:     ldy #0
        sta (raP),y
        inc raP
        bne s1
        inc raP+1
s1:     lda raP+1                // vol? (2 bytes over voor het einde)
        cmp #>[RL_BUF+RL_MAX]
        bcc s2
        lda raP
        cmp #<[RL_BUF+RL_MAX]
        bcs cl
s2:
        lda $90
        beq rd
cl:     jsr K_CLRCHN
        lda #2
        jsr K_CLOSE
        jsr cfg_io_end
        ldy #0                   // afsluiten: lege regel = einde van de lijst
        tya
        sta (raP),y
        iny
        sta (raP),y
        // regel 1: host[:poort] tot de eerste /, de rest is het basispad
        lda #<RL_BUF
        sta raP
        lda #>RL_BUF
        sta raP+1
        lda #$38                 // poort 80
        sta raPort
        lda #$30
        sta raPort+1
        lda #$ff
        sta raPort+2
        ldy #0
hl:     lda (raP),y
        beq he
        cmp #$2f
        beq he
        cmp #$3a                 // :poort
        beq pt
        jsr ra_P2S
        sta raHost,y
        iny
        cpy #32
        bne hl
he:     sty raHostLen
        lda #$ff
        ldx raHostLen
        sta raHost,x
        sty raBaseOff            // basispad begint hier (met de /)
        jmp cnt
pt:     sty raHostLen            // poortcijfers
        ldx #0
pc:     iny
        lda (raP),y
        cmp #$30
        bcc pe
        cmp #$3a
        bcs pe
        sta raPort,x
        inx
        cpx #5
        bne pc
pe:     lda #$ff
        sta raPort,x
        ldx raHostLen
        sta raHost,x
tp:     lda (raP),y              // naar de / (of het einde)
        beq tb
        cmp #$2f
        beq tb
        iny
        bne tp
tb:     sty raBaseOff
cnt:    jsr ra_NextLine          // tunes tellen
cn:     ldy #0
        lda (raP),y
        beq done
        inc raCount
        jsr ra_NextLine
        lda raCount
        cmp #255
        bne cn
done:   rts
.encoding "petscii_upper"
nm:     .text "RADIO.LST"
nmE:
.encoding "screencode_upper"
}

// ra_NextLine - raP voorbij de volgende 0.
ra_NextLine: {
        ldy #0
l:      lda (raP),y
        beq e
        iny
        bne l
e:      iny
        tya
        clc
        adc raP
        sta raP
        bcc r
        inc raP+1
r:      rts
}

// ra_P2S - PETSCII (lijst) -> schermcode om te tonen.
ra_P2S: {
        cmp #$a4                 // _
        bne n1
        lda #$64
        rts
n1:     cmp #$c1
        bcc n2
        cmp #$db
        bcs n2
        and #$1f                 // hoofdletter
        rts
n2:     jmp petscii2screen
}

// ra_P2A - PETSCII (lijst) -> ASCII voor het HTTP-verzoek.
ra_P2A: {
        cmp #$a4                 // _
        bne a1
        lda #$5f
        rts
a1:     cmp #$41
        bcc r
        cmp #$5b
        bcs h
        ora #$20                 // $41-$5A: kleine letter
        rts
h:      cmp #$c1
        bcc r
        cmp #$db
        bcs r
        and #$7f                 // $C1-$DA: hoofdletter
r:      rts
}

//--------------------------------------------------------
// ra_Draw
//--------------------------------------------------------
ra_Draw: {
        ldx #0
tl:     stx raI                  // vaste regels
        lda raTxtLo,x
        sta r0
        lda raTxtHi,x
        sta r0+1
        lda raTxtRow,x
        sta a1
        lda #RA_COL
        sta a0
        lda TH_text
        cpx #0
        bne tc
        lda TH_accent
tc:     sta a2
        jsr gfx_DrawText
        ldx raI
        inx
        cpx #RA_NTXT
        bne tl
        lda #<raHost             // server
        sta r0
        lda #>raHost
        sta r0+1
        lda #RA_COL
        sta a0
        lda #8
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        ldx #0                   // "79 TUNES IN RADIO.LST"
        lda raCount
        jsr ra_Dec
        ldy #0
t1:     lda sRaTunes,y
        sta raLine,x
        cmp #$ff
        beq t2
        inx
        iny
        bne t1
t2:     lda #10
        jsr ra_Line
        lda raLast+1             // laatste tune
        beq bt
        lda raLast
        sta raP
        lda raLast+1
        sta raP+1
        jsr ra_TuneText
        lda #13
        jsr ra_Line
bt:     lda #<sRaPlay            // PLAY
        sta r0
        lda #>sRaPlay
        sta r0+1
        lda #RA_COL
        sta a0
        lda #RA_R_BTN
        sta a1
        lda #10
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        jmp ra_ShowMsg
}

// ra_Line - raLine op rij A (accent).
ra_Line:
        sta a1
        lda #<raLine
        sta r0
        lda #>raLine
        sta r0+1
        lda #RA_COL
        sta a0
        lda TH_accent
        sta a2
        jmp gfx_DrawText

// ra_TuneText - tune op raP -> raLine (schermcodes, max RA_W).
ra_TuneText: {
        ldy #0
l:      lda (raP),y
        beq e
        jsr ra_P2S
        sta raLine,y
        iny
        cpy #RA_W
        bne l
e:      lda #$ff
        sta raLine,y
        rts
}

// ra_Dec - A (0-255) decimaal naar raLine,x.
ra_Dec: {
        ldy #0
        sty raAny
        sta raT
        ldy #2
d:      lda #0
        sta raDig
s:      lda raT
        cmp dTab,y
        bcc n
        sbc dTab,y
        sta raT
        inc raDig
        bne s
n:      lda raDig
        ora raAny
        bne p
        cpy #0
        bne z
p:      lda raDig
        ora #$30
        sta raLine,x
        inx
        inc raAny
z:      dey
        bpl d
        rts
dTab:   .byte 1, 10, 100
}

// ra_Say / ra_ShowMsg - meldingsregel.
ra_Say:
        stx raMsg
        sty raMsg+1
ra_ShowMsg: {
        lda #RA_COL
        sta a0
        lda #RA_R_MSG
        sta a1
        lda #RA_W
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda raMsg+1
        beq r
        sta r0+1
        lda raMsg
        sta r0
        lda #RA_COL
        sta a0
        lda #RA_R_MSG
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
r:      rts
}

//--------------------------------------------------------
// ra_Click - PLAY.
//--------------------------------------------------------
ra_Click: {
        lda #RA_COL
        sta a0
        lda #RA_R_BTN
        sta a1
        lda #10
        sta a2
        jsr btn_HitTest
        bcs ra_Run
        rts
}

//--------------------------------------------------------
// ra_Run - de radio: ophalen, spelen, volgende ... tot RUN/STOP.
//--------------------------------------------------------
ra_Run: {
        lda raCount
        bne go
        ldx #<sRaEmpty
        ldy #>sRaEmpty
        jmp ra_Say
go:     jsr nc_Load              // netwerk (NET.CFG) + hardware
        jsr net_Detect
        lda #0
        sta raFails
nxt:    jsr ra_Pick
        lda raP
        sta raLast
        lda raP+1
        sta raLast+1
        ldx #<sRaTune            // "TUNING IN..."
        ldy #>sRaTune
        stx raMsg
        sty raMsg+1
        jsr shell_DrawAll
        jsr ra_Fetch
        bcc bad
        lda #1                   // afspelen (Core is dan even weg)
        sta spRadio
        jsr sp_Play.ld
        lda #0
        sta spRadio
        bcc bad
        lda #0
        sta raFails
        lda spRes
        cmp #2
        bne nxt
        ldx #<sRaOff
        ldy #>sRaOff
        stx raMsg
        sty raMsg+1
        jmp shell_DrawAll        // (scherm en muis terug)
bad:    stx raMsg                // X/Y = melding; volgende proberen
        sty raMsg+1
        lda netAbort             // RUN/STOP tijdens het ophalen
        bne stop
        inc raFails
        lda raFails
        cmp #RA_FAILS
        bcc nxt
stop:   jmp shell_DrawAll
}

// ra_Pick - willekeurige tune (niet dezelfde als de vorige) -> raP.
ra_Pick: {
        lda $d012                // toeval: raster, CIA-timer, beeldteller
        eor $dc04
        eor frameLo
        adc raSeed
        sta raSeed
        ldx raCount
        cpx #2
        bcc z
m:      cmp raCount              // A mod raCount
        bcc k
        sbc raCount
        jmp m
z:      lda #0
k:      cmp raPrev
        bne ok
        cpx #2
        bcc ok
        clc                      // zelfde als de vorige: de volgende
        adc #1
        cmp raCount
        bcc ok
        lda #0
ok:     sta raPrev
        tax
        lda #<RL_BUF             // regel 1 = server, dan de tunes
        sta raP
        lda #>RL_BUF
        sta raP+1
        jsr ra_NextLine
        cpx #0
        beq r
l:      jsr ra_NextLine
        dex
        bne l
r:      rts
}

//--------------------------------------------------------
// ra_Fetch - tune raP met HTTP/1.0 naar $4000 (zonder de eerste 2
//            bytes, net als LOAD). Carry=1 -> spEnd; anders X/Y melding.
//--------------------------------------------------------
ra_Fetch: {
        lda raLast               // tune (raP is door het tekenen weg)
        sta raP
        lda raLast+1
        sta raP+1
        lda #0
        sta netAbort
        lda #<raHost
        sta r3
        lda #>raHost
        sta r3+1
        lda #<raPort
        sta r6
        lda #>raPort
        sta r6+1
        lda raP                  // (mn_Open gebruikt r3/r6)
        pha
        lda raP+1
        pha
        jsr mn_Open
        pla
        sta raP+1
        pla
        sta raP
        bcs op
        rts
op:     lda #<ra_Rx              // HTTP-antwoord zelf verwerken
        sta tcpRxVec
        lda #>ra_Rx
        sta tcpRxVec+1
        lda #0
        sta raSt
        sta raLn
        sta raOk
        sta raBig
        sta raNr
        lda #2
        sta raSkip
        lda #<SP_STAGE
        sta raWr+1
        lda #>SP_STAGE
        sta raWr+2
        // GET <basispad><tune> HTTP/1.0 / Host: <server>
        jsr mc_Start
        ldx #<sRaGet
        ldy #>sRaGet
        jsr mc_Str
        ldy raBaseOff
bp:     lda RL_BUF,y
        beq tp
        jsr ra_P2A
        jsr mc_Chr
        iny
        bne bp
tp:     ldy #0
tl:     lda (raP),y
        beq hv
        jsr ra_P2A
        jsr mc_Chr
        iny
        bne tl
hv:     ldx #<sRaHttp
        ldy #>sRaHttp
        jsr mc_Str
        ldx #<raHost
        ldy #>raHost
        jsr mc_Sc
        ldx #<sRaEnd
        ldy #>sRaEnd
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
wt:     lda #0                   // tot de server sluit (HTTP/1.0)
        sta raTicks
        sta raTicks+1
        lda frameLo
        sta raF
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
        cmp raF
        beq lp
        sta raF
        inc raTicks
        bne t1
        inc raTicks+1
t1:     lda raTicks+1            // (teller loopt terug naar 0 bij data)
        cmp #>RA_TMO
        bcc lp
        lda raTicks
        cmp #<RA_TMO
        bcc lp
        jsr mn_Close
        ldx #<sMnTime
        ldy #>sMnTime
        clc
        rts
dn:     jsr mn_Close
        lda raOk
        bne o1
        ldx #<sRaNotFound
        ldy #>sRaNotFound
        clc
        rts
o1:     lda raBig
        beq o2
        ldx #<sRaBig
        ldy #>sRaBig
        clc
        rts
o2:     lda raWr+1               // einde = volgende schrijfplek
        sta spEnd
        lda raWr+2
        sta spEnd+1
        cmp #>SP_STAGE           // niets ontvangen?
        bne o3
        lda raWr+1
        bne o3
        ldx #<sMnClosed
        ldy #>sMnClosed
        clc
        rts
o3:     sec
        rts
}

// ra_Rx - ontvangen byte: eerst de HTTP-kop (regels tot een lege regel),
//         dan het bestand.
ra_Rx: {
        ldx #0                   // er komt data: time-out opnieuw
        stx raTicks
        stx raTicks+1
        ldx raSt
        bne body
        cmp #$0d
        beq r
        cmp #$0a
        beq eol
        ldx raLn
        cpx #16
        bcs r
        sta raHl,x
        inc raLn
r:      rts
eol:    lda raLn
        bne ln
        lda #1                   // lege regel: nu het bestand
        sta raSt
        rts
ln:     lda raNr                 // eerste regel: "HTTP/1.1 200 OK"?
        bne nx
        lda raHl+9
        cmp #$32
        bne nx
        lda raHl+10
        cmp #$30
        bne nx
        lda raHl+11
        cmp #$30
        bne nx
        inc raOk
nx:     inc raNr
        lda #0
        sta raLn
        rts
body:   ldx raSkip               // "PS" overslaan (zoals LOAD)
        beq wr
        dec raSkip
        rts
wr:     ldx raWr+2               // tot $7EFF
        cpx #$7f
        bcs big
wrp:    sta $ffff
        inc wrp+1
        bne w1
        inc wrp+2
w1:     rts
big:    lda #1
        sta raBig
        rts
}
.label raWr = ra_Rx.wrp          // schrijfadres (zelfaanpassend)

//--------------------------------------------------------
raMsg:     .word 0
raLast:    .word 0               // laatst gekozen tune (0 = nog geen)
raTicks:   .word 0
raCount:   .byte 0
raPrev:    .byte $ff
raSeed:    .byte 0
raFails:   .byte 0
raHostLen: .byte 0
raBaseOff: .byte 0
raI:       .byte 0
raT:       .byte 0
raAny:     .byte 0
raDig:     .byte 0
raF:       .byte 0
raSt:      .byte 0
raLn:      .byte 0
raOk:      .byte 0
raBig:     .byte 0
raNr:      .byte 0
raSkip:    .byte 0
raHl:      .fill 16, 0
raHost:    .fill 33, $ff
raPort:    .fill 6, $ff          // poort als tekst (schermcodes = cijfers)
raLine:    .fill 41, $ff

raTxtLo:  .byte <sRaT0, <sRaT1, <sRaT2, <sRaT3, <sRaT4, <sRaT5
raTxtHi:  .byte >sRaT0, >sRaT1, >sRaT2, >sRaT3, >sRaT4, >sRaT5
raTxtRow: .byte 3, 5, 6, 7, 12, 15

.encoding "screencode_upper"
sRaT0:    .text "SID RADIO"
          .byte $ff
sRaT1:    .text "MUSIC FROM THE HIGH VOLTAGE SID"
          .byte $ff
sRaT2:    .text "COLLECTION (HVSC), STRAIGHT FROM"
          .byte $ff
sRaT3:    .text "THE INTERNET:"
          .byte $ff
sRaT4:    .text "LAST TUNE:"
          .byte $ff
sRaT5:    .text "SPACE = NEXT, RUN/STOP = STOP"
          .byte $ff
sRaTunes: .text " TUNES IN RADIO.LST"
          .byte $ff
sRaPlay:  .text "PLAY"
          .byte $ff
sRaTune:  .text "TUNING IN..."
          .byte $ff
sRaOff:   .text "RADIO STOPPED"
          .byte $ff
sRaEmpty: .text "NO TUNES: RADIO.LST IS MISSING"
          .byte $ff
sRaNotFound: .text "THE SERVER DOES NOT HAVE THIS TUNE"
          .byte $ff
sRaBig:   .text "THIS TUNE IS TOO BIG"
          .byte $ff
.encoding "ascii"
sRaGet:   .text "GET "
          .byte 0
sRaHttp:  .text " HTTP/1.0"
          .byte $0d, $0a
          .text "Host: "
          .byte 0
sRaEnd:   .byte $0d, $0a
          .text "User-Agent: CD64-Radio"
          .byte $0d, $0a, $0d, $0a, 0
.encoding "screencode_upper"
