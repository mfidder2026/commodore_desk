#importonce
//========================================================
// kernel/events.asm - event-queue (Fase 4)
// Commodore Desk 64
//
// Ringbuffer met 8 events. De IRQ-input (evt_GenMouse) schrijft
// naar de staart; de hoofdloop leest van de kop via evt_Poll.
// Elk event: type + kol + rij.
//========================================================

.const EVT_NONE      = 0
.const EVT_MOUSEDOWN = 1
.const EVT_MOUSEUP   = 2
.const EVT_KEY       = 3

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
        rts

//--------------------------------------------------------
evtHead:  .byte 0
evtTail:  .byte 0
evtType:  .fill EVT_QSIZE, 0
evtColB:  .fill EVT_QSIZE, 0
evtRowB:  .fill EVT_QSIZE, 0
pushCol:  .byte 0                // in-parameters voor evt_Push
pushRow:  .byte 0
evtA:     .byte 0                // uit-parameters van evt_Poll
evtB:     .byte 0
