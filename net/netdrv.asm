#importonce
//========================================================
// net/netdrv.asm - platformdetectie + netwerkconfig (Milestone 1)
// Commodore Desk 64
//
// Volgorde (bouwplan): eerst Ultimate (UCI), dan RR-Net (CS8900),
// anders geen netwerk. In de cartridge-build (cartMode=1) wordt de
// I/O-ruimte niet aangeraakt: EasyFlash gebruikt $DE00/$DE02 als
// bank/control-register en heeft RAM op $DF00.
//========================================================

// -----------------------------------------------------
// net_Detect
// In:  -
// Uit: netPlatform = NET_PLAT_*, netError = NET_OK / NET_ERR_*
// Klobbert: A, Y
// -----------------------------------------------------
net_Detect: {
        lda #NET_PLAT_NONE
        sta netPlatform
        lda cartMode
        beq go
        lda #NET_ERR_IO_BUSY
        sta netError
        rts
go:
.if (PLATFORM != PLATFORM_RRNET) {
        jsr uci_Detect
        bcc noUci
        lda #NET_PLAT_ULTIMATE
        jmp ok
noUci:
}
.if (PLATFORM != PLATFORM_ULTIMATE) {
        jsr cs_Detect
        bcc noCs
        lda #NET_PLAT_RRNET
        jmp ok
noCs:
}
        lda #NET_ERR_NO_DEVICE
        sta netError
        rts
ok:     sta netPlatform
        lda #NET_OK
        sta netError
        rts
}

netPlatform: .byte NET_PLAT_NONE
netError:    .byte NET_ERR_NO_DEVICE

// MAC is (nog) vast: locally administered. IP/MASK/GW/DNS staan in NETCFG.
netMac:  .byte $02, $64, $64, $00, $00, $01

// -----------------------------------------------------
// nc_Load - NET.CFG van disk naar NETCFG ($C400), tenzij hij daar al
//           staat. Ontbreekt het bestand: standaardwaarden.
// -----------------------------------------------------
nc_Load: {
        lda NC_MARK
        cmp #'N'
        bne load
        lda NC_MARK+1
        cmp #'C'
        beq done
load:   jsr cfg_io_begin
        lda #[nEnd-nm]
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #1
        ldx #8
        ldy #1                   // laadadres uit het bestand ($C400)
        jsr K_SETLFS
        lda #0
        jsr K_LOAD
        jsr cfg_io_end
        lda NC_MARK
        cmp #'N'
        bne dflt
        lda NC_MARK+1
        cmp #'C'
        beq done
dflt:   ldx #0
cp:     lda ncDefault,x
        sta NETCFG,x
        inx
        cpx #[NETCFG_END-NETCFG]
        bne cp
done:   rts
nm:     .encoding "petscii_upper"
        .text "NET.CFG"
nEnd:   .encoding "screencode_upper"
}

// nc_Save - NETCFG -> "@0:NET.CFG". Carry=1 bij fout.
nc_Save: {
        jsr cfg_io_begin
        lda #[nEnd-nm]
        ldx #<nm
        ldy #>nm
        jsr K_SETNAM
        lda #0
        ldx #8
        ldy #0
        jsr K_SETLFS
        lda #<NETCFG
        sta $fb
        lda #>NETCFG
        sta $fc
        lda #$fb
        ldx #<NETCFG_END
        ldy #>NETCFG_END
        jsr K_SAVE
        php
        jsr cfg_io_end
        plp
        rts
nm:     .encoding "petscii_upper"
        .text "@0:NET.CFG"
nEnd:   .encoding "screencode_upper"
}

// Standaardconfig (nog geen DHCP). IP/MASK/GW: VICE op de Windows-PC via
// de Hyper-V/WSL-adapter (Windows = gateway, routeert ook naar Tailscale).
// Op een echte C64 in het LAN: in NETWORK aanpassen. Chatserver: LM Studio
// (OpenAI-compatibel) met gemma-1.1-2b-it.
ncDefault:
        .text "NC"
        .byte 172, 27, 211, 64
        .byte 255, 255, 240, 0
        .byte 172, 27, 208, 1
        .byte 1, 1, 1, 1
        .text "100.112.242.111"
        .fill 33-15, $ff
        .text "1234"
        .fill 6-4, $ff
        .fill 41, $ff
        .text "GEMMA-1.1-2B-IT"
        .fill 33-15, $ff
.assert "ncDefault = NETCFG-lengte", * - ncDefault, NETCFG_END - NETCFG
