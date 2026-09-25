#importonce
//========================================================
// apps/inet.asm - INET (Milestone 1: netwerk-drivertest)
// Commodore Desk 64
//
// Overlay op $8000. Detecteert bij openen het netwerkplatform
// (Ultimate UCI -> RR-Net/CS8900) en toont het resultaat plus de
// statische netwerkconfiguratie. RESCAN zoekt opnieuw.
// De drivers staan in net/ en worden in dit overlay meegeassembleerd.
//========================================================

.const IN_COL = 4                // kolom van alle regels
.const IN_BTN_ROW = 18

// inet_Init - bij openen: hardware zoeken.
inet_Init:
        jmp net_Detect

//--------------------------------------------------------
// inet_Draw - drivertest-scherm.
//--------------------------------------------------------
inet_Draw: {
        lda #<sInTitle
        sta r0
        lda #>sInTitle
        sta r0+1
        lda #IN_COL
        sta a0
        lda #3
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText

        // PLATFORM
        lda #5
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

        lda netPlatform
        cmp #NET_PLAT_ULTIMATE
        bne notUlt
        // UCI : FOUND / INTERFACE: $DFxx
        ldx #<lUci
        ldy #>lUci
        jsr lb_Label
        ldx #<sFnd
        ldy #>sFnd
        jsr lb_Str
        jsr lb_Show
        ldx #<lIface
        ldy #>lIface
        jsr lb_Label
        lda uciBase+1
        ldx uciBase
        jsr lb_Addr
        jsr lb_Show
        jmp status
notUlt: cmp #NET_PLAT_RRNET
        bne none
        // BASE / CS8900 : FOUND / ID $630E REV $xx
        ldx #<lBase
        ldy #>lBase
        jsr lb_Label
        lda #>CS_BASE
        ldx #<CS_BASE
        jsr lb_Addr
        jsr lb_Show
        ldx #<lCs
        ldy #>lCs
        jsr lb_Label
        ldx #<sFnd
        ldy #>sFnd
        jsr lb_Str
        jsr lb_Show
        ldx #<lId
        ldy #>lId
        jsr lb_Label
        lda #CS_PRODUCT_HI
        ldx #CS_PRODUCT_LO
        jsr lb_Addr
        ldx #<sCsRev
        ldy #>sCsRev
        jsr lb_Str
        lda #$24                 // $
        jsr lb_Chr
        lda csRev
        jsr lb_Hex
        jsr lb_Show
        jmp status
none:   // niets gevonden (of in de cart-build niet gezocht)
        lda netError
        cmp #NET_ERR_IO_BUSY
        beq busy
        ldx #<lUci
        ldy #>lUci
        jsr lb_Label
        ldx #<sNotFnd
        ldy #>sNotFnd
        jsr lb_Str
        jsr lb_Show
        ldx #<lCs
        ldy #>lCs
        jsr lb_Label
        ldx #<sNotFnd
        ldy #>sNotFnd
        jsr lb_Str
        jsr lb_Show
        jmp status
busy:   ldx #<lIo
        ldy #>lIo
        jsr lb_Label
        ldx #<sInCart
        ldy #>sInCart
        jsr lb_Str
        jsr lb_Show

status: inc inRow                // lege regel
        ldx #<lStatus
        ldy #>lStatus
        jsr lb_Label
        ldx netError
        lda errLo,x
        ldy errHi,x
        tax
        jsr lb_Str
        jsr lb_Show

        // statische netwerkconfig
        lda #12
        sta inRow
        ldx #<lIp
        ldy #>lIp
        jsr lb_Label
        ldx #0
        jsr lb_Ip
        ldx #<lMask
        ldy #>lMask
        jsr lb_Label
        ldx #4
        jsr lb_Ip
        ldx #<lGw
        ldy #>lGw
        jsr lb_Label
        ldx #8
        jsr lb_Ip
        ldx #<lDns
        ldy #>lDns
        jsr lb_Label
        ldx #12
        jsr lb_Ip
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

        // RESCAN-knop
        lda #<sInRescan
        sta r0
        lda #>sInRescan
        sta r0+1
        lda #IN_COL
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
// inet_Click - RESCAN.
//--------------------------------------------------------
inet_Click:
        lda #IN_COL
        sta a0
        lda #IN_BTN_ROW
        sta a1
        lda #8
        sta a2
        jsr btn_HitTest
        bcc !+
        jsr net_Detect
        jmp shell_DrawAll
!:      rts

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
        rts
}
lb_Ip: {                         // X = offset in netIp..netDns -> "a.b.c.d"
        stx inI
        lda #4
        sta inCnt
lp:     ldx inI
        lda netIp,x
        jsr lb_Dec
        inc inI
        dec inCnt
        beq done
        lda #$2e                 // .
        jsr lb_Chr
        jmp lp
done:   jmp lb_Show
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
inRow:   .byte 0
inI:     .byte 0
inCnt:   .byte 0
inNum:   .byte 0
inDig:   .byte 0
lbX:     .byte 0
lbSaveX: .byte 0
lineBuf: .fill 36, 0
decTab:  .byte 100, 10, 1

platLo: .byte <pNone, <pUlt, <pRr
platHi: .byte >pNone, >pUlt, >pRr
errLo:  .byte <eOk, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eNoDev, <eBusy
errHi:  .byte >eOk, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eNoDev, >eBusy
.assert "errLo dekt alle NET_ERR-codes", errHi - errLo, NET_ERR_IO_BUSY + 1

.encoding "screencode_upper"
sInTitle:    .text "C64 NETWORK DRIVER TEST"
           .byte $ff
lPlat:     .text "PLATFORM : "
           .byte $ff
lBase:     .text "BASE     : "
           .byte $ff
lCs:       .text "CS8900   : "
           .byte $ff
lId:       .text "ID       : "
           .byte $ff
lUci:      .text "UCI      : "
           .byte $ff
lIface:    .text "INTERFACE: "
           .byte $ff
lIo:       .text "I/O      : "
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
pNone:     .text "NONE"
           .byte $ff
pUlt:      .text "ULTIMATE"
           .byte $ff
pRr:       .text "RR-NET"
           .byte $ff
sFnd:    .text "FOUND"
           .byte $ff
sNotFnd: .text "NOT FOUND"
           .byte $ff
sCsRev:      .text " REV "
           .byte $ff
sInCart:     .text "IN USE BY CARTRIDGE"
           .byte $ff
eOk:       .text "READY"
           .byte $ff
eNoDev:    .text "NO NETWORK HARDWARE"
           .byte $ff
eBusy:     .text "NOT SCANNED"
           .byte $ff
sInRescan:   .text "RESCAN"
           .byte $ff
