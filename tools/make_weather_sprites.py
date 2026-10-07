"""Build the weather sprites of the WEATHER app (docs/WEATHER_Plan.md).

The picture is made of layers of multicolour sprites, each layer 2 sprites
wide (24 x 21 fat pixels = 48 x 21 pixels; X/Y-expanded 96 x 42 on screen):

  SKY     sun or moon            (back)
  CLOUD   cloud                  (middle)
  PRECIP  rain / snow / sleet / fog
  BOLT    lightning, 1 sprite    (front)

Pixel values ('.', '1', '2', '3' in the grids) are the multicolour bit pairs:
  .  00 transparent
  1  01 shared multicolour 1  ($D025) = WHITE
  2  10 the sprite's own colour ($D027+n), chosen per weather type
  3  11 shared multicolour 2  ($D026) = LIGHT GREY

The shapes are drawn in screen pixels (96 x 42 per layer) and sampled per
fat pixel (4 x 2 screen pixels), so circles stay round on screen.

The 3-day forecast uses a small picture per day: 2 sprites side by side,
only Y-expanded (48 x 42 pixels), made by shrinking the big picture to half
size and bringing each sprite to 3 colours (white, light grey and its own).

Output:
  build/weather_spr.bin    the shapes, 128 bytes each (2 sprites x 64)
  build/weather_mini.bin   the small forecast pictures, 128 bytes each
  build/weather_spr.inc    shape numbers, the weather-type table, the small
                           pictures and the forecast codes (WWO -> type)
  build/weather_preview.png  every weather type on its sky (for review)

usage: python tools/make_weather_sprites.py
"""
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
W, H = 24, 21                           # fat pixels per layer (2 sprites)
SW, SH = 96, 42                         # screen pixels per layer

# C64 colours (same palette as tools/make_bootscreen.py)
PAL = [(0x00, 0x00, 0x00), (0xff, 0xff, 0xff), (0x88, 0x00, 0x00), (0xaa, 0xff, 0xee),
       (0xcc, 0x44, 0xcc), (0x00, 0xcc, 0x55), (0x00, 0x00, 0xaa), (0xee, 0xee, 0x77),
       (0xdd, 0x88, 0x55), (0x66, 0x44, 0x00), (0xff, 0x77, 0x77), (0x33, 0x33, 0x33),
       (0x77, 0x77, 0x77), (0xaa, 0xff, 0x66), (0x00, 0x88, 0xff), (0xbb, 0xbb, 0xbb)]
BLACK, WHITE, RED, CYAN, PURPLE, GREEN, BLUE, YELLOW = range(8)
ORANGE, BROWN, LRED, DGREY, GREY, LGREEN, LBLUE, LGREY = range(8, 16)
MC1, MC2 = WHITE, LGREY                 # shared multicolours


def blank():
    return [['.'] * W for _ in range(H)]


def from_screen(fn):
    """Sample fn(x, y) -> '.', '1', '2', '3' at the centre of each fat pixel."""
    g = blank()
    for r in range(H):
        for c in range(W):
            g[r][c] = fn(c * 4 + 2, r * 2 + 1)
    return g


def in_disc(x, y, cx, cy, r):
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def overlay(*gs):
    out = blank()
    for g in gs:
        for r in range(H):
            for c in range(W):
                if g[r][c] != '.':
                    out[r][c] = g[r][c]
    return out


def shift(g, dc, dr):
    """Shift a grid (wrapping round), for the second animation frame."""
    out = blank()
    for r in range(H):
        for c in range(W):
            out[(r + dr) % H][(c + dc) % W] = g[r][c]
    return out


def text_grid(rows):
    rows = [r.ljust(W, '.')[:W] for r in rows] + ['.' * W] * (H - len(rows))
    return [list(r) for r in rows[:H]]


# ---- shapes -------------------------------------------------------------------
def sun(rays_phase):
    cx, cy, r = 30, 21, 12

    def f(x, y):
        d = math.hypot(x - cx, y - cy)
        if d <= r:                                   # disc with a white highlight
            if in_disc(x, y, cx - 4, cy - 5, 4):
                return '1'
            return '2'
        if r + 3 <= d <= r + 9:                      # 8 rays, every other one long
            a = (math.degrees(math.atan2(y - cy, x - cx)) + 360 + rays_phase) % 45
            long_ray = int(((math.degrees(math.atan2(y - cy, x - cx)) + 360 + rays_phase) // 45)) % 2 == 0
            if (a < 7 or a > 38) and (long_ray or d <= r + 6):
                return '2'
        return '.'
    return from_screen(f)


def moon():
    cx, cy, r = 32, 20, 16

    def f(x, y):
        if in_disc(x, y, cx, cy, r) and not in_disc(x, y, cx + 12, cy - 7, 14):
            if in_disc(x, y, cx - 9, cy + 2, 2.5) or in_disc(x, y, cx - 3, cy + 10, 2.5):
                return '2'                           # craters (sprite colour)
            if (x - cx) * 0.4 + (y - cy) > 7:
                return '3'                           # shade at the bottom
            return '1'
        return '.'
    g = from_screen(f)
    for c, r in ((17, 3), (21, 9), (14, 15)):        # stars: small crosses
        g[r][c] = '1'
        g[r - 1][c] = g[r + 1][c] = '3'
    return g


def cloud(big):
    if big:
        discs = [(20, 30, 9), (34, 21, 12), (54, 15, 15), (72, 21, 12), (84, 30, 8)]
        base = (20, 84, 30, 39)
    else:                                            # small, on the right
        discs = [(56, 30, 7), (68, 23, 10), (82, 26, 9), (88, 32, 6)]
        base = (56, 88, 30, 38)

    def shape(x, y):
        x0, x1, y0, y1 = base
        if x0 <= x <= x1 and y0 <= y <= y1:
            return True
        return any(in_disc(x, y, *d) for d in discs)

    def inside(x, y):
        # filled per column: from the top of the outline down to the bottom
        # (no holes where two bulges meet)
        if not shape(x, y):
            top = any(shape(x, yy) for yy in range(0, y))
            bottom = any(shape(x, yy) for yy in range(y + 1, SH + 8))
            return top and bottom
        return True

    def f(x, y):
        if not inside(x, y):
            return '.'
        if not inside(x, y - 4):                     # top edge: white highlight
            return '1'
        if not inside(x, y + 4):                     # underside: light grey
            return '3'
        return '2'
    return from_screen(f)


def streaks(step, length, seed, per_col=1, colour='2'):
    """Rain: vertical drops (length rows, white tip) in every `step`-th
    column under the cloud, at staggered heights (an even pattern)."""
    g = blank()
    for k, c in enumerate(range(5, W - 3, step)):
        for d in range(per_col):
            r0 = (k * 7 + seed * 3 + d * (H // per_col)) % H
            for t in range(length):
                g[(r0 + t) % H][c] = colour
            g[(r0 + length) % H][c] = '1'
    return g


def flakes(step, seed):
    """Snow: flakes (a cross, 3 wide and 5 high) on a staggered grid."""
    g = blank()
    k = 0
    for c in range(5, W - 3, step):
        for r in (3 + (k * 5 + seed) % 6, 13 + (k * 3 + seed) % 5):
            g[r][c] = '3'
            for dc, dr in ((-1, 0), (1, 0), (0, -1), (0, 1), (0, -2), (0, 2)):
                if 0 <= r + dr < H and 0 <= c + dc < W:
                    g[r + dr][c + dc] = '1'
        k += 1
    return g


def fog(phase):
    def f(x, y):
        for i, yy in enumerate((6, 16, 26, 36)):
            wave = 2 * math.sin((x + phase * 12 + i * 20) / 11.0)
            if abs(y - (yy + wave)) <= 2:
                return '1' if i % 2 == 0 else '3'
        return '.'
    return from_screen(f)


BOLT = text_grid([
    '............',
    '.....2222...',
    '....2112....',
    '....212.....',
    '...2112.....',
    '...212......',
    '..21122222..',
    '..2111112...',
    '...22212....',
    '....212.....',
    '....212.....',
    '...212......',
    '...21.......',
    '..212.......',
    '..21........',
    '..2.........',
])

QMARK = text_grid([
    '.........222222.........',
    '.........222222.........',
    '........22....22........',
    '........22....22........',
    '..............22........',
    '..............22........',
    '.............22.........',
    '............22..........',
    '...........22...........',
    '...........22...........',
    '...........22...........',
    '........................',
    '...........22...........',
    '...........22...........',
])

SHAPES = {
    'SUN_A': sun(0),
    'SUN_B': sun(22.5),
    'MOON': moon(),
    'CLOUD_BIG': cloud(True),
    'CLOUD_SMALL': cloud(False),
    'RAIN_L_A': streaks(3, 3, 1),
    'RAIN_H_A': streaks(2, 4, 2, per_col=2),
    'SNOW_L_A': flakes(6, 1),
    'SNOW_H_A': flakes(3, 2),
    'SLEET_A': overlay(streaks(4, 3, 3), flakes(8, 4)),
    'FOG_A': fog(0),
    'BOLT': BOLT,
    'QMARK': QMARK,
}
SHAPES['RAIN_L_B'] = shift(SHAPES['RAIN_L_A'], 0, 5)
SHAPES['RAIN_H_B'] = shift(SHAPES['RAIN_H_A'], 0, 5)
SHAPES['SNOW_L_B'] = shift(SHAPES['SNOW_L_A'], 1, 2)
SHAPES['SNOW_H_B'] = shift(SHAPES['SNOW_H_A'], 1, 2)
SHAPES['SLEET_B'] = shift(SHAPES['SLEET_A'], 0, 3)
SHAPES['FOG_B'] = fog(1)
ORDER = ['SUN_A', 'SUN_B', 'MOON', 'CLOUD_BIG', 'CLOUD_SMALL', 'RAIN_L_A', 'RAIN_L_B',
         'RAIN_H_A', 'RAIN_H_B', 'SNOW_L_A', 'SNOW_L_B', 'SNOW_H_A', 'SNOW_H_B',
         'SLEET_A', 'SLEET_B', 'FOG_A', 'FOG_B', 'BOLT', 'QMARK']

# ---- weather types --------------------------------------------------------------
# (name, wttr.in %x symbols, sky colour, layers FRONT FIRST [(shape, colour, (dx, dy)[, width])],
#  animated layer: (shape A, shape B) or None).  dx/dy in screen pixels.
#  width: sprites of the layer (default 2, the bolt 1); a layer of 1 sprite
#  only shows the left half of its shape, and must come last when it moves
#  (the animation also sets the pointer of the next sprite).
P_SKY, P_CLOUD, P_RAIN = (0, 0), (0, 14), (0, 44)
TYPES = [
    ('SUNNY', 'o', LBLUE, [('SUN_A', YELLOW, P_SKY)], ('SUN_A', 'SUN_B')),
    ('CLEAR NIGHT', 'o*', BLUE, [('MOON', GREY, P_SKY)], None),
    ('PARTLY CLOUDY', 'm', LBLUE, [('CLOUD_SMALL', WHITE, (0, 18)), ('SUN_A', YELLOW, P_SKY)], None),
    ('PARTLY CLOUDY NIGHT', 'm*', BLUE, [('CLOUD_SMALL', LGREY, (0, 18)), ('MOON', GREY, P_SKY)], None),
    ('CLOUDY', 'mm', LBLUE, [('CLOUD_BIG', WHITE, P_CLOUD), ('CLOUD_SMALL', LGREY, (-34, -2))], None),
    ('OVERCAST', 'mmm', GREY, [('CLOUD_BIG', LGREY, P_CLOUD), ('CLOUD_SMALL', WHITE, (-34, -2))], None),
    ('FOG', '=', GREY, [('FOG_A', LGREY, (0, 20))], ('FOG_A', 'FOG_B')),
    ('LIGHT RAIN', '. /', LBLUE, [('CLOUD_BIG', LGREY, P_CLOUD), ('RAIN_L_A', BLUE, P_RAIN)],
     ('RAIN_L_A', 'RAIN_L_B')),
    ('SHOWERS', './ (day)', LBLUE, [('CLOUD_SMALL', WHITE, (0, 18)), ('SUN_A', YELLOW, P_SKY),
                                    ('RAIN_L_A', BLUE, (40, 46), 1)],    # (stays in the panel)
     ('RAIN_L_A', 'RAIN_L_B')),
    ('HEAVY RAIN', '// ///', GREY, [('CLOUD_BIG', DGREY, P_CLOUD), ('RAIN_H_A', LBLUE, P_RAIN)],
     ('RAIN_H_A', 'RAIN_H_B')),
    ('LIGHT SNOW', '* */', LBLUE, [('CLOUD_BIG', LGREY, P_CLOUD), ('SNOW_L_A', WHITE, P_RAIN)],
     ('SNOW_L_A', 'SNOW_L_B')),
    ('HEAVY SNOW', '** */*', GREY, [('CLOUD_BIG', GREY, P_CLOUD), ('SNOW_H_A', WHITE, P_RAIN)],
     ('SNOW_H_A', 'SNOW_H_B')),
    ('SLEET', 'x x/', GREY, [('CLOUD_BIG', LGREY, P_CLOUD), ('SLEET_A', BLUE, P_RAIN)],
     ('SLEET_A', 'SLEET_B')),
    ('THUNDER', '!/ /!/', DGREY, [('BOLT', YELLOW, (40, 36)), ('CLOUD_BIG', GREY, P_CLOUD),
                                  ('RAIN_H_A', LBLUE, P_RAIN)], ('RAIN_H_A', 'RAIN_H_B')),
    ('THUNDER SNOW', '*!*', DGREY, [('BOLT', YELLOW, (40, 36)), ('CLOUD_BIG', GREY, P_CLOUD),
                                    ('SNOW_H_A', WHITE, P_RAIN)], ('SNOW_H_A', 'SNOW_H_B')),
    ('UNKNOWN', '?', LBLUE, [('QMARK', DGREY, (2, 18)), ('CLOUD_BIG', LGREY, P_CLOUD)], None),
]
PIC_W, PIC_H = 96, 84                   # the sky panel (12 x 10.5 characters)
# where the sky panel sits on the C64 screen (apps/weather/weather.asm:
# WE_COL / WE_SKYR) as sprite coordinates: x = 24 + col*8, y = 50 + row*8
PANEL_COL, PANEL_ROW = 3, 7
PANEL_X, PANEL_Y = 24 + PANEL_COL * 8, 50 + PANEL_ROW * 8


# ---- small pictures (forecast) -------------------------------------------------
NIGHT = ('CLEAR NIGHT', 'PARTLY CLOUDY NIGHT')
MINI_TYPES = [t for t in TYPES if t[0] not in NIGHT]
ACCENT = (YELLOW, BLUE, LBLUE)          # these win the sprite's own colour


def compose(t):
    """The big picture of a type (panel pixels, colour or None)."""
    img = [[None] * PIC_W for _ in range(PIC_H)]
    for layer in reversed(t[3]):
        shape, colour, (dx, dy) = layer[:3]
        g = SHAPES[shape]
        for r in range(H):
            for c in range(12 * width(layer)):
                v = g[r][c]
                if v == '.':
                    continue
                col = {'1': MC1, '2': colour, '3': MC2}[v]
                for yy in range(2):
                    for xx in range(4):
                        X, Y = dx + c * 4 + xx, dy + r * 2 + yy
                        if 0 <= X < PIC_W and 0 <= Y < PIC_H:
                            img[Y][X] = col
    return img


def mini(t):
    """24 x 21 fat pixels (2 x 2 screen pixels): half size, centred, and per
    sprite (12 columns) only white, light grey and one colour of its own.
    Returns (grid of '.', '1', '2', '3', (own colour left, right))."""
    from collections import Counter
    img = compose(t)
    pts = [(x, y) for y in range(PIC_H) for x in range(PIC_W) if img[y][x] is not None]
    x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
    y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
    ox = (x0 + x1 + 1) // 2 - 48        # centre of the drawing -> centre of 96 x 84
    oy = (y0 + y1 + 1) // 2 - 42
    grid = [[None] * 24 for _ in range(21)]
    for r in range(21):
        for c in range(24):
            cnt = Counter()
            for y in range(4 * r + oy, 4 * r + oy + 4):
                for x in range(4 * c + ox, 4 * c + ox + 4):
                    cnt[img[y][x] if 0 <= x < PIC_W and 0 <= y < PIC_H else None] += 1
            col = cnt.most_common(1)[0][0]
            if col is None:
                nn = [(k, v) for k, v in cnt.items() if k is not None]
                if nn and max(v for _, v in nn) >= 6:
                    col = max(nn, key=lambda kv: kv[1])[0]
            grid[r][c] = col
    own = []
    for h in range(2):
        cnt = Counter(grid[r][c] for r in range(21) for c in range(h * 12, h * 12 + 12)
                      if grid[r][c] not in (None, MC1, MC2))
        acc = [k for k in ACCENT if cnt[k] >= 2]
        own.append(acc[0] if acc else (cnt.most_common(1)[0][0] if cnt else DGREY))

    def dist(a, b):
        return sum((p - q) ** 2 for p, q in zip(PAL[a], PAL[b]))
    out = blank()
    for r in range(21):
        for c in range(24):
            v = grid[r][c]
            if v is None:
                continue
            o = own[c // 12]
            k = o if v == o else min((MC1, MC2), key=lambda k: dist(k, v))
            out[r][c] = {MC1: '1', MC2: '3'}.get(k, '2')
    return out, own


# forecast: WWO weather codes (wttr.in format=j1, "weatherCode") -> type.
# The C64 looks them up as code >> 1 (all different, and < 256).
WWO = {113: 'SUNNY', 116: 'PARTLY CLOUDY', 119: 'CLOUDY', 122: 'OVERCAST',
       143: 'FOG', 248: 'FOG', 260: 'FOG'}
for codes, name in (((176, 263, 353), 'SHOWERS'), ((266, 293, 296), 'LIGHT RAIN'),
                    ((299, 302, 305, 308, 356, 359), 'HEAVY RAIN'),
                    ((179, 182, 185, 281, 284, 311, 314, 317, 350, 362, 365, 374, 377), 'SLEET'),
                    ((200, 386, 389), 'THUNDER'), ((227, 320, 323, 326, 368), 'LIGHT SNOW'),
                    ((230, 329, 332, 335, 338, 371, 395), 'HEAVY SNOW'), ((392,), 'THUNDER SNOW')):
    for c in codes:
        WWO[c] = name


def mini_asm():
    names = [t[0] for t in TYPES]
    keys = sorted(WWO)
    assert len({k >> 1 for k in keys}) == len(keys) and max(keys) >> 1 < 255
    mi = [names.index(t[0]) for t in MINI_TYPES]
    minis = [mini(t)[1] for t in MINI_TYPES]
    out = ['wtMini: .byte %s' % ', '.join(str(mi.index(i)) if i in mi else '0'
                                         for i in range(len(TYPES))),
           'wmColL: .byte %s' % ', '.join(str(o[0]) for o in minis),
           'wmColR: .byte %s' % ', '.join(str(o[1]) for o in minis),
           '.const WC_N = %d' % len(keys),
           'wcKey:  .byte %s' % ', '.join(str(k >> 1) for k in keys),
           'wcType: .byte %s' % ', '.join(str(names.index(WWO[k])) for k in keys)]
    return '\n'.join(out) + '\n'


def render_mini():
    from PIL import Image
    sc = 3
    img = Image.new('RGB', (len(MINI_TYPES) * 56 * sc, 56 * sc), (40, 40, 40))
    px = img.load()
    for i, t in enumerate(MINI_TYPES):
        g, own = mini(t)
        ox = i * 56 + 4
        for y in range(48):
            for x in range(48):
                for a in range(sc):
                    for b in range(sc):
                        px[(ox + x) * sc + a, (4 + y) * sc + b] = PAL[t[2]]
        for r in range(21):
            for c in range(24):
                v = g[r][c]
                if v == '.':
                    continue
                rgb = PAL[{'1': MC1, '3': MC2, '2': own[c // 12]}[v]]
                for yy in range(2):
                    for xx in range(2):
                        for a in range(sc):
                            for b in range(sc):
                                px[(ox + c * 2 + xx) * sc + a, (7 + r * 2 + yy) * sc + b] = rgb
    return img


# ---- output ---------------------------------------------------------------------
def sprite_bytes(g, half):
    """64 bytes of one sprite: 21 rows x 3 bytes (12 fat pixels), + 1 pad."""
    out = bytearray()
    for r in range(H):
        bits = 0
        for c in range(12):
            v = {'.': 0, '1': 1, '2': 2, '3': 3}[g[r][half * 12 + c]]
            bits = (bits << 2) | v
        out += bits.to_bytes(3, 'big')
    return out + b'\x00'


def width(layer):
    return layer[3] if len(layer) > 3 else (1 if layer[0] == 'BOLT' else 2)


def check_blocks():
    """At most 8 sprite blocks per weather type (plan 3.2) and 7 sprites;
    every layer stays inside the panel."""
    for name, _, _, layers, anim in TYPES:
        shapes = {l[0] for l in layers} | set(anim or ())
        blocks = sum(1 if s == 'BOLT' else 2 for s in shapes)
        sprites = sum(width(l) for l in layers)
        assert blocks <= 8, (name, blocks)
        assert sprites <= 7, (name, sprites)
        for i, l in enumerate(layers):
            g, (dx, dy) = SHAPES[l[0]], l[2]
            used = [c for r in range(H) for c in range(12 * width(l)) if g[r][c] != '.']
            assert dx + (max(used) + 1) * 4 <= PIC_W, (name, l[0], 'leaves the panel')
            if anim and l[0] == anim[0] and width(l) == 1:
                assert i == len(layers) - 1, (name, 'a moving 1-sprite layer must be last')


def render(frame):
    """All weather types on their sky, 2 x scale, frame 0 or 1."""
    from PIL import Image, ImageDraw
    cols, sc = 4, 2
    rows = (len(TYPES) + cols - 1) // cols
    cell_w, cell_h = PIC_W + 16, PIC_H + 30
    img = Image.new('RGB', (cols * cell_w * sc, rows * cell_h * sc), (40, 40, 40))
    px = img.load()
    d = ImageDraw.Draw(img)
    for i, (name, sym, sky, layers, anim) in enumerate(TYPES):
        ox, oy = (i % cols) * cell_w + 8, (i // cols) * cell_h + 8
        for y in range(PIC_H):
            for x in range(PIC_W):
                for a in range(sc):
                    for b in range(sc):
                        px[(ox + x) * sc + a, (oy + y) * sc + b] = PAL[sky]
        # back to front: the last layer in the list is drawn first
        for layer in reversed(layers):
            shape, colour, (dx, dy) = layer[:3]
            if frame and anim and shape == anim[0]:
                shape = anim[1]
            g = SHAPES[shape]
            for r in range(H):
                for c in range(12 * width(layer)):
                    v = g[r][c]
                    if v == '.':
                        continue
                    rgb = PAL[{'1': MC1, '2': colour, '3': MC2}[v]]
                    for yy in range(2):
                        for xx in range(4):
                            X, Y = dx + c * 4 + xx, dy + r * 2 + yy
                            if 0 <= X < PIC_W and 0 <= Y < PIC_H:
                                for a in range(sc):
                                    for b in range(sc):
                                        px[(ox + X) * sc + a, (oy + Y) * sc + b] = rgb
        d.text((ox * sc, (oy + PIC_H + 4) * sc), '%s  [%s]' % (name, sym), fill=(230, 230, 230))
    return img


def types_asm():
    """Per weather type (index = TYPES): sky colour, up to 4 layers front
    first (shape, colour, sprite x/y of the left sprite, 1 or 2 sprites),
    the animated layer + its second shape, and the lightning layer."""
    sky, nl, al, ab, bl = [], [], [], [], []
    sh, co, xs, ys, wd = [], [], [], [], []
    for name, sym, skyc, layers, anim in TYPES:
        sky.append(skyc)
        nl.append(len(layers))
        a_l, a_b, b_l = 255, 0, 255
        for i in range(4):
            if i < len(layers):
                s, c, (dx, dy) = layers[i][:3]
                x, y = PANEL_X + dx, PANEL_Y + dy
                assert 0 <= x and x + 96 <= 255 and 0 <= y <= 255, (name, x, y)
                sh.append(ORDER.index(s))
                co.append(c)
                xs.append(x)
                ys.append(y)
                wd.append(width(layers[i]))
                if anim and s == anim[0]:
                    a_l, a_b = i, ORDER.index(anim[1])
                if s == 'BOLT':
                    b_l = i
            else:
                for lst in (sh, co, xs, ys, wd):
                    lst.append(0)
        al.append(a_l)
        ab.append(a_b)
        bl.append(b_l)
    out = ['', '.const WT_N = %d' % len(TYPES)]
    for lab, vals in (('wtSky', sky), ('wtNL', nl), ('wtAnimL', al), ('wtAnimB', ab),
                      ('wtBolt', bl), ('wtShape', sh), ('wtCol', co), ('wtX', xs),
                      ('wtY', ys), ('wtW', wd)):
        out.append('%s: .byte %s' % (lab, ', '.join(str(v) for v in vals)))
    out.append('// types: ' + ', '.join('%d %s' % (i, t[0]) for i, t in enumerate(TYPES)))
    return '\n'.join(out) + '\n'


def main():
    check_blocks()
    data = bytearray()
    for s in ORDER:
        g = SHAPES[s]
        data += sprite_bytes(g, 0) + sprite_bytes(g, 1)
    os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
    open(os.path.join(ROOT, 'build', 'weather_spr.bin'), 'wb').write(data)
    with open(os.path.join(ROOT, 'build', 'weather_spr.inc'), 'w') as f:
        f.write('// generated by tools/make_weather_sprites.py - do not edit\n')
        for i, s in enumerate(ORDER):
            f.write('.const WS_%s = %d\n' % (s, i))
        f.write(types_asm())
        f.write(mini_asm())
    mdata = bytearray()
    for t in MINI_TYPES:
        g = mini(t)[0]
        mdata += sprite_bytes(g, 0) + sprite_bytes(g, 1)
    open(os.path.join(ROOT, 'build', 'weather_mini.bin'), 'wb').write(mdata)
    try:
        from PIL import Image
        a, b = render(0), render(1)
        both = Image.new('RGB', (a.width, a.height * 2 + 20), (20, 20, 20))
        both.paste(a, (0, 0))
        both.paste(b, (0, a.height + 20))
        both.save(os.path.join(ROOT, 'build', 'weather_preview.png'))
        render_mini().save(os.path.join(ROOT, 'build', 'weather_mini.png'))
    except ImportError:
        print('(no Pillow: no preview)')
    print('weather_spr.bin: %d shapes, %d bytes; %d weather types; %d small pictures (%d bytes)'
          % (len(ORDER), len(data), len(TYPES), len(MINI_TYPES), len(mdata)))


if __name__ == '__main__':
    main()
