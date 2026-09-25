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

// Statische config (nog geen DHCP). Later configureerbaar.
netIp:   .byte 192, 168, 1, 64
netMask: .byte 255, 255, 255, 0
netGw:   .byte 192, 168, 1, 1
netDns:  .byte 1, 1, 1, 1
netMac:  .byte $02, $64, $64, $00, $00, $01
