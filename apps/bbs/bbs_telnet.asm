#importonce
//========================================================
// apps/bbs/bbs_telnet.asm - Telnet-parser (bouwplan Increment 3, §15-20)
// Commodore Desk 64
//
// Elke ontvangen byte gaat eerst door tn_Byte. De toestand blijft
// bewaard tussen TCP-pakketten, dus een IAC-reeks mag over pakketten
// verdeeld zijn. Commando's komen nooit op het scherm.
//
// Beleid (conservatief, §18):
//   server WILL  BINARY/ECHO/SGA -> DO     (ECHO: lokale echo uit)
//   server WILL  anders          -> DONT
//   server DO    BINARY/SGA/TTYPE/NAWS -> WILL  (NAWS: meteen 40x24)
//   server DO    anders          -> WONT
//   WONT/DONT: alleen bevestigen als de optie aan stond (geen lussen).
//   SB TTYPE SEND -> "PETSCII" (ASCII-entries: "DUMB").
//
// Antwoorden worden NIET direct verstuurd: tn_Byte draait midden in de
// ontvangst (RX-buffer in gebruik). Ze gaan via tm_TxPut in tmTx en de
// terminal-lus verstuurt ze (tm_Flush).
//========================================================

.const TN_IAC  = $ff
.const TN_DONT = $fe
.const TN_DO   = $fd
.const TN_WONT = $fc
.const TN_WILL = $fb
.const TN_SB   = $fa
.const TN_SE   = $f0
.const TO_BINARY = 0
.const TO_ECHO   = 1
.const TO_SGA    = 3
.const TO_TTYPE  = 24
.const TO_NAWS   = 31
.const TN_OPTS   = 32            // opties 0-31 krijgen een toestand
.const TN_SBMAX  = 8             // alleen het begin van een SB is nodig

// toestanden
.const TS_DATA  = 0
.const TS_IAC   = 1
.const TS_OPT   = 2              // na WILL/WONT/DO/DONT: optiebyte
.const TS_SB    = 3
.const TS_SBIAC = 4

// tn_Reset - nieuwe sessie: alle opties uit.
tn_Reset: {
        lda #TS_DATA
        sta tnState
        ldx #TN_OPTS-1
        lda #0
lp:     sta tnHim,x
        sta tnUs,x
        dex
        bpl lp
        rts
}

// tn_Byte - A = ontvangen byte. Uit: carry=1 -> A is data voor het
//           scherm; carry=0 -> byte hoorde bij een Telnet-commando.
tn_Byte: {
        ldx tnState
        bne st
        cmp #TN_IAC
        beq iac
        sec
        rts
iac:    lda #TS_IAC
        sta tnState
        clc
        rts
st:     cpx #TS_IAC
        bne s2
        ldx #TS_DATA             // IAC x
        stx tnState
        cmp #TN_IAC              // IAC IAC = data $FF
        bne c1
        sec
        rts
c1:     cmp #TN_SB
        bne c2
        lda #TS_SB
        sta tnState
        lda #0
        sta tnSbLen
        clc
        rts
c2:     cmp #TN_WILL             // WILL/WONT/DO/DONT ($FB-$FE)
        bcc no                   // NOP, GA, AYT enz.: negeren
        sta tnVerb
        lda #TS_OPT
        sta tnState
no:     clc
        rts
s2:     cpx #TS_OPT
        bne s3
        sta tnOpt
        lda #TS_DATA
        sta tnState
        jsr tn_Opt
        clc
        rts
s3:     cpx #TS_SB
        bne s4
        cmp #TN_IAC
        bne sb
        lda #TS_SBIAC
        sta tnState
        clc
        rts
sb:     ldx tnSbLen              // (te lang: de rest weggooien)
        cpx #TN_SBMAX
        bcs sx
        sta tnSb,x
        inc tnSbLen
sx:     clc
        rts
s4:     cmp #TN_IAC              // SB ... IAC IAC = data $FF in de SB
        bne s5
        ldx #TS_SB
        stx tnState
        jmp sb
s5:     ldx #TS_DATA             // IAC SE (of iets anders): SB klaar
        stx tnState
        cmp #TN_SE
        bne sx
        jsr tn_SbDone
        clc
        rts
}

// tn_Opt - tnVerb + tnOpt afhandelen.
tn_Opt: {
        lda tnVerb
        cmp #TN_WILL
        bne v2
        jsr himOk                // server wil de optie aanzetten
        bcc dont
        ldx tnOpt
        lda tnHim,x
        bne done                 // stond al aan: niet opnieuw antwoorden
        lda #1
        sta tnHim,x
        lda #TN_DO
        jmp tn_Reply
dont:   lda #TN_DONT
        jmp tn_Reply
v2:     cmp #TN_WONT
        bne v3
        ldx tnOpt
        cpx #TN_OPTS
        bcs done
        lda tnHim,x
        beq done
        lda #0
        sta tnHim,x
        lda #TN_DONT
        jmp tn_Reply
v3:     cmp #TN_DO
        bne v4
        jsr usOk                 // server vraagt ons de optie aan te zetten
        bcc wont
        ldx tnOpt
        lda tnUs,x
        bne done
        lda #1
        sta tnUs,x
        lda #TN_WILL
        jsr tn_Reply
        lda tnOpt
        cmp #TO_NAWS
        bne done
        jmp tn_Naws
wont:   lda #TN_WONT
        jmp tn_Reply
v4:     ldx tnOpt                // DONT
        cpx #TN_OPTS
        bcs done
        lda tnUs,x
        beq done
        lda #0
        sta tnUs,x
        lda #TN_WONT
        jmp tn_Reply
done:   rts

himOk:  lda tnOpt                // wat de server mag doen
        cmp #TO_BINARY
        beq y
        cmp #TO_ECHO
        beq y
        cmp #TO_SGA
        beq y
        clc
        rts
usOk:   lda tnOpt                // wat wij doen
        cmp #TO_BINARY
        beq y
        cmp #TO_SGA
        beq y
        cmp #TO_TTYPE
        beq y
        cmp #TO_NAWS
        beq y
        clc
        rts
y:      sec
        rts
}

// tn_Reply - IAC <A> <tnOpt> in de zendrij.
tn_Reply:
        pha
        lda #TN_IAC
        jsr tm_TxPut
        pla
        jsr tm_TxPut
        lda tnOpt
        jmp tm_TxPut

// tn_Naws - venstergrootte: 40 kolommen, 24 regels (rij 24 = status).
tn_Naws: {
        ldx #0
lp:     lda naws,x
        jsr tm_TxPut
        inx
        cpx #9
        bne lp
        rts
naws:   .byte TN_IAC, TN_SB, TO_NAWS, 0, 40, 0, 24, TN_IAC, TN_SE
}

// tn_SbDone - subonderhandeling klaar: alleen TERMINAL-TYPE SEND.
tn_SbDone: {
        lda tnSbLen
        cmp #2
        bcc out
        lda tnSb
        cmp #TO_TTYPE
        bne out
        lda tnSb+1
        cmp #1                   // SEND
        bne out
        ldx #0                   // IAC SB TTYPE IS <naam> IAC SE
lp:     lda ttHead,x
        jsr tm_TxPut
        inx
        cpx #4
        bne lp
        ldx #0
        lda tmAscii
        beq nm
        ldx #ttDumb-ttPet
nm:     lda ttPet,x
        beq end
        jsr tm_TxPut
        inx
        bne nm
end:    lda #TN_IAC
        jsr tm_TxPut
        lda #TN_SE
        jmp tm_TxPut
out:    rts
ttHead: .byte TN_IAC, TN_SB, TO_TTYPE, 0
.encoding "ascii"
ttPet:  .text "PETSCII"
        .byte 0
ttDumb: .text "DUMB"
        .byte 0
.encoding "screencode_upper"
}

//--------------------------------------------------------
tnState: .byte 0
tnVerb:  .byte 0
tnOpt:   .byte 0
tnSbLen: .byte 0
tnSb:    .fill TN_SBMAX, 0
tnHim:   .fill TN_OPTS, 0        // server heeft de optie aan (WILL -> DO)
tnUs:    .fill TN_OPTS, 0        // wij hebben de optie aan (DO -> WILL)
