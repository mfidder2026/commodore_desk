#importonce
//========================================================
// apps/calendar/cal_date.asm - datumrekenen (1900-2099)
// Commodore Desk 64
//
// In: dY (jaar - 1900), dM (1-12), dD (1-31). Alles binair.
//   dt_Dow     -> A = weekdag (0 = maandag)
//   dt_Leap    -> carry=1: schrikkeljaar (1900 niet, 2000 wel)
//   dt_Dim     -> A = dagen in de maand
//   dt_Doy     -> dDoy (16 bits) = dag van het jaar (1 = 1 januari)
//   dt_FromDoy dDoy -> dM, dD (in jaar dY)
//   dt_Week    -> A = ISO-weeknummer van de week waarin de datum ligt
//                 (de donderdag van die week bepaalt het jaar)
//   dt_Easter  -> dEaster (16 bits) = dag van het jaar van eerste Paasdag
//   dt_Holidays (dY, dM) -> CL_HOL[1..31] = nummer van de feestdag (0 = geen)
//========================================================

// dt_Dow - weekdag van dY/dM/dD (0 = maandag). Sakamoto met het jaar
//          mod 28 (de weekdagen herhalen zich elke 28 jaar tussen 1901
//          en 2099; 1900 klopt ook, nagerekend voor 1900-2099): (j + j/4 + t[m] + d + 1) mod 7 = 0 voor zondag.
dt_Dow: {
        lda dY
        ldx dM
        cpx #3
        bcs y
        sec                      // januari, februari: het jaar ervoor
        sbc #1
        bcs y
        lda #5                   // 1899: j + j/4 = 6 (mod 7), net als 1899
y:      cmp #28                  // mod 28
        bcc m
        sbc #28
        bcs y
m:      sta dT
        lsr
        lsr
        clc
        adc dT
        ldx dM
        adc dtMonT-1,x
        adc dD
        adc #1
s7:     cmp #7
        bcc z
        sbc #7
        bcs s7
z:      clc                      // 0 = zondag -> 6, 1 = maandag -> 0
        adc #6
        cmp #7
        bcc r
        sbc #7
r:      rts
}
dtMonT: .byte 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4

// dt_Leap - carry=1 als dY een schrikkeljaar is (deelbaar door 4, niet 1900).
dt_Leap: {
        lda dY
        beq n
        and #3
        bne n
        sec
        rts
n:      clc
        rts
}

// dt_Dim - A = dagen in maand dM van jaar dY.
dt_Dim: {
        ldx dM
        lda dtDim-1,x
        cpx #2
        bne r
        jsr dt_Leap
        lda #28
        adc #0                   // (carry = schrikkeljaar)
r:      rts
}
dtDim:  .byte 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

// dt_Doy - dDoy = dag van het jaar van dY/dM/dD.
dt_Doy: {
        ldx dM
        lda dtCumLo-1,x
        clc
        adc dD
        sta dDoy
        lda dtCumHi-1,x
        adc #0
        sta dDoy+1
        cpx #3                   // na februari in een schrikkeljaar: +1
        bcc r
        jsr dt_Leap
        bcc r
        inc dDoy
        bne r
        inc dDoy+1
r:      rts
}
.var cum = List().add(0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334)
dtCumLo: .fill 12, <cum.get(i)
dtCumHi: .fill 12, >cum.get(i)

// dt_FromDoy - dDoy (in jaar dY) -> dM, dD.
dt_FromDoy: {
        lda #12
        sta dM
l:      jsr dt_Start             // dT16 = eerste dag van maand dM - 1
        lda dDoy                 // dDoy > dT16 ?
        cmp dT16
        lda dDoy+1
        sbc dT16+1
        bcc p
        lda dDoy
        cmp dT16
        bne f
        lda dDoy+1
        cmp dT16+1
        beq p
f:      lda dDoy                 // dag = dDoy - dT16
        sec
        sbc dT16
        sta dD
        rts
p:      dec dM
        bne l
        lda #1
        sta dM
        sta dD
        rts
}
// dt_Start - dT16 = aantal dagen van het jaar voor maand dM.
dt_Start: {
        ldx dM
        lda dtCumLo-1,x
        sta dT16
        lda dtCumHi-1,x
        sta dT16+1
        cpx #3
        bcc r
        jsr dt_Leap
        bcc r
        inc dT16
        bne r
        inc dT16+1
r:      rts
}

// dt_Week - ISO-weeknummer van dY/dM/dD: (dag van het jaar van de donderdag
//           van die week - 1) / 7 + 1, in het jaar van die donderdag.
dt_Week: {
        lda dY                   // (bewaren: de donderdag kan in een ander
        pha                      //  jaar of een andere maand liggen)
        lda dM
        pha
        lda dD
        pha
        jsr dt_Dow               // donderdag = datum + 3 - weekdag
        sta dT
        jsr dt_Doy
        lda dDoy
        clc
        adc #3
        sta dDoy
        bcc a
        inc dDoy+1
a:      lda dDoy
        sec
        sbc dT
        sta dDoy
        bcs b
        dec dDoy+1
b:      lda dDoy+1               // < 1: in het jaar ervoor
        bmi pv
        ora dDoy
        bne c
pv:     dec dY
        jsr ydays                // + dagen van dat jaar
        clc
        adc dDoy
        sta dDoy
        txa
        adc dDoy+1
        sta dDoy+1
        jmp w
c:      lda dDoy+1               // eind december: misschien het jaar erna
        beq w
        lda #<365
        ldx #>365
        jsr ydays                // A/X = dagen in dit jaar
        sta dT
        cpx dDoy+1
        bne w
        lda dT
        cmp dDoy
        bcs w
        lda dDoy                 // dDoy - dagen in het jaar
        sec
        sbc dT
        sta dDoy
        lda #0
        sta dDoy+1
w:      lda dDoy                 // (dDoy - 1) / 7 + 1
        sec
        sbc #1
        sta dT16
        lda dDoy+1
        sbc #0
        sta dT16+1
        ldx #0
d7:     lda dT16
        sec
        sbc #7
        tay
        lda dT16+1
        sbc #0
        bcc dd
        sta dT16+1
        sty dT16
        inx
        bne d7
dd:     inx
        pla
        sta dD
        pla
        sta dM
        pla
        sta dY
        txa
        rts
// ydays - A/X = 365 of 366 (jaar dY)
ydays:  jsr dt_Leap
        lda #<365
        adc #0
        ldx #>365
        rts
}

// dt_Easter - dEaster = dag van het jaar van eerste Paasdag (Gauss, voor
//             1900-2099: M = 24, N = 5). Jaar = dY + 1900.
//   a = j mod 19, b = j mod 4, c = j mod 7 (1900 is deelbaar door 19 en 4;
//   1900 mod 7 = 3), d = (19a + 24) mod 30, e = (2b + 4c + 6d + 5) mod 7,
//   Pasen = 22 maart + d + e; 26 april -> 19 april; 25 april met d = 28,
//   e = 6, a > 10 -> 18 april.
dt_Easter: {
        lda dY                   // a
        ldx #19
        jsr mod
        sta eA
        lda dY                   // b
        and #3
        sta eB
        lda dY                   // c = (dY + 3) mod 7
        clc
        adc #3
        ldx #7
        jsr mod
        sta eC
        lda #24                  // d = (19a + 24) mod 30
        ldy eA
        beq d1
d0:     clc
        adc #19
        cmp #30
        bcc d2
        sbc #30
d2:     dey
        bne d0
d1:     sta eD
        lda eB                   // e = (2b + 4c + 6d + 5) mod 7
        asl
        sta eE
        lda eC
        asl
        asl
        clc
        adc eE
        sta eE
        lda eD
        asl
        clc
        adc eD
        asl                      // 6d
        clc
        adc eE
        adc #5
        ldx #7
        jsr mod
        sta eE
        lda #3                   // dag van het jaar van 22 maart
        sta dM
        lda #22
        sta dD
        jsr dt_Doy
        lda dDoy
        clc
        adc eD
        sta dEaster
        lda dDoy+1
        adc #0
        sta dEaster+1
        lda dEaster
        clc
        adc eE
        sta dEaster
        bcc x
        inc dEaster+1
x:      lda #4                   // uitzonderingen: 26 april, 25 april
        sta dM
        lda #26
        sta dD
        jsr dt_Doy
        jsr same
        beq m7
        lda #25
        sta dD
        jsr dt_Doy
        jsr same
        bne r
        lda eD
        cmp #28
        bne r
        lda eE
        cmp #6
        bne r
        lda eA
        cmp #11
        bcc r
m7:     lda dEaster
        sec
        sbc #7
        sta dEaster
        bcs r
        dec dEaster+1
r:      rts
same:   lda dEaster              // Z=1 als dEaster = dDoy
        cmp dDoy
        bne s
        lda dEaster+1
        cmp dDoy+1
s:      rts
// mod - A mod X
mod:    stx eT
m:      cmp eT
        bcc mr
        sbc eT
        bcs m
mr:     rts
}

// dt_Holidays - de Nederlandse feestdagen van maand dM (jaar dY) in
//               CL_HOL[dag] (nummer, zie calHolLo; 0 = geen).
dt_Holidays: {
        lda dM
        sta hM
        ldx #31
        lda #0
c:      sta CL_HOL,x
        dex
        bpl c
        jsr dt_Easter
        ldx #0                   // vaste dagen: maand, dag, nummer
f:      lda hFix,x
        beq ea
        cmp hM
        bne fn
        ldy hFix+1,x
        lda hFix+2,x
        sta CL_HOL,y
fn:     inx
        inx
        inx
        bne f
ea:     ldx #0                   // Pasen + n: doy, terug naar maand/dag
e:      cpx #6
        beq k
        stx hI
        lda dEaster
        clc
        adc hEoff,x
        sta dDoy
        lda dEaster+1
        adc #0
        sta dDoy+1
        lda hEoff,x              // (Goede Vrijdag: -2)
        bpl e1
        dec dDoy+1
e1:     jsr dt_FromDoy
        lda dM
        cmp hM
        bne e2
        ldx hI
        ldy dD
        lda hEnum,x
        sta CL_HOL,y
e2:     ldx hI
        inx
        bne e
k:      lda hM                   // Koningsdag (vanaf 2014): 27 april, 26 als
        sta dM                   // de 27e een zondag is; daarvoor Koninginnedag
        cmp #4                   // 30 april (29 als de 30e een zondag is)
        bne r
        lda #27
        ldx #HOL_KING
        ldy dY
        cpy #114
        bcs k1
        lda #30
        ldx #HOL_QUEEN
k1:     sta dD
        stx hI
        jsr dt_Dow
        cmp #6
        bne k2
        dec dD
k2:     ldy dD
        lda hI
        sta CL_HOL,y
r:      lda hM
        sta dM
        rts
}
// vaste feestdagen: maand, dag, nummer
hFix:   .byte 1, 1, 1, 5, 5, 8, 12, 25, 12, 12, 26, 13, 0
// Pasen + n: Goede Vrijdag, 1e/2e Paasdag, Hemelvaart, 1e/2e Pinksterdag
hEoff:  .byte -2, 0, 1, 39, 49, 50
hEnum:  .byte 2, 3, 4, 9, 10, 11

.encoding "screencode_upper"
hol1:   .text "NEW YEAR'S DAY"
        .byte $ff
hol2:   .text "GOOD FRIDAY"
        .byte $ff
hol3:   .text "EASTER SUNDAY"
        .byte $ff
hol4:   .text "EASTER MONDAY"
        .byte $ff
hol6:   .text "KING'S DAY"
        .byte $ff
hol7:   .text "QUEEN'S DAY"
        .byte $ff
hol8:   .text "LIBERATION DAY"
        .byte $ff
hol9:   .text "ASCENSION DAY"
        .byte $ff
hol10:  .text "WHIT SUNDAY"
        .byte $ff
hol11:  .text "WHIT MONDAY"
        .byte $ff
hol12:  .text "CHRISTMAS DAY"
        .byte $ff
hol13:  .text "BOXING DAY"
        .byte $ff
// nummer -> naam (0 en 5 bestaan niet)
calHolLo: .byte 0, <hol1, <hol2, <hol3, <hol4, 0, <hol6, <hol7, <hol8, <hol9, <hol10, <hol11, <hol12, <hol13
calHolHi: .byte 0, >hol1, >hol2, >hol3, >hol4, 0, >hol6, >hol7, >hol8, >hol9, >hol10, >hol11, >hol12, >hol13

dY:     .byte 0
dM:     .byte 1
dD:     .byte 1
dT:     .byte 0
dDoy:   .word 0
dT16:   .word 0
dEaster: .word 0
eA:     .byte 0
eB:     .byte 0
eC:     .byte 0
eD:     .byte 0
eE:     .byte 0
eT:     .byte 0
hM:     .byte 0
hI:     .byte 0
