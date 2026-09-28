"""Build data/radio_lst.txt: the playlist of the RADIO app.

Line 1 is the server and base path, the other lines are tunes relative to
it. Every tune is downloaded once and checked with the same rules as the
CD64 SID player (apps/sidplay.asm), so RADIO only gets tunes it can play:
  - PSID with a play address (no own IRQ), not a BASIC tune
  - 50 Hz (VBI) speed for the start song
  - load area $0800-$3FFF, $4000-$7FFF, $C000-$CFFF or $E000-$FFF9
  - the file (at $4000) plus, if needed, a copy of the memory it replaces
    must stay below $8000
Only the paths are stored; the music itself stays on the server.

usage: python tools/make_radio_list.py [per-composer] [max-bytes]
"""
import os, re, sys, time, urllib.request

HOST = 'hvsc.brona.dk'
BASE = '/HVSC/C64Music/MUSICIANS/'
COMPOSERS = ['H/Hubbard_Rob', 'G/Galway_Martin', 'D/Daglish_Ben', 'T/Tel_Jeroen',
             'H/Huelsbeck_Chris', 'F/Follin_Tim', 'W/Whittaker_David', 'G/Gray_Matt',
             'R/Rowlands_Steve', 'C/Cooksey_Mark', 'D/Dunn_Jonathan', 'B/Brennan_Neil',
             'G/Gray_Fred', 'D/Deenen_Charles', 'C/Crowther_Antony']
PER = int(sys.argv[1]) if len(sys.argv) > 1 else 8
MAXB = int(sys.argv[2]) if len(sys.argv) > 2 else 2700      # RL_MAX in apps/radio/radio.asm
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'data', 'radio_lst.txt')


def get(path):
    time.sleep(0.2)                      # be polite to the mirror
    with urllib.request.urlopen('http://%s%s' % (HOST, path), timeout=20) as r:
        return r.read()


def playable(d):
    if len(d) < 0x76 or d[:4] != b'PSID':
        return False
    ver, off = d[5], (d[6] << 8) | d[7]
    load = (d[8] << 8) | d[9]
    play = (d[0x0c] << 8) | d[0x0d]
    start = max(d[0x11], 1) - 1
    speed = int.from_bytes(d[0x12:0x16], 'big')
    if play == 0 or (speed >> min(start, 31)) & 1:
        return False
    if ver >= 2 and len(d) > 0x77 and d[0x77] & 2:           # C64 BASIC tune
        return False
    data = d[off:]
    if load == 0:
        load, data = data[0] | (data[1] << 8), data[2:]
    end = load + len(data)
    if load < 0x0800 or end > 0xfffa:
        return False
    flen = len(d) - 2                     # LOAD/RADIO skip the first 2 bytes
    if flen > 63 * 254:
        return False
    if 0x4000 <= load and end <= 0x8000:
        return True                       # B: moved into place, no copy
    ok = (end <= 0x4000) or (0xc000 <= load and end <= 0xd000) or (load >= 0xe000)
    if not ok:
        return False
    back = (0x4000 + flen + 0xff) & 0xff00  # copy of the replaced memory
    return back + len(data) <= 0x8000


lines = [HOST + BASE]
size = len(lines[0]) + 1
for comp in COMPOSERS:
    html = get(BASE + comp + '/').decode('latin-1')
    names = [n for n in re.findall(r'href="([^"?/][^"]*\.sid)"', html)]
    n = 0
    for name in names:
        if n >= PER:
            break
        rel = comp + '/' + name
        if size + len(rel) + 1 > MAXB:
            break
        try:
            if not playable(get(BASE + rel)):
                continue
        except Exception as e:
            print('skip', rel, e)
            continue
        lines.append(rel)
        size += len(rel) + 1
        n += 1
    print(comp, n)
open(OUT, 'w', newline='\n').write('\n'.join(lines) + '\n')
print(len(lines) - 1, 'tunes,', size, 'bytes ->', os.path.normpath(OUT))
