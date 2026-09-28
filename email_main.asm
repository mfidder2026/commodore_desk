//========================================================
// Commodore Desk 64 - email_main.asm
// EMAIL als losse assembly -> build\email.prg (overlay op $8000).
//
// Zoals bbs_main.asm: de netwerklaag (net/*) gaat mee, de Core-adressen
// komen uit build\core_syms.inc (tools\export_core_syms.py).
// Twee app-id's delen deze overlay: 9 = EMAIL, 10 = EMAIL SETTINGS
// (SYSTEM -> EMAIL); em_Init/em_Draw/em_Click kijken naar activeApp.
//
// ABI met de Core: sprongtabel op $8000 (zie EMAIL_* in gui/shell.asm).
//========================================================
// kleiner: zonder DHCP-client en netwerklog (instellen gebeurt in NETWORK)
#define NO_DHCP
#define NO_NETLOG
#import "include/hardware.inc"
#import "include/palette.inc"
#import "include/layout.inc"
#import "include/memmap.inc"
#import "include/abi.inc"
#import "include/events.inc"
#import "build/core_syms.inc"
#import "apps/email/mail.inc"

.segmentdef Email [start=$8000, max=$bfff]
.file [name="email.prg", segments="Email"]

.segment Email
        jmp em_Init              // $8000
        jmp em_Draw              // $8003
        jmp em_Click             // $8006
        jmp em_Key               // $8009

        // netwerklaag (dezelfde bronnen als de INET- en BBS-overlay)
        #import "net/net.inc"
        #import "net/netcommon.asm"
        #import "net/uci.asm"
        #import "net/cs8900.asm"
        #import "net/netdrv.asm"
        #import "net/ip.asm"
        #import "net/tcp.asm"
        #import "net/dns.asm"
        #import "net/ultimate.asm"
        #import "net/wic64net.asm"
        #import "net/logpoints.asm"
        // EMAIL
        #import "apps/email/mail_cfg.asm"
        #import "apps/email/mail_net.asm"
        #import "apps/email/mail_text.asm"
        #import "apps/email/mail_pop.asm"
        #import "apps/email/mail_smtp.asm"
        #import "apps/email/mail_ui.asm"
