#importonce
//========================================================
// apps/email/mail_cfg.asm - MAIL.CFG + het scherm EMAIL SETTINGS
// Commodore Desk 64
//
// Alle instellingen om mail op te halen (POP3) en te versturen (SMTP),
// zonder SSL/TLS. MAIL.CFG wordt met secundair adres 0 geladen, dus
// naar mcData in deze overlay, wat het laadadres in het bestand ook is.
// Het wachtwoord staat leesbaar in MAIL.CFG (geen TLS, geen versleuteling)
// en wordt op het scherm als sterretjes getoond.
//========================================================

.const MC_VERSION = 1
.const SET_VCOL   = 14           // waardekolom
.const SET_VIS    = 24           // zichtbare breedte (kol 14-37)
.const SET_N      = 9            // aantal velden
.const SET_SAVE_ROW = 19

// mc_Load - MAIL.CFG laden (eenmaal per overlay-lading); anders defaults.
mc_Load: {
        lda mcLoaded
        bne done
        lda #1
        sta mcLoaded
        jsr cfg_io_begin
        lda #[nEnd-nm]
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #0                   // sa=0: naar het adres in X/Y
        jsr K_SETLFS
        lda #0
        ldx #<mcData
        ldy #>mcData
        jsr K_LOAD
        php
        stx mcTmp
        sty mcTmp+1
        jsr cfg_io_end
        plp
        bcs dflt
        lda mcTmp                // precies zo lang als deze versie?
        cmp #<mcEnd
        bne dflt
        lda mcTmp+1
        cmp #>mcEnd
        bne dflt
        lda mcMagic
        cmp #$4d
        bne dflt
        lda mcMagic+1
        cmp #$43
        bne dflt
        lda mcVer
        cmp #MC_VERSION
        beq done
dflt:   jmp mc_Default
done:   rts
nm:     .encoding "petscii_upper"
        .text "MAIL.CFG"
nEnd:   .encoding "screencode_upper"
}

// mc_Default - lege velden, standaardpoorten (110 / 587) en tijdzone.
mc_Default: {
        ldx #0
        lda #$ff
cl:     sta mcData,x
        inx
        cpx #[mcEnd-mcData]
        bne cl
        lda #$4d
        sta mcMagic
        lda #$43
        sta mcMagic+1
        lda #MC_VERSION
        sta mcVer
        ldx #3
p:      lda d110,x
        sta mcPopP,x
        lda d587,x
        sta mcSmtP,x
        dex
        bpl p
        ldx #5
t:      lda dTz,x
        sta mcTz,x
        dex
        bpl t
        rts
d110:   .text "110"
        .byte $ff
d587:   .text "587"
        .byte $ff
dTz:    .text "+0200"
        .byte $ff
}

// mc_Save - "@0:MAIL.CFG". Carry=1 bij een fout.
mc_Save: {
        jsr save_Begin           // "SETTINGS ARE BEING SAVED"
        jsr cfg_io_begin
        lda #[nEnd-nm]
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #0
        ldx #8
        ldy #0
        jsr K_SETLFS
        lda #<mcData
        sta $fb
        lda #>mcData
        sta $fc
        lda #$fb
        ldx #<mcEnd
        ldy #>mcEnd
        jsr K_SAVE
        php
        jsr cfg_io_end
        plp
        jmp save_End             // scherm terug (carry blijft)
nm:     .encoding "petscii_upper"
        .text "@0:MAIL.CFG"
nEnd:   .encoding "screencode_upper"
}

//--------------------------------------------------------
// Scherm EMAIL SETTINGS
//--------------------------------------------------------
set_Draw: {
        lda #<sSetTitle
        ldy #>sSetTitle
        ldx #2
        jsr em_TextAcc
        ldx #0
lp:     stx mcI
        lda fLblLo,x
        ldy fLblHi,x
        pha
        lda fRow,x
        tax
        pla
        jsr em_Text
        ldx mcI
        jsr set_Field
        lda #0
        sta leOn
        jsr le_Show
        ldx mcI
        inx
        cpx #SET_N
        bne lp
        lda #<sSave
        sta r0
        lda #>sSave
        sta r0+1
        lda #2
        sta a0
        lda #SET_SAVE_ROW
        sta a1
        lda #8
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sSetHint
        ldy #>sSetHint
        ldx #SET_SAVE_ROW+2
        jsr em_Text
        jmp em_ShowMsg
}

// set_Field - le_*-parameters voor veld X.
set_Field:
        lda fBufLo,x
        sta r3
        lda fBufHi,x
        sta r3+1
        lda fMax,x
        sta leMax
        lda fRow,x
        sta leRow
        lda fMask,x
        sta leMask
        lda #SET_VCOL
        sta leCol
        lda #SET_VIS
        sta leVis
        rts

set_Click: {
        lda #2                   // SAVE
        sta a0
        lda #SET_SAVE_ROW
        sta a1
        lda #8
        sta a2
        jsr btn_HitTest
        bcs save
        ldx #0
lp:     lda fRow,x
        cmp evtB
        beq hit
        inx
        cpx #SET_N
        bne lp
        rts
hit:    jsr set_Field
        lda #0
        sta emMsg+1
        jsr le_Edit
        bcc done
        jmp set_Click            // klik tijdens het bewerken: verwerken
done:   rts
save:   jsr mc_Save
        ldx #<sSaved
        ldy #>sSaved
        bcc sv
        ldx #<sSaveErr
        ldy #>sSaveErr
sv:     jmp em_SetMsg
}

//--------------------------------------------------------
// le_Edit - één regel bewerken (tekst achteraan erbij / DEL eraf).
//   In: r3 = buffer (schermcodes, $ff), leMax, leCol, leRow, leVis,
//       leMask (1 = sterretjes). Toetsenbord in de ruwe modus, zodat
//       @ en _ te typen zijn. RETURN / RUN/STOP / F7 = klaar.
//   Uit: carry=1 -> klaar door een muisklik (evtA/evtB) die de beller
//        nog moet verwerken.
//--------------------------------------------------------
le_Edit: {
        lda #1
        sta kbRaw
        sta leOn
        jsr le_Show
lp:     jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        beq ms
        cmp #EVT_KEY
        bne lp
        lda evtA
        cmp #KEY_RETURN
        beq end
        cmp #KEY_STOP
        beq end
        cmp #KEY_F7
        beq end
        cmp #KEY_DEL
        beq del
        jsr key_Sc
        bcc lp
        pha
        jsr le_Len
        pla
        cpy leMax
        bcs lp
        sta (r3),y
        iny
        lda #$ff
        sta (r3),y
        jsr le_Show
        jmp lp
del:    jsr le_Len
        cpy #0
        beq lp
        dey
        lda #$ff
        sta (r3),y
        jsr le_Show
        jmp lp
ms:     jsr off
        sec
        rts
end:    jsr off
        clc
        rts
off:    lda #0
        sta kbRaw
        sta leOn
        jmp le_Show
}

// le_Len - Y = lengte van de tekst in (r3).
le_Len:
        ldy #0
!:      lda (r3),y
        cmp #$ff
        beq !+
        iny
        cpy #64
        bne !-
!:      rts

// le_Show - veld tekenen; tijdens het bewerken het einde + cursor.
le_Show: {
        jsr le_Len
        sty leL
        lda #0
        sta leS
        lda leOn
        beq st
        lda leL
        sec
        sbc leVis
        bcc st
        adc #0                   // (carry=1) +1: plaats voor de cursor
        sta leS
st:     ldx #0
lp:     stx leI
        txa
        clc
        adc leS
        tay
        lda #$20
        cpy leL
        bcs sp
        lda (r3),y
        jsr em_Disp
        ldx leMask
        beq ch
        lda #$2a                 // *
        jmp ch
sp:     ldx leOn                 // cursor achter de tekst
        beq ch
        cpy leL
        bne ch
        lda #GL_SOLID
ch:     sta a2
        lda leI
        clc
        adc leCol
        sta a0
        lda leRow
        sta a1
        lda TH_text
        ldx leOn
        beq c
        lda TH_accent
c:      sta a3
        jsr gfx_PutChar
        ldx leI
        inx
        cpx leVis
        bne lp
        rts
}

// key_Sc - toets (evtA) -> schermcode voor tekstinvoer. Carry=1 geldig.
key_Sc: {
        cmp #KEY_AT
        bne k1
        lda #$00
        sec
        rts
k1:     cmp #KEY_LARROW          // _
        bne k2
        lda #$64
        sec
        rts
k2:     cmp #$80
        bcs no
        cmp #$1c
        beq no
        cmp #$1e                 // letters, [ ]
        bcc ok
        cmp #$20
        bcc no
        cmp #$40                 // spatie, cijfers, leestekens
        bcc ok
        beq no
        cmp #$5b                 // SHIFT + letter
        bcc ok
no:     clc
        rts
ok:     sec
        rts
}

//--------------------------------------------------------
// Configuratie (MAIL.CFG = mcData .. mcEnd)
//--------------------------------------------------------
mcLoaded: .byte 0
mcI:      .byte 0
mcTmp:    .word 0
leMax:    .byte 0
leCol:    .byte 0
leRow:    .byte 0
leVis:    .byte 0
leMask:   .byte 0
leOn:     .byte 0
leL:      .byte 0
leS:      .byte 0
leI:      .byte 0

mcData:
mcMagic:  .byte $4d, $43         // "MC"
mcVer:    .byte MC_VERSION
mcName:   .fill 25, $ff          // naam van de afzender (max 24)
mcAddr:   .fill 41, $ff          // e-mailadres (max 40)
mcPopH:   .fill 33, $ff          // POP3-server
mcPopP:   .fill 6, $ff           // POP3-poort (110)
mcSmtH:   .fill 33, $ff          // SMTP-server (leeg = POP3-server)
mcSmtP:   .fill 6, $ff           // SMTP-poort (587)
mcUser:   .fill 41, $ff          // gebruikersnaam (leeg = e-mailadres)
mcPass:   .fill 33, $ff          // wachtwoord
mcTz:     .fill 6, $ff           // tijdzone voor de Date-header (+0200)
mcEnd:

fRow:   .byte 4, 5, 7, 8, 10, 11, 13, 14, 16
fMax:   .byte 24, 40, 32, 5, 32, 5, 40, 32, 5
fMask:  .byte 0, 0, 0, 0, 0, 0, 0, 1, 0
fBufLo: .byte <mcName, <mcAddr, <mcPopH, <mcPopP, <mcSmtH, <mcSmtP, <mcUser, <mcPass, <mcTz
fBufHi: .byte >mcName, >mcAddr, >mcPopH, >mcPopP, >mcSmtH, >mcSmtP, >mcUser, >mcPass, >mcTz
fLblLo: .byte <lName, <lAddr, <lPopH, <lPopP, <lSmtH, <lSmtP, <lUser, <lPass, <lTz
fLblHi: .byte >lName, >lAddr, >lPopH, >lPopP, >lSmtH, >lSmtP, >lUser, >lPass, >lTz

.encoding "screencode_upper"
sSetTitle: .text "MAILBOX (POP3/SMTP, NO SSL/TLS)"
           .byte $ff
lName:  .text "YOUR NAME"
        .byte $ff
lAddr:  .text "EMAIL ADDR"
        .byte $ff
lPopH:  .text "POP3 SERVER"
        .byte $ff
lPopP:  .text "POP3 PORT"
        .byte $ff
lSmtH:  .text "SMTP SERVER"
        .byte $ff
lSmtP:  .text "SMTP PORT"
        .byte $ff
lUser:  .text "USER NAME"
        .byte $ff
lPass:  .text "PASSWORD"
        .byte $ff
lTz:    .text "TIME ZONE"
        .byte $ff
sSave:  .text "SAVE"
        .byte $ff
sSetHint: .text "CLICK A FIELD TO CHANGE IT"
        .byte $ff
sSaved: .text "SAVED IN MAIL.CFG"
        .byte $ff
sSaveErr: .text "COULD NOT SAVE MAIL.CFG"
        .byte $ff
