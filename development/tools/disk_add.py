"""Write optional files to a disk image only when they fit.

usage: disk_add.py <c1541> <image> <reserve-blocks> <file>[=name] ...

Each file is written only if the image still has enough free blocks
(ceil(size/254)) plus <reserve-blocks> left over for the user's own files
(CD64.CFG, NET.CFG, MAIL.CFG, BBS.CFG, DESK.APPS). A file that does not fit
is skipped with a message instead of failing half-way on a full disk.
"""
import glob
import os
import re
import subprocess
import sys

c1541, image, reserve = sys.argv[1], sys.argv[2], int(sys.argv[3])


def free_blocks():
    out = subprocess.run([c1541, '-attach', image, '-dir'], capture_output=True, text=True,
                         errors='replace').stdout
    m = re.search(r'(\d+)\s+blocks free', out)
    return int(m.group(1)) if m else 0


files = []
for arg in sys.argv[4:]:                 # (cmd.exe expandeert * niet zelf)
    path, _, name = arg.partition('=')
    for p in sorted(glob.glob(path)):
        files.append((p, name))

for path, name in files:
    base = os.path.basename(path)
    # .prg zonder extensie op de disk; andere bestanden (x.sid) houden hun naam
    name = name or (os.path.splitext(base)[0] if base.lower().endswith('.prg') else base)
    need = (os.path.getsize(path) + 253) // 254
    free = free_blocks()
    if need + reserve > free:
        print('  %s: past niet op %s (%d blokken, %d vrij)' % (name, os.path.basename(image), need, free))
        continue
    subprocess.run([c1541, '-attach', image, '-write', path, name], capture_output=True)
    print('  %s (%d blokken)' % (name, need))
