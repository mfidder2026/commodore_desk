#importonce
//========================================================
// apps/email/mail.inc - constanten en geheugenindeling van EMAIL
// Commodore Desk 64
//
// EMAIL is een aparte overlay (email_main.asm -> email.prg) met twee
// app-id's: 9 = EMAIL (postvak, lezen, opstellen), 10 = EMAIL SETTINGS
// (SYSTEM -> EMAIL). Ophalen via POP3, versturen via SMTP (AUTH PLAIN),
// zonder SSL/TLS.
//
// Geheugen (alleen zolang EMAIL draait; CHAT gebruikt dezelfde gebieden):
//   $C500-$C9EB  postvak: MB_MAX records van MB_REC bytes
//   $CA00-$CE37  opstelbuffer: CP_LINES regels van CP_W tekens
//   $CE38-$CFDB  protocolregel, opdracht, AUTH-buffer
//   $EC00-$F4FF  leesbuffer: MS_LINES regels van CP_W tekens
//   $F500-$F5F1  leesvelden (van, onderwerp, datum, adres), TO, SUBJ
//   ($F600-$F7FF netwerklog blijft vrij)
//   $F800-$FD77  SMTP-verzendbuffer (DATA)
//   $FD80-$FFED  headerbuffers, boundary, schrijfregel (niet bij SMTP)
//   ($FFFA-$FFFF: vectoren)
//========================================================

.const EM_APP_MAIL = 9
.const EM_APP_SET  = 10

.label MB_BASE  = $c500
.const MB_MAX   = 18             // berichten in de lijst (de nieuwste)
.const MB_REC   = 70
.const MB_NUM   = 0              // POP3-berichtnummer (2 bytes)
.const MB_FROM  = 2              // afzender: 30 tekens + $ff
.const MB_SUBJ  = 33             // onderwerp: 36 tekens + $ff
.const MB_FROMMAX = 30
.const MB_SUBJMAX = 36

.const CP_W     = 36             // regelbreedte (vensterinhoud kol 2-37)
.label CP_BODY  = $ca00
.const CP_LINES = 30
.const CP_VIS   = 15             // zichtbare regels in het opstelscherm
.const CP_TOP   = 5              // eerste schermrij van de tekst

.label MSGBUF   = $ec00
.const MS_LINES = 64
.const RD_VIS   = 15             // zichtbare regels in het leesscherm
.const RD_TOP   = 6

.label SENDBUF  = $f800
.const SEND_MAX = 1400

.const LB_MAX   = 200            // protocolregel (langere regels in stukken)
.const HV_MAX   = 120            // gedecodeerde headerwaarde
.const CMD_MAX  = 140            // POP3/SMTP-opdracht

// buffers buiten de overlay
.label mnLine  = $ce38           // LB_MAX
.label mnCmd   = $cf00           // CMD_MAX
.label smBuf   = $cf8c           // 80
.label rdFrom  = $f500           // 31
.label rdSubj  = $f51f           // 37
.label rdDate  = $f544           // 31
.label rdAddr  = $f563           // 61
.label cpTo    = $f5a0           // 41
.label cpSubj  = $f5c9           // 41 (-> $f5f2)
.label hvBuf0  = $fd80           // 4 x HV_MAX
.label hvBuf1  = hvBuf0 + HV_MAX
.label hvBuf2  = hvBuf1 + HV_MAX
.label hvBuf3  = hvBuf2 + HV_MAX
.label mmBnd   = hvBuf3 + HV_MAX // 70
.label twBuf   = mmBnd + 70      // CP_W
.label twTmp   = twBuf + CP_W    // CP_W (-> $ffee)

.const EM_MSG_ROW = 22
.const MN_TIMEOUT = 1500         // 30 s (beelden) wachten op een antwoord

// POP3-regelmodus
.const PM_SINGLE = 0
.const PM_MULTI  = 1             // statusregel, dan data tot "."
.const PM_DATA   = 2

// MIME-toestanden van de lezer
.const MS_HDR   = 0              // headers van het bericht
.const MS_SEEK  = 1              // multipart: wachten op --boundary
.const MS_PHDR  = 2              // headers van een deel
.const MS_BODY  = 3              // tekst tonen
.const MS_SKIP  = 4              // klaar: rest negeren

.const ENC_PLAIN = 0
.const ENC_QP    = 1
.const ENC_B64   = 2
