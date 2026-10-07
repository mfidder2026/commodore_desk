#importonce
//========================================================
// apps/weather/weather.inc - geheugen van WEATHER
// Commodore Desk 64
//========================================================
// $C500-$CFFF is app-buffer (vrij zolang WEATHER open is).
.label WE_BUF  = $c500           // 12 velden x 32 bytes (schermcodes, $ff)
.const WE_NF   = 12              // velden in het wttr.in-antwoord
.const WE_FL   = 32              // ruimte per veld
.label WE_SAVE = $c700           // 512 bytes: $3E00-$3FFF zolang de sprites er staan
.label WE_RAW  = $c900           // antwoord van wttr.in (max. 255 bytes + 0)
// verwachting (weather_fc.asm): 3 dagen x FC_DL bytes
.label WE_FC   = $ca00
.const FC_DL   = 48
.const FC_MAX  = 0               // max (schermcodes, $ff), 6 bytes
.const FC_MIN  = 6               // min, 6 bytes
.const FC_DESC = 12              // omschrijving, 22 tekens + $ff
.const FC_TYPE = 36              // weertype
.const FC_DOW  = 37              // weekdag (0 = zondag)
.const FC_RAIN = 38              // hoogste regenkans (0-100)
.label WE_STR  = $cb00           // JSON: de laatste tekst (32)
.label WE_KEY  = $cb20           // JSON: de laatste sleutel (32)
.label WE_OUT  = $cb40           // een regel om te tekenen (16)
// voor apps/email/mail_net.asm (TCP + opdrachtbuffer), zoals RADIO
.const LB_MAX   = 200
.const CMD_MAX  = 200            // HTTP-verzoek
.const MN_TIMEOUT = 1500
.label mnLine   = $f600          // (netwerklog is uit in deze overlay)
.label mnCmd    = $f6c8
// veldnummers (volgorde van het format: %l|%x|%t|%f|%C|%w|%h|%p|%P|%S|%s|%T)
.const WF_LOC   = 0
.const WF_SYM   = 1
.const WF_TEMP  = 2
.const WF_FEELS = 3
.const WF_COND  = 4
.const WF_WIND  = 5
.const WF_HUM   = 6
.const WF_RAIN  = 7
.const WF_PRESS = 8
.const WF_RISE  = 9
.const WF_SET   = 10
.const WF_TIME  = 11
