#importonce
//========================================================
// apps/calendar/cal_print.asm - de dag of de maand afdrukken
// Commodore Desk 64
//
// Met de printerdriver van EDITOR en PAINT (macro PrinterDriver, de
// printer die bij PRINT op het bureaublad gekozen is).
//========================================================

clPr: PrinterDriver()

// cl_Print - "D = de dag, M = de maand", dan afdrukken.
cl_Print: {
        ldx #<sPrQ
        ldy #>sPrQ
        jsr cl_Ask
        cmp #4                   // D
        beq d
        cmp #13                  // M
        beq m
        jmp cl_Redraw
d:      jsr clPr.pr_Open
        bcs msg                  // (de driver is dan al dicht)
        jsr p_Day
        bcs err
        jmp done
m:      jsr clPr.pr_Open
        bcs msg
        jsr p_Month
        bcs err
done:   jsr clPr.pr_Close
        lda #<sPrDone
        sta clMsg
        lda #>sPrDone
        sta clMsg+1
        jmp r
err:    jsr clPr.pr_Shut         // (geen papier meer sturen)
msg:    stx clMsg
        sty clMsg+1
r:      lda vY                   // (de dag weer zoals hij was)
        sta dY
        lda vM
        sta dM
        jsr cl_Day
        jmp cl_Redraw
}

// p_Line - CL_OUT (oN tekens) als regel naar de printer. Carry=1: fout.
p_Line: {
        lda #<CL_OUT
        sta r6
        lda #>CL_OUT
        sta r6+1
        ldy oN
        jsr clPr.pr_Line
        lda #0
        sta oN
        rts
}

// p_Day - de gekozen dag vD (cf_Day gedaan): titel, feestdag, afspraken.
p_Day: {
        lda #0
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
        jsr p_Line
        bcs r
        ldx vD                   // feestdag
        lda CL_HOL,x
        beq a
        tax
        lda #$2a
        jsr o_Chr
        lda #$20
        jsr o_Chr
        lda calHolLo,x
        ldy calHolHi,x
        jsr o_Str
        jsr p_Line
        bcs r
a:      ldx #0
l:      cpx cdN
        bcs e
        stx lI
        jsr cl_Entry
        jsr p_Line
        bcs r
        ldx lI
        inx
        bne l
e:      jsr p_Line               // lege regel
r:      rts
}

// p_Month - de maand: titel, weekdagen, het raster, dan elke dag met
//           afspraken of een feestdag.
p_Month: {
        lda #0
        sta oN
        ldx vM
        lda monLo-1,x
        ldy monHi-1,x
        jsr o_Str
        lda #$20
        jsr o_Chr
        jsr o_Year
        jsr p_Line
        bcc !c4+
        jmp r
!c4:
        jsr p_Line
        bcc !c5+
        jmp r
!c5:
        lda #<sClDays
        ldy #>sClDays
        jsr o_Str
        jsr p_Line
        bcc !c6+
        jmp r
!c6:
        lda #0                   // het raster
        sta gR
        lda #1
        sec
        sbc vOff
        sta gD
gr:     lda gD                   // nog een dag in deze rij?
        bmi gv
        beq gv
        cmp vDim
        beq gv
        bcs ds
gv:     lda #0
        sta oN
        jsr wk                   // weeknummer
        lda #$20
        jsr o_Chr
        ldx #0
gc:     stx gJ
        lda gD
        bmi sp
        beq sp
        cmp vDim
        beq nm
        bcs sp
nm:     lda #$20
        jsr o_Chr
        lda gD
        cmp #10
        bcs n2
        lda #$20
        jsr o_Chr
        lda gD
        ora #$30
        jsr o_Chr
        jmp mk
n2:     jsr num2s0
mk:     ldx gD
        lda #$20
        ldy CL_MARK,x
        beq mk1
        lda #$2a
mk1:    jsr o_Chr
        jmp nx
sp:     lda #$20
        jsr o_Chr
        jsr o_Chr
        jsr o_Chr
        jsr o_Chr
nx:     inc gD
        ldx gJ
        inx
        cpx #7
        bne gc
        jsr p_Line
        bcs r
        inc gR
        lda gR
        cmp #6
        beq !c0+
        jmp gr
!c0:
ds:     jsr p_Line               // de dagen
        bcs r
        lda vD
        pha
        lda #1
        sta vD
dl:     ldx vD
        lda CL_MARK,x
        ora CL_HOL,x
        beq dn
        lda vY
        sta dY
        lda vM
        sta dM
        lda vD
        sta dD
        jsr cf_Day
        jsr p_Day
        bcs rr
dn:     inc vD
        lda vD
        cmp vDim
        beq dl
        bcc dl
        clc
rr:     pla
        sta vD
r:      rts
// wk - weeknummer van de rij (gD = maandag) achter CL_OUT
wk:     lda gD
        clc
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
        sec
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
pv:     dec dM
        bne p1
        lda #12
        sta dM
        dec dY
p1:     jsr dt_Dim
        clc
        adc dD
        sta dD
ok:     jsr dt_Week
        cmp #10
        bcs w2
        pha
        lda #$20
        jsr o_Chr
        pla
        ora #$30
        jmp o_Chr
w2:     jmp num2s0
}

.encoding "screencode_upper"
sPrQ:    .text "PRINT: D = THE DAY, M = THE MONTH"
         .byte $ff
sPrDone: .text "PRINTED"
         .byte $ff
