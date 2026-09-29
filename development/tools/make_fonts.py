#!/usr/bin/env python3
# Genereert font-data voor Commodore Desk 64:
#  - data/lower.bin : 26 kleine letters (a-z) uit de C64 char-ROM (208 bytes)
#  - data/tiny.bin  : eigen 3x5 micro-font, A-Z (208) + 0-9 (80) = 288 bytes
import os

ROM = "C:/Users/aegwh/OneDrive/dev/c64/vice/C64/chargen-901225-01.bin"

# ---- lowercase a-z uit de ROM (2e 2KB = lowercase-set, code 1 = 'a') ----
with open(ROM, "rb") as f:
    rom = f.read()
assert len(rom) >= 4096, "chargen ROM moet 4KB zijn"
lower = rom[2048 + 1*8 : 2048 + 27*8]      # codes 1..26 = a..z, 208 bytes
open("data/lower.bin", "wb").write(lower)
print("lower.bin:", len(lower), "bytes")

# ---- 3x5 micro-font ----
# elke glyph = 5 rijen van 3 pixels; geplaatst op rij 1-5, kolom 1-3 (bits 6,5,4)
G = {
 'A':"010 101 111 101 101", 'B':"110 101 110 101 110", 'C':"011 100 100 100 011",
 'D':"110 101 101 101 110", 'E':"111 100 110 100 111", 'F':"111 100 110 100 100",
 'G':"011 100 101 101 011", 'H':"101 101 111 101 101", 'I':"111 010 010 010 111",
 'J':"001 001 001 101 010", 'K':"101 110 100 110 101", 'L':"100 100 100 100 111",
 'M':"101 111 111 101 101", 'N':"101 111 111 111 101", 'O':"010 101 101 101 010",
 'P':"110 101 110 100 100", 'Q':"010 101 101 110 011", 'R':"110 101 110 101 101",
 'S':"011 100 010 001 110", 'T':"111 010 010 010 010", 'U':"101 101 101 101 111",
 'V':"101 101 101 101 010", 'W':"101 101 111 111 101", 'X':"101 101 010 101 101",
 'Y':"101 101 010 010 010", 'Z':"111 001 010 100 111",
 '0':"111 101 101 101 111", '1':"010 110 010 010 111", '2':"111 001 111 100 111",
 '3':"111 001 111 001 111", '4':"101 101 111 001 001", '5':"111 100 111 001 111",
 '6':"111 100 111 101 111", '7':"111 001 010 010 010", '8':"111 101 111 101 111",
 '9':"111 101 111 001 111",
}

def glyph(pat):
    rows = pat.split()
    out = [0]*8
    for i, r in enumerate(rows):          # 5 rijen -> celrijen 1..5
        b = 0
        for c, ch in enumerate(r):        # 3 kolommen -> bits 6,5,4
            if ch == '1':
                b |= 1 << (6 - c)
        out[1 + i] = b
    return bytes(out)

az = b"".join(glyph(G[chr(ord('A')+i)]) for i in range(26))   # A-Z, 208
dg = b"".join(glyph(G[chr(ord('0')+i)]) for i in range(10))   # 0-9, 80
open("data/tiny.bin", "wb").write(az + dg)
print("tiny.bin:", len(az+dg), "bytes")

# ---- preview van het tiny-font ----
try:
    from PIL import Image
    data = az + dg
    n = len(data)//8
    cols = 18; rows = (n+cols-1)//cols
    im = Image.new("RGB", (cols*9, rows*9), (0,0,60))
    px = im.load()
    for g in range(n):
        gx = (g % cols)*9; gy = (g//cols)*9
        for ry in range(8):
            bits = data[g*8+ry]
            for rx in range(8):
                if bits & (1<<(7-rx)):
                    px[gx+rx, gy+ry] = (255,255,255)
    im.resize((cols*9*4, rows*9*4), Image.NEAREST).save("build/tiny_preview.png")
    print("preview -> build/tiny_preview.png")
except Exception as e:
    print("geen preview:", e)
