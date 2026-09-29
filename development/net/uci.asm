#importonce
//========================================================
// net/uci.asm - Ultimate Command Interface (Milestone 1: detectie)
// Commodore Desk 64
//
// Het identificatieregister (base+1) geeft op een Ultimate $C9.
// Defensief: meerdere keren lezen, zodat een toevallige open-bus-
// waarde geen valse detectie geeft. Eerst $DF1C, dan $DE1C.
//========================================================

// -----------------------------------------------------
// uci_Detect
// In:  -
// Uit: carry=1 gevonden (uciBase = registerbasis), carry=0 niet
// Klobbert: A, Y
// -----------------------------------------------------
uci_Detect: {
        ldy #8
p1:     lda UCI_BASE+1
        cmp #UCI_ID
        bne alt
        dey
        bne p1
        lda #<UCI_BASE
        ldy #>UCI_BASE
        jmp found
alt:    ldy #8
p2:     lda UCI_ALT+1
        cmp #UCI_ID
        bne none
        dey
        bne p2
        lda #<UCI_ALT
        ldy #>UCI_ALT
found:  sta uciBase
        sty uciBase+1
        sec
        rts
none:   clc
        rts
}

uciBase: .word 0
