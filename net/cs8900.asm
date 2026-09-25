#importonce
//========================================================
// net/cs8900.asm - CS8900a via RR-Net (Milestone 1: detectie)
// Commodore Desk 64
//
// Zet de clockport aan en leest PacketPage $0000 (product-ID
// $630E) en $0002 (revisie in bits 12-8).
//========================================================

// -----------------------------------------------------
// cs_Detect
// In:  -
// Uit: carry=1 gevonden (csRev = revisie), carry=0 niet
// Klobbert: A
// -----------------------------------------------------
cs_Detect: {
        lda RR_CTRL              // Retro Replay: clockport aan
        ora #$01
        sta RR_CTRL
        lda #$00                 // PacketPage $0000: product-ID
        sta CS_PPPTR
        sta CS_PPPTR+1
        lda CS_PPDATA
        cmp #CS_PRODUCT_LO
        bne none
        lda CS_PPDATA+1
        cmp #CS_PRODUCT_HI
        bne none
        lda #$02                 // PacketPage $0002: product/revisie
        sta CS_PPPTR
        lda #$00
        sta CS_PPPTR+1
        lda CS_PPDATA+1
        and #$1f
        sta csRev
        sec
        rts
none:   clc
        rts
}

csRev:  .byte 0
