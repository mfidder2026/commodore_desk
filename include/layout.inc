#importonce
//========================================================
// layout.inc - schermregio's (40 x 25 cellen)
// Commodore Desk 64
//
// De layout is RUNTIME instelbaar: teken- en app-code leest de
// content-grenzen uit de LAY_*-variabelen (hieronder), NOOIT uit
// hardgecodeerde rij-nummers. Zo is de dock-vorm later een keuze
// in Settings en blijft de C128-port (80 koloms) eenvoudig.
//========================================================

.const SCREEN_COLS    = 40
.const SCREEN_ROWS    = 25

// ---- Dock-modi ----
.const DOCK_MODE_LARGE   = 0   // 2x2-iconen + label  (status 21, dock 22-24)
.const DOCK_MODE_COMPACT = 1   // compacte iconen     (status 22, dock 23-24)
.const DEFAULT_DOCK_MODE = DOCK_MODE_LARGE

// ---- Preset: LARGE (standaard) ----
.const L_MENUBAR_ROW    = 0
.const L_CONTENT_TOP    = 1
.const L_CONTENT_BOTTOM = 20
.const L_STATUS_ROW     = 21
.const L_DOCK_ICON_ROW  = 22    // iconen beslaan rij 22-23 (2 hoog)
.const L_DOCK_LABEL_ROW = 24

// ---- Preset: COMPACT ----
.const C_MENUBAR_ROW    = 0
.const C_CONTENT_TOP    = 1
.const C_CONTENT_BOTTOM = 21
.const C_STATUS_ROW     = 22
.const C_DOCK_ICON_ROW  = 23
.const C_DOCK_LABEL_ROW = 24

// ---- Runtime layout-variabelen (OS-vars pagina, $0200) ----
// Bij boot gevuld uit het gekozen preset; Settings kan ze wijzigen
// en het scherm opnieuw laten tekenen.
.label LAY_dockMode      = $0200
.label LAY_menubarRow    = $0201
.label LAY_contentTop    = $0202
.label LAY_contentBottom = $0203
.label LAY_statusRow     = $0204
.label LAY_dockIconRow   = $0205
.label LAY_dockLabelRow  = $0206

// ---- Uiterlijk-instellingen (runtime, OS-vars pagina) ----
// Lettertype = charset. De 5 fonts delen hetzelfde UI-glyphblok
// (frames, dock-iconen, pijltjes); alleen de tekst-glyphs verschillen.
// Bij wissel/boot wordt de gekozen font naar CHARSET_BASE ($3800) gekopieerd.
.const FONT_SYSTEM  = 0    // strak modern 8x8 (default)
.const FONT_CLASSIC = 1    // nostalgische originele C64-stijl (schuin)
.const FONT_BOLD    = 2    // zwaar / hoog-contrast, extra leesbaar
.const FONT_LOWER   = 3    // kleine letters (C64 lowercase-set)
.const FONT_TINY    = 4    // eigen 3x5 micro-font (hele kleine letters)
// Van disk geladen fonts (charset naar $3800). Index op disk = id - FONT_FREMEN.
.const FONT_FREMEN  = 5    // eigen ronde sans (van disk)
.const FONT_SERIF   = 6    // serif (van disk)
.const FONT_MONO    = 7    // monospace/typemachine (van disk)
.const FONT_CASUAL  = 8    // rond/speels (van disk)
.const FONT_HEAVY   = 9    // zwaar display (van disk)
.const NUM_FONTS    = 10
.const DEFAULT_FONT = FONT_SYSTEM

.label CFG_fontId   = $0207   // actieve font (0..NUM_FONTS-1)

// ---- Thema-kleuren (runtime, instelbaar via Settings) ----
.label TH_border    = $0208   // schermrand ($D020)
.label TH_deskbg    = $0209   // bureaublad-achtergrond ($D021)
.label TH_menubg    = $020a   // menu-/statusbalk
.label TH_accent    = $020b   // titels/accent
.label TH_select    = $020c   // selectie/highlight

.label TH_text      = $020e   // standaardtekst (runtime)

// ---- Uitklapmenu-stijl (runtime, instelbaar via Settings) ----
.label CFG_menuFill = $020d   // 0 = doorzichtig, 1 = gevuld
.const MENU_CLEAR       = 0
.const MENU_FILLED      = 1
.const DEFAULT_MENUFILL = MENU_FILLED

// ---- Kleurprofiel (basis-thema, instelbaar via Settings) ----
.label CFG_profile  = $020f   // 0=C64, 1=Matrix, 2=Paper
.label CFG_sound    = $0210   // 0=uit, 1=aan (klik-piepje)

// ---- Win95-structuurkleuren (afgeleid van het profiel, NIET opgeslagen;
//      liggen net buiten het CFG-blok $0200-$0210) ----
.label TH_desktop   = $0211   // grijze desktop rond het venster
.label TH_title     = $0212   // titelbalk van vensters/dialogen

// ---- Venster-layout (Win95-stijl, vast) ----
//   rij 0      menubalk          rij 1      titelbalk
//   rij 2-22   vensterinhoud     rij 23     onderrand
//   rij 24     statusbalk met datum en tijd
.const WIN_BODY_TOP = 2
.const WIN_BODY_BOT = 22
.const WIN_FRAME_BOT = 23
.const STATUS_ROW   = 24
.const DEFAULT_SOUND    = 1
.const PROFILE_C64      = 0
.const PROFILE_MATRIX   = 1
.const PROFILE_PAPER    = 2
.const NUM_PROFILES     = 3
.const DEFAULT_PROFILE  = PROFILE_C64

// Vast UI-glyphblok binnen elke charset (identiek in alle fonts).
// Reserveer bijv. de bovenste tekens voor frames/iconen; tekst-glyphs
// staan op de standaard screencode-posities.
.const UI_GLYPH_FIRST = 96    // eerste screencode gereserveerd voor UI/iconen

// Basis van het scherm-RAM (char-mode). VIC-bank 0, scherm op $0400.
.label SCREEN_RAM     = $0400
