#importonce
//========================================================
// apps/calendar/cal_file.asm - AGENDA lezen/schrijven, afspraken zoeken
// Commodore Desk 64
//
// AGENDA (SEQ, PETSCII zoals de TEXT EDITOR schrijft), een regel per
// afspraak:   JJJJMMDD HHMM R TEKST      (HHMM = ---- : de hele dag;
//                                         R = - W M Y: herhalen)
//========================================================

// cf_Load - AGENDA -> CR_BUF (crN); regels met een fout: cfBad > 0.
cf_Load: {
        lda #0
        sta crN
        sta crN+1
        sta cfBad
        sta clLen
        sta cfFull
        lda #<CR_BUF
        sta cP
        lda #>CR_BUF
        sta cP+1
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
        and #$42                 // time-out / einde zonder data
        cmp #$02
        beq cl
        txa
        cmp #$0d
        beq eol
        ldx clLen
        cpx #79
        bcs nx
        sta CL_LINE,x
        inc clLen
        bne nx
eol:    jsr cf_Line
nx:     lda $90
        beq rd
        jsr cf_Line              // (laatste regel zonder CR)
cl:     jsr K_CLRCHN
        lda #2
        jsr K_CLOSE
        jmp cfg_io_end
.encoding "petscii_upper"
nm:     .text "AGENDA"
nmE:
.encoding "screencode_upper"
}

// cf_Line - de regel in CL_LINE (clLen) als afspraak op cP; dan leeg.
cf_Line: {
        lda clLen
        beq r                    // lege regel: niets
        jsr cf_Parse             // (leest clLen)
        lda #0
        sta clLen
        bcs ok
        inc cfBad
r:      rts
ok:     lda crN+1                // vol?
        cmp #>CR_MAX
        bcc a
        lda crN
        cmp #<CR_MAX
        bcc a
        inc cfFull
        rts
a:      lda cP
        clc
        adc #CR_LEN
        sta cP
        bcc i
        inc cP+1
i:      inc crN
        bne r
        inc crN+1
        rts
}

// cf_Parse - CL_LINE -> afspraak op cP. Carry=1: goed.
cf_Parse: {
        ldx #0                   // jaar: 4 cijfers
        jsr num2
        bcs bad
        sta pT                   // eeuw (19 of 20)
        ldx #2
        jsr num2
        bcs bad
        ldy pT
        cpy #19
        beq y19
        cpy #20
        bne bad
        clc
        adc #100
y19:    ldy #CR_Y
        sta (cP),y
        sta dY
        ldx #4
        jsr num2
        bcs bad
        cmp #1
        bcc bad
        cmp #13
        bcs bad
        sta dM
        ldy #CR_M
        sta (cP),y
        ldx #6
        jsr num2
        bcs bad
        cmp #1
        bcc bad
        sta dD
        jsr dt_Dim
        cmp dD
        bcc bad
        lda dD
        ldy #CR_D
        sta (cP),y
        lda CL_LINE+9            // tijd of ----
        cmp #$2d
        bne tm
        lda #$ff
        ldy #CR_HH
        sta (cP),y
        lda #0
        beq mm
bad:    clc
        rts
tm:     ldx #9
        jsr num2
        bcs bad
        cmp #24
        bcs bad
        ldy #CR_HH
        sta (cP),y
        ldx #11
        jsr num2
        bcs bad
        cmp #60
        bcs bad
mm:     ldy #CR_MM
        sta (cP),y
        lda CL_LINE+14           // herhalen: - W M Y
        and #$7f
        ldx #3
rp:     cmp cfRep,x
        beq rf
        dex
        bpl rp
        bmi bad
rf:     txa
        ldy #CR_REP
        sta (cP),y
        jsr dt_Dow
        ldy #CR_DOW
        sta (cP),y
        ldx #16                  // tekst (PETSCII -> schermcodes)
        ldy #CR_TXT
t:      cpx clLen
        bcs te
        cpy #CR_TXT+CT_W
        bcs te
        lda CL_LINE,x
        jsr p2s
        sta (cP),y
        inx
        iny
        bne t
te:     lda #$ff
        sta (cP),y
        lda clLen                // (minstens tot de herhaling)
        cmp #15
        bcc bad
        sec
        rts
// num2 - twee cijfers op CL_LINE+X -> A; carry=1: geen cijfers
num2:   lda CL_LINE,x
        jsr dig
        bcs n9
        sta pT2
        asl
        asl
        adc pT2
        asl
        sta pT2
        lda CL_LINE+1,x
        jsr dig
        bcs n9
        adc pT2
        clc
n9:     rts
dig:    sec
        sbc #$30
        cmp #10
        rts                      // (carry=1 als geen cijfer)
}
.encoding "petscii_upper"
cfRep:  .byte $2d, $57, $4d, $59  // - W M Y (PETSCII; and #$7f: ook SHIFT)
.encoding "screencode_upper"

// p2s - PETSCII -> schermcode (letters in beide gevallen als hoofdletters)
p2s: {
        cmp #$41
        bcc lo
        cmp #$5b
        bcc l1
        cmp #$c1
        bcc o
        cmp #$db
        bcs o
l1:     and #$1f
        rts
lo:     cmp #$20
        bcc o
        cmp #$40
        bcc r
        lda #0                   // @
        rts
o:      cmp #$a4
        bne q
        lda #$64                 // _
        rts
q:      lda #$2e
r:      rts
}
// s2p - schermcode -> PETSCII (zoals de TEXT EDITOR: letters $41-$5A)
s2p: {
        cmp #0
        bne a
        lda #$40
        rts
a:      cmp #27
        bcs b
        ora #$40
        rts
b:      cmp #$64
        bne c
        lda #$a4
        rts
c:      cmp #$20
        bcs r
        lda #$2e
r:      rts
}

// cf_Save - alle afspraken als AGENDA (SEQ). Carry=1: fout (X/Y = melding).
cf_Save: {
        jsr save_Begin
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
        bcs e
        ldx #2
        jsr K_CHKOUT
        bcs e
        lda #<CR_BUF
        sta cP
        lda #>CR_BUF
        sta cP+1
        lda crN
        sta sN
        lda crN+1
        sta sN+1
l:      lda sN
        ora sN+1
        beq d
        jsr cf_Out
        lda cP
        clc
        adc #CR_LEN
        sta cP
        bcc n
        inc cP+1
n:      lda sN
        bne n1
        dec sN+1
n1:     dec sN
        jmp l
d:
e:      jsr K_CLRCHN
        lda #2
        jsr K_CLOSE
        jsr cfg_io_end
        jsr save_End
        lda #8                   // hoe ging het? (72, DISK FULL ...)
        jsr dsk_Status
        lda dsCode
        cmp #20
        bcc ok
        ldx #<dsText
        ldy #>dsText
        sec
        rts
ok:     clc
        rts
.encoding "petscii_upper"
nm:     .text "@0:AGENDA,S,W"
nmE:
.encoding "screencode_upper"
}

// cf_Out - afspraak cP als regel naar het open bestand.
cf_Out: {
        ldy #CR_Y                // jaar
        lda (cP),y
        ldx #$31                 // 19.. of 20..
        cmp #100
        bcc c
        sbc #100
        ldx #$32
c:      pha
        txa
        jsr K_CHROUT
        lda #$39
        cpx #$32
        bne c2
        lda #$30
c2:     jsr K_CHROUT
        pla
        jsr out2
        ldy #CR_M
        lda (cP),y
        jsr out2
        ldy #CR_D
        lda (cP),y
        jsr out2
        jsr sp
        ldy #CR_HH
        lda (cP),y
        cmp #$ff
        bne t
        lda #$2d
        jsr K_CHROUT
        jsr K_CHROUT
        jsr K_CHROUT
        jsr K_CHROUT
        jmp r
t:      jsr out2
        ldy #CR_MM
        lda (cP),y
        jsr out2
r:      jsr sp
        ldy #CR_REP
        lda (cP),y
        tax
        lda cfRep,x
        jsr K_CHROUT
        jsr sp
        ldy #CR_TXT
x:      lda (cP),y
        cmp #$ff
        beq e
        jsr s2p
        sty oY
        jsr K_CHROUT
        ldy oY
        iny
        cpy #CR_TXT+CT_W
        bne x
e:      lda #$0d
        jmp K_CHROUT
sp:     lda #$20
        jmp K_CHROUT
// out2 - A (0-99) als twee cijfers
out2:   ldx #$2f
        sec
o1:     inx
        sbc #10
        bcs o1
        adc #$3a
        pha
        txa
        jsr K_CHROUT
        pla
        jmp K_CHROUT
}

//--------------------------------------------------------
// Afspraken op een dag
//--------------------------------------------------------
// cf_Match - valt afspraak cP op dY/dM/dD (weekdag dW)? Carry=1: ja.
cf_Match: {
        ldy #CR_REP
        lda (cP),y
        beq one
        cmp #3
        beq yr
        jsr ge                   // herhalingen: pas vanaf de eerste keer
        bcc no
        ldy #CR_REP
        lda (cP),y
        cmp #1
        beq wk
        ldy #CR_D                // maandelijks: zelfde dagnummer
        lda (cP),y
        cmp dD
        bne no
        sec
        rts
wk:     ldy #CR_DOW              // wekelijks: zelfde weekdag
        lda (cP),y
        cmp dW
        bne no
        sec
        rts
yr:     ldy #CR_Y                // jaarlijks: zelfde dag en maand, vanaf jaar
        lda dY
        cmp (cP),y
        bcc no
md:     ldy #CR_M
        lda (cP),y
        cmp dM
        bne no
        ldy #CR_D
        lda (cP),y
        cmp dD
        bne no
        sec
        rts
one:    ldy #CR_Y
        lda (cP),y
        cmp dY
        beq md
no:     clc
        rts
// ge - carry=1 als dY/dM/dD >= de datum van de afspraak
ge:     ldy #CR_Y
        lda dY
        cmp (cP),y
        bne g
        ldy #CR_M
        lda dM
        cmp (cP),y
        bne g
        ldy #CR_D
        lda dD
        cmp (cP),y
        bne g
        sec
g:      rts
}

// cf_Each - cP = eerste afspraak, cfI = aantal; cf_Next - cP verder.
cf_Each:
        lda #<CR_BUF
        sta cP
        lda #>CR_BUF
        sta cP+1
        lda crN
        sta cfI
        lda crN+1
        sta cfI+1
        rts
// cf_Next - carry=1: er was nog een afspraak (cP wijst ernaar, daarna verder)
cf_More: {
        lda cfI
        ora cfI+1
        bne y
        clc
        rts
y:      lda cfI
        bne d
        dec cfI+1
d:      dec cfI
        sec
        rts
}
cf_Adv:
        lda cP
        clc
        adc #CR_LEN
        sta cP
        bcc !+
        inc cP+1
!:      rts

// cf_Month - CL_MARK[dag] = 1 voor elke dag van maand dM/dY met afspraken.
cf_Month: {
        ldx #31
        lda #0
c:      sta CL_MARK,x
        dex
        bpl c
        jsr dt_Dim
        sta cfDim
        lda #1
        sta dD
        jsr dt_Dow
        sta dW
dl:     jsr cf_Each
al:     jsr cf_More
        bcc nd
        jsr cf_Match
        bcc an
        ldx dD
        lda #1
        sta CL_MARK,x
        bne nd                   // (een is genoeg voor deze dag)
an:     jsr cf_Adv
        jmp al
nd:     inc dW                   // volgende dag
        lda dW
        cmp #7
        bcc w
        lda #0
        sta dW
w:      inc dD
        lda dD
        cmp cfDim
        beq dl
        bcc dl
        lda #1
        sta dD
        rts
}

// cf_Day - de afspraken van dY/dM/dD in CL_DAY/CL_DAYH (cdN), op tijd
//          gesorteerd (de hele dag eerst).
cf_Day: {
        lda #0
        sta cdN
        jsr dt_Dow
        sta dW
        jsr cf_Each
l:      jsr cf_More
        bcc s
        jsr cf_Match
        bcc n
        ldx cdN
        cpx #CD_MAX
        bcs n
        lda cP
        sta CL_DAY,x
        lda cP+1
        sta CL_DAYH,x
        inc cdN
n:      jsr cf_Adv
        jmp l
s:      ldx #1                   // sorteren op invoegen (sleutel: uur+1, minuut)
o:      cpx cdN
        bcs r
        stx sI
i:      ldx sI
        beq nx
        jsr key                  // sleutel van X -> kH/kM
        lda kH
        sta kH2
        lda kM
        sta kM2
        dex
        jsr key                  // sleutel van X-1
        lda kH2                  // X-1 > X ? dan wisselen
        cmp kH
        bcc sw
        bne nx
        lda kM2
        cmp kM
        bcs nx
sw:     ldx sI
        lda CL_DAY,x
        pha
        lda CL_DAYH,x
        pha
        lda CL_DAY-1,x
        sta CL_DAY,x
        lda CL_DAYH-1,x
        sta CL_DAYH,x
        pla
        sta CL_DAYH-1,x
        pla
        sta CL_DAY-1,x
        dec sI
        jmp i
nx:     ldx sI
        inx
        jmp o
r:      rts
key:    lda CL_DAY,x
        sta cQ
        lda CL_DAYH,x
        sta cQ+1
        ldy #CR_HH
        lda (cQ),y
        clc
        adc #1                   // $ff (hele dag) -> 0: eerst
        sta kH
        ldy #CR_MM
        lda (cQ),y
        sta kM
        rts
}

crN:    .word 0
cfI:    .word 0
sN:     .word 0
cfBad:  .byte 0
cfFull: .byte 0
clLen:  .byte 0
cfDim:  .byte 0
dW:     .byte 0
cdN:    .byte 0
sI:     .byte 0
kH:     .byte 0
kM:     .byte 0
kH2:    .byte 0
kM2:    .byte 0
pT:     .byte 0
pT2:    .byte 0
oY:     .byte 0
