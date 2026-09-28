#importonce
//========================================================
// apps/radio/radio.inc - geheugen van RADIO (en wat mail_net.asm nodig heeft)
// Commodore Desk 64
//========================================================
.label RL_BUF   = $c500          // RADIO.LST (tekst, regels met een 0)
.const RL_MAX   = $0afe          // t/m $CFFD; tools/make_radio_list.py blijft eronder
// voor apps/email/mail_net.asm (TCP + opdrachtbuffer)
.const LB_MAX   = 200
.const CMD_MAX  = 200            // HTTP-verzoek
.const MN_TIMEOUT = 1500
.label mnLine   = $f600          // (netwerklog is uit in deze overlay)
.label mnCmd    = $f6c8
