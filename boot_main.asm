//========================================================
// boot_main.asm - Windows-95-stijl bootscherm (los programma)
// Commodore Desk 64
//
// Dit is een APART laadprogramma dat als eerste opstart. Het toont een
// multicolor-bitmap bootscherm (VIC-bank 1, bitmap $6000 / matrix $4000),
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
        // ---- kleuren-RAM -> $D800 (4 pagina's) ----
        lda #<srcCol
        sta $fb
        lda #>srcCol
        sta $fc
        lda #$00
        sta $fd
        lda #$d8
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
        // ---- VIC: multicolor bitmap, bank 1 ----
        lda #6
        sta $d021                // achtergrond = blauw (bitpaar 00)
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
        lda #$d8                 // multicolor aan, 40 kolommen
        sta $d016
        cli
        // ---- wacht op een willekeurige toets ----
        jsr waitKey
        // ---- keten-stub naar $0334 kopiëren en starten ----
        ldx #0
!c:     lda chainSrc,x
        sta $0334,x
        inx
        cpx #chainLen
        bne !c-
        jmp $0334

//--------------------------------------------------------
// waitKey - wacht tot een toets ingedrukt is (CIA1-matrix).
//--------------------------------------------------------
waitKey:
        lda #$00
        sta $dc00                // alle kolommen laag
!w:     lda $dc01
        cmp #$ff
        beq !w-                  // $ff = niets ingedrukt
        rts

//--------------------------------------------------------
// Ingesloten bootscherm (multicolor-bitmap, uit design/bootscreen.png).
//--------------------------------------------------------
srcBmp: .import binary "data/boot_bmp.bin"
srcScr: .import binary "data/boot_scr.bin"
srcCol: .import binary "data/boot_col.bin"
