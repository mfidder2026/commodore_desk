"""data/radio_lst.txt (ASCII) -> build/radio.lst (PETSCII, written as SEQ).
Also for other text files: make_radio_seq.py <in.txt> <out> (BOOKMARKS).

The text editor's convention: lower case a-z = $41-$5A, upper case A-Z =
$C1-$DA, '_' = $A4, end of line = CR. RADIO (apps/radio/radio.asm) turns
it back into ASCII for the HTTP request (paths are case-sensitive).
"""
import os
import sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = sys.argv[1] if len(sys.argv) > 2 else os.path.join(root, 'data', 'radio_lst.txt')
dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(root, 'build', 'radio.lst')
out = bytearray()
for line in open(src, encoding='ascii'):
    for ch in line.rstrip('\r\n'):
        c = ord(ch)
        if 0x61 <= c <= 0x7a:
            c -= 0x20
        elif 0x41 <= c <= 0x5a:
            c += 0x80
        elif ch == '_':
            c = 0xa4
        out.append(c)
    out.append(0x0d)
open(dst, 'wb').write(out)
print('%s: %d bytes' % (os.path.basename(dst), len(out)))
