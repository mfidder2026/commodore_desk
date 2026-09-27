//========================================================
// Commodore Desk 64 - dummy_main.asm
// Klein plaatsvervangend programma: "HIER KOMT <naam>", een toets, terug.
//
// Bouwen met de naam als commandoregelvariabele, bijvoorbeeld:
//   java -jar KickAss.jar dummy_main.asm :name="C64 CITY" -o build\c64cdesk.prg
// De launcher start het via de SYS-regel als subroutine: RTS = terug naar
// CD64. Geen KERNAL-IRQ nodig: het toetsenbord wordt direct gelezen.
//========================================================
.var name = cmdLineVars.get("name")
.if (name == null) .eval name = "APPLICATION"

.const BLUE_C  = 6
.const LBLUE_C = 14
.const WHITE_C = 1
.const line1Len = 10 + name.size()
.const line2Len = 17

BasicUpstart2(start)

start:  lda #0
        sta $d015                // geen sprites
        lda #$17                 // ROM-tekenset, hoofd- en kleine letters
        sta $d018
        lda #BLUE_C
        sta $d021
        lda #LBLUE_C
        sta $d020
        ldx #0
cl:     lda #$20
        sta $0400,x
        sta $0500,x
        sta $0600,x
        sta $06e8,x
        lda #WHITE_C
        sta $d800,x
        sta $d900,x
        sta $da00,x
        sta $dae8,x
        inx
        bne cl
        ldx #0
l1:     lda line1,x
        beq l2s
        sta $0400 + 11*40 + [40-line1Len]/2,x
        inx
        bne l1
l2s:    ldx #0
l2:     lda line2,x
        beq wait
        sta $0400 + 14*40 + [40-line2Len]/2,x
        inx
        bne l2
wait:   lda #$ff                 // toetsenbord: poort A uitgang
        sta $dc02
        lda #0
        sta $dc03
up:     lda #0                   // eerst alle toetsen los
        sta $dc00
        lda $dc01
        cmp #$ff
        bne up
dn:     lda #0                   // dan een toets indrukken
        sta $dc00
        lda $dc01
        cmp #$ff
        beq dn
        rts                      // terug naar CD64

.encoding "screencode_mixed"
line1:  .text "HIER KOMT " + name
        .byte 0
line2:  .text "druk op een toets"
        .byte 0
