#importonce
//========================================================
// memmap.inc - geheugenkaart + EasyFlash-layout
// Commodore Desk 64  (zie Ontwikkelplan §5.2 / §5.3)
// STARTVOORSTEL - definitief maken in fase 1.
//========================================================

// ---- RAM-indeling ----
.label SCREEN_RAM_BASE = $0400   // scherm-RAM (char-mode)
.label OS_VARS_BASE    = $0200   // OS-variabelen / event-queue / cursorstaat
.label KERNEL_BASE     = $0800   // resident kernel + framework (uit cart gekopieerd)
.label BITMAP_BASE     = $2000   // hi-res/MC bitmap (grafische apps)
.label CHARSET_BASE    = $3800   // herdefinieerde charset (boven de OS-image, VIC-bank 0)
.label APP_WORK_BASE   = $4000   // app-werkgeheugen + resources (ingebankt)
.label SCRATCH_BASE    = $c000   // vrije scratch / buffers

// ---- EasyFlash-configuratie ----
.const EF_NUM_BANKS    = 32      // 512 KB / 16 KB per bank
.const EF_MODE_16K     = $87     // $DE02: LED aan, 16K-modus ($8000 + $A000)
.const EF_MODE_8K      = $86     // $DE02: LED aan, 8K-modus ($8000)
.const EF_MODE_OFF     = $04     // cartridge uit (RAM zichtbaar), MODE-bit
