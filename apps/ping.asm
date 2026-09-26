#importonce
//========================================================
// apps/ping.asm - PING (INET-menu), eerste echte netwerk-app
// Commodore Desk 64
//
// Zit in dezelfde overlay als NETWORK (inet.prg) en gebruikt diens
// regelbuffer en veld-editor. TARGET staat op NC_PINGIP (niet opgeslagen,
// start op de gateway). START: ARP (MAC van doel of gateway), daarna 4
// echo requests van 1 s. Tijdens het wachten beantwoordt de C64 zelf
// ARP en ping, dus je kunt hem dan ook vanaf de PC pingen.
//========================================================

.const PG_FLD     = 8            // veldindex van TARGET (zie fRow e.d.)
.const PG_BTN_ROW = 5
.const PG_OUT_TOP = 7
.const PG_OUT_BOT = 22
.const PG_COUNT   = 4

ping_Init:
        jsr nc_Load
        lda NC_PINGOK            // eerste keer: doel = gateway
        cmp #'P'
        beq ok
        ldx #3
cp:     lda NC_GW,x
        sta NC_PINGIP,x
        dex
        bpl cp
        lda #'P'
        sta NC_PINGOK
ok:     jmp net_Detect

//--------------------------------------------------------
ping_Draw:
        ldx #PG_FLD
        jsr fld_Line
        lda #<sPgStart
        sta r0
        lda #>sPgStart
        sta r0+1
        lda #IN_COL
        sta a0
        lda #PG_BTN_ROW
        sta a1
        lda #7
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sPgHint
        sta r0
        lda #>sPgHint
        sta r0+1
        lda #IN_COL+9
        sta a0
        lda #PG_BTN_ROW
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText

//--------------------------------------------------------
ping_Click:
        lda evtB
        cmp fRow+PG_FLD
        bne !b+
        lda evtA
        cmp #IN_COL
        bcc !r+
        ldx #PG_FLD
        jmp fe_Edit
!b:     lda #IN_COL
        sta a0
        lda #PG_BTN_ROW
        sta a1
        lda #7
        sta a2
        jsr btn_HitTest
        bcc !r+
        jmp ping_Run
!r:     rts

//--------------------------------------------------------
// ping_Run - ARP + PG_COUNT pings, resultaat regel voor regel.
//--------------------------------------------------------
ping_Run: {
        lda #IN_COL              // uitvoer wissen
        sta a0
        lda #PG_OUT_TOP
        sta a1
        sta inRow
        lda #IN_VCOL+IN_VW-IN_COL
        sta a2
        lda #PG_OUT_BOT-PG_OUT_TOP+1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda #0
        sta netAbort
        lda netPlatform
        cmp #NET_PLAT_RRNET
        beq rr
        ldx #<sPgNoHw            // (Ultimate: TCP/IP via UCI volgt later)
        ldy #>sPgNoHw
        jmp say
rr:     lda csReady
        bne init
        jsr cs_Init
        bcs inOk
        ldx #<sPgChip
        ldy #>sPgChip
        jmp say
inOk:   lda #1
        sta csReady
init:   ldx #3
td:     lda NC_PINGIP,x
        sta ipDst,x
        dex
        bpl td
        jsr ip_NextHop
        // "ARP a.b.c.d"
        ldx #<sPgArp
        ldy #>sPgArp
        jsr lb_Label
        ldx #<arpIp
        ldy #>arpIp
        jsr lb_IpAt
        jsr lb_Show
        jsr arp_Resolve
        bcs arpOk
        ldx #<sPgStop
        ldy #>sPgStop
        lda netAbort
        bne sayJ
        ldx #<sPgNoArp
        ldy #>sPgNoArp
sayJ:   jmp say
arpOk:  ldx #<sPgMac             // "MAC xx:xx:.."
        ldy #>sPgMac
        jsr lb_Label
        ldx #0
mac:    stx inI
        lda arpMac,x
        jsr lb_Hex
        ldx inI
        inx
        cpx #6
        beq macE
        lda #$3a
        jsr lb_Chr
        jmp mac
macE:   jsr lb_Show
        lda #0
        sta pgSent
        sta pgRecv
        sta pingSeq
loop:   inc pingSeq
        lda #0
        sta netFlag
        lda frameLo
        sta pgT0
        jsr ping_Send
        inc pgSent
        lda #50
        jsr net_Wait
        bcs got
        lda netAbort
        beq tmo
        jmp stop
tmo:
        ldx #<sPgSeq             // "SEQ n  TIMEOUT"
        ldy #>sPgSeq
        jsr lb_Label
        lda pingSeq
        jsr lb_Dec
        ldx #<sPgTo
        ldy #>sPgTo
        jsr lb_Str
        jsr lb_Show
        jmp next
got:    inc pgRecv
        lda frameLo
        sec
        sbc pgT0
        sta pgDt
        ldx #<sPgRep             // "REPLY SEQ n  TIME t MS  TTL x"
        ldy #>sPgRep
        jsr lb_Label
        lda pingSeq
        jsr lb_Dec
        ldx #<sPgTime
        ldy #>sPgTime
        jsr lb_Str
        lda pgDt
        bne ms
        lda #$3c                 // "<20"
        jsr lb_Chr
        lda #20
        jsr lb_Dec
        jmp msE
ms:     jsr lb_Ms                // frames * 20
msE:    ldx #<sPgMs
        ldy #>sPgMs
        jsr lb_Str
        lda pingTtl
        jsr lb_Dec
        jsr lb_Show
        lda #50                  // rest van de seconde wachten (blijft
        sec                      // ARP/ping beantwoorden)
        sbc pgDt
        bcc next
        beq next
        ldx #0
        stx netFlag
        jsr net_Wait
        lda netAbort
        bne stop
next:   lda pingSeq
        cmp #PG_COUNT
        bcs sum
        jmp loop
stop:   ldx #<sPgStop
        ldy #>sPgStop
        jsr lb_Label
        jsr lb_Show
sum:    ldx #<sPgSent            // "SENT 4  RECEIVED 4  LOST 0"
        ldy #>sPgSent
        jsr lb_Label
        lda pgSent
        jsr lb_Dec
        ldx #<sPgRecv
        ldy #>sPgRecv
        jsr lb_Str
        lda pgRecv
        jsr lb_Dec
        ldx #<sPgLost
        ldy #>sPgLost
        jsr lb_Str
        lda pgSent
        sec
        sbc pgRecv
        jsr lb_Dec
        jmp lb_Show
say:    jsr lb_Label
        jmp lb_Show
}

// lb_IpAt - IP-adres (4 bytes op X/Y) als a.b.c.d achter de buffer.
lb_IpAt: {
        stx ck2
        sty ck2+1
        ldy #0
lp:     sty inCnt
        lda (ck2),y
        jsr lb_Dec
        ldy inCnt
        iny
        cpy #4
        beq done
        lda #$2e
        jsr lb_Chr
        jmp lp
done:   rts
}

// lb_Ms - A frames (1-255) * 20 ms decimaal achter de buffer.
lb_Ms: {
        sta msLo                 // *20 = *16 + *4
        lda #0
        sta msHi
        asl msLo
        rol msHi
        asl msLo
        rol msHi                 // *4
        lda msLo
        sta msT
        lda msHi
        sta msT+1
        asl msLo
        rol msHi
        asl msLo
        rol msHi                 // *16
        lda msLo
        clc
        adc msT
        sta msLo
        lda msHi
        adc msT+1
        sta msHi
        ldx #0                   // 16-bit decimaal, zonder voorloopnullen
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
        jsr lb_Chr
        inc msAny
nx:     inx
        cpx #5
        bne dg
        rts
}
d16Lo: .byte <10000, <1000, <100, <10, <1
d16Hi: .byte >10000, >1000, >100, >10, >1

//--------------------------------------------------------
csReady: .byte 0
pgSent:  .byte 0
pgRecv:  .byte 0
pgT0:    .byte 0
pgDt:    .byte 0
msLo:    .byte 0
msHi:    .byte 0
msT:     .word 0
msDig:   .byte 0
msAny:   .byte 0

.encoding "screencode_upper"
sPgStart: .text "START"
          .byte $ff
sPgHint:  .text "ESC STOPS"
          .byte $ff
sPgNoHw:  .text "NO RR-NET FOUND (SEE NETWORK)"
          .byte $ff
sPgChip:  .text "CS8900 INIT FAILED"
          .byte $ff
sPgArp:   .text "ARP  "
          .byte $ff
sPgMac:   .text "MAC  "
          .byte $ff
sPgNoArp: .text "NO ANSWER (ARP)"
          .byte $ff
sPgStop:  .text "STOPPED"
          .byte $ff
sPgSeq:   .text "SEQ "
          .byte $ff
sPgTo:    .text "  TIMEOUT"
          .byte $ff
sPgRep:   .text "REPLY SEQ "
          .byte $ff
sPgTime:  .text "  "
          .byte $ff
sPgMs:    .text " MS  TTL "
          .byte $ff
sPgSent:  .text "SENT "
          .byte $ff
sPgRecv:  .text "  RECEIVED "
          .byte $ff
sPgLost:  .text "  LOST "
          .byte $ff
