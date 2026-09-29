#importonce
//========================================================
// hardware.inc - C64 + EasyFlash register-labels
// Commodore Desk 64
//========================================================

// ---- VIC-II ($D000-$D02E) ----
.label SPR0_X      = $d000
.label SPR0_Y      = $d001
.label SPR_MSB_X   = $d010   // hoge X-bit per sprite
.label VIC_CTRL1   = $d011   // raster hi, bitmap/ecm/blank/rows/yscroll
.label RASTER      = $d012   // rasterregel (lees) / IRQ-regel (schrijf)
.label SPR_ENABLE  = $d015   // sprites aan/uit (bit per sprite)
.label VIC_CTRL2   = $d016   // multicolor/columns/xscroll
.label SPR_YEXP    = $d017
.label VIC_MEM     = $d018   // scherm- + charset-basis
.label VIC_IRQ     = $d019   // IRQ-status (schrijf 1 = bevestig)
.label VIC_IRQ_EN  = $d01a   // IRQ-enable
.label SPR_XEXP    = $d01d
.label BORDER_COL  = $d020
.label BG_COL0     = $d021
.label BG_COL1     = $d022
.label BG_COL2     = $d023
.label SPR0_COL    = $d027   // ...t/m $d02e voor sprite 1-7

// ---- SID ($D400-) : POT-lijnen voor de 1351-muis ----
.label POT_X       = $d419
.label POT_Y       = $d41a

// ---- CIA #1 ($DC00) : toetsenbord, joystick poort 2, timers ----
.label CIA1_PRA    = $dc00
.label CIA1_PRB    = $dc01
.label CIA1_DDRA   = $dc02
.label CIA1_DDRB   = $dc03
.label CIA1_ICR    = $dc0d

// ---- CIA #2 ($DD00) : VIC-bank, IEC-bus, joystick poort 1 ----
.label CIA2_PRA    = $dd00
.label CIA2_PRB    = $dd01
.label CIA2_DDRA   = $dd02
.label CIA2_ICR    = $dd0d

// ---- Kleuren-RAM ----
.label COLOR_RAM   = $d800

// ---- CPU / geheugenconfiguratie ----
.label CPU_PORT    = $01

// ---- KERNAL-vectoren ----
.label IRQ_VEC     = $0314
.label NMI_VEC     = $0318

// ---- EasyFlash ----
.label EF_BANK     = $de00   // bankselectie 0-63
.label EF_CTRL     = $de02   // controleregister (LED/GAME/EXROM/MODE)
.label EF_RAM      = $df00   // 256 bytes RAM, bank-onafhankelijk
