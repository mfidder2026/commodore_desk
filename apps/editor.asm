#importonce
//========================================================
// apps/editor.asm - Text Editor (Fase 8)
// Commodore Desk 64
//
// Eenvoudige teksteditor: typ in een 32x10 tekstveld, met RETURN
// (nieuwe regel) en DEL (backspace). Tijdens het typen worden alleen
// de gewijzigde cel + de cursorcel bijgewerkt (geen flikkering).
//========================================================

.const EDW = 32                  // tekstbreedte (kolommen)
.const EDH = 16                  // tekstregels  (rijen 3..18; kader rij 2..19)
.label edPtr = $3a               // zeropage-pointer

// ed_Init - buffer met spaties vullen, cursor naar 0,0.
ed_Init:
        lda #0
        sta edCol
        sta edRow
        ldx #0
!lp:    lda #$20
        sta edBuf,x
        sta edBuf + 256,x        // edBuf[0..511] = 512 cellen (32x16)
        inx
        bne !lp-
        rts

//--------------------------------------------------------
// ed_Draw - het hele tekstveld tekenen (op app-activatie).
//--------------------------------------------------------
ed_Draw:
        // (het Win95-venster levert titelbalk + kader; tekstveld 3..34 x 3..18)
        lda #0
        sta edRowIdx
rowLoop:
        lda edRowIdx
        cmp #EDH
        bcc rowGo
        rts
rowGo:
        lda #0
        sta edColIdx
colLoop:
        lda edColIdx
        cmp #EDW
        bcc colGo
        inc edRowIdx
        jmp rowLoop
colGo:
        lda edColIdx
        sta edDCol
        lda edRowIdx
        sta edDRow
        jsr ed_DrawCell
        inc edColIdx
        jmp colLoop

//--------------------------------------------------------
// ed_DrawCell - teken één cel (edDCol,edDRow); cursorstijl als
//               die cel de cursorpositie is.
//--------------------------------------------------------
ed_DrawCell:
        lda edDRow
        jsr edSetPtr
        ldy edDCol
        lda (edPtr),y
        sta edChar
        lda edDCol
        clc
        adc #3
        sta a0
        lda edDRow
        clc
        adc #3
        sta a1
        lda edChar
        sta a2
        lda TH_text
        sta a3
        lda edDRow
        cmp edRow
        bne notCur
        lda edDCol
        cmp edCol
        bne notCur
        lda edChar
        ora #$80
        sta a2
        lda #LIGHT_GREEN
        sta a3
notCur:
        jmp gfx_PutChar          // rts van PutChar keert terug naar aanroeper

//--------------------------------------------------------
// edSetPtr - edPtr = edBuf + row*32  (row in A).
//--------------------------------------------------------
edSetPtr:
        sta edTmp
        lda #0
        sta edPtr+1
        lda edTmp
        asl
        rol edPtr+1
        asl
        rol edPtr+1
        asl
        rol edPtr+1
        asl
        rol edPtr+1
        asl
        rol edPtr+1
        sta edPtr
        lda edPtr
        clc
        adc #<edBuf
        sta edPtr
        lda edPtr+1
        adc #>edBuf
        sta edPtr+1
        rts

//--------------------------------------------------------
// ed_Key - toets verwerken (evtA = schermcode of $80/$81).
//--------------------------------------------------------
ed_Key:
        lda evtA
        cmp #$80                 // RETURN
        beq edRet
        cmp #$81                 // DEL
        beq edDel
        // printbaar teken: opslaan op cursor, cursor door
        lda edCol
        sta edOCol
        lda edRow
        sta edORow
        lda edRow
        jsr edSetPtr
        ldy edCol
        lda evtA
        sta (edPtr),y
        inc edCol
        lda edCol
        cmp #EDW
        bcc edUpd
        lda #0
        sta edCol
        inc edRow
        lda edRow
        cmp #EDH
        bcc edUpd
        dec edRow
        lda #[EDW-1]
        sta edCol
edUpd:
        jsr edRefresh
        rts

edRet:
        lda edCol
        sta edOCol
        lda edRow
        sta edORow
        lda #0
        sta edCol
        inc edRow
        lda edRow
        cmp #EDH
        bcc edRetU
        dec edRow
edRetU:
        jsr edRefresh
        rts

edDel:
        lda edCol
        sta edOCol
        lda edRow
        sta edORow
        lda edCol
        beq edDelPrev
        dec edCol
        jmp edDelClear
edDelPrev:
        lda edRow
        beq edDelDone
        dec edRow
        lda #[EDW-1]
        sta edCol
edDelClear:
        lda edRow
        jsr edSetPtr
        ldy edCol
        lda #$20
        sta (edPtr),y
        jsr edRefresh
edDelDone:
        rts

// edRefresh - werk de oude cursorcel + de nieuwe cursorcel bij.
edRefresh:
        lda edOCol
        sta edDCol
        lda edORow
        sta edDRow
        jsr ed_DrawCell
        lda edCol
        sta edDCol
        lda edRow
        sta edDRow
        jmp ed_DrawCell

//--------------------------------------------------------
edCol:    .byte 0
edRow:    .byte 0
edOCol:   .byte 0
edORow:   .byte 0
edDCol:   .byte 0
edDRow:   .byte 0
edChar:   .byte 0
edTmp:    .byte 0
edRowIdx: .byte 0
edColIdx: .byte 0
edBuf:    .fill EDW * EDH, $20
