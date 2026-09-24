#importonce
//========================================================
// kernel/memory.asm - geheugenconfiguratie ($01)
// Commodore Desk 64
//
// Fase 1: we bannen BASIC + KERNAL uit zodat we maximaal RAM
// en een schone hardware-IRQ-vector ($FFFE in RAM) hebben. Voor
// disk-I/O bankt de disk-driver KERNAL tijdelijk terug in.
//========================================================

// mem_AllRam - RAM overal, alleen I/O zichtbaar ($D000-$DFFF).
//   $35 = LORAM=1, HIRAM=0, CHAREN=1 -> BASIC+KERNAL uit, I/O aan.
// Klobbert: A
mem_AllRam:
        lda #$35
        sta CPU_PORT
        rts

// mem_KernalIn - KERNAL + I/O zichtbaar (BASIC uit) voor KERNAL-calls.
//   $36 = LORAM=0, HIRAM=1, CHAREN=1.
// Klobbert: A
mem_KernalIn:
        lda #$36
        sta CPU_PORT
        rts
