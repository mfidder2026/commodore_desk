"""Build build/helptext.prg from gui/help.txt (the F1 help texts).

Layout (loaded to $4000 at start-up and copied to $D000, RAM under I/O):
  +0            number of contexts (N)
  +1 .. +2N     offset of each context (lo, hi), 0 = none
  text:         title, $FE, line, $FE, line, ..., $FF   (screencodes)
The PRG load address is $4000; the whole file must stay within 4 KB.
"""
import os
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = os.path.join(root, 'gui', 'help.txt')
out = os.path.join(root, 'build', 'helptext.prg')
MAX_LINES, MAX_W, LIMIT = 14, 33, 4096


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
body = bytearray()
offs = []
for i in range(count):
    if i not in ctx:
        offs.append(0)
        continue
    lines = ctx[i]
    while len(lines) > 1 and lines[-1] == '':
        lines.pop()
    if len(lines) - 1 > MAX_LINES:
        sys.exit('context %d has more than %d lines' % (i, MAX_LINES))
    offs.append(1 + 2 * count + len(body))
    for k, l in enumerate(lines):
        body += sc(l)
        body.append(0xfe if k < len(lines) - 1 else 0xff)
data = bytearray([count])
for o in offs:
    data += bytes([o & 0xff, o >> 8])
data += body
if len(data) > LIMIT:
    sys.exit('helptext is %d bytes, more than %d' % (len(data), LIMIT))
os.makedirs(os.path.dirname(out), exist_ok=True)
open(out, 'wb').write(bytes([0x00, 0x40]) + data)
print('helptext.prg: %d contexts, %d bytes' % (count, len(data)))
