#importonce
//========================================================
// apps/bbs/bbs_directory.asm - ingebouwde BBS-lijst (bouwplan §7, §64)
// Commodore Desk 64
//
// Alle ingebouwde BBS-adressen staan hier, nergens anders. Namen en hosts
// zijn schermcodes (hosts worden bij het verbinden klein verstuurd).
// Een DIRECTORY-entry is alleen informatie: CONNECT staat uit.
// De tabellen hebben BBS_MAX plaatsen: 0-9 ingebouwd (vast), 10-15 eigen
// BBS'en uit BBS.BOOK (bbs_book.asm vult poort/modus/vlaggen; naam en host
// wijzen naar het boek). bbCount = aantal geldige entries.
//========================================================

.const BBS_DIRECTORY_VERSION = 2   // v2: Reflections/Afterlife (weg) -> Dead Zone/C64U Club
.const BBS_COUNT = 10             // ingebouwd
.const BBS_CUSTOM = 6             // eigen BBS'en (BBS.BOOK)
.const BBS_MAX = BBS_COUNT + BBS_CUSTOM
// BBS.BOOK: 4 bytes kop + BBS_CUSTOM records
.const BK_NAMEMAX = 20
.const BK_HOSTMAX = 32
.const BK_REC  = 57               // naam 21 + host 33 + poort 2 + modus 1
.const BK_NAME = 0
.const BK_HOST = 21
.const BK_PORT = 54
.const BK_MODE = 56

.const BM_DIRECTORY = 0
.const BM_PETSCII   = 1
.const BM_ASCII     = 2
.const BM_AUTO      = 3          // versie 1: AUTO = PETSCII

.const BF_CONNECT   = $01        // kan verbinden

//          ID 01      02      03      04      05      06      07      08      09      10   + eigen
bbNameLo:  .byte <bn01, <bn02, <bn03, <bn04, <bn05, <bn06, <bn07, <bn08, <bn09, <bn10
           .fill BBS_CUSTOM, <[bookBuf + 4 + i*BK_REC + BK_NAME]
bbNameHi:  .byte >bn01, >bn02, >bn03, >bn04, >bn05, >bn06, >bn07, >bn08, >bn09, >bn10
           .fill BBS_CUSTOM, >[bookBuf + 4 + i*BK_REC + BK_NAME]
bbHostLo:  .byte <bh01, <bh02, <bh03, <bh04, <bh05, <bh06, <bh07, <bh08, <bh09, <bh10
           .fill BBS_CUSTOM, <[bookBuf + 4 + i*BK_REC + BK_HOST]
bbHostHi:  .byte >bh01, >bh02, >bh03, >bh04, >bh05, >bh06, >bh07, >bh08, >bh09, >bh10
           .fill BBS_CUSTOM, >[bookBuf + 4 + i*BK_REC + BK_HOST]
bbPortLo:  .byte <0,    <1025,  <6400,  <6400,  <6400,  <6400,  <64128, <64128, <6400,  <2300
           .fill BBS_CUSTOM, 0
bbPortHi:  .byte >0,    >1025,  >6400,  >6400,  >6400,  >6400,  >64128, >64128, >6400,  >2300
           .fill BBS_CUSTOM, 0
bbMode:    .byte BM_DIRECTORY, BM_PETSCII, BM_PETSCII, BM_PETSCII, BM_PETSCII
           .byte BM_PETSCII, BM_PETSCII, BM_PETSCII, BM_PETSCII, BM_AUTO
           .fill BBS_CUSTOM, BM_PETSCII
bbFlags:   .byte 0, BF_CONNECT, BF_CONNECT, BF_CONNECT, BF_CONNECT
           .byte BF_CONNECT, BF_CONNECT, BF_CONNECT, BF_CONNECT, BF_CONNECT
           .fill BBS_CUSTOM, BF_CONNECT
.assert "bbPortLo compleet", bbPortHi - bbPortLo, BBS_MAX
bbCount:   .byte BBS_COUNT        // ingebouwd + eigen (na bb_BookLoad)

.const BBS_DEFAULT = 2           // compile-time default: THE OASIS BBS

bbModeLo:  .byte <bmDir, <bmPet, <bmAsc, <bmAuto
bbModeHi:  .byte >bmDir, >bmPet, >bmAsc, >bmAuto

.encoding "screencode_upper"
bn01: .text "COMMODORE BBS OUTPOST"
      .byte $ff
bn02: .text "GENETIC-PET"
      .byte $ff
bn03: .text "THE OASIS BBS"
      .byte $ff
bn04: .text "MICROTOWN BBS"
      .byte $ff
bn05: .text "CENTRONIAN BBS"
      .byte $ff
bn06: .text "PARTICLES! BBS"
      .byte $ff
bn07: .text "RAPIDFIRE"
      .byte $ff
bn08: .text "DEAD ZONE BBS"
      .byte $ff
bn09: .text "C64 ULTIMATE CLUB"
      .byte $ff
bn10: .text "MUTINY COMMUNITY"
      .byte $ff
bh01: .text "WWW.COMMODOREBBS.COM"
      .byte $ff
bh02: .text "G-POINT.TUNK.ORG"
      .byte $ff
bh03: .text "OASISBBS.HOPTO.ORG"
      .byte $ff
bh04: .text "MICROTOWNBBS.COM"
      .byte $ff
bh05: .text "BBS.CENTRONIAN.CA"
      .byte $ff
bh06: .text "PARTICLESBBS.DYNDNS.ORG"
      .byte $ff
bh07: .text "RAPIDFIRE.HOPTO.ORG"
      .byte $ff
bh08: .text "DZBBS.HOPTO.ORG"
      .byte $ff
bh09: .text "C64U.CLUB"
      .byte $ff
bh10: .text "MUTINYBBS.COM"
      .byte $ff
bmDir:  .text "DIRECTORY (INFO ONLY)"
        .byte $ff
bmPet:  .text "PETSCII"
        .byte $ff
bmAsc:  .text "ASCII"
        .byte $ff
bmAuto: .text "AUTO (PETSCII)"
        .byte $ff
