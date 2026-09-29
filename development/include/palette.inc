#importonce
//========================================================
// palette.inc - de 16 VIC-II-kleuren + thema-rollen
// Commodore Desk 64 - GEBRUIK UITSLUITEND DEZE KLEUREN
//========================================================

// ---- De 16 kleur-indexen ----
.const BLACK        = 0
.const WHITE        = 1
.const RED          = 2
.const CYAN         = 3
.const PURPLE       = 4
.const GREEN        = 5
.const BLUE         = 6
.const YELLOW       = 7
.const ORANGE       = 8
.const BROWN        = 9
.const LIGHT_RED    = 10
.const DARK_GREY    = 11
.const GREY         = 12
.const LIGHT_GREEN  = 13
.const LIGHT_BLUE   = 14
.const LIGHT_GREY   = 15

// ---- Standaard-thema (aanpasbaar door de gebruiker, fase 9) ----
.const THEME_DESKTOP_BG   = BLUE        // bureaublad-achtergrond ($D021)
.const THEME_BORDER       = LIGHT_BLUE  // schermrand ($D020)
.const THEME_MENUBAR_BG   = LIGHT_GREY  // menubalk-achtergrond
.const THEME_MENUBAR_TEXT = BLACK       // menubalk-tekst
.const THEME_DOCK_BG      = DARK_GREY   // dock-achtergrond
.const THEME_PANEL_BG     = GREY        // paneel/venster-achtergrond
.const THEME_TEXT         = WHITE       // standaardtekst
.const THEME_SELECT       = CYAN        // selectie/highlight
.const THEME_ACCENT       = YELLOW      // accent/actieve knop
.const THEME_WARN         = LIGHT_RED   // waarschuwing
