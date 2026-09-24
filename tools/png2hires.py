#!/usr/bin/env python3
# Convert design/bootscreen.png -> C64 HI-RES bitmap (320x200, sharp).
# Outputs data/boot_bmp.bin (8000) + data/boot_scr.bin (1000).
# Hi-res: 2 colours per 8x8 cell -> screen byte = (fg<<4)|bg, bit=1 -> fg.
from PIL import Image
from collections import Counter

PAL = [
 (0x00,0x00,0x00),(0xff,0xff,0xff),(0x88,0x00,0x00),(0xaa,0xff,0xee),
 (0xcc,0x44,0xcc),(0x00,0xcc,0x55),(0x00,0x00,0xaa),(0xee,0xee,0x77),
 (0xdd,0x88,0x55),(0x66,0x44,0x00),(0xff,0x77,0x77),(0x33,0x33,0x33),
 (0x77,0x77,0x77),(0xaa,0xff,0x66),(0x00,0x88,0xff),(0xbb,0xbb,0xbb),
]

def dist(a,b):
    return (a[0]-b[0])**2+(a[1]-b[1])**2+(a[2]-b[2])**2

def nearest(rgb):
    best=0;bd=1<<30
    for i,c in enumerate(PAL):
        d=dist(rgb,c)
        if d<bd: bd=d;best=i
    return best

src=Image.open('design/bootscreen.png').convert('RGB')
img=src.resize((320,200), Image.LANCZOS)
px=img.load()

bitmap=bytearray(8000)
screen=bytearray(1000)

for cy in range(25):
    for cx in range(40):
        # quantise cell pixels, tally colours
        cnt=Counter()
        cell=[]
        for ry in range(8):
            row=[]
            for rx in range(8):
                idx=nearest(px[cx*8+rx, cy*8+ry])
                row.append(idx); cnt[idx]+=1
            cell.append(row)
        top=[c for c,_ in cnt.most_common(2)]
        bg=top[0]
        fg=top[1] if len(top)>1 else top[0]
        screen[cy*40+cx]=((fg&0xf)<<4)|(bg&0xf)
        for ry in range(8):
            b=0
            for rx in range(8):
                idx=cell[ry][rx]
                # nearest of the two chosen (by palette rgb) -> bit
                if dist(PAL[idx],PAL[fg]) < dist(PAL[idx],PAL[bg]):
                    b|=(1<<(7-rx))
            bitmap[cy*320+cx*8+ry]=b

open('data/boot_bmp.bin','wb').write(bitmap)
open('data/boot_scr.bin','wb').write(screen)
print("hi-res bitmap written (8000 + 1000 bytes)")

# preview back to PNG (320x200 -> x2)
prev=Image.new('RGB',(320,200)); pp=prev.load()
for cy in range(25):
    for cx in range(40):
        s=screen[cy*40+cx]; fg=(s>>4)&0xf; bg=s&0xf
        for ry in range(8):
            b=bitmap[cy*320+cx*8+ry]
            for rx in range(8):
                ci=fg if (b>>(7-rx))&1 else bg
                pp[cx*8+rx, cy*8+ry]=PAL[ci]
prev.resize((640,400),Image.NEAREST).save('build/boot_preview.png')
print("preview -> build/boot_preview.png")
