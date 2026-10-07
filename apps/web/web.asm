#importonce
//========================================================
// apps/web/web.asm - WEB, een eenvoudige tekstbrowser (app 15, PRG WEB)
// Commodore Desk 64 - plan: docs/BROWSER_Plan.md
//
// Rij 3 knoppen (BACK, MARKS, RELOAD), rij 4 het adres (klik = typen),
// rij 5 de titel, rij 6-21 de pagina (35 tekens, schuifbalk op kolom 37),
// rij 22 de status. De startpagina zijn de bladwijzers (BOOKMARKS).
// Alleen http:// (geen TLS op een C64).
//========================================================
.const WB_HELP = 20              // F1-context (gui/help.txt)
.const WB_C0   = 2               // eerste kolom van de pagina
.const WB_R0   = 6               // eerste rij van de pagina
.const WB_ROWS = 16
.const WB_SC   = 37              // schuifbalk
.const WB_RB   = 3               // knoppen
.const WB_RU   = 4               // adres
.const WB_RT   = 5               // titel
.const WB_RS   = 22              // status
.const WB_PG   = WB_ROWS - 1     // een bladzijde verder

wb_Init:
        lda #WB_HELP
        sta helpCtx
        lda #0
        sta hiN
        sta hiTop
        sta wbMsg+1
        sta ntPush
        jsr bm_Load
        jmp bm_Page

//--------------------------------------------------------
// wb_Draw - knoppen, adres, titel, pagina, schuifbalk, status.
//--------------------------------------------------------
wb_Draw: {
        ldx #2
b:      stx wbI
        lda btLo,x
        sta r0
        lda btHi,x
        sta r0+1
        lda btCol,x
        sta a0
        lda #WB_RB
        sta a1
        lda btW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx wbI
        dex
        bpl b
        jsr wb_Addr
        lda #WB_RT               // titel
        jsr wb_Clr
        lda #<WB_TITLE
        sta r0
        lda #>WB_TITLE
        sta r0+1
        lda #WB_C0
        sta a0
        lda #WB_RT
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        jmp wb_View
}
btLo:   .byte <sWbBack, <sWbMarks, <sWbReload
btHi:   .byte >sWbBack, >sWbMarks, >sWbReload
btCol:  .byte 2, 9, 17
btW:    .byte 6, 7, 8

// wb_View - pagina, schuifbalk en status (ook na scrollen).
wb_View:
        jsr pg_Draw
        jsr wb_Scroll
        jmp wb_Status

// wb_Clr - rij A leeg maken (kolom 2-36).
wb_Clr: {
        sta a1
        lda #WB_C0
        sta a0
        lda #WB_W
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jmp gfx_FillRect
}

// wb_Addr - het adres (zonder http://), of de uitnodiging om er een te typen.
wb_Addr: {
        lda #WB_RU
        jsr wb_Clr
        lda WB_URL
        bne u
        lda #<sWbType
        sta r0
        lda #>sWbType
        sta r0+1
        lda #GREY
        bne d
u:      ldx #0
        jsr ur_Skip7             // X = na "http://"
        ldy #0
l:      lda WB_URL,x
        beq e
        stx wbI
        jsr asc2scr
        ldx wbI
        bcs n
        sta WB_OUT,y
        iny
        cpy #WB_W
        beq e
n:      inx
        bne l
e:      lda #$ff
        sta WB_OUT,y
        lda #<WB_OUT
        sta r0
        lda #>WB_OUT
        sta r0+1
        lda TH_text
d:      sta a2
        lda #WB_C0
        sta a0
        lda #WB_RU
        sta a1
        jmp gfx_DrawText
}

// ur_Skip7 - X = 7 als WB_URL met "http://" begint, anders 0.
ur_Skip7: {
        ldx #6
l:      lda WB_URL,x
        ora #$20
        cmp sHttp,x
        bne n
        dex
        bpl l
        ldx #7
        rts
n:      ldx #0
        rts
}

//--------------------------------------------------------
// pg_Draw - 16 regels vanaf wT. Links in de accentkleur, koppen in de
//           kleur van de selectie.
//--------------------------------------------------------
pg_Draw: {
        lda wT
        sta wQ
        lda wT+1
        sta wQ+1
        lda #0
        sta pdR
l:      jsr pd_Line
        inc pdR
        lda pdR
        cmp #WB_ROWS
        bne l
        rts
}

// pd_Line - regel wQ (decoderen naar WB_OUT/WB_OUTC) op rij WB_R0+pdR;
//           wQ naar de volgende regel.
pd_Line: {
        jsr pd_Dec
        lda pdR                  // scherm- en kleuradres
        clc
        adc #WB_R0
        tax
        lda screenLo,x
        clc
        adc #WB_C0
        sta wD
        sta wS
        lda screenHi,x
        adc #0
        sta wD+1
        clc
        adc #$d4
        sta wS+1
        ldy #WB_W-1
l:      lda WB_OUT,y
        sta (wD),y
        lda WB_OUTC,y
        sta (wS),y
        dey
        bpl l
        rts
}

// pd_Dec - regel wQ -> WB_OUT (tekens) en WB_OUTC (kleuren), WB_W breed;
//          pdHit: de link onder kolom pdCol (of $ff), pdHitC: zijn begin.
//          wQ gaat naar de volgende regel (voorbij wP: lege regel).
pd_Dec: {
        lda #$ff
        sta pdHit
        ldx #WB_W-1              // eerst leeg
        lda TH_text
c:      sta WB_OUTC,x
        dex
        bpl c
        ldx #WB_W-1
        lda #$20
s:      sta WB_OUT,x
        dex
        bpl s
        lda wQ+1                 // voorbij het einde?
        cmp wP+1
        bcc ok
        beq !w0+
        jmp r
!w0:
        lda wQ
        cmp wP
        bcc !w1+
        jmp r
!w1:
ok:     ldy #0
        lda (wQ),y
        sta pdLen
        tax
        inx
        stx pdEnd
        lda #0
        sta pdX
        sta pdAcc
        sta pdId
        lda #$ff
        sta pdLnk
        iny
nx:     cpy pdEnd
        bcs dn
        lda (wQ),y
        iny
        ldx pdId
        beq c0
        ldx #0                   // linknummer
        stx pdId
        sta pdLnk
        ldx pdX
        stx pdSt
        jmp nx
c0:     cmp #WC_LINK
        bne c1
        inc pdId
        bne nx
c1:     cmp #WC_LINKX
        bne c2
        lda #$ff
        sta pdLnk
        bne nx
c2:     cmp #WC_ACC
        bne c3
        lda #1
        sta pdAcc
        bne nx
c3:     cmp #WC_ACCX
        bne ch
        lda #0
        sta pdAcc
        beq nx
ch:     ldx pdX
        cpx #WB_W
        bcs nx
        sta WB_OUT,x
        lda TH_text
        ldx pdAcc
        beq k1
        lda TH_select
k1:     ldx pdLnk
        cpx #$ff
        beq k2
        lda TH_accent
k2:     ldx pdX
        sta WB_OUTC,x
        cpx pdCol
        bne k3
        lda pdLnk
        sta pdHit
        lda pdSt
        sta pdHitC
k3:     inc pdX
        jmp nx
dn:     iny                      // wQ += lengte + 2
        tya
        clc
        adc wQ
        sta wQ
        bcc r
        inc wQ+1
r:      rts
}

// wb_Scroll - de schuifbalk (positie en maximum als byte: lange pagina's
//             gedeeld door 2, 4 ...).
wb_Scroll: {
        lda wbTop
        sta tmp0
        lda wbTop+1
        sta tmp1
        lda nLines               // max = regels - 16 (of 0)
        sec
        sbc #WB_ROWS
        sta tmp2
        lda nLines+1
        sbc #0
        sta tmp3
        bcs s
        lda #0
        sta tmp2
        sta tmp3
s:      lda tmp3
        beq d
        lsr tmp3
        ror tmp2
        lsr tmp1
        ror tmp0
        jmp s
d:      lda #WB_SC
        sta a0
        lda #WB_R0
        sta a1
        lda #WB_R0+WB_ROWS-1
        sta a2
        lda tmp0
        sta a3
        lda tmp2
        sta a4
        jmp scr_Draw
}

// wb_Status - melding (wbMsg) of "LINES 1-16 OF 212".
wb_Status: {
        lda #WB_RS
        jsr wb_Clr
        lda wbMsg+1
        beq ln
        sta r0+1
        lda wbMsg
        sta r0
        lda TH_accent
        jmp d
ln:     lda #0
        sta fcO2
        ldx #<sWbLines
        ldy #>sWbLines
        jsr ou_Str
        lda wbTop                // eerste regel
        clc
        adc #1
        tax
        lda wbTop+1
        adc #0
        jsr ou_Dec
        lda #$2d
        jsr ou_Chr
        lda wbTop                // laatste regel
        clc
        adc #WB_ROWS
        tax
        lda wbTop+1
        adc #0
        cmp nLines+1
        bcc l1
        bne l0
        cpx nLines
        bcc l1
l0:     ldx nLines
        lda nLines+1
l1:     jsr ou_Dec
        ldx #<sWbOf
        ldy #>sWbOf
        jsr ou_Str
        ldx nLines
        lda nLines+1
        jsr ou_Dec
        ldx fcO2
        lda #$ff
        sta WB_OUT,x
        lda #<WB_OUT
        sta r0
        lda #>WB_OUT
        sta r0+1
        lda TH_text
d:      sta a2
        lda #WB_C0
        sta a0
        lda #WB_RS
        sta a1
        jmp gfx_DrawText
}

// wb_Loading - "LOADING host 12K (RUN/STOP)" op de statusregel.
wb_Loading: {
        lda #0
        sta fcO2
        ldx #<sWbLoading
        ldy #>sWbLoading
        lda htFind
        beq n
        ldx #<sWbFind
        ldy #>sWbFind
n:      jsr ou_Str
        ldx #0
h:      lda WB_HOST,x
        cmp #$ff
        beq he
        cpx #14
        beq he
        jsr ou_Chr
        inx
        bne h
he:     lda #$20
        jsr ou_Chr
        lda ntBytes+2            // KB = bytes / 1024
        lsr
        sta tmp1
        lda ntBytes+1
        ror
        lsr tmp1
        ror
        tax
        lda tmp1
        jsr ou_Dec
        lda #11                  // K
        jsr ou_Chr
        ldx #<sWbStopH
        ldy #>sWbStopH
        jsr ou_Str
        ldx fcO2
        lda #$ff
        sta WB_OUT,x
        lda #WB_RS
        jsr wb_Clr
        lda #<WB_OUT
        sta r0
        lda #>WB_OUT
        sta r0+1
        lda #WB_C0
        sta a0
        lda #WB_RS
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
}

// ou_Chr / ou_Str / ou_Dec - een regel opbouwen in WB_OUT (positie fcO2).
ou_Chr: {
        stx ouX
        ldx fcO2
        cpx #WB_W
        bcs r
        sta WB_OUT,x
        inc fcO2
r:      ldx ouX
        rts
}
ou_Str: {
        stx wS
        sty wS+1
        ldy #0
l:      lda (wS),y
        cmp #$ff
        beq r
        jsr ou_Chr
        iny
        bne l
r:      rts
}
// ou_Dec - getal A (hoog) / X (laag) decimaal, zonder voorloopnullen.
ou_Dec: {
        sta dcHi
        stx dcLo
        lda #0
        sta dcNz
        ldy #4
d:      ldx #0                   // hoe vaak past 10^y?
s:      lda dcLo
        sec
        sbc dcTL,y
        pha
        lda dcHi
        sbc dcTH,y
        bcc e
        sta dcHi
        pla
        sta dcLo
        inx
        bne s
e:      pla
        txa
        bne o
        lda dcNz
        bne o
        cpy #0
        bne nx
o:      inc dcNz
        txa
        ora #$30
        jsr ou_Chr
nx:     dey
        bpl d
        rts
}
dcTL:   .byte <1, <10, <100, <1000, <10000
dcTH:   .byte >1, >10, >100, >1000, >10000

//--------------------------------------------------------
// wb_Click
//--------------------------------------------------------
wb_Click: {
        lda #0
        sta wbMsg+1
        ldx #2                   // knoppen
b:      stx wbI
        lda btCol,x
        sta a0
        lda #WB_RB
        sta a1
        lda btW,x
        sta a2
        jsr btn_HitTest
        bcs bt
        ldx wbI
        dex
        bpl b
        lda evtB
        cmp #WB_RU
        bne sc
        jmp wb_Edit
sc:     jsr scr_Hit              // schuifbalk
        cmp #0
        bne s1
        jmp pg
s1:
        cmp #1
        bne s2
        lda #2
        jmp up
s2:     cmp #2
        bne s3
        lda #2
        jmp dw
s3:     cmp #3
        bne s4
        lda #WB_PG
up:     jsr pg_Up
        jmp wb_View
s4:     lda #WB_PG
dw:     jsr pg_Down
        jmp wb_View
pg:     lda evtB                 // op de pagina?
        sec
        sbc #WB_R0
        cmp #WB_ROWS
        bcs r
        tax
        lda evtA
        sec
        sbc #WB_C0
        cmp #WB_W
        bcs r
        jsr pg_Hit
        cmp #$ff
        beq r
        jmp lk_Follow
r:      rts
bt:     lda wbI
        bne b1
        jmp wb_Back
b1:     cmp #1
        bne rl
        jmp wb_Marks
rl:     jmp wb_Reload
}

// pg_Hit - welke link op paginarij X, kolom A? A = nummer of $ff.
pg_Hit: {
        sta pdCol1
        stx pdR
        lda wT
        sta wQ
        lda wT+1
        sta wQ+1
l:      lda #$ff                 // alleen op de geklikte regel zoeken
        ldx pdR
        bne c
        lda pdCol1
c:      sta pdCol
        jsr pd_Dec
        ldx pdR
        beq e
        dec pdR
        jmp l
e:      lda #$ff
        sta pdCol
        lda pdHit
        rts
}

wb_Back: {
        jsr hi_Pop
        bcc r
        lda WB_NEW
        bne n
        jsr bm_Load              // terug naar de bladwijzers
        jsr bm_Page
        jmp shell_DrawAll
n:      lda #0
        sta ntPush
        jmp nv_Go
r:      rts
}

wb_Marks: {
        lda WB_URL               // (vanaf een pagina: in de geschiedenis)
        beq m
        jsr hi_Push
m:      jsr bm_Load
        jsr bm_Page
        jmp shell_DrawAll
}

wb_Reload: {
        lda WB_URL
        bne n
        jsr bm_Load
        jsr bm_Page
        jmp shell_DrawAll
n:      ldx #CP_URL_NEW
        jsr cp_Pair
        lda #0
        sta ntPush
        jmp nv_Go
}

// wb_Edit - het adres typen (RETURN = erheen).
wb_Edit: {
        ldx #0                   // WB_URL (zonder http://) -> schermcodes
        lda WB_URL
        beq e0
        jsr ur_Skip7
e0:     ldy #0
l:      lda WB_URL,x
        beq e
        stx wbI
        jsr asc2scr
        ldx wbI
        bcs n
        sta WB_EDIT,y
        iny
        cpy #120
        beq e
n:      inx
        bne l
e:      lda #$ff
        sta WB_EDIT,y
        lda #WB_RU
        jsr wb_Clr
        lda #<WB_EDIT
        sta r3
        lda #>WB_EDIT
        sta r3+1
        lda #120
        sta liMax
        lda #WB_C0
        sta liCol
        lda #WB_RU
        sta liRow
        lda #WB_W
        sta liVis
        jsr li_Edit
        bcs x                    // muisklik: niet gaan
        ldx #0                   // schermcodes -> ASCII
c:      lda WB_EDIT,x
        cmp #$ff
        beq ce
        jsr scr2url
        sta WB_NEW,x
        inx
        cpx #120
        bne c
ce:     lda #0
        sta WB_NEW,x
        lda WB_NEW
        beq x
        lda #1
        sta ntPush
        jmp nv_Go
x:      jmp shell_DrawAll
}

// scr2url - schermcode A (getypt) -> ASCII: letters klein, SHIFT-letters
//           groot, @ en _.
scr2url: {
        cmp #0
        bne a
        lda #$40
        rts
a:      cmp #27
        bcs b
        ora #$60                 // a-z
        rts
b:      cmp #$41
        bcc c
        cmp #$5b
        bcs c
        rts                      // A-Z (SHIFT)
c:      cmp #$64
        bne d
        lda #$5f
d:      rts
}

//--------------------------------------------------------
// Links volgen
//--------------------------------------------------------
// lk_Follow - link A (of het zoekveld / de zoekknop).
lk_Follow: {
        cmp #WL_FIELD
        bne s
        jmp fm_Edit
s:      cmp #WL_SUBMIT
        bne l
        jmp fm_Submit
l:      tax
        lda LK_HI,x
        beq hs
        sta wS+1                 // bewaard adres -> WB_HREF
        lda LK_LO,x
        sta wS
        lda LK_H,x
        sta lkL
        ldy #0
c:      cpy lkL
        beq ce
        lda (wS),y
        sta WB_HREF,y
        iny
        bne c
ce:     lda #0
        sta WB_HREF,y
        jmp nv_Link
hs:     lda LK_LO,x              // te lang adres: de pagina opnieuw lezen
        sta fdLo                 // en de link met dit controlegetal zoeken
        lda LK_H,x
        sta fdHi
        jmp nv_Find
}

// nv_Link - link WB_HREF volgen (t.o.v. de pagina; op de bladwijzers is
//           elke link al een adres).
nv_Link: {
        lda WB_URL
        bne r
        ldx #CP_HREF_NEW
        jsr cp_Pair
        jmp g
r:      jsr nv_Base
        jsr ur_Resolve
        bcs g
        ldx #<sWbBadUrl
        ldy #>sWbBadUrl
        jmp nv_Msg
g:      lda #1
        sta ntPush
        jmp nv_Go
}

// nv_Base - WB_URL als basis (UB) voor ur_Resolve.
nv_Base:
        ldx #CP_URL_UB
        jmp cp_Pair

// nv_Find - de link met controlegetal fdLo/fdHi zoeken op de pagina.
nv_Find: {
        ldx #CP_URL_NEW
        jsr cp_Pair
        jsr ur_Norm
        bcc m
        jsr ur_Parse
        bcc m
        lda #1
        sta htFind
        lda #0
        sta ntPush
        jsr wb_Loading
        jsr nt_Fetch
        lda #0
        sta htFind
        lda htFound
        bne f
        ldx #<sWbNoLink
        ldy #>sWbNoLink
m:      jmp nv_Msg
f:      ldx #CP_NEW_HREF         // gevonden: WB_NEW = de link zoals hij er staat
        jsr cp_Pair
        jmp nv_Link
}

//--------------------------------------------------------
// nv_Go - naar WB_NEW (ntPush = 1: de huidige pagina in de geschiedenis).
//         Volgt doorverwijzingen (max. 5).
//--------------------------------------------------------
nv_Go: {
        lda #0
        sta nvRed
lp:     jsr ur_Norm
        bcs !w2+
        jmp m
!w2:
        jsr ur_Parse
        bcs !w3+
        jmp m
!w3:
        lda #0
        sta htFind
        jsr wb_Loading
        jsr nt_Fetch
        php
        stx nvMx
        sty nvMy
        lda ntStarted
        beq ns
        jsr ht_End               // de pagina is vervangen
        ldx #CP_NEW_URL
        jsr cp_Pair
        plp
        bcs ok
        ldx nvMx                 // (gestopt / verbinding weg: wat er is blijft)
        ldy nvMy
        jmp nv_Msg
ok:     lda ntCode               // 4xx/5xx: de pagina van de server + melding
        cmp #$34
        bcc d
        ldx #2
e:      lda ntCode,x
        sta sWbErrN,x
        dex
        bpl e
        ldx #<sWbErr
        ldy #>sWbErr
        jmp nv_Msg
d:      lda #0
        sta wbMsg+1
        jmp shell_DrawAll
ns:     plp                      // niets getoond
        bcs n1
        ldx nvMx
        ldy nvMy
        jmp nv_Msg
n1:     lda ntCode
        cmp #$33
        bne n2
        lda WB_REQ               // doorverwijzing
        beq n3
        inc nvRed
        lda nvRed
        cmp #6
        bcs n4
        ldx #CP_NEW_UB           // basis = het adres dat net gevraagd werd
        jsr cp_Pair
        ldx #CP_REQ_HREF         // (Location)
        jsr cp_Pair
        jsr ur_Resolve
        bcc n3
        jmp lp
n2:     ldx #<sWbType2           // geen tekst
        ldy #>sWbType2
        lda ntType
        cmp #2
        beq m
        ldx #<sWbEmpty
        ldy #>sWbEmpty
        jmp m
n3:     ldx #<sWbBadUrl
        ldy #>sWbBadUrl
        jmp m
n4:     ldx #<sWbRedir
        ldy #>sWbRedir
m:      jmp nv_Msg
}

// nv_Msg - melding X/Y en alles opnieuw tekenen.
nv_Msg:
        stx wbMsg
        sty wbMsg+1
        jmp shell_DrawAll

//--------------------------------------------------------
// Het zoekformulier
//--------------------------------------------------------
// fm_Edit - in het zoekveld typen (op de plek van de klik); RETURN = zoeken.
fm_Edit: {
        lda pdHitC               // kolom van "[" -> tekst ernaast
        clc
        adc #WB_C0+1
        sta liCol
        lda evtB
        sta liRow
        lda #12
        sta liVis
        lda #40
        sta liMax
        lda #<WB_FVAL
        sta r3
        lda #>WB_FVAL
        sta r3+1
        lda liCol                // het veld leeg maken op het scherm
        sta a0
        lda evtB
        sta a1
        lda #12
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_accent
        sta a5
        jsr gfx_FillRect
        jsr li_Edit
        bcs x
        jmp fm_Submit
x:      jmp shell_DrawAll
}

// fm_Submit - action?naam=zoektekst&verborgen... -> WB_HREF, dan volgen.
//             (Geen action: "?..." t.o.v. deze pagina.)
fm_Submit: {
        ldx #0
a:      lda WB_FACT,x
        beq ae
        sta WB_HREF,x
        inx
        bne a
ae:     stx fmX
        lda #$3f                 // ? of & (als er al een ? in staat)
        sta fmSep
        ldy #0
qf:     cpy fmX
        beq qd
        lda WB_HREF,y
        iny
        cmp #$3f
        bne qf
        lda #$26
        sta fmSep
qd:     ldx fmX
        lda fmSep
        jsr hp
        ldy #0
n:      lda WB_FNAME,y           // naam=
        beq ne
        jsr hp
        iny
        bne n
ne:     lda #$3d
        jsr hp
        ldy #0
v:      lda WB_FVAL,y            // zoektekst, gecodeerd
        cmp #$ff
        beq ve
        jsr scr2url
        cmp #$20
        bne v1
        lda #$2b                 // spatie -> +
        bne v3
v1:     jsr urlOk
        bcs v3
        pha                      // %XX
        lda #$25
        jsr hp
        pla
        pha
        lsr
        lsr
        lsr
        lsr
        jsr hx
        pla
        and #$0f
        jsr hx
        jmp v4
v3:     jsr hp
v4:     iny
        cpy #40
        bne v
ve:     ldy #0
h:      lda WB_FHID,y            // verborgen velden (&n=v...)
        beq he
        jsr hp
        iny
        bne h
he:     lda #0
        sta WB_HREF,x
        jmp nv_Link
hx:     ora #$30
        cmp #$3a
        bcc hp
        adc #6                   // (carry=1: +7 -> A-F)
hp:     cpx #250
        bcs hr
        sta WB_HREF,x
        inx
hr:     rts
// urlOk - carry=1: A mag zo in een adres (letters, cijfers, - . _)
urlOk:  cmp #$30
        bcc u1
        cmp #$3a
        bcc uy
        cmp #$41
        bcc un
        cmp #$5b
        bcc uy
        cmp #$61
        bcc u2
        cmp #$7b
        bcc uy
        bcs un
u1:     cmp #$2d
        beq uy
        cmp #$2e
        beq uy
        bne un
u2:     cmp #$5f
        beq uy
un:     clc
        rts
uy:     sec
        rts
}

//--------------------------------------------------------
// Scrollen
//--------------------------------------------------------
// pg_Down - A regels verder (zolang er onder de onderste nog regels zijn).
pg_Down: {
        sta pgN
l:      lda wbTop                // wbTop + 16 < nLines ?
        clc
        adc #WB_ROWS
        tax
        lda wbTop+1
        adc #0
        cmp nLines+1
        bcc ok
        bne r
        cpx nLines
        bcs r
ok:     ldy #0                   // wT += lengte + 2
        lda (wT),y
        clc
        adc #2
        adc wT
        sta wT
        bcc i
        inc wT+1
i:      inc wbTop
        bne n
        inc wbTop+1
n:      dec pgN
        bne l
r:      rts
}

// pg_Up - A regels terug.
pg_Up: {
        sta pgN
l:      lda wbTop
        ora wbTop+1
        beq r
        lda wT                   // lengte van de vorige regel staat op wT-1
        sec
        sbc #1
        sta wQ
        lda wT+1
        sbc #0
        sta wQ+1
        ldy #0
        lda (wQ),y
        clc
        adc #2
        sta pgL
        lda wT
        sec
        sbc pgL
        sta wT
        bcs d
        dec wT+1
d:      lda wbTop
        bne d1
        dec wbTop+1
d1:     dec wbTop
        dec pgN
        bne l
r:      rts
}

// wb_Key - SPATIE verder, - terug, B BACK, M MARKS, R RELOAD, G adres.
wb_Key: {
        cmp #$20
        bne k1
        lda #WB_PG
        jsr pg_Down
        jmp v
k1:     cmp #$2d
        bne k2
        lda #WB_PG
        jsr pg_Up
v:      jsr wb_View
        sec
        rts
k2:     cmp #2                   // B
        bne k3
        jsr wb_Back
        sec
        rts
k3:     cmp #13                  // M
        bne k4
        jsr wb_Marks
        sec
        rts
k4:     cmp #18                  // R
        bne k5
        jsr wb_Reload
        sec
        rts
k5:     cmp #7                   // G
        bne no
        jsr wb_Edit
        sec
        rts
no:     clc
        rts
}

//--------------------------------------------------------
.encoding "screencode_upper"
sWbBack:    .text "BACK"
            .byte $ff
sWbMarks:   .text "MARKS"
            .byte $ff
sWbReload:  .text "RELOAD"
            .byte $ff
sWbType:    .text "CLICK HERE TO TYPE AN ADDRESS"
            .byte $ff
sWbLines:   .text "LINES "
            .byte $ff
sWbOf:      .text " OF "
            .byte $ff
sWbLoading: .text "LOADING "
            .byte $ff
sWbFind:    .text "FINDING THE LINK "
            .byte $ff
sWbStopH:   .text " (RUN/STOP)"
            .byte $ff
sWbStop:    .text "STOPPED"
            .byte $ff
sWbHttps:   .text "HTTPS: NOT POSSIBLE ON A C64"
            .byte $ff
sWbBadUrl:  .text "CANNOT OPEN THIS ADDRESS"
            .byte $ff
sWbType2:   .text "CANNOT SHOW THIS TYPE OF FILE"
            .byte $ff
sWbEmpty:   .text "THE PAGE IS EMPTY"
            .byte $ff
sWbRedir:   .text "TOO MANY REDIRECTS"
            .byte $ff
sWbNoLink:  .text "LINK NOT FOUND (PAGE CHANGED?)"
            .byte $ff
sWbErr:     .text "THE SERVER SAYS ERROR "
sWbErrN:    .text "000"
            .byte $ff
wbMsg:      .word 0
wbTop:      .word 0              // nummer van de bovenste regel
wbI:        .byte 0
pdR:        .byte 0
pdLen:      .byte 0
pdX:        .byte 0
pdAcc:      .byte 0
pdId:       .byte 0
pdLnk:      .byte 0
pdSt:       .byte 0
pdCol:      .byte $ff       // (pd_Dec: kolom om de link te zoeken)
pdCol1:     .byte 0
pdEnd:      .byte 0
lkL:        .byte 0
fmSep:      .byte 0
pdHit:      .byte $ff
pdHitC:     .byte 0
fcO2:       .byte 0
ouX:        .byte 0
dcLo:       .byte 0
dcHi:       .byte 0
dcNz:       .byte 0
pgN:        .byte 0
pgL:        .byte 0
nvRed:      .byte 0
nvMx:       .byte 0
nvMy:       .byte 0
fmX:        .byte 0
.label WB_OUTC = WB_OUT + 48     // kleuren bij WB_OUT
