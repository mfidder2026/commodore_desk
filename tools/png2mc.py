#!/usr/bin/env python3
# Convert design/bootscreen.png -> C64 multicolor bitmap (bitmap/screen/color/bg)
from PIL import Image

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
# multicolor: 160 wide x 200 tall
img=src.resize((160,200), Image.LANCZOS)
px=img.load()

# quantize every pixel to C64 index
q=[[nearest(px[x,y]) for x in range(160)] for y in range(200)]

# global background = most frequent color overall
from collections import Counter
gc=Counter()
for y in range(200):
    for x in range(160):
        gc[q[y][x]]+=1
bg=gc.most_common(1)[0][0]

bitmap=bytearray(8000)
screen=bytearray(1000)
color =bytearray(1000)

for cy in range(25):
    for cx in range(40):
        # gather cell pixels (4 wide x 8 tall)
        cnt=Counter()
        cellpx=[]
        for ry in range(8):
            for rx in range(4):
                x=cx*4+rx; y=cy*8+ry
                idx=q[y][x]
                cellpx.append((rx,ry,idx))
                if idx!=bg: cnt[idx]+=1
        top=[c for c,_ in cnt.most_common(3)]
        while len(top)<3: top.append(bg)
        c1,c2,c3=top[0],top[1],top[2]
        chosen=[bg,c1,c2,c3]
        screen[cy*40+cx]=((c1&0xf)<<4)|(c2&0xf)
        color[cy*40+cx]=c3&0xf
        # build bitmap bytes for this cell
        for ry in range(8):
            b=0
            for rx in range(4):
                x=cx*4+rx; y=cy*8+ry
                rgb=px[x,y]
                # nearest among chosen 4 (by their palette rgb)
                bestk=0;bd=1<<30
                for k,ci in enumerate(chosen):
                    d=dist(rgb,PAL[ci])
                    if d<bd: bd=d;bestk=k
                b|=(bestk&3)<<((3-rx)*2)
            bitmap[cy*320+cx*8+ry]=b

open('data/boot_bmp.bin','wb').write(bitmap)
open('data/boot_scr.bin','wb').write(screen)
open('data/boot_col.bin','wb').write(color)
print("bg index =",bg)

# preview render back to PNG (320x200 -> scale x2)
prev=Image.new('RGB',(320,200))
pp=prev.load()
for cy in range(25):
    for cx in range(40):
        s=screen[cy*40+cx]; c1=(s>>4)&0xf; c2=s&0xf; c3=color[cy*40+cx]&0xf
        chosen=[bg,c1,c2,c3]
        for ry in range(8):
            b=bitmap[cy*320+cx*8+ry]
            for rx in range(4):
                code=(b>>((3-rx)*2))&3
                ci=chosen[code]
                col=PAL[ci]
                X=(cx*4+rx)*2; Y=cy*8+ry
                pp[X,Y]=col; pp[X+1,Y]=col
prev.resize((640,400),Image.NEAREST).save('build/boot_preview.png')
print("preview written")
