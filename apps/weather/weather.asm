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
// Stap 3: nog zonder netwerk en sprites; REFRESH bladert door testregels
// in hetzelfde formaat (weT0-weT3).
//========================================================

.const WE_HELP  = 19             // F1-context (gui/help.txt)
.const WE_COL   = 3              // linkerkolom
.const WE_SKYR  = 5              // luchtvlak (plaatje): rij 5-15, kol 3-14
.const WE_SKYW  = 12
.const WE_SKYH  = 11
.const WE_R_LOC = 3              // LOCATION + CHANGE
.const WE_R_UPD = 20             // UPDATED + REFRESH
.const WE_R_MSG = 21             // meldingen
.const WE_C_CHG = 29             // CHANGE-knop
.const WE_W_CHG = 8
.const WE_C_REF = 27             // REFRESH-knop
.const WE_W_REF = 9
.const WE_NTEST = 4
.const WI_N     = 22             // regels in de wi-tabellen (we_Draw)
.label weS = r5                  // zeropage: bron (antwoord)
.label weD = r6                  // zeropage: doel (veld)

we_Init:
        lda #WE_HELP
        sta helpCtx
        lda #0
        sta weMsg+1
        sta weTest
        jmp we_TestLine

// we_Key - geen eigen toetsen (SPATIE/RETURN = klik op de cursor).
we_Key:
        clc
        rts

// we_TestLine - testregel weTest ontleden (zolang er geen netwerk is).
we_TestLine:
        ldx weTest
        lda weTLo,x
        sta weS
        lda weTHi,x
        sta weS+1
        jmp we_Parse

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
nb:     cmp #$80
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
        bne nx
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
        ldx #0                   // teksten en velden (tabel weI*)
lp:     stx weI
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
        inx
        cpx #WI_N
        bne lp
        lda #WE_COL              // luchtvlak (stap 4: sprites erin)
        sta a0
        lda #WE_SKYR
        sta a1
        lda #WE_SKYW
        sta a2
        lda #WE_SKYH
        sta a3
        lda #GL_SOLID
        sta a4
        lda #LIGHT_BLUE
        sta a5
        jsr gfx_FillRect
        lda #<sWeChange          // knoppen
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
        lda #<sWeLater           // (stap 6)
        sta weMsg
        lda #>sWeLater
        sta weMsg+1
        jmp we_ShowMsg
nc:     lda #WE_C_REF
        sta a0
        lda #WE_R_UPD
        sta a1
        lda #WE_W_REF
        sta a2
        jsr btn_HitTest
        bcc r
        ldx weTest               // stap 3: volgende testregel
        inx
        cpx #WE_NTEST
        bcc t
        ldx #0
t:      stx weTest
        jsr we_TestLine
        lda #0
        sta weMsg+1
        jmp shell_DrawAll
r:      rts
}

//--------------------------------------------------------
weF:     .byte 0                 // veld (we_Parse)
weN:     .byte 0                 // positie in het veld
weI:     .byte 0
weC:     .byte 0
weT:     .word 0
weTest:  .byte 0
weMsg:   .word 0
weFLo:   .fill WE_NF, <[WE_BUF + i*WE_FL]
weFHi:   .fill WE_NF, >[WE_BUF + i*WE_FL]
// maximale lengte per veld: zo blijft alles binnen het venster
weFMax:  .byte 15, 4, 6, 6, 20, 10, 5, 7, 8, 5, 5, 5
weTLo:   .byte <weT0, <weT1, <weT2, <weT3
weTHi:   .byte >weT0, >weT1, >weT2, >weT3

// wat we_Draw tekent: tekst of veld, kolom, rij, accentkleur (1)
wiLo:    .byte <sWeLoc, <[WE_BUF+WF_LOC*WE_FL], <[WE_BUF+WF_TEMP*WE_FL], <sWeFeels
         .byte <[WE_BUF+WF_FEELS*WE_FL], <[WE_BUF+WF_COND*WE_FL], <sWeWind
         .byte <[WE_BUF+WF_WIND*WE_FL], <sWeHum, <[WE_BUF+WF_HUM*WE_FL], <sWeRain
         .byte <[WE_BUF+WF_RAIN*WE_FL], <sWePress, <[WE_BUF+WF_PRESS*WE_FL], <sWeRise
         .byte <[WE_BUF+WF_RISE*WE_FL], <sWeSet, <[WE_BUF+WF_SET*WE_FL], <sWeLocal
         .byte <[WE_BUF+WF_TIME*WE_FL], <sWeUpd, <sWeTestData
wiHi:    .byte >sWeLoc, >[WE_BUF+WF_LOC*WE_FL], >[WE_BUF+WF_TEMP*WE_FL], >sWeFeels
         .byte >[WE_BUF+WF_FEELS*WE_FL], >[WE_BUF+WF_COND*WE_FL], >sWeWind
         .byte >[WE_BUF+WF_WIND*WE_FL], >sWeHum, >[WE_BUF+WF_HUM*WE_FL], >sWeRain
         .byte >[WE_BUF+WF_RAIN*WE_FL], >sWePress, >[WE_BUF+WF_PRESS*WE_FL], >sWeRise
         .byte >[WE_BUF+WF_RISE*WE_FL], >sWeSet, >[WE_BUF+WF_SET*WE_FL], >sWeLocal
         .byte >[WE_BUF+WF_TIME*WE_FL], >sWeUpd, >sWeTestData
wiCol:   .byte WE_COL, 13, 17, 17, 28, 17, 17, 27, 17, 27, 17
         .byte 27, 17, 27, WE_COL, 11, 17, 24, WE_COL, 14, WE_COL, 11
wiRow:   .byte WE_R_LOC, WE_R_LOC, 5, 6, 6, 8, 10, 10, 11, 11, 12
         .byte 12, 13, 13, 17, 17, 17, 17, 18, 18, WE_R_UPD, WE_R_UPD
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
sWeTestData: .text "TEST DATA"
            .byte $ff
sWeChange:  .text "CHANGE"
            .byte $ff
sWeRefresh: .text "REFRESH"
            .byte $ff
sWeLater:   .text "CHOOSING A PLACE COMES IN STEP 6"
            .byte $ff
// windpijl E2 86 90-99 -> waar de wind VANDAAN komt (2 tekens)
weDir:      .text "E S W N     SESWNWNE"
// testregels in het wttr.in-formaat (UTF-8, zoals de dienst ze stuurt),
// gemaakt met een Python-hulpje; REFRESH bladert erdoor (stap 3/4)
weT0:
        .byte $55,$74,$72,$65,$63,$68,$74,$7c,$6d,$7c,$2b,$31,$39,$c2,$b0,$43
        .byte $7c,$2b,$31,$38,$c2,$b0,$43,$7c,$50,$61,$72,$74,$6c,$79,$20,$63
        .byte $6c,$6f,$75,$64,$79,$7c,$e2,$86,$97,$36,$6b,$6d,$2f,$68,$7c,$36
        .byte $33,$25,$7c,$30,$2e,$30,$6d,$6d,$7c,$31,$30,$31,$36,$68,$50,$61
        .byte $7c,$30,$37,$3a,$35,$38,$3a,$31,$32,$7c,$31,$39,$3a,$30,$32,$3a
        .byte $34,$30,$7c,$31,$33,$3a,$34,$35,$3a,$31,$30,$2b,$30,$32,$30,$30
        .byte $00
weT1:
        .byte $41,$6d,$73,$74,$65,$72,$64,$61,$6d,$7c,$2f,$2f,$7c,$2b,$31,$32
        .byte $c2,$b0,$43,$7c,$2b,$39,$c2,$b0,$43,$7c,$48,$65,$61,$76,$79,$20
        .byte $72,$61,$69,$6e,$7c,$e2,$86,$90,$32,$34,$6b,$6d,$2f,$68,$7c,$39
        .byte $34,$25,$7c,$35,$2e,$32,$6d,$6d,$7c,$31,$30,$30,$34,$68,$50,$61
        .byte $7c,$30,$37,$3a,$35,$37,$3a,$30,$31,$7c,$31,$39,$3a,$30,$31,$3a
        .byte $31,$32,$7c,$32,$32,$3a,$31,$30,$3a,$30,$30,$2b,$30,$32,$30,$30
        .byte $00
weT2:
        .byte $4f,$73,$6c,$6f,$7c,$2a,$2a,$7c,$2d,$34,$c2,$b0,$43,$7c,$2d,$39
        .byte $c2,$b0,$43,$7c,$48,$65,$61,$76,$79,$20,$73,$6e,$6f,$77,$7c,$e2
        .byte $86,$93,$31,$38,$6b,$6d,$2f,$68,$7c,$38,$38,$25,$7c,$31,$2e,$34
        .byte $6d,$6d,$7c,$39,$39,$38,$68,$50,$61,$7c,$30,$38,$3a,$30,$35,$3a
        .byte $30,$30,$7c,$31,$38,$3a,$33,$30,$3a,$30,$30,$7c,$30,$39,$3a,$31
        .byte $35,$3a,$30,$30,$2b,$30,$32,$30,$30,$00
weT3:
        .byte $52,$6f,$6d,$65,$7c,$6f,$7c,$2b,$32,$37,$c2,$b0,$43,$7c,$2b,$32
        .byte $38,$c2,$b0,$43,$7c,$53,$75,$6e,$6e,$79,$7c,$e2,$86,$91,$33,$6b
        .byte $6d,$2f,$68,$7c,$34,$30,$25,$7c,$30,$2e,$30,$6d,$6d,$7c,$31,$30
        .byte $32,$30,$68,$50,$61,$7c,$30,$37,$3a,$31,$35,$3a,$30,$30,$7c,$31
        .byte $38,$3a,$35,$30,$3a,$30,$30,$7c,$31,$32,$3a,$30,$30,$3a,$30,$30
        .byte $2b,$30,$32,$30,$30,$00
