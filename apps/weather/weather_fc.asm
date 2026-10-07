#importonce
//========================================================
// apps/weather/weather_fc.asm - verwachting voor 3 dagen (WEATHER)
// Commodore Desk 64
//
// wttr.in /<plaats>?format=j1 geeft JSON (~40 KB). Die past nergens in,
// dus fc_Byte leest hem byte voor byte terwijl hij binnenkomt en houdt
// per dag (WE_FC) alleen over:
//   "date"                 -> nieuwe dag (0-2) en de weekdag
//   "maxtempC"/"maxtempF"  -> max (de eenheid van weUnit)
//   "mintempC"/"mintempF"  -> min
//   "chanceofrain"         -> de hoogste kans van de dag
//   "time": "1200"         -> het uur om 12:00: daarvan
//   "weatherCode"          ->   het weertype (tabel wcKey/wcType)
//   "value"                ->   en de omschrijving (weatherDesc)
// Alle waarden van wttr.in zijn teksten ("..."); een tekst gevolgd door :
// is een sleutel. Alles voor de eerste "date" (het weer van nu, de plaats)
// telt niet mee.
//
// Het scherm: drie kolommen (dag, plaatje, omschrijving, max, min, regen).
// Elk plaatje is een sprite-paar, alleen hoog vergroot (48 x 42), uit
// build/weather_mini.bin (tools/make_weather_sprites.py).
//========================================================
.const FC_COL0   = 3             // kolom van dag 0; dag 1 en 2 12 verder
.const FC_R_DAY  = 6
.const FC_R_SKY  = 7             // luchtvak 6 x 6 tekens, 2 kolommen ingesprongen
.const FC_R_DESC = 14            // 2 regels
.const FC_R_MAX  = 17
.const FC_R_MIN  = 18
.const FC_R_RAIN = 19
.const FC_SPRY   = 50 + FC_R_SKY*8 + 3
.const FC_LW     = 11            // tekens per regel in een kolom

// fc_Start - voor het ophalen: nog geen dagen, de lezer leeg.
fc_Start:
        lda #$ff
        sta fcDay
        lda #0
        sta fcN
        sta fcSt
        sta fcNoon
        sta fcWant
        rts

//--------------------------------------------------------
// fc_Byte - een byte (A) van de JSON, vanuit we_Rx.
//   fcSt: 0 buiten een tekst, 1 in een tekst, 2 na een tekst, 3 na \
//--------------------------------------------------------
fc_Byte: {
        ldx fcSt
        beq out
        dex
        beq str
        dex
        beq aft
        lda #1                   // het teken na \ overslaan
        sta fcSt
        rts
out:    cmp #$22                 // " = begin van een tekst
        bne r
        lda #0
        sta fcLen
        lda #1
        sta fcSt
r:      rts
str:    cmp #$22
        beq cl
        cmp #$5c
        beq es
        ldx fcLen
        cpx #31
        bcs r
        sta WE_STR,x
        inc fcLen
        rts
es:     lda #3
        sta fcSt
        rts
cl:     lda #2
        sta fcSt
        rts
aft:    cmp #$21                 // spaties en regeleinden overslaan
        bcc r
        ldx #0
        stx fcSt
        cmp #$3a                 // : -> het was een sleutel
        beq key
        jmp fc_Value             // anders een waarde
key:    ldx fcLen
        stx fcKLen
k:      dex
        bmi r
        lda WE_STR,x
        sta WE_KEY,x
        jmp k
}

// fc_Value - de waarde WE_STR bij sleutel WE_KEY verwerken.
fc_Value: {
        ldx #0                   // sleutel zoeken: fcKeys = lengte, tekst ...
        stx fcK
nx:     lda fcKeys,x
        beq r                    // 0 = einde: niet nodig
        cmp fcKLen
        bne sk
        stx fcT
        ldy #0
cp:     lda fcKeys+1,x
        cmp WE_KEY,y
        bne sk0
        inx
        iny
        cpy fcKLen
        bne cp
        lda fcK                  // gevonden
        beq go                   // "date" altijd
        lda fcDay                // de rest alleen binnen dag 0-2
        cmp #3
        bcs r
        lda fcK
go:     asl
        tax
        lda fcJmp+1,x
        pha
        lda fcJmp,x
        pha
r:      rts
sk0:    ldx fcT
sk:     txa                      // volgende: X + lengte + 1
        sec
        adc fcKeys,x
        tax
        inc fcK
        jmp nx
}
fcJmp:  .word fv_Date-1, fv_Max-1, fv_Max-1, fv_Min-1, fv_Min-1, fv_Rain-1
        .word fv_Time-1, fv_Code-1, fv_Desc-1

// "date": "2026-10-07" -> volgende dag, velden leeg, weekdag.
fv_Date: {
        inc fcDay
        lda fcDay
        cmp #3
        bcs r
        tax
        lda fcOffT,x
        sta fcOff
        tax
        lda #$ff
        sta WE_FC+FC_MAX,x
        sta WE_FC+FC_MIN,x
        sta WE_FC+FC_DESC,x
        lda #15                  // (nog) onbekend weer
        sta WE_FC+FC_TYPE,x
        lda #0
        sta WE_FC+FC_RAIN,x
        sta fcNoon
        sta fcWant
        // weekdag (2000-2099): (jj + jj/4 + maandtabel + dag) mod 7, 0 = zondag;
        // in januari en februari telt het jaar ervoor
        ldy #2
        jsr fcNum2
        sta fcY
        ldy #5
        jsr fcNum2
        sta fcM
        cmp #3
        bcs y
        dec fcY
y:      ldy #8
        jsr fcNum2
        clc
        adc fcY
        sta fcT
        lda fcY
        lsr
        lsr
        clc
        adc fcT
        ldx fcM
        clc
        adc fcMonT-1,x
m7:     cmp #7
        bcc st
        sbc #7
        bcs m7
st:     ldx fcOff
        sta WE_FC+FC_DOW,x
        inc fcN
r:      rts
}

// "maxtempC"/"maxtempF" (fcK 1/2) en "mintempC"/"mintempF" (3/4): alleen
// die in de gekozen eenheid.
fv_Max: lda fcK
        sec
        sbc #1
        cmp weUnit
        bne fvr
        lda #FC_MAX
        jmp fcTemp
fv_Min: lda fcK
        sec
        sbc #3
        cmp weUnit
        bne fvr
        lda #FC_MIN
fcTemp: clc                      // max. 4 tekens (cijfers en - zijn al
        adc fcOff                // schermcodes)
        tax
        ldy #0
tl:     cpy fcLen
        beq te
        cpy #4
        beq te
        lda WE_STR,y
        sta WE_FC,x
        inx
        iny
        bne tl
te:     lda #$ff
        sta WE_FC,x
fvr:    rts

// "chanceofrain": de hoogste van de dag bewaren.
fv_Rain: {
        ldy #0
        sty fcT
l:      cpy fcLen
        beq d
        lda fcT                  // x 10 + cijfer
        asl
        asl
        adc fcT
        asl
        sta fcT
        lda WE_STR,y
        and #$0f
        clc
        adc fcT
        sta fcT
        iny
        bne l
d:      ldx fcOff
        lda fcT
        cmp WE_FC+FC_RAIN,x
        bcc r
        sta WE_FC+FC_RAIN,x
r:      rts
}

// "time": alleen het uur "1200" geeft het weer van de dag.
fv_Time: {
        ldx #0
        lda fcLen
        cmp #4
        bne n
        ldy #3
l:      lda WE_STR,y
        cmp s1200,y
        bne n
        dey
        bpl l
        inx
n:      stx fcNoon
        rts
}

// "weatherCode" (om 12:00): code / 2 opzoeken in wcKey -> weertype.
fv_Code: {
        lda fcNoon
        beq r
        lda fcLen
        cmp #3
        bne r
        ldy #1                   // honderdtal x 50 + (rest / 2)
        jsr fcNum2
        lsr
        sta fcT
        lda WE_STR
        and #$0f
        tax
        lda fcT
h:      dex
        bmi k
        clc
        adc #50
        jmp h
k:      ldx #WC_N-1
l:      cmp wcKey,x
        beq hit
        dex
        bpl l
        lda #15                  // onbekende code: vraagteken
        bne st
hit:    lda wcType,x
st:     ldx fcOff
        sta WE_FC+FC_TYPE,x
        lda #1                   // de volgende "value" is de omschrijving
        sta fcWant
r:      rts
}

// "value" (na de weatherCode van 12:00): de omschrijving, max. 22 tekens.
fv_Desc: {
        lda fcWant
        beq r
        lda #0
        sta fcWant
        sta fcNoon
        lda fcOff
        clc
        adc #FC_DESC
        tax
        ldy #0
l:      cpy fcLen
        beq e
        cpy #22
        beq e
        lda WE_STR,y
        jsr we_Parse.asc
        sta WE_FC,x
        inx
        iny
        bne l
e:      lda #$ff
        sta WE_FC,x
r:      rts
}

// fcNum2 - twee ASCII-cijfers op WE_STR+Y -> A (0-99).
fcNum2: lda WE_STR,y
        and #$0f
        sta fcT2
        asl
        asl
        adc fcT2                 // x 5
        asl                      // x 10
        sta fcT2
        lda WE_STR+1,y
        and #$0f
        clc
        adc fcT2
        rts

//--------------------------------------------------------
// fc_Draw - de dagen: naam, luchtvak, omschrijving, max, min, regen.
//--------------------------------------------------------
fc_Draw: {
        lda #0
        sta fcD
dl:     lda fcD
        cmp fcN
        bcc go
        rts
go:     tax
        lda fcOffT,x
        sta fcOff
        lda fcColT,x
        sta fcCol
        lda #0
        sta fcO
        lda #<sFcToday           // dag 0 = TODAY, dan de weekdag
        ldy #>sFcToday
        cpx #0
        beq dn
        ldx fcOff
        ldy WE_FC+FC_DOW,x
        lda fcDayLo,y
        pha
        lda fcDayHi,y
        tay
        pla
dn:     sta r0
        sty r0+1
        lda fcCol
        sta a0
        lda #FC_R_DAY
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        lda fcCol                // luchtvak in de kleur van het weer
        clc
        adc #2
        sta a0
        lda #FC_R_SKY
        sta a1
        lda #6
        sta a2
        sta a3
        lda #GL_SOLID
        sta a4
        ldx fcOff
        ldy WE_FC+FC_TYPE,x
        lda wtSky,y
        sta a5
        jsr gfx_FillRect
        jsr fcDesc
        lda #<sFcMax             // MAX 22 C
        ldx #>sFcMax
        jsr fcCat
        lda fcOff
        clc
        adc #<[WE_FC+FC_MAX]
        ldx #>WE_FC
        jsr fcCat
        jsr fcUnit
        lda #FC_R_MAX
        jsr fcOut
        lda #<sFcMin             // MIN 13 C
        ldx #>sFcMin
        jsr fcCat
        lda fcOff
        clc
        adc #<[WE_FC+FC_MIN]
        ldx #>WE_FC
        jsr fcCat
        jsr fcUnit
        lda #FC_R_MIN
        jsr fcOut
        lda #<sFcRain            // RAIN 80%
        ldx #>sFcRain
        jsr fcCat
        ldx fcOff
        lda WE_FC+FC_RAIN,x
        jsr fcDec
        lda #$25
        jsr fcChr
        lda #FC_R_RAIN
        jsr fcOut
        inc fcD
        jmp dl
}

// fcDesc - de omschrijving op 2 regels van max. 11 tekens (afbreken op
//          de laatste spatie die nog past).
fcDesc: {
        ldx fcOff                // naar WE_STR (vrij na het ophalen)
        ldy #0
c:      lda WE_FC+FC_DESC,x
        sta WE_STR,y
        cmp #$ff
        beq e
        inx
        iny
        bne c
e:      sty fcT                  // lengte
        cpy #FC_LW+1
        bcc one
        ldy #FC_LW               // laatste spatie op 1-11
s:      lda WE_STR,y
        cmp #$20
        beq sp
        dey
        bne s
        ldy #FC_LW               // geen spatie: hard afbreken
        sty fcT
        bne two
sp:     sty fcT                  // regel 1 = 0..Y-1, regel 2 vanaf Y+1
        iny
two:    sty fcT2
        tya                      // regel 2 hoogstens 11 tekens
        clc
        adc #FC_LW
        tax
        lda #$ff
        sta WE_STR,x
one:    ldx fcT                  // regel 1
        lda WE_STR,x
        pha
        lda #$ff
        sta WE_STR,x
        lda #<WE_STR
        sta r0
        lda #>WE_STR
        sta r0+1
        lda #FC_R_DESC
        jsr dt
        pla
        ldx fcT
        sta WE_STR,x
        cmp #$ff
        beq r
        lda fcT2                 // regel 2
        clc
        adc #<WE_STR
        sta r0
        lda #>WE_STR
        sta r0+1
        lda #FC_R_DESC+1
dt:     sta a1
        lda fcCol
        sta a0
        lda TH_accent
        sta a2
        jmp gfx_DrawText
r:      rts
}

// fcCat - tekst A/X ($ff) achter WE_OUT (positie fcO).
fcCat: {
        sta weS
        stx weS+1
        ldy #0
l:      lda (weS),y
        cmp #$ff
        beq r
        jsr fcChr
        iny
        bne l
r:      rts
}
fcChr:  ldx fcO
        sta WE_OUT,x
        inc fcO
        rts
// fcUnit - " C" of " F".
fcUnit: lda #$20
        jsr fcChr
        lda #3                   // C
        ldx weUnit
        beq fcChr
        lda #6                   // F
        bne fcChr
// fcDec - A (0-100) als getal achter WE_OUT.
fcDec: {
        cmp #100
        bcc t
        lda #$31
        jsr fcChr
        lda #$30
        jsr fcChr
        lda #$30
        jmp fcChr
t:      ldy #$2f                 // tientallen
        sec
l:      iny
        sbc #10
        bcs l
        adc #$3a                 // eenheden als cijfer
        pha
        tya
        cmp #$30
        beq u
        jsr fcChr
u:      pla
        jmp fcChr
}
// fcOut - WE_OUT op rij A in de kolom van de dag, dan leeg.
fcOut:  sta a1
        ldx fcO
        lda #$ff
        sta WE_OUT,x
        lda #<WE_OUT
        sta r0
        lda #>WE_OUT
        sta r0+1
        lda fcCol
        sta a0
        lda TH_text
        sta a2
        lda #0
        sta fcO
        jmp gfx_DrawText

//--------------------------------------------------------
// fc_SprShow - de plaatjes van de dagen: dag d = sprites 2d+1 en 2d+2,
//              48 pixels breed (niet breed vergroot), 42 hoog.
//--------------------------------------------------------
fc_SprShow: {
        jsr we_SprSave
        lda #<weMiniData
        sta weBase
        lda #>weMiniData
        sta weBase+1
        lda #0
        sta weSlot
        sta weMask
        sta fcD
l:      lda fcD
        cmp fcN
        bcs reg
        tax
        ldy fcOffT,x
        ldx WE_FC+FC_TYPE,y
        lda wtMini,x
        sta fcT
        jsr we_CpShape           // A = blok van de linker sprite
        pha
        lda fcD
        asl
        tay
        iny                      // Y = linker sprite (1, 3, 5)
        pla
        sta $07f8,y
        clc
        adc #1
        sta $07f9,y
        ldx fcT
        lda wmColL,x
        sta $d027,y
        lda wmColR,x
        sta $d028,y
        lda bitTab,y
        ora bitTab+1,y
        ora weMask
        sta weMask
        tya
        asl
        tay
        ldx fcD
        lda fcSprX,x
        sta $d000,y
        clc
        adc #24
        sta $d002,y
        lda #FC_SPRY
        sta $d001,y
        sta $d003,y
        inc fcD
        jmp l
reg:    lda $d010                // dag 2 staat voorbij x = 255
        and #1
        ldx fcN
        cpx #3
        bcc m
        ora #$60
m:      sta $d010
        lda $d01b
        and #1
        sta $d01b
        lda $d01c
        and #1
        ora weMask
        sta $d01c
        lda $d017                // alleen hoog vergroot
        and #1
        ora weMask
        sta $d017
        lda $d01d
        and #1
        sta $d01d
        lda #WHITE
        sta $d025
        lda #LIGHT_GREY
        sta $d026
        lda $d015
        and #1
        ora weMask
        sta $d015
        rts
}

//--------------------------------------------------------
fcSt:    .byte 0
fcLen:   .byte 0
fcKLen:  .byte 0
fcK:     .byte 0
fcT:     .byte 0
fcT2:    .byte 0
fcY:     .byte 0
fcM:     .byte 0
fcDay:   .byte $ff               // dag die nu binnenkomt ($ff = nog geen)
fcN:     .byte 0                 // dagen met gegevens (0 = geen verwachting)
fcOff:   .byte 0
fcNoon:  .byte 0
fcWant:  .byte 0
fcD:     .byte 0
fcCol:   .byte 0
fcO:     .byte 0
fcOffT:  .byte 0, FC_DL, 2*FC_DL
fcColT:  .byte FC_COL0, FC_COL0+12, FC_COL0+24
fcSprX:  .byte <[24+(FC_COL0+2)*8], <[24+(FC_COL0+14)*8], <[24+(FC_COL0+26)*8]
fcMonT:  .byte 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4
.encoding "ascii"
fcKeys:  .byte 4
         .text "date"
         .byte 8
         .text "maxtempC"
         .byte 8
         .text "maxtempF"
         .byte 8
         .text "mintempC"
         .byte 8
         .text "mintempF"
         .byte 12
         .text "chanceofrain"
         .byte 4
         .text "time"
         .byte 11
         .text "weatherCode"
         .byte 5
         .text "value"
         .byte 0
s1200:   .text "1200"
.encoding "screencode_upper"
fcUpd:   .text "--:--"
         .byte $ff
sFcToday: .text "TODAY"
         .byte $ff
sFcMax:  .text "MAX "
         .byte $ff
sFcMin:  .text "MIN "
         .byte $ff
sFcRain: .text "RAIN "
         .byte $ff
fcD0:    .text "SUNDAY"
         .byte $ff
fcD1:    .text "MONDAY"
         .byte $ff
fcD2:    .text "TUESDAY"
         .byte $ff
fcD3:    .text "WEDNESDAY"
         .byte $ff
fcD4:    .text "THURSDAY"
         .byte $ff
fcD5:    .text "FRIDAY"
         .byte $ff
fcD6:    .text "SATURDAY"
         .byte $ff
fcDayLo: .byte <fcD0, <fcD1, <fcD2, <fcD3, <fcD4, <fcD5, <fcD6
fcDayHi: .byte >fcD0, >fcD1, >fcD2, >fcD3, >fcD4, >fcD5, >fcD6
