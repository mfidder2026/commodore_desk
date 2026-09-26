#importonce
//========================================================
// net/net.inc - netwerk-API: constanten (Milestone 1)
// Commodore Desk 64
//
// Zie docs/C64_Network_Stack_Technisch_Bouwplan.md.
//========================================================

// Compile-time platformkeuze (§42). AUTO = runtime-detectie.
.const PLATFORM_AUTO     = 0
.const PLATFORM_RRNET    = 1
.const PLATFORM_ULTIMATE = 2
.var PLATFORM = PLATFORM_AUTO

// Runtime-platform (netPlatform)
.const NET_PLAT_NONE     = 0
.const NET_PLAT_ULTIMATE = 1
.const NET_PLAT_RRNET    = 2

// Foutcodes (foutmodel uit het bouwplan)
.const NET_OK                     = 0
.const NET_ERR_NO_DEVICE          = 1
.const NET_ERR_TIMEOUT            = 2
.const NET_ERR_ARP                = 3
.const NET_ERR_DNS                = 4
.const NET_ERR_TCP                = 5
.const NET_ERR_CONNECTION_REFUSED = 6
.const NET_ERR_RESET              = 7
.const NET_ERR_PROTOCOL           = 8
.const NET_ERR_BUFFER             = 9
.const NET_ERR_IO_BUSY            = 10  // I/O-ruimte bezet (EasyFlash-cart)

// CS8900a via RR-Net op de clockport ($DE00). De RR-Net verwisselt
// adreslijn 3: register-offset n zit op $DE00 + (n XOR 8).
.const CS_BASE     = $de00
.const CS_RXTX     = CS_BASE + $08  // CS-offset $00: RX/TX-data
.const CS_TXCMD    = CS_BASE + $0c  // CS-offset $04: TX-commando
.const CS_TXLEN    = CS_BASE + $0e  // CS-offset $06: TX-lengte
.const CS_ISQ      = CS_BASE + $00  // CS-offset $08: interrupt status queue
.const CS_PPPTR    = CS_BASE + $02  // CS-offset $0A: PacketPage-pointer
.const CS_PPDATA   = CS_BASE + $04  // CS-offset $0C: PacketPage-data
.const RR_CTRL     = $de01          // Retro Replay: bit 0 = clockport aan
.const CS_PRODUCT_LO = $0e          // PacketPage $0000 = $630E
.const CS_PRODUCT_HI = $63

// Ultimate Command Interface (§6). Normaal op $DF1C; sommige carts
// verschuiven hem naar $DE1C.
.const UCI_BASE    = $df1c
.const UCI_ALT     = $de1c
.const UCI_ID      = $c9            // identificatie op base+1

// Netwerkconfig (NET.CFG), vast op $C400 zodat NETWORK, PING en CHAT
// (elk een eigen overlay) dezelfde instellingen zien. Tekstvelden zijn
// schermcodes, $ff-afgesloten. Marker "NC" = geldig.
.label NETCFG     = $c400
.label NC_MARK    = NETCFG + 0     // 2 bytes
.label NC_IP      = NETCFG + 2     // 4 bytes
.label NC_MASK    = NETCFG + 6
.label NC_GW      = NETCFG + 10
.label NC_DNS     = NETCFG + 14
.label NC_HOST    = NETCFG + 18    // chat-server: host/IP (max 32)
.label NC_PORT    = NETCFG + 51    // poort als tekst (max 5)
.label NC_KEY     = NETCFG + 57    // API-key (max 40)
.label NC_MODEL   = NETCFG + 98    // model (max 32)
.label NETCFG_END = NETCFG + 131

// Geheugen (§9): netwerkbuffers in het RAM onder de KERNAL ($E000+),
// bruikbaar zolang de OS met $35 draait. $C000-$C3FF is bezet door de
// launcher-stubs en DESK.APPS-records.
.const NET_RXBUF   = $e000          // $E000-$E5FF RX-pakket
.const NET_TXBUF   = $e600          // $E600-$EBFF TX-pakket
.const NET_WORK    = $ec00          // $EC00-$EFFF protocol/parser
