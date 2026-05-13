#!/usr/bin/env python3
"""
Generate cyberpunk HUD sprite assets for WidgetLib.
Output: PNG files with alpha transparency.
Run: python3 gen_sprites.py
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = os.path.dirname(os.path.abspath(__file__))

# ── Color palette ──────────────────────────────────────────────
C_BG      = (6,   6,  17, 255)
C_PANEL   = (8,   0,  22, 255)
C_DARK    = (3,   0,   9, 255)
C_PINK    = (255,  0, 204)
C_CYAN    = (0,  238, 255)
C_PINK2   = (180,  0, 140)
C_CYAN2   = (0,  140, 180)
C_METAL   = (25,  18,  40)
C_METAL2  = (45,  32,  70)


def glow_layer(draw_fn, size, color, radius, alpha_scale=1.0):
    """Create a glow layer: draw shape on blank, then blur."""
    layer = Image.new('RGBA', size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    draw_fn(d)
    # Blur to create glow
    r, g, b = color
    # Convert to colored layer
    colored = Image.new('RGBA', size, (r, g, b, 0))
    # Use the layer alpha to set glow alpha
    layer_r = layer.split()[3]  # alpha channel
    colored.putalpha(layer_r)
    blurred = colored.filter(ImageFilter.GaussianBlur(radius=radius))
    # Scale alpha
    if alpha_scale != 1.0:
        r2, g2, b2, a2 = blurred.split()
        a2 = a2.point(lambda x: int(x * alpha_scale))
        blurred = Image.merge('RGBA', (r2, g2, b2, a2))
    return blurred


def draw_hex_outline(draw, cx, cy, r, color, width=2):
    """Draw flat-top hexagon outline."""
    pts = []
    for i in range(6):
        angle = math.radians(i * 60 + 30)
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    pts.append(pts[0])
    draw.line(pts, fill=color, width=width)


def draw_hex_filled(draw, cx, cy, r, color):
    """Draw filled flat-top hexagon."""
    pts = []
    for i in range(6):
        angle = math.radians(i * 60 + 30)
        pts.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(pts, fill=color)


# ══════════════════════════════════════════════════════════════
#  1. health_ring.png  300×300
#     — metallic outer ring frame with pink glow
# ══════════════════════════════════════════════════════════════
def make_health_ring():
    W, H = 300, 300
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cx, cy = W//2, H//2
    R_outer = 142   # outer edge of ring
    R_inner = 110   # inner edge (interior is transparent)
    R_mid   = (R_outer + R_inner) // 2

    # --- Layer 1: mega pink glow (wide, very soft) ---
    glow1 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d1 = ImageDraw.Draw(glow1)
    for i in range(25, 0, -1):
        a = int(12 * i / 25)
        d1.ellipse([cx - R_outer - i*2, cy - R_outer - i*2,
                    cx + R_outer + i*2, cy + R_outer + i*2],
                   outline=(*C_PINK, a), width=2)
    glow1 = glow1.filter(ImageFilter.GaussianBlur(radius=8))
    img = Image.alpha_composite(img, glow1)

    # --- Layer 2: medium pink glow (tight) ---
    glow2 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(glow2)
    for i in range(12, 0, -1):
        a = int(40 * i / 12)
        d2.ellipse([cx - R_outer - i, cy - R_outer - i,
                    cx + R_outer + i, cy + R_outer + i],
                   outline=(*C_PINK, a), width=3)
    glow2 = glow2.filter(ImageFilter.GaussianBlur(radius=4))
    img = Image.alpha_composite(img, glow2)

    # --- Layer 3: metallic ring body ---
    ring = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d3 = ImageDraw.Draw(ring)
    # Dark metallic fill between R_inner and R_outer
    # Draw as thick annulus using concentric ellipses
    for r in range(R_inner, R_outer + 1):
        # Gradient: darker inside, lighter at outer edge
        t = (r - R_inner) / (R_outer - R_inner)
        rr = int(C_METAL[0] + (C_METAL2[0] - C_METAL[0]) * t)
        gg = int(C_METAL[1] + (C_METAL2[1] - C_METAL[1]) * t)
        bb = int(C_METAL[2] + (C_METAL2[2] - C_METAL[2]) * t)
        a  = 230
        d3.ellipse([cx - r, cy - r, cx + r, cy + r],
                   outline=(rr, gg, bb, a), width=1)
    img = Image.alpha_composite(img, ring)

    # --- Layer 4: pink inner edge highlight ---
    edge = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d4 = ImageDraw.Draw(edge)
    d4.ellipse([cx - R_inner - 1, cy - R_inner - 1,
                cx + R_inner + 1, cy + R_inner + 1],
               outline=(*C_PINK2, 180), width=2)
    d4.ellipse([cx - R_outer,     cy - R_outer,
                cx + R_outer,     cy + R_outer],
               outline=(*C_PINK, 220), width=2)
    img = Image.alpha_composite(img, edge)

    # --- Layer 5: sharp inner glow rim ---
    rim = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(rim)
    dr.ellipse([cx - R_inner + 1, cy - R_inner + 1,
                cx + R_inner - 1, cy + R_inner - 1],
               outline=(*C_PINK, 60), width=3)
    rim = rim.filter(ImageFilter.GaussianBlur(radius=2))
    img = Image.alpha_composite(img, rim)

    # --- Notch marks at 10° intervals on ring ---
    notch = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dn = ImageDraw.Draw(notch)
    for deg in range(0, 360, 10):
        angle = math.radians(deg)
        # Inner notch line
        x1 = cx + (R_inner + 2) * math.cos(angle)
        y1 = cy + (R_inner + 2) * math.sin(angle)
        if deg % 30 == 0:
            x2 = cx + (R_inner + 14) * math.cos(angle)
            y2 = cy + (R_inner + 14) * math.sin(angle)
            dn.line([(x1, y1), (x2, y2)], fill=(*C_PINK, 180), width=2)
        else:
            x2 = cx + (R_inner + 7) * math.cos(angle)
            y2 = cy + (R_inner + 7) * math.sin(angle)
            dn.line([(x1, y1), (x2, y2)], fill=(*C_PINK2, 100), width=1)
    img = Image.alpha_composite(img, notch)

    path = os.path.join(OUT, 'health_ring.png')
    img.save(path)
    print(f'  saved {path}')


# ══════════════════════════════════════════════════════════════
#  2. ammo_ring.png  240×240
#     — cyan version, slightly smaller
# ══════════════════════════════════════════════════════════════
def make_ammo_ring():
    W, H = 240, 240
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cx, cy = W//2, H//2
    R_outer = 114
    R_inner = 88

    # Mega cyan glow
    glow1 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d1 = ImageDraw.Draw(glow1)
    for i in range(20, 0, -1):
        a = int(12 * i / 20)
        d1.ellipse([cx - R_outer - i*2, cy - R_outer - i*2,
                    cx + R_outer + i*2, cy + R_outer + i*2],
                   outline=(*C_CYAN, a), width=2)
    glow1 = glow1.filter(ImageFilter.GaussianBlur(radius=7))
    img = Image.alpha_composite(img, glow1)

    # Medium glow
    glow2 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(glow2)
    for i in range(10, 0, -1):
        a = int(45 * i / 10)
        d2.ellipse([cx - R_outer - i, cy - R_outer - i,
                    cx + R_outer + i, cy + R_outer + i],
                   outline=(*C_CYAN, a), width=3)
    glow2 = glow2.filter(ImageFilter.GaussianBlur(radius=3))
    img = Image.alpha_composite(img, glow2)

    # Metallic ring body
    ring = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d3 = ImageDraw.Draw(ring)
    for r in range(R_inner, R_outer + 1):
        t = (r - R_inner) / (R_outer - R_inner)
        # Cyan-tinted metal gradient
        rr = int(C_METAL[0] * (1-t) + 15 * t)
        gg = int(C_METAL[1] * (1-t) + 25 * t)
        bb = int(C_METAL[2] * (1-t) + 50 * t)
        d3.ellipse([cx - r, cy - r, cx + r, cy + r],
                   outline=(rr, gg, bb, 225), width=1)
    img = Image.alpha_composite(img, ring)

    # Cyan edges
    edge = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d4 = ImageDraw.Draw(edge)
    d4.ellipse([cx - R_inner - 1, cy - R_inner - 1,
                cx + R_inner + 1, cy + R_inner + 1],
               outline=(*C_CYAN2, 180), width=2)
    d4.ellipse([cx - R_outer,     cy - R_outer,
                cx + R_outer,     cy + R_outer],
               outline=(*C_CYAN, 220), width=2)
    img = Image.alpha_composite(img, edge)

    # Notches
    notch = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dn = ImageDraw.Draw(notch)
    for deg in range(0, 360, 12):
        angle = math.radians(deg)
        x1 = cx + (R_inner + 2) * math.cos(angle)
        y1 = cy + (R_inner + 2) * math.sin(angle)
        if deg % 36 == 0:
            x2 = cx + (R_inner + 12) * math.cos(angle)
            y2 = cy + (R_inner + 12) * math.sin(angle)
            dn.line([(x1, y1), (x2, y2)], fill=(*C_CYAN, 180), width=2)
        else:
            x2 = cx + (R_inner + 6) * math.cos(angle)
            y2 = cy + (R_inner + 6) * math.sin(angle)
            dn.line([(x1, y1), (x2, y2)], fill=(*C_CYAN2, 90), width=1)
    img = Image.alpha_composite(img, notch)

    path = os.path.join(OUT, 'ammo_ring.png')
    img.save(path)
    print(f'  saved {path}')


# ══════════════════════════════════════════════════════════════
#  3. panel_bg.png  1200×280
#     — dark metallic panel with angular corners and metal texture
# ══════════════════════════════════════════════════════════════
def make_panel_bg():
    W, H = 1200, 280
    ANG  = 28   # corner cut pixels

    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)

    # Main polygon with angled corners
    pts = [
        (ANG,   0),
        (W-ANG, 0),
        (W,     ANG),
        (W,     H-ANG),
        (W-ANG, H),
        (ANG,   H),
        (0,     H-ANG),
        (0,     ANG),
    ]
    # Fill with dark gradient
    d.polygon(pts, fill=(8, 0, 22, 245))

    # Subtle top-to-bottom gradient (lighter at top edge)
    grad = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dg = ImageDraw.Draw(grad)
    for y in range(H):
        t   = y / H
        a   = int(18 * (1 - t))   # brighter near top
        dg.line([(0, y), (W, y)], fill=(80, 40, 120, a))
    # Clip to polygon shape
    mask = Image.new('L', (W, H), 0)
    dm = ImageDraw.Draw(mask)
    dm.polygon(pts, fill=255)
    grad.putalpha(mask)
    img = Image.alpha_composite(img, grad)

    # Subtle horizontal scanlines (very faint)
    scan = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ds  = ImageDraw.Draw(scan)
    for y in range(0, H, 4):
        ds.line([(ANG if y < ANG else 0, y), (W - ANG if y < ANG else W, y)],
                fill=(20, 10, 40, 8))
    scan.putalpha(mask)
    img = Image.alpha_composite(img, scan)

    # Left section darker bg (behind health circle)
    left_bg = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dl = ImageDraw.Draw(left_bg)
    dl.ellipse([10, 10, 320, 270], fill=(14, 0, 35, 180))
    img = Image.alpha_composite(img, left_bg)

    # Right section darker bg (behind ammo + weapon)
    right_bg = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(right_bg)
    dr.rectangle([850, 10, W-10, H-10], fill=(5, 0, 14, 120))
    img = Image.alpha_composite(img, right_bg)

    # --- BORDER GLOW ---
    border_glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dbg = ImageDraw.Draw(border_glow)
    # Pink border (left half top + left edge)
    for thickness in range(8, 0, -1):
        a = int(70 * thickness / 8)
        # top-left (pink)
        dbg.line([(ANG, 0), (W//2, 0)], fill=(*C_PINK, a), width=thickness)
        dbg.line([(0, ANG), (0, H-ANG)], fill=(*C_PINK, a), width=thickness)
        dbg.line([(0, ANG), (ANG, 0)], fill=(*C_PINK, a), width=thickness)
        # top-right (cyan)
        dbg.line([(W//2, 0), (W-ANG, 0)], fill=(*C_CYAN, a), width=thickness)
        dbg.line([(W, ANG), (W, H-ANG)], fill=(*C_CYAN, a), width=thickness)
        dbg.line([(W-ANG, 0), (W, ANG)], fill=(*C_CYAN, a), width=thickness)
        # bottom mixed
        dbg.line([(ANG, H), (W//2, H)], fill=(*C_PINK, a//2), width=thickness)
        dbg.line([(W//2, H), (W-ANG, H)], fill=(*C_CYAN, a//2), width=thickness)
    border_glow = border_glow.filter(ImageFilter.GaussianBlur(radius=4))
    img = Image.alpha_composite(img, border_glow)

    # Solid thin border on top
    border_solid = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dbs = ImageDraw.Draw(border_solid)
    dbs.line([(ANG, 0), (W//2, 0)], fill=(*C_PINK2, 220), width=2)
    dbs.line([(W//2, 0), (W-ANG, 0)], fill=(*C_CYAN2, 220), width=2)
    dbs.line([(0, ANG), (ANG, 0)], fill=(*C_PINK, 255), width=2)
    dbs.line([(W-ANG, 0), (W, ANG)], fill=(*C_CYAN, 255), width=2)
    dbs.line([(0, ANG), (0, H-ANG)], fill=(*C_PINK2, 200), width=2)
    dbs.line([(W, ANG), (W, H-ANG)], fill=(*C_CYAN2, 200), width=2)
    dbs.line([(ANG, H), (W-ANG, H)], fill=(50, 60, 80, 180), width=2)
    img = Image.alpha_composite(img, border_solid)

    # Internal vertical separator lines
    sep = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dsep = ImageDraw.Draw(sep)
    # Left separator (pink)
    for i in range(4, 0, -1):
        a = int(60 * i / 4)
        dsep.line([(340, 10), (340, H-10)], fill=(*C_PINK, a), width=i*2)
    dsep.line([(340, 10), (340, H-10)], fill=(*C_PINK2, 200), width=2)
    # Right separator (cyan)
    for i in range(4, 0, -1):
        a = int(60 * i / 4)
        dsep.line([(860, 10), (860, H-10)], fill=(*C_CYAN, a), width=i*2)
    dsep.line([(860, 10), (860, H-10)], fill=(*C_CYAN2, 200), width=2)
    img = Image.alpha_composite(img, sep)

    # Top center accent bar
    accent = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    da = ImageDraw.Draw(accent)
    da.rectangle([W//2-55, 0, W//2+55, 5], fill=(*C_CYAN2, 220))
    for i in range(6, 0, -1):
        a = int(80 * i / 6)
        da.rectangle([W//2-55-i, -i, W//2+55+i, 5+i], fill=(*C_CYAN, a))
    accent = accent.filter(ImageFilter.GaussianBlur(radius=2))
    img = Image.alpha_composite(img, accent)

    path = os.path.join(OUT, 'panel_bg.png')
    img.save(path)
    print(f'  saved {path}')


# ══════════════════════════════════════════════════════════════
#  4. slot_hex.png  90×90  normal hex slot
#  5. slot_hex_active.png  90×90  glowing active hex slot
# ══════════════════════════════════════════════════════════════
def make_hex_slots():
    W, H = 90, 90
    cx, cy = W//2, H//2
    R = 40

    # ── Normal slot ──
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))

    # Dark fill
    fill = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    df = ImageDraw.Draw(fill)
    draw_hex_filled(df, cx, cy, R-1, (6, 0, 14, 220))
    img = Image.alpha_composite(img, fill)

    # Dim outer border
    border = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    db = ImageDraw.Draw(border)
    draw_hex_outline(db, cx, cy, R,   (60, 80, 110, 200), width=2)
    draw_hex_outline(db, cx, cy, R-6, (30, 20, 50,  120), width=1)
    img = Image.alpha_composite(img, border)

    path = os.path.join(OUT, 'slot_hex.png')
    img.save(path)
    print(f'  saved {path}')

    # ── Active slot ──
    img2 = Image.new('RGBA', (W, H), (0, 0, 0, 0))

    # Glow halo (wide)
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dg = ImageDraw.Draw(glow)
    for i in range(14, 0, -1):
        a = int(55 * i / 14)
        draw_hex_outline(dg, cx, cy, R + i*2, (*C_CYAN, a), width=3)
    glow = glow.filter(ImageFilter.GaussianBlur(radius=5))
    img2 = Image.alpha_composite(img2, glow)

    # Bright fill
    fill2 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    df2 = ImageDraw.Draw(fill2)
    draw_hex_filled(df2, cx, cy, R-1, (18, 0, 40, 235))
    img2 = Image.alpha_composite(img2, fill2)

    # Cyan glow fill (very subtle)
    inner_glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dig = ImageDraw.Draw(inner_glow)
    draw_hex_filled(dig, cx, cy, R-2, (*C_CYAN, 18))
    img2 = Image.alpha_composite(img2, inner_glow)

    # Bright cyan borders
    bdr2 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    db2  = ImageDraw.Draw(bdr2)
    draw_hex_outline(db2, cx, cy, R,   (*C_CYAN, 240), width=3)
    draw_hex_outline(db2, cx, cy, R-6, (*C_CYAN2, 120), width=1)
    img2 = Image.alpha_composite(img2, bdr2)

    # Inner border glow
    inner_rim = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dir2 = ImageDraw.Draw(inner_rim)
    draw_hex_outline(dir2, cx, cy, R-1, (*C_CYAN, 120), width=4)
    inner_rim = inner_rim.filter(ImageFilter.GaussianBlur(radius=2))
    img2 = Image.alpha_composite(img2, inner_rim)

    path2 = os.path.join(OUT, 'slot_hex_active.png')
    img2.save(path2)
    print(f'  saved {path2}')


# ══════════════════════════════════════════════════════════════
#  6. weapon_panel.png  200×290
#     — dark panel for the weapon image, cyan glowing border
# ══════════════════════════════════════════════════════════════
def make_weapon_panel():
    W, H = 200, 290

    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)

    # Dark fill
    d.rectangle([0, 0, W, H], fill=(1, 8, 16, 240))

    # Subtle cyan tint fill
    tint = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dt  = ImageDraw.Draw(tint)
    for y in range(H):
        t = y / H
        a = int(12 * (1 - t * 0.5))
        dt.line([(0, y), (W, y)], fill=(0, 30, 50, a))
    img = Image.alpha_composite(img, tint)

    # Scanlines
    scan = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ds  = ImageDraw.Draw(scan)
    for y in range(0, H, 5):
        ds.line([(2, y), (W-2, y)], fill=(0, 30, 45, 7))
    img = Image.alpha_composite(img, scan)

    # Cyan border glow
    bglow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dbg  = ImageDraw.Draw(bglow)
    for i in range(10, 0, -1):
        a = int(65 * i / 10)
        dbg.rectangle([i, i, W-i, H-i], outline=(*C_CYAN, a))
    bglow = bglow.filter(ImageFilter.GaussianBlur(radius=3))
    img = Image.alpha_composite(img, bglow)

    # Solid border
    bsolid = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dbs   = ImageDraw.Draw(bsolid)
    dbs.rectangle([0, 0, W-1, H-1], outline=(*C_CYAN2, 200), width=2)
    dbs.rectangle([1, 1, W-2, H-2], outline=(0, 40, 60, 160), width=1)
    img = Image.alpha_composite(img, bsolid)

    # Corner L-shape ticks
    ticks = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dt2  = ImageDraw.Draw(ticks)
    L = 22
    for cx2, cy2, dx, dy in [(0, 0, 1, 1), (W-1, 0, -1, 1),
                               (0, H-1, 1, -1), (W-1, H-1, -1, -1)]:
        dt2.line([(cx2, cy2), (cx2 + dx*L, cy2)], fill=(*C_CYAN, 240), width=2)
        dt2.line([(cx2, cy2), (cx2, cy2 + dy*L)], fill=(*C_CYAN, 240), width=2)
        # Glow on ticks
        for gi in range(4, 0, -1):
            a = gi * 15
            dt2.line([(cx2-gi*dx, cy2), (cx2 + dx*(L+gi), cy2)],
                     fill=(*C_CYAN, a), width=1)
    img = Image.alpha_composite(img, ticks)

    path = os.path.join(OUT, 'weapon_panel.png')
    img.save(path)
    print(f'  saved {path}')


# ══════════════════════════════════════════════════════════════
#  7. objective_panel.png  500×110
#     — pink-bordered box for the objective text
# ══════════════════════════════════════════════════════════════
def make_objective_panel():
    W, H = 500, 110

    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)
    d.rectangle([0, 0, W-1, H-1], fill=(4, 0, 18, 235))

    # Pink border glow
    bglow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dbg  = ImageDraw.Draw(bglow)
    for i in range(8, 0, -1):
        a = int(70 * i / 8)
        dbg.rectangle([i, i, W-i, H-i], outline=(*C_PINK, a))
    bglow = bglow.filter(ImageFilter.GaussianBlur(radius=3))
    img = Image.alpha_composite(img, bglow)

    # Solid border
    bs = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dbs = ImageDraw.Draw(bs)
    dbs.rectangle([0, 0, W-1, H-1], outline=(*C_PINK2, 220), width=2)
    dbs.rectangle([1, 1, W-2, H-2], outline=(50, 0, 40, 120), width=1)
    img = Image.alpha_composite(img, bs)

    # Pink corner decorations
    ticks = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dt = ImageDraw.Draw(ticks)
    L = 18
    for cx2, cy2, dx, dy in [(0, 0, 1, 1), (W-1, 0, -1, 1),
                               (0, H-1, 1, -1), (W-1, H-1, -1, -1)]:
        dt.line([(cx2, cy2), (cx2 + dx*L, cy2)], fill=(*C_PINK, 255), width=2)
        dt.line([(cx2, cy2), (cx2, cy2 + dy*L)], fill=(*C_PINK, 255), width=2)
    img = Image.alpha_composite(img, ticks)

    path = os.path.join(OUT, 'objective_panel.png')
    img.save(path)
    print(f'  saved {path}')


# ══════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════
if __name__ == '__main__':
    print('Generating cyberpunk HUD sprites...')
    make_health_ring()
    make_ammo_ring()
    make_panel_bg()
    make_hex_slots()
    make_weapon_panel()
    make_objective_panel()
    print('Done.')
