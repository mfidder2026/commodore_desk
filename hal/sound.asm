#importonce
//========================================================
// hal/sound.asm - SID-geluid (Fase 10)
// Commodore Desk 64
//
// Korte klik-feedback via SID-stem 1 (ruis + snelle decay).
//========================================================

.label SID_V1_FREQ_LO = $d400
.label SID_V1_FREQ_HI = $d401
.label SID_V1_CTRL    = $d404
.label SID_V1_AD      = $d405
.label SID_V1_SR      = $d406
.label SID_VOLUME     = $d418

// sid_Init - volume aan, stem 1 envelope voor korte tik.
sid_Init:
        lda #$0f
        sta SID_VOLUME
        lda #$00
        sta SID_V1_FREQ_LO
        lda #$40
        sta SID_V1_FREQ_HI
        lda #$08                 // attack 0, decay 8
        sta SID_V1_AD
        lda #$00                 // sustain 0, release 0
        sta SID_V1_SR
        lda #$00
        sta SID_V1_CTRL
        rts

// sid_Click - korte klik (retrigger van de envelope).
sid_Click:
        lda #$00
        sta SID_V1_CTRL          // gate uit (retrigger)
        lda #$81                 // ruis + gate aan
        sta SID_V1_CTRL
        rts
