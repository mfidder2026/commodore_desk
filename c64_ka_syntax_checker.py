"""
Kick Assembler Syntax Checker
=============================

Statische controle van Kick Assembler bronbestanden (.asm) voor de Commodore 64.
Vindt fouten die anders pas bij het assembleren - of erger, pas op de C64 -
naar boven komen.

Gecontroleerd wordt onder meer:
  - balans van (), [], {} en van #if/#endif
  - niet-afgesloten strings en blokcommentaar
  - onbekende of verkeerd gespelde directives en preprocessor-directives
  - onbekende mnemonics, inclusief mnemonics die wel bestaan maar niet in de
    geselecteerde .cpu (bv. 'bra' onder _6502, 'lax' onder _6502NoIllegals)
  - ongeldige adresseringsmodi per mnemonic (bv. 'sta #$10', 'ldx $10,x')
  - geforceerde modi (.abs/.zp/...) die het mnemonic niet kent
  - ';' gebruikt als regelcommentaar (in Kick Assembler is dat een
    statement-scheider - een klassieke fout bij overstappers)
  - leidende '(' die als indirecte adressering wordt gelezen terwijl
    groepering bedoeld is (gebruik [] daarvoor)
  - waardebereiken: #$100, .byte 256, .word $10000
  - .for-headers zonder twee puntkomma's
  - .function zonder .return
  - macro-/pseudocommand-aanroepen met het verkeerde aantal argumenten
  - dubbel gedefinieerde labels binnen dezelfde scope
  - .eval op een variabele die nergens met .var is gedeclareerd
  - ontbrekend laadadres (* = ...) / segment
  - bestaan van bestanden bij #import en .import (alleen bij check_file)

Gebruik:
    python c64_ka_syntax_checker.py bron.asm
    python c64_ka_syntax_checker.py bron.asm --json
    python c64_ka_syntax_checker.py bron.asm --no-warn
    python c64_ka_syntax_checker.py bron.asm --cpu _65c02

Beperkingen:
  - Dit is een statische controle, geen assembler. Waarden van labels en
    expressies worden niet uitgerekend, dus zaken als branch-bereik,
    geheugenoverlap en zeropage-keuze worden NIET gecontroleerd.
  - Definities uit geimporteerde bestanden worden niet meegenomen; daarom zijn
    onbekende bezoekers van het type 'MyMacro()' waarschuwingen, geen fouten.
"""
from __future__ import annotations

import json
import os
import re
import sys
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, Tuple

# ---------------------------------------------------------------------------
# Opcode-tabellen
# ---------------------------------------------------------------------------
# Per mnemonic de hardware-adresseringsmodi. Afkortingen:
#   noarg  geen argument (incl. accumulator-vorm)
#   imm    #waarde
#   zp     $12          abs   $1234        rel   label
#   zpx    $12,x        abx   $1234,x
#   zpy    $12,y        aby   $1234,y
#   izx    ($12,x)      izy   ($12),y
#   ind    ($1234)      izp   ($12)   [65c02]
#   indx   ($1234,x)    [65c02 jmp]
#   zprel  $12,label    [65c02 bbr/bbs]

_STANDARD = {
    "adc": "imm,zp,zpx,izx,izy,abs,abx,aby",
    "and": "imm,zp,zpx,izx,izy,abs,abx,aby",
    "asl": "noarg,zp,zpx,abs,abx",
    "bcc": "rel", "bcs": "rel", "beq": "rel", "bmi": "rel",
    "bne": "rel", "bpl": "rel", "bvc": "rel", "bvs": "rel",
    "bit": "zp,abs",
    "brk": "noarg",
    "clc": "noarg", "cld": "noarg", "cli": "noarg", "clv": "noarg",
    "cmp": "imm,zp,zpx,izx,izy,abs,abx,aby",
    "cpx": "imm,zp,abs",
    "cpy": "imm,zp,abs",
    "dec": "zp,zpx,abs,abx",
    "dex": "noarg", "dey": "noarg",
    "eor": "imm,zp,zpx,izx,izy,abs,abx,aby",
    "inc": "zp,zpx,abs,abx",
    "inx": "noarg", "iny": "noarg",
    "jmp": "abs,ind",
    "jsr": "abs",
    "lda": "imm,zp,zpx,izx,izy,abs,abx,aby",
    "ldx": "imm,zp,zpy,abs,aby",
    "ldy": "imm,zp,zpx,abs,abx",
    "lsr": "noarg,zp,zpx,abs,abx",
    "nop": "noarg",
    "ora": "imm,zp,zpx,izx,izy,abs,abx,aby",
    "pha": "noarg", "php": "noarg", "pla": "noarg", "plp": "noarg",
    "rol": "noarg,zp,zpx,abs,abx",
    "ror": "noarg,zp,zpx,abs,abx",
    "rti": "noarg", "rts": "noarg",
    "sbc": "imm,zp,zpx,izx,izy,abs,abx,aby",
    "sec": "noarg", "sed": "noarg", "sei": "noarg",
    "sta": "zp,zpx,izx,izy,abs,abx,aby",
    "stx": "zp,zpy,abs",
    "sty": "zp,zpx,abs",
    "tax": "noarg", "tay": "noarg", "tsx": "noarg",
    "txa": "noarg", "txs": "noarg", "tya": "noarg",
}

# Illegale opcodes. Aliassen staan als losse ingangen.
_ILLEGAL_EXTRA = {
    "ahx": "izy,aby", "sha": "izy,aby",
    "alr": "imm", "asr": "imm",
    "anc": "imm", "anc2": "imm",
    "arr": "imm",
    "axs": "imm", "sbx": "imm",
    "dcp": "zp,zpx,izx,izy,abs,abx,aby", "dcm": "zp,zpx,izx,izy,abs,abx,aby",
    "isc": "zp,zpx,izx,izy,abs,abx,aby", "ins": "zp,zpx,izx,izy,abs,abx,aby",
    "isb": "zp,zpx,izx,izy,abs,abx,aby",
    "las": "aby", "lae": "aby", "lds": "aby",
    "lax": "imm,zp,zpy,izx,izy,abs,aby", "lxa": "imm,zp,zpy,izx,izy,abs,aby",
    "rla": "zp,zpx,izx,izy,abs,abx,aby",
    "rra": "zp,zpx,izx,izy,abs,abx,aby",
    "sax": "zp,zpy,izx,abs",
    "sbc2": "imm",
    "shx": "aby", "shy": "abx",
    "slo": "zp,zpx,izx,izy,abs,abx,aby",
    "sre": "zp,zpx,izx,izy,abs,abx,aby",
    "tas": "aby", "shs": "aby",
    "xaa": "imm", "ane": "imm",
}
# nop krijgt er onder de illegale set extra modi bij
_ILLEGAL_NOP = "noarg,imm,zp,zpx,abs,abx"

_DTV_EXTRA = {"bra": "rel", "sac": "imm", "sir": "imm"}

# 65c02: standaardset met wijzigingen en uitbreidingen
_65C02_OVERRIDE = {
    "adc": "imm,zp,zpx,izx,izy,abs,abx,aby,izp",
    "and": "imm,zp,zpx,izx,izy,abs,abx,aby,izp",
    "bit": "imm,zp,zpx,abs,abx",
    "bra": "rel",
    "cmp": "imm,zp,zpx,izx,izy,abs,abx,aby,izp",
    "dec": "noarg,zp,zpx,abs,abx",
    "eor": "imm,zp,zpx,izx,izy,abs,abx,aby,izp",
    "inc": "noarg,zp,zpx,abs,abx",
    "jmp": "abs,ind,indx",
    "lda": "imm,zp,zpx,izx,izy,abs,abx,aby,izp",
    "ora": "imm,zp,zpx,izx,izy,abs,abx,aby,izp",
    "phx": "noarg", "phy": "noarg", "plx": "noarg", "ply": "noarg",
    "sbc": "imm,zp,zpx,izx,izy,abs,abx,aby,izp",
    "sta": "zp,zpx,izx,izy,abs,abx,aby,izp",
    "stp": "noarg",
    "stz": "zp,zpx,abs,abx",
    "trb": "zp,abs",
    "tsb": "zp,abs",
    "wai": "noarg",
}
for _n in range(8):
    _65C02_OVERRIDE["bbr%d" % _n] = "zprel"
    _65C02_OVERRIDE["bbs%d" % _n] = "zprel"
    _65C02_OVERRIDE["rmb%d" % _n] = "zp"
    _65C02_OVERRIDE["smb%d" % _n] = "zp"


def _build_cpu_tables() -> Dict[str, Dict[str, Set[str]]]:
    def split(d):
        return {k: set(v.split(",")) for k, v in d.items()}

    plain = split(_STANDARD)

    illegal = {k: set(v) for k, v in plain.items()}
    illegal.update(split(_ILLEGAL_EXTRA))
    illegal["nop"] = set(_ILLEGAL_NOP.split(","))

    dtv = {k: set(v) for k, v in illegal.items()}
    dtv.update(split(_DTV_EXTRA))

    c02 = {k: set(v) for k, v in plain.items()}
    c02.update(split(_65C02_OVERRIDE))

    return {
        "_6502noillegals": plain,
        "_6502": illegal,
        "dtv": dtv,
        "_65c02": c02,
    }


CPU_TABLES = _build_cpu_tables()
DEFAULT_CPU = "_6502"
ALL_MNEMONICS: Set[str] = set()
for _t in CPU_TABLES.values():
    ALL_MNEMONICS |= set(_t.keys())

# hardware-modus -> syntactische vorm zoals hij in de bron staat.
# zp en abs zijn syntactisch niet te onderscheiden zonder de waarde te kennen,
# dus die vallen samen. Hetzelfde geldt voor zpx/abx en zpy/aby.
MODE_TO_SYNTAX = {
    "noarg": "NONE",
    "imm": "IMM",
    "zp": "DIRECT", "abs": "DIRECT", "rel": "DIRECT",
    "zpx": "DIRECT_X", "abx": "DIRECT_X",
    "zpy": "DIRECT_Y", "aby": "DIRECT_Y",
    "izx": "IND_X", "indx": "IND_X",
    "izy": "IND_Y",
    "ind": "IND", "izp": "IND",
    "zprel": "DIRECT_LABEL",
}

SYNTAX_EXAMPLE = {
    "NONE": "geen argument",
    "IMM": "#waarde",
    "DIRECT": "adres",
    "DIRECT_X": "adres,x",
    "DIRECT_Y": "adres,y",
    "IND_X": "(adres,x)",
    "IND_Y": "(adres),y",
    "IND": "(adres)",
    "DIRECT_LABEL": "adres,label",
}

# Geforceerde modus-achtervoegsels achter een mnemonic (lda.abs, stx.zp, ...)
FORCED_SUFFIX = {
    "a": "DIRECT", "abs": "DIRECT",
    "z": "DIRECT", "zp": "DIRECT",
    "im": "IMM", "imm": "IMM",
    "zx": "DIRECT_X", "zpx": "DIRECT_X",
    "ax": "DIRECT_X", "absx": "DIRECT_X",
    "zy": "DIRECT_Y", "zpy": "DIRECT_Y",
    "ay": "DIRECT_Y", "absy": "DIRECT_Y",
    "izx": "IND_X", "izpx": "IND_X",
    "izy": "IND_Y", "izpy": "IND_Y",
    "i": "IND", "ind": "IND",
    "r": "DIRECT", "rel": "DIRECT",
}
DEPRECATED_SUFFIX = {
    "im", "imm", "zx", "zpx", "zy", "zpy", "izx", "izpx",
    "izy", "izpy", "ax", "absx", "ay", "absy", "i", "ind", "r", "rel",
}

# ---------------------------------------------------------------------------
# Directives
# ---------------------------------------------------------------------------
DIRECTIVES = {
    "align", "assert", "asserterror", "break", "by", "byte", "const", "cpu",
    "define", "disk", "dw", "dword", "encoding", "enum", "error", "errorif",
    "eval", "file", "filemodify", "filenamespace", "fill", "fillword", "for",
    "function", "if", "import", "importonce", "label", "lohifill", "macro",
    "memblock", "modify", "namespace", "pc", "plugin", "print", "printnow",
    "pseudocommand", "pseudopc", "return", "segment", "segmentdef",
    "segmentout", "struct", "te", "text", "var", "watch", "while", "wo",
    "word", "zp",
}

PP_DIRECTIVES = {
    "define", "elif", "else", "endif", "if", "import", "importif",
    "importonce", "undef",
}

BLOCK_DIRECTIVES = {"macro", "function", "pseudocommand", "define", "namespace",
                    "struct", "modify", "filemodify"}

ENCODINGS = {"ascii", "petscii_mixed", "petscii_upper",
             "screencode_mixed", "screencode_upper"}

CPU_NAMES = {"_6502noillegals", "_6502", "dtv", "_65c02"}

SEGMENT_PARAMS = {
    "align", "allowoverlap", "dest", "fill", "fillbyte", "hide", "marg1",
    "marg2", "marg3", "marg4", "marg5", "max", "min", "modify", "outbin",
    "outprg", "prgfiles", "segments", "sidfiles", "start", "startafter",
    "virtual",
}
FILE_PARAMS = SEGMENT_PARAMS | {"mbfiles", "name", "type"}
DISK_PARAMS = {
    "dontsplitfilesoverdir", "filename", "format", "id", "interleave", "name",
    "showinfo", "storefilesindir",
}
DISK_FILE_PARAMS = SEGMENT_PARAMS | {
    "hide", "interleave", "name", "nostartaddr", "type",
}

IMPORT_KINDS = {"binary", "c64", "text", "source"}

# Directives die bytes produceren. Een label ervoor wijst dus naar data,
# niet naar uitvoerbare code.
DATA_DIRECTIVES = {"byte", "by", "word", "wo", "dword", "dw", "text", "te",
                   "fill", "fillword", "lohifill", "import"}

# Macro's die Kick Assembler zelf meelevert (autoinclude.asm in de jar).
BUILTIN_MACROS = {"BasicUpstart": 1, "BasicUpstart2": 1}

# Woorden uit de scripttaal die aan het begin van een statement mogen staan
# zonder dat het een mnemonic of macro is.
SCRIPT_KEYWORDS = {"else", "var", "true", "false", "null", "a", "x", "y"}

# ---------------------------------------------------------------------------
# Tokenizer
# ---------------------------------------------------------------------------


@dataclass
class Token:
    kind: str   # 'nl' 'id' 'dir' 'pp' 'num' 'str' 'char' 'op'
    text: str
    line: int
    value: Optional[int] = None   # alleen voor 'num' als het een integer is


_TWO_CHAR_OPS = {"==", "!=", "<=", ">=", "&&", "||", "<<", ">>", "++", "--",
                 "+=", "-=", "*=", "/="}

_IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_NUM_RE = re.compile(r"\$[0-9a-fA-F]+|%[01]+|\d+(?:\.\d+)?")


class TokenizeResult:
    def __init__(self):
        self.tokens: List[Token] = []
        self.errors: List[Tuple[int, str]] = []


def tokenize(text: str) -> TokenizeResult:
    """Zet de bron om in tokens. Commentaar wordt verwijderd, strings blijven
    als een enkel 'str'-token staan."""
    res = TokenizeResult()
    out = res.tokens
    i = 0
    line = 1
    n = len(text)
    at_line_start = True

    def emit(kind, txt, value=None):
        nonlocal at_line_start
        out.append(Token(kind, txt, line, value))
        at_line_start = False

    while i < n:
        c = text[i]

        if c == "\n":
            out.append(Token("nl", "\n", line))
            line += 1
            i += 1
            at_line_start = True
            continue

        if c in " \t\r":
            i += 1
            continue

        # commentaar
        if c == "/" and i + 1 < n:
            if text[i + 1] == "/":
                while i < n and text[i] != "\n":
                    i += 1
                continue
            if text[i + 1] == "*":
                start_line = line
                i += 2
                closed = False
                while i < n:
                    if text[i] == "\n":
                        line += 1
                    elif text[i] == "*" and i + 1 < n and text[i + 1] == "/":
                        i += 2
                        closed = True
                        break
                    i += 1
                if not closed:
                    res.errors.append(
                        (start_line, "Blokcommentaar /* is nooit afgesloten met */"))
                continue

        # string, eventueel met @ ervoor (escape-string)
        if c == '"' or (c == "@" and i + 1 < n and text[i + 1] == '"'):
            escaped = c == "@"
            start_line = line
            j = i + (2 if escaped else 1)
            buf = []
            closed = False
            while j < n:
                ch = text[j]
                if ch == "\n":
                    break
                if escaped and ch == "\\" and j + 1 < n:
                    buf.append(text[j + 1])
                    j += 2
                    continue
                if ch == '"':
                    closed = True
                    j += 1
                    break
                buf.append(ch)
                j += 1
            if not closed:
                res.errors.append(
                    (start_line, "String is niet afgesloten met een dubbele quote"))
            emit("str", "".join(buf))
            i = j
            continue

        # char-literal 'x'  (alleen als de sluitquote op dezelfde regel staat)
        if c == "'":
            j = i + 1
            buf = []
            closed = False
            while j < n and text[j] != "\n":
                if text[j] == "'":
                    closed = True
                    j += 1
                    break
                buf.append(text[j])
                j += 1
            if closed and len(buf) <= 2:
                emit("char", "".join(buf))
                i = j
                continue
            # geen geldige char-literal: behandel als losse operator
            emit("op", "'")
            i += 1
            continue

        # preprocessor-directive (# als eerste teken op de regel)
        if c == "#" and at_line_start:
            m = _IDENT_RE.match(text, i + 1)
            if m:
                emit("pp", m.group(0).lower())
                i = m.end()
                continue

        # assembler-directive
        if c == "." :
            m = _IDENT_RE.match(text, i + 1)
            if m:
                emit("dir", m.group(0))
                i = m.end()
                continue

        m = _NUM_RE.match(text, i)
        if m:
            raw = m.group(0)
            val = None
            try:
                if raw.startswith("$"):
                    val = int(raw[1:], 16)
                elif raw.startswith("%"):
                    val = int(raw[1:], 2)
                elif "." not in raw:
                    val = int(raw)
            except ValueError:
                val = None
            emit("num", raw, val)
            i = m.end()
            continue

        m = _IDENT_RE.match(text, i)
        if m:
            emit("id", m.group(0))
            i = m.end()
            continue

        two = text[i:i + 2]
        if two in _TWO_CHAR_OPS:
            emit("op", two)
            i += 2
            continue

        emit("op", c)
        i += 1

    out.append(Token("nl", "\n", line))
    return res


# ---------------------------------------------------------------------------
# Statements
# ---------------------------------------------------------------------------

@dataclass
class Statement:
    """Eén statement: optionele labels, daarna de tokens tot de volgende
    scheider (';', '{', '}' of regeleinde)."""
    line: int
    tokens: List[Token] = field(default_factory=list)
    labels: List[str] = field(default_factory=list)
    depth: int = 0
    is_data: bool = False   # binnen een .enum- of .struct-body


@dataclass
class Issue:
    line: Optional[int]
    severity: str          # 'ERROR' of 'WARN'
    message: str


class KickAssChecker:
    def __init__(self, cpu: str = DEFAULT_CPU, base_dir: Optional[str] = None):
        self.issues: List[Issue] = []
        self.tokens: List[Token] = []
        self.statements: List[Statement] = []
        self.cpu = cpu.lower()
        self.base_dir = base_dir
        self.check_imports = base_dir is not None
        # verzamelde definities
        self.macros: Dict[str, int] = dict(BUILTIN_MACROS)  # naam -> aantal params
        self.functions: Dict[str, int] = {}
        self.pseudocommands: Dict[str, int] = {}    # naam -> aantal argumenten
        self.declared_vars: Set[str] = set()
        self.declared_consts: Set[str] = set()
        self.labels_by_scope: Dict[Tuple[int, str], int] = {}
        self.data_labels: Dict[str, int] = {}
        self.segment_defs: Dict[str, int] = {}
        self.has_imports = False
        self._prose_lines: Set[int] = set()
        self._warned_import_source = False
        self.is_include = False
        self.looks_like_main = False
        # In een bestand met #if/#else staan alternatieve definities van
        # hetzelfde label of dezelfde macro naast elkaar. Slechts één tak wordt
        # geassembleerd, dus dat is geen dubbele definitie.
        self.has_pp_branches = False
        self.has_start_address = False
        self.has_segment = False
        self.mnemonic_count = 0
        # Adressen achter .const-namen. Zonder deze tabel zien de
        # hardwarecontroles alleen kale getallen, terwijl vrijwel niemand
        # $d018 letterlijk uitschrijft.
        self.const_values: Dict[str, int] = {}
        self._label_names: Set[str] = set()
        self.source_text = ""

    # -- hulpjes -----------------------------------------------------------
    def _add(self, line: Optional[int], severity: str, msg: str):
        self.issues.append(Issue(line, severity, msg))

    def _error(self, line, msg):
        self._add(line, "ERROR", msg)

    def _warn(self, line, msg):
        self._add(line, "WARN", msg)

    def _cpu_table(self) -> Dict[str, Set[str]]:
        return CPU_TABLES.get(self.cpu, CPU_TABLES[DEFAULT_CPU])

    # -- laden -------------------------------------------------------------
    def load(self, text: str):
        self.source_text = text
        # Constanten staan vrijwel altijd in een apart bestand dat via
        # #import binnenkomt. Zonder de imports erbij kent de checker
        # alleen de getallen die letterlijk in dit bestand staan, en dan
        # zien de hardwarecontroles een 'sta VMCSB' voor niets aan.
        parts = self._project_texts()
        joined = "\n".join(parts) if parts else text
        self.const_values = self._collect_const_values(joined)
        result = tokenize(text)
        self.has_pp_branches = any(
            t.kind == "pp" and t.text in ("if", "elif", "else")
            for t in result.tokens)
        for line, msg in result.errors:
            self._error(line, msg)
        self.tokens = result.tokens
        self._scan_semicolon_comments(text)
        self._build_statements()

    def _scan_semicolon_comments(self, text: str):
        """';' is in Kick Assembler een statement-scheider, geen commentaar.
        Wie uit een andere assembler komt schrijft toch ';commentaar'."""
        in_block = False
        for lineno, raw in enumerate(text.splitlines(), 1):
            i = 0
            in_str = False
            while i < len(raw):
                ch = raw[i]
                if in_block:
                    if ch == "*" and raw[i:i + 2] == "*/":
                        in_block = False
                        i += 2
                        continue
                    i += 1
                    continue
                if in_str:
                    if ch == '"':
                        in_str = False
                    i += 1
                    continue
                if ch == '"':
                    in_str = True
                    i += 1
                    continue
                if raw[i:i + 2] == "//":
                    break
                if raw[i:i + 2] == "/*":
                    in_block = True
                    i += 2
                    continue
                if ch == ";":
                    rest = raw[i + 1:]
                    cut = rest.find("//")
                    if cut >= 0:
                        rest = rest[:cut]
                    if self._looks_like_prose(rest):
                        self._prose_lines.add(lineno)
                        self._warn(
                            lineno,
                            "';' is in Kick Assembler een statement-scheider, geen "
                            "commentaar - gebruik '//' voor commentaar")
                        break
                i += 1

    @staticmethod
    def _looks_like_prose(rest: str) -> bool:
        rest = rest.strip()
        if not rest:
            return False
        words = rest.split()
        first = words[0].lower().rstrip(":")
        if first.startswith(".") or first.startswith("#"):
            return False
        if first in ALL_MNEMONICS:
            return False
        # een tweede statement heeft bijna altijd een operand of haakjes
        if any(c in rest for c in "()=$#%"):
            return False
        # één woord kan een macro-aanroep zonder haakjes zijn; twee of meer
        # losse woorden zonder operator is vrijwel zeker proza
        return len(words) >= 2

    def _build_statements(self):
        depth = 0
        paren = 0          # diepte van () en [] - daarbinnen scheidt ';' niet
        scope_counter = 0
        scope_stack = [0]  # unieke id per accolade-blok, 0 = root
        cur = Statement(line=1)
        pending_labels: List[str] = []

        data_depth: Optional[int] = None

        def flush():
            nonlocal cur, pending_labels, data_depth, scope_counter
            if not cur.tokens:
                # Alleen labels op deze regel: laat ze staan tot het volgende
                # statement, want 'label:' en de bijbehorende data of code
                # staan vaak op aparte regels.
                return
            if cur.tokens or pending_labels:
                cur.labels = pending_labels
                cur.depth = depth
                cur.is_data = data_depth is not None
                self.statements.append(cur)
                if cur.tokens and cur.tokens[0].kind == "dir":
                    d = cur.tokens[0].text.lower()
                    if d in ("enum", "struct"):
                        data_depth = depth + 1
                    elif d == "filenamespace":
                        # Alles hierna zit in een nieuwe namespace, dus labels
                        # botsen niet meer met wat ervoor stond.
                        scope_counter += 1
                        scope_stack[0] = scope_counter
            pending_labels = []
            cur = Statement(line=1)

        idx = 0
        toks = self.tokens
        while idx < len(toks):
            t = toks[idx]

            if t.kind == "nl":
                if paren == 0:
                    flush()
                idx += 1
                continue

            if t.kind == "op" and t.text in "([":
                paren += 1
            elif t.kind == "op" and t.text in ")]":
                paren = max(0, paren - 1)

            if paren == 0 and t.kind == "op" and t.text in "{}":
                flush()
                if t.text == "{":
                    depth += 1
                    scope_counter += 1
                    scope_stack.append(scope_counter)
                else:
                    depth = max(0, depth - 1)
                    if len(scope_stack) > 1:
                        scope_stack.pop()
                    if data_depth is not None and depth < data_depth:
                        data_depth = None
                idx += 1
                continue

            if paren == 0 and t.kind == "op" and t.text == ";":
                flush()
                idx += 1
                continue

            # labeldefinitie aan het begin van een statement
            if not cur.tokens:
                lbl = self._match_label_def(toks, idx)
                if lbl is not None:
                    name, consumed = lbl
                    pending_labels.append(name)
                    self._register_label(name, scope_stack[-1], t.line)
                    idx += consumed
                    continue

            # ':' vlak voor een macro-aanroep is optioneel en mag weg
            if not cur.tokens and t.kind == "op" and t.text == ":":
                idx += 1
                continue

            if not cur.tokens:
                cur.line = t.line
            cur.tokens.append(t)
            idx += 1

        flush()

    def _match_label_def(self, toks: List[Token], idx: int):
        """Herkent 'naam:' en '!naam:' en '!:' aan het begin van een statement."""
        t = toks[idx]
        if t.kind == "id" and idx + 1 < len(toks):
            nxt = toks[idx + 1]
            if nxt.kind == "op" and nxt.text == ":":
                return t.text, 2
            return None
        if t.kind == "op" and t.text == "!":
            j = idx + 1
            name = "!"
            if j < len(toks) and toks[j].kind == "id":
                name += toks[j].text
                j += 1
            if j < len(toks) and toks[j].kind == "op" and toks[j].text == ":":
                return name, (j - idx) + 1
        if t.kind == "op" and t.text == "@" and idx + 2 < len(toks):
            if toks[idx + 1].kind == "id" and toks[idx + 2].text == ":":
                return "@" + toks[idx + 1].text, 3
        return None

    def _register_label(self, name: str, scope_id: int, line: int):
        if name.startswith("!"):
            return    # multi-labels mogen bewust herhaald worden
        key = (scope_id, name.lstrip("@"))
        if key in self.labels_by_scope:
            if self.has_pp_branches:
                return   # kan in verschillende #if-takken staan
            self._error(line,
                        "Label '%s' is in deze scope al gedefinieerd op regel %d"
                        % (name, self.labels_by_scope[key]))
        else:
            self.labels_by_scope[key] = line

    # -- validatie ---------------------------------------------------------
    def validate(self):
        self._check_brackets()
        self._check_preprocessor_balance()
        self._collect_definitions()
        self._check_statements()
        self._check_global()

    # ---- haakjes ----
    def _check_brackets(self):
        pairs = {")": "(", "]": "[", "}": "{"}
        opens = {"(": ")", "[": "]", "{": "}"}
        stack: List[Token] = []
        for t in self.tokens:
            if t.kind != "op":
                continue
            if t.text in opens:
                stack.append(t)
            elif t.text in pairs:
                if not stack:
                    self._error(t.line, "Sluitend '%s' zonder bijbehorend '%s'"
                                % (t.text, pairs[t.text]))
                    continue
                top = stack.pop()
                if top.text != pairs[t.text]:
                    self._error(t.line,
                                "'%s' sluit een '%s' die op regel %d is geopend"
                                % (t.text, top.text, top.line))
        for t in stack:
            self._error(t.line, "'%s' wordt nergens gesloten" % t.text)

    # ---- preprocessor ----
    def _check_preprocessor_balance(self):
        # elk element is [regel van de #if, heeft al een #else gezien]
        stack: List[List] = []
        for t in self.tokens:
            if t.kind != "pp":
                continue
            name = t.text
            if name not in PP_DIRECTIVES:
                self._error(t.line, "Onbekende preprocessor-directive '#%s'" % name)
                continue
            if name == "if":
                stack.append([t.line, False])
            elif name in ("elif", "else"):
                if not stack:
                    self._error(t.line, "#%s zonder bijbehorende #if" % name)
                    continue
                if stack[-1][1]:
                    self._error(t.line,
                                "#%s na het #else van de #if op regel %d"
                                % (name, stack[-1][0]))
                if name == "else":
                    stack[-1][1] = True
            elif name == "endif":
                if not stack:
                    self._error(t.line, "#endif zonder bijbehorende #if")
                else:
                    stack.pop()
        for line, _ in stack:
            self._error(line, "#if wordt nergens afgesloten met #endif")

    # ---- definities verzamelen ----
    def _collect_definitions(self):
        for st in self.statements:
            toks = st.tokens
            if st.labels and toks and toks[0].kind == "dir" \
                    and toks[0].text.lower() in DATA_DIRECTIVES:
                for lbl in st.labels:
                    self.data_labels[lbl.lstrip("@")] = st.line
            if not toks or toks[0].kind != "dir":
                continue
            d = toks[0].text.lower()

            if d in ("macro", "function") and len(toks) > 1 and toks[1].kind == "id":
                name = toks[1].text
                params = self._count_params(toks, 2)
                target = self.macros if d == "macro" else self.functions
                if d == "function":
                    key = "%s/%d" % (name, params)
                    if key in self.functions and not self.has_pp_branches:
                        self._error(toks[0].line,
                                    "Functie '%s' met %d argument(en) is al "
                                    "gedefinieerd" % (name, params))
                    self.functions[key] = params
                else:
                    if (name in self.macros and name not in BUILTIN_MACROS
                            and not self.has_pp_branches):
                        self._warn(toks[0].line,
                                   "Macro '%s' is al eerder gedefinieerd" % name)
                    self.macros[name] = params

            elif d == "pseudocommand" and len(toks) > 1 and toks[1].kind == "id":
                name = toks[1].text
                args = 0
                for t in toks[2:]:
                    if t.kind == "id":
                        args += 1
                self.pseudocommands[name] = args

            elif d in ("var", "const") and len(toks) > 1 and toks[1].kind == "id":
                (self.declared_vars if d == "var"
                 else self.declared_consts).add(toks[1].text)

            elif d in ("for", "while", "define", "enum", "struct", "label"):
                for j, t in enumerate(toks):
                    if t.kind == "id" and t.text == "var" and j + 1 < len(toks) \
                            and toks[j + 1].kind == "id":
                        self.declared_vars.add(toks[j + 1].text)
                if d in ("label", "struct", "enum"):
                    for t in toks[1:]:
                        if t.kind == "id":
                            self.declared_consts.add(t.text)
                            break

            elif d == "import" and len(toks) > 1:
                self.has_imports = True
            elif d in ("segment", "segmentdef"):
                self.has_segment = True
            elif d == "pc":
                self.has_start_address = True

        for i, t in enumerate(self.tokens):
            if t.kind == "pp" and t.text in ("import", "importif"):
                self.has_imports = True
                # de bestandsnaam is de laatste string voor het regeleinde
                for nxt in self.tokens[i + 1:]:
                    if nxt.kind == "nl":
                        break
                    if nxt.kind == "str":
                        self._check_file_exists(nxt.line, nxt.text)
            elif t.kind == "pp" and t.text == "importonce":
                self.is_include = True
            elif t.kind == "dir" and t.text.lower() == "importonce":
                self.is_include = True
            elif t.kind == "dir" and t.text.lower() == "filenamespace":
                self.is_include = True
            elif t.kind == "dir" and t.text.lower() in ("file", "disk"):
                self.looks_like_main = True
            elif t.kind == "id" and t.text in BUILTIN_MACROS:
                self.looks_like_main = True
                # BasicUpstart2 zet zelf het geheugenblok op; BasicUpstart (v1)
                # verwacht dat je er zelf een '*=$0801' omheen zet.
                if t.text == "BasicUpstart2":
                    self.has_start_address = True

    @staticmethod
    def _count_params(toks: List[Token], start: int) -> int:
        """Telt de parameters tussen de haakjes van een definitie."""
        if start >= len(toks) or toks[start].text != "(":
            return 0
        depth = 0
        count = 0
        seen_any = False
        for t in toks[start:]:
            if t.kind == "op" and t.text in "([":
                depth += 1
                continue
            if t.kind == "op" and t.text in ")]":
                depth -= 1
                if depth == 0:
                    break
                continue
            if depth == 1 and t.kind == "op" and t.text == ",":
                count += 1
            elif depth >= 1 and t.kind != "op":
                seen_any = True
        return count + 1 if seen_any else 0

    # ---- per statement ----
    def _check_statements(self):
        for st in self.statements:
            toks = st.tokens
            if not toks:
                continue
            first = toks[0]

            if first.kind == "dir":
                self._check_directive(st)
            elif first.kind == "op" and first.text in ("*", "*="):
                self.has_start_address = True
            elif first.kind == "id":
                if st.is_data or first.text.lower() in SCRIPT_KEYWORDS:
                    continue
                self._check_identifier_statement(st)

    # ---- directives ----
    def _check_directive(self, st: Statement):
        toks = st.tokens
        name = toks[0].text
        low = name.lower()
        line = toks[0].line

        if low not in DIRECTIVES:
            hint = self._closest(low, DIRECTIVES)
            extra = " - bedoelde je '.%s'?" % hint if hint else ""
            self._error(line, "Onbekende directive '.%s'%s" % (name, extra))
            return

        if low == "cpu":
            if len(toks) > 1:
                cpu = toks[1].text.lower()
                if cpu not in CPU_NAMES:
                    self._error(line, "Onbekende cpu '%s' - geldig zijn: %s"
                                % (toks[1].text, ", ".join(sorted(CPU_NAMES))))
                else:
                    self.cpu = cpu
            else:
                self._error(line, ".cpu zonder cpu-naam")

        elif low == "encoding":
            if len(toks) > 1 and toks[1].kind == "str":
                if toks[1].text.lower() not in ENCODINGS:
                    self._error(line,
                                "Onbekende encoding '%s' - geldig zijn: %s"
                                % (toks[1].text, ", ".join(sorted(ENCODINGS))))
            else:
                self._error(line, ".encoding verwacht een string")

        elif low == "for":
            self._check_for_header(st)

        elif low in ("byte", "by"):
            self._check_data_range(st, 0, 255, "byte")
        elif low in ("word", "wo"):
            self._check_data_range(st, 0, 65535, "word")

        elif low == "eval":
            self._check_eval(st)

        elif low == "import":
            self._check_import(st)

        elif low in ("segment", "segmentdef"):
            self._check_param_block(st, SEGMENT_PARAMS, "segment")
            self._check_segment_definition(st)
        elif low == "file":
            self._check_param_block(st, FILE_PARAMS, "file")
            if not any(t.kind == "id" and t.text.lower() == "name" for t in toks):
                self._error(line, ".file zonder verplichte parameter 'name'")
        elif low == "disk":
            self._check_param_block(st, DISK_PARAMS, "disk")
        elif low == "segmentout":
            self._check_param_block(st, SEGMENT_PARAMS, "segmentout")

        elif low == "function":
            pass  # .return-controle gebeurt in _check_global

        elif low == "fill":
            if len([t for t in toks if t.kind == "op" and t.text == ","]) < 1:
                self._error(line, ".fill verwacht twee argumenten: aantal, expressie")

    def _check_segment_definition(self, st: Statement):
        """Een segment mag maar één keer worden gedefinieerd. Er later opnieuw
        naartoe schakelen ('.segment CODE') mag wel en is juist de bedoeling."""
        toks = st.tokens
        if len(toks) < 2 or toks[1].kind != "id":
            return
        name = toks[1].text
        has_params = any(t.kind == "op" and t.text == "[" for t in toks)
        if not has_params:
            return
        if name in self.segment_defs and not self.has_pp_branches:
            self._error(toks[0].line,
                        "Segment '%s' krijgt op regel %d al parameters. Een "
                        "segment mag maar één keer gedefinieerd worden; "
                        "gebruik '.segment %s' zonder parameters om er weer "
                        "naartoe te schakelen"
                        % (name, self.segment_defs[name], name))
        else:
            self.segment_defs[name] = toks[0].line

    def _check_for_header(self, st: Statement):
        toks = st.tokens
        depth = 0
        semis = 0
        found_paren = False
        for t in toks[1:]:
            if t.kind == "op" and t.text in "([":
                depth += 1
                found_paren = True
            elif t.kind == "op" and t.text in ")]":
                depth -= 1
                if depth == 0:
                    break
            elif depth == 1 and t.kind == "op" and t.text == ";":
                semis += 1
        if not found_paren:
            self._error(toks[0].line, ".for zonder haakjes rond de lus-header")
        elif semis != 2:
            self._error(toks[0].line,
                        ".for-header heeft %d puntkomma('s), verwacht 2: "
                        ".for (init; conditie; iteratie)" % semis)

    def _check_data_range(self, st: Statement, lo: int, hi: int, what: str):
        toks = st.tokens
        for j, t in enumerate(toks[1:], 1):
            if t.kind == "op" and t.text == "#":
                self._warn(t.line,
                           "'#' hoort bij een mnemonic-argument, niet bij .%s"
                           % what)
            if t.kind != "num" or t.value is None:
                continue
            prev = toks[j - 1]
            nxt = toks[j + 1] if j + 1 < len(toks) else None
            # alleen kale literals beoordelen, geen deelexpressies
            if prev.kind == "op" and prev.text not in (",",):
                continue
            if nxt is not None and nxt.kind == "op" and nxt.text not in (",",):
                continue
            if not (lo <= t.value <= hi):
                self._error(t.line,
                            "Waarde %s past niet in een %s (%d..%d)"
                            % (t.text, what, lo, hi))

    def _check_eval(self, st: Statement):
        toks = st.tokens
        if len(toks) < 2:
            self._error(toks[0].line, ".eval zonder expressie")
            return
        if toks[1].kind == "id" and toks[1].text == "var":
            if len(toks) > 2 and toks[2].kind == "id":
                self.declared_vars.add(toks[2].text)
            return
        if toks[1].kind != "id":
            return
        name = toks[1].text
        if len(toks) > 2 and toks[2].kind == "op" and toks[2].text in (
                "=", "+=", "-=", "*=", "/=", "++", "--"):
            if name in self.declared_consts:
                self._error(toks[0].line,
                            "'%s' is een .const en kan niet met .eval worden "
                            "gewijzigd" % name)
            elif name not in self.declared_vars:
                self._warn(toks[0].line,
                           "'%s' wordt met .eval gewijzigd maar nergens met "
                           ".var gedeclareerd" % name)

    def _check_import(self, st: Statement):
        toks = st.tokens
        line = toks[0].line
        if len(toks) < 2:
            self._error(line, ".import zonder soort (binary, c64, text of source)")
            return
        if toks[1].kind == "id" and toks[1].text.lower() == "once":
            return
        kind = toks[1].text.lower() if toks[1].kind == "id" else None
        if kind not in IMPORT_KINDS:
            self._error(line,
                        ".import verwacht binary, c64, text of source, niet '%s'"
                        % toks[1].text)
            return
        if kind == "source" and not self._warned_import_source:
            self._warned_import_source = True
            self._warn(line,
                       ".import source is verouderd - gebruik #import zodat de "
                       "preprocessor het bestand meteen invoegt (deze melding "
                       "verschijnt eenmalig)")
        if len(toks) > 2 and toks[2].kind == "str":
            self._check_file_exists(line, toks[2].text)
        else:
            self._error(line,
                        ".import %s verwacht een bestandsnaam tussen quotes"
                        % kind)

    def _check_file_exists(self, line: int, filename: str):
        if not self.check_imports or not filename:
            return
        if "%" in filename:
            return
        path = os.path.join(self.base_dir, filename)
        if not os.path.isfile(path):
            self._warn(line, "Bestand '%s' niet gevonden vanaf de bronmap "
                             "(kan in een -libdir staan)" % filename)

    def _check_param_block(self, st: Statement, allowed: Set[str], what: str):
        toks = st.tokens
        depth = 0
        expect_name = True
        for j, t in enumerate(toks):
            if t.kind == "op" and t.text == "[":
                depth += 1
                expect_name = True
                continue
            if t.kind == "op" and t.text == "]":
                depth -= 1
                continue
            if depth != 1:
                continue
            if t.kind == "op" and t.text == ",":
                expect_name = True
                continue
            if expect_name:
                expect_name = False
                if t.kind != "id":
                    continue
                if t.text.startswith("_"):
                    continue    # modifier-parameter, naam is vrij te kiezen
                if t.text.lower() not in allowed:
                    hint = self._closest(t.text.lower(), allowed)
                    extra = " - bedoelde je '%s'?" % hint if hint else ""
                    self._error(t.line,
                                "Onbekende %s-parameter '%s'%s"
                                % (what, t.text, extra))

    # ---- mnemonics en macro-aanroepen ----
    def _check_identifier_statement(self, st: Statement):
        toks = st.tokens
        first = toks[0]
        name = first.text
        low = name.lower()
        line = first.line
        table = self._cpu_table()

        # geforceerde modus: lda.abs / stx.zp / jmp.z
        forced = None
        rest_start = 1
        if len(toks) > 1 and toks[1].kind == "dir":
            suffix = toks[1].text.lower()
            if low in ALL_MNEMONICS:
                if suffix not in FORCED_SUFFIX:
                    self._error(toks[1].line,
                                "Onbekend modus-achtervoegsel '.%s' achter '%s'"
                                % (toks[1].text, name))
                    return
                forced = FORCED_SUFFIX[suffix]
                if suffix in DEPRECATED_SUFFIX:
                    self._warn(toks[1].line,
                               "Achtervoegsel '.%s' is verouderd - gebruik .a/.abs "
                               "of .z/.zp, of laat het weg" % toks[1].text)
                rest_start = 2

        if low in table:
            self.mnemonic_count += 1
            self._check_mnemonic(st, low, toks[rest_start:], forced)
            return

        if low in ALL_MNEMONICS:
            owners = [c for c, t in CPU_TABLES.items() if low in t]
            self._error(line,
                        "'%s' bestaat niet in cpu '%s' - wel in: %s. Zet "
                        "'.cpu %s' bovenin of kies een ander mnemonic"
                        % (name, self.cpu, ", ".join(sorted(owners)), owners[0]))
            return

        # macro of pseudocommand?
        if name in self.macros:
            expected = self.macros[name]
            got = self._count_params(toks, 1)
            if got != expected:
                self._error(line,
                            "Macro '%s' verwacht %d argument(en), er zijn er %d "
                            "meegegeven" % (name, expected, got))
            return
        if name in self.pseudocommands:
            return
        if any(k.split("/")[0] == name for k in self.functions):
            return

        # Onbekend. Zijn er imports, dan kan het een macro of pseudocommand uit
        # een bibliotheek zijn (mov, add16, irqStart, ...) en zwijgen we.
        if self.has_imports:
            return
        if line in self._prose_lines:
            return       # al gemeld als ';'-commentaar
        if len(low) == 3 and low.isalpha() and name.islower():
            hint = (self._closest(low, set(_STANDARD))
                    or self._closest(low, ALL_MNEMONICS))
            extra = " - bedoelde je '%s'?" % hint if hint else ""
            self._error(line, "Onbekend mnemonic '%s'%s" % (name, extra))
        else:
            self._warn(line,
                       "'%s' is geen mnemonic, macro of pseudocommand dat in dit "
                       "bestand is gedefinieerd" % name)

    def _check_mnemonic(self, st: Statement, mnem: str,
                        operand: List[Token], forced: Optional[str]):
        line = st.line
        table = self._cpu_table()
        allowed_hw = table[mnem]
        allowed_syn = {MODE_TO_SYNTAX[m] for m in allowed_hw}

        syn, problem = self._operand_syntax(operand, mnem)
        if problem:
            self._error(line, "%s: %s" % (mnem, problem))
            return
        if syn is None:
            return  # te complex om te beoordelen (bv. ternary in het argument)

        if syn not in allowed_syn:
            self._error(line,
                        "'%s' kent de adresseringsmodus '%s' niet. Toegestaan: %s"
                        % (mnem, SYNTAX_EXAMPLE[syn],
                           ", ".join(sorted(SYNTAX_EXAMPLE[s] for s in allowed_syn))))
            return

        if forced is not None and forced not in allowed_syn:
            self._error(line,
                        "Geforceerde modus past niet bij '%s'. Toegestaan: %s"
                        % (mnem, ", ".join(sorted(
                            SYNTAX_EXAMPLE[s] for s in allowed_syn))))

        if syn == "IMM":
            self._check_immediate_range(line, mnem, operand)

        if mnem in ("jmp", "jsr") and syn == "DIRECT":
            body = [t for t in operand if t.kind != "nl"]
            if len(body) == 1 and body[0].kind == "id":
                target = body[0].text.lstrip("@")
                if target in self.data_labels:
                    self._warn(line,
                               "'%s %s' springt naar data (gedefinieerd op regel "
                               "%d), niet naar code. Bedoelde je een indirecte "
                               "sprong '%s (%s)'?"
                               % (mnem, body[0].text,
                                  self.data_labels[target], mnem, body[0].text))

    def _check_immediate_range(self, line: int, mnem: str, operand: List[Token]):
        body = operand[1:]
        if len(body) != 1 or body[0].kind != "num" or body[0].value is None:
            return
        if body[0].value > 255:
            self._error(line,
                        "%s #%s: een immediate waarde moet in een byte passen "
                        "(0..255). Gebruik #<%s of #>%s"
                        % (mnem, body[0].text, body[0].text, body[0].text))

    def _operand_syntax(self, operand: List[Token], mnem: str):
        """Bepaalt de syntactische adresseringsmodus. Geeft (modus, foutmelding)."""
        toks = [t for t in operand if t.kind != "nl"]
        if not toks:
            return "NONE", None

        # 'asl a' / 'lsr a' -> accumulator
        if len(toks) == 1 and toks[0].kind == "id" and toks[0].text.lower() == "a":
            return "NONE", None

        if toks[0].kind == "op" and toks[0].text == "#":
            return "IMM", None

        # ternary of andere constructies met ':' laten we met rust
        if any(t.kind == "op" and t.text == "?" for t in toks):
            return None, None

        if toks[0].kind == "op" and toks[0].text == "(":
            close = self._match_paren(toks, 0)
            if close is None:
                return None, "haakje '(' wordt niet gesloten"
            inner = toks[1:close]
            after = toks[close + 1:]

            inner_x = (len(inner) >= 2 and inner[-2].text == ","
                       and inner[-1].kind == "id"
                       and inner[-1].text.lower() == "x")
            if after:
                if (len(after) == 2 and after[0].text == ","
                        and after[1].kind == "id"):
                    reg = after[1].text.lower()
                    if reg == "y":
                        if inner_x:
                            return None, ("(...,x),y bestaat niet - kies "
                                          "(adres,x) of (adres),y")
                        return "IND_Y", None
                    if reg == "x":
                        return None, ("(adres),x bestaat niet - bedoelde je "
                                      "(adres,x) of (adres),y?")
                    return None, "onbekend indexregister '%s'" % after[1].text
                # de haakjes waren groepering, geen indirecte adressering
                return None, ("de haakjes aan het begin worden als indirecte "
                              "adressering gelezen - gebruik [] om te groeperen")
            if inner_x:
                return "IND_X", None
            return "IND", None

        # top-niveau komma zoeken
        depth = 0
        comma = -1
        for j, t in enumerate(toks):
            if t.kind == "op" and t.text in "([":
                depth += 1
            elif t.kind == "op" and t.text in ")]":
                depth -= 1
            elif depth == 0 and t.kind == "op" and t.text == ",":
                comma = j
                break
        if comma < 0:
            return "DIRECT", None

        tail = toks[comma + 1:]
        if len(tail) == 1 and tail[0].kind == "id":
            reg = tail[0].text.lower()
            if reg == "x":
                return "DIRECT_X", None
            if reg == "y":
                return "DIRECT_Y", None
        if mnem.startswith(("bbr", "bbs")):
            return "DIRECT_LABEL", None
        return None, ("na de komma wordt 'x' of 'y' verwacht")

    @staticmethod
    def _match_paren(toks: List[Token], start: int) -> Optional[int]:
        depth = 0
        for j in range(start, len(toks)):
            t = toks[j]
            if t.kind == "op" and t.text in "([":
                depth += 1
            elif t.kind == "op" and t.text in ")]":
                depth -= 1
                if depth == 0:
                    return j
        return None

    # ---- overall ----
    def _check_global(self):
        # Een include-bestand hoeft geen laadadres te hebben; alleen een
        # hoofdbestand. We herkennen een hoofdbestand aan een BasicUpstart-
        # aanroep of aan een .file/.disk-directive.
        if self.looks_like_main and not self.has_start_address \
                and not self.has_segment:
            self._warn(None,
                       "Geen laadadres gevonden: begin met '*=$0801' of definieer "
                       "een segment. Is dit een include-bestand, zet dan "
                       "'#importonce' bovenaan")
        self._check_functions_return()
        self._check_irq_patterns()
        self._check_encoding_scope()
        self._check_branch_range()
        self._check_vic_bank()
        self._check_line_continuation()
        self._check_errorif()
        self._check_undefined_calls()
        self._check_register_across_calls()
        self._check_mainloop_reads()
        self._check_indirect_zeropage()
        self._check_uninitialised_virtual()

    def _check_encoding_scope(self):
        """`.encoding` is een globale schakelaar, geen scope-eigenschap. Staat
        hij binnen een blok en volgt er daarna nog tekstdata, dan krijgt die
        ongemerkt de verkeerde tekenset."""
        depth = 0
        pending: List[Tuple[int, int]] = []   # (regel, diepte van de .encoding)
        closed: List[int] = []                # regels van .encoding's die dicht zijn
        for t in self.tokens:
            if t.kind == "op" and t.text == "{":
                depth += 1
            elif t.kind == "op" and t.text == "}":
                depth = max(0, depth - 1)
                while pending and pending[-1][1] > depth:
                    closed.append(pending.pop()[0])
            elif t.kind == "dir":
                low = t.text.lower()
                if low == "encoding" and depth > 0:
                    pending.append((t.line, depth))
                elif low in ("text", "te") and closed:
                    self._warn(closed[-1],
                               ".encoding staat binnen een blok maar geldt "
                               "globaal - de tekstdata op regel %d erft deze "
                               "tekenset. Zet .encoding op bestandsniveau of "
                               "herstel hem na het blok" % t.line)
                    closed = []

    def _check_irq_patterns(self):
        """Twee klassieke IRQ-fouten die de machine laten vastlopen."""
        wrote_d01a = wrote_d019 = False
        wrote_hw_vector = False
        kernal_exit_line = None
        has_pp_if = any(t.kind == "pp" and t.text in ("if", "elif", "else")
                        for t in self.tokens)

        for st in self.statements:
            toks = st.tokens
            if not toks or toks[0].kind != "id":
                continue
            mnem = toks[0].text.lower()
            if mnem not in ("sta", "stx", "sty", "asl", "lsr", "inc", "dec",
                            "jmp"):
                continue
            nums = [t.value for t in toks[1:] if t.kind == "num"
                    and t.value is not None]
            if mnem == "jmp":
                if 0xea31 in nums or 0xea81 in nums:
                    kernal_exit_line = kernal_exit_line or st.line
                continue
            if 0xd01a in nums:
                wrote_d01a = True
            if 0xd019 in nums:
                wrote_d019 = True
            if 0xfffe in nums or 0xffff in nums:
                wrote_hw_vector = True

        if wrote_d01a and not wrote_d019:
            self._warn(None,
                       "Raster-interrupt wordt aangezet ($d01a) maar nergens "
                       "bevestigd ($d019). Zonder 'asl $d019' of "
                       "'lda #$ff / sta $d019' blijft de interrupt vuren en "
                       "loopt de machine vast")

        if wrote_hw_vector and kernal_exit_line and not has_pp_if:
            self._warn(kernal_exit_line,
                       "De hardware-vector $fffe wordt gebruikt, maar de "
                       "routine eindigt via de kernal ($ea31/$ea81). Met de "
                       "kernal uitgeschakeld moet je zelf de registers "
                       "herstellen en met 'rti' afsluiten")


    # -- constantwaarden ---------------------------------------------------
    _CONST_RE = re.compile(
        r"^[ \t]*\.(?:const|label)[ \t]+([A-Za-z_]\w*)[ \t]*=[ \t]*(.+?)[ \t]*$",
        re.M)
    _SAFE_EXPR = re.compile(r"^[0-9A-Za-z_+\-*/()<>&|^ ]+$")

    def _collect_const_values(self, text: str) -> Dict[str, int]:
        """Zoekt de getalswaarde achter elke .const. Constanten die naar
        elkaar verwijzen worden in een paar rondes opgelost."""
        vals: Dict[str, int] = {}
        for _ in range(4):
            progress = False
            for m in self._CONST_RE.finditer(text):
                name, expr = m.group(1), m.group(2)
                if name in vals:
                    continue
                e = expr.split("//")[0].strip().rstrip(";")
                e = re.sub(r"\$([0-9a-fA-F]+)",
                           lambda g: str(int(g.group(1), 16)), e)
                e = re.sub(r"%([01]+)",
                           lambda g: str(int(g.group(1), 2)), e)
                e = e.replace("[", "(").replace("]", ")")
                if not self._SAFE_EXPR.match(e):
                    continue
                try:
                    v = eval(e, {"__builtins__": {}}, dict(vals))
                except Exception:
                    continue
                if isinstance(v, int):
                    vals[name] = v
                    progress = True
            if not progress:
                break
        return vals

    def _operand_addresses(self, st: Statement) -> Set[int]:
        """Alle adressen die dit statement noemt, met .const-namen opgelost."""
        out: Set[int] = set()
        for t in st.tokens[1:]:
            if t.kind == "num" and t.value is not None:
                out.add(t.value)
            elif t.kind == "id":
                v = self.const_values.get(t.text)
                if v is not None:
                    out.add(v)
        return out

    # -- branch-bereik -----------------------------------------------------
    _BRANCHES = {"bcc", "bcs", "beq", "bmi", "bne", "bpl", "bvc", "bvs"}

    def _stmt_size(self, st: Statement) -> Optional[Tuple[int, int]]:
        """(minimum, maximum) aantal bytes dat dit statement oplevert.
        None betekent: niet te bepalen, en dan slaan we het gebied over."""
        toks = [t for t in st.tokens if t.kind != "nl"]
        if not toks:
            return (0, 0)

        if toks[0].kind == "dir":
            d = toks[0].text.lower()
            rest = toks[1:]
            if d in ("byte", "by"):
                return (self._count_items(rest), self._count_items(rest))
            if d in ("word", "wo"):
                n = self._count_items(rest) * 2
                return (n, n)
            if d == "dword":
                n = self._count_items(rest) * 4
                return (n, n)
            if d == "text":
                total = sum(len(t.text) for t in rest if t.kind == "str")
                return (total, total) if total else None
            if d == "fill":
                if rest and rest[0].kind == "num" and rest[0].value is not None:
                    return (rest[0].value, rest[0].value)
                return None
            if d in ("align", "pseudopc", "modify", "fillword", "lohifill"):
                return None
            return (0, 0)          # .const, .label, .var: geen bytes

        if toks[0].kind == "id":
            mnem = toks[0].text.lower().split(".")[0]
            if mnem in self._cpu_table():
                return self._insn_size(mnem, toks[1:])
            return None            # macro-aanroep of onbekend: grootte onbekend
        return (0, 0)

    @staticmethod
    def _count_items(toks: List[Token]) -> int:
        if not toks:
            return 0
        n = 1
        depth = 0
        for t in toks:
            if t.kind == "op":
                if t.text in "([":
                    depth += 1
                elif t.text in ")]":
                    depth -= 1
                elif t.text == "," and depth == 0:
                    n += 1
        return n

    def _insn_size(self, mnem: str, body: List[Token]) -> Tuple[int, int]:
        if not body:
            return (1, 1)
        if body[0].kind == "op" and body[0].text == "#":
            return (2, 2)
        if len(body) == 1 and body[0].kind == "id" and body[0].text.lower() == "a":
            return (1, 1)
        if mnem in self._BRANCHES:
            return (2, 2)
        if mnem in ("jmp", "jsr"):
            return (3, 3)
        if body[0].kind == "op" and body[0].text == "(":
            return (3, 3) if mnem == "jmp" else (2, 2)
        # absoluut of zeropage: alleen bij een letterlijk getal zeker
        addrs = [t.value for t in body if t.kind == "num" and t.value is not None]
        names = [t.text for t in body if t.kind == "id"]
        if len(body) == 1 and addrs:
            return (2, 2) if addrs[0] <= 0xff else (3, 3)
        if names and names[0] in self.const_values:
            return (2, 2) if self.const_values[names[0]] <= 0xff else (3, 3)
        # Alles wat hier overblijft is een label of een naam uit een ander
        # bestand. Zeropage bereik je in Kick Assembler vrijwel altijd via
        # een .const of .label met een kleine waarde, en die zijn hierboven
        # al afgevangen. Dus: absoluut.
        return (3, 3)

    def _check_branch_range(self):
        """Een relatieve sprong reikt maar -128..+127 bytes. Kick Assembler
        meldt dit pas bij het assembleren, en dan met een regelnummer dat
        vaak naast de oorzaak ligt.

        Omdat de checker niet altijd weet of een operand zeropage of
        absoluut is, wordt zowel de kleinst als de grootst mogelijke afstand
        berekend. Alleen als beide buiten bereik vallen is het zeker fout.
        """
        self._label_names = {lab.lstrip("!@") for st in self.statements
                             for lab in st.labels}
        pc_min = pc_max = 0
        region = 0
        labels: Dict[str, List[Tuple[int, int, int]]] = {}
        branches: List[Tuple[int, str, int, int, int]] = []

        for st in self.statements:
            for lab in st.labels:
                labels.setdefault(lab.lstrip("!@"), []).append(
                    (pc_min, pc_max, region))

            toks = [t for t in st.tokens if t.kind != "nl"]
            if not toks:
                continue

            # '*=' zet de programmateller opnieuw; een sprong hoort daar
            # nooit overheen te gaan, dus dat is meteen een nieuw gebied.
            if toks[0].kind == "op" and toks[0].text in ("*", "*="):
                region += 1
                pc_min = pc_max = 0
                continue

            if toks[0].kind == "id":
                mnem = toks[0].text.lower().split(".")[0]
                if mnem in self._BRANCHES:
                    body = [t for t in toks[1:] if t.kind == "id"]
                    if body:
                        branches.append((st.line, body[0].text.lstrip("!@"),
                                         pc_min + 2, pc_max + 2, region))

            size = self._stmt_size(st)
            if size is None:
                region += 1        # onbekende grootte: gebied afsluiten
                continue
            pc_min += size[0]
            pc_max += size[1]

        for line, name, after_min, after_max, reg in branches:
            cands = [(lo, hi) for (lo, hi, r) in labels.get(name, []) if r == reg]
            if not cands:
                continue
            # Bij gelijknamige labels in verschillende scopes wint de
            # dichtstbijzijnde; dat is ook wat Kick Assembler doet.
            lo, hi = min(cands, key=lambda p: abs(p[0] - after_min))
            off_lo = lo - after_min
            off_hi = hi - after_max
            bad_lo = not (-128 <= off_lo <= 127)
            bad_hi = not (-128 <= off_hi <= 127)
            if bad_lo and bad_hi:
                self._error(line,
                            "Sprong naar '%s' overbrugt %d bytes en dat valt "
                            "buiten het bereik -128..+127 van een relatieve "
                            "sprong. Keer de voorwaarde om en spring met 'jmp': "
                            "'b<tegengestelde> vervolg / jmp %s / vervolg:'. "
                            "Of zet het doellabel dichterbij"
                            % (name, off_lo, name))
            elif bad_hi:
                self._warn(line,
                           "Sprong naar '%s' overbrugt %d tot %d bytes en zit "
                           "daarmee tegen de grens van -128..+127 aan"
                           % (name, off_lo, off_hi))

    # -- hardware-valkuilen ------------------------------------------------
    def _check_vic_bank(self):
        """Twee dingen die bij het omschakelen van VIC-bank vaak misgaan."""
        dd00_line = None
        wrote_dd02 = False
        d018_line = None
        for st in self.statements:
            toks = [t for t in st.tokens if t.kind != "nl"]
            if not toks or toks[0].kind != "id":
                continue
            if toks[0].text.lower() not in ("sta", "stx", "sty", "inc", "dec",
                                            "asl", "lsr", "rol", "ror", "ora",
                                            "and"):
                continue
            addrs = self._operand_addresses(st)
            if 0xdd00 in addrs and dd00_line is None:
                dd00_line = st.line
            if 0xdd02 in addrs:
                wrote_dd02 = True
            if 0xd018 in addrs and d018_line is None:
                d018_line = st.line

        if dd00_line and not wrote_dd02:
            self._warn(dd00_line,
                       "De VIC-bank wordt via $dd00 gekozen, maar $dd02 wordt "
                       "nergens gezet. Bits 0-1 van $dd00 zijn CIA-poortlijnen "
                       "en moeten eerst als uitgang worden ingesteld: "
                       "'lda $dd02 / ora #%00000011 / sta $dd02'")

        # Charset of sprites in het schaduwgebied van het karakter-ROM
        if d018_line:
            for st in self.statements:
                toks = [t for t in st.tokens if t.kind != "nl"]
                if len(toks) < 2 or toks[0].kind != "op" \
                        or toks[0].text not in ("*", "*="):
                    continue
                for t in toks[1:]:
                    v = (t.value if t.kind == "num" else
                         self.const_values.get(t.text) if t.kind == "id" else None)
                    if v is None:
                        continue
                    if 0x1000 <= v < 0x2000 or 0x9000 <= v < 0xa000:
                        self._warn(st.line,
                                   "Op $%04x ziet de VIC in bank 0 en 2 het "
                                   "karakter-ROM in plaats van je eigen data. "
                                   "Zet grafiek buiten $1000-$1fff en "
                                   "$9000-$9fff, of gebruik bank 1 of 3" % v)
                        break

    # -- werkgeheugen ------------------------------------------------------
    _IMPORT_RE = re.compile(r'#import(?:if)?\s+(?:[^"]*\s+)?"([^"]+)"')
    _STORE_RE = re.compile(r"\b(?:sta|stx|sty|inc|dec)\s+([A-Za-z_]\w*)", re.I)
    _READ_RE = re.compile(
        r"\b(?:lda|ldx|ldy|cmp|cpx|cpy|adc|sbc|ora|and|eor|bit|asl|lsr|rol|ror)"
        r"\s+([A-Za-z_]\w*)", re.I)
    # '<naam' of '>[naam + ...]' bouwt een pointer naar een buffer. Wat
    # daarna via '(zp),y' geschreven wordt zien we niet, dus zo'n label
    # geldt als beschreven.
    _PTR_RE = re.compile(r"[<>]\s*\[?\s*([A-Za-z_]\w*)")

    def _project_texts(self) -> Optional[List[str]]:
        """Bronregels van dit bestand plus alles wat het importeert, als
        losse stukken. Los, omdat een 'virtual' blok aan het einde van een
        bestand niet mag doorlopen in het volgende."""
        if not self.base_dir:
            return None
        texts = [self.source_text]
        seen: Set[str] = set()
        todo = list(self._IMPORT_RE.findall(self.source_text))
        while todo:
            rel = todo.pop()
            path = os.path.normpath(os.path.join(self.base_dir, rel))
            if path in seen or not os.path.isfile(path):
                continue
            seen.add(path)
            try:
                with open(path, "r", encoding="utf-8", errors="replace") as fh:
                    body = fh.read()
            except OSError:
                continue
            texts.append(body)
            todo.extend(self._IMPORT_RE.findall(body))
        if not seen:
            return None
        return texts

    _CALL_RE = re.compile(r"\b(?:jsr|jmp)\s+([A-Za-z_][\w.]*)", re.I)
    _LABEL_RE = re.compile(r"^[ \t]*([A-Za-z_]\w*):", re.M)
    _DEF_RE = re.compile(r"\.(?:const|label|var|macro|function|pseudocommand)"
                         r"\s+([A-Za-z_]\w*)")

    # Bewust zonder re.S: Kick Assembler leest een directive per regel,
    # dus een .errorif waarvan de tekst op de volgende regel staat is
    # geen geldige .errorif maar een syntaxfout.
    _ERRORIF_RE = re.compile(r"\.errorif\s+([^\n]+?),\s*\"([^\"\n]*)\"")

    _DIR_LINE_RE = re.compile(r"^[ \t]*\.(\w+)\b")
    _DATA_DIRS = {"byte", "by", "word", "wo", "dword", "text", "fill"}

    def _check_line_continuation(self):
        """Kick Assembler leest een statement per regel. Een lijst met
        argumenten die op een komma eindigt en op de volgende regel
        doorloopt is een syntaxfout, hoe netjes het er ook uitziet."""
        for lineno, raw in enumerate(self.source_text.splitlines(), 1):
            line = raw.split("//")[0].rstrip()
            if not line.endswith(","):
                continue
            m = self._DIR_LINE_RE.match(line)
            if not m:
                continue
            name = m.group(1).lower()
            msg = ("De regel eindigt op een komma, maar Kick Assembler leest "
                   "een '.%s' per regel. Zet het hele statement op een regel"
                   % name)
            if name in self._DATA_DIRS:
                self._warn(lineno, msg)
            else:
                self._error(lineno, msg)

    def _check_errorif(self):
        """Rekent .errorif-voorwaarden alvast uit. Kick Assembler doet dat
        ook, maar pas bij het assembleren; zo zie je het al bij de
        syntaxcheck. Voorwaarden die niet te evalueren zijn worden
        overgeslagen."""
        parts = self._project_texts() or [self.source_text]
        text = re.sub(r"//[^\n]*", "", "\n".join(parts))
        for m in self._ERRORIF_RE.finditer(text):
            expr, msg = m.group(1), m.group(2)
            e = expr.strip().replace("[", "(").replace("]", ")")
            e = re.sub(r"\$([0-9a-fA-F]+)",
                       lambda g: str(int(g.group(1), 16)), e)
            e = re.sub(r"%([01]+)", lambda g: str(int(g.group(1), 2)), e)
            e = e.replace("!=", "\x00").replace("&&", " and ")
            e = e.replace("||", " or ").replace("!", " not ").replace("\x00", "!=")
            if not re.match(r"^[0-9A-Za-z_+\-*/()<>=!&|. ]+$", e):
                continue
            try:
                hit = eval(e, {"__builtins__": {}}, dict(self.const_values))
            except Exception:
                continue
            if hit:
                self._error(None, "Een .errorif gaat af: %s" % msg)

    def _check_undefined_calls(self):
        """Een 'jsr' naar een routine die nergens bestaat. De assembler
        vindt dit ook, maar pas na de syntaxcheck en zonder te vertellen
        in welk bestand het label had moeten staan.

        Alleen voor het hoofdbestand: daar is via de imports het hele
        programma bereikbaar. Bij een los include-bestand zou een
        verwijzing naar een ander bestand vals alarm geven."""
        if not self.looks_like_main:
            return
        texts = self._project_texts()
        if texts is None:
            return
        clean = "\n".join(re.sub(r"//[^\n]*", "", t) for t in texts)
        clean = re.sub(r"/\*.*?\*/", "", clean, flags=re.S)

        known = set(self._LABEL_RE.findall(clean))
        known |= set(self._DEF_RE.findall(clean))
        known |= set(self.const_values)

        seen: Set[str] = set()
        for m in self._CALL_RE.finditer(clean):
            target = m.group(1)
            if target in seen:
                continue
            head = target.split(".")[0]
            if target in known or head in known:
                continue
            seen.add(target)
            self._error(None,
                        "'jsr' of 'jmp' naar '%s', maar dat label staat "
                        "nergens in dit bestand of in de imports" % target)

    _ROUTINE_RE = re.compile(r"^([A-Za-z_]\w*):[ \t]*\{", re.M)
    _CLOB_X = re.compile(r"\b(?:ldx|inx|dex|tax|tsx)\b", re.I)
    _CLOB_Y = re.compile(r"\b(?:ldy|iny|dey|tay)\b", re.I)
    _USE_X = re.compile(r",[ \t]*x\b|\b(?:inx|dex|cpx|stx|txa)\b", re.I)
    _USE_Y = re.compile(r",[ \t]*y\b|\b(?:iny|dey|cpy|sty|tya)\b", re.I)
    _SET_X = re.compile(r"\b(?:ldx|tax|tsx)\b", re.I)
    _SET_Y = re.compile(r"\b(?:ldy|tay)\b", re.I)
    _JSR_RE = re.compile(r"\bjsr[ \t]+([A-Za-z_]\w*)", re.I)

    def _check_register_across_calls(self):
        """Een routine die X of Y overschrijft, aangeroepen terwijl de
        aanroeper dat register nog nodig heeft. Klassiek gevolg: een
        indexlus die zichzelf terugzet en dus nooit eindigt.

        Alleen voor het hoofdbestand, zodat de aangeroepen routines via
        de imports gevonden kunnen worden."""
        if not self.looks_like_main:
            return
        texts = self._project_texts()
        if texts is None:
            return

        routines: Dict[str, List[str]] = {}
        for body in texts:
            clean = re.sub(r"//[^\n]*", "", body)
            cur: Optional[str] = None
            lines: List[str] = []
            for line in clean.splitlines():
                m = self._ROUTINE_RE.match(line)
                if m:
                    if cur:
                        routines[cur] = lines
                    cur, lines = m.group(1), []
                elif cur is not None:
                    lines.append(line)
            if cur:
                routines[cur] = lines
        if not routines:
            return

        clobbers = {}
        for name, lines in routines.items():
            joined = "\n".join(lines)
            clobbers[name] = (bool(self._CLOB_X.search(joined)),
                              bool(self._CLOB_Y.search(joined)))

        seen: Set[Tuple[str, str, str]] = set()
        for name, lines in routines.items():
            for i, line in enumerate(lines):
                m = self._JSR_RE.search(line)
                if not m:
                    continue
                target = m.group(1)
                if target not in clobbers or target == name:
                    continue
                live_x, live_y = clobbers[target]
                for nxt in lines[i + 1:]:
                    if re.search(r"\b(?:rts|rti|jmp)\b", nxt):
                        break
                    for live, use, setr, reg in ((live_x, self._USE_X, self._SET_X, "X"),
                                                 (live_y, self._USE_Y, self._SET_Y, "Y")):
                        if not live or not use.search(nxt) or setr.search(nxt):
                            continue
                        key = (name, target, reg)
                        if key in seen:
                            continue
                        seen.add(key)
                        self._warn(None,
                                   "'%s' roept '%s' aan en gebruikt daarna nog "
                                   "register %s, maar '%s' overschrijft dat. "
                                   "Bewaar %s eromheen of laat de routine het "
                                   "met rust" % (name, target, reg, target, reg))
                    if self._SET_X.search(nxt):
                        live_x = False
                    if self._SET_Y.search(nxt):
                        live_y = False
                    if not live_x and not live_y:
                        break

    _INDIRECT_RE = re.compile(
        r"\b(?:lda|sta|cmp|adc|sbc|ora|and|eor)\s*\(\s*([A-Za-z_]\w*)\s*[,)]",
        re.I)

    def _check_indirect_zeropage(self):
        """'lda (ptr),y' en 'lda (ptr,x)' bestaan alleen met een pointer in
        zeropage. Wijst de naam naar iets daarbuiten, dan leest de code van
        een heel andere plek -- en de assembler kapt het adres gewoon af.

        Het gevolg is lastig te herkennen: de routine draait, maar met
        gegevens die nergens op slaan."""
        texts = self._project_texts() or [self.source_text]
        clean = "\n".join(re.sub(r"//[^\n]*", "", t) for t in texts)

        # labels in een virtual blok, met het adres waar dat blok begint
        block: Dict[str, int] = {}
        for t in texts:
            base = None
            for line in re.sub(r"//[^\n]*", "", t).splitlines():
                m = re.match(r"\s*\*\s*=\s*\$?([0-9a-fA-F]+)", line)
                if m:
                    base = int(m.group(1), 16)
                    continue
                m = re.match(r"\s*([A-Za-z_]\w*):", line)
                if m and base is not None:
                    block[m.group(1)] = base

        seen: Set[str] = set()
        for m in self._INDIRECT_RE.finditer(clean):
            name = m.group(1)
            if name in seen:
                continue
            addr = self.const_values.get(name)
            if addr is None:
                addr = block.get(name)
            if addr is None or addr <= 0xff:
                continue
            seen.add(name)
            self._error(None,
                        "'%s' wordt indirect gebruikt maar staat op $%04x. "
                        "Indirect geindexeerd adresseren kan alleen met een "
                        "pointer in zeropage; zet hem daar neer" % (name, addr))

    def _check_mainloop_reads(self):
        """Een variabele uit het virtual blok die de hoofdlus leest voordat
        er ooit iets in geschreven is.

        Dit is een ander geval dan 'nergens geschreven': de variabele
        wordt wel degelijk gezet, maar pas door code die zelf nog niet is
        gedraaid. Het gevolg is dat de eerste frames op rommel draaien.
        Deze fout is in dit project twee keer gemaakt en kost telkens veel
        zoekwerk, want alles assembleert schoon.

        Alleen voor het hoofdbestand, want daar staat de hoofdlus."""
        if not self.looks_like_main:
            return
        texts = self._project_texts()
        if texts is None:
            return

        virt = self._virtual_names(texts)
        if not virt:
            return
        routines = self._routine_bodies(texts)
        writes = self._transitive_writes(routines, virt)

        body = re.sub(r"//[^\n]*", "", self.source_text).splitlines()
        try:
            start = next(i for i, l in enumerate(body)
                         if re.match(r"^start:", l))
            loop = next(i for i, l in enumerate(body)
                        if re.match(r"^mainLoop:", l))
        except StopIteration:
            return

        known: Set[str] = set()
        for line in body[start:loop]:                 # de opstartcode
            m = self._JSR_RE.search(line)
            if m:
                known |= writes.get(m.group(1), set())
            m = self._STORE_RE.search(line)
            if m:
                known.add(m.group(1))

        seen: Set[str] = set()
        for line in body[loop:]:
            if re.match(r"^\s*(?:#import|\.segment)\b", line):
                break
            m = self._JSR_RE.search(line)
            if m:
                known |= writes.get(m.group(1), set())
                continue
            m = self._STORE_RE.search(line)
            if m:
                known.add(m.group(1))
                continue
            m = self._READ_RE.search(line)
            if m and m.group(1) in virt and m.group(1) not in known:
                if m.group(1) in seen:
                    continue
                seen.add(m.group(1))
                self._error(None,
                            "De hoofdlus leest '%s' voordat er iets in "
                            "geschreven is. Die staat in een virtual blok, "
                            "dus dat is wat er toevallig in het geheugen lag. "
                            "Zet hem in de initialisatie" % m.group(1))

    @staticmethod
    def _virtual_names(texts: List[str]) -> Set[str]:
        out: Set[str] = set()
        for body in texts:
            clean = re.sub(r"//[^\n]*", "", body)
            in_virtual = False
            for line in clean.splitlines():
                if re.match(r"\s*\*\s*=", line):
                    in_virtual = "virtual" in line
                    continue
                if not in_virtual:
                    continue
                m = re.match(r"\s*([A-Za-z_]\w*):", line)
                if m:
                    out.add(m.group(1))
        return out

    def _routine_bodies(self, texts: List[str]) -> Dict[str, List[str]]:
        routines: Dict[str, List[str]] = {}
        for body in texts:
            clean = re.sub(r"//[^\n]*", "", body)
            cur: Optional[str] = None
            lines: List[str] = []
            for line in clean.splitlines():
                m = self._ROUTINE_RE.match(line)
                if m:
                    if cur:
                        routines[cur] = lines
                    cur, lines = m.group(1), []
                elif cur is not None:
                    lines.append(line)
            if cur:
                routines[cur] = lines
        return routines

    def _transitive_writes(self, routines, virt) -> Dict[str, Set[str]]:
        direct: Dict[str, Set[str]] = {}
        calls: Dict[str, Set[str]] = {}
        for name, lines in routines.items():
            w: Set[str] = set()
            c: Set[str] = set()
            for line in lines:
                m = self._STORE_RE.search(line)
                if m and m.group(1) in virt:
                    w.add(m.group(1))
                m = self._JSR_RE.search(line)
                if m:
                    c.add(m.group(1))
            direct[name], calls[name] = w, c
        for _ in range(6):                            # tot het stabiel is
            changed = False
            for name in routines:
                before = len(direct[name])
                for callee in calls[name]:
                    direct[name] |= direct.get(callee, set())
                if len(direct[name]) != before:
                    changed = True
            if not changed:
                break
        return direct

    def _check_uninitialised_virtual(self):
        """Labels in een 'virtual' blok staan niet in de .prg. Wat daar
        staat is dus wat er toevallig in het geheugen lag. Een variabele die
        wel gelezen maar nergens geschreven wordt, leest gegarandeerd
        rommel."""
        texts = self._project_texts()
        if texts is None:
            return

        def strip(t):
            t = re.sub(r"//[^\n]*", "", t)
            return re.sub(r"/\*.*?\*/", "", t, flags=re.S)

        virt: Set[str] = set()
        for body in texts:
            in_virtual = False
            for raw in strip(body).splitlines():
                if re.match(r"\s*\*\s*=", raw):
                    in_virtual = "virtual" in raw
                    continue
                if not in_virtual:
                    continue
                m = re.match(r"\s*([A-Za-z_]\w*):", raw)
                if m:
                    virt.add(m.group(1))
        if not virt:
            return

        clean = "\n".join(strip(b) for b in texts)
        written = {m.group(1) for m in self._STORE_RE.finditer(clean)}
        written |= {m.group(1) for m in self._PTR_RE.finditer(clean)}
        read = {m.group(1) for m in self._READ_RE.finditer(clean)}

        for name in sorted(virt):
            if name in read and name not in written:
                self._warn(None,
                           "'%s' staat in een virtual blok en wordt gelezen, "
                           "maar nergens geschreven. Virtual data zit niet in "
                           "de .prg, dus dit leest wat er toevallig in het "
                           "geheugen stond" % name)

    def _check_functions_return(self):
        """Waarschuwt bij een .function zonder .return in het bijbehorende blok."""
        depth = 0
        stack: List[Tuple[str, int, int, bool]] = []
        pending: Optional[Tuple[str, int]] = None
        for t in self.tokens:
            if t.kind == "dir":
                low = t.text.lower()
                if low == "function":
                    pending = ("fn", t.line)
                elif low == "return" and stack:
                    name, line, d, _ = stack[-1]
                    stack[-1] = (name, line, d, True)
            elif t.kind == "id" and pending and pending[0] == "fn":
                pending = (t.text, pending[1])
            elif t.kind == "op" and t.text == "{":
                depth += 1
                if pending and pending[0] != "fn":
                    stack.append((pending[0], pending[1], depth, False))
                pending = None
            elif t.kind == "op" and t.text == "}":
                if stack and stack[-1][2] == depth:
                    name, line, _, has_return = stack.pop()
                    if not has_return:
                        self._warn(line,
                                   "Functie '%s' bevat geen .return en levert "
                                   "daarom altijd null op" % name)
                depth = max(0, depth - 1)

    @staticmethod
    def _closest(word: str, candidates) -> Optional[str]:
        """Zoekt een kandidaat op afstand 1 (typefout)."""
        best = None
        for cand in candidates:
            if abs(len(cand) - len(word)) > 1:
                continue
            if KickAssChecker._edit_distance_le1(word, cand):
                if best is None or len(cand) < len(best):
                    best = cand
        return best

    @staticmethod
    def _edit_distance_le1(a: str, b: str) -> bool:
        if a == b:
            return False
        # omgewisselde buurletters tellen als één typefout
        if len(a) == len(b):
            diff = [k for k in range(len(a)) if a[k] != b[k]]
            if len(diff) == 2 and diff[1] == diff[0] + 1:
                k = diff[0]
                if a[k] == b[k + 1] and a[k + 1] == b[k]:
                    return True
        la, lb = len(a), len(b)
        if abs(la - lb) > 1:
            return False
        if la == lb:
            return sum(1 for x, y in zip(a, b) if x != y) == 1
        if la > lb:
            a, b, la, lb = b, a, lb, la
        i = j = 0
        skipped = False
        while i < la and j < lb:
            if a[i] != b[j]:
                if skipped:
                    return False
                skipped = True
                j += 1
                continue
            i += 1
            j += 1
        return True

    # -- rapportage --------------------------------------------------------
    def report(self, print_errors: bool = True,
               return_warnings: bool = True) -> str:
        lines: List[str] = []
        for issue in self._sorted_issues():
            if issue.severity == "WARN" and not return_warnings:
                continue
            where = "Line %d: " % issue.line if issue.line is not None else ""
            lines.append("%s: %s%s" % (issue.severity, where, issue.message))
        errors = sum(1 for i in self.issues if i.severity == "ERROR")
        warnings = sum(1 for i in self.issues if i.severity == "WARN")
        lines.append("")
        lines.append("Summary: %d error(s), %d warning(s)" % (errors, warnings))
        text = "\n".join(lines)
        if print_errors:
            print(text)
        return text

    def _sorted_issues(self) -> List[Issue]:
        return sorted(self.issues,
                      key=lambda i: (i.line if i.line is not None else 10 ** 9,
                                     0 if i.severity == "ERROR" else 1))

    def structured(self) -> Dict[str, object]:
        errors = sum(1 for i in self.issues if i.severity == "ERROR")
        warnings = sum(1 for i in self.issues if i.severity == "WARN")
        return {
            "issues": [
                {"line": i.line, "severity": i.severity, "message": i.message}
                for i in self._sorted_issues()
            ],
            "summary": {"errors": errors, "warnings": warnings, "cpu": self.cpu},
        }


# ---------------------------------------------------------------------------
# Publieke API - spiegelt c64_syntax_checker.py zodat beide door dezelfde
# tooling aangeroepen kunnen worden.
# ---------------------------------------------------------------------------

def check_source(source: str, return_structured: bool = False,
                 print_errors: bool = True, return_warnings: bool = True,
                 cpu: str = DEFAULT_CPU, base_dir: Optional[str] = None):
    """Controleer Kick Assembler broncode die als string wordt aangeleverd.

    Geeft een tekstrapport terug, of een dict wanneer return_structured=True.
    """
    if os.getenv("KA_NO_WARN") == "1":
        return_warnings = False
    checker = KickAssChecker(cpu=cpu, base_dir=base_dir)
    checker.load(source)
    checker.validate()
    if return_structured:
        return checker.structured()
    return checker.report(print_errors=print_errors,
                          return_warnings=return_warnings)


def check_file(path: str, return_structured: bool = False,
               cpu: str = DEFAULT_CPU, no_warn: bool = False):
    """Controleer een .asm-bestand. Geeft 0 of 1 terug als exit-code, of een
    dict wanneer return_structured=True."""
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    checker = KickAssChecker(cpu=cpu, base_dir=os.path.dirname(os.path.abspath(path)))
    checker.load(text)
    checker.validate()
    if return_structured:
        return checker.structured()
    checker.report(print_errors=True, return_warnings=not no_warn)
    errors = sum(1 for i in checker.issues if i.severity == "ERROR")
    return 1 if errors else 0


def main(argv: List[str]) -> int:
    if len(argv) < 2:
        print("Gebruik: python c64_ka_syntax_checker.py <bestand.asm> "
              "[--json] [--no-warn] [--cpu NAAM]")
        return 2
    path = argv[1]
    args = argv[2:]
    want_json = "--json" in args
    no_warn = "--no-warn" in args or os.getenv("KA_NO_WARN") == "1"

    cpu = DEFAULT_CPU
    if "--cpu" in args:
        idx = args.index("--cpu")
        if idx + 1 >= len(args):
            print("--cpu verwacht een naam")
            return 2
        cpu = args[idx + 1].lower()
        if cpu not in CPU_NAMES:
            print("Onbekende cpu '%s' - geldig zijn: %s"
                  % (cpu, ", ".join(sorted(CPU_NAMES))))
            return 2

    if not os.path.isfile(path):
        print("Bestand niet gevonden: %s" % path)
        return 2

    if want_json:
        data = check_file(path, return_structured=True, cpu=cpu)
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return 1 if data["summary"]["errors"] else 0
    return check_file(path, cpu=cpu, no_warn=no_warn)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
