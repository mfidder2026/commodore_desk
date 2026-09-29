#importonce
//========================================================
// apps/email/mail_ui.asm - schermen van EMAIL
// Commodore Desk 64
//
//   postvak  FETCH / NEW, lijst van de nieuwste berichten
//            (klik = lezen); toetsen F = fetch, N = new. De instellingen
//            zijn alleen via SYSTEM -> EMAIL te bereiken (zoals overal).
//   lezen    afzender, onderwerp, datum, tekst; UP/DOWN/REPLY/BACK
//            (SPATIE = volgende bladzijde, - = vorige, R = reply)
//   opstellen TO, SUBJ en de tekst (klik om te typen); SEND / CANCEL.
//            In de tekst: cursortoetsen, RETURN, DEL, CLR/HOME.
// EMAIL SETTINGS (app 10) staat in mail_cfg.asm.
//========================================================

.const SC_INBOX = 0
.const SC_READ  = 1
.const SC_COMP  = 2
.const IN_TOP   = 4              // eerste rij van de lijst
.const IN_ROWS  = 18
.const IN_SUBJ  = 15             // kolom van het onderwerp
.const IN_BTNS  = 2              // FETCH, NEW
.const RD_BTN   = 21
.const CP_BTN   = 20
.const CP_FCOL  = 8              // kolom van de TO/SUBJ-velden

em_Init:
        jsr nc_Load              // netwerk (NET.CFG) + hardware
        jsr net_Detect
        jsr mc_Load
        lda #0
        sta emMsg+1
        rts

em_Draw: {
        ldx emScreen             // F1-context: lezen 15, opstellen 16
        lda emHelp,x
        ldx activeApp
        cpx #EM_APP_SET
        bne !+
        lda #0
!:      sta helpCtx
        lda activeApp
        cmp #EM_APP_SET
        bne m
        jmp set_Draw
m:      lda emScreen
        bne m1
        jmp in_Draw
m1:     cmp #SC_READ
        bne m2
        jmp rd_Draw
m2:     jmp cp_Draw
}

em_Click: {
        lda activeApp
        cmp #EM_APP_SET
        bne m
        jmp set_Click
m:      lda emScreen
        bne m1
        jmp in_Click
m1:     cmp #SC_READ
        bne m2
        jmp rd_Click
m2:     jmp cp_Click
}

// em_Key - toets in EMAIL (carry=1 = afgehandeld).
em_Key: {
        ldx activeApp
        cpx #EM_APP_SET
        beq no
        ldx emScreen
        bne k1
        cmp #$06                 // F
        bne k0
        jmp in_Fetch
k0:     cmp #$0e                 // N
        bne no
        jmp cp_New
k1:     cpx #SC_READ
        bne no
        cmp #$20                 // SPATIE = verder
        bne k2
        jmp rd_Down
k2:     cmp #$2d                 // - = terug
        bne k3
        jmp rd_Up
k3:     cmp #$12                 // R = reply
        bne no
        jmp rd_Reply
no:     clc
        rts
}

//--------------------------------------------------------
// Postvak
//--------------------------------------------------------
in_Draw: {
        ldx #0
bl:     stx emI
        lda inBtnLo,x
        sta r0
        lda inBtnHi,x
        sta r0+1
        lda inBtnCol,x
        sta a0
        lda #2
        sta a1
        lda inBtnW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx emI
        inx
        cpx #IN_BTNS
        bne bl
        lda mbCount
        bne list
        lda #<sInEmpty
        ldy #>sInEmpty
        ldx #IN_TOP+1
        jsr em_Text
        jmp em_ShowMsg
list:   lda #<sInFrom
        ldy #>sInFrom
        ldx #IN_TOP-1
        jsr em_TextAcc
        lda #<sInSubj
        sta r0
        lda #>sInSubj
        sta r0+1
        lda #IN_SUBJ
        sta a0
        lda #IN_TOP-1
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        lda #0
        sta mbSel
rl:     jsr mb_Ptr
        lda mbSel
        clc
        adc #IN_TOP
        sta emRow
        lda r3                   // afzender (12 tekens)
        clc
        adc #MB_FROM
        sta r6
        lda r3+1
        adc #0
        sta r6+1
        lda #2
        ldx #12
        jsr em_TextW
        jsr mb_Ptr
        lda r3                   // onderwerp (23 tekens)
        clc
        adc #MB_SUBJ
        sta r6
        lda r3+1
        adc #0
        sta r6+1
        ldy #0
        lda (r6),y
        cmp #$ff
        bne sj
        lda #<sNoSubj
        sta r6
        lda #>sNoSubj
        sta r6+1
sj:     lda #IN_SUBJ
        ldx #23
        jsr em_TextW
        inc mbSel
        lda mbSel
        cmp mbCount
        bcc rl
        jmp em_ShowMsg
}

in_Click: {
        ldx #0
bl:     stx emI
        lda inBtnCol,x
        sta a0
        lda #2
        sta a1
        lda inBtnW,x
        sta a2
        jsr btn_HitTest
        bcs hit
        ldx emI
        inx
        cpx #IN_BTNS
        bne bl
        lda evtB                 // op een bericht?
        sec
        sbc #IN_TOP
        bcc r
        cmp mbCount
        bcs r
        sta mbSel
        jsr pp_Read
        bcc err
        lda #SC_READ
        sta emScreen
        lda #0
        sta emMsg+1
        jmp shell_DrawAll
err:    jmp em_Error
hit:    lda emI
        beq in_Fetch
        jmp cp_New               // (instellingen: alleen via SYSTEM -> EMAIL)
r:      rts
}

in_Fetch: {
        lda #SC_INBOX
        sta emScreen
        jsr pp_Fetch
        bcc err
        lda mbTotal              // "25 MESSAGES ON THE SERVER"
        sta emNum
        lda mbTotal+1
        sta emNum+1
        jsr em_NumMsg
        jsr shell_DrawAll
        sec
        rts
err:    jsr em_Error
        sec
        rts
}

// em_Error - melding X/Y tonen en alles opnieuw tekenen.
em_Error:
        stx emMsg
        sty emMsg+1
        jmp shell_DrawAll

//--------------------------------------------------------
// Lezen
//--------------------------------------------------------
rd_Draw: {
        lda #<sRdFrom
        ldy #>sRdFrom
        ldx #2
        jsr em_TextAcc
        lda #<sRdSubj
        ldy #>sRdSubj
        ldx #3
        jsr em_TextAcc
        lda #<sRdDate
        ldy #>sRdDate
        ldx #4
        jsr em_TextAcc
        lda #2
        sta emRow
        lda #<rdFrom
        sta r6
        lda #>rdFrom
        sta r6+1
        lda #CP_FCOL
        ldx #30
        jsr em_TextW
        inc emRow
        lda #<rdSubj
        sta r6
        lda #>rdSubj
        sta r6+1
        lda #CP_FCOL
        ldx #30
        jsr em_TextW
        inc emRow
        lda #<rdDate
        sta r6
        lda #>rdDate
        sta r6+1
        lda #CP_FCOL
        ldx #30
        jsr em_TextW
        lda #5
        jsr em_Rule
        lda #0
        sta emI
ll:     lda emI
        clc
        adc rdTop
        cmp rdLines
        bcs done
        tax
        lda msLo,x
        sta r6
        lda msHi,x
        sta r6+1
        lda emI
        clc
        adc #RD_TOP
        jsr em_Row36
        inc emI
        lda emI
        cmp #RD_VIS
        bcc ll
done:   ldx #0
bl:     stx emI
        lda rdBtnLo,x
        sta r0
        lda rdBtnHi,x
        sta r0+1
        lda rdBtnCol,x
        sta a0
        lda #RD_BTN
        sta a1
        lda rdBtnW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx emI
        inx
        cpx #4
        bne bl
        lda emMsg+1
        beq pos
        jmp em_ShowMsg
pos:    lda rdLines              // "LINE 1 OF 40"
        bne p1
        lda #<sRdEmpty
        ldy #>sRdEmpty
        ldx #EM_MSG_ROW
        jmp em_Text
p1:     jmp rd_Pos
}

// rd_Pos - "LINE x OF y" op de meldingsregel.
rd_Pos: {
        lda #0
        sta emNum+1
        ldx rdTop
        inx
        stx emNum
        jsr em_NumStart          // "x"
        ldx #<sOf
        ldy #>sOf
        jsr em_MsgStr
        lda rdLines
        sta emNum
        jsr em_NumAdd
        lda #<sLine
        ldy #>sLine
        ldx #EM_MSG_ROW
        jsr em_Text
        lda #<emMsgBuf
        sta r0
        lda #>emMsgBuf
        sta r0+1
        lda #7
        sta a0
        lda #EM_MSG_ROW
        sta a1
        lda TH_text
        sta a2
        jmp gfx_DrawText
}

rd_Click: {
        ldx #0
bl:     stx emI
        lda rdBtnCol,x
        sta a0
        lda #RD_BTN
        sta a1
        lda rdBtnW,x
        sta a2
        jsr btn_HitTest
        bcs hit
        ldx emI
        inx
        cpx #4
        bne bl
        rts
hit:    lda emI
        bne h1
        jmp rd_Up
h1:     cmp #1
        bne h2
        jmp rd_Down
h2:     cmp #2
        bne h3
        jmp rd_Reply
h3:     lda #SC_INBOX            // BACK
        sta emScreen
        jmp shell_DrawAll
}

rd_Down: {
        lda rdTop
        clc
        adc #RD_VIS
        cmp rdLines
        bcs r
        sta rdTop
        jsr shell_DrawAll
r:      sec
        rts
}

rd_Up: {
        lda rdTop
        sec
        sbc #RD_VIS
        bcs s
        lda #0
s:      sta rdTop
        jsr shell_DrawAll
        sec
        rts
}

// rd_Reply - antwoord: TO = afzender, SUBJ = "RE: ...", tekst geciteerd.
rd_Reply: {
        jsr cp_Clear
        ldx #0                   // TO = adres (ASCII -> schermcode)
        ldy #0
ta:     lda rdAddr,x
        beq te
        stx emI
        jsr a2sc
        sta cpTo,y
        ldx emI
        inx
        iny
        cpy #40
        bcc ta
te:     lda #$ff
        sta cpTo,y
        ldx #0                   // SUBJ = "RE: " + onderwerp
        lda rdSubj
        cmp #$12                 // R
        bne re
        lda rdSubj+1
        cmp #$05                 // E
        bne re
        lda rdSubj+2
        cmp #$3a                 // :
        beq sc
re:     lda sRe,x
        sta cpSubj,x
        inx
        cpx #4
        bne re
sc:     ldy #0
sl:     lda rdSubj,y
        cmp #$ff
        beq se
        sta cpSubj,x
        inx
        iny
        cpx #40
        bcc sl
se:     lda #$ff
        sta cpSubj,x
        lda #0                   // tekst: regel 0 leeg, dan "> " + bericht
        sta emI
ql:     lda emI
        cmp rdLines
        bcs qd
        cmp #CP_LINES-2
        bcs qd
        tax
        lda msLo,x
        sta r3
        lda msHi,x
        sta r3+1
        txa
        clc
        adc #2
        jsr cp_Ptr               // r6 = opstelregel
        ldy #0
        lda #$3e                 // >
        sta (r6),y
        iny
        lda #$20
        sta (r6),y
        ldy #0
qc:     lda (r3),y
        iny
        iny
        sta (r6),y
        dey
        cpy #CP_W-2
        bcc qc
        inc emI
        jmp ql
qd:     lda #SC_COMP
        sta emScreen
        lda #0
        sta emMsg+1
        jsr shell_DrawAll
        sec
        rts
}

//--------------------------------------------------------
// Opstellen
//--------------------------------------------------------
cp_New: {
        jsr cp_Clear
        lda #SC_COMP
        sta emScreen
        lda #0
        sta emMsg+1
        jsr shell_DrawAll
        sec
        rts
}

// cp_Clear - leeg bericht, cursor linksboven.
cp_Clear: {
        lda #$ff
        sta cpTo
        sta cpSubj
        lda #0
        sta cpX
        sta cpY
        sta cpTop
        sta emI
lp:     lda emI
        jsr cp_Ptr
        ldy #CP_W-1
        lda #$20
cl:     sta (r6),y
        dey
        bpl cl
        inc emI
        lda emI
        cmp #CP_LINES
        bcc lp
        rts
}

// cp_Ptr - r6 = opstelregel A.
cp_Ptr:
        tax
        lda cpLo,x
        sta r6
        lda cpHi,x
        sta r6+1
        rts

// cp_Line - r6 = opstelregel A, Y = lengte zonder spaties achteraan.
cp_Line: {
        jsr cp_Ptr
        ldy #CP_W
lp:     dey
        bmi z
        lda (r6),y
        cmp #$20
        beq lp
        iny
        rts
z:      ldy #0
        rts
}

cp_Draw: {
        lda #<sCpTo
        ldy #>sCpTo
        ldx #2
        jsr em_TextAcc
        lda #<sCpSubj
        ldy #>sCpSubj
        ldx #3
        jsr em_TextAcc
        jsr cp_FieldTo
        jsr le_Show
        jsr cp_FieldSubj
        jsr le_Show
        lda #4
        jsr em_Rule
        jsr cp_Lines
        lda #<sSend
        sta r0
        lda #>sSend
        sta r0+1
        lda #2
        sta a0
        lda #CP_BTN
        sta a1
        lda #6
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sCancel
        sta r0
        lda #>sCancel
        sta r0+1
        lda #10
        sta a0
        lda #CP_BTN
        sta a1
        lda #8
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        lda #<sCpHint
        ldy #>sCpHint
        ldx #CP_BTN+1
        jsr em_Text
        jmp em_ShowMsg
}

// cp_Lines - zichtbare tekstregels tekenen.
cp_Lines: {
        lda #0
        sta emI
lp:     lda emI
        clc
        adc cpTop
        jsr cp_Ptr
        lda emI
        clc
        adc #CP_TOP
        jsr em_Row36
        inc emI
        lda emI
        cmp #CP_VIS
        bcc lp
        rts
}

cp_FieldTo:
        lda #<cpTo
        sta r3
        lda #>cpTo
        sta r3+1
        lda #2
        bne cpF
cp_FieldSubj:
        lda #<cpSubj
        sta r3
        lda #>cpSubj
        sta r3+1
        lda #3
cpF:    sta leRow
        lda #40
        sta leMax
        lda #CP_FCOL
        sta leCol
        lda #30
        sta leVis
        lda #0
        sta leMask
        sta leOn
        rts

cp_Click: {
        lda #2                   // SEND
        sta a0
        lda #CP_BTN
        sta a1
        lda #6
        sta a2
        jsr btn_HitTest
        bcs send
        lda #10                  // CANCEL
        sta a0
        lda #8
        sta a2
        jsr btn_HitTest
        bcs cancel
        lda evtB
        cmp #2
        bne c3
        jsr cp_FieldTo
        jmp ed
c3:     cmp #3
        bne c4
        jsr cp_FieldSubj
ed:     lda #0
        sta emMsg+1
        jsr le_Edit
        bcc r
        jmp cp_Click             // klik tijdens het typen: verwerken
c4:     sec                      // in de tekst?
        sbc #CP_TOP
        bcc r
        cmp #CP_VIS
        bcs r
        clc
        adc cpTop
        sta cpY
        lda evtA
        sec
        sbc #2
        bcc r
        cmp #CP_W
        bcs r
        sta cpX
        jsr be_Edit
        bcc r
        jmp cp_Click
r:      rts
cancel: lda #SC_INBOX
        sta emScreen
        lda #0
        sta emMsg+1
        jmp shell_DrawAll
send:   lda cpTo
        cmp #$ff
        bne s1
        ldx #<sNoTo
        ldy #>sNoTo
        jmp em_Error
s1:     jsr sm_Send
        bcc err
        lda #SC_INBOX
        sta emScreen
        ldx #<sSent
        ldy #>sSent
err:    jmp em_Error
}

//--------------------------------------------------------
// be_Edit - de tekst bewerken (modale lus, ruwe toetsenbordmodus).
//           Carry=1: klaar door een muisklik (nog te verwerken).
//--------------------------------------------------------
be_Edit: {
        lda #1
        sta kbRaw
lp:     jsr be_Show
wt:     jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        bne fb4324_8
        jmp ms
fb4324_8:
        cmp #EVT_KEY
        bne wt
        lda evtB
        sta emMods
        lda evtA
        cmp #KEY_STOP
        bne fb4324_9
        jmp end
fb4324_9:
        cmp #KEY_F7
        bne fb4324_10
        jmp end
fb4324_10:
        cmp #KEY_RETURN
        bne k1
        jsr be_Return
        jmp lp
k1:     cmp #KEY_DEL
        bne k2
        jsr be_Del
        jmp lp
k2:     cmp #KEY_CRSR_R
        bne k3
        lda emMods
        and #KM_SHIFT
        bne left
        lda cpX
        cmp #CP_W-1
        bcs lp
        inc cpX
        jmp lp
left:   lda cpX
        beq lp
        dec cpX
        jmp lp
k3:     cmp #KEY_CRSR_D
        bne k4
        lda emMods
        and #KM_SHIFT
        bne up
        lda cpY
        cmp #CP_LINES-1
        bcs lp
        inc cpY
        jmp lp
up:     lda cpY
        beq lp
        dec cpY
        jmp lp
k4:     cmp #KEY_HOME
        bne k5
        lda #0
        sta cpX
        lda emMods
        and #KM_SHIFT
        bne fb4324_0
        jmp lp
fb4324_0:
        lda #0
        sta cpY
        jmp lp
k5:     jsr key_Sc
        bcs fb4324_1
        jmp wt
fb4324_1:
        jsr be_Ins
        jmp lp
ms:     jsr off
        sec
        rts
end:    jsr off
        clc
        rts
off:    lda #0
        sta kbRaw
        jmp cp_Lines             // zonder cursor
}

// be_Show - scrollen zodat de cursor zichtbaar is, tekenen + cursor.
be_Show: {
        lda cpY
        cmp cpTop
        bcs a
        sta cpTop
a:      lda cpTop
        clc
        adc #CP_VIS-1
        cmp cpY
        bcs b
        lda cpY
        sec
        sbc #CP_VIS-1
        sta cpTop
b:      jsr cp_Lines
        lda cpY
        jsr cp_Ptr
        ldy cpX
        lda (r6),y
        jsr em_Disp
        jsr gfx_CurChar          // cursor (STONE: zonder omgekeerde tekens)
        sta a2
        lda cpX
        clc
        adc #2
        sta a0
        lda cpY
        sec
        sbc cpTop
        clc
        adc #CP_TOP
        sta a1
        lda TH_accent
        sta a3
        jmp gfx_PutChar
}

// be_Ins - teken A op de cursor invoegen.
be_Ins: {
        pha
        lda cpY
        jsr cp_Ptr
        ldy #CP_W-1
sh:     cpy cpX
        beq put
        dey
        lda (r6),y
        iny
        sta (r6),y
        dey
        jmp sh
put:    pla
        sta (r6),y
        inc cpX
        lda cpX
        cmp #CP_W
        bcc r
        lda cpY                  // regel vol: naar de volgende regel
        cmp #CP_LINES-1
        bcs last
        inc cpY
        lda #0
        sta cpX
        rts
last:   dec cpX
r:      rts
}

// be_Del - teken links van de cursor weg (aan het begin: regels samen).
be_Del: {
        lda cpX
        beq join
        dec cpX
        lda cpY
        jsr cp_Ptr
        ldy cpX
sh:     cpy #CP_W-1
        bcs e
        iny
        lda (r6),y
        dey
        sta (r6),y
        iny
        jmp sh
e:      lda #$20
        sta (r6),y
        rts
join:   lda cpY
        beq r
        sec
        sbc #1
        jsr cp_Line              // lengte van de vorige regel
        sty emJ
        lda cpY
        jsr cp_Line
        tya
        clc
        adc emJ
        cmp #CP_W+1
        bcs mv                   // past niet: alleen de cursor verplaatsen
        lda cpY                  // huidige regel achter de vorige plakken
        jsr cp_Ptr
        lda r6
        sta r3
        lda r6+1
        sta r3+1
        lda cpY
        sec
        sbc #1
        jsr cp_Ptr
        ldx emJ
        ldy #0
jc:     cpx #CP_W
        bcs jd
        lda (r3),y
        sty emI
        pha
        txa
        tay
        pla
        sta (r6),y
        ldy emI
        inx
        iny
        bne jc
jd:     lda cpY                  // huidige regel verwijderen
        jsr cp_Remove
        dec cpY
        lda emJ
        sta cpX
        rts
mv:     dec cpY
        lda emJ
        cmp #CP_W
        bcc m1
        lda #CP_W-1
m1:     sta cpX
r:      rts
}

// be_Return - regel splitsen op de cursor.
be_Return: {
        lda cpY
        cmp #CP_LINES-1
        bcs r
        clc                      // ruimte maken onder de huidige regel
        adc #1
        jsr cp_Insert
        lda cpY                  // rest van de regel naar de nieuwe
        jsr cp_Ptr
        lda r6
        sta r3
        lda r6+1
        sta r3+1
        lda cpY
        clc
        adc #1
        jsr cp_Ptr
        ldy cpX
        ldx #0
cp:     cpy #CP_W
        bcs d
        lda (r3),y
        pha
        lda #$20
        sta (r3),y
        sty emI
        txa
        tay
        pla
        sta (r6),y
        ldy emI
        inx
        iny
        bne cp
d:      inc cpY
        lda #0
        sta cpX
r:      rts
}

// cp_Insert - lege regel A invoegen (de laatste regel valt weg).
cp_Insert: {
        sta emJ
        lda #CP_LINES-1
        sta emI
lp:     lda emI
        cmp emJ
        beq clr
        sec
        sbc #1
        jsr cp_Ptr               // bron = regel i-1
        lda r6
        sta r3
        lda r6+1
        sta r3+1
        lda emI
        jsr cp_Ptr               // doel = regel i
        ldy #CP_W-1
c:      lda (r3),y
        sta (r6),y
        dey
        bpl c
        dec emI
        jmp lp
clr:    lda emJ
        jsr cp_Ptr
        ldy #CP_W-1
        lda #$20
cl:     sta (r6),y
        dey
        bpl cl
        rts
}

// cp_Remove - regel A verwijderen (onderaan komt een lege regel).
cp_Remove: {
        sta emI
lp:     lda emI
        cmp #CP_LINES-1
        bcs clr
        clc
        adc #1
        jsr cp_Ptr               // bron = regel i+1
        lda r6
        sta r3
        lda r6+1
        sta r3+1
        lda emI
        jsr cp_Ptr
        ldy #CP_W-1
c:      lda (r3),y
        sta (r6),y
        dey
        bpl c
        inc emI
        jmp lp
clr:    lda #CP_LINES-1
        jsr cp_Ptr
        ldy #CP_W-1
        lda #$20
cl:     sta (r6),y
        dey
        bpl cl
        rts
}

//--------------------------------------------------------
// Hulpjes
//--------------------------------------------------------
// em_Text / em_TextAcc - tekst A/Y (lo/hi) op rij X, kolom 2.
em_TextAcc:
        pha
        lda TH_accent
        jmp !+
em_Text:
        pha
        lda TH_text
!:      sta a2
        pla
        sta r0
        sty r0+1
        lda #2
        sta a0
        stx a1
        jmp gfx_DrawText

// em_TextW - tekst (r6, $ff) op kolom A, rij emRow, hoogstens X tekens.
em_TextW: {
        sta emCol
        stx emW
        ldy #0
lp:     cpy emW
        bcs r
        lda (r6),y
        cmp #$ff
        beq r
        jsr em_Disp
        sta a2
        sty emY
        lda emCol
        clc
        adc emY
        sta a0
        lda emRow
        sta a1
        lda TH_text
        sta a3
        jsr gfx_PutChar
        ldy emY
        iny
        bne lp
r:      rts
}

// em_Row36 - CP_W tekens vanaf (r6) op schermrij A, kolom 2.
em_Row36: {
        tax
        lda scrLo,x
        sta r3
        lda scrHi,x
        sta r3+1
        ldy #CP_W-1
lp:     lda (r6),y
        jsr em_Disp
        sta (r3),y
        dey
        bpl lp
        lda r3+1
        clc
        adc #>[COLOR_RAM-SCREEN_RAM]
        sta r3+1
        ldy #CP_W-1
        lda TH_text
cl:     sta (r3),y
        dey
        bpl cl
        rts
}

// em_Disp - schermcode om te tonen: SHIFT-letters ($41-$5A) zijn in de
//           desktop-charset iconen, dus als reverse letter (zoals de editor).
em_Disp:
        cmp #$41
        bcc !+
        cmp #$5b
        bcs !+
        eor #$c0
!:      rts

// em_Rule - streep over de breedte op rij A.
em_Rule:
        sta a1
        lda #2
        sta a0
        lda #CP_W
        sta a2
        lda #1
        sta a3
        lda #$2d
        sta a4
        lda TH_text
        sta a5
        jmp gfx_FillRect

// em_ShowMsg - meldingsregel (rij 22): leeg of emMsg.
em_ShowMsg: {
        lda #2
        sta a0
        lda #EM_MSG_ROW
        sta a1
        lda #CP_W
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda emMsg+1
        beq r
        sta r0+1
        lda emMsg
        sta r0
        lda #2
        sta a0
        lda #EM_MSG_ROW
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
r:      rts
}

// em_SetMsg / em_Progress - melding X/Y onthouden en meteen tonen.
em_SetMsg:
em_Progress:
        stx emMsg
        sty emMsg+1
        jmp em_ShowMsg

// em_NumMsg - "<emNum> MESSAGES ON THE SERVER" als melding.
em_NumMsg:
        jsr em_NumStart
        ldx #<sOnSrv
        ldy #>sOnSrv
        jsr em_MsgStr
        ldx #<emMsgBuf
        ldy #>emMsgBuf
        stx emMsg
        sty emMsg+1
        rts

// em_NumStart - emMsgBuf = emNum decimaal; em_NumAdd plakt erachter.
em_NumStart:
        lda #0
        sta emML
em_NumAdd: {
        ldx #0
        stx emAny
dg:     lda #0
        sta emDig
sb:     lda emNum
        sec
        sbc d16Lo,x
        tay
        lda emNum+1
        sbc d16Hi,x
        bcc pd
        sta emNum+1
        sty emNum
        inc emDig
        jmp sb
pd:     lda emDig
        ora emAny
        bne pr
        cpx #4
        bne nx
pr:     lda emDig
        ora #$30
        jsr em_MsgChr
        inc emAny
nx:     inx
        cpx #5
        bne dg
        rts
d16Lo:  .byte <10000, <1000, <100, <10, <1
d16Hi:  .byte >10000, >1000, >100, >10, >1
}

// em_MsgStr - schermcodetekst X/Y achter emMsgBuf.
em_MsgStr: {
        stx r6
        sty r6+1
        ldy #0
lp:     lda (r6),y
        cmp #$ff
        beq r
        jsr em_MsgChr
        iny
        bne lp
r:      rts
}
em_MsgChr:
        stx emXs
        ldx emML
        cpx #36
        bcs !+
        sta emMsgBuf,x
        inx
        stx emML
        lda #$ff
        sta emMsgBuf,x
!:      ldx emXs
        rts

//--------------------------------------------------------
emScreen: .byte SC_INBOX
emHelp:   .byte 0, 15, 16        // hulpcontext per scherm (0 = die van de app)
emMsg:    .word 0
emNum:    .word 0
emI:      .byte 0
emJ:      .byte 0
emRow:    .byte 0
emCol:    .byte 0
emW:      .byte 0
emY:      .byte 0
emXs:     .byte 0
emML:     .byte 0
emAny:    .byte 0
emDig:    .byte 0
emMods:   .byte 0
cpX:      .byte 0
cpY:      .byte 0
cpTop:    .byte 0
emMsgBuf: .fill 37, $ff

scrLo:  .fill 25, <[SCREEN_RAM + i*40 + 2]
scrHi:  .fill 25, >[SCREEN_RAM + i*40 + 2]
cpLo:   .fill CP_LINES, <[CP_BODY + i*CP_W]
cpHi:   .fill CP_LINES, >[CP_BODY + i*CP_W]
msLo:   .fill MS_LINES, <[MSGBUF + i*CP_W]
msHi:   .fill MS_LINES, >[MSGBUF + i*CP_W]

inBtnLo:  .byte <sFetch, <sNew
inBtnHi:  .byte >sFetch, >sNew
inBtnCol: .byte 2, 10
inBtnW:   .byte 7, 5
rdBtnLo:  .byte <sUp, <sDown, <sReply, <sBack
rdBtnHi:  .byte >sUp, >sDown, >sReply, >sBack
rdBtnCol: .byte 2, 7, 14, 22
rdBtnW:   .byte 4, 6, 7, 6

.encoding "screencode_upper"
sFetch:   .text "FETCH"
          .byte $ff
sNew:     .text "NEW"
          .byte $ff
sInEmpty: .text "CLICK FETCH TO GET YOUR MAIL"
          .byte $ff
sInFrom:  .text "FROM"
          .byte $ff
sInSubj:  .text "SUBJECT"
          .byte $ff
sNoSubj:  .text "(NO SUBJECT)"
          .byte $ff
sOnSrv:   .text " MESSAGES ON THE SERVER"
          .byte $ff
sRdFrom:  .text "FROM"
          .byte $ff
sRdSubj:  .text "SUBJ"
          .byte $ff
sRdDate:  .text "DATE"
          .byte $ff
sRdEmpty: .text "(NO TEXT IN THIS MESSAGE)"
          .byte $ff
sLine:    .text "LINE"
          .byte $ff
sOf:      .text " OF "
          .byte $ff
sUp:      .text "UP"
          .byte $ff
sDown:    .text "DOWN"
          .byte $ff
sReply:   .text "REPLY"
          .byte $ff
sBack:    .text "BACK"
          .byte $ff
sCpTo:    .text "TO"
          .byte $ff
sCpSubj:  .text "SUBJ"
          .byte $ff
sSend:    .text "SEND"
          .byte $ff
sCancel:  .text "CANCEL"
          .byte $ff
sCpHint:  .text "CLICK A FIELD OR THE TEXT TO TYPE"
          .byte $ff
sNoTo:    .text "WHO IS IT FOR? FILL IN TO"
          .byte $ff
sSent:    .text "MESSAGE SENT"
          .byte $ff
sRe:      .byte $52              // "Re: " (R met SHIFT = hoofdletter)
          .text "E: "
