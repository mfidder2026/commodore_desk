//========================================================
// cowboy_main.asm - GEWOON voorbeeld-PRG voor de launcher
// Commodore Desk 64
//
// Dit is een heel normaal C64-programma (laadt op $0801, SYS 2061).
// Het weet NIETS van Commodore Desk 64: het tekent een schermpje en
// blijft draaien. Terugkeren naar het bureaublad doet de gebruiker met
// de RESTORE-toets; die terugkeer regelt de launcher generiek, zodat
// elk net PRG werkt zonder dat je de code hoeft aan te passen.
//========================================================
        *=$0801
        BasicUpstart2(start)     // 10 SYS <start>

.encoding "petscii_upper"
start:
        lda #$06                 // blauw scherm/rand
        sta $d020
        sta $d021
        lda #$93                 // scherm wissen (CHROUT)
        jsr $ffd2
        lda #$05                 // witte tekst
        jsr $ffd2
        ldx #0
!lp:    lda msg,x
        beq !idle+
        jsr $ffd2                // CHROUT
        inx
        bne !lp-
!idle:  jmp !idle-               // gewoon blijven draaien

msg:    .byte $0d, $0d
        .text "         HOWDY, PARTNER!"
        .byte $0d, $0d, $0d
        .text "      .---."
        .byte $0d
        .text "      (O.O)   A LITTLE"
        .byte $0d
        .text "      (   )   EXAMPLE"
        .byte $0d
        .text "      -----   PROGRAM"
        .byte $0d, $0d, $0d
        .text "     LAUNCHED FROM THE DESKTOP!"
        .byte $0d, $0d
        .text "     PRESS RESTORE TO GO BACK."
        .byte $00
