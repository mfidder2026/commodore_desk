#importonce
//========================================================
// hal/disk.asm - IEC disk-toegang (Fase 7)
// Commodore Desk 64
//
// Leest de directory van device 8 via de KERNAL ("$"-kanaal).
// Belangrijk: onze raster-IRQ draait met uitgebankte ROMs. Voor
// KERNAL-calls bankt dir_Read KERNAL in EN zet de raster-IRQ uit,
// zodat de KERNAL-IRQ (die de raster-IRQ niet zou bevestigen) geen
// IRQ-storm veroorzaakt. Daarna weer terug naar onze toestand.
//========================================================

.const MAXDIR   = 18             // max. getoonde entries
.const NAME_MAX = 15             // max. naamlengte (excl. $ff)

.label bufPtr = $38             // zeropage-pointer (nodig voor (bufPtr),y)

// KERNAL-vectoren
.label K_SETLFS = $ffba
.label K_SETNAM = $ffbd
.label K_OPEN   = $ffc0
.label K_CLOSE  = $ffc3
.label K_CHKIN  = $ffc6
.label K_CLRCHN = $ffcc
.label K_CHRIN  = $ffcf
.label K_READST = $ffb7
.label K_LOAD   = $ffd5
.label K_SAVE   = $ffd8

// Config-blok = OS-vars $0200-$020F (LAY 0-6, font 7, thema 8-12,
// menuFill 13, text 14, profile 15).
.label CFG_START = $0200
.label CFG_END   = $0211

//--------------------------------------------------------
// dir_Read - lees de directory in dirBuf + dirPtr-tabel.
// Uit: dirCount = aantal entries.
//--------------------------------------------------------
dir_Read: {
        sei
        lda #0
        sta VIC_IRQ_EN           // raster-IRQ uit tijdens KERNAL-I/O
        sta $9d                  // KERNAL-meldingen uit
        jsr mem_KernalIn         // $36: KERNAL + I/O

        lda #1
        ldx #<name
        ldy #>name
        jsr K_SETNAM             // naam "$", lengte 1
        lda #1
        ldx #8
        ldy #0
        jsr K_SETLFS             // logisch 1, device 8, secondary 0
        jsr K_OPEN
        ldx #1
        jsr K_CHKIN

        lda #0
        sta dirCount
        lda #<dirBuf
        sta bufPtr
        lda #>dirBuf
        sta bufPtr+1

        jsr K_CHRIN              // laadadres overslaan (2 bytes)
        jsr K_CHRIN

nextLine:
        jsr K_CHRIN              // link-lo
        sta tmpA
        jsr K_READST
        beq nl1
        jmp endDir
nl1:    jsr K_CHRIN              // link-hi
        ora tmpA
        bne nl2
        jmp endDir               // link == 0 -> einde
nl2:    jsr K_CHRIN              // blokken-lo (genegeerd)
        jsr K_CHRIN              // blokken-hi
        lda #0
        sta gotName
        sta nameLen

scanLine:
        jsr K_CHRIN
        sta tmpA
        jsr K_READST
        beq sl1
        jmp endDir
sl1:    lda tmpA
        bne sl2
        jmp nextLine             // $00 -> regeleinde
sl2:    lda gotName
        bne notSearch
        // zoek open-quote
        lda tmpA
        cmp #$22
        beq foundQuote
        jmp scanLine
notSearch:
        cmp #1
        beq inName
        jmp scanLine             // naam klaar -> rest opeten

foundQuote:
        lda dirCount
        cmp #MAXDIR
        bcc fq1
        jmp scanLine             // vol -> niet opslaan
fq1:    ldx dirCount
        lda bufPtr
        sta dirPtrLo,x
        lda bufPtr+1
        sta dirPtrHi,x
        lda #1
        sta gotName
        lda #0
        sta nameLen
        jmp scanLine

inName:
        lda tmpA
        cmp #$22                 // sluit-quote
        beq closeName
        lda nameLen
        cmp #NAME_MAX
        bcc in1
        jmp scanLine             // naam vol
in1:    lda tmpA
        jsr petscii2screen
        ldy #0
        sta (bufPtr),y
        inc bufPtr
        bne skip1
        inc bufPtr+1
skip1:  inc nameLen
        jmp scanLine

closeName:
        lda #$ff                 // naam-terminator
        ldy #0
        sta (bufPtr),y
        inc bufPtr
        bne skip2
        inc bufPtr+1
skip2:  inc dirCount
        lda #2
        sta gotName
        jmp scanLine

endDir:
        jsr K_CLRCHN
        lda #1
        jsr K_CLOSE

        jsr mem_AllRam           // $35: terug naar onze toestand
        lda #$01
        sta VIC_IRQ              // pending raster-IRQ wissen
        sta VIC_IRQ_EN           // raster-IRQ weer aan
        cli
        rts

name:   .byte $24                // "$"
}

//--------------------------------------------------------
// petscii2screen - PETSCII in A -> schermcode (letters/cijfers).
//--------------------------------------------------------
petscii2screen: {
        cmp #$41
        bcc keep                 // < 'A'
        cmp #$5b
        bcc upper                // 'A'-'Z'
        cmp #$61
        bcc keep                 // $5B-$60
        cmp #$7b
        bcc lower                // 'a'-'z'
keep:   rts
upper:  sec
        sbc #$40
        rts
lower:  sec
        sbc #$60
        rts
}

//--------------------------------------------------------
// cfg_io_begin / cfg_io_end - KERNAL inbanken + raster-IRQ pauzeren
// rondom disk-I/O. Werkt zowel bij boot (IRQ nog uit) als later
// (IRQ aan) door de vorige VIC_IRQ_EN-staat te bewaren.
//--------------------------------------------------------
cfg_io_begin:
        sei
        lda VIC_IRQ_EN
        sta savedIrqEn
        lda #0
        sta VIC_IRQ_EN
        sta $9d                  // KERNAL-meldingen uit (geen scherm-editor nodig)
        jsr mem_KernalIn
        rts
cfg_io_end:
        jsr mem_AllRam
        lda #$01
        sta VIC_IRQ
        lda savedIrqEn
        sta VIC_IRQ_EN
        cli
        rts

//--------------------------------------------------------
// cfg_Save - schrijf het config-blok naar "@0:CD64.CFG".
//--------------------------------------------------------
cfg_Save: {
        jsr cfg_io_begin
        lda #[nameSaveEnd - nameSave]
        ldx #<nameSave
        ldy #>nameSave
        jsr K_SETNAM
        lda #0
        ldx #8
        ldy #0
        jsr K_SETLFS
        lda #<CFG_START          // startpointer in $fb/$fc
        sta $fb
        lda #>CFG_START
        sta $fc
        lda #$fb                 // A = zp-offset van de startpointer
        ldx #<CFG_END
        ldy #>CFG_END
        jsr K_SAVE
        jsr cfg_io_end
        rts
nameSave: .encoding "petscii_upper"
          .text "@0:CD64.CFG"
nameSaveEnd:
}

//--------------------------------------------------------
// cfg_Load - laad "CD64.CFG" naar zijn laadadres ($0200).
//            Bestaat het niet, dan blijven de defaults staan.
//--------------------------------------------------------
cfg_Load: {
        jsr cfg_io_begin
        lda #[nameLoadEnd - nameLoad]
        ldx #<nameLoad
        ldy #>nameLoad
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #1                   // sa=1 -> gebruik laadadres uit bestand
        jsr K_SETLFS
        lda #0
        ldx #0
        ldy #0
        jsr K_LOAD
        jsr cfg_io_end
        rts
nameLoad: .encoding "petscii_upper"
          .text "CD64.CFG"
nameLoadEnd:
}

//--------------------------------------------------------
// loadApp - laad app-overlay (X = index 0-4) naar $8000.
//           De app-PRG's hebben laadadres $8000 (secondary 1).
//--------------------------------------------------------
loadApp:
        stx loadIdx
        jsr cfg_io_begin
        ldx loadIdx
        lda appLen,x
        pha
        lda appPtrLo,x
        pha
        lda appPtrHi,x
        tay
        pla
        tax                      // X = naam-lo
        pla                      // A = lengte
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #1                   // sa=1 -> laadadres uit bestand ($8000)
        jsr K_SETLFS
        lda #0
        jsr K_LOAD               // carry=1 bij fout (bestand niet gevonden)
        bcs !err+
        jsr cfg_io_end           // (zet interrupts weer aan via cli)
        clc
        rts
!err:   jsr cfg_io_end
        sec
        rts

//--------------------------------------------------------
// loadCharset - laad een font-charset (X = disk-font index) naar zijn
//               laadadres ($3800). Carry=1 bij fout.
//--------------------------------------------------------
loadCharset:
        stx loadIdx
        jsr cfg_io_begin
        ldx loadIdx
        lda fntLen,x
        pha
        lda fntPtrLo,x
        pha
        lda fntPtrHi,x
        tay
        pla
        tax
        pla
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #1                   // sa=1 -> laadadres uit bestand ($3800)
        jsr K_SETLFS
        lda #0
        jsr K_LOAD
        bcs !err+
        jsr cfg_io_end
        clc
        rts
!err:   jsr cfg_io_end
        sec
        rts

appPtrLo: .byte <anFiles, <anEdit, <anPaint, <anCalc, <anSetup
appPtrHi: .byte >anFiles, >anEdit, >anPaint, >anCalc, >anSetup
appLen:   .byte 5, 6, 5, 4, 5
fntPtrLo: .byte <anFremen, <anSerif, <anMono, <anCasual, <anHeavy
fntPtrHi: .byte >anFremen, >anSerif, >anMono, >anCasual, >anHeavy
fntLen:   .byte 6, 5, 4, 6, 5
.encoding "petscii_upper"
anFiles:  .text "FILES"
anEdit:   .text "EDITOR"
anPaint:  .text "PAINT"
anCalc:   .text "CALC"
anSetup:  .text "SETUP"
anFremen: .text "FREMEN"
anSerif:  .text "SERIF"
anMono:   .text "MONO"
anCasual: .text "CASUAL"
anHeavy:  .text "HEAVY"
loadIdx:  .byte 0

//--------------------------------------------------------
dirCount:  .byte 0
tmpA:      .byte 0
savedIrqEn: .byte 0
gotName:   .byte 0
nameLen:   .byte 0
dirPtrLo:  .fill MAXDIR, 0
dirPtrHi:  .fill MAXDIR, 0
dirBuf:    .fill MAXDIR * [NAME_MAX+1], 0
