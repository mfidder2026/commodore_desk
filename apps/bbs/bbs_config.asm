#importonce
//========================================================
// apps/bbs/bbs_config.asm - BBS.CFG (bouwplan §9)
// Commodore Desk 64
//
//   byte 0-1  magic "BB"
//   byte 2    config-versie
//   byte 3    default BBS (0..BBS_MAX-1; eigen BBS'en vanaf BBS_COUNT)
//   byte 4    local echo (0 uit, 1 aan)
//   byte 5    terminal (0 = zoals de BBS-entry)
//   byte 6    gereserveerd
//   byte 7    checksum (som van byte 0-6)
// Vast op $C4E0 (NETCFG-pagina, buiten NET.CFG), zodat het laadadres in
// het bestand niet van de overlay-indeling afhangt. Ontbreekt of klopt
// het bestand niet: compile-time defaults, geen crash.
//========================================================

.label BBS_CFG    = $c4e0
.label BC_MAGIC   = BBS_CFG + 0
.label BC_VERSION = BBS_CFG + 2
.label BC_DEFAULT = BBS_CFG + 3
.label BC_ECHO    = BBS_CFG + 4
.label BC_TERM    = BBS_CFG + 5
.label BC_SUM     = BBS_CFG + 7
.const BBS_CFG_VERSION = 1

// bb_CfgLoad - BBS.CFG laden (alleen als hij nog niet geldig in RAM staat).
bb_CfgLoad: {
        jsr bb_CfgValid
        bcs done
        jsr cfg_io_begin
        lda #[nEnd-nm]
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #1                   // laadadres uit het bestand ($C4E0)
        jsr K_SETLFS
        lda #0
        jsr K_LOAD
        jsr cfg_io_end
        jsr bb_CfgValid
        bcs done
        ldx #7                   // ontbreekt / beschadigd: defaults
df:     lda bbCfgDefault,x
        sta BBS_CFG,x
        dex
        bpl df
        jsr bb_CfgSum
done:   rts
nm:     .encoding "petscii_upper"
        .text "BBS.CFG"
nEnd:   .encoding "screencode_upper"
}

// bb_CfgSave - "@0:BBS.CFG". Carry=1 bij een fout.
bb_CfgSave: {
        jsr bb_CfgSum
        jsr cfg_io_begin
        lda #[nEnd-nm]
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #0
        ldx #8
        ldy #0
        jsr K_SETLFS
        lda #<BBS_CFG
        sta $fb
        lda #>BBS_CFG
        sta $fc
        lda #$fb
        ldx #<[BBS_CFG+8]
        ldy #>[BBS_CFG+8]
        jsr K_SAVE
        php
        jsr cfg_io_end
        plp
        rts
nm:     .encoding "petscii_upper"
        .text "@0:BBS.CFG"
nEnd:   .encoding "screencode_upper"
}

// bb_CfgValid - magic, versie, checksum en default kloppen? Carry=1 ja.
bb_CfgValid: {
        lda BC_MAGIC
        cmp #$42                 // "B"
        bne no
        lda BC_MAGIC+1
        cmp #$42
        bne no
        lda BC_VERSION
        cmp #BBS_CFG_VERSION
        bne no
        lda BC_DEFAULT
        cmp #BBS_MAX
        bcs no
        jsr sum
        cmp BC_SUM
        bne no
        sec
        rts
no:     clc
        rts
sum:    lda #0
        ldx #6
lp:     clc
        adc BBS_CFG,x
        dex
        bpl lp
        rts
}

// bb_CfgSum - checksum (byte 7) opnieuw uitrekenen.
bb_CfgSum:
        jsr bb_CfgValid.sum
        sta BC_SUM
        rts

bbCfgDefault: .byte $42, $42, BBS_CFG_VERSION, BBS_DEFAULT, 0, 0, 0, 0
