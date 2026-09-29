#importonce
//========================================================
// abi.inc - zeropage-pseudoregisters + aanroepconventie
// Commodore Desk 64  (zie Ontwikkelplan §7)
//
// Geldt zodra BASIC/KERNAL uitgebankt zijn: de zeropage is
// dan van ons, behalve $00/$01 (6510-poort). Markeer
// zeropage-labels bij gebruik met .zp waar nodig (skill §1.11).
//========================================================

// ---- 16-bits pseudoregisters / pointers ----
.label r0  = $02
.label r1  = $04
.label r2  = $06
.label r3  = $08
.label r4  = $0a
.label r5  = $0c
.label r6  = $0e

// ---- Byte-argumenten & scratch ----
.label a0  = $10
.label a1  = $11
.label a2  = $12
.label a3  = $13
.label a4  = $14
.label a5  = $15
.label a6  = $16
.label a7  = $17

// ---- Vrije scratch binnen één routine ----
.label tmp0  = $20
.label tmp1  = $21
.label tmp2  = $22
.label tmp3  = $23
.label tmp4  = $24
.label tmp5  = $25
.label tmp6  = $26
.label tmp7  = $27
.label tmp8  = $28
.label tmp9  = $29
.label tmp10 = $2a
.label tmp11 = $2b
.label tmp12 = $2c
.label tmp13 = $2d
.label tmp14 = $2e
.label tmp15 = $2f

// ---- GUI-/cursorstaat ----
.label curX     = $30   // cursor-kolom of x-pixel
.label curY     = $31
.label curBtn   = $32   // bit0=links, bit1=rechts
.label hotItem  = $33   // item onder de cursor
.label inputSrc = $34   // 0=muis, 1=joystick, 2=toetsenbord

//--------------------------------------------------------
// Handige 16-bits pseudocommands (skill §6.3)
//--------------------------------------------------------
.function _abiNext(arg) {
    .if (arg.getType()==AT_IMMEDIATE)
        .return CmdArgument(arg.getType(), >arg.getValue())
    .return CmdArgument(arg.getType(), arg.getValue()+1)
}

// mov16 src : tar   -> kopieer een 16-bits waarde
.pseudocommand mov16 src : tar {
    lda src
    sta tar
    lda _abiNext(src)
    sta _abiNext(tar)
}

// inc16 arg         -> verhoog een 16-bits waarde
.pseudocommand inc16 arg {
    inc arg
    bne over
    inc _abiNext(arg)
over:
}
