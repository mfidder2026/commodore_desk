"""List the existing CD64 disk images in <dir>, most recently changed first.

usage: python tools/disks_by_age.py <dir>

build_disk.bat reads the user's own files (CD64.CFG, MAIL.CFG, ...) back from
these images before it formats new ones. The image the user worked with last
(D81, D71 or D64) has the newest settings, so it is tried first.
"""
import os
import sys

d = sys.argv[1] if len(sys.argv) > 1 else 'build'
disks = [os.path.join(d, 'CD64.' + ext) for ext in ('d81', 'd71', 'd64')]
disks = [p for p in disks if os.path.isfile(p)]
for p in sorted(disks, key=os.path.getmtime, reverse=True):
    print(p)
