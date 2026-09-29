#importonce
//========================================================
// apps/email/mail_text.asm - tekst uit mail naar het scherm
// Commodore Desk 64
//
//   cv_Byte   UTF-8 / ASCII -> schermcode (accenten -> gewone letter)
//   a2sc      ASCII -> schermcode
//   hv_*      headerwaarden met encoded words (=?UTF-8?Q/B?...?=)
//   b64_*     base64 decoderen (body, headers) en coderen (AUTH PLAIN)
//   tw_*      tekstschrijver: regels van CP_W tekens in MSGBUF, met
//             woordomslag en (optioneel) HTML-tags/entities eruit
//========================================================

//--------------------------------------------------------
// cv_Byte - byte A -> carry=1 + A = schermcode, of carry=0 (niets:
//           midden in een UTF-8-reeks).
//--------------------------------------------------------
cv_Byte: {
        ldx cvN
        bne cont
        cmp #$80
        bcs fb4324_2
        jmp a2sc
fb4324_2:
        cmp #$c0
        bcc no                   // losse vervolgbyte
        sta cvLead
        ldx #1
        cmp #$e0
        bcc set
        inx
        cmp #$f0
        bcc set
        inx
set:    stx cvN
        lda #0
        sta cvMid
no:     clc
        rts
cont:   cmp #$80                 // geen vervolgbyte: reeks afbreken
        bcc brk
        cmp #$c0
        bcs brk
        dec cvN
        bne mid
        ldx cvLead               // laatste byte: teken bepalen
        cpx #$c3
        beq lat
        cpx #$c2
        beq c2
        cpx #$e2
        bne q
        ldx cvMid
        cpx #$80
        bne q
        cmp #$98                 // E2 80 xx: aanhalingstekens, streepjes
        beq ap
        cmp #$99
        beq ap
        cmp #$9c
        beq dq
        cmp #$9d
        beq dq
        cmp #$93
        beq da
        cmp #$94
        beq da
        cmp #$a6
        beq dt
        cmp #$a2
        beq bu
q:      lda #$3f                 // ?
        sec
        rts
mid:    ldx cvMid                // eerste vervolgbyte onthouden
        bne no
        sta cvMid
        clc
        rts
brk:    ldx #0
        stx cvN
        jmp cv_Byte
c2:     cmp #$a0                 // harde spatie
        bne q
        lda #$20
        sec
        rts
lat:    and #$3f                 // C3 xx = Latin-1 $C0-$FF
        tax
        lda latTab,x
        jmp a2sc
ap:     lda #$27
        sec
        rts
dq:     lda #$22
        sec
        rts
da:     lda #$2d
        sec
        rts
dt:     lda #$2e
        sec
        rts
bu:     lda #$2a
        sec
        rts
}

// a2sc - ASCII A -> schermcode (carry=1). Hoofd- en kleine letters worden
//        dezelfde letter (de desktop-charset kent alleen hoofdletters).
a2sc: {
        cmp #$20
        bcc sp
        cmp #$40
        bcc ok
        beq at
        cmp #$5b
        bcc lt
        cmp #$60
        bcc sy
        beq bq
        cmp #$7b
        bcc lt
        cmp #$7f
        bcs sp
        tax
        lda syTab2-$7b,x
        sec
        rts
lt:     and #$1f
ok:     sec
        rts
at:     lda #0
        sec
        rts
bq:     lda #$27
        sec
        rts
sy:     tax
        lda syTab-$5b,x
        sec
        rts
sp:     lda #$20
        sec
        rts
syTab:  .byte $1b, $2f, $1d, $1e, $64      // [ \ ] ^ _
syTab2: .byte $28, $21, $29, $2d           // { | } ~
}

// Latin-1 $C0-$FF -> ASCII-letter zonder accent
.encoding "ascii"
latTab: .text "AAAAAAACEEEEIIIIDNOOOOOxOUUUUYPs"
        .text "aaaaaaaceeeeiiiidnooooo/ouuuuypy"
.encoding "screencode_upper"

//--------------------------------------------------------
// hexVal - ASCII-hexcijfer A -> 0-15, carry=1 geldig.
//--------------------------------------------------------
hexVal: {
        cmp #$30
        bcc no
        cmp #$3a
        bcc dg
        and #$df
        cmp #$41
        bcc no
        cmp #$47
        bcs no
        sbc #$36                 // (carry=0) 'A' -> 10
        sec
        rts
dg:     and #$0f
        sec
        rts
no:     clc
        rts
}

//--------------------------------------------------------
// base64
//--------------------------------------------------------
// b64_Val - ASCII A -> 0-63, carry=1 geldig.
b64_Val: {
        cmp #$41
        bcc lo
        cmp #$5b
        bcs lc
        sbc #$40                 // (carry=0) 'A' -> 0
        sec
        rts
lc:     cmp #$61
        bcc no
        cmp #$7b
        bcs no
        sbc #$46                 // (carry=0) 'a' -> 26
        sec
        rts
lo:     cmp #$2b
        beq pl
        cmp #$2f
        beq sl
        cmp #$30
        bcc no
        cmp #$3a
        bcs no
        adc #4                   // (carry=0) '0' -> 52
        sec
        rts
pl:     lda #62
        sec
        rts
sl:     lda #63
        sec
        rts
no:     clc
        rts
}

b64_Reset:
        lda #0
        sta b64N
        rts

// b64_Char - base64-teken A decoderen; bytes gaan naar (b64Vec).
b64_Char: {
        jsr b64_Val
        bcc out                  // '=', spaties e.d.
        sta b64V
        ldx b64N
        inx
        txa
        and #3
        sta b64N
        dex
        beq n0
        dex
        beq n1
        dex
        beq n2
        lda b64Acc               // 4e teken
        ora b64V
        jmp emit
n0:     lda b64V
        asl
        asl
        sta b64Acc
out:    rts
n1:     lda b64V
        lsr
        lsr
        lsr
        lsr
        ora b64Acc
        pha
        lda b64V
        asl
        asl
        asl
        asl
        sta b64Acc
        pla
        jmp emit
n2:     lda b64V
        lsr
        lsr
        ora b64Acc
        pha
        lda b64V
        ror
        ror
        ror
        and #$c0
        sta b64Acc
        pla
emit:   jmp (b64Vec)
}

// b64_Enc - A bytes vanaf (r6) base64-gecodeerd achter mnCmd (mc_Chr).
b64_Enc: {
        sta b64Cnt
        ldy #0
grp:    lda b64Cnt
        bne go
        rts
go:     lda #0
        sta b64G+1
        sta b64G+2
        lda (r6),y
        sta b64G
        iny
        ldx #1
        dec b64Cnt
        beq pad
        lda (r6),y
        sta b64G+1
        iny
        inx
        dec b64Cnt
        beq pad
        lda (r6),y
        sta b64G+2
        iny
        inx
        dec b64Cnt
pad:    stx b64Have
        lda b64G                 // 4 tekens
        lsr
        lsr
        jsr ch
        lda b64G
        and #3
        asl
        asl
        asl
        asl
        sta b64V
        lda b64G+1
        lsr
        lsr
        lsr
        lsr
        ora b64V
        jsr ch
        lda b64Have
        cmp #2
        bcc eq2
        lda b64G+1
        and #$0f
        asl
        asl
        sta b64V
        lda b64G+2
        rol
        rol
        rol
        and #3
        ora b64V
        jsr ch
        lda b64Have
        cmp #3
        bcc eq1
        lda b64G+2
        and #$3f
        jsr ch
        jmp grp
eq2:    lda #$3d
        jsr mc_Chr
eq1:    lda #$3d
        jsr mc_Chr
        jmp grp
ch:     tax
        lda b64Tab,x
        jmp mc_Chr
}
.encoding "ascii"
b64Tab: .text "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
.encoding "screencode_upper"

//--------------------------------------------------------
// Headerwaarden: 4 buffers (bytes, nog UTF-8), HV_MAX elk.
//   0 = From, 1 = Subject, 2 = Date, 3 = Content-Type
//--------------------------------------------------------
.const HV_FROM = 0
.const HV_SUBJ = 1
.const HV_DATE = 2
.const HV_CT   = 3

// hv_Clear - alle vier leeg.
hv_Clear:
        lda #0
        ldx #3
!:      sta hvLens,x
        dex
        bpl !-
        rts

// hv_Append - mnLine[mnOff..mnLen) (encoded words gedecodeerd) achter
//             buffer X plakken.
hv_Append: {
        stx hvSel
        lda hvBufLo,x
        sta hvOut+1
        lda hvBufHi,x
        sta hvOut+2
        lda hvLens,x
        sta hvLen
        lda #<hv_Out
        sta b64Vec
        lda #>hv_Out
        sta b64Vec+1
        ldy mnOff
lp:     cpy mnLen
        bcc go
        ldx hvSel
        lda hvLen
        sta hvLens,x
        rts
go:     lda mnLine,y
        cmp #$3d                 // =?  -> encoded word?
        bne lit
        lda mnLine+1,y
        cmp #$3f
        bne lit0
        sty hvI
        jsr hv_EW
        bcs lp
        ldy hvI
lit0:   lda mnLine,y
lit:    cmp #$20
        beq ws
        cmp #$09
        beq ws
        pha
        jsr hv_Ws
        pla
        jsr hv_Out
        lda #0
        sta hvEW
        iny
        jmp lp
ws:     lda #1
        sta hvWs
        iny
        jmp lp
}

// hv_Ws - uitgestelde witruimte als één spatie (niet aan het begin).
hv_Ws:
        lda hvWs
        beq !+
        lda #0
        sta hvWs
        lda hvLen
        beq !+
        lda #$20
        jmp hv_Out
!:      rts

// hv_Out - byte A in de gekozen buffer (Y blijft).
hv_Out: {
        ldx hvLen
        cpx #HV_MAX
        bcs r
hvSt:   sta $ffff,x              // (adres ingevuld door hv_Append)
        inc hvLen
r:      rts
}
.label hvOut = hv_Out.hvSt

// hv_EW - encoded word vanaf Y (bij "=?"). Carry=1 gedecodeerd, Y erachter.
hv_EW: {
        iny
        iny
cs:     cpy mnLen                // charset overslaan
        bcs no
        lda mnLine,y
        iny
        cmp #$3f
        bne cs
        lda mnLine,y             // Q of B
        and #$df
        sta hvEnc
        iny
        lda mnLine,y
        cmp #$3f
        bne no
        iny
        sty hvT
fe:     cpy mnLen                // einde "?="
        bcs no
        lda mnLine,y
        cmp #$3f
        bne nx
        lda mnLine+1,y
        cmp #$3d
        beq found
nx:     iny
        jmp fe
no:     clc
        rts
found:  sty hvE
        lda hvWs                 // witruimte tussen twee encoded words vervalt
        beq w1
        lda hvEW
        bne w0
        jsr hv_Ws
w0:     lda #0
        sta hvWs
w1:     jsr b64_Reset
        ldy hvT
dl:     cpy hvE
        bcs done
        lda hvEnc
        cmp #$42                 // B
        beq b
        lda mnLine,y
        cmp #$5f                 // Q: _ = spatie
        bne q1
        lda #$20
        jmp qo
q1:     cmp #$3d
        bne qo
        lda mnLine+1,y
        jsr hexVal
        bcc qe
        asl
        asl
        asl
        asl
        sta hvT
        lda mnLine+2,y
        jsr hexVal
        bcc qe
        ora hvT
        iny
        iny
        jmp qo
qe:     lda #$3d
qo:     jsr hv_Out
        iny
        jmp dl
b:      lda mnLine,y
        sty hvT2
        jsr b64_Char
        ldy hvT2
        iny
        jmp dl
done:   lda #1
        sta hvEW
        ldy hvE
        iny
        iny
        sec
        rts
}

// hv_Render - bytes [hvA..hvB) van buffer X -> schermcodes naar (r6),
//             hoogstens A tekens, $ff erachter.
hv_Render: {
        sta hvMax
        lda hvBufLo,x
        sta rd+1
        lda hvBufHi,x
        sta rd+2
        lda #0
        sta hvO
        sta cvN
        ldx hvA
lp:     cpx hvB
        bcs end
        stx hvI
rd:     lda $ffff,x
        jsr cv_Byte
        bcc nx
        ldy hvO
        cpy hvMax
        bcs end
        sta (r6),y
        inc hvO
nx:     ldx hvI
        inx
        bne lp
end:    ldy hvO
        lda #$ff
        sta (r6),y
        rts
}

// hv_Range - hvA = 0, hvB = lengte van buffer X.
hv_Range:
        lda #0
        sta hvA
        lda hvLens,x
        sta hvB
        rts

// fr_Split - From-buffer -> naam [frNa..frNb) en adres [frAa..frAb).
fr_Split: {
        ldx #0
        stx frNa
        stx frAa
        lda hvLens+HV_FROM
        sta frNb
        sta frAb
lt:     cpx hvLens+HV_FROM       // '<' zoeken
        bcs noLt
        lda hvBuf0,x
        cmp #$3c
        beq gotLt
        inx
        bne lt
noLt:   rts                      // alleen een adres: naam = adres
gotLt:  stx frNb
        inx
        stx frAa
gt:     cpx hvLens+HV_FROM
        bcs tn
        lda hvBuf0,x
        cmp #$3e
        beq gotGt
        inx
        bne gt
gotGt:  stx frAb
tn:     ldx frNb                 // naam: spaties en " achteraan weg
tb:     cpx frNa
        beq empty
        lda hvBuf0-1,x
        cmp #$20
        beq t1
        cmp #$22
        bne tf
t1:     dex
        jmp tb
tf:     stx frNb
        ldx frNa                 // " vooraan weg
        lda hvBuf0,x
        cmp #$22
        bne r
        inc frNa
r:      rts
empty:  lda frAa                 // lege naam: het adres tonen
        sta frNa
        lda frAb
        sta frNb
        rts
}

// ci_Find - komt de ASCII-tekst X/Y (klein, 0-afgesloten) voor in buffer
//           HV_CT (hoofdletterongevoelig)? Carry=1 ja, hvI = index erachter.
ci_Find: {
        stx r6
        sty r6+1
        ldx #0
st:     stx hvI
        ldy #0
cm:     lda (r6),y
        beq yes
        cpx hvLens+HV_CT
        bcs nx
        lda hvBuf3,x
        cmp #$41
        bcc c
        cmp #$5b
        bcs c
        ora #$20
c:      cmp (r6),y
        bne nx
        inx
        iny
        bne cm
nx:     ldx hvI
        inx
        cpx hvLens+HV_CT
        bcc st
        clc
        rts
yes:    stx hvI
        sec
        rts
}

//--------------------------------------------------------
// Tekstschrijver: MSGBUF, regels van CP_W tekens.
//--------------------------------------------------------
tw_Reset: {
        lda #0
        sta twLine
        sta twCol
        sta twFull
        sta twHtml
        sta twTag
        sta twEnt
        sta twSkip
        sta cvN
        lda #1                   // geen lege regels aan het begin
        sta twBlank
        lda #<MSGBUF
        sta twDst
        lda #>MSGBUF
        sta twDst+1
        rts
}

// tw_Byte - ruwe byte A uit de body.
tw_Byte: {
        ldx twHtml
        bne html
        cmp #$0a
        beq nl
        cmp #$0d
        beq r
        cmp #$09
        bne cv
        lda #$20
cv:     jsr cv_Byte
        bcc r
        jmp tw_Char
nl:     jmp tw_Nl
r:      rts
html:   ldx twTag
        bne tag
        ldx twEnt
        bne ent
        cmp #$3c                 // <
        bne h1
        lda #1
        sta twTag
        lda #0
        sta twTagL
        sta twTagN
        sta twTagN+1
        sta twTagN+2
        sta twTagN+3
        rts
h1:     ldx twSkip               // <style>/<script>: inhoud overslaan
        bne r
        cmp #$26                 // &
        bne h2
        lda #1
        sta twEnt
        lda #0
        sta twEntC
        rts
h2:     cmp #$21                 // witruimte -> hoogstens één spatie
        bcs cv
        ldx twCol
        beq r
        lda twBuf-1,x
        cmp #$20
        beq r
        lda #$20
        jmp tw_Char
tag:    cmp #$3e                 // >
        beq te
        cmp #$21
        bcc tsp
        ldx twTagL
        cpx #4
        bcs r
        ora #$20
        sta twTagN,x
        inc twTagL
        rts
tsp:    lda #4                   // na een spatie: naam compleet
        sta twTagL
        rts
te:     lda #0
        sta twTag
        jmp tw_TagEnd
ent:    cmp #$3b                 // ;
        beq ee
        ldx twEntC
        bne ec
        sta twEntC               // alleen het eerste teken telt
ec:     rts
ee:     lda #0
        sta twEnt
        lda twEntC
        ldx #5
em:     cmp entC,x
        beq ef
        dex
        bpl em
        rts
ef:     lda entV,x
        jsr a2sc
        jmp tw_Char
.encoding "ascii"
entC:   .text "nalgq#"
entV:   .text " &<>"
        .byte $22, $27
.encoding "screencode_upper"
}

// tw_TagEnd - einde van een HTML-tag: regeleinde of stijl/script.
tw_TagEnd: {
        ldx #0
        lda twTagN
        cmp #$2f                 // /
        bne n
        inx
n:      lda twTagN,x
        cmp #$73                 // s(tyle) / s(cript)
        bne nl
        lda twTagN+1,x
        cmp #$74                 // st(yle), niet st(rong)
        bne sc
        lda twTagN+2,x
        cmp #$79
        beq sk
        bne nl
sc:     cmp #$63                 // sc(ript)
        bne nl
sk:     lda #1
        cpx #0
        beq s1
        lda #0
s1:     sta twSkip
        rts
nl:     lda twTagN,x             // br p div tr li h1-h6 -> nieuwe regel
        cmp #$62
        bne p
        lda twTagN+1,x
        cmp #$72
        beq yes
        rts
p:      cmp #$70
        bne d
        lda twTagN+1,x
        beq yes
        rts
d:      cmp #$64
        bne t
        lda twTagN+1,x
        cmp #$69
        beq yes
        rts
t:      cmp #$74
        bne l
        lda twTagN+1,x
        cmp #$72
        beq yes
        rts
l:      cmp #$6c
        bne h
        lda twTagN+1,x
        cmp #$69
        beq yes
        rts
h:      cmp #$68
        bne r
        lda twTagN+1,x
        cmp #$31
        bcc r
        cmp #$37
        bcs r
yes:    jmp tw_Nl
r:      rts
}

// tw_Char - schermcode A erbij (woordomslag op CP_W tekens).
tw_Char: {
        ldx twFull
        bne r
        ldx twCol
        cpx #CP_W
        bcs wrap
        sta twBuf,x
        inc twCol
        lda #0
        sta twBlank
r:      rts
wrap:   cmp #$20
        bne w1
        jmp tw_Nl                // spatie op de grens: regel klaar
w1:     sta twC
        ldx #CP_W-1              // laatste spatie in de regel zoeken
ws:     lda twBuf,x
        cmp #$20
        beq sp
        dex
        bne ws
        jsr tw_Nl                // geen spatie: hard afbreken
        lda twC
        jmp tw_Char
sp:     stx twCol                // regel tot de spatie
        inx
        stx twI
        ldy #0                   // rest bewaren
cp:     cpx #CP_W
        bcs cd
        lda twBuf,x
        sta twTmp,y
        inx
        iny
        bne cp
cd:     sty twJ
        jsr tw_Nl
        ldx #0
cb:     cpx twJ
        bcs ad
        lda twTmp,x
        sta twBuf,x
        inx
        bne cb
ad:     stx twCol
        lda twC
        jmp tw_Char
}

// tw_Nl - huidige regel naar MSGBUF (aangevuld met spaties), volgende.
tw_Nl: {
        lda twFull
        bne r
        lda twCol
        bne go
        lda twBlank              // hoogstens één lege regel achter elkaar
        bne r
        inc twBlank
go:     lda twDst
        sta r6
        lda twDst+1
        sta r6+1
        ldy #0
cp:     cpy twCol
        bcs pad
        lda twBuf,y
        sta (r6),y
        iny
        bne cp
pad:    lda #$20
pl:     cpy #CP_W
        bcs nx
        sta (r6),y
        iny
        bne pl
nx:     lda #0
        sta twCol
        lda twDst
        clc
        adc #CP_W
        sta twDst
        bcc nc
        inc twDst+1
nc:     inc twLine
        lda twLine
        cmp #MS_LINES
        bcc r
        lda #1
        sta twFull
r:      rts
}

// tw_End - laatste regel afsluiten.
tw_End:
        lda twCol
        beq !+
        jmp tw_Nl
!:      rts

//--------------------------------------------------------
cvN:     .byte 0
cvLead:  .byte 0
cvMid:   .byte 0
.align 2
b64Vec:  .word 0
b64N:    .byte 0
b64V:    .byte 0
b64Acc:  .byte 0
b64Cnt:  .byte 0
b64Have: .byte 0
b64G:    .fill 3, 0
hvSel:   .byte 0
hvLen:   .byte 0
hvI:     .byte 0
hvT:     .byte 0
hvT2:    .byte 0
hvE:     .byte 0
hvEnc:   .byte 0
hvWs:    .byte 0
hvEW:    .byte 0
hvA:     .byte 0
hvB:     .byte 0
hvO:     .byte 0
hvMax:   .byte 0
frNa:    .byte 0
frNb:    .byte 0
frAa:    .byte 0
frAb:    .byte 0
hvLens:  .fill 4, 0
hvBufLo: .byte <hvBuf0, <hvBuf1, <hvBuf2, <hvBuf3
hvBufHi: .byte >hvBuf0, >hvBuf1, >hvBuf2, >hvBuf3
twDst:   .word 0
twLine:  .byte 0
twCol:   .byte 0
twFull:  .byte 0
twBlank: .byte 0
twHtml:  .byte 0
twTag:   .byte 0
twTagL:  .byte 0
twTagN:  .fill 4, 0
twEnt:   .byte 0
twEntC:  .byte 0
twSkip:  .byte 0
twC:     .byte 0
twI:     .byte 0
twJ:     .byte 0
