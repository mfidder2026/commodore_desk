#importonce
//========================================================
// apps/calendar/cal.inc - geheugen van CALENDAR
// Commodore Desk 64 - plan: docs/CALENDAR_Plan.md
//========================================================
// Datums: jaar = jaar - 1900 (0-199), maand 1-12, dag 1-31 (binair).
// Weekdag: 0 = maandag ... 6 = zondag.

// de afspraken (werkgeheugen van de app; $7000-$7FFF is van de F1-help)
.label CR_BUF  = $4000
.const CR_LEN  = 40              // per afspraak
.const CR_MAX  = 300             // $4000 + 300*40 = $6EE0
.const CR_Y    = 0               // jaar - 1900
.const CR_M    = 1
.const CR_D    = 2
.const CR_HH   = 3               // uur, $ff = de hele dag
.const CR_MM   = 4
.const CR_REP  = 5               // 0 niet, 1 week, 2 maand, 3 jaar
.const CR_DOW  = 6               // weekdag van de eerste keer
.const CR_TXT  = 7               // tekst: schermcodes, $ff (max. CT_W)
.const CT_W    = 27              // tekens tekst ("HH:MM R " + 27 = 35)

.const HOL_KING  = 6             // feestdagnummers (cal_date.asm)
.const HOL_QUEEN = 7

// $C500-$CFFF (app-buffer)
.label CL_LINE = $c500           // gelezen regel uit AGENDA (PETSCII), 80
.label CL_OUT  = $c550           // een regel om te tekenen/printen (48)
.label CL_EDIT = $c580           // invoerregel (schermcodes, $ff), 40
.label CL_HOL  = $c5c0           // feestdag per dag van de maand (0 = geen), 32
.label CL_MARK = $c5e0           // afspraken per dag van de maand (0/1), 32
.label CL_DAY  = $c600           // afspraken van de gekozen dag: adres lo
.label CL_DAYH = $c640           //   ... hi (max. CD_MAX)
.const CD_MAX  = 40

// zeropage (vrij: $40-$8F, zie include/abi.inc)
.label cP  = $40                 // werkpointer (afspraak)
.label cQ  = $42                 // tweede pointer
.label cS  = $44                 // bron (tekst)
