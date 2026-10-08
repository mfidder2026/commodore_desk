#importonce
//========================================================
// kernel/events.asm - event-queue (Fase 4)
// Commodore Desk 64
//
// Ringbuffer met 8 events. De IRQ-input (evt_GenMouse) schrijft
// naar de staart; de hoofdloop leest van de kop via evt_Poll.
// Elk event: type + kol + rij.
//========================================================

// (EVT_*-typen staan in include/events.inc)

.const EVT_QSIZE = 8             // moet een macht van 2 zijn

// evt_Init - queue leegmaken.
evt_Init:
        lda #0
        sta evtHead
        sta evtTail
        rts

// evt_Push - voeg een event toe (vanuit de IRQ).
// In: A=type, pushCol, pushRow
// Klobbert: X
evt_Push:
        ldx evtTail
        sta evtType,x
        lda pushCol
        sta evtColB,x
        lda pushRow
        sta evtRowB,x
        txa
        clc
        adc #1
        and #[EVT_QSIZE-1]
        sta evtTail
        rts

// evt_Poll - haal het volgende event op (hoofdloop).
// Uit: A=type (EVT_NONE als leeg), evtA=kol, evtB=rij
// Klobbert: X
evt_Poll:
        lda evtHead
        cmp evtTail
        bne !have+
        lda #EVT_NONE
        rts
!f1:    jsr help_Show            // F1: hulp (bewaart en herstelt het scherm)
        lda #EVT_NONE
        rts
!have:
        ldx evtHead
        lda evtColB,x
        sta evtA
        lda evtRowB,x
        sta evtB
        lda evtType,x
        pha
        txa
        clc
        adc #1
        and #[EVT_QSIZE-1]
        sta evtHead
        pla
        cmp #EVT_KEY             // F1 overal opvangen (behalve als dat
        bne !r+                  // niet kan, zie help_Show)
        ldx evtA
        cpx #$83
        bne !r+
        ldx helpBusy
        bne !r+
        ldx helpOff
        bne !r+
        ldx activeApp
        cpx #2                   // Paint: bitmapmodus
        bne !f1-
!r:     rts

//--------------------------------------------------------
evtHead:  .byte 0
evtTail:  .byte 0
// de wachtrij in vrij RAM (niet in de Core): $C0B8-$C0CF
.label evtType = $c0b8
.label evtColB = $c0c0
.label evtRowB = $c0c8
.assert "wachtrij past", EVT_QSIZE <= 8, true
pushCol:  .byte 0                // in-parameters voor evt_Push
pushRow:  .byte 0
evtA:     .byte 0                // uit-parameters van evt_Poll
evtB:     .byte 0
