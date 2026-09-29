"""Build build/helptext.prg from gui/help.txt (the F1 help texts).

Layout (loaded to $4000 at start-up and copied to $D000, RAM under I/O):
  +0            number of contexts (N)
  +1 .. +2      offset of the dictionary
  +3 .. +2N+2   offset of each context (lo, hi), 0 = none
  text:         title, $FE, line, $FE, line, ..., $FF   (screencodes)
  dictionary:   the words, the last character of each with bit 7 set
  +$0C00        the UI glyphs (build/uiglyphs.prg, gfx/uiglyphs.asm)
Bytes $40-$FD in a text are words from the dictionary (index = byte-$40),
chosen by merging the most frequent pairs (byte-pair encoding); help_Show
unpacks them. The PRG load address is $4000; the file must stay within 4 KB.
"""
import os
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(root, 'gui', 'help.txt')
out = os.path.join(root, 'build', 'helptext.prg')
MAX_LINES, MAX_W, LIMIT = 14, 33, 4096
GLYPHS_AT = 0x0c00                       # UI-glyphs op $DC00


def sc(text):
    b = bytearray()
    for ch in text:
        c = ord(ch)
        if 'A' <= ch <= 'Z':
            c -= 0x40
        elif ch == '@':
            c = 0
        elif ch == "'":
            c = 0x27
        elif not (0x20 <= c <= 0x3f):
            sys.exit('help.txt: character %r not allowed' % ch)
        b.append(c)
    return b


ctx = {}
cur = None
for n, line in enumerate(open(src, encoding='utf-8'), 1):
    line = line.rstrip('\n')
    if line.startswith('#'):
        continue
    if line.startswith('@'):
        num, _, title = line[1:].partition(' ')
        cur = int(num)
        ctx[cur] = [title.strip()]
        continue
    if cur is None:
        continue
    if len(line) > MAX_W:
        sys.exit('help.txt line %d longer than %d: %s' % (n, MAX_W, line))
    ctx[cur].append(line)

count = max(ctx) + 1
texts = {}
for i in range(count):
    if i not in ctx:
        continue
    lines = ctx[i]
    while len(lines) > 1 and lines[-1] == '':
        lines.pop()
    if len(lines) - 1 > MAX_LINES:
        sys.exit('context %d has more than %d lines' % (i, MAX_LINES))
    t = []
    for k, l in enumerate(lines):
        t += list(sc(l))
        t.append(0xfe if k < len(lines) - 1 else 0xff)
    texts[i] = t

# byte-pair encoding: the most frequent pair becomes a new word (0x40-0xFD)
words = []                               # expansion of each word (screencodes)
def expand(sym):
    return words[sym - 0x40] if 0x40 <= sym < 0xfe else [sym]
while len(words) < 0xfe - 0x40:
    freq = {}
    for t in texts.values():
        for a, b in zip(t, t[1:]):
            if a < 0xfe and b < 0xfe:
                freq[(a, b)] = freq.get((a, b), 0) + 1
    if not freq:
        break
    pair, n = max(freq.items(), key=lambda kv: kv[1])
    new = expand(pair[0]) + expand(pair[1])
    if n - len(new) <= 1:                # saves less than it costs
        break
    words.append(new)
    code = 0x3f + len(words)
    for i, t in texts.items():
        res, j = [], 0
        while j < len(t):
            if j + 1 < len(t) and (t[j], t[j + 1]) == pair:
                res.append(code)
                j += 2
            else:
                res.append(t[j])
                j += 1
        texts[i] = res

body = bytearray()
offs = []
head = 3 + 2 * count
for i in range(count):
    if i not in texts:
        offs.append(0)
        continue
    offs.append(head + len(body))
    body += bytes(texts[i])
dict_off = head + len(body)
for w in words:
    body += bytes(w[:-1]) + bytes([w[-1] | 0x80])
data = bytearray([count, dict_off & 0xff, dict_off >> 8])
for o in offs:
    data += bytes([o & 0xff, o >> 8])
data += body
if len(data) > GLYPHS_AT:
    sys.exit('helptext is %d bytes, more than %d' % (len(data), GLYPHS_AT))
# de UI-glyphs (gfx/uiglyphs.asm, segment UiGlyphs op $DC00) erachter
g = open(os.path.join(root, 'build', 'uiglyphs.prg'), 'rb').read()
assert g[0] | (g[1] << 8) == 0xd000 + GLYPHS_AT, 'uiglyphs.prg moet op $DC00 staan'
data += bytes(GLYPHS_AT - len(data)) + g[2:]
if len(data) > LIMIT:
    sys.exit('helptext + glyphs is %d bytes, more than %d' % (len(data), LIMIT))
os.makedirs(os.path.dirname(out), exist_ok=True)
open(out, 'wb').write(bytes([0x00, 0x40]) + data)
print('helptext.prg: %d contexts, %d words, %d bytes' % (count, len(words), len(data)))
