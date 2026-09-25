//========================================================
// cowboy_main.asm - voorbeeld standalone-PRG voor de launcher
// Commodore Desk 64
//
// Laadt op $0801 (SYS 2061), toont een eigen scherm en keert bij een
// toets terug naar het bureaublad door "CD64" te herladen. Draait als
// gewone C64-PRG met de KERNAL beschikbaar.
//========================================================
        *=$0801
        BasicUpstart2($080d)     // 10 SYS 2061

        *=$080d
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
        beq !wait+
        jsr $ffd2                // CHROUT
        inx
        bne !lp-
!wait:  jsr $ffe4                // GETIN
        beq !wait-
        // terug naar het bureaublad: CD64 herladen en starten
        lda #4
        ldx #<dname
        ldy #>dname
        jsr $ffbd                // SETNAM
        lda #1
        ldx #8
        ldy #1
        jsr $ffba                // SETLFS
        lda #0
        jsr $ffd5                // LOAD "CD64",8,1
        jmp $0810                // start CD64 (kernel_Init)

.encoding "petscii_upper"
dname:  .text "CD64"

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
        .text "     PRESS ANY KEY TO RETURN..."
        .byte $00
