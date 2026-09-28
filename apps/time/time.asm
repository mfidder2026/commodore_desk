#importonce
//========================================================
// apps/time/time.asm - DATUM EN TIJD (SYSTEM -> TIME)
// Commodore Desk 64
//
// Toont datum en tijd, de tijdzone (keuzelijst met alle zones, zie
// tzdata.asm), de tijdserver en "SYNC AT START". SYNC NOW haalt de tijd
// via NTP (ntp.asm) en zet de klok (CIA-TOD + datum in de Core).
// SAVE schrijft alles naar CD64.CFG (CFG_tz, CFG_timeAuto, CFG_ntp).
// ti_Auto draait na een koude start als SYNC AT START aan staat (de Core
// laadt dan deze overlay, kernel/clock.asm: time_Boot).
//
// Rekenwerk: NTP-seconden - (1900 -> 2000) + zone -> dagen/uur/min/sec
// -> jaar/maand/dag. Zomertijd wordt op de lokale standaardtijd bepaald
// (regels in tiDst*); zo ja: een uur erbij en de datum opnieuw.
//========================================================

.const TI_COL    = 3
.const TI_VCOL   = 18
.const TI_R_DATE = 3
.const TI_R_TIME = 4
.const TI_R_TZL  = 6
.const TI_R_TZ   = 7
.const TI_R_DST  = 8
.const TI_R_SRVL = 10
.const TI_R_SRV  = 11
.const TI_R_AUTO = 13
.const TI_R_NOTE = 14
.const TI_R_BTN  = 17
.const TI_R_MSG  = 20
.const TI_ZW     = 34            // breedte van een zoneregel
.const TP_TOP    = 4             // keuzelijst: eerste rij
.const TP_VIS    = 15
.const TP_R_BTN  = 20
.const TI_HELP   = 17            // F1-context (gui/help.txt)
.label tiP       = r5            // zeropage: naam van een zone

// ti_Init - bij het openen.
ti_Init:
        lda #TI_HELP
        sta helpCtx
        lda #0
        sta tiMsg+1
        jmp ti_SrvDefault

// ti_Key - geen eigen toetsen (SPATIE/RETURN = klik op de cursor).
ti_Key:
        clc
        rts

//--------------------------------------------------------
// ti_Draw
//--------------------------------------------------------
ti_Draw: {
        ldx #<sTiDate
        ldy #>sTiDate
        lda #TI_R_DATE
        jsr ti_Label
        jsr clk_Read             // "28-09-2026" / "14:05:33"
        ldx #0
        lda clkDay
        jsr ti_Bcd
        jsr ti_Dash
        lda clkMon
        jsr ti_Bcd
        jsr ti_Dash
        lda clkYearHi
        jsr ti_Bcd
        lda clkYearLo
        jsr ti_Bcd
        lda #TI_R_DATE
        jsr ti_Value
        ldx #<sTiTime
        ldy #>sTiTime
        lda #TI_R_TIME
        jsr ti_Label
        ldx #0
        lda clkHour
        jsr ti_Bcd
        jsr ti_Colon
        lda clkMin
        jsr ti_Bcd
        jsr ti_Colon
        lda TOD_SEC
        jsr ti_Bcd
        lda #TI_R_TIME
        jsr ti_Value
        ldx #<sTiZone            // TIME ZONE
        ldy #>sTiZone
        lda #TI_R_TZL
        jsr ti_Label
        ldx CFG_tz
        cpx #TZ_N
        bcc zk
        ldx #TZ_DEFAULT
        stx CFG_tz
zk:     jsr ti_ZoneText          // als veld: klik = keuzelijst
        lda #<tiLine
        sta r0
        lda #>tiLine
        sta r0+1
        lda #TI_COL
        sta a0
        lda #TI_R_TZ
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawTextRev
        ldx #<sTiDst             // SUMMER TIME: EU
        ldy #>sTiDst
        lda #TI_R_DST
        jsr ti_Label
        ldx CFG_tz
        ldy tzRule,x
        ldx tiDstLo,y
        lda tiDstHi,y
        tay
        lda #TI_R_DST
        jsr ti_ValueXY
        ldx #<sTiSrv             // TIME SERVER
        ldy #>sTiSrv
        lda #TI_R_SRVL
        jsr ti_Label
        jsr ti_Field
        lda #0
        sta liOn
        jsr li_Show
        ldx #<sTiAuto            // SYNC AT START  [ON ]
        ldy #>sTiAuto
        lda #TI_R_AUTO
        jsr ti_Label
        ldx #<sTiOff
        ldy #>sTiOff
        lda CFG_timeAuto
        beq ao
        ldx #<sTiOn
        ldy #>sTiOn
ao:     stx r0
        sty r0+1
        lda #TI_VCOL
        sta a0
        lda #TI_R_AUTO
        sta a1
        lda #5
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx #<sTiNote
        ldy #>sTiNote
        lda #TI_R_NOTE
        jsr ti_Label
        ldx #0                   // knoppen
bl:     stx tiI
        lda tbLo,x
        sta r0
        lda tbHi,x
        sta r0+1
        lda tbCol,x
        sta a0
        lda #TI_R_BTN
        sta a1
        lda tbW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx tiI
        inx
        cpx #2
        bne bl
        jmp ti_ShowMsg
}

// ti_Label - tekst X/Y op rij A, kolom TI_COL.
ti_Label:
        sta a1
        stx r0
        sty r0+1
        lda #TI_COL
        sta a0
        lda TH_text
        sta a2
        jmp gfx_DrawText

// ti_Value - tiLine (X tekens) op rij A in de waardekolom.
ti_Value:
        pha
        lda #$ff
        sta tiLine,x
        pla
        ldx #<tiLine
        ldy #>tiLine
ti_ValueXY:
        sta a1
        stx r0
        sty r0+1
        lda #TI_VCOL
        sta a0
        lda TH_accent
        sta a2
        jmp gfx_DrawText

// ti_Bcd - BCD A als twee cijfers naar tiLine,x.
ti_Bcd:
        pha
        lsr
        lsr
        lsr
        lsr
        ora #$30
        sta tiLine,x
        inx
        pla
        and #$0f
        ora #$30
        sta tiLine,x
        inx
        rts
ti_Dash:
        lda #$2d
        .byte $2c
ti_Colon:
        lda #$3a
        sta tiLine,x
        inx
        rts

// ti_Field - invoerveld voor de tijdserver.
ti_Field:
        lda #<CFG_ntp
        sta r3
        lda #>CFG_ntp
        sta r3+1
        lda #31
        sta liMax
        lda #TI_COL
        sta liCol
        lda #TI_R_SRV
        sta liRow
        lda #TI_ZW
        sta liVis
        rts

// ti_SrvDefault - lege tijdserver -> POOL.NTP.ORG.
ti_SrvDefault: {
        lda CFG_ntp
        cmp #$ff
        bne r
        ldx #0
cc:      lda sTiPool,x
        sta CFG_ntp,x
        inx
        cmp #$ff
        bne cc
r:      rts
}

// ti_ZoneText - zone X -> tiLine: "UTC+01:00 AMSTERDAM, BERLIN, PARIS",
//               aangevuld tot TI_ZW tekens.
ti_ZoneText: {
        stx tiI
        lda #$15                 // U T C
        sta tiLine
        lda #$14
        sta tiLine+1
        lda #$03
        sta tiLine+2
        lda tzQ,x
        ldy #$2b                 // +
        cmp #$80
        bcc pos
        eor #$ff
        clc
        adc #1
        ldy #$2d                 // -
pos:    sty tiLine+3
        sta tiT7
        lsr                      // uren
        lsr
        ldx #4
        jsr ti_Dec2
        lda #$3a
        sta tiLine,x
        inx
        lda tiT7                 // minuten: 00 15 30 45
        and #3
        tay
        lda tiQm1,y
        sta tiLine,x
        inx
        lda tiQm2,y
        sta tiLine,x
        inx
        lda #$20
        sta tiLine,x
        inx
        ldy tiI
        lda tzNameLo,y
        sta tiP
        lda tzNameHi,y
        sta tiP+1
        ldy #0
nm:     lda (tiP),y
        cmp #$ff
        beq pad
        sta tiLine,x
        inx
        iny
        bne nm
pad:    lda #$20
p1:     cpx #TI_ZW
        bcs e
        sta tiLine,x
        inx
        bne p1
e:      lda #$ff
        sta tiLine,x
        rts
}
tiQm1:  .byte $30, $31, $33, $34
tiQm2:  .byte $30, $35, $30, $35

// ti_Dec2 - A (0-99) als twee cijfers naar tiLine,x.
ti_Dec2: {
        ldy #$30
t:      cmp #10
        bcc o
        sbc #10
        iny
        bne t
o:      pha
        tya
        sta tiLine,x
        inx
        pla
        ora #$30
        sta tiLine,x
        inx
        rts
}

// ti_Say / ti_ShowMsg - meldingsregel.
ti_Say:
        stx tiMsg
        sty tiMsg+1
ti_ShowMsg: {
        lda #TI_COL
        sta a0
        lda #TI_R_MSG
        sta a1
        lda #TI_ZW
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda tiMsg+1
        beq r
        sta r0+1
        lda tiMsg
        sta r0
        lda #TI_COL
        sta a0
        lda #TI_R_MSG
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
r:      rts
}

//--------------------------------------------------------
// ti_Click
//--------------------------------------------------------
ti_Click: {
        lda evtB
        cmp #TI_R_TZ             // zone -> keuzelijst
        bne c1
        jmp ti_Pick
c1:     cmp #TI_R_SRV            // tijdserver bewerken
        bne c2
        jsr ti_Field
        jsr li_Edit
        php
        jsr ti_SrvDefault
        plp
        bcc r
        jmp ti_Click             // (klik die het typen beeindigde)
c2:     lda #TI_VCOL             // SYNC AT START aan/uit
        sta a0
        lda #TI_R_AUTO
        sta a1
        lda #5
        sta a2
        jsr btn_HitTest
        bcc c3
        lda CFG_timeAuto
        eor #1
        sta CFG_timeAuto
        ldx #<sTiSaveHint
        ldy #>sTiSaveHint
        stx tiMsg
        sty tiMsg+1
        jmp shell_DrawAll
c3:     ldx #0                   // knoppen
bl:     stx tiI
        lda tbCol,x
        sta a0
        lda #TI_R_BTN
        sta a1
        lda tbW,x
        sta a2
        jsr btn_HitTest
        bcs btn
        ldx tiI
        inx
        cpx #2
        bne bl
r:      rts
btn:    lda tiI
        bne save
        jmp ti_SyncNow
save:   jsr cfg_Save
        ldx #<sTiSaved
        ldy #>sTiSaved
        jmp ti_Say
}

// ti_SyncNow - SYNC NOW.
ti_SyncNow: {
        ldx #<sTiAsk
        ldy #>sTiAsk
        jsr ti_Say
        jsr ti_Sync
        bcs ok
        jmp ti_Say
ok:     ldx #<sTiSet
        ldy #>sTiSet
        stx tiMsg
        sty tiMsg+1
        jmp shell_DrawAll        // datum/tijd en statusbalk opnieuw
}

// ti_Auto - na een koude start (Core): stil de tijd ophalen.
ti_Auto:
        lda #<sTiBoot            // "GETTING THE TIME..." in de statusbalk
        sta r0
        lda #>sTiBoot
        sta r0+1
        lda #10
        sta a0
        lda #STATUS_ROW
        sta a1
        lda TH_menubg
        sta a2
        jsr gfx_DrawTextRev
        jsr ti_Sync
        jmp drawStatus

// ti_Sync - netwerk klaarmaken, NTP vragen, klok zetten.
//           Uit: carry=1 gelukt, carry=0 -> X/Y melding.
ti_Sync: {
        jsr ti_SrvDefault
        jsr nc_Load
        jsr net_Detect
        ldx #0
cc:      lda CFG_ntp,x
        cmp #$ff
        beq e
        sta feBuf,x
        inx
        cpx #31
        bne cc
e:      stx feLen
        lda #0
        sta netAbort
        sta netNoKeys
        jsr ntp_Get
        bcc r
        jsr ti_Apply
r:      rts
}

//--------------------------------------------------------
// ti_Apply - ntpSec + zone -> klok. Carry=0 -> X/Y melding.
//--------------------------------------------------------
ti_Apply: {
        lda ntpSec+3             // big-endian -> tiT (little-endian)
        sta tiT
        lda ntpSec+2
        sta tiT+1
        lda ntpSec+1
        sta tiT+2
        lda ntpSec
        sta tiT+3
        sec                      // - 3155673600 (1-1-1900 -> 1-1-2000)
        lda tiT
        sbc #$00
        sta tiT
        lda tiT+1
        sbc #$c2
        sta tiT+1
        lda tiT+2
        sbc #$17
        sta tiT+2
        lda tiT+3
        sbc #$bc
        sta tiT+3
        bcs ok
        ldx #<sTiBad
        ldy #>sTiBad
        rts
ok:     ldx CFG_tz
        cpx #TZ_N
        bcc z
        ldx #TZ_DEFAULT
z:      lda tzQ,x
        sta tiQ
        lda tzRule,x
        sta tiRule
        lda tiQ                  // + zone (kwartieren van 900 s)
        beq zd
        bmi neg
zp:     lda #<900
        ldx #>900
        jsr ti_Add
        dec tiQ
        bne zp
        beq zd
neg:    lda #<900
        ldx #>900
        jsr ti_Sub
        inc tiQ
        bne neg
zd:     ldx CFG_tz               // (tiQ weer herstellen voor de regels)
        cpx #TZ_N
        bcc z2
        ldx #TZ_DEFAULT
z2:     lda tzQ,x
        sta tiQ
        jsr ti_Date
        jsr ti_IsDst
        bcc set
        lda #<3600               // zomertijd: een uur erbij
        ldx #>3600
        jsr ti_Add
        jsr ti_Date
set:    lda tiD
        jsr ti_ToBcd
        sta clkDay
        lda tiM
        jsr ti_ToBcd
        sta clkMon
        lda #$20
        sta clkYearHi
        lda tiY
        jsr ti_ToBcd
        sta clkYearLo
        lda tiS
        jsr ti_ToBcd
        sta tiSb
        lda tiMi
        jsr ti_ToBcd
        sta tiMb
        lda tiH
        jsr ti_ToBcd
        ldx tiMb
        jsr clk_SetTime
        lda tiSb
        sta TOD_SEC
        sec
        rts
}

// ti_Add / ti_Sub - tiT +/- X:A (16 bit).
ti_Add:
        clc
        adc tiT
        sta tiT
        txa
        adc tiT+1
        sta tiT+1
        bcc !+
        inc tiT+2
        bne !+
        inc tiT+3
!:      rts
ti_Sub:
        sta tiT7
        stx tiT7+1
        sec
        lda tiT
        sbc tiT7
        sta tiT
        lda tiT+1
        sbc tiT7+1
        sta tiT+1
        lda tiT+2
        sbc #0
        sta tiT+2
        lda tiT+3
        sbc #0
        sta tiT+3
        rts

// ti_ToBcd - A (0-99) -> BCD.
ti_ToBcd: {
        ldx #0
l:      cmp #10
        bcc d
        sbc #10
        inx
        bne l
d:      sta tiT7
        txa
        asl
        asl
        asl
        asl
        ora tiT7
        rts
}

// ti_Date - tiT (seconden sinds 1-1-2000) -> tiY (jaren na 2000), tiM,
//           tiD, tiH, tiMi, tiS, tiWd (0 = zondag).
ti_Date: {
        ldx #3
cc:      lda tiT,x
        sta dvN,x
        dex
        bpl cc
        lda #<86400
        ldx #>86400
        ldy #86400>>16
        jsr ti_Div
        lda dvN
        sta tiDays
        lda dvN+1
        sta tiDays+1
        ldx #3                   // rest -> uur, minuut, seconde
r1:     lda dvR,x
        sta dvN,x
        dex
        bpl r1
        lda #<3600
        ldx #>3600
        ldy #0
        jsr ti_Div
        lda dvN
        sta tiH
        ldx #3
r2:     lda dvR,x
        sta dvN,x
        dex
        bpl r2
        lda #60
        ldx #0
        ldy #0
        jsr ti_Div
        lda dvN
        sta tiMi
        lda dvR
        sta tiS
        lda tiDays               // weekdag: 1-1-2000 was een zaterdag
        clc
        adc #6
        sta dvN
        lda tiDays+1
        adc #0
        sta dvN+1
        lda #0
        sta dvN+2
        sta dvN+3
        lda #7
        ldx #0
        ldy #0
        jsr ti_Div
        lda dvR
        sta tiWd
        lda #0                   // jaar
        sta tiY
yl:     jsr ti_YLen              // tiT7 = lengte (16 bit)
        lda tiDays
        cmp tiT7
        lda tiDays+1
        sbc tiT7+1
        bcc ym
        lda tiDays
        sbc tiT7
        sta tiDays
        lda tiDays+1
        sbc tiT7+1
        sta tiDays+1
        inc tiY
        bne yl
ym:     lda #1                   // maand
        sta tiM
ml:     lda tiM
        jsr ti_MonLen
        sta tiT7
        lda tiDays+1
        bne mn
        lda tiDays
        cmp tiT7
        bcc md
mn:     sec
        lda tiDays
        sbc tiT7
        sta tiDays
        lda tiDays+1
        sbc #0
        sta tiDays+1
        inc tiM
        bne ml
md:     ldx tiDays
        inx
        stx tiD
        rts
}

// ti_YLen - tiT7 = dagen in jaar 2000+tiY.
ti_YLen:
        lda #<365
        sta tiT7
        lda #>365
        sta tiT7+1
        lda tiY
        and #3
        bne !+
        inc tiT7
!:      rts

// ti_MonLen - A = dagen in maand A (1-12) van jaar tiY.
ti_MonLen: {
        tax
        lda tiDim-1,x
        cpx #2
        bne r
        tax
        lda tiY
        and #3
        bne n
        inx
n:      txa
r:      rts
}
tiDim:  .byte 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

// ti_Div - dvN (32 bit) / Y:X:A -> dvN quotient, dvR rest.
ti_Div: {
        sta dvD
        stx dvD+1
        sty dvD+2
        lda #0
        sta dvD+3
        sta dvR
        sta dvR+1
        sta dvR+2
        sta dvR+3
        ldx #32
l:      asl dvN
        rol dvN+1
        rol dvN+2
        rol dvN+3
        rol dvR
        rol dvR+1
        rol dvR+2
        rol dvR+3
        sec
        lda dvR
        sbc dvD
        sta dvS
        lda dvR+1
        sbc dvD+1
        sta dvS+1
        lda dvR+2
        sbc dvD+2
        sta dvS+2
        lda dvR+3
        sbc dvD+3
        bcc nx
        sta dvR+3
        lda dvS+2
        sta dvR+2
        lda dvS+1
        sta dvR+1
        lda dvS
        sta dvR
        inc dvN
nx:     dex
        bne l
        rts
}

//--------------------------------------------------------
// ti_IsDst - geldt zomertijd op de lokale standaardtijd tiY/M/D/H?
//            Carry=1 ja.
//--------------------------------------------------------
ti_IsDst: {
        ldx tiRule
        bne go
        clc
        rts
go:     dex
        lda tdSm,x
        sta tiSm
        lda tdEm,x
        sta tiEm
        lda tdSk,x
        sta tiSk
        lda tdEk,x
        sta tiEk
        lda tdH,x
        sta tiSh
        lda tdEh,x
        sta tiEh
        cpx #DST_EU-1            // EU: om 01:00 UTC = 1 + zone-uren
        bne nh
        lda tiQ
        cmp #$80
        ror
        cmp #$80
        ror
        clc
        adc #1
        sta tiSh
        sta tiEh
nh:     lda tiSm
        cmp tiEm
        bcs south
        lda tiM                  // noordelijk: tussen start en eind
        cmp tiSm
        beq ins
        bcc no
        cmp tiEm
        beq ine
        bcs no
yes:    sec
        rts
south:  lda tiM                  // zuidelijk: over de jaarwisseling
        cmp tiSm
        beq ins
        bcs yes
        cmp tiEm
        beq ine
        bcc yes
no:     clc
        rts
ins:    lda tiSk                 // in de startmaand: na de start?
        jsr ti_Sunday
        cmp tiD
        bcc yes
        bne no
        lda tiH
        cmp tiSh
        bcs yes
        bcc no
ine:    lda tiEk                 // in de eindmaand: voor het eind?
        jsr ti_Sunday
        cmp tiD
        beq eq
        bcs yes
        bcc no
eq:     lda tiH
        cmp tiEh
        bcc yes
        bcs no
}
//              EU  US  AU  NZ
tdSm:   .byte   3,  3, 10,  9            // startmaand
tdSk:   .byte   0,  2,  1,  0            // 1e/2e zondag, 0 = laatste
tdH:    .byte   2,  2,  2,  2            // uur (lokale standaardtijd)
tdEm:   .byte  10, 11,  4,  4            // eindmaand
tdEk:   .byte   0,  1,  1,  1
tdEh:   .byte   2,  1,  2,  2

// ti_Sunday - A = soort (1 = eerste, 2 = tweede, 0 = laatste) ->
//             A = dag van die zondag in maand tiM.
ti_Sunday: {
        sta tiK
        lda tiWd                 // weekdag van de 1e: (wd + 36 - d) mod 7
        clc
        adc #36
        sec
        sbc tiD
        jsr mod7
        sta tiT7
        lda #7                   // eerste zondag = 1 + (7 - wd1) mod 7
        sec
        sbc tiT7
        jsr mod7
        clc
        adc #1
        sta tiFs
        lda tiK
        cmp #1
        beq f
        cmp #2
        bne l
        lda tiFs
        clc
        adc #7
        rts
l:      lda tiM                  // laatste: 1e + 28 als dat past, anders + 21
        jsr ti_MonLen
        sta tiT7
        lda tiFs
        clc
        adc #28
        cmp tiT7
        beq r
        bcc r
        sec
        sbc #7
r:      rts
f:      lda tiFs
        rts
mod7:   cmp #7
        bcc m
        sbc #7
        bcs mod7
m:      rts
}

//--------------------------------------------------------
// ti_Pick - keuzelijst met alle tijdzones.
//--------------------------------------------------------
ti_Pick: {
        lda kbRaw
        sta tiRaw
        lda #1
        sta kbRaw
        lda CFG_tz
        cmp #TZ_N
        bcc s0
        lda #TZ_DEFAULT
s0:     sta tiSel
        sec                      // bovenste regel: selectie in het midden
        sbc #7
        bcs s1
        lda #0
s1:     sta tiTop
        jsr clampTop
        lda #<sTiZone
        sta r0
        lda #>sTiZone
        sta r0+1
        lda #2
        sta a0
        lda #2
        sta a1
        lda #36
        sta a2
        lda #21
        sta a3
        jsr dlg_Draw             // rijen 2-22
        ldx #0
pb:     stx tiI
        lda tpLo,x
        sta r0
        lda tpHi,x
        sta r0+1
        lda tpCol,x
        sta a0
        lda #TP_R_BTN
        sta a1
        lda tpW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx tiI
        inx
        cpx #4
        bne pb
redraw: jsr list
wait:   jsr evt_Poll
        cmp #EVT_KEY
        bne fb3992_0
        jmp key
fb3992_0:
        cmp #EVT_MOUSEDOWN
        bne wait
        lda evtB                 // klik in de lijst
        cmp #TP_TOP
        bcc btns
        cmp #TP_TOP+TP_VIS
        bcs btns
        sbc #TP_TOP-1            // (carry=0: -TP_TOP)
        clc
        adc tiTop
        cmp #TZ_N
        bcs wait
        cmp tiSel
        bne fb3992_1                 // nog eens op de selectie = kiezen
        jmp pick
fb3992_1:
        sta tiSel
        jmp redraw
btns:   ldx #0
bt:     stx tiI
        lda tpCol,x
        sta a0
        lda #TP_R_BTN
        sta a1
        lda tpW,x
        sta a2
        jsr btn_HitTest
        bcs hit
        ldx tiI
        inx
        cpx #4
        bne bt
        lda evtB                 // sluitknop van de titelbalk
        cmp #2
        bne wait
        lda evtA
        cmp #37
        bne fb3992_2
        jmp cancel
fb3992_2:
        jmp wait
hit:    lda tiI
        beq pgUp
        cmp #1
        beq pgDn
        cmp #2
        beq pick
        jmp cancel
pgUp:   lda tiTop
        sec
        sbc #TP_VIS
        bcs pu
        lda #0
pu:     sta tiTop
        jmp mvSel
pgDn:   lda tiTop
        clc
        adc #TP_VIS
        sta tiTop
        jsr clampTop
mvSel:  lda tiTop                // selectie mee naar de zichtbare pagina
        sta tiSel
        jmp redraw
key:    lda evtA
        cmp #KEY_CRSR_D
        bne k1
        lda evtB
        and #KM_SHIFT
        bne up
        ldx tiSel                // omlaag
        inx
        cpx #TZ_N
        bcs kw
        stx tiSel
        txa
        sec
        sbc tiTop
        cmp #TP_VIS
        bcc kr
        inc tiTop
kr:     jmp redraw
up:     ldx tiSel
        beq kw
        dex
        stx tiSel
        cpx tiTop
        bcs kr
        stx tiTop
        jmp redraw
k1:     cmp #KEY_RETURN
        beq pick
        cmp #KEY_STOP
        beq cancel
kw:     jmp wait
pick:   lda tiSel
        sta CFG_tz
        ldx #<sTiZoneSet
        ldy #>sTiZoneSet
        stx tiMsg
        sty tiMsg+1
cancel: lda tiRaw
        sta kbRaw
        jmp shell_DrawAll

// list - de zichtbare zones, de selectie omgekeerd.
list:   lda #0
        sta tiRow
ll:     lda tiRow
        clc
        adc tiTop
        tax
        cpx #TZ_N
        bcc lz
        ldx #0                   // (onder het einde: lege regel)
        lda #$20
lb:     sta tiLine,x
        inx
        cpx #TI_ZW
        bne lb
        lda #$ff
        sta tiLine,x
        jmp ld
lz:     jsr ti_ZoneText
ld:     lda #<tiLine
        sta r0
        lda #>tiLine
        sta r0+1
        lda #TI_COL
        sta a0
        lda tiRow
        clc
        adc #TP_TOP
        sta a1
        lda tiRow
        clc
        adc tiTop
        cmp tiSel
        bne ln
        lda TH_select
        sta a2
        jsr gfx_DrawTextRev
        jmp lx
ln:     lda TH_text
        sta a2
        jsr gfx_DrawText
lx:     inc tiRow
        lda tiRow
        cmp #TP_VIS
        bne ll
        rts

clampTop:
        lda tiTop                // hoogstens TZ_N - TP_VIS
        cmp #TZ_N-TP_VIS
        bcc ct
        lda #TZ_N-TP_VIS
        sta tiTop
ct:     rts
}

//--------------------------------------------------------
tiMsg:   .word 0
tiI:     .byte 0
tiRow:   .byte 0
tiSel:   .byte 0
tiTop:   .byte 0
tiRaw:   .byte 0
tiT:     .fill 4, 0
tiT7:    .word 0
tiQ:     .byte 0
tiRule:  .byte 0
tiDays:  .word 0
tiY:     .byte 0
tiM:     .byte 0
tiD:     .byte 0
tiH:     .byte 0
tiMi:    .byte 0
tiS:     .byte 0
tiWd:    .byte 0
tiSb:    .byte 0
tiMb:    .byte 0
tiSm:    .byte 0
tiEm:    .byte 0
tiSk:    .byte 0
tiEk:    .byte 0
tiSh:    .byte 0
tiEh:    .byte 0
tiK:     .byte 0
tiFs:    .byte 0
dvN:     .fill 4, 0
dvD:     .fill 4, 0
dvR:     .fill 4, 0
dvS:     .fill 3, 0
tiLine:  .fill 41, $ff

tbLo:    .byte <sTiSync, <sTiSave
tbHi:    .byte >sTiSync, >sTiSave
tbCol:   .byte TI_COL, TI_COL+12
tbW:     .byte 10, 6
tpLo:    .byte <sTpUp, <sTpDown, <sTpOk, <sTpCancel
tpHi:    .byte >sTpUp, >sTpDown, >sTpOk, >sTpCancel
tpCol:   .byte 3, 10, 19, 25
tpW:     .byte 6, 8, 5, 8
tiDstLo: .byte <sDstNone, <sDstEu, <sDstUs, <sDstAu, <sDstNz
tiDstHi: .byte >sDstNone, >sDstEu, >sDstUs, >sDstAu, >sDstNz

.encoding "screencode_upper"
sTiDate:  .text "DATE"
          .byte $ff
sTiTime:  .text "TIME"
          .byte $ff
sTiZone:  .text "TIME ZONE"
          .byte $ff
sTiDst:   .text "SUMMER TIME"
          .byte $ff
sTiSrv:   .text "TIME SERVER (NTP)"
          .byte $ff
sTiAuto:  .text "SYNC AT START"
          .byte $ff
sTiOn:    .text "ON"
          .byte $ff
sTiOff:   .text "OFF"
          .byte $ff
sTiNote:  .text "(USES THE NETWORK SETTINGS)"
          .byte $ff
sTiSync:  .text "SYNC NOW"
          .byte $ff
sTiSave:  .text "SAVE"
          .byte $ff
sTiPool:  .text "POOL.NTP.ORG"
          .byte $ff
sTiAsk:   .text "ASKING THE TIME SERVER..."
          .byte $ff
sTiSet:   .text "DATE AND TIME SET"
          .byte $ff
sTiSaved: .text "SAVED"
          .byte $ff
sTiSaveHint: .text "PRESS SAVE TO KEEP THIS"
          .byte $ff
sTiZoneSet: .text "PRESS SYNC NOW, THEN SAVE"
          .byte $ff
sTiBad:   .text "THE TIME SERVER SENT A WRONG TIME"
          .byte $ff
sTiBoot:  .text "GETTING THE TIME..."
          .byte $ff
sDstNone: .text "NONE"
          .byte $ff
sDstEu:   .text "EUROPE"
          .byte $ff
sDstUs:   .text "USA / CANADA"
          .byte $ff
sDstAu:   .text "AUSTRALIA"
          .byte $ff
sDstNz:   .text "NEW ZEALAND"
          .byte $ff
sTpUp:    .text "PG UP"
          .byte $ff
sTpDown:  .text "PG DOWN"
          .byte $ff
sTpOk:    .text "OK"
          .byte $ff
sTpCancel: .text "CANCEL"
          .byte $ff
