#importonce
//========================================================
// apps/weather/weather.asm - WEERBERICHT (app 14, PRG WEATHER)
// Commodore Desk 64
//
// Het actuele weer van wttr.in (gewone HTTP, geen sleutel), zie
// docs/WEATHER_Plan.md. De dienst stuurt een regel met | tussen de velden:
//   %l|%x|%t|%f|%C|%w|%h|%p|%P|%S|%s|%T
//   Utrecht|m|+19°C|+18°C|Partly cloudy|↗6km/h|63%|0.0mm|1016hPa|07:58:12|...
// we_Parse zet die (ASCII + UTF-8) om naar schermcodes in WE_BUF: °C wordt
// " C", een windpijl een windrichting.
//
// Het weerbeeld: lagen multicolor-sprites (zon/maan, wolk, neerslag,
// bliksem) uit tools/make_weather_sprites.py, op $3E00-$3FFF (daar staan
// de bureaublad-iconen; die worden zolang bewaard op WE_SAVE). De Core
// roept ovIdle (animatie) en ovExit (sprites uit, iconen terug) aan.
//
// Ophalen (weather_net.asm): na het openen, met REFRESH en elke 15
// minuten zolang WEATHER open is (ovIdle). Plaats: weLoc (leeg = AUTO).
//
// Twee pagina's (wePage): 0 = het weer nu, 1 = de verwachting voor 3
// dagen (weather_fc.asm); de knop 3 DAYS / NOW wisselt. Eenheden (weUnit):
// 0 = C en km/h, 1 = F en mph; samen met de plaats in WEATHER.CFG.
//========================================================

.const WE_HELP  = 19             // F1-context (gui/help.txt)
.const WE_COL   = 3              // linkerkolom
.const WE_SKYR  = 7              // luchtvlak (plaatje): rij 7-17, kol 3-14
                                 // (onder de uitklapmenu's: sprites staan voor tekst)
.const WE_SKYW  = 12
.const WE_SKYH  = 11
.const WE_R_LOC = 3              // LOCATION + CHANGE
.const WE_R_UPD = 21             // UPDATED + REFRESH
.const WE_R_MSG = 22             // meldingen
.const WE_C_CHG = 29             // CHANGE-knop
.const WE_W_CHG = 8
.const WE_C_REF = 27             // REFRESH-knop
.const WE_W_REF = 9
.const WE_C_PG  = 17             // 3 DAYS / NOW
.const WE_W_PG  = 8
.const WE_R_UN  = 4              // eenheden-knop (onder CHANGE, even breed)
.const WE_C_UN  = WE_C_CHG
.const WE_W_UN  = WE_W_CHG
.const WI_N     = 22             // regels in de wi-tabellen (we_Draw)
.label weS = r5                  // zeropage: bron (antwoord)
.label weD = r6                  // zeropage: doel (veld)

we_Init:
        lda #WE_HELP
        sta helpCtx
        lda #0
        sta weMsg+1
        sta weMinCnt
        lda #$ff
        sta weType
        jsr we_LoadCfg           // de bewaarde plaats (WEATHER.CFG)
        lda #<weEmpty            // velden leeg tot het eerste antwoord
        sta weS
        lda #>weEmpty
        sta weS+1
        jsr we_Parse
        jsr we_LocDefault
        lda clkMin
        sta weLastMin
        lda #1                   // ophalen zodra het scherm staat (we_Idle)
        sta weNeed
        lda #<we_SprOff          // haken in de Core: sluiten en de hoofdlus
        sta ovExit
        lda #>we_SprOff
        sta ovExit+1
        lda #<we_Idle
        sta ovIdle
        lda #>we_Idle
        sta ovIdle+1
        rts

// we_DoFetch - "FETCHING ...", ophalen, alles opnieuw tekenen (met de
//              melding van een fout; de vorige gegevens blijven dan staan).
we_DoFetch:
        lda #<sWeBusy
        sta weMsg
        lda #>sWeBusy
        sta weMsg+1
        jsr we_ShowMsg
        jsr we_Fetch
        bcs !ok+
        stx weMsg
        sty weMsg+1
        lda weMode               // verwachting mislukt: geen halve dagen
        beq !d+
        lda #0
        sta fcN
!d:     jmp shell_DrawAll
!ok:    lda #0
        sta weMsg+1
        sta weMinCnt
        jmp shell_DrawAll

// we_Key - geen eigen toetsen (SPATIE/RETURN = klik op de cursor).
we_Key:
        clc
        rts

//--------------------------------------------------------
// we_Parse - wttr.in-regel (weS: ASCII/UTF-8, tot $00, CR of LF) in de
//            velden WE_BUF (schermcodes, $ff-afgesloten, max. weFMax).
//--------------------------------------------------------
we_Parse: {
        ldx #WE_NF-1             // alle velden leeg
cl:     txa
        jsr fptr
        lda #$ff
        ldy #0
        sta (weD),y
        dex
        bpl cl
        lda #0
        sta weF
        sta weN
        jsr fptr0
nx:     ldy #0
        lda (weS),y
        bne !j0+
        jmp end
!j0:
        cmp #$0d
        bne !j1+
        jmp end
!j1:
        cmp #$0a
        bne !j2+
        jmp end
!j2:
        jsr inc1
        cmp #$7c                 // | = volgend veld
        bne nb
        jsr term
        inc weF
        lda weF
        cmp #WE_NF
        bcc !j4+
        jmp done
!j4:
        lda #0
        sta weN
        jsr fptr0
        jmp nx
nb:     cmp #$2c                 // plaats: alleen tot de eerste komma
        bne nc
        ldx weF
        bne nc
        jsr term
        lda weFMax
        sta weN
        jmp nx
nc:     cmp #$80
        bcs utf
        jsr asc
        jsr put
        jmp nx
utf:    cmp #$c2                 // C2 B0 = graden-teken -> spatie
        bne u3
        ldy #0
        lda (weS),y
        jsr inc1
        cmp #$b0
        bne nx
        lda #$20
        jsr put
        jmp nx
u3:     cmp #$e2                 // E2 86 90-99 = pijl -> windrichting
        bne usk
        ldy #0
        lda (weS),y
        sta weT
        iny
        lda (weS),y
        sta weT+1
        jsr inc1
        jsr inc1
        lda weT
        cmp #$86
        beq !j0+
        jmp nx
!j0:
        lda weT+1
        sec
        sbc #$90
        cmp #10
        bcc !j3+
        jmp nx
!j3:
        asl
        sta weI
        tax
        lda weDir,x
        jsr put
        ldx weI
        lda weDir+1,x
        cmp #$20
        beq sp
        jsr put
sp:     lda #$20
        jsr put
        jmp nx
usk:    cmp #$e0                 // andere UTF-8: de vervolgbytes overslaan
        bcc s1
        cmp #$f0
        bcc s2
        jsr inc1
s2:     jsr inc1
s1:     jsr inc1
        jmp nx
end:    jsr term
done:   rts

inc1:   inc weS                  // (A blijft)
        bne r1
        inc weS+1
r1:     rts
put:    sta weC                  // A in het veld (tot de maximale lengte)
        ldx weF
        lda weFMax,x
        cmp weN
        beq r2
        bcc r2
        ldy weN
        lda weC
        sta (weD),y
        inc weN
r2:     rts
term:   lda #$ff
        ldy weN
        sta (weD),y
        rts
fptr0:  lda weF
fptr:   tay                      // weD = veld A
        lda weFLo,y
        sta weD
        lda weFHi,y
        sta weD+1
        rts
asc:    cmp #$61                 // ASCII -> schermcode (hoofdletters)
        bcc a1
        cmp #$7b
        bcs q
        and #$1f                 // a-z
        rts
a1:     cmp #$41
        bcc a2
        cmp #$5b
        bcs q
        and #$1f                 // A-Z
        rts
a2:     cmp #$40
        beq at
        cmp #$20
        bcc q
        rts                      // spatie, cijfers, leestekens
at:     lda #0
        rts
q:      lda #$2e                 // de rest -> .
        rts
}

//--------------------------------------------------------
// we_Draw - plaatsnaam, luchtvlak, het weer, knoppen, melding.
//--------------------------------------------------------
we_Draw: {
        lda #<weUpd              // UPDATED: van de pagina
        ldx #>weUpd
        ldy wePage
        beq u
        lda #<fcUpd
        ldx #>fcUpd
u:      sta wiLo+WI_N-1
        stx wiHi+WI_N-1
        ldx #0                   // teksten en velden (tabel weI*)
lp:     lda wePage               // verwachting: alleen plaats en UPDATED
        beq lq
        cpx #2
        bcc lq
        cpx #WI_N-2
        bcc nx
lq:     stx weI
        lda wiLo,x
        sta r0
        lda wiHi,x
        sta r0+1
        lda wiCol,x
        sta a0
        lda wiRow,x
        sta a1
        lda TH_text
        ldy wiAcc,x
        beq c
        lda TH_accent
c:      sta a2
        jsr gfx_DrawText
        ldx weI
nx:     inx
        cpx #WI_N
        bne lp
        lda wePage
        beq now
        jsr fc_Draw
        jsr fc_SprShow
        jmp bt
now:    lda #WE_COL              // luchtvlak (stap 4: sprites erin)
        sta a0
        lda #WE_SKYR
        sta a1
        lda #WE_SKYW
        sta a2
        lda #WE_SKYH
        sta a3
        lda #GL_SOLID
        sta a4
        ldx weType               // lucht van het weertype
        lda TH_deskbg
        cpx #WT_N
        bcs sk
        lda wtSky,x
sk:     sta a5
        jsr gfx_FillRect
        jsr we_SprShow
bt:     lda #<sWeChange          // knoppen
        sta r0
        lda #>sWeChange
        sta r0+1
        lda #WE_C_CHG
        sta a0
        lda #WE_R_LOC
        sta a1
        lda #WE_W_CHG
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sWeRefresh
        sta r0
        lda #>sWeRefresh
        sta r0+1
        lda #WE_C_REF
        sta a0
        lda #WE_R_UPD
        sta a1
        lda #WE_W_REF
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sWe3Days           // 3 DAYS / NOW
        ldx #>sWe3Days
        ldy wePage
        beq p
        lda #<sWeNow
        ldx #>sWeNow
p:      sta r0
        stx r0+1
        lda #WE_C_PG
        sta a0
        lda #WE_R_UPD
        sta a1
        lda #WE_W_PG
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sWeMetric          // C KM/H / F MPH
        ldx #>sWeMetric
        ldy weUnit
        beq m
        lda #<sWeUS
        ldx #>sWeUS
m:      sta r0
        stx r0+1
        lda #WE_C_UN
        sta a0
        lda #WE_R_UN
        sta a1
        lda #WE_W_UN
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        jmp we_ShowMsg
}

// we_ShowMsg - meldingsregel (weMsg, 0 = leeg).
we_ShowMsg: {
        lda #WE_COL
        sta a0
        lda #WE_R_MSG
        sta a1
        lda #34
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda weMsg+1
        beq r
        sta r0+1
        lda weMsg
        sta r0
        lda #WE_COL
        sta a0
        lda #WE_R_MSG
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
r:      rts
}

//--------------------------------------------------------
// we_Click - CHANGE (locatie, stap 6) en REFRESH.
//--------------------------------------------------------
we_Click: {
        lda #WE_C_CHG
        sta a0
        lda #WE_R_LOC
        sta a1
        lda #WE_W_CHG
        sta a2
        jsr btn_HitTest
        bcc nc
        jmp we_Change
nc:     lda #WE_C_REF
        sta a0
        lda #WE_R_UPD
        sta a1
        lda #WE_W_REF
        sta a2
        jsr btn_HitTest
        bcc np
        lda #1                   // REFRESH: ophalen (in we_Idle)
        sta weNeed
        rts
np:     lda #WE_C_PG
        sta a0
        lda #WE_R_UPD
        sta a1
        lda #WE_W_PG
        sta a2
        jsr btn_HitTest
        bcc nu
        lda #0
        sta weMsg+1
        lda wePage               // andere pagina; nu altijd opnieuw ophalen,
        eor #1                   // de verwachting alleen als hij er niet is
        sta wePage
        beq f
        lda fcN
        bne d
f:      lda #1
        sta weNeed
d:      jmp shell_DrawAll
nu:     lda #WE_C_UN
        sta a0
        lda #WE_R_UN
        sta a1
        lda #WE_W_UN
        sta a2
        jsr btn_HitTest
        bcc r
        lda weUnit               // C <-> F: bewaren en opnieuw ophalen
        eor #1
        sta weUnit
        jsr we_SaveCfg
        jmp we_Reset
r:      rts
}

//--------------------------------------------------------
// Weertype en sprites (stap 4)
//--------------------------------------------------------
// we_Type - weType uit het symbool (%x), 's nachts maan i.p.v. zon.
we_Type: {
        ldx #0
next:   lda weSymT,x             // tabel: patroon, $ff, type ... $fe = einde
        cmp #$fe
        beq unk
        ldy #0
cl:     lda weSymT,x
        cmp WE_BUF+WF_SYM*WE_FL,y
        bne skip
        cmp #$ff
        beq hit
        inx
        iny
        bne cl
skip:   lda weSymT,x             // naar het volgende patroon
        inx
        cmp #$ff
        bne skip
        inx                      // (typebyte)
        jmp next
hit:    lda weSymT+1,x
        jmp got
unk:    lda #15                  // onbekend: wolk met vraagteken
got:    sta weType
        jsr we_Night
        bcc r
        ldx #2                   // nacht: zon -> maan, buien -> lichte regen
nl:     lda weType
        cmp weDayT,x
        bne nn
        lda weNightT,x
        sta weType
        rts
nn:     dex
        bpl nl
r:      rts
}
weDayT:   .byte 0, 2, 8          // SUNNY, PARTLY CLOUDY, SHOWERS
weNightT: .byte 1, 3, 7          // CLEAR NIGHT, PARTLY CLOUDY NIGHT, LIGHT RAIN

// we_Night - carry=1 als de lokale tijd (%T) voor zonsopkomst (%S) of na
//            zonsondergang (%s) ligt. Tijden als "HH:MM" (schermcodes).
we_Night: {
        lda WE_BUF+WF_TIME*WE_FL
        cmp #$ff
        beq day
        lda WE_BUF+WF_RISE*WE_FL
        cmp #$ff
        beq day
        lda WE_BUF+WF_SET*WE_FL
        cmp #$ff
        beq day
        ldx #0
r:      lda WE_BUF+WF_TIME*WE_FL,x
        cmp WE_BUF+WF_RISE*WE_FL,x
        bcc night                // voor zonsopkomst
        bne s
        inx
        cpx #5
        bne r
s:      ldx #0
t:      lda WE_BUF+WF_TIME*WE_FL,x
        cmp WE_BUF+WF_SET*WE_FL,x
        bcc day                  // voor zonsondergang
        bne night
        inx
        cpx #5
        bne t
night:  sec
        rts
day:    clc
        rts
}

//--------------------------------------------------------
// we_SprShow - het weerbeeld van weType: vormen naar $3E00 (eerst de
//              bureaublad-iconen daar bewaren), sprites 1-7 zetten.
//--------------------------------------------------------
we_SprShow: {
        lda weType
        cmp #WT_N
        bcc ok
        jmp we_SprOff
ok:     jsr we_SprSave
        lda #<weSprData
        sta weBase
        lda #>weSprData
        sta weBase+1
        jmp we_SprLay
}

// we_SprSave - eenmalig de bureaublad-iconen op $3E00-$3FFF bewaren en de
//              haken van de Core zetten.
we_SprSave: {
        lda weSaved
        bne r
        ldx #0                   // $3E00-$3FFF (iconen) bewaren
sv:     lda $3e00,x
        sta WE_SAVE,x
        lda $3f00,x
        sta WE_SAVE+$100,x
        inx
        bne sv
        inc weSaved
        lda #<we_SprOff          // de Core roept dit aan bij sluiten
        sta ovExit
        lda #>we_SprOff
        sta ovExit+1
        lda #<we_Idle            // en dit in de hoofdlus (animatie)
        sta ovIdle
        lda #>we_Idle
        sta ovIdle+1
r:      rts
}

we_SprLay: {
cp:     lda weType               // tabelindex van laag 0
        asl
        asl
        sta weB
        lda #0
        sta weSlot
        sta weL
cl:     ldx weType               // vormen van de lagen
        lda weL
        cmp wtNL,x
        bcs an
        clc
        adc weB
        tax
        lda wtShape,x
        jsr we_CpShape
        ldx weL
        sta weLBlk,x
        inc weL
        jmp cl
an:     ldx weType               // tweede vorm van de bewegende laag
        lda wtAnimL,x
        cmp #$ff
        beq spr
        tay
        lda weLBlk,y
        sta weABlk
        lda wtAnimB,x
        jsr we_CpShape
        sta weBBlk
spr:    lda #0
        sta weMask
        sta weL
        sta weFr
        lda #1
        sta weSpr
sl:     ldx weType
        lda weL
        cmp wtNL,x
        bcs reg
        clc
        adc weB
        sta weI                  // tabelindex van deze laag
        ldx weL
        lda weSpr
        sta weLSpr,x
        lda weLBlk,x
        jsr one                  // linker sprite
        ldx weI
        lda wtW,x
        cmp #2
        bne nx
        ldx weL                  // rechter sprite: blok+1, 48 pixels verder
        lda weLBlk,x
        clc
        adc #1
        jsr one
        dey                      // (Y = 2 * spritenummer van de rechter)
        dey
        lda $d000,y
        clc
        adc #48
        sta $d000,y
nx:     inc weL
        jmp sl
reg:    lda $d010                // x < 256; muis (sprite 0) blijft
        and #1
        sta $d010
        lda $d01b                // voor de tekens (het luchtvlak)
        and #1
        sta $d01b
        lda $d01c                // multicolor
        and #1
        ora weMask
        sta $d01c
        lda $d017                // dubbel hoog en breed
        and #1
        ora weMask
        sta $d017
        lda $d01d
        and #1
        ora weMask
        sta $d01d
        lda #WHITE
        sta $d025
        lda #LIGHT_GREY
        sta $d026
        lda $d015
        and #1
        ora weMask
        sta $d015
        lda #1
        sta weAC
        sta weBC
        rts
// one - sprite weSpr: blok A, kleur/plaats van laag weI; weSpr+1.
one:    ldy weSpr
        sta $07f8,y
        ldx weI
        lda wtCol,x
        sta $d027,y
        lda bitTab,y
        ora weMask
        sta weMask
        tya
        asl
        tay
        lda wtX,x
        sta $d000,y
        lda wtY,x
        sta $d001,y
        iny
        iny
        inc weSpr
        rts
}

// we_CpShape - vorm A (128 bytes) naar plek weSlot op $3E00; A = blok.
we_CpShape: {
        sta weT                  // bron = weBase + A*128
        lsr
        clc
        adc weBase+1
        sta weS+1
        lda weT
        and #1
        beq e
        lda #$80
e:      clc
        adc weBase
        sta weS
        bcc s1
        inc weS+1
s1:     lda weSlot               // doel = $3E00 + slot*128
        lsr
        clc
        adc #$3e
        sta weD+1
        lda weSlot
        and #1
        beq f
        lda #$80
f:      sta weD
        ldy #127
lp:     lda (weS),y
        sta (weD),y
        dey
        bpl lp
        lda weSlot               // blok = $3E00/64 + 2*slot
        asl
        clc
        adc #$3e00/64
        inc weSlot
        rts
}

// we_SprOff - sprites 1-7 uit, de bureaublad-iconen terug (ovExit).
we_SprOff: {
        lda $d015
        and #1
        sta $d015
        lda weSaved
        beq r
        ldx #0
rs:     lda WE_SAVE,x
        sta $3e00,x
        lda WE_SAVE+$100,x
        sta $3f00,x
        inx
        bne rs
        lda #0
        sta weSaved
r:      rts
}

// we_Idle - animatie (ovIdle, elke ronde van de hoofdlus): op de 1/10 s
//           van de TOD-klok; elke 0,3 s het andere beeld van de bewegende
//           laag, de bliksem 0,2 s aan per 2,5 s.
we_Idle: {
        lda weNeed               // ophalen gevraagd (openen, REFRESH, 15 min)
        beq m
        lda #0
        sta weNeed
        jmp we_DoFetch
m:      lda clkMin               // elke 15 minuten opnieuw
        cmp weLastMin
        beq an
        sta weLastMin
        inc weMinCnt
        lda weMinCnt
        cmp #15
        bcc an
        lda #0
        sta weMinCnt
        sta fcN                  // (verwachting: opnieuw zodra hij te zien is)
        inc weNeed
an:     lda wePage               // verwachting: geen animatie
        bne r
        lda $dc08                // tienden van de TOD-klok
        cmp weLastT
        bne t
        rts
t:      sta weLastT
        ldx weType
        cpx #WT_N
        bcs r
        dec weAC
        bne bolt
        lda #3
        sta weAC
        lda wtAnimL,x
        cmp #$ff
        beq bolt
        tay                      // eerste sprite van de laag
        lda weLSpr,y
        tay
        lda weFr
        eor #1
        sta weFr
        lda weABlk
        ldx weFr
        beq a
        lda weBBlk
a:      sta $07f8,y
        clc
        adc #1
        sta $07f9,y              // (rechter sprite; bij 1 sprite onzichtbaar)
bolt:   ldx weType
        lda wtBolt,x
        cmp #$ff
        beq r
        tay
        lda weLSpr,y
        tay                      // spritenummer van de bliksem
        dec weBC
        bpl b1
        lda #24
        sta weBC
b1:     lda weBC
        cmp #2
        bcs off
        lda $d015
        ora bitTab,y
        sta $d015
        rts
off:    lda bitTab,y
        eor #$ff
        and $d015
        sta $d015
r:      rts
}

bitTab:   .byte 1, 2, 4, 8, 16, 32, 64, 128
// wttr.in %x -> weertype (schermcodes: o = 15, m = 13, x = 24)
weSymT:   .byte 15, $ff, 0                    // o    zonnig / helder
          .byte 13, $ff, 2                    // m    half bewolkt
          .byte 13, 13, $ff, 4                // mm   bewolkt
          .byte 13, 13, 13, $ff, 5            // mmm  zwaar bewolkt
          .byte $3d, $ff, 6                   // =    mist
          .byte $2f, $ff, 7                   // /    lichte regen
          .byte $2e, $ff, 8                   // .    lichte buien
          .byte $2f, $2f, $ff, 9              // //   (zware) buien
          .byte $2f, $2f, $2f, $ff, 9         // ///  zware regen
          .byte $2a, $ff, 10                  // *    lichte sneeuw
          .byte $2a, $2f, $ff, 10             // */   sneeuwbuien
          .byte $2a, $2a, $ff, 11             // **   zware sneeuw
          .byte $2a, $2f, $2a, $ff, 11        // */*  zware sneeuwbuien
          .byte 24, $ff, 12                   // x    natte sneeuw
          .byte 24, $2f, $ff, 12              // x/   natte-sneeuwbuien
          .byte $21, $2f, $ff, 13             // !/   onweersbuien
          .byte $2f, $21, $2f, $ff, 13        // /!/  onweer met zware regen
          .byte $2a, $21, $2a, $ff, 14        // *!*  onweer met sneeuw
          .byte $fe
weType:   .byte $ff
weSaved:  .byte 0
weB:      .byte 0
weL:      .byte 0
weSlot:   .byte 0
weSpr:    .byte 0
weMask:   .byte 0
weFr:     .byte 0
weAC:     .byte 1
weBC:     .byte 1
weLastT:  .byte 0
weABlk:   .byte 0
weBBlk:   .byte 0
weLBlk:   .fill 4, 0
weLSpr:   .fill 4, 0


//--------------------------------------------------------
// Plaats kiezen en bewaren (stap 6): WEATHER.CFG = weLoc (32 bytes,
// schermcodes, $ff-afgesloten; leeg = AUTO).
//--------------------------------------------------------
// we_LoadCfg - WEATHER.CFG naar weLoc (ontbreekt hij: AUTO).
we_LoadCfg: {
        jsr cfg_io_begin
        lda #nmE-nm
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #0                   // sa=0: naar het adres in X/Y
        jsr K_SETLFS
        lda #0
        ldx #<weLoc
        ldy #>weLoc
        jsr K_LOAD
        jsr cfg_io_end
        lda #$ff                 // altijd afgesloten
        sta weLoc+31
        lda weUnit
        and #1
        sta weUnit
        jmp we_Clean
nm:     .encoding "petscii_upper"
        .text "WEATHER.CFG"
nmE:
        .encoding "screencode_upper"
}

// we_SaveCfg - weLoc als WEATHER.CFG ("SETTINGS ARE BEING SAVED").
we_SaveCfg: {
        jsr save_Begin
        jsr cfg_io_begin
        lda #nmE-nm
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #0
        jsr K_SETLFS
        lda #<weLoc
        sta $fb
        lda #>weLoc
        sta $fc
        lda #$fb
        ldx #<[weLoc+33]         // plaats + eenheid
        ldy #>[weLoc+33]
        jsr K_SAVE
        php
        jsr cfg_io_end
        plp
        jmp save_End
nm:     .encoding "petscii_upper"
        .text "@0:WEATHER.CFG"
nmE:
        .encoding "screencode_upper"
}

// we_Change - CHANGE: plaats typen (RETURN), bewaren, het weer ophalen.
we_Change: {
        lda #<sWeAsk
        sta weMsg
        lda #>sWeAsk
        sta weMsg+1
        jsr we_ShowMsg
        lda #13                  // het oude antwoord weg uit de regel
        sta a0
        lda #WE_R_LOC
        sta a1
        lda #15
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda #<weLoc
        sta r3
        lda #>weLoc
        sta r3+1
        lda #31
        sta liMax
        lda #13
        sta liCol
        lda #WE_R_LOC
        sta liRow
        lda #15
        sta liVis
        jsr li_Edit
        jsr we_Clean
        jsr we_SaveCfg
        // (valt door)
}

// we_Reset - nieuwe plaats of eenheid: de oude gegevens weg, ophalen.
we_Reset: {
        lda #0
        sta fcN
        lda #$ff                 // geen oude gegevens bij de nieuwe plaats
        sta weType
        lda #<weEmpty
        sta weS
        lda #>weEmpty
        sta weS+1
        jsr we_Parse
        jsr we_LocDefault
        ldx #4                   // UPDATED weer --:--
u:      lda sWeNoTime,x
        sta weUpd,x
        sta fcUpd,x
        dex
        bpl u
        lda #0
        sta weMsg+1
        lda #1                   // ophalen (we_Idle)
        sta weNeed
        jmp shell_DrawAll
}

// we_LocDefault - zolang er geen antwoord is: de gekozen plaats of AUTO.
we_LocDefault: {
        ldx #0
        lda weLoc
        cmp #$ff
        bne lp
a:      lda sWeAuto,x            // AUTO
        sta WE_BUF+WF_LOC*WE_FL,x
        inx
        cmp #$ff
        bne a
        rts
lp:     lda weLoc,x
        cpx #15                  // (veldbreedte)
        bcc s
        lda #$ff
s:      sta WE_BUF+WF_LOC*WE_FL,x
        inx
        cmp #$ff
        bne lp
        rts
}

// we_Clean - alleen A-Z, 0-9, spatie, - en , in weLoc; geen spaties aan
//            het begin of eind (ze worden + in het webadres).
we_Clean: {
        ldx #0
        ldy #0
lp:     cpx #31
        bcs e
        lda weLoc,x
        cmp #$ff
        beq e
        inx
        jsr ok
        bcc lp
        cmp #$20                 // spatie aan het begin overslaan
        bne st
        cpy #0
        beq lp
st:     sta weLoc,y
        iny
        jmp lp
e:      cpy #0                   // spaties aan het eind weg
        beq z
        lda weLoc-1,y
        cmp #$20
        bne z
        dey
        jmp e
z:      lda #$ff                 // rest leeg
f:      sta weLoc,y
        iny
        cpy #32
        bcc f
        rts
ok:     cmp #1                   // carry=1: toegestaan
        bcc no
        cmp #27
        bcc yes                  // A-Z
        cmp #$20
        beq yes
        cmp #$2c
        beq yes
        cmp #$2d
        beq yes
        cmp #$30
        bcc no
        cmp #$3a
        bcc yes                  // 0-9
no:     clc
        rts
yes:    sec
        rts
}

//--------------------------------------------------------
weF:     .byte 0                 // veld (we_Parse)
weN:     .byte 0                 // positie in het veld
weI:     .byte 0
weC:     .byte 0
weT:     .word 0
weNeed:  .byte 0                 // 1 = ophalen in we_Idle
weMinCnt: .byte 0                // minuten sinds het laatste ophalen
weLastMin: .byte 0
weEmpty: .byte 0
weLoc:   .fill 32, $ff           // plaats (schermcodes; leeg = AUTO), WEATHER.CFG
weUnit:  .byte 0                 // (byte 33 van WEATHER.CFG) 0 = C km/h, 1 = F mph
wePage:  .byte 0                 // 0 = nu, 1 = 3 dagen
weMode:  .byte 0                 // wat we_Fetch ophaalt (= wePage)
weBase:  .word 0                 // bron van we_CpShape
weUpd:   .text "--:--"
         .byte $ff
weMsg:   .word 0
weFLo:   .fill WE_NF, <[WE_BUF + i*WE_FL]
weFHi:   .fill WE_NF, >[WE_BUF + i*WE_FL]
// maximale lengte per veld: zo blijft alles binnen het venster
weFMax:  .byte 15, 4, 6, 6, 20, 10, 5, 7, 8, 5, 5, 5

// wat we_Draw tekent: tekst of veld, kolom, rij, accentkleur (1)
wiLo:    .byte <sWeLoc, <[WE_BUF+WF_LOC*WE_FL], <[WE_BUF+WF_TEMP*WE_FL], <sWeFeels
         .byte <[WE_BUF+WF_FEELS*WE_FL], <[WE_BUF+WF_COND*WE_FL], <sWeWind
         .byte <[WE_BUF+WF_WIND*WE_FL], <sWeHum, <[WE_BUF+WF_HUM*WE_FL], <sWeRain
         .byte <[WE_BUF+WF_RAIN*WE_FL], <sWePress, <[WE_BUF+WF_PRESS*WE_FL], <sWeRise
         .byte <[WE_BUF+WF_RISE*WE_FL], <sWeSet, <[WE_BUF+WF_SET*WE_FL], <sWeLocal
         .byte <[WE_BUF+WF_TIME*WE_FL], <sWeUpd, <weUpd
wiHi:    .byte >sWeLoc, >[WE_BUF+WF_LOC*WE_FL], >[WE_BUF+WF_TEMP*WE_FL], >sWeFeels
         .byte >[WE_BUF+WF_FEELS*WE_FL], >[WE_BUF+WF_COND*WE_FL], >sWeWind
         .byte >[WE_BUF+WF_WIND*WE_FL], >sWeHum, >[WE_BUF+WF_HUM*WE_FL], >sWeRain
         .byte >[WE_BUF+WF_RAIN*WE_FL], >sWePress, >[WE_BUF+WF_PRESS*WE_FL], >sWeRise
         .byte >[WE_BUF+WF_RISE*WE_FL], >sWeSet, >[WE_BUF+WF_SET*WE_FL], >sWeLocal
         .byte >[WE_BUF+WF_TIME*WE_FL], >sWeUpd, >weUpd
wiCol:   .byte WE_COL, 13, 17, 17, 28, 17, 17, 27, 17, 27, 17
         .byte 27, 17, 27, WE_COL, 11, 17, 24, WE_COL, 14, WE_COL, 11
wiRow:   .byte WE_R_LOC, WE_R_LOC, 7, 8, 8, 10, 12, 12, 13, 13, 14
         .byte 14, 15, 15, 19, 19, 19, 19, 20, 20, WE_R_UPD, WE_R_UPD
wiAcc:   .byte 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0
         .byte 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1
.assert "wi-tabellen even lang", wiRow - wiCol, WI_N

.encoding "screencode_upper"
sWeLoc:     .text "LOCATION"
            .byte $ff
sWeFeels:   .text "FEELS LIKE"
            .byte $ff
sWeWind:    .text "WIND"
            .byte $ff
sWeHum:     .text "HUMIDITY"
            .byte $ff
sWeRain:    .text "RAIN"
            .byte $ff
sWePress:   .text "PRESSURE"
            .byte $ff
sWeRise:    .text "SUNRISE"
            .byte $ff
sWeSet:     .text "SUNSET"
            .byte $ff
sWeLocal:   .text "LOCAL TIME"
            .byte $ff
sWeUpd:     .text "UPDATED"
            .byte $ff
sWeChange:  .text "CHANGE"
            .byte $ff
sWeRefresh: .text "REFRESH"
            .byte $ff
sWe3Days:   .text "3 DAYS"
            .byte $ff
sWeNow:     .text "NOW"
            .byte $ff
sWeMetric:  .text "C KM/H"
            .byte $ff
sWeUS:      .text "F MPH"
            .byte $ff
sWeAsk:     .text "TYPE A PLACE, RETURN (EMPTY=AUTO)"
            .byte $ff
sWeAuto:    .text "AUTO"
            .byte $ff
sWeNoTime:  .text "--:--"
// windpijl E2 86 90-99 -> waar de wind VANDAAN komt (2 tekens)
weDir:      .text "E S W N     SESWNWNE"
