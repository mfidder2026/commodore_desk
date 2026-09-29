#importonce
//========================================================
// apps/bbs/bbs_book.asm - adresboek met eigen BBS'en (bouwplan §41)
// Commodore Desk 64
//
// De tien ingebouwde BBS'en zijn vast (read-only). Daaronder komen tot
// BBS_CUSTOM eigen BBS'en, bewaard in BBS.BOOK:
//   +0 "BK", +2 versie, +3 aantal, dan per BBS: naam (20 + $ff),
//   host (32 + $ff), poort (lo, hi), terminal (BM_PETSCII / BM_ASCII).
// Een klik op een BBS maakt hem de default (BBS.CFG). ADD voegt er een
// toe; EDIT en DELETE werken op de default, alleen als dat een eigen BBS is.
//========================================================

.const BOOK_VERSION = 1
.const BK_TOP  = 3               // eerste lijstregel in het adresboek
.const BK_BTN  = 19              // knoppen
.const BK_HINT = 20              // hint / melding
.const FM_COL  = 14              // waardekolom in het formulier

// bb_BookLoad - BBS.BOOK laden (eenmaal per overlay-lading), tabellen vullen.
bb_BookLoad: {
        lda bkLoaded
        bne sync
        inc bkLoaded
        jsr cfg_io_begin
        lda #[nEnd-nm]
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #0                   // sa=0: naar bookBuf (LOAD slaat 2 bytes over)
        jsr K_SETLFS
        lda #0
        ldx #<[bookBuf-2]
        ldy #>[bookBuf-2]
        jsr K_LOAD
        php
        stx bkT
        sty bkT+1
        jsr cfg_io_end
        plp
        bcs empty
        lda bkT                  // precies zo lang?
        cmp #<bookEnd
        bne empty
        lda bkT+1
        cmp #>bookEnd
        bne empty
        lda bookBuf              // "BK", versie, aantal
        cmp #$42
        bne empty
        lda bookBuf+1
        cmp #$4b
        bne empty
        lda bookBuf+2
        cmp #BOOK_VERSION
        bne empty
        lda bookBuf+3
        cmp #BBS_CUSTOM+1
        bcc sync
empty:  jsr bb_BookEmpty
sync:   jsr bb_BookSync
        lda BC_DEFAULT           // default bestaat niet meer: compile-time default
        cmp bbCount
        bcc r
        lda #BBS_DEFAULT
        sta BC_DEFAULT
        jsr bb_CfgSum
r:      rts
nm:     .encoding "petscii_upper"
        .text "BBS.BOOK"
nEnd:   .encoding "screencode_upper"
}

// bb_BookEmpty - leeg boek.
bb_BookEmpty:
        lda #$42
        sta bookBuf
        lda #$4b
        sta bookBuf+1
        lda #BOOK_VERSION
        sta bookBuf+2
        lda #0
        sta bookBuf+3
        rts

// bb_BookSync - poort en terminal van de eigen BBS'en in de tabellen.
bb_BookSync: {
        lda bookBuf+3
        clc
        adc #BBS_COUNT
        sta bbCount
        ldx #0
lp:     cpx bookBuf+3
        bcs r
        jsr bk_Ptr               // r6 = record X
        ldy #BK_PORT
        lda (r6),y
        sta bbPortLo+BBS_COUNT,x
        iny
        lda (r6),y
        sta bbPortHi+BBS_COUNT,x
        ldy #BK_MODE
        lda (r6),y
        sta bbMode+BBS_COUNT,x
        inx
        bne lp
r:      rts
}

// bk_Ptr - r6 = record X (0..BBS_CUSTOM-1).
bk_Ptr:
        lda bkRecLo,x
        sta r6
        lda bkRecHi,x
        sta r6+1
        rts

// bb_BookSave - "@0:BBS.BOOK". Carry=1 bij een fout.
bb_BookSave: {
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
        lda #<[bookBuf-2]        // (2 bytes laadadres ervoor, zie bb_BookLoad)
        sta $fb
        lda #>[bookBuf-2]
        sta $fc
        lda #$fb
        ldx #<bookEnd
        ldy #>bookEnd
        jsr K_SAVE
        php
        jsr cfg_io_end
        plp
        jmp save_End             // scherm terug (carry blijft)
nm:     .encoding "petscii_upper"
        .text "@0:BBS.BOOK"
nEnd:   .encoding "screencode_upper"
}

//--------------------------------------------------------
// bb_Book - adresboek: klik = nieuwe default; ADD / EDIT / DELETE.
//--------------------------------------------------------
bb_Book: {
        lda #13                  // F1: hulp bij het adresboek
        sta helpCtx
        lda #<sBbBook
        sta r0
        lda #>sBbBook
        sta r0+1
        lda #2
        sta a0
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
        lda TH_text              // directory-entry grijs, eigen BBS accent
        ldy bbFlags,x
        bne c1
        lda #GREY
        jmp col
c1:     cpx #BBS_COUNT
        bcc col
        lda TH_accent
col:    sta a2
        jsr gfx_DrawText
        ldx bbI
        inx
        cpx bbCount
        bne row
        ldx #0                   // knoppen
bl:     stx bbI
        lda bkBtnLo,x
        sta r0
        lda bkBtnHi,x
        sta r0+1
        lda bkBtnCol,x
        sta a0
        lda #BK_BTN
        sta a1
        lda bkBtnW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx bbI
        inx
        cpx #3
        bne bl
        lda bkMsg                // hint of melding
        sta r0
        lda bkMsg+1
        sta r0+1
        lda #4
        sta a0
        lda #BK_HINT
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        lda #<sBbBookHint        // (volgende keer weer de hint)
        sta bkMsg
        lda #>sBbBookHint
        sta bkMsg+1
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
        ldx #0                   // knoppen?
bh:     stx bbI
        lda bkBtnCol,x
        sta a0
        lda #BK_BTN
        sta a1
        lda bkBtnW,x
        sta a2
        jsr btn_HitTest
        bcs btn
        ldx bbI
        inx
        cpx #3
        bne bh
        lda evtB                 // op een BBS-regel?
        sec
        sbc #BK_TOP
        bcc wait
        cmp bbCount
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
back:   lda #0
        sta helpCtx
        jmp shell_DrawAll
btn:    lda bbI
        bne b1
        lda bbCount              // ADD
        cmp #BBS_MAX
        bcc add
        ldx #<sBkFull
        ldy #>sBkFull
        jmp redo
add:    lda #1
        sta fmNew
        jsr bb_Form
        jmp bb_Book
b1:     lda BC_DEFAULT           // EDIT / DELETE: alleen een eigen BBS
        cmp #BBS_COUNT
        bcs own
        ldx #<sBkBuiltin
        ldy #>sBkBuiltin
redo:   stx bkMsg
        sty bkMsg+1
        jmp bb_Book
own:    lda bbI
        cmp #1
        bne del
        lda #0
        sta fmNew
        jsr bb_Form
        jmp bb_Book
del:    jsr bb_Delete
        ldx #<sBkDeleted
        ldy #>sBkDeleted
        jmp redo
}

// bb_Delete - eigen BBS BC_DEFAULT verwijderen (de rest schuift op).
bb_Delete: {
        lda BC_DEFAULT
        sec
        sbc #BBS_COUNT
        tax
lp:     inx                      // record x+1 -> record x
        cpx bookBuf+3
        bcs done
        jsr bk_Ptr               // r6 = bron (x)
        lda r6
        sta r3
        lda r6+1
        sta r3+1
        dex
        jsr bk_Ptr               // r6 = doel (x-1)
        ldy #BK_REC-1
cp:     lda (r3),y
        sta (r6),y
        dey
        bpl cp
        inx
        jmp lp
done:   dec bookBuf+3
        jsr bb_BookSync
        lda #BBS_DEFAULT
        sta BC_DEFAULT
        jsr bb_BookSave
        jmp bb_CfgSave
}

//--------------------------------------------------------
// bb_Form - ADD BBS (fmNew=1) of EDIT BBS (de default).
//--------------------------------------------------------
bb_Form: {
        lda #14                  // F1: hulp bij het formulier
        sta helpCtx
        lda fmNew
        beq ed
        lda #$ff                 // leeg; poort 23, PETSCII
        sta fmName
        sta fmHost
        ldx #0
dp:     lda dPort,x
        sta fmPort,x
        inx
        cpx #3
        bne dp
        lda #BM_PETSCII
        sta fmMode
        jmp draw
ed:     lda BC_DEFAULT           // waarden van de eigen BBS kopieren
        sec
        sbc #BBS_COUNT
        tax
        jsr bk_Ptr
        ldy #BK_NAME
n1:     lda (r6),y
        sta fmName-BK_NAME,y
        iny
        cpy #BK_NAME+BK_NAMEMAX+1
        bne n1
        ldy #BK_HOST
h1:     lda (r6),y
        sta fmHost-BK_HOST,y
        iny
        cpy #BK_HOST+BK_HOSTMAX+1
        bne h1
        ldy #BK_MODE
        lda (r6),y
        sta fmMode
        ldx BC_DEFAULT
        lda bbPortLo,x
        sta bbPort
        lda bbPortHi,x
        sta bbPort+1
        jsr fm_PortText
draw:   ldx #<sFmAdd
        ldy #>sFmAdd
        lda fmNew
        bne dt
        ldx #<sFmEdit
        ldy #>sFmEdit
dt:     stx r0
        sty r0+1
        lda #3
        sta a0
        lda #5
        sta a1
        lda #34
        sta a2
        lda #12
        sta a3
        jsr dlg_Draw
        ldx #0                   // labels
lb:     stx bbI
        lda fmLblLo,x
        sta r0
        lda fmLblHi,x
        sta r0+1
        lda #5
        sta a0
        lda fmRow,x
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        ldx bbI
        inx
        cpx #4
        bne lb
        ldx #0                   // velden
fl:     stx bbI
        jsr fm_Field
        lda #0
        sta fxOn
        jsr fx_Show
        ldx bbI
        inx
        cpx #3
        bne fl
        jsr fm_ShowMode
        ldx #0                   // SAVE / CANCEL
fb:     stx bbI
        lda fmBtnLo,x
        sta r0
        lda fmBtnHi,x
        sta r0+1
        lda fmBtnCol,x
        sta a0
        lda #15
        sta a1
        lda fmBtnW,x
        sta a2
        lda TH_accent
        sta a3
        jsr btn_Draw
        ldx bbI
        inx
        cpx #2
        bne fb
wait:   jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        beq click
        cmp #EVT_KEY
        bne wait
        lda evtA
        cmp #$82                 // ESC = annuleren
        bne w1
        rts
w1:     cmp #$80
        beq kc
        cmp #$20
        bne wait
kc:     jsr cursorToCell
click:  jsr dlg_HitClose
        bcc c0
        rts
c0:     ldx #0                   // SAVE / CANCEL?
cb:     stx bbI
        lda fmBtnCol,x
        sta a0
        lda #15
        sta a1
        lda fmBtnW,x
        sta a2
        jsr btn_HitTest
        bcs btn
        ldx bbI
        inx
        cpx #2
        bne cb
        lda evtB                 // een veld?
        cmp fmRow+3
        beq mode
        ldx #0
cf:     cmp fmRow,x
        beq field
        inx
        cpx #3
        bne cf
        jmp wait
field:  jsr fm_Field
        jsr fx_Edit
        bcs click                // klik tijdens het typen: verwerken
        jmp wait
mode:   lda fmMode               // PETSCII <-> ASCII
        eor #[BM_PETSCII^BM_ASCII]
        sta fmMode
        jsr fm_ShowMode
        jmp wait
btn:    lda bbI
        beq save
        rts                      // CANCEL
save:   jsr fm_Save
        bcs ok
        stx fmErr                // melding in het formulier, verder typen
        sty fmErr+1
        jsr fm_ShowErr
        jmp wait
ok:     rts
dPort:  .text "23"
        .byte $ff
}

// fm_Field - fx-parameters voor veld X (0 naam, 1 host, 2 poort).
fm_Field:
        lda fmBufLo,x
        sta r3
        lda fmBufHi,x
        sta r3+1
        lda fmMax,x
        sta fxMax
        lda fmVis,x
        sta fxVis
        lda fmRow,x
        sta fxRow
        lda #FM_COL
        sta fxCol
        rts

fm_ShowMode: {
        ldx #<bmPet
        ldy #>bmPet
        lda fmMode
        cmp #BM_ASCII
        bne p
        ldx #<sFmAscii
        ldy #>sFmAscii
p:      stx r0
        sty r0+1
        lda #FM_COL
        sta a0
        lda fmRow+3
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
}

fm_ShowErr:
        lda fmErr
        sta r0
        lda fmErr+1
        sta r0+1
        lda #5
        sta a0
        lda #14
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText

// fm_Save - controleren en opslaan. Carry=1 gelukt, anders X/Y melding.
fm_Save: {
        lda fmName
        cmp #$ff
        bne n
        ldx #<sFmNoName
        ldy #>sFmNoName
        clc
        rts
n:      lda fmHost
        cmp #$ff
        bne h
        ldx #<sFmNoHost
        ldy #>sFmNoHost
        clc
        rts
h:      lda #0                   // poort: 1-65535
        sta bbPort
        sta bbPort+1
        tay
pl:     lda fmPort,y
        cmp #$ff
        beq pe
        cmp #$30
        bcc bad
        cmp #$3a
        bcs bad
        and #$0f
        pha
        lda bbPort               // *10
        ldx bbPort+1
        asl bbPort
        rol bbPort+1
        asl bbPort
        rol bbPort+1
        clc
        adc bbPort
        sta bbPort
        txa
        adc bbPort+1
        sta bbPort+1
        asl bbPort
        rol bbPort+1
        bcs bad1                 // > 65535
        pla
        clc
        adc bbPort
        sta bbPort
        bcc nc
        inc bbPort+1
        beq bad
nc:     iny
        cpy #5
        bne pl
pe:     lda bbPort
        ora bbPort+1
        bne ok
        jmp bad
bad1:   pla
bad:    ldx #<sChPort
        ldy #>sChPort
        clc
        rts
ok:     lda fmNew                // record kiezen
        beq ed
        ldx bookBuf+3
        inc bookBuf+3
        jmp st
ed:     lda BC_DEFAULT
        sec
        sbc #BBS_COUNT
        tax
st:     stx bkT
        jsr bk_Ptr
        ldy #BK_NAME
n1:     lda fmName-BK_NAME,y
        sta (r6),y
        iny
        cpy #BK_NAME+BK_NAMEMAX+1
        bne n1
        ldy #BK_HOST
h1:     lda fmHost-BK_HOST,y
        sta (r6),y
        iny
        cpy #BK_HOST+BK_HOSTMAX+1
        bne h1
        ldy #BK_PORT
        lda bbPort
        sta (r6),y
        iny
        lda bbPort+1
        sta (r6),y
        ldy #BK_MODE
        lda fmMode
        sta (r6),y
        jsr bb_BookSync
        lda bkT                  // de nieuwe/bewerkte BBS wordt de default
        clc
        adc #BBS_COUNT
        sta BC_DEFAULT
        jsr bb_BookSave
        jsr bb_CfgSave
        sec
        rts
}

// fm_PortText - bbPort (1-65535) -> fmPort (decimaal, $ff).
fm_PortText: {
        ldx #0
        stx bbAny
        stx bkT
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
        ora bbAny
        bne pr
        cpx #4
        bne nx
pr:     lda bbDig
        ora #$30
        ldy bkT
        sta fmPort,y
        inc bkT
        inc bbAny
nx:     inx
        cpx #5
        bne dg
        ldy bkT
        lda #$ff
        sta fmPort,y
        rts
}

//--------------------------------------------------------
// fx_Edit - één regel bewerken (tekst achteraan erbij / DEL eraf).
//   In: r3 = buffer (schermcodes, $ff), fxMax, fxCol, fxRow, fxVis.
//   RETURN / RUN/STOP = klaar. Uit: carry=1 -> klaar door een muisklik.
//--------------------------------------------------------
fx_Edit: {
        lda #1
        sta fxOn
        jsr fx_Show
lp:     jsr evt_Poll
        cmp #EVT_MOUSEDOWN
        beq ms
        cmp #EVT_KEY
        bne lp
        lda evtA
        cmp #$80
        beq end
        cmp #$82
        beq end
        cmp #$81                 // DEL
        beq del
        cmp #$1c                 // letters, [ ], cijfers, leestekens,
        beq lp                   // SHIFT-letters
        cmp #$1e
        bcc ok
        cmp #$20
        bcc lp
        cmp #$40
        bcc ok
        beq lp
        cmp #$5b
        bcs lp
ok:     pha
        jsr fx_Len
        pla
        cpy fxMax
        bcs lp
        sta (r3),y
        iny
        lda #$ff
        sta (r3),y
        jsr fx_Show
        jmp lp
del:    jsr fx_Len
        cpy #0
        beq lp
        dey
        lda #$ff
        sta (r3),y
        jsr fx_Show
        jmp lp
ms:     jsr off
        sec
        rts
end:    jsr off
        clc
        rts
off:    lda #0
        sta fxOn
        jmp fx_Show
}

fx_Len:
        ldy #0
!:      lda (r3),y
        cmp #$ff
        beq !+
        iny
        cpy #40
        bne !-
!:      rts

// fx_Show - veld tekenen; tijdens het bewerken het einde + cursor.
fx_Show: {
        jsr fx_Len
        sty fxL
        lda #0
        sta fxS
        lda fxOn
        beq st
        lda fxL
        sec
        sbc fxVis
        bcc st
        adc #0
        sta fxS
st:     ldx #0
lp:     stx fxI
        txa
        clc
        adc fxS
        tay
        lda #$20
        cpy fxL
        bcs sp
        lda (r3),y
        cmp #$41                 // SHIFT-letter: als reverse letter tonen
        bcc ch
        cmp #$5b
        bcs ch
        eor #$c0
        jmp ch
sp:     ldx fxOn
        beq ch
        cpy fxL
        bne ch
        lda #GL_SOLID                 // cursor
ch:     sta a2
        lda fxI
        clc
        adc fxCol
        sta a0
        lda fxRow
        sta a1
        lda TH_text
        ldx fxOn
        beq c
        lda TH_accent
c:      sta a3
        jsr gfx_PutChar
        ldx fxI
        inx
        cpx fxVis
        bne lp
        rts
}

//--------------------------------------------------------
bkLoaded: .byte 0
bkT:      .word 0
bkMsg:    .word sBbBookHint
fmNew:    .byte 0
fmMode:   .byte 0
fmErr:    .word 0
fxMax:    .byte 0
fxVis:    .byte 0
fxCol:    .byte 0
fxRow:    .byte 0
fxOn:     .byte 0
fxL:      .byte 0
fxS:      .byte 0
fxI:      .byte 0
fmName:   .fill BK_NAMEMAX+1, $ff
fmHost:   .fill BK_HOSTMAX+1, $ff
fmPort:   .fill 6, $ff
bkRecLo:  .fill BBS_CUSTOM, <[bookBuf + 4 + i*BK_REC]
bkRecHi:  .fill BBS_CUSTOM, >[bookBuf + 4 + i*BK_REC]
fmRow:    .byte 7, 9, 11, 13
fmMax:    .byte BK_NAMEMAX, BK_HOSTMAX, 5
fmVis:    .byte 20, 20, 6
fmBufLo:  .byte <fmName, <fmHost, <fmPort
fmBufHi:  .byte >fmName, >fmHost, >fmPort
fmLblLo:  .byte <sFmName, <sFmHost, <sFmPort, <sFmTerm
fmLblHi:  .byte >sFmName, >sFmHost, >sFmPort, >sFmTerm
fmBtnLo:  .byte <sFmSave, <sFmCancel
fmBtnHi:  .byte >sFmSave, >sFmCancel
fmBtnCol: .byte 5, 13
fmBtnW:   .byte 6, 8
bkBtnLo:  .byte <sBkAdd, <sBkEdit, <sBkDel
bkBtnHi:  .byte >sBkAdd, >sBkEdit, >sBkDel
bkBtnCol: .byte 4, 10, 17
bkBtnW:   .byte 5, 6, 8

.encoding "screencode_upper"
sBkAdd:     .text "ADD"
            .byte $ff
sBkEdit:    .text "EDIT"
            .byte $ff
sBkDel:     .text "DELETE"
            .byte $ff
sBkFull:    .text "THE ADDRESS BOOK IS FULL"
            .byte $ff
sBkBuiltin: .text "ONLY YOUR OWN BBS CAN CHANGE"
            .byte $ff
sBkDeleted: .text "DELETED"
            .byte $ff
sFmAdd:     .text "ADD BBS"
            .byte $ff
sFmEdit:    .text "EDIT BBS"
            .byte $ff
sFmName:    .text "NAME"
            .byte $ff
sFmHost:    .text "HOST"
            .byte $ff
sFmPort:    .text "PORT"
            .byte $ff
sFmTerm:    .text "TERMINAL"
            .byte $ff
sFmAscii:   .text "ASCII  "
            .byte $ff
sFmSave:    .text "SAVE"
            .byte $ff
sFmCancel:  .text "CANCEL"
            .byte $ff
sFmNoName:  .text "FILL IN A NAME        "
            .byte $ff
sFmNoHost:  .text "FILL IN A HOST        "
            .byte $ff

// BBS.BOOK in het geheugen (2 bytes ervoor = laadadres bij LOAD/SAVE)
            .word 0
bookBuf:    .byte $42, $4b, BOOK_VERSION, 0
            .fill BBS_CUSTOM*BK_REC, $ff
bookEnd:
