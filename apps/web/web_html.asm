#importonce
//========================================================
// apps/web/web_html.asm - HTML (of platte tekst) -> tekstregels
// Commodore Desk 64
//
// ht_Byte krijgt het antwoord byte voor byte (terwijl het binnenkomt) en
// zet het om naar regels van WB_W tekens in het pagina-geheugen (wP):
//   regel = [lengte] inhoud [lengte], inhoud = schermcodes en de codes
//   WC_ACC/WC_ACCX (kop aan/uit) en WC_LINK n / WC_LINKX (link n).
// Woorden worden eerst in WB_WORD verzameld en dan op de regel gezet
// (afbreken op de laatste spatie); codes hebben geen breedte en lopen met
// hun woord mee. Een regel begint opnieuw met de link/kop die nog open is.
//
// Zoekmodus (htFind): niets tekenen, alleen de links nalopen tot de link
// met controlegetal fdLo/fdHi gevonden is (lange adressen worden niet
// bewaard, zie lk_Store).
//========================================================

// toestanden van de lezer (htSt)
.const ST_TEXT  = 0
.const ST_TAG   = 1              // na <: de naam
.const ST_ATTRS = 2              // tussen attributen
.const ST_ANAME = 3              // attribuutnaam
.const ST_AFTER = 4              // na de naam (= of een nieuw attribuut)
.const ST_AVS   = 5              // begin van de waarde
.const ST_AVQ   = 6              // waarde tussen aanhalingstekens
.const ST_AVU   = 7              // waarde zonder aanhalingstekens
.const ST_ENT   = 8              // &naam;
.const ST_COMM  = 9              // <!-- ... -->
.const ST_DECL  = 10             // <!...> of <?...>: tot >
.const ST_UTF   = 11             // UTF-8-vervolgbytes
.const ST_SKIP  = 12             // inhoud van script/style: tot </naam
.const ST_BANG  = 13             // na <!

// tag-acties (htTags)
.const A_NONE = 0
.const A_BRK  = 1
.const A_PARA = 2
.const A_HEAD = 3
.const A_BOLD = 4
.const A_LI   = 5
.const A_A    = 6
.const A_TITLE= 7
.const A_PRE  = 8
.const A_SKIP = 9
.const A_IMG  = 10
.const A_HR   = 11
.const A_CELL = 12
.const A_FORM = 13
.const A_INPUT= 14
.const A_BR   = 15

// ht_Begin - A = 0: HTML, 1: platte tekst. Het pagina-geheugen is al leeg
//            (pg_Reset); htFind blijft zoals hij gezet is.
ht_Begin:
        sta htPlain
        sta htPre
        lda #0
        sta htSt
        sta htTitle
        sta htFound
        sta lnLen
        sta lnW
        sta wdLen
        sta wdW
        sta spPend
        sta lnAcc
        sta inLink
        sta fmState
        sta fmHave
        sta htAccN
        lda #1
        sta lastBlank
        lda #$ff
        sta lnLink
        rts

//--------------------------------------------------------
// ht_Byte - een byte van het antwoord.
//--------------------------------------------------------
ht_Byte: {
        sta htC
        ldx htFull               // pagina vol of link gevonden: klaar
        bne r
        ldx htFound
        bne r
        ldx htSt
        lda htJmpHi,x
        pha
        lda htJmpLo,x
        pha
        lda htC
r:      rts
}
htJmpLo: .byte <[st_Text-1], <[st_Tag-1], <[st_Attrs-1], <[st_AName-1], <[st_After-1]
         .byte <[st_AvS-1], <[st_AvQ-1], <[st_AvU-1], <[st_Ent-1], <[st_Comm-1]
         .byte <[st_Decl-1], <[st_Utf-1], <[st_Skip-1], <[st_Bang-1]
htJmpHi: .byte >[st_Text-1], >[st_Tag-1], >[st_Attrs-1], >[st_AName-1], >[st_After-1]
         .byte >[st_AvS-1], >[st_AvQ-1], >[st_AvU-1], >[st_Ent-1], >[st_Comm-1]
         .byte >[st_Decl-1], >[st_Utf-1], >[st_Skip-1], >[st_Bang-1]

// gewone tekst
st_Text: {
        ldx htPlain
        bne pl
        cmp #$3c                 // <
        beq lt
        cmp #$26                 // &
        beq amp
pl:     ldx htFind               // zoekmodus: tekst doet niet mee
        bne r
        cmp #$80
        bcs utf
        jmp ht_Char
lt:     lda #ST_TAG
        sta htSt
        lda #0
        sta nmLen
        sta htClose
        rts
amp:    ldx htFind
        bne r
        lda #ST_ENT
        sta htSt
        lda #0
        sta entLen
r:      rts
utf:    sta utfLead              // UTF-8: C2-DF 1, E0-EF 2, F0-F4 3 vervolgbytes;
        ldx #0                   // anders een Latin-1-teken
        stx cpHi
        cmp #$c2
        bcc lat
        cmp #$e0
        bcc u2
        cmp #$f0
        bcc u3
        cmp #$f5
        bcs lat
        and #$07
        ldx #3
        bne us
u3:     and #$0f
        ldx #2
        bne us
u2:     and #$1f
        ldx #1
us:     sta cpLo
        stx utfN
        lda #ST_UTF
        sta htSt
        rts
lat:    sta cpLo
        jmp ht_Cp
}

st_Utf: {
        and #$c0
        cmp #$80
        bne bad
        ldx #6                   // cp = cp << 6 | (byte & $3f)
l:      asl cpLo
        rol cpHi
        dex
        bne l
        lda htC
        and #$3f
        ora cpLo
        sta cpLo
        dec utfN
        bne r
        lda #ST_TEXT
        sta htSt
        jmp ht_Cp
bad:    lda #ST_TEXT             // geen UTF-8: de eerste byte was Latin-1
        sta htSt
        lda utfLead
        sta cpLo
        lda #0
        sta cpHi
        jsr ht_Cp
        lda htC
        jmp ht_Byte
r:      rts
}

// ht_Cp - teken cpHi/cpLo (Unicode) -> ASCII naar ht_Char (onbekend: weg).
ht_Cp: {
        lda cpHi
        bne hi
        lda cpLo
        bpl as
        cmp #$c0
        bcs l1
        ldx #cpTab0E-cpTab0-1    // $80-$BF: een paar tekens
t0:     cmp cpTab0,x
        beq g0
        dex
        bpl t0
        rts
g0:     lda cpTab0R,x
as:     jmp ht_Char
l1:     sec                      // $C0-$FF: letter zonder accent
        sbc #$c0
        tax
        lda latTab,x
        jmp ht_Char
hi:     cmp #$20
        bne r
        lda cpLo
        ldx #cpTab2E-cpTab2-1
t2:     cmp cpTab2,x
        beq g2
        dex
        bpl t2
r:      rts
g2:     lda cpTab2R,x
        cmp #$2e                 // ... = drie punten
        bne as
        jsr ht_Char
        lda #$2e
        jsr ht_Char
        lda #$2e
        jmp ht_Char
}
cpTab0:  .byte $a0, $ab, $bb, $b4, $b7, $a9, $ae, $d7
cpTab0E:
cpTab0R: .byte $20, $22, $22, $27, $2e, $43, $52, $58
cpTab2:  .byte $18, $19, $1c, $1d, $13, $14, $22, $26, $10, $11, $12, $15
cpTab2E:
cpTab2R: .byte $27, $27, $22, $22, $2d, $2d, $2a, $2e, $2d, $2d, $2d, $2d
// Latin-1 $C0-$FF -> letter zonder accent (ASCII)
.encoding "ascii"
latTab:  .text "AAAAAAACEEEEIIIIDNOOOOOXOUUUUYTS"
         .text "AAAAAAACEEEEIIIIDNOOOOO/OUUUUYTY"
.encoding "screencode_upper"

//--------------------------------------------------------
// ht_Char - ASCII-teken A in de tekst (titel, pre, spaties, woorden).
//--------------------------------------------------------
ht_Char: {
        ldx htTitle
        bne ti
        cmp #$0a
        beq nl
        cmp #$0d
        beq cr
        cmp #$09
        beq tab
        cmp #$0c
        beq sp
        cmp #$20
        beq sp
        bcc r
        ldx #0
        stx htPreNL
        jsr asc2scr
        bcs r
        jmp ht_Vis
nl:     ldx htPre
        beq ws
        ldx htPreNL
        beq n1
        ldx #0
        stx htPreNL
        rts
n1:     jmp ht_NL
cr:     ldx htPre
        beq ws
r:      rts
tab:    ldx htPre
        beq ws
t8:     lda #$20                 // tot de volgende 8
        jsr ht_Vis
        lda lnW
        and #7
        bne t8
        rts
sp:     ldx htPre
        beq ws
        lda #$20
        jmp ht_Vis
ws:     jmp ht_Space
ti:     cmp #$21                 // titel: spaties samenvoegen
        bcs tc
        ldx ttLen
        beq r
        lda WB_TITLE-1,x
        cmp #$20
        beq r
        lda #$20
        bne tp
tc:     jsr asc2scr
        bcs r
tp:     ldx ttLen
        cpx #WB_W
        bcs r
        sta WB_TITLE,x
        inc ttLen
        lda #$ff
        sta WB_TITLE+1,x
        rts
}

// asc2scr - ASCII A -> schermcode A (carry=1: geen teken). Klein = hoofd.
asc2scr: {
        cmp #$20
        bcc no
        cmp #$40
        bcc ok
        beq at
        cmp #$5b
        bcc up
        cmp #$61
        bcc pu
        cmp #$7b
        bcc lo
        cmp #$7f
        bcs no
        tax
        lda t7b-$7b,x
ok:     clc
        rts
pu:     tax
        lda t5b-$5b,x
        clc
        rts
up:     sec
        sbc #$40
        clc
        rts
lo:     sec
        sbc #$60
        clc
        rts
at:     lda #0
        clc
        rts
no:     sec
        rts
t5b:    .byte $1b, $2f, $1d, $1e, $64, $27      // [ \ ] ^ _ `
t7b:    .byte $28, $21, $29, $2d                // { | } ~
}

//--------------------------------------------------------
// Woorden en regels
//--------------------------------------------------------
// ht_Vis - zichtbaar teken (schermcode A).
ht_Vis: {
        ldx htPre
        beq w
        ldx lnW                  // pre / platte tekst: direct op de regel
        cpx #WB_W
        bcc p
        pha
        jsr ht_EmitLine
        pla
p:      jsr ln_Raw
        inc lnW
        rts
w:      ldx wdLen
        cpx #60
        bcc s
        pha
        jsr ht_Flush
        pla
        ldx wdLen
s:      sta WB_WORD,x
        inc wdLen
        inc wdW
        lda wdW
        cmp #WB_W
        bcc r
        jmp ht_Flush             // te lang woord: hard afbreken
r:      rts
}

// ht_Ctl - code A (geen breedte): in het woord (of in pre op de regel).
ht_Ctl: {
        ldx htPre
        beq w
        jmp ln_PutC
w:      ldx wdLen
        cpx #62
        bcs r
        sta WB_WORD,x
        inc wdLen
r:      rts
}

// ht_Space - spatie tussen woorden.
ht_Space:
        jsr ht_Flush
        lda #1
        sta spPend
        rts

// ht_Flush - het woord op de regel (of op een nieuwe regel).
ht_Flush: {
        lda wdLen
        beq r
        lda wdW
        beq cp                   // alleen codes: geen spatie
        ldx #0
        lda spPend
        beq ns
        lda lnW
        beq ns
        inx
ns:     stx flSp
        txa
        clc
        adc lnW
        adc wdW
        cmp #WB_W+1
        bcc fit
        lda lnW
        beq fit                  // (lege regel: dan maar zo)
        jsr ht_EmitLine
        lda #0
        sta flSp
fit:    lda flSp
        beq ap
        lda #$20
        jsr ln_Raw
        inc lnW
ap:     lda lnW
        clc
        adc wdW
        sta lnW
        lda #0
        sta spPend
cp:     ldx #0
l:      cpx wdLen
        beq e
        stx flI
        lda WB_WORD,x
        jsr ln_PutC
        ldx flI
        inx
        bne l
e:      lda #0
        sta wdLen
        sta wdW
r:      rts
}

// ln_PutC - byte A op de regel, en de stand van link/kop bijhouden.
ln_PutC: {
        ldx lnId                 // vorige byte was WC_LINK: dit is n
        beq c
        ldx #0
        stx lnId
        sta lnLink
        jmp ln_Raw
c:      cmp #WC_LINK
        bne c1
        inc lnId
        bne ln_Raw
c1:     cmp #WC_LINKX
        bne c2
        ldx #$ff
        stx lnLink
        bne ln_Raw
c2:     cmp #WC_ACC
        bne c3
        ldx #1
        stx lnAcc
        bne ln_Raw
c3:     cmp #WC_ACCX
        bne ln_Raw
        ldx #0
        stx lnAcc
}
// ln_Raw - byte A op de regel (zonder meer).
ln_Raw: {
        ldx lnLen
        cpx #63
        bcs r
        sta WB_LINE,x
        inc lnLen
r:      rts
}

// ht_EmitLine - de regel naar het pagina-geheugen; de volgende begint met
//               de link/kop die nog open is.
ht_EmitLine: {
        lda lnLink
        cmp #$ff
        beq a1
        lda #WC_LINKX
        jsr ln_Raw
a1:     lda lnAcc
        beq a2
        lda #WC_ACCX
        jsr ln_Raw
a2:     jsr pg_Store
        lda lnW
        bne nb
        lda #1
        .byte $2c
nb:     lda #0
        sta lastBlank
        lda #0
        sta lnLen
        sta lnW
        lda lnLink
        cmp #$ff
        beq b1
        lda #WC_LINK
        jsr ln_Raw
        lda lnLink
        jsr ln_Raw
b1:     lda lnAcc
        beq r
        lda #WC_ACC
        jmp ln_Raw
r:      rts
}

// ht_NL - nieuwe regel in pre/platte tekst (ook leeg).
ht_NL:
        jmp ht_EmitLine

// ht_Brk - regel afsluiten als er iets op staat.
ht_Brk: {
        jsr ht_Flush
        lda #0
        sta spPend
        lda lnW
        beq r
        jmp ht_EmitLine
r:      rts
}

// ht_Para - regel afsluiten + een lege regel (niet twee achter elkaar).
ht_Para:
        jsr ht_Brk
ht_Blank: {
        lda lastBlank
        bne r
        lda nLines
        ora nLines+1
        beq r
        lda #1
        sta lastBlank
        lda lnLen                // (de codes van de regel blijven staan)
        pha
        lda #0
        sta lnLen
        jsr pg_Store
        pla
        sta lnLen
r:      rts
}

// pg_Store - WB_LINE (lnLen) als regel in het pagina-geheugen.
pg_Store: {
        lda wU2                  // grens = wU2 - 48 (48 bytes voor de slotregel)
        sec
        sbc #48
        sta psL
        lda wU2+1
        sbc #0
        sta psL+1
        lda lnLen
        clc
        adc #2
        adc wP
        tax
        lda wP+1
        adc #0
        cmp psL+1
        bcc ok
        bne full
        cpx psL
        bcc ok
full:   lda #1
        sta htFull
        rts
ok:
pg_StoreF:
        ldy #0
        lda lnLen
        sta (wP),y
        tax
        beq e
l:      lda WB_LINE,y
        iny
        sta (wP),y
        dex
        bne l
e:      iny
        lda lnLen
        sta (wP),y
        iny                      // wP += lengte + 2
        tya
        clc
        adc wP
        sta wP
        bcc i
        inc wP+1
i:      inc nLines
        bne r
        inc nLines+1
r:      rts
}

// ht_End - het laatste woord en de laatste regel; vol: een slotregel.
ht_End: {
        lda htFind
        bne r
        jsr ht_Flush
        lda lnW
        beq f
        jsr ht_EmitLine
f:      lda htFull
        beq r
        ldx #0
        lda #WC_ACC
        sta WB_LINE
l:      lda sPgCut,x
        cmp #$ff
        beq e
        sta WB_LINE+1,x
        inx
        bne l
e:      inx
        stx lnLen
        jmp pg_Store.pg_StoreF
r:      rts
}

//--------------------------------------------------------
// Tags
//--------------------------------------------------------
st_Tag: {
        ldx nmLen
        bne nm
        cmp #$2f                 // </...
        bne t1
        ldx htClose
        bne dc
        inc htClose
        rts
t1:     cmp #$21                 // <!
        bne t2
        lda #0
        sta bngN
        lda #ST_BANG
        sta htSt
        rts
t2:     cmp #$3f                 // <?
        beq dc
        jsr isAlpha
        bcc nt
nm:     jsr isAlnum
        bcc en
        jsr lower
        ldx nmLen
        cpx #15
        bcs r
        sta WB_NAME,x
        inc nmLen
r:      rts
en:     pha                      // naam compleet
        jsr tg_Lookup
        pla
        ldx #ST_ATTRS
        stx htSt
        jmp st_Attrs
dc:     lda #ST_DECL
        sta htSt
        rts
nt:     ldx htClose              // geen tag: "<" is gewoon tekst
        bne dc
        lda #ST_TEXT
        sta htSt
        lda #$3c
        ldx htFind
        bne x
        jsr ht_Char
x:      lda htC
        jmp st_Text
}

st_Bang: {
        cmp #$2d                 // <!-- ?
        bne o
        inc bngN
        lda bngN
        cmp #2
        bcc r
        lda #0
        sta bngN
        lda #ST_COMM
        sta htSt
r:      rts
o:      cmp #$3e
        beq t
        lda #ST_DECL
        sta htSt
        rts
t:      lda #ST_TEXT
        sta htSt
        rts
}

st_Comm: {
        cmp #$2d
        bne o
        inc bngN
        rts
o:      cmp #$3e
        bne z
        lda bngN
        cmp #2
        bcc z
        lda #ST_TEXT
        sta htSt
z:      lda #0
        sta bngN
        rts
}

st_Decl: {
        cmp #$3e
        bne r
        lda #ST_TEXT
        sta htSt
r:      rts
}

st_Attrs: {
        cmp #$3e
        bne a1
        jmp tg_End
a1:     jsr isSpace
        bcs r
        cmp #$2f
        beq r
        ldx #0
        stx anLen
        ldx #ST_ANAME
        stx htSt
        jmp st_AName
r:      rts
}

st_AName: {
        cmp #$3d                 // =
        beq eq
        cmp #$3e
        beq gt
        jsr isSpace
        bcs sp
        cmp #$2f
        beq sp
        jsr lower
        ldx anLen
        cpx #15
        bcs r
        sta WB_ANAME,x
        inc anLen
r:      rts
eq:     jsr av_Select
        lda #ST_AVS
        sta htSt
        rts
sp:     lda #ST_AFTER
        sta htSt
        rts
gt:     jmp tg_End
}

st_After: {
        jsr isSpace
        bcs r
        cmp #$3d
        bne o
        jsr av_Select
        lda #ST_AVS
        sta htSt
r:      rts
o:      cmp #$3e
        bne n
        jmp tg_End
n:      ldx #0
        stx anLen
        ldx #ST_ANAME
        stx htSt
        jmp st_AName
}

st_AvS: {
        jsr isSpace
        bcs r
        cmp #$22
        beq q
        cmp #$27
        beq q
        cmp #$3e
        bne u
        jsr av_Done
        jmp tg_End
u:      ldx #ST_AVU
        stx htSt
        jmp av_Put
q:      sta htQ
        lda #ST_AVQ
        sta htSt
r:      rts
}

st_AvQ: {
        cmp htQ
        beq d
        jmp av_Put
d:      jsr av_Done
        lda #ST_ATTRS
        sta htSt
        rts
}

st_AvU: {
        jsr isSpace
        bcs d
        cmp #$3e
        bne p
        jsr av_Done
        jmp tg_End
p:      jmp av_Put
d:      jsr av_Done
        lda #ST_ATTRS
        sta htSt
        rts
}

// tg_Lookup - WB_NAME (nmLen) opzoeken in htTags -> tgAct (open of dicht),
//             tgOpen; de attribuutbuffers leeg ($ff = er niet).
tg_Lookup: {
        lda #$ff
        sta WB_HREF
        sta WB_INAME
        sta WB_ITYPE
        lda #0
        sta avOn                 // (geen waarde bewaren)
        sta tgAct
        sta tgOpen
        lda #<htTags             // lengte, naam, open, dicht ... 0
        sta wS
        lda #>htTags
        sta wS+1
nx:     ldy #0
        lda (wS),y
        beq r
        cmp nmLen
        bne sk
        tax
        iny
cp:     lda (wS),y
        cmp WB_NAME-1,y
        bne sk
        iny
        dex
        bne cp
        lda (wS),y               // open-actie
        sta tgOpen
        ldx htClose
        bne c
        cmp #A_FORM              // <form>: de action van het vorige weg
        bne o                    // (niet bij elke tag: die blijft nodig)
        ldx #$ff
        stx WB_FACT
        bne o
c:
        iny
        lda (wS),y               // dicht-actie
o:      sta tgAct
r:      rts
sk:     ldy #0                   // volgende: lengte + 3
        lda (wS),y
        clc
        adc #3
        adc wS
        sta wS
        bcc nx
        inc wS+1
        bne nx
}

// av_Select - waar komt de waarde van dit attribuut (tag tgOpen, naam
//             WB_ANAME)? avMax = 0: nergens.
av_Select: {
        lda #0
        sta avOn
        ldx tgOpen
        cpx #A_A
        bne n1
        ldy #sAhref-htAttrs             // a href
        jsr an_Is
        beq !w0+
        jmp r
!w0:
        lda #<WB_HREF            // (tot URL_MAX tekens)
        ldx #>WB_HREF
        ldy #<URL_MAX
        jsr set
        lda #>URL_MAX
        sta avMax+1
        rts
n1:     cpx #A_IMG
        bne n2
        ldy #sAalt-htAttrs
        jsr an_Is
        bne r
        lda #<WB_HREF
        ldx #>WB_HREF
        ldy #40
        bne set
n2:     cpx #A_FORM
        bne n3
        ldy #sAaction-htAttrs
        jsr an_Is
        bne m
        lda #<WB_FACT
        ldx #>WB_FACT
        ldy #159
        bne set
m:      ldy #sAmethod-htAttrs
        jsr an_Is
        bne r
        lda #<WB_ITYPE
        ldx #>WB_ITYPE
        ldy #15
        bne set
n3:     cpx #A_INPUT
        bne r
        ldy #sAtype-htAttrs
        jsr an_Is
        bne i1
        lda #<WB_ITYPE
        ldx #>WB_ITYPE
        ldy #15
        bne set
i1:     ldy #sAname-htAttrs
        jsr an_Is
        bne i2
        lda #<WB_INAME
        ldx #>WB_INAME
        ldy #31
        bne set
i2:     ldy #sAvalue-htAttrs
        jsr an_Is
        bne r
        lda #<WB_HREF
        ldx #>WB_HREF
        ldy #63
set:    sta wA
        sta avBeg
        stx wA+1
        stx avBeg+1
        sty avMax
        lda #0
        sta avMax+1
        sta avLen
        sta avLen+1
        tay
        sta (wA),y
        lda #1
        sta avOn
r:      rts
}

// an_Is - WB_ANAME (anLen) == tekst op htAttrs+Y (0-afgesloten)? Z=1: ja.
an_Is: {
        ldx #0
l:      lda htAttrs,y
        beq e
        cpx anLen
        beq no
        cmp WB_ANAME,x
        bne no
        inx
        iny
        bne l
e:      cpx anLen
        rts
no:     lda #1
        rts
}

// av_Put - teken A van de waarde bewaren (tot avMax tekens).
av_Put: {
        ldx avOn
        beq r
        ldx avLen+1
        cpx avMax+1
        bcc ok
        bne r
        ldx avLen
        cpx avMax
        bcs r
ok:     ldy #0
        sta (wA),y
        inc wA
        bne i
        inc wA+1
i:      inc avLen
        bne r
        inc avLen+1
r:      rts
}

// av_Done - waarde afsluiten; "&amp;" -> "&" (lezen wS, schrijven wQ).
av_Done: {
        lda avOn
        beq r
        lda #0
        sta avOn
        tay
        sta (wA),y
        lda avBeg
        sta wS
        sta wQ
        lda avBeg+1
        sta wS+1
        sta wQ+1
l:      ldy #0
        lda (wS),y
        beq e
        jsr inS
        cmp #$26
        bne w
m:      lda (wS),y               // volgt "amp;"?
        cmp sAmp,y
        bne w0
        iny
        cpy #4
        bne m
        lda wS
        clc
        adc #4
        sta wS
        bcc w0
        inc wS+1
w0:     lda #$26
w:      ldy #0
        sta (wQ),y
        inc wQ
        bne l
        inc wQ+1
        jmp l
e:      sta (wQ),y
r:      rts
inS:    inc wS
        bne s
        inc wS+1
s:      rts
}

//--------------------------------------------------------
// tg_End - einde van een tag: actie uitvoeren.
//--------------------------------------------------------
tg_End: {
        lda #ST_TEXT
        sta htSt
        lda htFind
        beq n
        lda tgOpen               // zoekmodus: alleen <a href>
        cmp #A_A
        bne r
        lda htClose
        bne r
        jmp fd_Check
n:      ldx tgAct
        lda actHi,x
        pha
        lda actLo,x
        pha
r:      rts
}
actLo:  .byte <[r_None-1], <[ht_Brk-1], <[ht_Para-1], <[ac_Head-1], <[ac_Bold-1], <[ac_Li-1]
        .byte <[ac_A-1], <[ac_Title-1], <[ac_Pre-1], <[ac_Skip-1], <[ac_Img-1], <[ac_Hr-1]
        .byte <[ht_Space-1], <[ac_Form-1], <[ac_Input-1], <[ac_Br-1]
actHi:  .byte >[r_None-1], >[ht_Brk-1], >[ht_Para-1], >[ac_Head-1], >[ac_Bold-1], >[ac_Li-1]
        .byte >[ac_A-1], >[ac_Title-1], >[ac_Pre-1], >[ac_Skip-1], >[ac_Img-1], >[ac_Hr-1]
        .byte >[ht_Space-1], >[ac_Form-1], >[ac_Input-1], >[ac_Br-1]
r_None: rts

ac_Head: {
        lda htClose
        bne c
        jsr ht_Para
        jmp acOn
c:      jsr acOff
        jmp ht_Para
}

ac_Bold: {
        lda htClose
        bne acOff
}
// acOn / acOff - kop/vet aan of uit; genest (<b> in <h1>) telt mee.
acOn: {
        lda htAccN
        inc htAccN
        cmp #0
        bne r
        lda #WC_ACC
        jmp ht_Ctl
r:      rts
}
acOff: {
        lda htAccN
        beq r
        dec htAccN
        bne r
        lda #WC_ACCX
        jmp ht_Ctl
r:      rts
}

ac_Li: {
        jsr ht_Brk
        lda #$2a                 // *
        jsr ht_Vis
        jmp ht_Space
}

ac_Br: {
        jsr ht_Flush
        lda #0
        sta spPend
        lda lnW
        beq b
        jmp ht_EmitLine
b:      jmp ht_Blank
}

ac_Title: {
        ldx #0
        lda htClose
        bne c
        stx ttLen
        inx
c:      stx htTitle
        rts
}

ac_Pre: {
        jsr ht_Para
        lda htClose
        eor #1
        sta htPre
        sta htPreNL              // (de regelovergang direct na <pre> telt niet)
        rts
}

// ac_Skip - script/style/...: overslaan tot "</naam".
ac_Skip: {
        lda htClose
        bne r
        lda #$3c
        sta WB_ENT
        lda #$2f
        sta WB_ENT+1
        ldx #0
l:      cpx nmLen
        beq e
        cpx #13
        beq e
        lda WB_NAME,x
        sta WB_ENT+2,x
        inx
        bne l
e:      inx
        inx
        stx skLen
        lda #0
        sta skM
        lda #ST_SKIP
        sta htSt
r:      rts
}

st_Skip: {
        jsr lower
        ldx skM
        cmp WB_ENT,x
        beq m
        ldx #0
        cmp #$3c
        bne s
        inx
s:      stx skM
        rts
m:      inx
        stx skM
        cpx skLen
        bne r
        lda #ST_DECL             // "</script" gevonden: verder tot >
        sta htSt
r:      rts
}

// ac_Img - [alt-tekst]; alt="" (versiering): niets; geen alt: [IMAGE].
ac_Img: {
        lda WB_HREF
        beq r
        jsr ht_Space
        lda #$1b                 // [
        jsr ht_Vis
        lda WB_HREF
        cmp #$ff
        beq im
        ldx #0
l:      stx imI
        lda WB_HREF,x
        beq e
        jsr asc2scr
        bcs n
        jsr ht_Vis
n:      ldx imI
        inx
        cpx #24
        bne l
        beq e
im:     ldx #0
l2:     lda sImage,x
        cmp #$ff
        beq e
        stx imI
        jsr ht_Vis
        ldx imI
        inx
        bne l2
e:      lda #$1d                 // ]
        jsr ht_Vis
        jmp ht_Space
r:      rts
}

ac_Hr: {
        jsr ht_Brk
        ldx #WB_W
l:      stx imI
        lda #$2d
        jsr ht_Vis
        ldx imI
        dex
        bne l
        jmp ht_Brk
}

// ac_A - <a href>: link begint (als het adres te volgen is); </a>: einde.
ac_A: {
        lda htClose
        bne c
        jsr c                    // (een open link eerst sluiten)
        lda WB_HREF
        beq r
        cmp #$ff
        beq r
        jsr lk_Ok
        bcc r
        lda linkN
        cmp #WL_MAX
        bcs r
        jsr lk_Store
        lda #WC_LINK
        jsr ht_Ctl
        lda linkN
        jsr ht_Ctl
        inc linkN
        lda #1
        sta inLink
r:      rts
c:      lda inLink
        beq r
        lda #0
        sta inLink
        lda #WC_LINKX
        jmp ht_Ctl
}

// lk_Ok - is WB_HREF een link om te volgen? (niet #..., mailto:,
//         javascript: ...). Carry=1: ja.
lk_Ok: {
        lda WB_HREF
        cmp #$23                 // #anker op deze pagina
        beq no
        ldx #0                   // een schema (letters + :) voor / ? #
l:      lda WB_HREF,x
        beq ok
        cmp #$3a
        beq sc
        cmp #$2f
        beq ok
        cmp #$3f
        beq ok
        cmp #$23
        beq ok
        inx
        bne l
ok:     sec
        rts
sc:     cpx #4                   // http: of https:
        beq h
        cpx #5
        bne no
h:      lda WB_HREF
        ora #$20
        cmp #$68
        bne no
        sec
        rts
no:     clc
        rts
}

// lk_Store - adres van link linkN bewaren (kort genoeg en er is plek):
//            eerst achter de code (wU, tot wbEnd), dan bovenin het
//            paginageheugen (wU2, er blijft 2 KB voor tekst); anders alleen
//            het controlegetal.
lk_Store: {
        ldx #0
l:      lda WB_HREF,x            // lengte
        beq e
        inx
        bne l
        dex
e:      stx lkLen
        cpx #201
        bcs hs
        lda wU                   // A: wU - lengte - 1 >= wbEnd ?
        ldy wU+1
        jsr sub
        cpy #>wbEnd
        bcc b
        bne oka
        cpx #<wbEnd
        bcc b
oka:    stx wU
        sty wU+1
        jmp put
b:      lda wP                   // B: wU2 - lengte - 1 >= wP + 2048 ?
        sta psL
        lda wP+1
        clc
        adc #8
        sta psL+1
        lda wU2
        ldy wU2+1
        jsr sub
        cpy psL+1
        bcc hs
        bne okb
        cpx psL
        bcc hs
okb:    stx wU2
        sty wU2+1
put:    stx wQ                   // adres op X/Y
        sty wQ+1
        ldy #0
c:      cpy lkLen
        beq ce
        lda WB_HREF,y
        sta (wQ),y
        iny
        bne c
ce:     lda lkLen
        sta (wQ),y
        ldx linkN
        lda wQ
        sta LK_LO,x
        lda wQ+1
        sta LK_HI,x
        lda lkLen
        sta LK_H,x
        rts
hs:     jsr lk_Hash              // te lang / geen plek: controlegetal
        ldx linkN
        lda hsLo
        sta LK_LO,x
        lda hsHi
        sta LK_H,x
        lda #0
        sta LK_HI,x
        rts
// sub - X/Y = (A/Y) - lengte - 1
sub:    sec
        sbc lkLen
        tax
        tya
        sbc #0
        tay
        txa
        bne d
        dey
d:      dex
        rts
}

// lk_Hash - controlegetal van WB_HREF (h = h * 33 xor teken) -> hsLo/hsHi.
lk_Hash: {
        lda #$05
        sta hsLo
        lda #$15
        sta hsHi
        lda #<WB_HREF
        sta wS
        lda #>WB_HREF
        sta wS+1
l:      ldy #0
        lda (wS),y
        beq r
        lda hsLo
        sta hsT
        lda hsHi
        sta hsT+1
        ldx #5
s:      asl hsLo
        rol hsHi
        dex
        bne s
        lda hsLo
        clc
        adc hsT
        sta hsLo
        lda hsHi
        adc hsT+1
        sta hsHi
        lda (wS),y
        eor hsLo
        sta hsLo
        inc wS
        bne l
        inc wS+1
        bne l
r:      rts
}

// fd_Check - zoekmodus: is dit de gezochte link? Dan naar WB_NEW.
fd_Check: {
        lda WB_HREF
        beq r
        cmp #$ff
        beq r
        jsr lk_Hash
        lda hsLo
        cmp fdLo
        bne r
        lda hsHi
        cmp fdHi
        bne r
        ldx #CP_HREF_NEW         // het hele adres
        jsr cp_Pair
        lda #1
        sta htFound
r:      rts
}

//--------------------------------------------------------
// Formulier: alleen GET, het eerste met een tekstveld.
//   fmState 0 = nog geen, 1 = erin, 2 = klaar (er is een veld), 3 = POST
//--------------------------------------------------------
ac_Form: {
        lda htClose
        bne c
        lda fmState
        bne r
        lda #1
        sta fmState
        lda #0
        sta WB_FHID
        lda WB_FACT
        cmp #$ff
        bne m
        lda #0
        sta WB_FACT
m:      lda WB_ITYPE
        ora #$20
        cmp #$70                 // post
        bne r
        lda #3
        sta fmState
r:      rts
c:      lda fmState
        cmp #1
        bne r
        lda fmHave
        bne d
        lda #0                   // geen tekstveld: een volgend formulier mag
        sta fmState
        rts
d:      lda #2
        sta fmState
        rts
}

ac_Input: {
        lda fmState
        cmp #1
        bne r
        lda WB_ITYPE             // type: (geen), text, search -> veld
        cmp #$ff
        beq fl
        ora #$20
        cmp #$74                 // text
        beq fl
        cmp #$68                 // hidden
        beq hd
        cmp #$73                 // search / submit
        bne bt0
        lda WB_ITYPE+1
        ora #$20
        cmp #$65
        beq fl
        bne bt
bt0:    cmp #$69                 // image
        beq bt
        cmp #$62                 // button
        beq bt
r:      rts
fl:     lda fmHave               // het zoekveld (alleen het eerste)
        bne r
        inc fmHave
        lda WB_INAME
        cmp #$ff
        bne cn
        lda #$71                 // (geen naam: q)
        sta WB_FNAME
        lda #0
        sta WB_FNAME+1
        beq dr
cn:     ldx #0                   // naam -> WB_FNAME (max. 31)
n:      lda WB_INAME,x
        sta WB_FNAME,x
        beq dr
        inx
        cpx #31
        bne n
        lda #0
        sta WB_FNAME,x
dr:     jsr ht_Space
        lda #WC_LINK
        jsr ht_Ctl
        lda #WL_FIELD
        jsr ht_Ctl
        lda #$1b
        jsr ht_Vis
        ldx #12
u:      stx imI
        lda #$64                 // _
        jsr ht_Vis
        ldx imI
        dex
        bne u
        lda #$1d
        jsr ht_Vis
        lda #WC_LINKX
        jsr ht_Ctl
        jmp ht_Space
hd:     jmp fm_Hidden
bt:     jsr ht_Space             // knop: [waarde] of [GO]
        lda #WC_LINK
        jsr ht_Ctl
        lda #WL_SUBMIT
        jsr ht_Ctl
        lda #$1b
        jsr ht_Vis
        lda WB_HREF
        beq go
        cmp #$ff
        beq go
        ldx #0
b:      stx imI
        lda WB_HREF,x
        beq be
        jsr asc2scr
        bcs b2
        jsr ht_Vis
b2:     ldx imI
        inx
        cpx #12
        bne b
        beq be
go:     lda #7                   // G
        jsr ht_Vis
        lda #15                  // O
        jsr ht_Vis
be:     lda #$1d
        jsr ht_Vis
        lda #WC_LINKX
        jsr ht_Ctl
        jmp ht_Space
}

// fm_Hidden - verborgen veld: "&naam=waarde" achter WB_FHID.
fm_Hidden: {
        lda WB_INAME
        cmp #$ff
        beq r
        ldx #0                   // einde van WB_FHID
e:      lda WB_FHID,x
        beq a
        inx
        bne e
        rts
a:      lda #$26
        jsr p
        ldy #0
n:      lda WB_INAME,y
        beq v
        jsr p
        iny
        bne n
v:      lda #$3d
        jsr p
        ldy #0
        lda WB_HREF
        cmp #$ff
        beq z
w:      lda WB_HREF,y
        beq z
        jsr p
        iny
        bne w
z:      lda #0
        sta WB_FHID,x
r:      rts
p:      cpx #250
        bcs pr
        sta WB_FHID,x
        inx
pr:     rts
}

//--------------------------------------------------------
// &naam; en &#123;
//--------------------------------------------------------
st_Ent: {
        cmp #$3b                 // ;
        beq end
        cmp #$23
        beq add
        jsr isAlnum
        bcs add
        jsr en_Decode            // zonder ; (bv. "AT&T")
        lda #ST_TEXT
        sta htSt
        lda htC
        jmp st_Text
add:    ldx entLen
        cpx #10
        bcs ov
        sta WB_ENT,x
        inc entLen
        rts
ov:     jsr en_Lit
        lda #ST_TEXT
        sta htSt
        lda htC
        jmp st_Text
end:    lda #ST_TEXT
        sta htSt
        jmp en_Decode
}

// en_Decode - WB_ENT (entLen) -> tekst.
en_Decode: {
        lda entLen
        bne n0
        lda #$26
        jmp ht_Char
n0:     lda WB_ENT
        cmp #$23
        beq !w4+
        jmp nm
!w4:
        lda #0                   // &#123; of &#x7b;
        sta cpLo
        sta cpHi
        ldx #1
        lda WB_ENT+1
        ora #$20
        cmp #$78
        beq hx
dl:     cpx entLen
        beq dn
        jsr m10
        lda WB_ENT,x
        and #$0f
        clc
        adc cpLo
        sta cpLo
        bcc d1
        inc cpHi
d1:     inx
        bne dl
dn:     jmp ht_Cp
hx:     inx
hl:     cpx entLen
        beq dn
        ldy #4
h4:     asl cpLo
        rol cpHi
        dey
        bne h4
        lda WB_ENT,x
        cmp #$41
        bcc h0
        adc #8                   // a-f / A-F (carry=1: +9)
h0:     and #$0f
        ora cpLo
        sta cpLo
        inx
        bne hl
m10:    lda cpLo                 // cp = cp * 10
        sta hsT
        lda cpHi
        sta hsT+1
        asl cpLo
        rol cpHi
        asl cpLo
        rol cpHi
        lda cpLo
        clc
        adc hsT
        sta cpLo
        lda cpHi
        adc hsT+1
        sta cpHi
        asl cpLo
        rol cpHi
        rts
nm:     ldx #0                   // namen: tabel enTab ("naam", 0, "tekst", 0)
nx:     lda enTab,x
        beq sf
        stx tgX
        ldy #0
c:      lda enTab,x
        beq ce
        cpy entLen
        beq sk
        cmp WB_ENT,y
        bne sk
        inx
        iny
        bne c
ce:     cpy entLen
        bne sk
        inx                      // gevonden: de tekst
o:      lda enTab,x
        beq r
        stx tgX
        jsr ht_Char
        ldx tgX
        inx
        bne o
sk:     ldx tgX                  // naar de volgende: twee keer tot een 0
s1:     lda enTab,x
        inx
        cmp #0
        bne s1
s2:     lda enTab,x
        inx
        cmp #0
        bne s2
        jmp nx
sf:     ldx #enSufE-enSuf-1      // eacute, ouml, ...: de eerste letter
sfl:    lda enSuf,x              // (laatste letters vergelijken)
        ldy entLen
        dey
        cmp WB_ENT,y
        beq sfm
        dex
        bpl sfl
        jmp en_Lit
sfm:    lda entLen
        cmp #4
        bcc lt
        lda WB_ENT
        jmp ht_Char
lt:     jmp en_Lit
r:      rts
}
// laatste letter van acute, grave, uml, circ, tilde, cedil, ring, slash
.encoding "ascii"
enSuf:  .text "elcgh"
enSufE:
.encoding "screencode_upper"

// en_Lit - onbekend: "&" en de naam zoals ze er staan.
en_Lit: {
        lda #$26
        jsr ht_Char
        ldx #0
l:      cpx entLen
        beq r
        stx tgX
        lda WB_ENT,x
        jsr ht_Char
        ldx tgX
        inx
        bne l
r:      rts
}

//--------------------------------------------------------
// tekens
//--------------------------------------------------------
lower: {
        cmp #$41
        bcc r
        cmp #$5b
        bcs r
        ora #$20
r:      rts
}
// isAlpha / isAlnum / isSpace - carry=1: ja (A blijft)
isAlpha: {
        pha
        ora #$20
        cmp #$61
        bcc no
        cmp #$7b
        bcs no
        pla
        sec
        rts
no:     pla
        clc
        rts
}
isAlnum: {
        jsr isAlpha
        bcs r
        cmp #$30
        bcc no
        cmp #$3a
        bcs no
        sec
        rts
no:     clc
r:      rts
}
isSpace: {
        cmp #$20
        beq y
        cmp #$09
        bcc n
        cmp #$0e
        bcs n
y:      sec
        rts
n:      clc
        rts
}

//--------------------------------------------------------
.encoding "ascii"
// tags: lengte, naam, open-actie, dicht-actie
htTags:
        .byte 1
        .text "a"
        .byte A_A, A_A
        .byte 1
        .text "p"
        .byte A_PARA, A_PARA
        .byte 2
        .text "br"
        .byte A_BR, A_BR
        .byte 3
        .text "div"
        .byte A_BRK, A_BRK
        .byte 2
        .text "h1"
        .byte A_HEAD, A_HEAD
        .byte 2
        .text "h2"
        .byte A_HEAD, A_HEAD
        .byte 2
        .text "h3"
        .byte A_HEAD, A_HEAD
        .byte 2
        .text "h4"
        .byte A_HEAD, A_HEAD
        .byte 2
        .text "h5"
        .byte A_HEAD, A_HEAD
        .byte 2
        .text "h6"
        .byte A_HEAD, A_HEAD
        .byte 2
        .text "li"
        .byte A_LI, A_BRK
        .byte 2
        .text "ul"
        .byte A_PARA, A_PARA
        .byte 2
        .text "ol"
        .byte A_PARA, A_PARA
        .byte 2
        .text "dl"
        .byte A_PARA, A_PARA
        .byte 2
        .text "hr"
        .byte A_HR, A_NONE
        .byte 5
        .text "title"
        .byte A_TITLE, A_TITLE
        .byte 3
        .text "pre"
        .byte A_PRE, A_PRE
        .byte 6
        .text "script"
        .byte A_SKIP, A_NONE
        .byte 5
        .text "style"
        .byte A_SKIP, A_NONE
        .byte 3
        .text "svg"
        .byte A_SKIP, A_NONE
        .byte 6
        .text "select"
        .byte A_SKIP, A_NONE
        .byte 8
        .text "textarea"
        .byte A_SKIP, A_NONE
        .byte 3
        .text "img"
        .byte A_IMG, A_NONE
        .byte 2
        .text "tr"
        .byte A_BRK, A_BRK
        .byte 5
        .text "table"
        .byte A_PARA, A_PARA
        .byte 2
        .text "td"
        .byte A_CELL, A_NONE
        .byte 2
        .text "th"
        .byte A_CELL, A_NONE
        .byte 1
        .text "b"
        .byte A_BOLD, A_BOLD
        .byte 6
        .text "strong"
        .byte A_BOLD, A_BOLD
        .byte 4
        .text "form"
        .byte A_FORM, A_FORM
        .byte 5
        .text "input"
        .byte A_INPUT, A_NONE
        .byte 10
        .text "blockquote"
        .byte A_PARA, A_PARA
        .byte 2
        .text "dt"
        .byte A_BRK, A_BRK
        .byte 2
        .text "dd"
        .byte A_BRK, A_BRK
        .byte 6
        .text "center"
        .byte A_BRK, A_BRK
        .byte 7
        .text "section"
        .byte A_BRK, A_BRK
        .byte 7
        .text "article"
        .byte A_BRK, A_BRK
        .byte 6
        .text "header"
        .byte A_BRK, A_BRK
        .byte 6
        .text "footer"
        .byte A_BRK, A_BRK
        .byte 3
        .text "nav"
        .byte A_BRK, A_BRK
        .byte 4
        .text "main"
        .byte A_BRK, A_BRK
        .byte 0
htAttrs:                         // (an_Is: Y = plek vanaf htAttrs)
sAhref:   .text "href"
          .byte 0
sAalt:    .text "alt"
          .byte 0
sAaction: .text "action"
          .byte 0
sAmethod: .text "method"
          .byte 0
sAtype:   .text "type"
          .byte 0
sAname:   .text "name"
          .byte 0
sAvalue:  .text "value"
          .byte 0
sAmp:     .text "amp;"
// &namen; -> tekst
enTab:  .text "amp"
        .byte 0
        .text "&"
        .byte 0
        .text "lt"
        .byte 0
        .text "<"
        .byte 0
        .text "gt"
        .byte 0
        .text ">"
        .byte 0
        .text "quot"
        .byte 0, $22, 0
        .text "apos"
        .byte 0, $27, 0
        .text "nbsp"
        .byte 0
        .text " "
        .byte 0
        .text "copy"
        .byte 0
        .text "(C)"
        .byte 0
        .text "reg"
        .byte 0
        .text "(R)"
        .byte 0
        .text "trade"
        .byte 0
        .text "TM"
        .byte 0
        .text "hellip"
        .byte 0
        .text "..."
        .byte 0
        .text "mdash"
        .byte 0
        .text "-"
        .byte 0
        .text "ndash"
        .byte 0
        .text "-"
        .byte 0
        .text "laquo"
        .byte 0, $22, 0
        .text "raquo"
        .byte 0, $22, 0
        .text "lsquo"
        .byte 0, $27, 0
        .text "rsquo"
        .byte 0, $27, 0
        .text "ldquo"
        .byte 0, $22, 0
        .text "rdquo"
        .byte 0, $22, 0
        .text "bull"
        .byte 0
        .text "*"
        .byte 0
        .text "middot"
        .byte 0
        .text "."
        .byte 0
        .text "times"
        .byte 0
        .text "x"
        .byte 0
        .text "szlig"
        .byte 0
        .text "ss"
        .byte 0
        .text "euro"
        .byte 0
        .text "EUR"
        .byte 0, 0
.encoding "screencode_upper"
sImage: .text "IMAGE"
        .byte $ff
sPgCut: .text "PAGE TOO LONG - REST NOT SHOWN"
        .byte $ff

// toestand
htC:      .byte 0
htSt:     .byte 0
htPlain:  .byte 0
htPre:    .byte 0
htPreNL:  .byte 0
htAccN:   .byte 0
htTitle:  .byte 0
htFind:   .byte 0
htFound:  .byte 0
htFull:   .byte 0
htClose:  .byte 0
htQ:      .byte 0
nmLen:    .byte 0
anLen:    .byte 0
avLen:    .word 0
avMax:    .word 0
avBeg:    .word 0
avOn:     .byte 0
tgAct:    .byte 0
tgOpen:   .byte 0
tgX:      .byte 0
bngN:     .byte 0
skLen:    .byte 0
skM:      .byte 0
entLen:   .byte 0
utfN:     .byte 0
utfLead:  .byte 0
cpLo:     .byte 0
cpHi:     .byte 0
lnLen:    .byte 0
lnW:      .byte 0
lnId:     .byte 0
lnLink:   .byte $ff
lnAcc:    .byte 0
wdLen:    .byte 0
wdW:      .byte 0
spPend:   .byte 0
lastBlank: .byte 1
flSp:     .byte 0
flI:      .byte 0
nLines:   .word 0
linkN:    .byte 0
inLink:   .byte 0
lkLen:    .byte 0
psL:      .word 0
wU2:      .word 0
hsLo:     .byte 0
hsHi:     .byte 0
hsT:      .word 0
fdLo:     .byte 0
fdHi:     .byte 0
ttLen:    .byte 0
imI:      .byte 0
rdI:      .byte 0
wrI:      .byte 0
fmState:  .byte 0
fmHave:   .byte 0
