#importonce
//========================================================
// apps/sidplay.asm - SID PLAYER (overlay SIDPLAY)
// Commodore Desk 64
//
// Leest de directory en toont alle .SID-bestanden (PSID/RSID). Een klik
// speelt de tune af in een eigen afspeelscherm:
//   1. het bestand laden naar $4000 (app-werkgeheugen) en de PSID-header
//      lezen (laad-, init- en play-adres, aantal songs, titel, maker, jaar)
//   2. het geheugen waar de tune moet staan bewaren (meestal $1000: daar
//      staat de Core!) en de tune erheen kopieren; ook de zeropage bewaren
//   3. eigen IRQ ($FFFE) en afspeelscherm in de ROM-letters: vanaf hier
//      roept deze overlay GEEN Core-routines meer aan (die zijn weg)
//   4. SPATIE / RUN/STOP = stoppen: SID stil, alles terugzetten, lijst
//   + / - = volgende / vorige song.
// Tunes van $0800-$3FFF, $4000-$7FFF, $C000-$CFFF en $E000-$FFF9 kunnen
// spelen; tunes zonder play-adres (eigen IRQ, RSID) niet.
// RADIO (apps/radio) gebruikt dit afspelen ook: spRadio = 1, het bestand
// staat al op $4000 (spEnd = einde) -> sp_Play.ld. Dan is SPATIE de
// volgende tune, RUN/STOP stopt de radio (spRes 1 / 2), en na RADIO_T
// beelden gaat hij vanzelf door (spRes 1).
//========================================================

.const SP_MAX   = 16             // .SID-bestanden in de lijst
.const SP_NLEN  = 16             // naamlengte op disk
.const SP_TOP   = 4              // eerste rij van de lijst
.label SP_STAGE = $4000          // hier wordt het bestand geladen
.label SP_HDR   = SP_STAGE - 2   // (LOAD slaat de eerste 2 bytes over: "PS")
.const SP_MAXBLK = 63            // 63 blokken ~ 16 KB ($4000-$7EFF)
.const RADIO_T  = 50*60*3        // RADIO: 3 minuten per tune (50 Hz)
.label spPtr  = r3               // zeropage (alleen buiten het afspelen)
.label spPtr2 = r6

sp_Init: {
        lda #0
        sta spMsg+1
        lda #8
        sta spDev
        lda fileReq              // tune uit de File Manager: meteen spelen
        bne fm
        jmp sp_Dir
fm:     lda #0
        sta fileReq
        lda fileDev
        sta spDev
        jsr sp_Dir               // (lijst van die drive)
        ldx #0                   // het bestand in de lijst zoeken
en:     cpx spCount
        bcs nf
        stx spSel
        lda spNLen,x
        cmp fileLen
        bne nx
        jsr sp_NamePtr
        ldy #0
cm:     cpy fileLen
        beq hit
        lda (spPtr),y
        cmp fileName,y
        bne nx0
        iny
        bne cm
nx0:    ldx spSel
nx:     inx
        bne en
nf:     rts
hit:    jsr sp_Play              // speelt en komt terug in de lijst
        bcs r
        stx spMsg
        sty spMsg+1
r:      rts
}

//--------------------------------------------------------
// sp_Dir - directory lezen, .SID-bestanden onthouden (ruwe PETSCII-naam
//          + aantal blokken).
//--------------------------------------------------------
sp_Dir: {
        lda #0
        sta spCount
        jsr cfg_io_begin
        lda #1
        ldx #<dl
        ldy #>dl
        jsr K_SETNAM
        lda #2
        ldx spDev
        ldy #0
        jsr K_SETLFS
        jsr K_OPEN
        bcs done
        ldx #2
        jsr K_CHKIN
        jsr K_CHRIN              // laadadres
        jsr K_CHRIN
line:   jsr K_CHRIN              // link
        sta spT
        jsr K_READST
        bne end
        jsr K_CHRIN
        ora spT
        beq end
        jsr K_CHRIN              // blokken
        sta spBlk
        jsr K_CHRIN
        sta spBlk+1
        lda #0
        sta spQ
        sta spNL
ch:     jsr K_CHRIN
        sta spT
        jsr K_READST
        bne end
        lda spT
        beq eol
        ldx spQ
        bne inq
        cmp #$22                 // begin van de naam
        bne ch
        inc spQ
        jmp ch
inq:    cpx #1
        bne ch
        cmp #$22                 // einde van de naam
        beq cq
        ldx spNL
        cpx #SP_NLEN
        bcs ch
        sta spTmp,x
        inc spNL
        jmp ch
cq:     inc spQ
        jmp ch
eol:    jsr keep
        jmp line
end:    jsr K_CLRCHN
        lda #2
        jsr K_CLOSE
done:   jmp cfg_io_end
dl:     .byte $24                // "$"

keep:   ldx spNL                 // eindigt op ".SID"?
        cpx #5
        bcc kr
        lda spTmp-1,x
        and #$7f
        cmp #$44                 // D
        bne kr
        lda spTmp-2,x
        and #$7f
        cmp #$49                 // I
        bne kr
        lda spTmp-3,x
        and #$7f
        cmp #$53                 // S
        bne kr
        lda spTmp-4,x
        cmp #$2e                 // .
        bne kr
        lda spCount
        cmp #SP_MAX
        bcs kr
        tax
        lda spNL
        sta spNLen,x
        lda spBlk
        sta spBlkLo,x
        lda spBlk+1
        sta spBlkHi,x
        jsr sp_NamePtr           // spPtr = naam X
        ldy #0
kc:     lda spTmp,y
        sta (spPtr),y
        iny
        cpy spNL
        bne kc
        inc spCount
kr:     rts
}

// sp_NamePtr - spPtr = naambuffer van entry X.
sp_NamePtr:
        txa
        asl
        asl
        asl
        asl
        clc
        adc #<spNames
        sta spPtr
        lda #>spNames
        adc #0
        sta spPtr+1
        rts

//--------------------------------------------------------
// sp_Draw - lijst met tunes.
//--------------------------------------------------------
sp_Draw: {
        lda #<sSpTitle
        sta r0
        lda #>sSpTitle
        sta r0+1
        lda #2
        sta a0
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
        lda spCount
        bne list
        lda #<sSpNone
        sta r0
        lda #>sSpNone
        sta r0+1
        lda #2
        sta a0
        lda #SP_TOP
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        jmp msg
list:   ldx #0
ll:     stx spI
        jsr sp_NamePtr
        ldy #0
nc:     lda (spPtr),y            // PETSCII -> schermcode
        and #$7f
        jsr petscii2screen
        sta spLine,y
        iny
        tya
        ldx spI
        cmp spNLen,x
        bne nc
        lda #$ff
        sta spLine,y
        lda #<spLine
        sta r0
        lda #>spLine
        sta r0+1
        lda #4
        sta a0
        lda spI
        clc
        adc #SP_TOP
        sta a1
        lda TH_text
        sta a2
        jsr gfx_DrawText
        lda #$2a                 // teken voor de naam
        sta a2
        lda #2
        sta a0
        lda spI
        clc
        adc #SP_TOP
        sta a1
        lda TH_accent
        sta a3
        jsr gfx_PutChar
        ldx spI
        inx
        cpx spCount
        bne ll
        lda #<sSpHint
        sta r0
        lda #>sSpHint
        sta r0+1
        lda #2
        sta a0
        lda #21
        sta a1
        lda TH_accent
        sta a2
        jsr gfx_DrawText
msg:    lda spMsg+1
        beq r
        sta r0+1
        lda spMsg
        sta r0
        lda #2
        sta a0
        lda #22
        sta a1
        lda TH_accent
        sta a2
        jmp gfx_DrawText
r:      rts
}

//--------------------------------------------------------
// sp_Click - klik op een tune = afspelen.
//--------------------------------------------------------
sp_Click: {
        lda evtB
        sec
        sbc #SP_TOP
        bcc r
        cmp spCount
        bcs r
        sta spSel
        lda #0
        sta spMsg+1
        jsr sp_Play              // (X/Y = melding als het niet lukt)
        bcs ok
        stx spMsg
        sty spMsg+1
ok:     jmp shell_DrawAll
r:      rts
}

//--------------------------------------------------------
// sp_Play - tune spSel laden, controleren en afspelen.
//           Carry=1 gespeeld, carry=0 -> X/Y melding.
//--------------------------------------------------------
sp_Play: {
        ldx spSel                // past het in $4000-$7EFF?
        lda spBlkHi,x
        bne big
        lda spBlkLo,x
        cmp #SP_MAXBLK+1
        bcc sz
big:    ldx #<sSpBig
        ldy #>sSpBig
        clc
        rts
sz:     jsr sp_NamePtr
        jsr cfg_io_begin
        ldx spSel
        lda spNLen,x
        ldx spPtr
        ldy spPtr+1
        jsr K_SETNAM
        lda #1
        ldx spDev
        ldy #0                   // sa=0: naar $4000, waar het bestand ook heen wil
        jsr K_SETLFS
        lda #0
        ldx #<SP_STAGE
        ldy #>SP_STAGE
        jsr K_LOAD
        php
        stx spEnd
        sty spEnd+1
        jsr cfg_io_end
        plp
        bcc ld
        ldx #<sSpLoad
        ldy #>sSpLoad
        clc
        rts
ld:     lda SP_HDR+2             // "PSID" of "RSID" ("PS" viel weg)
        cmp #$49
        bne nosid
        lda SP_HDR+3
        cmp #$44
        beq hdr
nosid:  ldx #<sSpNoSid
        ldy #>sSpNoSid
        clc
        rts
hdr:    lda SP_HDR+$05         // PSID v2+: welk geheugen is vrij?
        cmp #2                   // (startPage/pageLength op $78/$79)
        bcc fr
        lda SP_HDR+$78
        beq fr                   // 0: alleen het eigen bereik
        cmp #$81                 // anders moet $8000-$BFFF (deze overlay)
        bcs nfr                  // in het vrije bereik liggen
        clc
        adc SP_HDR+$79
        bcs fr
        cmp #$c0
        bcs fr
nfr:    ldx #<sSpMem             // tune gebruikt (bijna) al het geheugen
        ldy #>sSpMem
        clc
        rts
fr:     lda SP_HDR+$0c         // play-adres (big-endian)
        sta spPlay+1
        lda SP_HDR+$0d
        sta spPlay
        ora spPlay+1
        bne hp
        ldx #<sSpIrq             // tune met eigen IRQ: kan hier niet
        ldy #>sSpIrq
        clc
        rts
hp:     lda SP_HDR+$0a
        sta spInit+1
        lda SP_HDR+$0b
        sta spInit
        lda SP_HDR+$0f         // aantal songs, startsong
        bne s1
        lda #1
s1:     sta spSongs
        lda SP_HDR+$11
        beq s2
        sec
        sbc #1
s2:     cmp spSongs
        bcc s3
        lda #0
s3:     sta spSong
        lda SP_HDR+$07         // data = header + dataOffset
        clc
        adc #<SP_HDR
        sta spSrc
        lda SP_HDR+$06
        adc #>SP_HDR
        sta spSrc+1
        lda SP_HDR+$09         // laadadres; 0 = eerste 2 databytes
        sta spLoad
        lda SP_HDR+$08
        sta spLoad+1
        ora spLoad
        bne la
        lda spSrc
        sta spPtr
        lda spSrc+1
        sta spPtr+1
        ldy #0
        lda (spPtr),y
        sta spLoad
        iny
        lda (spPtr),y
        sta spLoad+1
        lda spSrc
        clc
        adc #2
        sta spSrc
        bcc la
        inc spSrc+1
la:     lda spEnd                // lengte = einde bestand - data
        sec
        sbc spSrc
        sta spLen
        lda spEnd+1
        sbc spSrc+1
        sta spLen+1
        lda spLoad               // einde van de tune in het geheugen
        clc
        adc spLen
        sta spTEnd
        lda spLoad+1
        adc spLen+1
        sta spTEnd+1
        bcs bad                  // over $FFFF heen
        // waar mag de tune staan?
        lda spLoad+1
        cmp #$08
        bcc bad                  // onder $0800 (zeropage, scherm)
        lda spTEnd+1             // A: $0800-$3FFF (Core): bewaren
        cmp #$40
        bcc ma
        bne nb
        lda spTEnd
        beq ma
nb:     lda spLoad+1             // B: $4000-$7FFF: vrij RAM
        cmp #$40
        bcc bad
        lda spTEnd+1
        cmp #$80
        bcc mb
        bne nc
        lda spTEnd
        beq mb
nc:     lda spLoad+1             // C: $C000-$CFFF
        cmp #$c0
        bcc bad
        cmp #$d0
        bcs ne
        lda spTEnd+1
        cmp #$d0
        bcc ma
        bne bad
        lda spTEnd
        beq ma
        bne bad
ne:     cmp #$e0                 // E: $E000-$FFF9 (vectoren blijven)
        bcc bad
        lda spTEnd+1
        cmp #$ff
        bcc ma
        lda spTEnd
        cmp #$fb
        bcc ma
bad:    ldx #<sSpWhere
        ldy #>sSpWhere
        clc
        rts
mb:     lda #0                   // geen backup nodig
        sta spMode
        jmp sp_Run
ma:     lda #1                   // backup direct achter het bestand
        sta spMode
        lda spEnd
        beq pa
        inc spEnd+1              // (op een pagina afgerond)
pa:     lda #0
        sta spBack
        lda spEnd+1
        sta spBack+1
        clc                      // past de backup nog onder $8000?
        lda spBack
        adc spLen
        lda spBack+1
        adc spLen+1
        cmp #$80
        bcc ok
        ldx #<sSpBig
        ldy #>sSpBig
        clc
        rts
ok:     jmp sp_Run
}

//--------------------------------------------------------
// sp_Run - afspelen tot SPATIE / RUN/STOP. Geen Core-aanroepen hierin!
//--------------------------------------------------------
sp_Run: {
        sei
        lda $fffa                // NMI (RESTORE) -> rti zolang de Core weg is
        sta spVec
        lda $fffb
        sta spVec+1
        lda $fffe
        sta spVec+2
        lda $ffff
        sta spVec+3
        lda #<sp_Nmi
        sta $fffa
        lda #>sp_Nmi
        sta $fffb
        ldx #2                   // zeropage bewaren ($02-$FF)
zs:     lda $00,x
        sta spZp,x
        inx
        bne zs
        lda $01
        sta spSave01
        lda #$35                 // RAM + I/O
        sta $01
        lda VIC_MEM
        sta spVic
        lda BORDER_COL
        sta spVic+1
        lda BG_COL0
        sta spVic+2
        lda SPR_ENABLE
        sta spVic+3
        lda #0
        sta SPR_ENABLE
        jsr sp_Screen            // eerst: leest de titel nog uit de header
        lda spMode               // tune-geheugen bewaren
        beq cp
        lda spLoad
        sta spPtr
        lda spLoad+1
        sta spPtr+1
        lda spBack
        sta spPtr2
        lda spBack+1
        sta spPtr2+1
        jsr sp_Copy
cp:     lda spSrc                // tune op zijn plaats
        sta spPtr
        lda spSrc+1
        sta spPtr+1
        lda spLoad
        sta spPtr2
        lda spLoad+1
        sta spPtr2+1
        jsr sp_Move
        jsr sp_Start             // init (met I=1)
        lda #<sp_Irq
        sta $fffe
        lda #>sp_Irq
        sta $ffff
        lda #$7f                 // geen CIA-IRQ's
        sta $dc0d
        lda $dc0d
        lda #$ff
        sta $d019
        lda #$ff                 // toetsenbord: poort A = kolommen
        sta $dc02
        lda #0
        sta $dc03
        jsr sp_Keys              // huidige stand = "al ingedrukt"
        lda #0
        sta spFrames
        sta spFrames+1
        sta spRes
        cli
        // ---- afspelen: toetsen ----
kl:     lda spRadio              // RADIO: na RADIO_T beelden door
        beq kk
        lda spFrames+1
        cmp #>RADIO_T
        bcc kk
        lda #1
        sta spRes
        jmp stop
kk:     jsr sp_Keys              // A = nieuw ingedrukte toetsen
        lsr
        bcs sp0                  // bit 0: SPATIE
        lsr
        bcs nx                   // bit 1: +
        lsr
        bcs pv                   // bit 2: -
        lsr
        bcs rs                   // bit 3: RUN/STOP
        jmp kl
sp0:    lda #1                   // SPATIE: stoppen (RADIO: volgende)
        .byte $2c
rs:     lda #2                   // RUN/STOP: stoppen (RADIO: radio uit)
        sta spRes
        jmp stop
nx:     lda spSong
        clc
        adc #1
        cmp spSongs
        bcc sg
        lda #0
        jmp sg
pv:     lda spSong
        bne p1
        lda spSongs
p1:     sec
        sbc #1
sg:     sta spSong
        sei
        jsr sp_Start
        cli
        jmp kl
stop:   sei
        jsr sp_Silence
        lda spMode               // Core-geheugen terug
        beq nr
        lda spBack
        sta spPtr
        lda spBack+1
        sta spPtr+1
        lda spLoad
        sta spPtr2
        lda spLoad+1
        sta spPtr2+1
        jsr sp_Copy
nr:     lda spVec                // vectoren, VIC en $01 terug
        sta $fffa
        lda spVec+1
        sta $fffb
        lda spVec+2
        sta $fffe
        lda spVec+3
        sta $ffff
        lda spVic
        sta VIC_MEM
        lda spVic+1
        sta BORDER_COL
        lda spVic+2
        sta BG_COL0
        lda spVic+3
        sta SPR_ENABLE
        lda spSave01
        sta $01
        ldx #2                   // zeropage terug (als laatste: spPtr!)
zr:     lda spZp,x
        sta $00,x
        inx
        bne zr
        lda #$ff
        sta $d019
        cli
        sec
        rts
}

// sp_Start - SID stil, song spSong initialiseren, songregel tonen.
sp_Start:
        jsr sp_Silence
        jsr sp_SongLine
        lda spSong
        ldx #0
        ldy #0
        jmp (spInit)

sp_Silence:
        lda #0
        ldx #$18
!:      sta $d400,x
        dex
        bpl !-
        rts

// sp_Irq - 50 Hz (raster-IRQ van de Core, regel 252): play aanroepen.
sp_Irq:
        pha
        txa
        pha
        tya
        pha
        lda #$ff
        sta $d019
        lda $dc0d
        inc spFrames
        bne !+
        inc spFrames+1
!:      jsr sp_PlayJ
        pla
        tay
        pla
        tax
        pla
sp_Nmi: rti
sp_PlayJ:
        jmp (spPlay)

// sp_Keys - A = toetsen die NU ingedrukt worden (bit 0 SPATIE/STOP,
//           bit 1 +, bit 2 -).
sp_Keys: {
        lda #0
        sta spT
        lda #%01111111           // kolom 7: SPATIE (rij 4), RUN/STOP (rij 7)
        sta $dc00
        lda $dc01
        eor #$ff
        tax
        and #%00010000
        beq k0
        lda #1
        sta spT
k0:     txa
        and #%10000000
        beq k1
        lda spT
        ora #8
        sta spT
k1:     lda #%11011111           // kolom 5: + (rij 0), - (rij 3)
        sta $dc00
        lda $dc01
        eor #$ff
        tax
        and #%00000001
        beq k2
        lda spT
        ora #2
        sta spT
k2:     txa
        and #%00001000
        beq k3
        lda spT
        ora #4
        sta spT
k3:     lda #$ff
        sta $dc00
        lda spKeys               // alleen nieuwe
        eor #$ff
        and spT
        pha
        lda spT
        sta spKeys
        pla
        rts
}

// sp_Copy - spLen bytes van (spPtr) naar (spPtr2), vooruit.
sp_Copy: {
        ldx spLen+1
        ldy #0
pg:     cpx #0
        beq rest
lp:     lda (spPtr),y
        sta (spPtr2),y
        iny
        bne lp
        inc spPtr+1
        inc spPtr2+1
        dex
        jmp pg
rest:   cpy spLen
        beq r
        lda (spPtr),y
        sta (spPtr2),y
        iny
        jmp rest
r:      rts
}

// sp_Move - als sp_Copy, maar achteruit als het doel hoger ligt en
//           overlapt (tune in $4000-$7FFF, net als het bestand).
sp_Move: {
        lda spPtr2+1
        cmp spPtr+1
        bcc sp_Copy
        bne back
        lda spPtr2
        cmp spPtr
        bcc sp_Copy
        beq r
back:   lda spPtr                // bron/doel = einde
        clc
        adc spLen
        sta spPtr
        lda spPtr+1
        adc spLen+1
        sta spPtr+1
        lda spPtr2
        clc
        adc spLen
        sta spPtr2
        lda spPtr2+1
        adc spLen+1
        sta spPtr2+1
        lda spLen
        sta spC
        lda spLen+1
        sta spC+1
lp:     lda spC
        ora spC+1
        beq r
        lda spPtr
        bne a1
        dec spPtr+1
a1:     dec spPtr
        lda spPtr2
        bne a2
        dec spPtr2+1
a2:     dec spPtr2
        ldy #0
        lda (spPtr),y
        sta (spPtr2),y
        lda spC
        bne a3
        dec spC+1
a3:     dec spC
        jmp lp
r:      rts
}

//--------------------------------------------------------
// Afspeelscherm (ROM-letters, hoofd/kleine letters; geen Core-routines)
//--------------------------------------------------------
sp_Screen: {
        lda #$17                 // ROM-charset met kleine letters
        sta VIC_MEM
        lda TH_border
        sta BORDER_COL
        lda TH_deskbg
        sta BG_COL0
        ldx #0
cl:     lda #$20
        sta SCREEN_RAM,x
        sta SCREEN_RAM+$100,x
        sta SCREEN_RAM+$200,x
        sta SCREEN_RAM+$2e8,x
        lda TH_text
        sta COLOR_RAM,x
        sta COLOR_RAM+$100,x
        sta COLOR_RAM+$200,x
        sta COLOR_RAM+$2e8,x
        inx
        bne cl
        ldx #<tTitle             // vaste teksten
        ldy #>tTitle
        lda spRadio
        beq t0
        ldx #<tRadio
        ldy #>tRadio
t0:     lda #3
        jsr sp_Center
        ldx #<tKeys1
        ldy #>tKeys1
        lda spRadio
        beq t1
        ldx #<tRKeys1
        ldy #>tRKeys1
t1:     lda #18
        jsr sp_Center
        ldx #<tKeys2
        ldy #>tKeys2
        lda spRadio
        beq t2
        ldx #<tRKeys2
        ldy #>tRKeys2
t2:     lda #20
        jsr sp_Center
        // titel, maker, jaar uit de header (ASCII, 32 tekens)
        lda #$16
        ldx #7
        jsr hdrLine
        lda #$36
        ldx #9
        jsr hdrLine
        lda #$56
        ldx #11
        jmp hdrLine
hdrLine:
        stx spRow
        tax
        ldy #0
hl:     lda SP_HDR,x
        beq he
        jsr sp_Asc
        sta spLine,y
        inx
        iny
        cpy #32
        bne hl
he:     lda #0
        sta spLine,y
        ldx #<spLine
        ldy #>spLine
        lda spRow
        jmp sp_Center
}

// sp_SongLine - "Song x of y" op rij 14.
sp_SongLine: {
        ldy #0
        ldx #0
t1:     lda tSong,x
        beq n1
        sta spLine,y
        iny
        inx
        bne t1
n1:     ldx spSong
        inx
        txa
        jsr dcm
        ldx #0
t2:     lda tOf,x
        beq n2
        sta spLine,y
        iny
        inx
        bne t2
n2:     lda spSongs
        jsr dcm
        lda #$20                 // (vorige, langere regel wissen)
        sta spLine,y
        iny
        sta spLine,y
        iny
        lda #0
        sta spLine,y
        ldx #<spLine
        ldy #>spLine
        lda #14
        jmp sp_Center
dcm:    sta spT              // A = 1-255 decimaal naar spLine,y
        lda #0
        sta spAny
        ldx #2
dl:     lda #0
        sta spAny+1
ds:     lda spT
        cmp dTab,x
        bcc dn
        sbc dTab,x
        sta spT
        inc spAny+1
        jmp ds
dn:     lda spAny+1
        ora spAny
        bne dp
        cpx #0
        bne dz
dp:     lda spAny+1
        ora #$30
        sta spLine,y
        iny
        inc spAny
dz:     dex
        bpl dl
        rts
}
dTab:   .byte 1, 10, 100

// sp_Center - tekst X/Y (schermcodes, 0) gecentreerd op rij A.
sp_Center: {
        stx spPtr
        sty spPtr+1
        tax
        lda spScrLo,x
        sta spPtr2
        lda spScrHi,x
        sta spPtr2+1
        ldy #0
ln:     lda (spPtr),y
        beq lc
        iny
        bne ln
lc:     sty spT
        lda #40
        sec
        sbc spT
        lsr
        clc
        adc spPtr2
        sta spPtr2
        bcc cp
        inc spPtr2+1
cp:     ldy #0
c1:     lda (spPtr),y
        beq r
        sta (spPtr2),y
        iny
        bne c1
r:      rts
}

// sp_Asc - ASCII / Latin-1 (PSID-tekst) -> schermcode in de kleine-letterset.
sp_Asc: {
        cmp #$80
        bcc a7
        cmp #$c0
        bcc q
        and #$3f                 // Latin-1 -> letter zonder accent
        stx spI
        tax
        lda spLat,x
        ldx spI
a7:     cmp #$20
        bcc q
        cmp #$40
        bcc r
        beq at
        cmp #$5b
        bcc r                    // A-Z -> $41-$5A (hoofdletters)
        cmp #$61
        bcc q
        cmp #$7b
        bcs q
        and #$1f                 // a-z -> $01-$1A
r:      rts
at:     lda #0
        rts
q:      lda #$2e                 // .
        rts
}
.encoding "ascii"
spLat:  .text "AAAAAAACEEEEIIIIDNOOOOOxOUUUUYPs"
        .text "aaaaaaaceeeeiiiidnooooo/ouuuuypy"
.encoding "screencode_upper"

spScrLo:  .fill 25, <[SCREEN_RAM + i*40]
spScrHi:  .fill 25, >[SCREEN_RAM + i*40]

//--------------------------------------------------------
.align 2
spInit:   .word 0
spPlay:   .word 0
spSrc:    .word 0
spLoad:   .word 0
spLen:    .word 0
spEnd:    .word 0
spTEnd:   .word 0
spBack:   .word 0
spC:      .word 0
spMsg:    .word 0
spVec:    .fill 4, 0
spVic:    .fill 4, 0
spAny:    .fill 2, 0
spBlk:    .word 0
spSave01: .byte 0
spMode:   .byte 0
spSongs:  .byte 0
spSong:   .byte 0
spKeys:   .byte 0
spRadio:  .byte 0                // 1 = RADIO speelt (zie boven)
spRes:    .byte 0                // na het afspelen: 1 SPATIE/tijd, 2 RUN/STOP
spFrames: .word 0
spCount:  .byte 0
spSel:    .byte 0
spDev:    .byte 8
spI:      .byte 0
spT:      .byte 0
spQ:      .byte 0
spNL:     .byte 0
spRow:    .byte 0
spTmp:    .fill SP_NLEN, 0
spNLen:   .fill SP_MAX, 0
spBlkLo:  .fill SP_MAX, 0
spBlkHi:  .fill SP_MAX, 0
spNames:  .fill SP_MAX*SP_NLEN, 0
spLine:   .fill 41, 0
spZp:     .fill 256, 0

.encoding "screencode_upper"
sSpTitle: .text "SID TUNES ON THE DISK"
          .byte $ff
sSpNone:  .text "NO .SID FILES ON THE DISK"
          .byte $ff
sSpHint:  .text "CLICK A TUNE TO PLAY IT"
          .byte $ff
sSpBig:   .text "THIS TUNE IS TOO BIG"
          .byte $ff
sSpMem:   .text "THIS TUNE NEEDS ALL MEMORY"
          .byte $ff
sSpLoad:  .text "COULD NOT LOAD THE FILE"
          .byte $ff
sSpNoSid: .text "THIS IS NOT A SID FILE"
          .byte $ff
sSpIrq:   .text "THIS TUNE NEEDS ITS OWN IRQ"
          .byte $ff
sSpWhere: .text "CANNOT PLAY A TUNE AT THIS ADDRESS"
          .byte $ff
.encoding "screencode_mixed"
tTitle:   .text "SID PLAYER"
          .byte 0
tKeys1:   .text "+ / -   next / previous song"
          .byte 0
tKeys2:   .text "SPACE or RUN/STOP   stop"
          .byte 0
tRadio:   .text "SID RADIO"
          .byte 0
tRKeys1:  .text "SPACE   next tune (or after 3 min.)"
          .byte 0
tRKeys2:  .text "RUN/STOP   stop the radio"
          .byte 0
tSong:    .text "Song "
          .byte 0
tOf:      .text " of "
          .byte 0
.encoding "screencode_upper"
