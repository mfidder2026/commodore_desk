#importonce
//========================================================
// gui/files.asm - gedeelde bestandsdiensten (Core)
// Commodore Desk 64
//
//   file*       overdracht "open dit bestand": de File Manager zet een
//               bestand klaar voor de editor of de SID Player
//   dsk_Status  foutkanaal van een drive lezen ("62,FILE NOT FOUND,00,00")
//   dsk_Cmd     DOS-opdracht sturen (bv. "S0:NAAM"), met status
//   li_Edit     invoerregel (tekst achteraan erbij, DEL eraf)
//========================================================

// dsk_Status - A = device. Uit: dsCode (0-99), dsText (schermcodes, $ff),
//              carry=1 als de drive er niet is.
dsk_Status:
        ldx #0
        stx dsCmdLen
// dsk_Cmd - A = device, opdracht (PETSCII) op dsCmd, lengte dsCmdLen.
dsk_Cmd: {
        sta dsDev
        jsr cfg_io_begin
        lda dsCmdLen
        ldx #<dsCmd
        ldy #>dsCmd
        jsr K_SETNAM
        lda #15
        ldx dsDev
        ldy #15
        jsr K_SETLFS
        lda #0
        sta $90                  // ST wissen
        jsr K_OPEN
        bcs none
        ldx #15
        jsr K_CHKIN
        bcs none
        lda $90
        bmi none                 // device not present
        ldy #0
rd:     sty dsI
        jsr K_CHRIN
        ldy dsI
        cmp #$0d
        beq end
        jsr petscii2screen
        cpy #38
        bcs nx
        sta dsText,y
        iny
nx:     lda $90                  // EOF / fout
        beq rd
end:    lda #$ff
        sta dsText,y
        jsr K_CLRCHN
        lda #15
        jsr K_CLOSE
        jsr cfg_io_end
        lda dsText               // code = eerste twee cijfers
        and #$0f
        sta dsCode
        asl
        asl
        adc dsCode
        asl
        sta dsCode
        lda dsText+1
        and #$0f
        clc
        adc dsCode
        sta dsCode
        clc
        rts
none:   jsr K_CLRCHN
        lda #15
        jsr K_CLOSE
        jsr cfg_io_end
        lda #$ff
        sta dsText
        sta dsCode
        sec
        rts
}

//--------------------------------------------------------
// li_Edit - invoerregel. In: r3 = buffer (schermcodes, $ff), liMax, liCol,
//   liRow, liVis. RETURN / RUN/STOP = klaar. Uit: carry=1 -> klaar door
//   een muisklik (evtA/evtB nog te verwerken). @ en _ in de ruwe modus.
//--------------------------------------------------------
li_Edit: {
        lda kbRaw
        sta liRaw
        lda #1
        sta kbRaw
        sta liOn
        jsr li_Show
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
        cmp #$81
        beq del
        cmp #$8d                 // @
        bne k1
        lda #0
        jmp ok
k1:     cmp #$90                 // _
        bne k2
        lda #$64
        jmp ok
k2:     cmp #$80
        bcs lp
        cmp #$1c
        beq lp
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
        jsr li_Len
        pla
        cpy liMax
        bcs lp
        sta (r3),y
        iny
        lda #$ff
        sta (r3),y
        jsr li_Show
        jmp lp
del:    jsr li_Len
        cpy #0
        beq lp
        dey
        lda #$ff
        sta (r3),y
        jsr li_Show
        jmp lp
ms:     jsr off
        sec
        rts
end:    jsr off
        clc
        rts
off:    lda liRaw
        sta kbRaw
        lda #0
        sta liOn
        jmp li_Show
}

li_Len:
        ldy #0
!:      lda (r3),y
        cmp #$ff
        beq !+
        iny
        cpy #40
        bne !-
!:      rts

// li_Show - veld tekenen; tijdens het typen het einde + cursor.
li_Show: {
        jsr li_Len
        sty liL
        lda #0
        sta liS
        lda liOn
        beq st
        lda liL
        sec
        sbc liVis
        bcc st
        adc #0
        sta liS
st:     ldx #0
lp:     stx liI
        txa
        clc
        adc liS
        tay
        lda #$20
        cpy liL
        bcs sp
        lda (r3),y
        jsr sc_Disp
        jmp ch
sp:     ldx liOn
        beq ch
        cpy liL
        bne ch
        lda #$a0
ch:     sta a2
        lda liI
        clc
        adc liCol
        sta a0
        lda liRow
        sta a1
        lda TH_text
        ldx liOn
        beq c
        lda TH_accent
c:      sta a3
        jsr gfx_PutChar
        ldx liI
        inx
        cpx liVis
        bne lp
        rts
}

// sc_Disp - schermcode om te tonen: SHIFT-letters ($41-$5A) zijn in de
//           desktop-charset iconen -> als reverse letter.
sc_Disp:
        cmp #$41
        bcc !+
        cmp #$5b
        bcs !+
        eor #$c0
!:      rts

//--------------------------------------------------------
fileReq:  .byte 0                // 1 = er staat een bestand klaar (fileDev/Name)
fileDev:  .byte 8
fileSkip: .byte 0                // 1 = eerste 2 bytes overslaan (PRG als tekst)
fileLen:  .byte 0
fileName: .fill 16, 0            // PETSCII
dsDev:    .byte 0
dsCode:   .byte 0
dsI:      .byte 0
dsCmdLen: .byte 0
dsCmd:    .fill 24, 0
dsText:   .fill 39, $ff
liMax:    .byte 0
liCol:    .byte 0
liRow:    .byte 0
liVis:    .byte 0
liOn:     .byte 0
liRaw:    .byte 0
liL:      .byte 0
liS:      .byte 0
liI:      .byte 0
