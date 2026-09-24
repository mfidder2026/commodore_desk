//========================================================
// boot_main.asm - Windows-95-stijl bootscherm (los programma)
// Commodore Desk 64
//
// Dit is een APART laadprogramma dat als eerste opstart. Het toont een
// hi-res bitmap bootscherm (scherp, VIC-bank 1, bitmap $6000 / matrix $4000),
// wacht op een toets en laadt daarna "CD64" - het echte bureaublad -
// dat over dit programma heen laadt. Zo kost het bootscherm GEEN geheugen
// in de draaiende Commodore Desk: de plaatjesdata zit alleen in dit
// laadprogramma en verdwijnt zodra CD64 eroverheen laadt. De bitmap op
// $6000 blijft tijdens het laden zichtbaar (bank 1), waarna CD64 bij het
// opstarten terugschakelt naar char-mode.
//========================================================

*=$0801
BasicUpstart2(bootStart)

//--------------------------------------------------------
// chain-stub - draait vanaf $0334 (veilig onder CD64 @ $0801). Laadt
//              "CD64" en start het bureaublad. Wordt hierheen gekopieerd
//              zodat de LOAD dit programma zelf mag overschrijven.
//--------------------------------------------------------
chainSrc:
.pseudopc $0334 {
cstub:
        lda #0
        sta $9d                  // KERNAL-laadmeldingen uit
        lda #dnameEnd-dname
        ldx #<dname
        ldy #>dname
        jsr $ffbd                // SETNAM
        lda #1
        ldx #8
        ldy #1
        jsr $ffba                // SETLFS (secundair 1 = laad op eigen adres)
        lda #0
        jsr $ffd5                // LOAD
        jmp $0810                // start CD64 (kernel_Init)
.encoding "petscii_upper"
dname:  .text "CD64"
dnameEnd:
}
chainEnd:
.const chainLen = chainEnd - chainSrc

bootStart:
        sei
        // ---- bitmap -> $6000 (32 pagina's) ----
        lda #<srcBmp
        sta $fb
        lda #>srcBmp
        sta $fc
        lda #$00
        sta $fd
        lda #$60
        sta $fe
        ldx #32
        ldy #0
!b:     lda ($fb),y
        sta ($fd),y
        iny
        bne !b-
        inc $fc
        inc $fe
        dex
        bne !b-
        // ---- video-matrix -> $4000 (4 pagina's) ----
        lda #<srcScr
        sta $fb
        lda #>srcScr
        sta $fc
        lda #$00
        sta $fd
        lda #$40
        sta $fe
        ldx #4
        ldy #0
!b:     lda ($fb),y
        sta ($fd),y
        iny
        bne !b-
        inc $fc
        inc $fe
        dex
        bne !b-
        // ---- VIC: hi-res bitmap (scherp, 320x200), bank 1 ----
        lda #0
        sta $d020                // rand zwart
        lda $dd00
        and #$fc
        ora #%10                 // VIC-bank 1 ($4000-$7FFF)
        sta $dd00
        lda #$08                 // matrix $4000, bitmap $6000
        sta $d018
        lda #$3b                 // bitmapmodus aan, DEN, 25 rijen
        sta $d011
        lda #$c8                 // multicolor UIT, 40 kolommen (hi-res)
        sta $d016
        cli
        // ---- scannend laadlampje (auto, geen toets nodig) ----
        jsr scanLed
        // ---- keten-stub naar $0334 kopiëren en starten ----
        ldx #0
!c:     lda chainSrc,x
        sta $0334,x
        inx
        cpx #chainLen
        bne !c-
        jmp $0334

//--------------------------------------------------------
// scanLed - een licht dat op de onderste regel heen en weer scant
//           terwijl "geladen" wordt (~2,5 sec, daarna keten-load).
//           Rij 24 (py 192-199) van de bitmap; kleur lichtrood op blauw.
//--------------------------------------------------------
.label krPtr = $fb               // zeropage-pointer
scanLed:
        ldx #0                   // video-matrix rij 24 -> lichtrood/blauw
        lda #$a6
!m:     sta $43c0,x
        inx
        cpx #40
        bne !m-
        lda #0
        sta krPos
        lda #1
        sta krDir
        lda #60
        sta krFrames
krlp:   jsr krDraw
        jsr krDelay
        lda krDir
        bmi !left+
        inc krPos                // naar rechts
        lda krPos
        cmp #37
        bcc !nx+
        lda #$ff
        sta krDir
        jmp !nx+
!left:  dec krPos                // naar links
        lda krPos
        bne !nx+
        lda #1
        sta krDir
!nx:    dec krFrames
        bne krlp
        rts

// krDraw - wis rij-24 bitmap en teken het lampje (3 cellen) op krPos.
krDraw:
        lda krPos                // krPtr = $7E00 + krPos*8
        sta krTmp
        lda #0
        sta krTmp+1
        asl krTmp
        rol krTmp+1
        asl krTmp
        rol krTmp+1
        asl krTmp
        rol krTmp+1
        lda krTmp
        clc
        adc #<$7e00
        sta krPtr
        lda krTmp+1
        adc #>$7e00
        sta krPtr+1
        ldx #0                   // rij-24 bitmap wissen (320 bytes)
        lda #0
!a:     sta $7e00,x
        inx
        bne !a-
        ldx #0
!b:     sta $7f00,x
        inx
        cpx #$40
        bne !b-
        ldy #0                   // lampje: 3 cellen, rijen 2-5
!d:     tya
        and #7
        cmp #2
        bcc !off+
        cmp #6
        bcs !off+
        lda #$ff
        sta (krPtr),y
        jmp !ny+
!off:   lda #0
        sta (krPtr),y
!ny:    iny
        cpy #24
        bne !d-
        rts

krDelay:
        ldx #0
!o:     ldy #0
!i:     iny
        bne !i-
        inx
        cpx #$1a
        bne !o-
        rts

krPos:    .byte 0
krDir:    .byte 0
krFrames: .byte 0
krTmp:    .byte 0, 0

//--------------------------------------------------------
// Ingesloten bootscherm (multicolor-bitmap, uit design/bootscreen.png).
//--------------------------------------------------------
srcBmp: .import binary "data/boot_bmp.bin"
srcScr: .import binary "data/boot_scr.bin"
