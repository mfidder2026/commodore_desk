#importonce
//========================================================
// apps/ramdisk.asm - RAM-drives voor de File Manager (REU, GeoRAM)
// Commodore Desk 64
//
// Een REU ($DF00) wordt drive R:30, een GeoRAM ($DE00, venster van
// 256 bytes) drive R:31. Beide worden als pagina's van 256 bytes
// gebruikt (max 2048 = 512 KB):
//   pagina 0-3   directory: slot 0 = kop ("CD64RD" + naam), 1-31 bestanden
//                (naam 16, lengte, type, eerste pagina (2), grootte (3))
//   pagina 4-    de bestanden, aaneengesloten in slotvolgorde
// Wissen schuift de bestanden erachter op, zodat er geen gaten zijn.
// Een RAM-drive is leeg na het uitzetten; een onbekende inhoud wordt
// bij het lezen geformatteerd.
//
// GeoRAM zit in dezelfde I/O-ruimte als de RR-Net en de EasyFlash: in de
// cartridge-build wordt niets gezocht, en met een RR-Net geen GeoRAM.
// De laatste twee GeoRAM-pagina's zijn voor het zoeken (niet gebruikt).
//========================================================

.label RD_DIR   = $6c00          // directory tijdens een actie (1 KB)
.const RD_DATA  = 4              // eerste datapagina
.const RD_SLOTS = 32
.const RS_LEN   = 16
.const RS_TYPE  = 17
.const RS_START = 18
.const RS_SIZE  = 20
.label rdS      = r4             // zeropage: slot
.label rdS2     = r5

// rd_Detect - REU en GeoRAM zoeken, als drive in de drivetabel zetten.
rd_Detect: {
        lda #0
        sta rdTot
        sta rdTot+1
        sta rdTot+2
        sta rdTot+3
        lda cartMode             // cartridge: $DE00/$DF00 zijn bezet
        bne r
        jsr reu_Probe
        jsr geo_Probe
r:      rts
}

// reu_Probe - REU-registers terug te lezen? Grootte via bankmarkeringen.
reu_Probe: {
        ldx #$55
        ldy #$aa
        jsr t
        beq fb748_0
        jmp no
fb748_0:
        ldx #$aa
        ldy #$55
        jsr t
        bne no
        lda #0
        sta rdKind
        sta rdPg
        lda #1
        sta rdLen
        lda #0
        sta rdLen+1
        ldx #0                   // byte 0 van bank 0-7 bewaren
sv:     stx rdPg+1
        jsr sadr
        lda #$91
        jsr reu_Xfer
        inx
        cpx #8
        bne sv
        lda #<rdMark
        sta rdAdr
        lda #>rdMark
        sta rdAdr+1
        ldx #7                   // markeren, van hoog naar laag
mk:     stx rdMark
        stx rdPg+1
        lda #$90
        jsr reu_Xfer
        dex
        bpl mk
        ldx #0                   // tellen zolang bank k = k
ck:     stx rdPg+1
        lda #$91
        jsr reu_Xfer
        lda rdMark
        cmp rdPg+1
        bne cd
        inx
        cpx #8
        bne ck
cd:     stx rdBanks
        ldx #0                   // terugzetten
rs:     stx rdPg+1
        jsr sadr
        lda #$90
        jsr reu_Xfer
        inx
        cpx #8
        bne rs
        lda rdBanks
        beq no
        sta rdTot+1              // pagina's = banken * 256
        lda #RD_REU
        ldx #0
        jmp rd_AddDrv
no:     rts
t:      stx $df02
        sty $df03
        cpx $df02
        bne tr
        cpy $df03
tr:     rts
sadr:   txa
        clc
        adc #<rdSave
        sta rdAdr
        lda #>rdSave
        adc #0
        sta rdAdr+1
        rts
}

// geo_Probe - eerst op de RR-Net letten (zelfde adressen), dan GeoRAM.
geo_Probe: {
        lda #63                  // parkeren op de laatste pagina
        sta $dffe
        lda #31
        sta $dfff
        lda #$01                 // RR-Net? (zoals cs_Detect)
        sta RR_CTRL
        lda #$00
        sta CS_PPPTR
        sta CS_PPPTR+1
        lda CS_PPDATA
        cmp #CS_PRODUCT_LO
        bne nrr
        lda CS_PPDATA+1
        cmp #CS_PRODUCT_HI
        bne nrr
        rts
nrr:    lda #62
        sta $dffe
        lda #$5a
        sta $de00
        lda #$a5
        sta $de01
        lda #63
        sta $dffe
        lda #$c3
        sta $de00
        lda #$3c
        sta $de01
        lda #62
        sta $dffe
        lda $de00
        cmp #$5a
        bne no
        lda $de01
        cmp #$a5
        bne no
        lda #63
        sta $dffe
        lda $de00
        cmp #$c3
        bne no
        lda #0                   // grootte: byte 2 van pagina 0 per blok
        sta $dffe
        ldx #0
sv:     stx $dfff
        lda $de02
        sta rdSave,x
        inx
        cpx #32
        bne sv
        ldx #31
mk:     stx $dfff
        stx $de02
        dex
        bpl mk
        ldx #0
ck:     stx $dfff
        cpx $de02
        bne cd
        inx
        cpx #32
        bne ck
cd:     stx rdBanks
        ldx #0
rs:     stx $dfff
        lda rdSave,x
        sta $de02
        inx
        cpx #32
        bne rs
        lda rdBanks              // pagina's = blokken * 64 - 2
        beq no
        lsr
        lsr
        sta rdTot+3
        lda rdBanks
        asl
        asl
        asl
        asl
        asl
        asl
        sec
        sbc #2
        sta rdTot+2
        bcs ad
        dec rdTot+3
ad:     lda #RD_GEO
        ldx #6
        jmp rd_AddDrv
no:     rts
}

// rd_AddDrv - device A, type-tekst rdTypes+X in de drivetabel.
rd_AddDrv: {
        stx rdT
        ldx drvCnt
        cpx #DRV_MAX
        bcs r
        sta drvDev,x
        txa
        asl
        asl
        asl
        tax
        ldy rdT
        lda #6
        sta rdT+1
c:      lda rdTypes,y
        sta drvTyp,x
        inx
        iny
        dec rdT+1
        bne c
        inc drvCnt
r:      rts
}

// reu_Xfer - REU-DMA: C64 rdAdr <-> REU pagina rdPg, rdLen bytes.
//            A = $90 schrijven naar de REU, $91 lezen.
reu_Xfer:
        pha
        lda rdAdr
        sta $df02
        lda rdAdr+1
        sta $df03
        lda #0
        sta $df04
        sta $df0a
        lda rdPg
        sta $df05
        lda rdPg+1
        sta $df06
        lda rdLen
        sta $df07
        lda rdLen+1
        sta $df08
        pla
        sta $df01
        rts

// geo_Sel - GeoRAM-venster op pagina rdPg.
geo_Sel:
        lda rdPg
        and #63
        sta $dffe
        lda rdPg+1
        sta rdT
        lda rdPg
        asl
        rol rdT
        asl
        rol rdT
        lda rdT
        sta $dfff
        rts

// rd_Get / rd_Put - pagina rdPg -> / <- rdAdr (256 bytes), drive rdKind.
rd_Get: {
        lda rdKind
        bne g
        jsr len
        lda #$91
        jmp reu_Xfer
g:      jsr geo_Sel
        lda rdAdr
        sta w+1
        lda rdAdr+1
        sta w+2
        ldy #0
l:      lda $de00,y
w:      sta $ffff,y
        iny
        bne l
        rts
len:    lda #0
        sta rdLen
        lda #1
        sta rdLen+1
        rts
}
rd_Put: {
        lda rdKind
        bne g
        jsr rd_Get.len
        lda #$90
        jmp reu_Xfer
g:      jsr geo_Sel
        lda rdAdr
        sta rr+1
        lda rdAdr+1
        sta rr+2
        ldy #0
rr:     lda $ffff,y
        sta $de00,y
        iny
        bne rr
        rts
}

// rd_GetN / rd_PutN - rdCnt pagina's vanaf rdPg / rdAdr (beide lopen op).
rd_GetN: {
        lda rdCnt
        beq r
l:      jsr rd_Get
        jsr rd_Next
        bne l
r:      rts
}
rd_PutN: {
        lda rdCnt
        beq r
l:      jsr rd_Put
        jsr rd_Next
        bne l
r:      rts
}
rd_Next:
        inc rdPg
        bne n
        inc rdPg+1
n:      inc rdAdr+1
        dec rdCnt
        rts

// rd_Use - rdKind voor device A.
rd_Use:
        sec
        sbc #RD_REU
        sta rdKind
        rts

// rd_Dir4 - rdPg=0, rdAdr=RD_DIR, rdCnt=4.
rd_Dir4:
        lda #0
        sta rdPg
        sta rdPg+1
        sta rdAdr
        lda #>RD_DIR
        sta rdAdr+1
        lda #4
        sta rdCnt
        rts

// rd_LoadDir - directory lezen (en formatteren als hij onbekend is),
//              daarna rdN (aantal bestanden) en rdEnd (eerste vrije pagina).
rd_LoadDir: {
        jsr rd_Dir4
        jsr rd_GetN
        ldx #5
m:      lda RD_DIR,x
        cmp rdMagic,x
        bne fmt
        dex
        bpl m
        jmp rd_Scan
fmt:    lda #0
        tax
cl:     sta RD_DIR,x
        sta RD_DIR+$100,x
        sta RD_DIR+$200,x
        sta RD_DIR+$300,x
        inx
        bne cl
        ldx #5
mc:     lda rdMagic,x
        sta RD_DIR,x
        dex
        bpl mc
        ldx #7
nm:     lda rdName,x
        sta RD_DIR+8,x
        dex
        bpl nm
        jsr rd_SaveDir
        jmp rd_Scan
}

rd_SaveDir:
        jsr rd_Dir4
        jmp rd_PutN

// rd_Slot - rdS = slot A.
rd_Slot:
        sta rdT
        lsr
        lsr
        lsr
        clc
        adc #>RD_DIR
        sta rdS+1
        lda rdT
        asl
        asl
        asl
        asl
        asl
        sta rdS
        rts

// rd_Scan - rdN = aantal bestanden, rdEnd = eerste vrije pagina.
rd_Scan: {
        ldx #1
l:      stx rdI
        cpx #RD_SLOTS
        bcs d
        txa
        jsr rd_Slot
        ldy #RS_LEN
        lda (rdS),y
        beq d
        ldx rdI
        inx
        bne l
d:      ldx rdI
        dex
        stx rdN
        lda #RD_DATA
        sta rdEnd
        lda #0
        sta rdEnd+1
        txa
        beq r
        jsr rd_Slot
        jsr rd_SlotPages
        ldy #RS_START
        lda (rdS),y
        clc
        adc rdP
        sta rdEnd
        iny
        lda (rdS),y
        adc rdP+1
        sta rdEnd+1
r:      rts
}

// rd_SlotPages - rdP = pagina's van slot rdS.
rd_SlotPages: {
        ldy #RS_SIZE+1
        lda (rdS),y
        sta rdP
        iny
        lda (rdS),y
        sta rdP+1
        ldy #RS_SIZE
        lda (rdS),y
        beq r
        inc rdP
        bne r
        inc rdP+1
r:      rts
}

// rd_Free - rdP = vrije pagina's.
rd_Free: {
        lda rdKind
        asl
        tax
        sec
        lda rdTot,x
        sbc rdEnd
        sta rdP
        lda rdTot+1,x
        sbc rdEnd+1
        sta rdP+1
        bcs r
        lda #0
        sta rdP
        sta rdP+1
r:      rts
}

// rd_Find - fileName/fileLen zoeken. Carry=1: gevonden (rdI, rdS).
rd_Find: {
        ldx #1
l:      stx rdI
        cpx #RD_SLOTS
        bcs no
        txa
        jsr rd_Slot
        ldy #RS_LEN
        lda (rdS),y
        beq no
        cmp fileLen
        bne nx
        ldy #0
c:      cpy fileLen
        bcs yes
        lda (rdS),y
        cmp fileName,y
        bne nx
        iny
        bne c
nx:     ldx rdI
        inx
        bne l
no:     clc
        rts
yes:    sec
        rts
}

//--------------------------------------------------------
// rd_FillPane - venster fmP vullen met de RAM-drive fmDev.
//--------------------------------------------------------
rd_FillPane: {
        lda fmDev
        jsr rd_Use
        jsr rd_LoadDir
        ldy #PN_NLEN
        lda #8
        sta (fmP),y
        ldx #0
        ldy #PN_NAME
n:      lda RD_DIR+8,x
        sta (fmP),y
        iny
        inx
        cpx #8
        bne n
        jsr rd_Free
        ldy #PN_FREE
        lda rdP
        sta (fmP),y
        iny
        lda rdP+1
        sta (fmP),y
        lda #0
        sta rdJ
e:      lda rdJ
        cmp rdN
        bcs r
        cmp #FM_MAX
        bcs r
        jsr fm_EntP
        lda rdJ
        clc
        adc #1
        jsr rd_Slot
        ldy #0
c:      lda (rdS),y              // naam, lengte, type
        sta (fmE),y
        iny
        cpy #RS_START
        bne c
        jsr rd_SlotPages
        ldy #FE_BLK
        lda rdP
        sta (fmE),y
        iny
        lda rdP+1
        sta (fmE),y
        inc rdJ
        lda rdJ
        ldy #PN_CNT
        sta (fmP),y
        jmp e
r:      rts
}

//--------------------------------------------------------
// Kopieren. Bron: rd_OpenSrc + rd_ReadChunk; doel: rd_NewBegin,
// rd_WriteChunk, rd_NewEnd. Eerst de bron openen: er is maar een
// directorybuffer, het doel houdt hem daarna vast.
//--------------------------------------------------------
rd_OpenSrc: {
        lda fileDev
        jsr rd_Use
        lda rdKind
        sta rdSrcK
        jsr rd_LoadDir
        jsr rd_Find
        bcc r
        ldy #RS_START
        lda (rdS),y
        sta rdSrcPg
        iny
        lda (rdS),y
        sta rdSrcPg+1
        ldy #RS_SIZE
        lda (rdS),y
        sta rdRem
        iny
        lda (rdS),y
        sta rdRem+1
        iny
        lda (rdS),y
        sta rdRem+2
        sec
r:      rts
}

// rd_ReadChunk - tot FM_BUFSZ bytes naar FM_BUF; fmN = aantal, fmEof.
rd_ReadChunk: {
        lda rdSrcK
        sta rdKind
        lda rdRem+2
        bne big
        lda rdRem+1
        cmp #>FM_BUFSZ
        bcs big
        lda rdRem
        sta fmN
        lda rdRem+1
        sta fmN+1
        jmp g
big:    lda #0
        sta fmN
        lda #>FM_BUFSZ
        sta fmN+1
g:      sec
        lda rdRem
        sbc fmN
        sta rdRem
        lda rdRem+1
        sbc fmN+1
        sta rdRem+1
        lda rdRem+2
        sbc #0
        sta rdRem+2
        ora rdRem+1
        ora rdRem
        bne nf
        lda #1
        sta fmEof
nf:     jsr rd_NPages
        lda rdSrcPg
        sta rdPg
        lda rdSrcPg+1
        sta rdPg+1
        jsr rd_Buf
        jsr rd_GetN
        lda rdPg
        sta rdSrcPg
        lda rdPg+1
        sta rdSrcPg+1
        rts
}

// rd_NPages - rdCnt = pagina's voor fmN bytes.
rd_NPages:
        lda fmN+1
        ldx fmN
        beq pz
        clc
        adc #1
pz:     sta rdCnt
        rts

rd_Buf:
        lda #<FM_BUF
        sta rdAdr
        lda #>FM_BUF
        sta rdAdr+1
        rts

// rd_NewBegin - nieuw bestand op RAM-drive fmDst. Carry=1: fout, X/Y = melding.
rd_NewBegin: {
        lda fmDst
        jsr rd_Use
        lda rdKind
        sta rdDstK
        jsr rd_LoadDir
        jsr rd_Find
        bcc nf
        ldx #<sRdExists
        ldy #>sRdExists
        sec
        rts
nf:     lda rdN
        cmp #RD_SLOTS-1
        bcc ok
        ldx #<sRdFull
        ldy #>sRdFull
        sec
        rts
ok:     lda rdEnd
        sta rdDstPg
        sta rdDst0
        lda rdEnd+1
        sta rdDstPg+1
        sta rdDst0+1
        lda #0
        sta rdSize
        sta rdSize+1
        sta rdSize+2
        clc
        rts
}

// rd_WriteChunk - fmN bytes uit FM_BUF erbij. Carry=0: drive vol.
rd_WriteChunk: {
        lda rdDstK
        sta rdKind
        jsr rd_NPages
        lda rdKind
        asl
        tax
        clc
        lda rdDstPg
        adc rdCnt
        sta rdT
        lda rdDstPg+1
        adc #0
        sta rdT+1
        lda rdTot,x
        cmp rdT
        lda rdTot+1,x
        sbc rdT+1
        bcs ok
        rts                      // carry=0 -> vol melden
ok:     lda rdDstPg
        sta rdPg
        lda rdDstPg+1
        sta rdPg+1
        jsr rd_Buf
        jsr rd_PutN
        lda rdPg
        sta rdDstPg
        lda rdPg+1
        sta rdDstPg+1
        clc
        lda rdSize
        adc fmN
        sta rdSize
        lda rdSize+1
        adc fmN+1
        sta rdSize+1
        lda rdSize+2
        adc #0
        sta rdSize+2
        sec
        rts
}

// rd_NewEnd - slot invullen en de directory opslaan.
rd_NewEnd: {
        lda rdDstK
        sta rdKind
        lda rdN
        clc
        adc #1
        jsr rd_Slot
        ldy #0
n:      lda #0
        cpy fileLen
        bcs z
        lda fileName,y
z:      sta (rdS),y
        iny
        cpy #16
        bne n
        lda fileLen
        sta (rdS),y              // RS_LEN
        iny
        lda fmTy
        and #$7f
        sta (rdS),y              // RS_TYPE
        iny
        lda rdDst0
        sta (rdS),y
        iny
        lda rdDst0+1
        sta (rdS),y
        iny
        lda rdSize
        sta (rdS),y
        iny
        lda rdSize+1
        sta (rdS),y
        iny
        lda rdSize+2
        sta (rdS),y
        jmp rd_SaveDir
}

//--------------------------------------------------------
// rd_Delete - fileName van RAM-drive fileDev wissen. X/Y = melding.
//--------------------------------------------------------
rd_Delete: {
        lda fileDev
        jsr rd_Use
        jsr rd_LoadDir
        jsr rd_Find
        bcs f
        ldx #<sRdNoFile
        ldy #>sRdNoFile
        rts
f:      jsr rd_SlotPages         // rdP = pagina's, rdDst0 = begin
        ldy #RS_START
        lda (rdS),y
        sta rdDst0
        iny
        lda (rdS),y
        sta rdDst0+1
        clc                      // bron = begin + pagina's
        lda rdDst0
        adc rdP
        sta rdSrcPg
        lda rdDst0+1
        adc rdP+1
        sta rdSrcPg+1
mv:     lda rdSrcPg              // bestanden erachter opschuiven
        cmp rdEnd
        lda rdSrcPg+1
        sbc rdEnd+1
        bcs sh
        lda rdSrcPg
        sta rdPg
        lda rdSrcPg+1
        sta rdPg+1
        jsr rd_Buf
        jsr rd_Get
        lda rdDst0
        sta rdPg
        lda rdDst0+1
        sta rdPg+1
        jsr rd_Put
        inc rdSrcPg
        bne m1
        inc rdSrcPg+1
m1:     inc rdDst0
        bne mv
        inc rdDst0+1
        jmp mv
sh:     lda rdI                  // slots erachter: begin -= pagina's
        sta rdJ
s1:     inc rdJ
        lda rdJ
        cmp #RD_SLOTS
        bcs sl
        jsr rd_Slot
        ldy #RS_LEN
        lda (rdS),y
        beq sl
        ldy #RS_START
        sec
        lda (rdS),y
        sbc rdP
        sta (rdS),y
        iny
        lda (rdS),y
        sbc rdP+1
        sta (rdS),y
        jmp s1
sl:     lda rdI                  // slots een plaats omlaag
        sta rdJ
s2:     lda rdJ
        cmp #RD_SLOTS-1
        bcs lst
        jsr rd_Slot
        lda rdS
        sta rdS2
        lda rdS+1
        sta rdS2+1
        lda rdJ
        clc
        adc #1
        jsr rd_Slot
        ldy #31
c2:     lda (rdS),y
        sta (rdS2),y
        dey
        bpl c2
        inc rdJ
        jmp s2
lst:    lda #RD_SLOTS-1          // laatste slot leeg
        jsr rd_Slot
        ldy #31
        lda #0
c3:     sta (rdS),y
        dey
        bpl c3
        jsr rd_SaveDir
        ldx #<sRdDeleted
        ldy #>sRdDeleted
        rts
}

//--------------------------------------------------------
rdKind:   .byte 0                // 0 REU, 1 GeoRAM
rdTot:    .word 0, 0             // bruikbare pagina's per soort
rdBanks:  .byte 0
rdMark:   .byte 0
rdSave:   .fill 32, 0
rdPg:     .word 0
rdAdr:    .word 0
rdLen:    .word 0
rdCnt:    .byte 0
rdT:      .word 0
rdP:      .word 0
rdI:      .byte 0
rdJ:      .byte 0
rdN:      .byte 0
rdEnd:    .word 0
rdSrcK:   .byte 0
rdDstK:   .byte 0
rdSrcPg:  .word 0
rdDstPg:  .word 0
rdDst0:   .word 0
rdRem:    .byte 0, 0, 0
rdSize:   .byte 0, 0, 0
rdErr:    .word 0
rdMagic:  .byte $43, $44, $36, $34, $52, $44           // "CD64RD"
rdName:   .byte $52, $41, $4d, $20, $44, $49, $53, $4b // "RAM DISK" (PETSCII)
.encoding "screencode_upper"
rdTypes:  .text "REU   GEORAM"
sRdExists: .text "FILE EXISTS ON THE RAM DRIVE"
          .byte $ff
sRdFull:  .text "RAM DRIVE FULL"
          .byte $ff
sRdNoFile: .text "FILE NOT FOUND"
          .byte $ff
sRdDeleted: .text "FILE DELETED"
          .byte $ff
sRdNoRun: .text "COPY IT TO A DISK DRIVE FIRST"
          .byte $ff
