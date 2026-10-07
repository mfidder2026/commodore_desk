#importonce
//========================================================
// apps/web/web_url.asm - adressen, geschiedenis, bladwijzers
// Commodore Desk 64
//
// Adressen zijn ASCII, 0-afgesloten, max. 255 tekens.
//   ur_Norm    WB_NEW: alleen http (https -> melding), "http://" ervoor
//   ur_Parse   WB_NEW -> WB_HOST / WB_PORT (schermcodes), urPath
//   ur_Resolve WB_HREF (link) t.o.v. UB (basis) -> WB_NEW
//========================================================
.label UB = WB_REQ + 256         // basisadres voor ur_Resolve (256)

// ur_Norm - spaties voor weg, #anker weg, "http://" ervoor als er geen
//           schema staat. Carry=0: X/Y = melding (https, ander schema).
ur_Norm: {
        ldx #0                   // spaties aan het begin
s:      lda WB_NEW,x
        cmp #$20
        bne s1
        inx
        bne s
s1:     txa
        beq f
        clc                      // (naar voren schuiven)
        adc #<WB_NEW
        sta wS
        lda #>WB_NEW
        adc #0
        sta wS+1
        lda #<WB_NEW
        sta wD
        lda #>WB_NEW
        sta wD+1
        jsr str_Copy
f:      jsr ur_NoFrag
        lda WB_NEW
        bne sc
        jmp no
sc:     ldx #0                   // schema = letters voor "://"
l:      lda WB_NEW,x
        beq add
        cmp #$3a
        beq col
        jsr isAlpha
        bcc add
        inx
        cpx #10
        bne l
        beq add
col:    lda WB_NEW+1,x
        cmp #$2f
        bne add                  // (host:poort)
        lda WB_NEW+2,x
        cmp #$2f
        bne add
        cpx #4
        bne hs
        jsr ur_IsHttp
        bcc no
        sec
        rts
hs:     cpx #5
        bne no
        jsr ur_IsHttp
        bcc no
        ldx #<sWbHttps
        ldy #>sWbHttps
        clc
        rts
no:     ldx #<sWbBadUrl
        ldy #>sWbBadUrl
        clc
        rts
add:    jsr ur_Len               // "http://" ervoor (alles 7 naar achteren)
        lda urL+1
        cmp #>[URL_MAX-7]
        bcc mv0
        bne no
        lda urL
        cmp #<[URL_MAX-7]
        bcs no
mv0:    lda #<WB_NEW             // wS = de 0 aan het eind, wD = 7 verder
        clc
        adc urL
        sta wS
        lda #>WB_NEW
        adc urL+1
        sta wS+1
        lda wS
        clc
        adc #7
        sta wD
        lda wS+1
        adc #0
        sta wD+1
        ldy #0
mv:     lda (wS),y
        sta (wD),y
        lda wS
        cmp #<WB_NEW
        bne dn
        lda wS+1
        cmp #>WB_NEW
        beq mvd
dn:     lda wS
        bne x1
        dec wS+1
x1:     dec wS
        lda wD
        bne x2
        dec wD+1
x2:     dec wD
        jmp mv
mvd:    ldx #6
p:      lda sHttp,x
        sta WB_NEW,x
        dex
        bpl p
        sec
        rts
}

// ur_Len - lengte van WB_NEW -> urL (16 bits).
ur_Len: {
        lda #<WB_NEW
        sta wQ
        lda #>WB_NEW
        sta wQ+1
        lda #0
        sta urL
        sta urL+1
        tay
l:      lda (wQ),y
        beq r
        inc urL
        bne n
        inc urL+1
n:      iny
        bne l
        inc wQ+1
        bne l
r:      rts
}

// str_Copy - ASCII-tekst (wS) naar (wD) met de 0, max. URL_MAX tekens;
// str_CopyN - idem, max. scN tekens.
str_Copy:
        lda #<URL_MAX
        sta scN
        lda #>URL_MAX
        sta scN+1
str_CopyN: {
        ldy #0
l:      lda (wS),y
        sta (wD),y
        beq r
        iny
        bne n
        inc wS+1
        inc wD+1
n:      lda scN
        bne d
        lda scN+1
        beq z
        dec scN+1
d:      dec scN
        lda scN
        ora scN+1
        bne l
z:      lda #0
        sta (wD),y
r:      rts
}

// cp_Pair - adres kopieren, X = CP_* (web.inc).
cp_Pair:
        lda cpS0,x
        sta wS
        lda cpS1,x
        sta wS+1
        lda cpD0,x
        sta wD
        lda cpD1,x
        sta wD+1
        jmp str_Copy
cpS0:   .byte <WB_NEW, <WB_URL, <WB_URL, <WB_NEW, <WB_HREF, <WB_NEW, <WB_REQ
cpS1:   .byte >WB_NEW, >WB_URL, >WB_URL, >WB_NEW, >WB_HREF, >WB_NEW, >WB_REQ
cpD0:   .byte <WB_URL, <UB, <WB_NEW, <WB_HREF, <WB_NEW, <UB, <WB_HREF
cpD1:   .byte >WB_URL, >UB, >WB_NEW, >WB_HREF, >WB_NEW, >UB, >WB_HREF

// ur_IsHttp - begint WB_NEW met "http" (hoofd- of kleine letters)?
ur_IsHttp: {
        ldx #3
l:      lda WB_NEW,x
        ora #$20
        cmp sHttp,x
        bne n
        dex
        bpl l
        sec
        rts
n:      clc
        rts
}

// ur_NoFrag - #anker weg uit WB_NEW.
ur_NoFrag: {
        lda #<WB_NEW
        sta wQ
        lda #>WB_NEW
        sta wQ+1
        ldy #0
l:      lda (wQ),y
        beq r
        cmp #$23
        beq z
        iny
        bne l
        inc wQ+1
        bne l
z:      lda #0
        sta (wQ),y
r:      rts
}

// ur_Parse - WB_NEW ("http://host[:poort][/pad]") -> WB_HOST, WB_PORT
//            (schermcodes, $ff), urHost/urHEnd (plek in WB_NEW), urPath
//            (plek van het pad; urSlash=1: er moet een / voor).
ur_Parse: {
        ldx #7
        stx urHost
        ldy #0
h:      lda WB_NEW,x
        beq he
        cmp #$2f
        beq he
        cmp #$3f
        beq he
        cmp #$3a
        beq he
        cpy #60
        bcs b
        stx urT
        jsr asc2scr
        ldx urT
        bcs b
        sta WB_HOST,y
        iny
        inx
        bne h
he:     cpy #0
        beq b
        stx urHEnd
        lda #$ff
        sta WB_HOST,y
        lda #$38                 // poort 80
        sta WB_PORT
        lda #$30
        sta WB_PORT+1
        lda #$ff
        sta WB_PORT+2
        lda #0
        sta urPortS
        lda WB_NEW,x
        cmp #$3a
        bne pa
        inx
        stx urPortS
        ldy #0
pt:     lda WB_NEW,x
        cmp #$30
        bcc pe
        cmp #$3a
        bcs pe
        cpy #5
        bcs b
        sta WB_PORT,y
        iny
        inx
        bne pt
pe:     cpy #0
        beq b
        lda #$ff
        sta WB_PORT,y
        stx urPortE
pa:     stx urPath
        ldy #0
        lda WB_NEW,x
        cmp #$2f
        beq s
        iny
s:      sty urSlash
        sec
        rts
b:      ldx #<sWbBadUrl
        ldy #>sWbBadUrl
        clc
        rts
}

// ur_Resolve - link WB_HREF t.o.v. basis UB -> WB_NEW. Carry=0: niet te volgen.
ur_Resolve: {
        ldx #0                   // spaties voor de link weg
s:      lda WB_HREF,x
        cmp #$20
        bne s1
        inx
        bne s
s1:     stx rsH
        lda WB_HREF,x
        bne n0
        jmp base                 // leeg: de basis zelf
n0:     ldy #0                   // schema?
sl:     lda WB_HREF,x
        beq ns
        cmp #$3a
        beq ab
        cmp #$2f
        beq ns
        cmp #$3f
        beq ns
        cmp #$23
        beq ns
        inx
        iny
        bne sl
ab:     ldx rsH                  // volledig adres
        ldy #0
        jsr cpH
        jmp done
ns:     ldx rsH
        lda WB_HREF,x
        cmp #$2f
        bne nr
        lda WB_HREF+1,x
        cmp #$2f
        bne rt
        ldy #0                   // //host/pad -> http://host/pad
c5:     lda sHttp,y
        sta WB_NEW,y
        iny
        cpy #5
        bne c5
        jsr cpH
        jmp done
rt:     jsr orig                 // /pad -> oorsprong + /pad
        jsr cpH
        jmp done
nr:     cmp #$3f                 // ?q -> basis zonder ?... + ?q
        bne nh
        ldy #0
q:      lda UB,y
        beq qe
        cmp #$3f
        beq qe
        cmp #$23
        beq qe
        sta WB_NEW,y
        iny
        bne q
qe:     jsr cpH
        jmp done
nh:     cmp #$23                 // #anker -> de basis
        bne rel
base:   ldx #CP_URL_UB           // (UB -> WB_NEW: zie hieronder)
        lda #<UB
        sta wS
        lda #>UB
        sta wS+1
        lda #<WB_NEW
        sta wD
        lda #>WB_NEW
        sta wD+1
        jsr str_Copy
        jmp done
rel:    jsr orig                 // relatief: map van de basis + link
        sty rsO
        ldx rsO                  // laatste / in het pad (voor ? of #)
        stx rsD
dl:     lda UB,x
        beq de
        cmp #$3f
        beq de
        cmp #$23
        beq de
        cmp #$2f
        bne dn
        stx rsD
dn:     inx
        bne dl
de:     ldx rsD
        cpx rsO
        bne dc
        lda UB,x                 // geen pad: "/"
        cmp #$2f
        beq dc
        lda #$2f
        sta WB_NEW,y
        iny
        bne dk
dc:     ldy rsO                  // pad t/m de laatste /
dcl:    cpy rsD
        beq dce
        lda UB,y
        sta WB_NEW,y
        iny
        bne dcl
dce:    lda #$2f
        sta WB_NEW,y
        iny
dk:     ldx rsH
        jsr cpH
        jsr dots
done:   jsr ur_NoFrag
        sec
        rts
// orig - "http://host[:poort]" van UB naar WB_NEW; Y = lengte.
orig:   ldy #0
o1:     lda UB,y
        beq oe
        sta WB_NEW,y
        cpy #7
        bcc o2
        cmp #$2f
        beq oe
        cmp #$3f
        beq oe
o2:     iny
        bne o1
oe:     lda #0
        sta WB_NEW,y
        rts
// cpH - WB_HREF vanaf X achter WB_NEW vanaf Y (samen max. URL_MAX).
cpH:    txa
        clc
        adc #<WB_HREF
        sta wS
        lda #>WB_HREF
        adc #0
        sta wS+1
        sty rsY
        tya
        clc
        adc #<WB_NEW
        sta wD
        lda #>WB_NEW
        adc #0
        sta wD+1
        lda #<URL_MAX
        sec
        sbc rsY
        sta scN
        lda #>URL_MAX
        sbc #0
        sta scN+1
        jmp str_CopyN
// dots - "/./" en "/x/../" uit het pad (vanaf rsO).
dots:   ldx rsO
        ldy rsO
dl2:    cpx #250                 // (heel lang pad: de rest zoals hij is)
        bcs dq
        lda WB_NEW,x
        beq dz
        cmp #$3f
        beq dq
        cmp #$2f
        bne dw
        lda WB_NEW+1,x
        cmp #$2e
        bne dw0
        lda WB_NEW+2,x
        jsr endSeg
        bne d2
        inx                      // "/." weg
        inx
        jmp dl2
d2:     cmp #$2e
        bne dw0
        lda WB_NEW+3,x
        jsr endSeg
        bne dw0
        inx                      // "/.." : vorige map weg
        inx
        inx
up:     cpy rsO
        beq dl2
        dey
        lda WB_NEW,y
        cmp #$2f
        bne up
        jmp dl2
dw0:    lda #$2f
dw:     sta WB_NEW,y
        inx
        iny
        bne dl2
dq:     stx rsX                  // ?... ongewijzigd naar voren (X -> Y)
        cpy rsX
        beq dz2
        txa
        clc
        adc #<WB_NEW
        sta wS
        lda #>WB_NEW
        adc #0
        sta wS+1
        tya
        clc
        adc #<WB_NEW
        sta wD
        lda #>WB_NEW
        adc #0
        sta wD+1
        jmp str_Copy
dz:     cpy rsO                  // leeg pad: /
        bne dz1
        lda #$2f
        sta WB_NEW,y
        iny
dz1:    lda #0
        sta WB_NEW,y
dz2:    rts
endSeg: cmp #$2f                 // Z=1 als A = /, ? of 0
        beq e1
        cmp #$3f
        beq e1
        cmp #0
e1:     rts
}

//--------------------------------------------------------
// Geschiedenis: 6 adressen van max. 255 tekens (wbHistHi), een ring.
// (Een langer adres wordt afgekapt: BACK erheen lukt dan niet.)
//--------------------------------------------------------
hi_Push: {
        ldx hiTop
        lda wbHistHi,x
        sta wD+1
        lda #0
        sta wD
        tay
l:      lda WB_URL,y
        sta (wD),y
        beq e
        iny
        cpy #255
        bne l
        lda #0
        sta (wD),y
e:      inx
        cpx #6
        bcc s
        ldx #0
s:      stx hiTop
        lda hiN
        cmp #6
        bcs r
        inc hiN
r:      rts
}

// hi_Pop - laatste adres naar WB_NEW. Carry=0: er is niets.
hi_Pop: {
        lda hiN
        bne p
        clc
        rts
p:      dec hiN
        ldx hiTop
        dex
        bpl s
        ldx #5
s:      stx hiTop
        lda wbHistHi,x
        sta wD+1
        lda #0
        sta wD
        tay
l:      lda (wD),y
        sta WB_NEW,y
        beq e
        iny
        bne l
e:      sec
        rts
}
wbHistHi: .byte $f3, $f4, $f5, $fc, $fd, $fe

//--------------------------------------------------------
// Bladwijzers: BOOKMARKS (SEQ) = regels "adres naam" (PETSCII zoals de
// TEXT EDITOR schrijft: kleine letters $41-$5A, hoofdletters $C1-$DA).
// In WB_BM als ASCII-regels met een 0, aan het eind een lege regel.
//--------------------------------------------------------
bm_Load: {
        lda #<WB_BM
        sta wD
        lda #>WB_BM
        sta wD+1
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
        and #$42
        cmp #$02
        beq cl
        txa
        jsr p2a
        ldy #0
        sta (wD),y
        inc wD
        bne s1
        inc wD+1
s1:     lda wD+1                 // vol? (2 bytes over)
        cmp #>[WB_BM+766]
        bcc s2
        lda wD
        cmp #<[WB_BM+766]
        bcs cl
s2:     lda $90
        beq rd
cl:     jsr K_CLRCHN
        lda #2
        jsr K_CLOSE
        jsr cfg_io_end
        lda #0
        tay
        sta (wD),y
        iny
        sta (wD),y
        lda WB_BM                // geen (lege) BOOKMARKS: de standaardlijst
        bne r
        ldx #bmDefE-bmDef-1
d:      lda bmDef,x
        sta WB_BM,x
        dex
        bpl d
r:      rts
// p2a - PETSCII -> ASCII (regeleinde -> 0)
p2a:    cmp #$0d
        bne a1
        lda #0
        rts
a1:     cmp #$41
        bcc a9
        cmp #$5b
        bcs a2
        ora #$20                 // a-z
        rts
a2:     cmp #$c1
        bcc a3
        cmp #$db
        bcs a3
        and #$7f                 // A-Z
        rts
a3:     cmp #$a4
        bne a4
        lda #$5f                 // _
        rts
a4:     cmp #$60
        bcc a9
        lda #$2e
a9:     rts
.encoding "petscii_upper"
nm:     .text "BOOKMARKS"
nmE:
.encoding "screencode_upper"
}

// bm_Page - de bladwijzers als pagina (de startpagina; WB_URL = "").
bm_Page: {
        lda #0
        sta WB_URL
        sta htFind
        jsr pg_Reset
        lda #0
        jsr ht_Begin
        ldx #<hBmTop
        ldy #>hBmTop
        jsr ht_Str
        lda #<WB_BM
        sta wD
        lda #>WB_BM
        sta wD+1
ln:     ldy #0
        lda (wD),y
        bne l1
        iny                      // lege regel: einde (2x 0) of overslaan
        lda (wD),y
        beq end
        jsr nxt
        jmp ln
l1:     cmp #$20                 // regel die met een spatie begint: overslaan
        beq skip
        ldx #<hA1                // <a href="
        ldy #>hA1
        jsr ht_Str
        ldy #0
u:      lda (wD),y               // adres tot de spatie
        beq ue
        cmp #$20
        beq ue
        jsr hb
        iny
        bne u
ue:     sty bmU
        ldx #<hA2                // ">
        ldy #>hA2
        jsr ht_Str
        ldy bmU                  // naam (of het adres)
        lda (wD),y
        beq nn
n1:     iny
        lda (wD),y
        beq ne
        jsr hb
        jmp n1
nn:     ldy #0
n2:     lda (wD),y
        beq ne
        jsr hb
        iny
        bne n2
ne:     ldx #<hA3                // </a><br>
        ldy #>hA3
        jsr ht_Str
skip:   jsr nxt
        jmp ln
end:    ldx #<hBmEnd
        ldy #>hBmEnd
        jsr ht_Str
        jsr ht_End
        lda #<WP_BEG
        sta wT
        lda #>WP_BEG
        sta wT+1
        lda #0
        sta wbTop
        sta wbTop+1
        rts
// hb - ht_Byte met Y bewaard
hb:     sty bmY
        jsr ht_Byte
        ldy bmY
        rts
// nxt - wD naar de volgende regel
nxt:    ldy #0
n3:     lda (wD),y
        beq n4
        iny
        bne n3
n4:     iny
        tya
        clc
        adc wD
        sta wD
        bcc n5
        inc wD+1
n5:     rts
}

// ht_Str - ASCII-tekst X/Y (0) naar de HTML-lezer (Y blijft niet).
ht_Str: {
        stx wR
        sty wR+1
        ldy #0
l:      lda (wR),y
        beq r
        sty hsY
        jsr ht_Byte
        ldy hsY
        iny
        bne l
r:      rts
}
hsY:    .byte 0

// pg_Reset - lege pagina: geen regels, geen links, geen titel/formulier.
pg_Reset:
        lda #<WP_BEG
        sta wP
        sta wT
        lda #>WP_BEG
        sta wP+1
        sta wT+1
        lda #<WU_TOP
        sta wU
        lda #>WU_TOP
        sta wU+1
        lda #<WP_END
        sta wU2
        lda #>WP_END
        sta wU2+1
        lda #0
        sta nLines
        sta nLines+1
        sta wbTop
        sta wbTop+1
        sta linkN
        sta htFull
        sta ttLen
        sta WB_FACT
        sta WB_FHID
        sta WB_FNAME
        lda #$ff
        sta WB_TITLE
        sta WB_FVAL
        rts

.encoding "ascii"
sHttp:  .text "http://"
hBmTop: .text "<title>Bookmarks</title><h1>Bookmarks</h1>"
        .byte 0
hA1:    .text "<a href="
        .byte $22, 0
hA2:    .byte $22
        .text ">"
        .byte 0
hA3:    .text "</a><br>"
        .byte 0
hBmEnd: .text "<p>Click a page, or click the address line above to type an "
        .text "address. Edit the list: BOOKMARKS in the TEXT EDITOR.</p>"
        .byte 0
// standaardlijst als er geen BOOKMARKS is (zelfde vorm als WB_BM)
bmDef:  .text "http://68k.news/ 68K.NEWS - NEWS FOR OLD COMPUTERS"
        .byte 0
        .text "http://wiby.me/ WIBY - SEARCH THE CLASSIC WEB"
        .byte 0, 0
bmDefE:
.encoding "screencode_upper"
hiN:    .byte 0
hiTop:  .byte 0
bmU:    .byte 0
bmY:    .byte 0
urT:    .byte 0
urHost: .byte 0
urHEnd: .byte 0
urPortS: .byte 0
urPortE: .byte 0
urPath: .byte 0
urSlash: .byte 0
rsH:    .byte 0
rsY:    .byte 0
rsX:    .byte 0
urL:    .word 0
scN:    .word 0
rsO:    .byte 0
rsD:    .byte 0
