#importonce
//========================================================
// apps/calendar/cal.asm - CALENDAR: maand + agenda (app 16, PRG CALENDAR)
// Commodore Desk 64 - plan: docs/CALENDAR_Plan.md
//
// Rij 3: < MAAND JAAR >  TODAY; rij 5 de weekdagen, rij 6-11 de maand
// (weeknummers links, > = gekozen dag, * = afspraken, vandaag in de
// accentkleur, feestdagen in de selectiekleur); rij 13 de gekozen dag,
// rij 14-19 zijn afspraken; rij 21 ADD EDIT DELETE PRINT; rij 22 status.
// ADD/EDIT: hetzelfde stuk scherm als formulier (TIME, TEXT, REPEAT).
//========================================================
.const CL_HELP = 21
.const CG_ROW  = 6               // eerste weekrij
.const CG_COL  = 6               // kolom van maandag (cel: > d d *)
.const CL_RT   = 13              // titel van de dag
.const CL_R0   = 14              // eerste afspraak
.const CL_ROWS = 6
.const CL_RB   = 21
.const CL_RS   = 22

cl_Init:
        lda #CL_HELP
        sta helpCtx
        lda #0
        sta clMode
        sta clMsg+1
        sta clTop
        jsr cl_Today
        jsr cf_Load
        jsr cl_Month
        lda cfBad
        beq !+
        lda #<sClBad
        sta clMsg
        lda #>sClBad
        sta clMsg+1
!:      rts

// cl_Today - vandaag (klok van de Core, BCD) -> tY/tM/tD en de gekozen dag.
cl_Today: {
        lda clkYearLo
        jsr bcd
        ldx clkYearHi
        cpx #$20
        bne y
        clc
        adc #100
y:      sta tY
        sta vY
        lda clkMon
        jsr bcd
        sta tM
        sta vM
        lda clkDay
        jsr bcd
        sta tD
        sta vD
        rts
bcd:    pha
        lsr
        lsr
        lsr
        lsr
        tax
        pla
        and #$0f
        clc
dl:     dex
        bmi r
        adc #10
        bne dl
r:      rts
}

// cl_Month - de maand van vY/vM opnieuw uitrekenen (afspraken, feestdagen)
//            en de dag vD (binnen de maand houden).
cl_Month: {
        lda vY
        sta dY
        lda vM
        sta dM
        jsr dt_Dim
        sta vDim
        cmp vD
        bcs d
        sta vD
d:      jsr cf_Month
        jsr dt_Holidays
        lda #1
        sta dD
        jsr dt_Dow
        sta vOff                 // weekdag van de 1e
        // fall through
}
cl_Day: {
        lda vY
        sta dY
        lda vM
        sta dM
        lda vD
        sta dD
        jsr cf_Day
        lda #$ff
        sta clSel
        lda #0
        sta clTop
        rts
}

//--------------------------------------------------------
// Tekenen
//--------------------------------------------------------
cl_Draw: {
        lda clMode
        beq v
        jmp fm_Draw
v:      jsr cl_Head
        jsr cl_Grid
        jsr cl_List
        jsr cl_Btns
        jmp cl_Status
}

// cl_Head - < MAAND JAAR >  TODAY en de weekdagen
cl_Head: {
        ldx #2
b:      stx clI
        lda hbLo,x
        sta r0
        lda hbHi,x
        sta r0+1
        lda hbCol,x
        sta a0
        lda #3
        sta a1
        lda hbW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx clI
        dex
        bpl b
        lda #3                   // maand en jaar
        jsr cl_Clr6
        lda #0
        sta oN
        ldx vM
        lda monLo-1,x
        ldy monHi-1,x
        jsr o_Str
        lda #$20
        jsr o_Chr
        jsr o_Year
        lda #6
        sta a0
        lda #3
        sta a1
        lda TH_text
        jsr o_Draw
        lda #<sClDays            // WK MO TU ...
        sta r0
        lda #>sClDays
        sta r0+1
        lda #3
        sta a0
        lda #5
        sta a1
        lda TH_text
        sta a2
        jmp gfx_DrawText
}
hbLo:   .byte <sClPrev, <sClNext, <sClToday
hbHi:   .byte >sClPrev, >sClNext, >sClToday
hbCol:  .byte 2, 21, 27
hbW:    .byte 3, 3, 9

// cl_Clr6 - rij A, kolom 6-20 leeg (titel tussen < en >)
cl_Clr6: {
        sta a1
        lda #6
        sta a0
        lda #14
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jmp gfx_FillRect
}

// cl_Grid - de weken van de maand (6 rijen). gD = dag van de maandag van
//           de rij (in rij 0 kan dat 0 of negatief zijn).
cl_Grid: {
        lda #0
        sta gR
        lda #1
        sec
        sbc vOff
        sta gD
r:      lda gR
        clc
        adc #CG_ROW
        sta a1
        jsr cl_RowClr
        lda gD                   // heeft deze rij nog een dag van de maand?
        bmi v
        beq v
        cmp vDim
        beq v
        bcs nx
v:      jsr cl_Week
        ldx #0
dl:     stx gJ
        lda gD
        bmi nd
        beq nd
        cmp vDim
        beq dd
        bcs nd
dd:     jsr cl_Cell
nd:     inc gD
        ldx gJ
        inx
        cpx #7
        bne dl
        jmp n2
nx:     lda gD
        clc
        adc #7
        sta gD
n2:     inc gR
        lda gR
        cmp #6
        bne r
        rts
}

// cl_RowClr - rij a1 (kolom 3-36) leeg
cl_RowClr: {
        lda #3
        sta a0
        lda #34
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jmp gfx_FillRect
}

// cl_Week - het weeknummer van de rij (gD = dag van de maandag) op kolom 3
cl_Week: {
        lda gD                   // donderdag = gD + 3, eventueel in een
        clc                      // andere maand
        adc #3
        sta dD
        lda vY
        sta dY
        lda vM
        sta dM
        lda dD
        bmi pv
        beq pv
        cmp vDim
        beq ok
        bcc ok
        sec                      // volgende maand
        sbc vDim
        sta dD
        inc dM
        lda dM
        cmp #13
        bcc ok
        lda #1
        sta dM
        inc dY
        bne ok
pv:     dec dM                   // vorige maand
        bne p1
        lda #12
        sta dM
        dec dY
p1:     jsr dt_Dim
        clc
        adc dD
        sta dD
ok:     jsr dt_Week
        jsr num2s
        lda #3
        sta a0
        lda gR
        clc
        adc #CG_ROW
        sta a1
        lda TH_text
        jmp o_Draw
}

// cl_Cell - dag gD op rij gR, kolom gJ: marker, getal, *
cl_Cell: {
        lda #0
        sta oN
        lda gD                   // > voor de gekozen dag
        cmp vD
        bne s
        lda #$3e
        .byte $2c
s:      lda #$20
        jsr o_Chr
        lda gD
        cmp #10
        bcs t
        lda #$20
        jsr o_Chr
        lda gD
        ora #$30
        jsr o_Chr
        jmp m
t:      jsr num2s0
m:      ldx gD
        lda #$20
        ldy CL_MARK,x
        beq m1
        lda #$2a                 // *
m1:     jsr o_Chr
        lda gJ                   // kolom
        asl
        asl
        clc
        adc #CG_COL
        sta a0
        lda gR
        clc
        adc #CG_ROW
        sta a1
        lda TH_text              // kleur: vandaag accent, feestdag selectie
        ldx gD
        ldy CL_HOL,x
        beq c1
        lda TH_select
c1:     cpx tD
        bne c2
        ldy vM
        cpy tM
        bne c2
        ldy vY
        cpy tY
        bne c2
        lda TH_accent
c2:     jmp o_Draw
}

// cl_List - de gekozen dag: titel, feestdag, afspraken
cl_List: {
        lda #CL_RT
        jsr cl_Line0
        lda #0                   // titel: DONDERDAG 8 OKTOBER 2026
        sta oN
        lda vY
        sta dY
        lda vM
        sta dM
        lda vD
        sta dD
        jsr dt_Dow
        tax
        lda dayLo,x
        ldy dayHi,x
        jsr o_Str
        lda #$20
        jsr o_Chr
        lda vD
        jsr num1s
        lda #$20
        jsr o_Chr
        ldx vM
        lda monLo-1,x
        ldy monHi-1,x
        jsr o_Str
        lda #$20
        jsr o_Chr
        jsr o_Year
        lda #2
        sta a0
        lda #CL_RT
        sta a1
        lda TH_accent
        jsr o_Draw
        lda #0                   // regels: feestdag, dan de afspraken
        sta lR
        ldx vD
        lda CL_HOL,x
        beq ap
        tax
        lda #0
        sta oN
        lda #$2a
        jsr o_Chr
        lda #$20
        jsr o_Chr
        lda calHolLo,x
        ldy calHolHi,x
        jsr o_Str
        lda TH_select
        jsr lOut
ap:     ldx clTop
la1:     cpx cdN
        bcs fill
        lda lR
        cmp #CL_ROWS
        bcs more
        stx lI
        jsr cl_Entry
        lda TH_text
        ldx lI
        cpx clSel
        bne la2
        lda TH_accent
la2:     jsr lOut
        ldx lI
        inx
        bne la1
more:   rts
fill:   lda lR
        cmp #CL_ROWS
        bcs more
        lda #CL_R0
        clc
        adc lR
        jsr cl_Line0
        inc lR
        bne fill
// lOut - de regel (oN) op rij CL_R0+lR in kleur A
lOut:   pha
        lda #CL_R0
        clc
        adc lR
        sta lRow
        jsr cl_Line0
        lda #2
        sta a0
        lda lRow
        sta a1
        inc lR
        pla
        jmp o_Draw
}

// cl_Line0 - rij A (kolom 2-36) leeg
cl_Line0: {
        sta a1
        lda #2
        sta a0
        lda #35
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jmp gfx_FillRect
}

// cl_Entry - afspraak X van de dag als regel: HH:MM R TEKST
cl_Entry: {
        lda CL_DAY,x
        sta cQ
        lda CL_DAYH,x
        sta cQ+1
        lda #0
        sta oN
        ldy #CR_HH
        lda (cQ),y
        cmp #$ff
        bne t
        lda #<sSp5               // hele dag: geen tijd
        ldy #>sSp5
        jsr o_Str
        jmp r
t:      jsr num2s0
        lda #$3a
        jsr o_Chr
        ldy #CR_MM
        lda (cQ),y
        jsr num2s0
r:      lda #$20
        jsr o_Chr
        ldy #CR_REP
        lda (cQ),y
        tax
        lda repCh,x
        jsr o_Chr
        lda #$20
        jsr o_Chr
        ldy #CR_TXT
x:      lda (cQ),y
        cmp #$ff
        beq e
        jsr o_Chr
        iny
        cpy #CR_TXT+CT_W
        bne x
e:      rts
}
repCh:  .byte $20, 23, 13, 25    // (niet), W, M, Y

// cl_Btns - ADD EDIT DELETE PRINT
cl_Btns: {
        ldx #3
b:      stx clI
        lda bLo,x
        sta r0
        lda bHi,x
        sta r0+1
        lda bCol,x
        sta a0
        lda #CL_RB
        sta a1
        lda bW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx clI
        dex
        bpl b
        rts
}
bLo:    .byte <sClAdd, <sClEdit, <sClDel, <sClPrint
bHi:    .byte >sClAdd, >sClEdit, >sClDel, >sClPrint
bCol:   .byte 2, 9, 17, 27
bW:     .byte 6, 7, 9, 9

// cl_Status - melding, of de datum nog niet gezet is
cl_Status: {
        lda #CL_RS
        jsr cl_Line0
        lda clMsg+1
        bne m
        lda tY                   // 01-01-2026: de klok is nooit gezet
        cmp #126
        bne r
        lda tM
        cmp #1
        bne r
        lda tD
        cmp #1
        bne r
        lda #<sClSet
        ldx #>sClSet
        bne d
m:      ldx clMsg+1
        lda clMsg
d:      sta r0
        stx r0+1
        lda #2
        sta a0
        lda #CL_RS
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
r:      rts
}

//--------------------------------------------------------
// Klikken en toetsen
//--------------------------------------------------------
cl_Click: {
        lda #0
        sta clMsg+1
        lda clMode
        beq v
        jmp fm_Click
v:      ldx #2                   // < > TODAY
h:      stx clI
        lda hbCol,x
        sta a0
        lda #3
        sta a1
        lda hbW,x
        sta a2
        jsr btn_HitTest
        bcc !c1+
        jmp hh
!c1:
        ldx clI
        dex
        bpl h
        ldx #3                   // ADD EDIT DELETE PRINT
b:      stx clI
        lda bCol,x
        sta a0
        lda #CL_RB
        sta a1
        lda bW,x
        sta a2
        jsr btn_HitTest
        bcc !c2+
        jmp bb
!c2:
        ldx clI
        dex
        bpl b
        lda evtB                 // in de maand?
        sec
        sbc #CG_ROW
        cmp #6
        bcs ls
        sta gR
        lda evtA
        sec
        sbc #CG_COL
        cmp #28
        bcs r
        lsr
        lsr
        sta gJ
        lda gR                   // dag = rij*7 + kolom + 1 - vOff
        asl
        asl
        asl
        sec
        sbc gR
        clc
        adc gJ
        adc #1
        sec
        sbc vOff
        beq r
        bmi r
        cmp vDim
        beq sd
        bcs r
sd:     sta vD
        jsr cl_Day
        jmp cl_Redraw
ls:     lda evtB                 // in de lijst: afspraak kiezen
        sec
        sbc #CL_R0
        cmp #CL_ROWS
        bcs r
        sec                      // (min een regel als er een feestdag staat)
        ldx vD
        ldy CL_HOL,x
        beq l1
        sbc #1
        bmi r
l1:     clc
        adc clTop
        cmp cdN
        bcs r
        sta clSel
        jmp cl_Redraw
r:      rts
hh:     lda clI
        beq prev
        cmp #1
        beq next
        jsr cl_Today             // TODAY
        jsr cl_Month
        jmp cl_Redraw
bb:     lda clI
        bne b1
        jmp fm_Add
b1:     cmp #1
        bne b2
        jmp fm_Edit
b2:     cmp #2
        bne b3
        jmp cl_Delete
b3:     jmp cl_Print
prev:   dec vM
        bne pm
        lda #12
        sta vM
        dec vY
pm:     jsr cl_Month
        jmp cl_Redraw
next:   inc vM
        lda vM
        cmp #13
        bcc pm
        lda #1
        sta vM
        inc vY
        bne pm
}

cl_Redraw:
        jmp shell_DrawAll

// cl_Key - - / + maand, T vandaag, A E P, SPATIE de lijst verder
cl_Key: {
        ldx clMode
        bne no
        cmp #$2d                 // -
        bne k1
        jsr cl_Click.prev
        sec
        rts
k1:     cmp #$2b                 // +
        bne k2
        jsr cl_Click.next
        sec
        rts
k2:     cmp #20                  // T
        bne k3
        jsr cl_Today
        jsr cl_Month
        jsr cl_Redraw
        sec
        rts
k3:     cmp #1                   // A
        bne k4
        jsr fm_Add
        sec
        rts
k4:     cmp #5                   // E
        bne k5
        jsr fm_Edit
        sec
        rts
k5:     cmp #16                  // P
        bne k6
        jsr cl_Print
        sec
        rts
k6:     cmp #$20                 // SPATIE: de lijst verder (rondom)
        bne no
        lda clTop
        clc
        adc #CL_ROWS-1
        cmp cdN
        bcc k7
        lda #0
k7:     sta clTop
        jsr cl_Redraw
        sec
        rts
no:     clc
        rts
}

// cl_Ask - melding X/Y op de statusregel, wachten op een toets; A = toets
//          (0 = een muisklik).
cl_Ask: {
        stx r0
        sty r0+1
        lda #CL_RS
        jsr cl_Line0
        lda #2
        sta a0
        lda #CL_RS
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
w:      jsr evt_Poll
        cmp #EVT_KEY
        beq k
        cmp #EVT_MOUSEDOWN
        bne w
        lda #0
        rts
k:      lda evtA
        rts
}

// cl_Delete - de gekozen afspraak weg (na Y)
cl_Delete: {
        ldx clSel
        cpx #$ff
        bne s
        lda #<sClPick
        sta clMsg
        lda #>sClPick
        sta clMsg+1
        jmp cl_Redraw
s:      ldx #<sClSure
        ldy #>sClSure
        jsr cl_Ask
        cmp #25                  // Y
        bne r
        ldx clSel
        lda CL_DAY,x
        sta cP
        lda CL_DAYH,x
        sta cP+1
        jsr cr_Remove
        jsr cl_Store
r:      jsr cl_Month
        jmp cl_Redraw
}

// cr_Remove - afspraak cP weg: alles erachter een plek naar voren.
cr_Remove: {
        lda cP                   // bron = cP + CR_LEN
        clc
        adc #CR_LEN
        sta cS
        lda cP+1
        adc #0
        sta cS+1
        jsr cr_End               // cQ = einde van de lijst
        ldy #0
l:      lda cS+1
        cmp cQ+1
        bcc c
        bne d
        lda cS
        cmp cQ
        bcs d
c:      lda (cS),y
        sta (cP),y
        inc cS
        bne a
        inc cS+1
a:      inc cP
        bne l
        inc cP+1
        bne l
d:      lda crN
        bne e
        dec crN+1
e:      dec crN
        rts
}

// cr_End - cQ = CR_BUF + crN * CR_LEN
cr_End: {
        lda #<CR_BUF
        sta cQ
        lda #>CR_BUF
        sta cQ+1
        lda crN
        sta sN
        lda crN+1
        sta sN+1
l:      lda sN
        ora sN+1
        beq r
        lda cQ
        clc
        adc #CR_LEN
        sta cQ
        bcc n
        inc cQ+1
n:      lda sN
        bne m
        dec sN+1
m:      dec sN
        jmp l
r:      rts
}

// cl_Store - AGENDA schrijven; een fout als melding.
cl_Store: {
        jsr cf_Save
        bcc r
        stx clMsg
        sty clMsg+1
r:      rts
}

//--------------------------------------------------------
// Het formulier: ADD / EDIT
//--------------------------------------------------------
fm_Add: {
        lda crN+1                // vol?
        cmp #>CR_MAX
        bcc ok
        lda crN
        cmp #<CR_MAX
        bcc ok
        lda #<sClFull
        sta clMsg
        lda #>sClFull
        sta clMsg+1
        jmp cl_Redraw
ok:     lda #1
        sta clMode
        lda #$ff                 // nieuw: hele dag, lege tekst, niet herhalen
        sta fHH
        sta fText
        lda #0
        sta fMM
        sta fRep
        lda #$ff
        sta fRec+1               // (geen bestaande afspraak)
        jsr cl_Redraw
        jsr fm_Time              // meteen de tijd en de tekst typen
        jmp fm_Text
}

fm_Edit: {
        ldx clSel
        cpx #$ff
        bne s
        lda #<sClPick
        sta clMsg
        lda #>sClPick
        sta clMsg+1
        jmp cl_Redraw
s:      lda CL_DAY,x
        sta cQ
        sta fRec
        lda CL_DAYH,x
        sta cQ+1
        sta fRec+1
        ldy #CR_HH
        lda (cQ),y
        sta fHH
        ldy #CR_MM
        lda (cQ),y
        sta fMM
        ldy #CR_REP
        lda (cQ),y
        sta fRep
        ldy #CR_TXT
        ldx #0
t:      lda (cQ),y
        sta fText,x
        cmp #$ff
        beq e
        inx
        iny
        cpx #CT_W
        bne t
        lda #$ff
        sta fText,x
e:      lda #1
        sta clMode
        jmp cl_Redraw
}

// fm_Draw - het formulier (rij 13-19) en SAVE / CANCEL
fm_Draw: {
        jsr cl_Head
        jsr cl_Grid
        ldx #CL_RT
c:      stx clI
        txa
        jsr cl_Line0
        ldx clI
        inx
        cpx #CL_R0+CL_ROWS
        bne c
        lda #<sFmNew
        ldx #>sFmNew
        ldy fRec+1
        cpy #$ff
        beq t
        lda #<sFmChg
        ldx #>sFmChg
t:      sta r0
        stx r0+1
        lda #2
        sta a0
        lda #CL_RT
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        ldx #2                   // TIME / TEXT / REPEAT
l:      stx clI
        lda fLblLo,x
        sta r0
        lda fLblHi,x
        sta r0+1
        lda #2
        sta a0
        txa
        clc
        adc #CL_R0+1
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        ldx clI
        dex
        bpl l
        lda #0                   // de tijd
        sta oN
        lda fHH
        cmp #$ff
        bne tm
        lda #<sFmAll
        ldy #>sFmAll
        jsr o_Str
        jmp td
tm:     jsr num2s0
        lda #$3a
        jsr o_Chr
        lda fMM
        jsr num2s0
td:     lda #10
        sta a0
        lda #CL_R0+1
        sta a1
        lda TH_accent
        jsr o_Draw
        lda #<fText              // de tekst
        sta r0
        lda #>fText
        sta r0+1
        lda #10
        sta a0
        lda #CL_R0+2
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        ldx fRep                 // herhalen
        lda repLo,x
        sta r0
        lda repHi,x
        sta r0+1
        lda #10
        sta a0
        lda #CL_R0+3
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        lda #<sFmSave            // knoppen
        sta r0
        lda #>sFmSave
        sta r0+1
        lda #2
        sta a0
        lda #CL_RB
        sta a1
        lda #6
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sFmCancel
        sta r0
        lda #>sFmCancel
        sta r0+1
        lda #10
        sta a0
        lda #CL_RB
        sta a1
        lda #8
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        jmp cl_Status
}
fLblLo: .byte <sFmTime, <sFmText, <sFmRep
fLblHi: .byte >sFmTime, >sFmText, >sFmRep
repLo:  .byte <sRep0, <sRep1, <sRep2, <sRep3
repHi:  .byte >sRep0, >sRep1, >sRep2, >sRep3

fm_Click: {
        lda #2                   // SAVE
        sta a0
        lda #CL_RB
        sta a1
        lda #6
        sta a2
        jsr btn_HitTest
        bcc c
        jmp fm_Save
c:      lda #10                  // CANCEL
        sta a0
        lda #CL_RB
        sta a1
        lda #8
        sta a2
        jsr btn_HitTest
        bcc f
        lda #0
        sta clMode
        jmp cl_Redraw
f:      lda evtB
        cmp #CL_R0+1
        bne f2
        jmp fm_Time
f2:     cmp #CL_R0+2
        bne f3
        jmp fm_Text
f3:     cmp #CL_R0+3
        bne r
        inc fRep                 // NONE -> WEEKLY -> MONTHLY -> YEARLY
        lda fRep
        and #3
        sta fRep
        jmp cl_Redraw
r:      rts
}

// fm_Time - de tijd typen: HH:MM, HHMM, H:MM of leeg (= de hele dag)
fm_Time: {
        lda #$ff
        sta CL_EDIT
        lda #CL_R0+1
        jsr edit6
        bcc !c3+                    // (muisklik: niet veranderen)
        jmp x
!c3:
        ldx #0                   // cijfers verzamelen (: overslaan)
        ldy #0
l:      lda CL_EDIT,x
        cmp #$ff
        beq e
        inx
        cmp #$3a
        beq l
        sec
        sbc #$30
        cmp #10
        bcs bad
        sta fDig,y
        iny
        cpy #5
        bcc l
        bcs bad
e:      cpy #0
        bne t
        lda #$ff                 // leeg: de hele dag
        sta fHH
        lda #0
        sta fMM
        beq ok
t:      cpy #3
        bcc bad
        lda #0                   // H MM of HH MM
        sta fT
        cpy #4
        bne h1
        lda fDig                 // HH
        asl
        asl
        adc fDig
        asl
        sta fT
        lda fDig+1
        clc
        adc fT
        ldx #2
        bne h2
h1:     lda fDig
        ldx #1
h2:     cmp #24
        bcs bad
        sta fHH
        lda fDig,x               // MM
        asl
        asl
        adc fDig,x
        asl
        clc
        adc fDig+1,x
        cmp #60
        bcs bad
        sta fMM
ok:     jmp cl_Redraw
bad:    lda #<sFmBadT
        sta clMsg
        lda #>sFmBadT
        sta clMsg+1
x:      jmp cl_Redraw
// edit6 - CL_EDIT typen op rij A, kolom 10 (5 tekens)
edit6:  sta liRow
        sta a1                   // (ALL DAY is langer dan het veld)
        lda #10
        sta a0
        lda #7
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda #10
        sta liCol
        lda #5
        sta liMax
        sta liVis
        lda #<CL_EDIT
        sta r3
        lda #>CL_EDIT
        sta r3+1
        jmp li_Edit
}

// fm_Text - de tekst typen (max. CT_W tekens)
fm_Text: {
        lda #10
        sta liCol
        lda #CL_R0+2
        sta liRow
        lda #CT_W
        sta liMax
        sta liVis
        lda #<fText
        sta r3
        lda #>fText
        sta r3+1
        jsr li_Edit
        jmp cl_Redraw
}

// fm_Save - afspraak schrijven (nieuw: achteraan), AGENDA opslaan
fm_Save: {
        lda fRec+1
        cmp #$ff
        bne o
        jsr cr_End               // nieuw: achteraan
        lda cQ
        sta cP
        lda cQ+1
        sta cP+1
        inc crN
        bne d
        inc crN+1
        bne d
o:      lda fRec
        sta cP
        lda fRec+1
        sta cP+1
        ldy #CR_Y                // (EDIT: de datum blijft)
        lda (cP),y
        sta dY
        ldy #CR_M
        lda (cP),y
        sta dM
        ldy #CR_D
        lda (cP),y
        sta dD
        jmp f
d:      lda vY                   // ADD: de gekozen dag
        sta dY
        ldy #CR_Y
        sta (cP),y
        lda vM
        sta dM
        ldy #CR_M
        sta (cP),y
        lda vD
        sta dD
        ldy #CR_D
        sta (cP),y
f:      lda fHH
        ldy #CR_HH
        sta (cP),y
        lda fMM
        ldy #CR_MM
        sta (cP),y
        lda fRep
        ldy #CR_REP
        sta (cP),y
        jsr dt_Dow
        ldy #CR_DOW
        sta (cP),y
        ldx #0
        ldy #CR_TXT
t:      lda fText,x
        sta (cP),y
        cmp #$ff
        beq e
        inx
        iny
        cpx #CT_W
        bne t
        lda #$ff
        sta (cP),y
e:      lda #0
        sta clMode
        jsr cl_Store
        jsr cl_Month
        jmp cl_Redraw
}

//--------------------------------------------------------
// Een regel opbouwen (CL_OUT, oN) en tekenen
//--------------------------------------------------------
o_Chr: {                         // (X blijft)
        stx sx
        ldx oN
        cpx #40
        bcs r
        sta CL_OUT,x
        inc oN
r:      ldx sx
        rts
sx:     .byte 0
}
// o_Str - tekst A/Y (schermcodes, $ff) erachter
o_Str: {
        sta cS
        sty cS+1
        ldy #0
l:      lda (cS),y
        cmp #$ff
        beq r
        sty oY2
        jsr o_Chr
        ldy oY2
        iny
        bne l
r:      rts
}
// o_Draw - CL_OUT op a0/a1 in kleur A
o_Draw: {
        sta a2
        ldx oN
        lda #$ff
        sta CL_OUT,x
        lda #<CL_OUT
        sta r0
        lda #>CL_OUT
        sta r0+1
        jmp gfx_DrawText
}
// o_Year - het jaar dY/vY? (vY) als 4 cijfers
o_Year: {
        lda vY
        ldx #$31                 // 19.. of 20..
        ldy #$39
        cmp #100
        bcc c
        sbc #100
        ldx #$32
        ldy #$30
c:      pha
        sty oY2
        txa
        jsr o_Chr
        lda oY2
        jsr o_Chr
        pla
        jmp num2s0
}
// num2s0 - A (0-99) als twee cijfers; num2s - met een spatie i.p.v. 0x;
// num1s - zonder voorloopnul
num2s0: {
        ldx #$2f
        sec
l:      inx
        sbc #10
        bcs l
        adc #$3a
        pha
        txa
        jsr o_Chr
        pla
        jmp o_Chr
}
num2s:  ldy #0
        sty oN
num1s:  cmp #10
        bcs num2s0
        ora #$30
        jmp o_Chr

//--------------------------------------------------------
// Herinnering bij het opstarten ($800C, vanuit de Core)
//--------------------------------------------------------
// cl_Remind - afspraken (of een feestdag) vandaag? Venster + OK, A = 1.
//             Niets, of de klok nooit gezet: A = 0.
cl_Remind: {
        jsr cl_Today
        lda tY                   // 01-01-2026: de klok is nooit gezet
        cmp #126
        bne g
        lda tM
        cmp #1
        bne g
        lda tD
        cmp #1
        beq no
g:      jsr cf_Load
        jsr cl_Month
        ldx vD
        lda CL_HOL,x
        ora cdN
        bne yes
no:     lda #0
        rts
yes:    lda #2                   // venster
        sta a0
        lda #6
        sta a1
        lda #36
        sta a2
        lda #12
        sta a3
        lda #<sRmTitle
        sta r0
        lda #>sRmTitle
        sta r0+1
        jsr dlg_Draw
        lda #0
        sta lR
        ldx vD                   // feestdag
        lda CL_HOL,x
        beq ap
        tax
        lda #0
        sta oN
        lda calHolLo,x
        ldy calHolHi,x
        jsr o_Str
        lda TH_select
        jsr out
ap:     ldx #0
al:     cpx cdN
        bcs ok
        lda lR
        cmp #7
        bcs ok
        stx lI
        jsr cl_Entry
        lda TH_text
        jsr out
        ldx lI
        inx
        bne al
ok:     lda #18
        sta a0
        lda #16
        sta a1
        jsr dlg_OkButton
        jsr dlg_WaitClose
        lda #1
        rts
out:    pha
        lda oN                   // (niet breder dan het venster)
        cmp #33
        bcc o1
        lda #33
        sta oN
o1:     lda #4
        sta a0
        lda #8
        clc
        adc lR
        sta a1
        inc lR
        pla
        jmp o_Draw
}

//--------------------------------------------------------
.encoding "screencode_upper"
sClPrev:  .text "<"
          .byte $ff
sClNext:  .text ">"
          .byte $ff
sClToday: .text "TODAY"
          .byte $ff
sClDays:  .text "WK  MO  TU  WE  TH  FR  SA  SU"
          .byte $ff
sSp5:     .text "     "
          .byte $ff
sClAdd:   .text "ADD"
          .byte $ff
sClEdit:  .text "EDIT"
          .byte $ff
sClDel:   .text "DELETE"
          .byte $ff
sClPrint: .text "PRINT"
          .byte $ff
sClSet:   .text "SET THE DATE: SYSTEM - TIME"
          .byte $ff
sClBad:   .text "AGENDA: LINES WITH ERRORS SKIPPED"
          .byte $ff
sClPick:  .text "CLICK AN APPOINTMENT FIRST"
          .byte $ff
sClSure:  .text "DELETE IT? PRESS Y"
          .byte $ff
sClFull:  .text "THE AGENDA IS FULL"
          .byte $ff
sFmNew:   .text "NEW APPOINTMENT"
          .byte $ff
sFmChg:   .text "CHANGE THE APPOINTMENT"
          .byte $ff
sFmTime:  .text "TIME"
          .byte $ff
sFmText:  .text "TEXT"
          .byte $ff
sFmRep:   .text "REPEAT"
          .byte $ff
sFmAll:   .text "ALL DAY"
          .byte $ff
sFmSave:  .text "SAVE"
          .byte $ff
sFmCancel: .text "CANCEL"
          .byte $ff
sFmBadT:  .text "TIME: HH:MM, OR EMPTY = ALL DAY"
          .byte $ff
sRep0:    .text "NONE   "
          .byte $ff
sRep1:    .text "WEEKLY "
          .byte $ff
sRep2:    .text "MONTHLY"
          .byte $ff
sRep3:    .text "YEARLY "
          .byte $ff
sRmTitle: .text "TODAY"
          .byte $ff
mon1:  .text "JANUARY"
       .byte $ff
mon2:  .text "FEBRUARY"
       .byte $ff
mon3:  .text "MARCH"
       .byte $ff
mon4:  .text "APRIL"
       .byte $ff
mon5:  .text "MAY"
       .byte $ff
mon6:  .text "JUNE"
       .byte $ff
mon7:  .text "JULY"
       .byte $ff
mon8:  .text "AUGUST"
       .byte $ff
mon9:  .text "SEPTEMBER"
       .byte $ff
mon10: .text "OCTOBER"
       .byte $ff
mon11: .text "NOVEMBER"
       .byte $ff
mon12: .text "DECEMBER"
       .byte $ff
monLo: .byte <mon1, <mon2, <mon3, <mon4, <mon5, <mon6, <mon7, <mon8, <mon9, <mon10, <mon11, <mon12
monHi: .byte >mon1, >mon2, >mon3, >mon4, >mon5, >mon6, >mon7, >mon8, >mon9, >mon10, >mon11, >mon12
day0:  .text "MONDAY"
       .byte $ff
day1:  .text "TUESDAY"
       .byte $ff
day2:  .text "WEDNESDAY"
       .byte $ff
day3:  .text "THURSDAY"
       .byte $ff
day4:  .text "FRIDAY"
       .byte $ff
day5:  .text "SATURDAY"
       .byte $ff
day6:  .text "SUNDAY"
       .byte $ff
dayLo: .byte <day0, <day1, <day2, <day3, <day4, <day5, <day6
dayHi: .byte >day0, >day1, >day2, >day3, >day4, >day5, >day6

tY:     .byte 0
tM:     .byte 0
tD:     .byte 0
vY:     .byte 0
vM:     .byte 0
vD:     .byte 0
vDim:   .byte 0
vOff:   .byte 0
clMode: .byte 0
clMsg:  .word 0
clI:    .byte 0
clSel:  .byte $ff
clTop:  .byte 0
gR:     .byte 0
gD:     .byte 0
gJ:     .byte 0
gC:     .byte 0
lR:     .byte 0
lRow:   .byte 0
lI:     .byte 0
oN:     .byte 0
oY2:    .byte 0
fHH:    .byte 0
fMM:    .byte 0
fRep:   .byte 0
fRec:   .word 0
fT:     .byte 0
fDig:   .fill 5, 0
fText:  .fill CT_W + 1, $ff
