#importonce
//========================================================
// apps/web/web.inc - geheugen van WEB (de browser)
// Commodore Desk 64 - plan: docs/BROWSER_Plan.md
//========================================================
// De pagina: tekstregels vanaf WP_BEG (het werkgeheugen van de open app;
// $7000-$7FFF is van de F1-help). De bewaarde linkadressen groeien omlaag
// van $C000 tot het einde van de code (wbEnd), en daarna van WP_END omlaag
// (er blijft 2 KB voor tekst).
//   regel = [lengte] inhoud [lengte]; inhoud = schermcodes (< $80) en codes:
.const WB_W     = 35             // tekens per regel van de pagina
.label WP_BEG   = $4000
.label WP_END   = $6800
.label WU_TOP   = $c000
.const WC_ACC   = $f0            // accent aan (koppen)
.const WC_ACCX  = $f1            // accent uit
.const WC_LINK  = $f2            // link n begint (n volgt: 0-252, of een veld)
.const WC_LINKX = $f3            // link eindigt
.const WL_FIELD = $fe            // "link" = het zoekveld van het formulier
.const WL_SUBMIT= $fd            // "link" = de zoekknop
.const WL_MAX   = 253            // links 0-252

// Adressen: ASCII, 0-afgesloten, max. URL_MAX tekens (artikellinks van
// 68k.news zijn tot ~720 tekens lang).
.const URL_MAX  = 767
.label WB_HREF  = $c500          // waarde van een attribuut (768)
.label WB_NEW   = $c800          // adres dat geladen wordt (768)
.label WB_URL   = $cb00          // adres van de pagina (768; "" = MARKS)
.label WB_TITLE = $ce00          // titel (schermcodes, $ff), 36
.label WB_HOST  = $ce30          // host (schermcodes, $ff), 64
.label WB_PORT  = $ce70          // poort (schermcodes, $ff), 8
.label WB_LINE  = $ce80          // regel in opbouw (64)
.label WB_WORD  = $cec0          // woord in opbouw (64)
.label WB_EDIT  = $cf00          // adresregel om te typen (schermcodes, $ff), 128
.label WB_OUT   = $cf80          // een regel om te tekenen (48) + kleuren (48)
// $6800-$6FFF (werkgeheugen, onder de F1-help)
.label WB_BM    = $6800          // BOOKMARKS (gelezen bestand, 768)
.label WB_HDR   = $6b00          // kopregel van het antwoord (ASCII), 96
.label WB_NAME  = $6b60          // tag- en attribuutnaam, &naam; (16 + 16 + 16)
.label WB_ANAME = $6b70
.label WB_ENT   = $6b80
.label WB_INAME = $6b90          // input: name (32)
.label WB_ITYPE = $6bb0          // input: type (16)
.label WB_FVAL  = $6bc0          // zoektekst (schermcodes, $ff), 48
.label WB_FNAME = $6bf0          // naam van het zoekveld (ASCII, 0), 32
.label WB_FACT  = $6c10          // formulier: action (ASCII, 0), 160
.label WB_FHID  = $6cb0          // formulier: verborgen velden "&n=v..." (256)
// $F000-$F5FF en $F800-$FEFF (onder de KERNAL; netwerk = $E000-$EFFF, $F600)
.label LK_LO    = $f000          // per link: adres van het bewaarde adres, of
.label LK_HI    = $f100          //   LK_HI = 0: LK_LO/LK_H = controlegetal
.label LK_H     = $f200
.label WB_REQ   = $f800          // HTTP-verzoek (1 KB); ook Location (256) en
                                 // de basis voor ur_Resolve (UB = +256, 768)
// kopieerparen voor cp_Pair (web_url.asm)
.const CP_NEW_URL  = 0
.const CP_URL_UB   = 1
.const CP_URL_NEW  = 2
.const CP_NEW_HREF = 3
.const CP_HREF_NEW = 4
.const CP_NEW_UB   = 5
.const CP_REQ_HREF = 6
// terug-geschiedenis: 6 x 256 op $F300-$F5FF en $FC00-$FEFF (wbHistHi)

// voor apps/email/mail_net.asm (TCP), zoals RADIO/WEATHER
.const LB_MAX   = 200
.const CMD_MAX  = 200
.const MN_TIMEOUT = 1500
.label mnLine   = $f600
.label mnCmd    = $f6c8

// zeropage (vrij: $40-$8F, zie include/abi.inc)
.label wP  = $40                 // schrijfplek in de pagina
.label wU  = $42                 // onderkant van de linkadressen
.label wT  = $44                 // bovenste regel op het scherm
.label wQ  = $46                 // werkpointer
.label wS  = $48                 // bron (tekst, adres)
.label wD  = $4a                 // doel
.label wR  = $4c                 // ht_Str
.label wA  = $4e                 // attribuutwaarde (av_Put)
