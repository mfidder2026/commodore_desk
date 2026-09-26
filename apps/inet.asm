#importonce
//========================================================
// apps/inet.asm - NETWORK (INET-menu): status + alle instellingen
// Commodore Desk 64
//
// Overlay op $8000. Bovenaan de gevonden netwerkhardware (Ultimate UCI
// of RR-Net/CS8900), daaronder alle instellingen op één plek: IP-config
// en de CHAT-server (OpenAI-compatibel: host, poort, API-key, model).
// Klik een waarde om hem te typen; SAVE schrijft NET.CFG. De drivers en
// NETCFG ($C400) staan in net/ en worden door PING/CHAT gedeeld.
//========================================================

.const IN_COL  = 4               // kolom van de labels
.const IN_VCOL = 15              // kolom van de waarden
.const IN_VW   = 22              // zichtbare breedte van een waarde (kol 15-36)
.const IN_BTN_ROW = 21
.const NUM_FLD = 8

// veldtypes
.const FT_IP   = 0
.const FT_TEXT = 1
.const FT_NUM  = 2
.const FT_KEY  = 3               // tekst, gemaskeerd getoond

// inet_Init - bij openen: config laden en hardware zoeken.
inet_Init:
        jsr nc_Load
        jmp net_Detect

//--------------------------------------------------------
// inet_Draw - status, instellingen en knoppen.
//--------------------------------------------------------
inet_Draw: {
        // PLATFORM
        lda #3
        sta inRow
        ldx #<lPlat
        ldy #>lPlat
        jsr lb_Label
        ldx netPlatform
        lda platLo,x
        ldy platHi,x
        tax
        jsr lb_Str
        jsr lb_Show
        // DEVICE
        ldx #<lDev
        ldy #>lDev
        jsr lb_Label
        lda netPlatform
        cmp #NET_PLAT_ULTIMATE
        bne notUlt
        ldx #<sUci               // "UCI $DF1C"
        ldy #>sUci
        jsr lb_Str
        lda uciBase+1
        ldx uciBase
        jsr lb_Addr
        jmp devEnd
notUlt: cmp #NET_PLAT_RRNET
        bne none
        ldx #<sCs                // "CS8900 $DE00 REV $09"
        ldy #>sCs
        jsr lb_Str
        lda #>CS_BASE
        ldx #<CS_BASE
        jsr lb_Addr
        ldx #<sCsRev
        ldy #>sCsRev
        jsr lb_Str
        lda #$24                 // $
        jsr lb_Chr
        lda csRev
        jsr lb_Hex
        jmp devEnd
none:   ldx #<sNotFnd
        ldy #>sNotFnd
        lda netError
        cmp #NET_ERR_IO_BUSY
        bne nf
        ldx #<sInCart
        ldy #>sInCart
nf:     jsr lb_Str
devEnd: jsr lb_Show
        // STATUS
        ldx #<lStatus
        ldy #>lStatus
        jsr lb_Label
        ldx netError
        lda errLo,x
        ldy errHi,x
        tax
        jsr lb_Str
        jsr lb_Show

        // alle instelvelden
        ldx #0
fl:     stx inI
        jsr fld_Line
        ldx inI
        inx
        cpx #NUM_FLD
        bne fl
        // MAC (vast)
        lda #11
        sta inRow
        ldx #<lMac
        ldy #>lMac
        jsr lb_Label
        lda #0
        sta inI
mac:    ldx inI
        lda netMac,x
        jsr lb_Hex
        inc inI
        lda inI
        cmp #6
        beq macEnd
        lda #$3a                 // :
        jsr lb_Chr
        jmp mac
macEnd: jsr lb_Show
        // kopje CHAT-server
        lda #<sChatHdr
        sta r0
        lda #>sChatHdr
        sta r0+1
        lda #IN_COL
        sta a0
        lda #13
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        // hint
        lda #<sHint
        sta r0
        lda #>sHint
        sta r0+1
        lda #IN_COL
        sta a0
        lda #19
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        // knoppen
        lda #<sInSave
        sta r0
        lda #>sInSave
        sta r0+1
        lda #IN_COL
        sta a0
        lda #IN_BTN_ROW
        sta a1
        lda #6
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sInRescan
        sta r0
        lda #>sInRescan
        sta r0+1
        lda #IN_COL+8
        sta a0
        lda #IN_BTN_ROW
        sta a1
        lda #8
        sta a2
        lda TH_accent
        sta a3
        jmp btn_Draw
}

//--------------------------------------------------------
// inet_Click - SAVE / RESCAN / klik op een waarde.
//--------------------------------------------------------
inet_Click: {
        lda evtB
        cmp #IN_BTN_ROW
        bne fields
        lda #IN_COL              // SAVE
        sta a0
        lda #IN_BTN_ROW
        sta a1
        lda #6
        sta a2
        jsr btn_HitTest
        bcc resc
        jsr nc_Save
        ldx #<sNcSaved
        ldy #>sNcSaved
        bcc msg
        ldx #<sNcSaveErr
        ldy #>sNcSaveErr
msg:    stx r0
        sty r0+1
        lda #IN_COL+18
        sta a0
        lda #IN_BTN_ROW
        sta a1
        lda TH_text
        sta a2
        jmp gfx_DrawText
resc:   lda #IN_COL+8            // RESCAN
        sta a0
        lda #6+2
        sta a2
        jsr btn_HitTest
        bcc no
        jsr net_Detect
        jmp shell_DrawAll
fields: lda evtA
        cmp #IN_COL
        bcc no
        ldx #0
fl:     lda fRow,x
        cmp evtB
        bne nx
        jmp fe_Edit
nx:     inx
        cpx #NUM_FLD
        bne fl
no:     rts
}

//--------------------------------------------------------
// fld_Line - label + waarde van veld X op zijn rij (rij eerst gewist).
//--------------------------------------------------------
fld_Line: {
        stx fldI
        lda #IN_COL              // rij wissen (labels + waarde)
        sta a0
        lda fRow,x
        sta a1
        sta inRow
        lda #IN_VCOL+IN_VW-IN_COL
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        ldx fldI
        lda fLblLo,x
        ldy fLblHi,x
        tax
        jsr lb_Label
        lda #0
        sta feRaw
        jsr fld_Text
        jmp lb_Show
}

// fld_Text - waarde van veld fldI achter de regelbuffer plakken.
//            feRaw=1: de API-key onversleuteld (voor het bewerken).
fld_Text: {
        ldx fldI
        lda fOff,x
        sta fOffs
        lda fType,x
        bne notIp
        lda #4                   // IP: a.b.c.d
        sta inCnt
ip:     ldx fOffs
        lda NETCFG,x
        jsr lb_Dec
        inc fOffs
        dec inCnt
        beq done
        lda #$2e                 // .
        jsr lb_Chr
        jmp ip
notIp:  cmp #FT_KEY
        bne text
        lda feRaw
        bne text
        ldx fOffs                // gemaskeerd: '*' per teken, '-' als leeg
        lda NETCFG,x
        cmp #$ff
        bne stars
        lda #$2d
        jmp lb_Chr
stars:  lda NETCFG,x
        cmp #$ff
        beq done
        lda lbX
        cmp #IN_VCOL-IN_COL+IN_VW
        bcs done
        lda #$2a                 // *
        jsr lb_Chr
        inx
        bne stars
text:   ldx fOffs
tl:     lda NETCFG,x
        cmp #$ff
        beq done
        ldy feRaw                // bewerken: alles; tonen: tot de rand
        bne tput
        ldy lbX
        cpy #IN_VCOL-IN_COL+IN_VW
        bcs done
tput:   jsr lb_Chr
        inx
        bne tl
done:   rts
}

//--------------------------------------------------------
// fe_Edit - veld X bewerken. Typen voegt achteraan toe, DEL wist,
//           RETURN of een klik = overnemen, ESC = annuleren.
//--------------------------------------------------------
fe_Edit: {
        stx fldI
        lda #0                   // huidige waarde als tekst ophalen
        sta lbX
        lda #1
        sta feRaw
        jsr fld_Text
        lda lbX
        sta feLen
        tax
        beq draw
cp:     dex
        lda lineBuf,x
        sta feBuf,x
        cpx #0
        bne cp
draw:   // zichtbaar stuk: de laatste IN_VW-1 tekens + cursorblok
        lda #0
        sta lbX
        lda feLen
        sec
        sbc #IN_VW-1
        bcs st
        lda #0
st:     tax
vis:    cpx feLen
        beq cur
        lda feBuf,x
        jsr lb_Chr
        inx
        bne vis
cur:    lda #$a0                 // cursor = blok
        jsr lb_Chr
pad:    lda lbX
        cmp #IN_VW
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
        lda #IN_VCOL
        sta a0
        ldx fldI
        lda fRow,x
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
wait:   jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        beq accept
        cmp #EVT_KEY
        bne wait
        lda evtA
        cmp #$80                 // RETURN
        beq accept
        cmp #$82                 // ESC
        beq cancel
        cmp #$81                 // DEL
        bne chr
        lda feLen
        beq wait
        dec feLen
        jmp draw
chr:    cmp #$80                 // overige besturingstoetsen
        bcs wait
        cmp #$20                 // geen spaties
        beq wait
        cmp #0
        beq wait
        jsr fe_Allowed
        bcc wait
        sta feChr
        ldx fldI
        lda feLen
        cmp fMax,x
        bcs wait                 // vol
        tay
        lda feChr
        sta feBuf,y
        inc feLen
        jmp draw
cancel: ldx fldI
        jmp fld_Line
accept: ldx fldI
        lda fType,x
        bne notIp
        jsr ip_Parse             // IP: 4 getallen 0-255
        bcc bad
        ldx fldI
        ldy fOff,x
        ldx #0
ipc:    lda ipTmp,x
        sta NETCFG,y
        iny
        inx
        cpx #4
        bne ipc
        jmp fin
notIp:  cmp #FT_NUM              // poort: minstens één cijfer
        bne store
        lda feLen
        beq bad
store:  ldy fOff,x
        ldx #0
sc:     cpx feLen
        beq term
        lda feBuf,x
        sta NETCFG,y
        iny
        inx
        bne sc
term:   lda #$ff
        sta NETCFG,y
fin:    ldx fldI
        jmp fld_Line
bad:    jsr sid_Click
        jmp wait
}

// fe_Allowed - mag teken A in dit veld? Carry=1 ja (A blijft).
fe_Allowed: {
        ldx fldI
        ldy fType,x
        cmp #$30
        bcc notDig
        cmp #$3a
        bcc yes                  // cijfer mag overal
notDig: cpy #FT_NUM
        beq no
        cpy #FT_IP
        bne yes
        cmp #$2e                 // IP: alleen nog de punt
        beq yes
no:     clc
        rts
yes:    sec
        rts
}

// ip_Parse - feBuf/feLen "a.b.c.d" -> ipTmp[4]. Carry=1 geldig.
ip_Parse: {
        ldx #0                   // X = positie in feBuf
        ldy #0                   // Y = octet
oct:    lda #0
        sta ipVal
        sta ipDig
dig:    cpx feLen
        beq endOct
        lda feBuf,x
        cmp #$2e
        beq endOct
        and #$0f
        sta ipD
        lda ipVal                // val = val*10 + cijfer, max 255
        cmp #26
        bcs bad
        asl
        sta ipT
        asl
        asl
        adc ipT
        adc ipD
        bcs bad
        sta ipVal
        inx
        inc ipDig
        lda ipDig
        cmp #4
        bcs bad
        jmp dig
endOct: lda ipDig
        beq bad
        lda ipVal
        sta ipTmp,y
        iny
        cpy #4
        beq last
        cpx feLen                // na octet 1-3 moet een punt komen
        beq bad
        inx
        jmp oct
last:   cpx feLen                // na octet 4: klaar
        bne bad
        sec
        rts
bad:    clc
        rts
}

//--------------------------------------------------------
// Regelbuffer: lb_Label begint een regel met een label, de
// andere routines plakken er iets achter, lb_Show tekent hem op
// rij inRow en schuift een rij op.
//--------------------------------------------------------
lb_Label:                        // X/Y = label
        lda #0
        sta lbX
lb_Str: {                        // X/Y = $ff-getermineerde string
        stx r0
        sty r0+1
        ldy #0
lp:     lda (r0),y
        cmp #$ff
        beq done
        jsr lb_Chr
        iny
        bne lp
done:   rts
}
lb_Chr: {                        // A -> buffer (bewaart X, Y)
        stx lbSaveX
        ldx lbX
        sta lineBuf,x
        inc lbX
        ldx lbSaveX
        rts
}
lb_Hex: {                        // A -> 2 hex-cijfers
        pha
        lsr
        lsr
        lsr
        lsr
        jsr nib
        pla
        and #$0f
nib:    cmp #10
        bcc dig
        sbc #9                   // A-F -> schermcode 1-6 (carry=1)
        jmp lb_Chr
dig:    ora #$30
        jmp lb_Chr
}
lb_Addr:                         // "$" + A (hi) + X (lo) in hex
        pha
        lda #$24
        jsr lb_Chr
        pla
        jsr lb_Hex
        txa
        jmp lb_Hex
lb_Dec: {                        // A -> decimaal zonder voorloopnullen
        stx lbSaveX2
        ldy #0                   // Y = "al een cijfer geschreven"
        ldx #0
dlp:    sta inNum
        lda #$30
        sta inDig
        lda inNum
sub:    cmp decTab,x
        bcc put
        sbc decTab,x
        inc inDig
        jmp sub
put:    sta inNum
        lda inDig
        cpx #2                   // laatste cijfer altijd tonen
        beq show
        cmp #$30
        bne show
        cpy #0
        beq next
show:   jsr lb_Chr
        ldy #1
next:   lda inNum
        inx
        cpx #3
        bne dlp
        ldx lbSaveX2
        rts
}
lb_Show:
        ldx lbX
        lda #$ff
        sta lineBuf,x
        lda #<lineBuf
        sta r0
        lda #>lineBuf
        sta r0+1
        lda #IN_COL
        sta a0
        lda inRow
        sta a1
        lda TH_text
        sta a2
        inc inRow
        jmp gfx_DrawText

//--------------------------------------------------------
inRow:    .byte 0
inI:      .byte 0
inCnt:    .byte 0
inNum:    .byte 0
inDig:    .byte 0
lbX:      .byte 0
lbSaveX:  .byte 0
lbSaveX2: .byte 0
fldI:     .byte 0
fOffs:    .byte 0
feRaw:    .byte 0
feLen:    .byte 0
feChr:    .byte 0
ipVal:    .byte 0
ipDig:    .byte 0
ipD:      .byte 0
ipT:      .byte 0
ipTmp:    .fill 4, 0
lineBuf:  .fill 48, 0
feBuf:    .fill 48, 0
decTab:   .byte 100, 10, 1

// velden: rij, type, max. lengte, offset in NETCFG, label
fRow:   .byte 7, 8, 9, 10, 14, 15, 16, 17
fType:  .byte FT_IP, FT_IP, FT_IP, FT_IP, FT_TEXT, FT_NUM, FT_KEY, FT_TEXT
fMax:   .byte 15, 15, 15, 15, 32, 5, 40, 32
fOff:   .byte NC_IP-NETCFG, NC_MASK-NETCFG, NC_GW-NETCFG, NC_DNS-NETCFG
        .byte NC_HOST-NETCFG, NC_PORT-NETCFG, NC_KEY-NETCFG, NC_MODEL-NETCFG
fLblLo: .byte <lIp, <lMask, <lGw, <lDns, <lHost, <lPort, <lKey, <lModel
fLblHi: .byte >lIp, >lMask, >lGw, >lDns, >lHost, >lPort, >lKey, >lModel

platLo: .byte <pNone, <pUlt, <pRr
platHi: .byte >pNone, >pUlt, >pRr
errLo:  .byte <eOk, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eBusy
errHi:  .byte >eOk, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eBusy
.assert "errLo dekt alle NET_ERR-codes", errHi - errLo, NET_ERR_IO_BUSY + 1

.encoding "screencode_upper"
lPlat:     .text "PLATFORM : "
           .byte $ff
lDev:      .text "DEVICE   : "
           .byte $ff
lStatus:   .text "STATUS   : "
           .byte $ff
lIp:       .text "IP       : "
           .byte $ff
lMask:     .text "MASK     : "
           .byte $ff
lGw:       .text "GATEWAY  : "
           .byte $ff
lDns:      .text "DNS      : "
           .byte $ff
lMac:      .text "MAC      : "
           .byte $ff
lHost:     .text "HOST     : "
           .byte $ff
lPort:     .text "PORT     : "
           .byte $ff
lKey:      .text "API KEY  : "
           .byte $ff
lModel:    .text "MODEL    : "
           .byte $ff
pNone:     .text "NONE"
           .byte $ff
pUlt:      .text "ULTIMATE"
           .byte $ff
pRr:       .text "RR-NET"
           .byte $ff
sUci:      .text "UCI "
           .byte $ff
sCs:       .text "CS8900 "
           .byte $ff
sCsRev:    .text " REV "
           .byte $ff
sNotFnd:   .text "NOT FOUND"
           .byte $ff
sInCart:   .text "IN USE BY CARTRIDGE"
           .byte $ff
eOk:       .text "READY"
           .byte $ff
eNoDev:    .text "NO NETWORK HARDWARE"
           .byte $ff
eBusy:     .text "NOT SCANNED"
           .byte $ff
sChatHdr:  .text "CHAT SERVER (OPENAI API)"
           .byte $ff
sHint:     .text "CLICK A VALUE TO CHANGE IT"
           .byte $ff
sInSave:   .text "SAVE"
           .byte $ff
sInRescan: .text "RESCAN"
           .byte $ff
sNcSaved:    .text "SAVED      "
           .byte $ff
sNcSaveErr:  .text "SAVE FAILED"
           .byte $ff
