#!/usr/bin/env python3
# Generate a NATIVE 320x200 hi-res C64 boot screen (sharp, cell-clean).
# Draws with the real C64 charset (data/chargen.bin), flat C64 colours,
# max 2 colours per 8x8 cell. Emits data/boot_bmp.bin + data/boot_scr.bin
# and a preview (build/boot_preview.png).
from PIL import Image

PAL = [
 (0x00,0x00,0x00),(0xff,0xff,0xff),(0x88,0x00,0x00),(0xaa,0xff,0xee),
 (0xcc,0x44,0xcc),(0x00,0xcc,0x55),(0x00,0x00,0xaa),(0xee,0xee,0x77),
 (0xdd,0x88,0x55),(0x66,0x44,0x00),(0xff,0x77,0x77),(0x33,0x33,0x33),
 (0x77,0x77,0x77),(0xaa,0xff,0x66),(0x00,0x88,0xff),(0xbb,0xbb,0xbb),
]
# colour names
BLACK,WHITE,RED,CYAN,PURPLE,GREEN,BLUE,YELLOW=0,1,2,3,4,5,6,7
ORANGE,BROWN,LRED,DGREY,GREY,LGREEN,LBLUE,LGREY=8,9,10,11,12,13,14,15

font=open('data/chargen.bin','rb').read()   # 2048 bytes, 8x8 glyphs

def sc(ch):
    if 'A'<=ch<='Z': return ord(ch)-64
    o=ord(ch)
    if 0x20<=o<=0x3f: return o
    return 0x20

grid=[[GREY]*320 for _ in range(200)]        # flat grey desktop

def fill(x0,y0,x1,y1,c):
    for y in range(y0,y1):
        for x in range(x0,x1):
            if 0<=x<320 and 0<=y<200: grid[y][x]=c

def text(s,x,y,fg,scale=1):
    for i,ch in enumerate(s):
        g=sc(ch)
        for ry in range(8):
            bits=font[g*8+ry]
            for rx in range(8):
                if bits&(1<<(7-rx)):
                    for sy in range(scale):
                        for sx in range(scale):
                            X=x+(i*8+rx)*scale+sx; Y=y+ry*scale+sy
                            if 0<=X<320 and 0<=Y<200: grid[Y][X]=fg

def ctext(s,y,fg,scale=1):
    w=len(s)*8*scale
    text(s,(320-w)//2,y,fg,scale)

# ---- header strip (rows 0-1) ----
fill(0,0,320,16,BLUE)
ctext("COMMODORE 64      64K RAM SYSTEM",4,WHITE,1)

# ---- centre panel (rows 4-21) with white border ----
fill(8,32,312,176,BLUE)
fill(8,32,312,34,WHITE); fill(8,174,312,176,WHITE)
fill(8,32,10,176,WHITE); fill(310,32,312,176,WHITE)

# ---- Windows-flag logo: 4 squares, centred, rows 6-9 ----
sq=16; gap=8
lw=sq*2+gap
lx=(320-lw)//2; ly=48
fill(lx,      ly,      lx+sq,      ly+sq,      RED)
fill(lx+sq+gap,ly,     lx+2*sq+gap,ly+sq,      GREEN)
fill(lx,      ly+sq+gap,lx+sq,     ly+2*sq+gap,LBLUE)
fill(lx+sq+gap,ly+sq+gap,lx+2*sq+gap,ly+2*sq+gap,YELLOW)

# ---- big title (scale 2) ----
ctext("COMMODORE DESK 64",96,WHITE,2)

# ---- subtitle + version (scale 1) ----
ctext("GRAPHICAL DESKTOP ENVIRONMENT",128,CYAN,1)
ctext("VERSION 1.0   -   VIC-II 320X200",144,LGREY,1)
ctext("(C) 2026 FREMEN IT WORKERS",160,WHITE,1)

# ---- footer strip (rows 23-24) ----
# text on row 23; row 24 (py 192-199) is left blank for the Knight Rider LED
fill(0,184,320,200,BLUE)
ctext("LOADING - PLEASE WAIT",184,YELLOW,1)

# ---- emit hi-res bitmap + screen (max 2 colours/cell) ----
bitmap=bytearray(8000); screen=bytearray(1000)
overflow=0
for cy in range(25):
    for cx in range(40):
        from collections import Counter
        cnt=Counter()
        for ry in range(8):
            for rx in range(8):
                cnt[grid[cy*8+ry][cx*8+rx]]+=1
        cols=[c for c,_ in cnt.most_common()]
        if len(cols)>2: overflow+=1
        bg=cols[0]; fg=cols[1] if len(cols)>1 else cols[0]
        screen[cy*40+cx]=((fg&0xf)<<4)|(bg&0xf)
        for ry in range(8):
            b=0
            for rx in range(8):
                if grid[cy*8+ry][cx*8+rx]==fg and fg!=bg:
                    b|=(1<<(7-rx))
            bitmap[cy*320+cx*8+ry]=b

open('data/boot_bmp.bin','wb').write(bitmap)
open('data/boot_scr.bin','wb').write(screen)
print("boot screen written; cells with >2 colours:",overflow)

prev=Image.new('RGB',(320,200)); pp=prev.load()
for y in range(200):
    for x in range(320): pp[x,y]=PAL[grid[y][x]]
prev.resize((640,400),Image.NEAREST).save('build/boot_preview.png')
print("preview -> build/boot_preview.png")
