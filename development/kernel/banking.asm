#importonce
//========================================================
// kernel/banking.asm - modules laden
// Commodore Desk 64
//
// Twee werelden:
//  - DISK (nu): apps/resources als PRG van de D71 laden via de KERNAL.
//  - CARTRIDGE (later, CRT): EasyFlash-banks schakelen via $DE00.
//========================================================

//--------------------------------------------------------
// DISK: mod_Load - laad een PRG van device 8 naar zijn eigen
//                  laadadres. Bankt KERNAL tijdelijk in.
// In : r0 = pointer naar bestandsnaam (schermcodes? nee: PETSCII),
//      a0 = lengte van de naam
// Uit: carry = 1 bij fout
// Klobbert: A,X,Y
//--------------------------------------------------------
mod_Load: {
        jsr mem_KernalIn
        lda a0
        ldx r0
        ldy r0+1
        jsr $ffbd                // SETNAM
        lda #1                   // logisch bestand 1
        ldx #8                   // device 8
        ldy #1                   // secondary 1 = gebruik laadadres uit bestand
        jsr $ffba                // SETLFS
        lda #0                   // 0 = laden (niet verifiëren)
        ldx #0
        ldy #0
        jsr $ffd5                // LOAD
        php
        jsr mem_AllRam           // KERNAL weer uit
        plp
        rts
}

//--------------------------------------------------------
// CARTRIDGE (EasyFlash) - alleen voor de CRT-build.
// LET OP: bij de echte cartridge horen deze routines in RAM of in
// de EasyFlash-RAM ($DF00) te draaien, niet onder de bank die ze
// verwisselen. Op de disk-build zijn ze inert (geen EasyFlash).
//--------------------------------------------------------

// switch_bank - selecteer EasyFlash-bank. In: A = bank.
switch_bank:
        sta EF_BANK
        sta curBank
        rts

// farcall - roep een routine in een andere bank aan.
// In: a0 = doelbank, r0 = doeladres. Bewaart/herstelt de bank.
farcall: {
        lda curBank
        pha
        lda a0
        sta EF_BANK
        sta curBank
        jsr callVector
        pla
        sta EF_BANK
        sta curBank
        rts
callVector:
        jmp (r0)
}

curBank: .byte 0
