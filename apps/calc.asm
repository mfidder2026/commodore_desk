#importonce
//========================================================
// apps/calc.asm - Calculator (Fase 8)
// Commodore Desk 64
//
// 16-bits integer-rekenmachine, muis/cursor-bediend. Display +
// 4x4 toetsengrid (0-9, + - * /, =, C).
//========================================================

// calc_Init - reset.
calc_Init:
        lda #0
        sta calcVal
        sta calcVal+1
        sta calcAcc
        sta calcAcc+1
        sta calcOp
        lda #1
        sta calcNew
        rts

//--------------------------------------------------------
// calc_Draw - display + toetsen.
//--------------------------------------------------------
calc_Draw: {
        gfxDrawBox(6, 4, 22, 3, LIGHT_GREY)
        // display leegmaken met kleur, dan getal erin
        lda #7
        sta a0
        lda #5
        sta a1
        lda #20
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda #LIGHT_GREEN
        sta a5
        jsr gfx_FillRect
        lda #<[SCREEN_RAM + 5*40 + 22]
        sta r4
        lda #>[SCREEN_RAM + 5*40 + 22]
        sta r4+1
        jsr num2dec16
        // toetsen
        lda #0
        sta calcI
bloop:  lda calcI
        cmp #16
        bcs bdone
        lda calcI
        asl
        clc
        adc calcI                // i*3
        tax
        lda buttonTab,x
        sta a0
        lda buttonTab+1,x
        sta a1
        lda #4
        sta a2
        lda #LIGHT_GREY
        sta a3
        ldy calcI
        lda btnLabelLo,y
        sta r0
        lda btnLabelHi,y
        sta r0+1
        jsr btn_Draw
        inc calcI
        jmp bloop
bdone:  rts
}

//--------------------------------------------------------
// calc_Click - toets aanklikken.
//--------------------------------------------------------
calc_Click: {
        lda #0
        sta calcI
loop:   lda calcI
        cmp #16
        bcs done
        lda calcI
        asl
        clc
        adc calcI
        tax
        lda buttonTab,x
        sta a0
        lda buttonTab+1,x
        sta a1
        lda #4
        sta a2
        stx calcTmpX
        jsr btn_HitTest
        bcc nextb
        ldx calcTmpX
        lda buttonTab+2,x
        jsr calc_Action
        jsr calc_Draw
        rts
nextb:  inc calcI
        jmp loop
done:   rts
}

//--------------------------------------------------------
// calc_Action - waarde 0-9 (cijfer), 10-13 (+ - * /), 14 (=), 15 (C).
//--------------------------------------------------------
calc_Action: {
        cmp #10
        bcc digit
        cmp #15
        beq clear
        cmp #14
        beq equals
        // operator
        pha
        jsr calc_Equals
        lda calcVal
        sta calcAcc
        lda calcVal+1
        sta calcAcc+1
        pla
        sta calcOp
        lda #1
        sta calcNew
        rts
digit:  jmp calc_Digit
equals: jsr calc_Equals
        lda #1
        sta calcNew
        rts
clear:  lda #0
        sta calcVal
        sta calcVal+1
        sta calcAcc
        sta calcAcc+1
        sta calcOp
        lda #1
        sta calcNew
        rts
}

// calc_Digit - cijfer A toevoegen aan calcVal.
calc_Digit: {
        pha
        lda calcNew
        beq append
        pla
        sta calcVal
        lda #0
        sta calcVal+1
        sta calcNew
        rts
append: pla
        sta digitTmp
        jsr mulVal10
        lda calcVal
        clc
        adc digitTmp
        sta calcVal
        lda calcVal+1
        adc #0
        sta calcVal+1
        rts
}

// mulVal10 - calcVal *= 10.
mulVal10:
        lda calcVal
        sta mLo
        lda calcVal+1
        sta mHi
        asl calcVal
        rol calcVal+1
        asl calcVal
        rol calcVal+1
        lda calcVal
        clc
        adc mLo
        sta calcVal
        lda calcVal+1
        adc mHi
        sta calcVal+1
        asl calcVal
        rol calcVal+1
        rts

// calc_Equals - pas de openstaande operator toe (calcAcc OP calcVal -> calcVal).
calc_Equals: {
        lda calcOp
        beq done
        cmp #10
        beq doAdd
        cmp #11
        beq doSub
        cmp #12
        beq doMul
        jsr calc_Div
        jmp fin
doAdd:  jsr calc_Add
        jmp fin
doSub:  jsr calc_Sub
        jmp fin
doMul:  jsr calc_Mul
fin:    lda #0
        sta calcOp
done:   rts
}

calc_Add:
        lda calcAcc
        clc
        adc calcVal
        sta calcVal
        lda calcAcc+1
        adc calcVal+1
        sta calcVal+1
        rts

calc_Sub: {
        lda calcAcc
        sec
        sbc calcVal
        sta calcVal
        lda calcAcc+1
        sbc calcVal+1
        sta calcVal+1
        bcs ok
        lda #0
        sta calcVal
        sta calcVal+1
ok:     rts
}

calc_Mul: {
        lda #0
        sta resLo
        sta resHi
        ldx #16
loop:   lsr calcVal+1
        ror calcVal
        bcc noadd
        lda resLo
        clc
        adc calcAcc
        sta resLo
        lda resHi
        adc calcAcc+1
        sta resHi
noadd:  asl calcAcc
        rol calcAcc+1
        dex
        bne loop
        lda resLo
        sta calcVal
        lda resHi
        sta calcVal+1
        rts
}

calc_Div: {
        lda calcVal
        ora calcVal+1
        bne go
        lda #0                   // deel door 0 -> 0
        sta calcVal
        sta calcVal+1
        rts
go:     lda #0
        sta remLo
        sta remHi
        sta quoLo
        sta quoHi
        ldx #16
loop:   asl calcAcc
        rol calcAcc+1
        rol remLo
        rol remHi
        lda remLo
        sec
        sbc calcVal
        sta tmpLo
        lda remHi
        sbc calcVal+1
        bcc noSub
        sta remHi
        lda tmpLo
        sta remLo
        sec
        jmp shiftQ
noSub:  clc
shiftQ: rol quoLo
        rol quoHi
        dex
        bne loop
        lda quoLo
        sta calcVal
        lda quoHi
        sta calcVal+1
        rts
}

//--------------------------------------------------------
// num2dec16 - calcVal (0-65535) als 5 decimalen op (r4).
//--------------------------------------------------------
num2dec16: {
        lda calcVal
        sta nLo
        lda calcVal+1
        sta nHi
        lda #0
        sta p10i
loop:   ldx p10i
        lda #0
        sta digitv
sub:    lda nLo
        sec
        sbc pow10Lo,x
        sta t
        lda nHi
        sbc pow10Hi,x
        bcc done
        sta nHi
        lda t
        sta nLo
        inc digitv
        ldx p10i
        jmp sub
done:   ldy p10i
        lda digitv
        ora #$30
        sta (r4),y
        inc p10i
        lda p10i
        cmp #5
        bne loop
        rts
pow10Lo: .byte <10000, <1000, <100, <10, <1
pow10Hi: .byte >10000, >1000, >100, >10, >1
}

//--------------------------------------------------------
// Data
//--------------------------------------------------------
calcVal:  .word 0
calcAcc:  .word 0
calcOp:   .byte 0
calcNew:  .byte 1
calcI:    .byte 0
calcTmpX: .byte 0
digitTmp: .byte 0
mLo:      .byte 0
mHi:      .byte 0
resLo:    .byte 0
resHi:    .byte 0
remLo:    .byte 0
remHi:    .byte 0
quoLo:    .byte 0
quoHi:    .byte 0
tmpLo:    .byte 0
nLo:      .byte 0
nHi:      .byte 0
t:        .byte 0
digitv:   .byte 0
p10i:     .byte 0

// Toetsen: kol, rij, waarde (0-9 cijfer; 10=+ 11=- 12=* 13=/ 14== 15=C)
buttonTab:
        .byte 8,8,7,    13,8,8,   18,8,9,   23,8,13
        .byte 8,10,4,   13,10,5,  18,10,6,  23,10,12
        .byte 8,12,1,   13,12,2,  18,12,3,  23,12,11
        .byte 8,14,0,   13,14,15, 18,14,14, 23,14,10

btnLabelLo: .byte <k7,<k8,<k9,<kdiv,<k4,<k5,<k6,<kmul,<k1,<k2,<k3,<kmin,<k0,<kc,<keq,<kplus
btnLabelHi: .byte >k7,>k8,>k9,>kdiv,>k4,>k5,>k6,>kmul,>k1,>k2,>k3,>kmin,>k0,>kc,>keq,>kplus

.encoding "screencode_upper"
k7:  .text " 7 "
     .byte $ff
k8:  .text " 8 "
     .byte $ff
k9:  .text " 9 "
     .byte $ff
kdiv:.text " / "
     .byte $ff
k4:  .text " 4 "
     .byte $ff
k5:  .text " 5 "
     .byte $ff
k6:  .text " 6 "
     .byte $ff
kmul:.text " * "
     .byte $ff
k1:  .text " 1 "
     .byte $ff
k2:  .text " 2 "
     .byte $ff
k3:  .text " 3 "
     .byte $ff
kmin:.text " - "
     .byte $ff
k0:  .text " 0 "
     .byte $ff
kc:  .text " C "
     .byte $ff
keq: .text " = "
     .byte $ff
kplus:.text " + "
      .byte $ff
