//========================================================
// Commodore Desk 64 - bbs_main.asm
// BBS-client als losse assembly -> build\bbs.prg (overlay op $8000).
//
// Apart geassembleerd zodat de netwerklaag (net/*) ook hierin mee kan
// zonder de broncode te dupliceren (KickAss zet geïmporteerde bestanden
// altijd in de globale namespace, dus twee overlays met dezelfde bronnen
// kunnen niet in één assembly). De Core-adressen komen uit
// build\core_syms.inc (tools\export_core_syms.py, na disk_main.asm).
//
// ABI met de Core: sprongtabel op $8000 (zie BBS_* in gui/shell.asm).
//========================================================
#import "include/hardware.inc"
#import "include/palette.inc"
#import "include/layout.inc"
#import "include/memmap.inc"
#import "include/abi.inc"
#import "include/events.inc"
#import "build/core_syms.inc"

.segmentdef Bbs [start=$8000, max=$bfff]
.file [name="bbs.prg", segments="Bbs"]

.segment Bbs
        jmp bbs_Init             // $8000
        jmp bbs_Draw             // $8003
        jmp bbs_Click            // $8006
        jmp bbs_Key              // $8009

        // netwerklaag (dezelfde bronnen als de INET-overlay)
        #import "net/net.inc"
        #import "net/log.asm"
        #import "net/netcommon.asm"
        #import "net/uci.asm"
        #import "net/cs8900.asm"
        #import "net/netdrv.asm"
        #import "net/ip.asm"
        #import "net/tcp.asm"
        #import "net/dns.asm"
        #import "net/dhcp.asm"
        #import "net/ultimate.asm"
        #import "net/logpoints.asm"
        // de BBS-client
        #import "apps/bbs/bbs_directory.asm"
        #import "apps/bbs/bbs_config.asm"
        #import "apps/bbs/bbs.asm"
        #import "apps/bbs/bbs_session.asm"
