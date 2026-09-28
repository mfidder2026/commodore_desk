"""data/radio_lst.txt (ASCII) -> build/radio.lst (PETSCII, written as SEQ).

The text editor's convention: lower case a-z = $41-$5A, upper case A-Z =
$C1-$DA, '_' = $A4, end of line = CR. RADIO (apps/radio/radio.asm) turns
it back into ASCII for the HTTP request (paths are case-sensitive).
"""
import os
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = bytearray()
for line in open(os.path.join(root, 'data', 'radio_lst.txt'), encoding='ascii'):
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
open(os.path.join(root, 'build', 'radio.lst'), 'wb').write(out)
print('radio.lst: %d bytes' % len(out))
