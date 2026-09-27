#importonce
//========================================================
// apps/bbs/bbs.asm - BBS CLIENT (overlay BBS, bouwplan Increment 1)
// Commodore Desk 64
//
// Hoofdscherm met de default BBS, knoppen CONNECT / DISCONNECT /
// ADDRESS BOOK / LOCAL ECHO / BACK TO DESKTOP, en het adresboek waarin
// een klik de default kiest (opgeslagen in BBS.CFG).
// Increment 1: nog geen netwerk (CONNECT volgt in increment 2).
//========================================================

.const BB_COL  = 4               // labels en knoppen
.const BB_BTNW = 17              // knopbreedte
.const BB_MSG_ROW = 21

// knoppen: rij per knop
.const BB_R_CONNECT = 11
.const BB_R_DISC    = 13
.const BB_R_BOOK    = 15
.const BB_R_ECHO    = 17
.const BB_R_BACK    = 19

bbs_Init:
        jsr bb_CfgLoad
        lda #<sBbNotConn
        sta bbStatus
        lda #>sBbNotConn
        sta bbStatus+1
        lda #0
        sta bbMsg+1              // geen melding
        rts

// bbs_Key - toetsen (voor de terminal, volgt).
bbs_Key:
        rts

//--------------------------------------------------------
// bbs_Draw - hoofdscherm.
//--------------------------------------------------------
bbs_Draw: {
        lda #<sBbDefault         // DEFAULT BBS
        ldy #>sBbDefault
        ldx #3
        jsr bb_TextAcc
        ldx BC_DEFAULT           // naam
        lda bbNameLo,x
        ldy bbNameHi,x
        ldx #5
        jsr bb_Text
        jsr bb_HostLine          // host:poort (rij 6)
        lda #<sBbTerm            // TERMINAL: ...
        ldy #>sBbTerm
        ldx #7
        jsr bb_Text
        ldx BC_DEFAULT
        lda bbMode,x
        tax
        lda bbModeLo,x
        sta r0
        lda bbModeHi,x
        sta r0+1
        lda #BB_COL+10
        sta a0
        lda #7
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        lda #<sBbStatus          // STATUS: ...
        ldy #>sBbStatus
        ldx #9
        jsr bb_Text
        lda bbStatus
        sta r0
        lda bbStatus+1
        sta r0+1
        lda #BB_COL+8
        sta a0
        lda #9
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        // knoppen
        ldx #0
bl:     stx bbI
        lda bbBtnLo,x
        sta r0
        lda bbBtnHi,x
        sta r0+1
        lda #BB_COL
        sta a0
        lda bbBtnRow,x
        sta a1
        lda #BB_BTNW
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx bbI
        inx
        cpx #5
        bne bl
        lda BC_ECHO              // LOCAL ECHO: ON/OFF naast de knop
        ldx #<sBbOff
        ldy #>sBbOff
        cmp #0
        beq eo
        ldx #<sBbOn
        ldy #>sBbOn
eo:     stx r0
        sty r0+1
        lda #BB_COL+BB_BTNW+1
        sta a0
        lda #BB_R_ECHO
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        jmp bb_ShowMsg
}

// bb_HostLine - "HOST:POORT" (of de website bij een directory) op rij 6.
bb_HostLine: {
        ldx BC_DEFAULT
        lda bbHostLo,x
        sta r0
        lda bbHostHi,x
        sta r0+1
        lda #BB_COL
        sta a0
        lda #6
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText         // (laat de cursor-kolom in r4 niet achter)
        ldx BC_DEFAULT
        lda bbMode,x
        bne port
        rts                      // directory: geen poort
port:
        ldy #0                   // lengte van de host -> kolom voor ":poort"
        ldx BC_DEFAULT
        lda bbHostLo,x
        sta r0
        lda bbHostHi,x
        sta r0+1
ln:     lda (r0),y
        cmp #$ff
        beq le
        iny
        bne ln
le:     tya
        clc
        adc #BB_COL
        sta bbCol
        lda #0
        sta bbN
        lda #$3a                 // :
        jsr put
        ldx BC_DEFAULT
        lda bbPortLo,x
        sta bbPort
        lda bbPortHi,x
        sta bbPort+1
        ldx #0                   // 16-bit decimaal zonder voorloopnullen
        stx bbAny
dg:     lda #0
        sta bbDig
sb:     lda bbPort
        sec
        sbc bbD16Lo,x
        tay
        lda bbPort+1
        sbc bbD16Hi,x
        bcc pd
        sta bbPort+1
        sty bbPort
        inc bbDig
        jmp sb
pd:     lda bbDig
        bne pr
        lda bbAny
        bne pr
        cpx #4
        bne nx
pr:     lda bbDig
        ora #$30
        stx bbX
        jsr put
        ldx bbX
        inc bbAny
nx:     inx
        cpx #5
        bne dg
done:   rts
put:    sta a2                   // één teken op (bbCol, rij 6)
        lda bbCol
        sta a0
        lda #6
        sta a1
        lda TH_text
        sta a3
        jsr gfx_PutChar
        inc bbCol
        rts
}
bbD16Lo: .byte <10000, <1000, <100, <10, <1
bbD16Hi: .byte >10000, >1000, >100, >10, >1

// bb_Text / bb_TextAcc - tekst A/Y (lo/hi) op rij X, kolom BB_COL.
bb_TextAcc:
        pha
        lda TH_accent
        jmp bbT
bb_Text:
        pha
        lda TH_text
bbT:    sta a2
        pla
        sta r0
        sty r0+1
        lda #BB_COL
        sta a0
        stx a1
        jmp gfx_DrawText

// bb_ShowMsg - meldingsregel (rij 21), leeg als er geen melding is.
bb_ShowMsg: {
        lda #BB_COL
        sta a0
        lda #BB_MSG_ROW
        sta a1
        lda #33
        sta a2
        lda #1
        sta a3
        lda #$20
        sta a4
        lda TH_text
        sta a5
        jsr gfx_FillRect
        lda bbMsg+1
        beq out
        sta r0+1
        lda bbMsg
        sta r0
        lda #BB_COL
        sta a0
        lda #BB_MSG_ROW
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
out:    rts
}

// bb_SetMsg - melding X/Y tonen.
bb_SetMsg:
        stx bbMsg
        sty bbMsg+1
        jmp bb_ShowMsg

//--------------------------------------------------------
// bbs_Click - knoppen.
//--------------------------------------------------------
bbs_Click: {
        ldx #0
lp:     stx bbI
        lda #BB_COL
        sta a0
        lda bbBtnRow,x
        sta a1
        lda #BB_BTNW
        sta a2
        jsr btn_HitTest
        bcs hit
        ldx bbI
        inx
        cpx #5
        bne lp
        rts
hit:    lda bbI
        beq connect
        cmp #1
        beq disc
        cmp #2
        beq book
        cmp #3
        beq echo
        jmp exitToDesktop        // BACK TO DESKTOP
connect:
        ldx BC_DEFAULT           // directory-entry: kan niet verbinden
        lda bbFlags,x
        and #BF_CONNECT
        bne soon
        ldx #<sBbDirOnly
        ldy #>sBbDirOnly
        jmp bb_SetMsg
soon:   ldx #<sBbSoon
        ldy #>sBbSoon
        jmp bb_SetMsg
disc:   ldx #<sBbNotConnMsg
        ldy #>sBbNotConnMsg
        jmp bb_SetMsg
echo:   lda BC_ECHO              // LOCAL ECHO aan/uit (en bewaren)
        eor #1
        sta BC_ECHO
        jsr bb_CfgSave
        jmp shell_DrawAll
book:   jmp bb_Book
}

//--------------------------------------------------------
// bb_Book - adresboek: klik een BBS = nieuwe default (BBS.CFG).
//--------------------------------------------------------
.const BK_TOP = 4                // eerste regel
bb_Book: {
        lda #<sBbBook
        sta r0
        lda #>sBbBook
        sta r0+1
        lda #2
        sta a0
        lda #2
        sta a1
        lda #36
        sta a2
        lda #20
        sta a3
        jsr dlg_Draw
        ldx #0
row:    stx bbI
        lda #$20                 // markering voor de default
        cpx BC_DEFAULT
        bne nm
        lda #$3e                 // >
nm:     sta a2
        lda #4
        sta a0
        txa
        clc
        adc #BK_TOP
        sta a1
        lda TH_accent
        sta a3
        jsr gfx_PutChar
        ldx bbI
        lda bbNameLo,x
        sta r0
        lda bbNameHi,x
        sta r0+1
        lda #6
        sta a0
        txa
        clc
        adc #BK_TOP
        sta a1
        lda TH_text              // directory-entry grijs: niet te verbinden
        ldy bbFlags,x
        bne col
        lda #GREY
col:    sta a2
        jsr gfx_DrawText
        ldx bbI
        inx
        cpx #BBS_COUNT
        bne row
        lda #<sBbBookHint
        sta r0
        lda #>sBbBookHint
        sta r0+1
        lda #4
        sta a0
        lda #BK_TOP+BBS_COUNT+2
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
wait:   jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        beq click
        cmp #EVT_KEY
        bne wait
        lda evtA
        cmp #$82                 // ESC = terug
        beq back
        cmp #$20                 // spatie/RETURN = klik op de cursor
        beq kc
        cmp #$80
        bne wait
kc:     jsr cursorToCell
click:  jsr dlg_HitClose
        bcs back
        lda evtB                 // op een BBS-regel?
        sec
        sbc #BK_TOP
        bcc wait
        cmp #BBS_COUNT
        bcs wait
        sta BC_DEFAULT
        jsr bb_CfgSave           // (berekent ook de checksum)
        ldx #<sBbSaved
        ldy #>sBbSaved
        bcc sv
        ldx #<sBbSaveErr
        ldy #>sBbSaveErr
sv:     stx bbMsg
        sty bbMsg+1
back:   jmp shell_DrawAll
}

//--------------------------------------------------------
bbStatus: .word 0
bbMsg:    .word 0
bbI:      .byte 0
bbCol:    .byte 0
bbN:      .byte 0
bbX:      .byte 0
bbDig:    .byte 0
bbAny:    .byte 0
bbPort:   .word 0
bbBtnRow: .byte BB_R_CONNECT, BB_R_DISC, BB_R_BOOK, BB_R_ECHO, BB_R_BACK
bbBtnLo:  .byte <sBbConnect, <sBbDisc, <sBbBookB, <sBbEcho, <sBbBack
bbBtnHi:  .byte >sBbConnect, >sBbDisc, >sBbBookB, >sBbEcho, >sBbBack

.encoding "screencode_upper"
sBbDefault:  .text "DEFAULT BBS"
             .byte $ff
sBbTerm:     .text "TERMINAL:"
             .byte $ff
sBbStatus:   .text "STATUS:"
             .byte $ff
sBbNotConn:  .text "NOT CONNECTED"
             .byte $ff
sBbConnect:  .text "CONNECT"
             .byte $ff
sBbDisc:     .text "DISCONNECT"
             .byte $ff
sBbBookB:    .text "ADDRESS BOOK"
             .byte $ff
sBbEcho:     .text "LOCAL ECHO"
             .byte $ff
sBbBack:     .text "BACK TO DESKTOP"
             .byte $ff
sBbOn:       .text "ON "
             .byte $ff
sBbOff:      .text "OFF"
             .byte $ff
sBbBook:     .text "BBS ADDRESS BOOK"
             .byte $ff
sBbBookHint: .text "CLICK A BBS = NEW DEFAULT"
             .byte $ff
sBbSaved:    .text "DEFAULT SAVED IN BBS.CFG"
             .byte $ff
sBbSaveErr:  .text "COULD NOT SAVE BBS.CFG"
             .byte $ff
sBbDirOnly:  .text "DIRECTORY ONLY - NO CONNECT"
             .byte $ff
sBbSoon:     .text "CONNECT COMES IN THE NEXT STEP"
             .byte $ff
sBbNotConnMsg: .text "NOT CONNECTED"
             .byte $ff
