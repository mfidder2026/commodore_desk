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
