#importonce
//========================================================
// events.inc - event-typen (gedeeld met los geassembleerde overlays)
// Commodore Desk 64
//========================================================
.const EVT_NONE      = 0
.const EVT_MOUSEDOWN = 1
.const EVT_MOUSEUP   = 2
.const EVT_KEY       = 3

// Toetscodes in evtA (naast schermcodes): vast in keyTab
.const KEY_RETURN  = $80
.const KEY_DEL     = $81
.const KEY_STOP    = $82
.const KEY_F1      = $83         // (in de shell: HELP)
// alleen in de ruwe modus (kbRaw = 1, BBS-terminal); evtB = modificaties
.const KEY_CRSR_R  = $84         // + SHIFT = links
.const KEY_CRSR_D  = $86         // + SHIFT = omhoog
.const KEY_F3      = $89
.const KEY_F5      = $8a
.const KEY_F7      = $8b
.const KEY_HOME    = $8c         // + SHIFT = CLR
.const KEY_AT      = $8d
.const KEY_POUND   = $8e
.const KEY_UPARROW = $8f
.const KEY_LARROW  = $90
.const KM_SHIFT = $01
.const KM_CTRL  = $02
.const KM_CBM   = $04
