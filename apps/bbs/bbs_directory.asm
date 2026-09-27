#importonce
//========================================================
// apps/bbs/bbs_directory.asm - ingebouwde BBS-lijst (bouwplan §7, §64)
// Commodore Desk 64
//
// Alle BBS-adressen staan hier, nergens anders. Namen en hosts zijn
// schermcodes (hosts worden bij het verbinden klein verstuurd).
// Een DIRECTORY-entry is alleen informatie: CONNECT staat uit.
//========================================================

.const BBS_DIRECTORY_VERSION = 1
.const BBS_COUNT = 10

.const BM_DIRECTORY = 0
.const BM_PETSCII   = 1
.const BM_ASCII     = 2
.const BM_AUTO      = 3          // versie 1: AUTO = PETSCII

.const BF_CONNECT   = $01        // kan verbinden

//          ID 01      02      03      04      05      06      07      08      09      10
bbNameLo:  .byte <bn01, <bn02, <bn03, <bn04, <bn05, <bn06, <bn07, <bn08, <bn09, <bn10
bbNameHi:  .byte >bn01, >bn02, >bn03, >bn04, >bn05, >bn06, >bn07, >bn08, >bn09, >bn10
bbHostLo:  .byte <bh01, <bh02, <bh03, <bh04, <bh05, <bh06, <bh07, <bh08, <bh09, <bh10
bbHostHi:  .byte >bh01, >bh02, >bh03, >bh04, >bh05, >bh06, >bh07, >bh08, >bh09, >bh10
bbPortLo:  .byte <0,    <1025,  <6400,  <6400,  <6400,  <6400,  <64128, <64128, <6400,  <2300
bbPortHi:  .byte >0,    >1025,  >6400,  >6400,  >6400,  >6400,  >64128, >64128, >6400,  >2300
bbMode:    .byte BM_DIRECTORY, BM_PETSCII, BM_PETSCII, BM_PETSCII, BM_PETSCII
           .byte BM_PETSCII, BM_PETSCII, BM_PETSCII, BM_PETSCII, BM_AUTO
bbFlags:   .byte 0, BF_CONNECT, BF_CONNECT, BF_CONNECT, BF_CONNECT
           .byte BF_CONNECT, BF_CONNECT, BF_CONNECT, BF_CONNECT, BF_CONNECT
.assert "bbPortLo compleet", bbPortHi - bbPortLo, BBS_COUNT

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
bn08: .text "REFLECTIONS BBS"
      .byte $ff
bn09: .text "AFTERLIFE BBS"
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
bh08: .text "REFLECTIONS.HOPTO.ORG"
      .byte $ff
bh09: .text "AFTERLIFE.DYNU.COM"
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
