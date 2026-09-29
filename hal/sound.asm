#importonce
//========================================================
// hal/sound.asm - SID-geluid
// Commodore Desk 64
//
// Kort, zacht piepje als klik-feedback via SID-stem 1 (driehoeksgolf,
// laag volume, snelle decay). Aan/uit via CFG_sound (Settings).
//========================================================

.label SID_V1_FREQ_LO = $d400
.label SID_V1_FREQ_HI = $d401
.label SID_V1_CTRL    = $d404
.label SID_V1_AD      = $d405
.label SID_V1_SR      = $d406
.label SID_VOLUME     = $d418

// sid_Init - laag volume, stem 1 envelope voor een kort zacht piepje.
sid_Init:
        lda #$06                 // zacht master-volume (was $0f = hard)
        sta SID_VOLUME
        lda #$00
        sta SID_V1_FREQ_LO
        lda #$28                 // ~hoog piepje
        sta SID_V1_FREQ_HI
        lda #$05                 // attack 0, decay 5 (kort)
        sta SID_V1_AD
        lda #$00                 // sustain 0, release 0
        sta SID_V1_SR
        lda #$00
        sta SID_V1_CTRL
        rts

// sid_Click - kort piepje (driehoek), alleen als geluid aanstaat.
sid_Click:
        lda CFG_sound
        beq !off+
        lda #$10                 // gate uit (retrigger), driehoek
        sta SID_V1_CTRL
        lda #$11                 // driehoeksgolf + gate aan
        sta SID_V1_CTRL
!off:   rts
