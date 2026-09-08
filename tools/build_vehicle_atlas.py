"""Generates assets/vehicles/vehicle_atlas.png - the shared stylized vehicle
texture atlas (4x4 grid of 64px tiles).

Tiles (col,row):
  (0,0) cart paint   (1,0) cart worn   (2,0) truck paint  (3,0) truck worn
  (0,1) race paint   (1,1) race worn   (2,1) dark paint   (3,1) cream panel
  (0,2) brushed metal(1,2) brass       (2,2) rubber tread (3,2) glass
  (0,3) grime        (1,3) headlight lens (2,3) hubcap     (3,3) hazard stripe

Deterministic (random.Random(5)); rerunning produces a byte-identical file.
Origin: original hand-drawn pixel noise, no external assets.
"""
import random
import struct
import zlib
from pathlib import Path

SIZE = 256
TILE = 64
GRID = 4


def clamp(v, lo=0, hi=255):
    return int(max(lo, min(hi, v)))


def shade(rgb, factor):
    return tuple(clamp(c * factor) for c in rgb)


def paint_tile(px, ox, oy, base, rng, worn=False):
    """Solid paint with soft vertical value gradient, speckle, darker edges;
    the worn variant adds primer scratches and chipped edges."""
    for y in range(TILE):
        for x in range(TILE):
            t = y / (TILE - 1)
            # subtle top-light gradient + per-pixel speckle
            v = 1.04 - 0.16 * t + rng.uniform(-0.05, 0.05)
            # darker rounded edge frame
            edge = min(x, y, TILE - 1 - x, TILE - 1 - y)
            if edge < 2:
                v *= 0.78 + 0.07 * edge
            # a couple of horizontal panel lines
            if y in (21, 22, 43):
                v *= 0.88
            c = shade(base, v)
            if worn:
                # primer scratches: short horizontal runs of grey
                if rng.random() < 0.045:
                    run = rng.randint(3, 9)
                    sx = rng.randint(0, TILE - run)
                    primer = shade(base, 0.45)
                    for i in range(run):
                        px[oy + y][ox + sx + i] = primer
                # chipped corner showing primer
                if (x < 4 and y < 4 and rng.random() < 0.4):
                    px[oy + y][ox + x] = shade(base, 0.5)
            px[oy + y][ox + x] = c


def fill_tile(px, ox, oy, color, rng, noise=0.04):
    for y in range(TILE):
        for x in range(TILE):
            v = 1.0 + rng.uniform(-noise, noise)
            px[oy + y][ox + x] = shade(color, v)


def metal_tile(px, ox, oy, base, rng):
    for y in range(TILE):
        for x in range(TILE):
            # brushed streaks along x
            v = 0.92 + 0.12 * ((x * 7 + y * 3) % 5 == 0) + rng.uniform(-0.05, 0.05)
            if y in (0, TILE - 1):
                v *= 0.7
            px[oy + y][ox + x] = shade(base, v)
    # two rows of rivets
    for ry in (10, TILE - 11):
        for rx in range(8, TILE, 12):
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    x, y = rx + dx, ry + dy
                    if 0 <= x < TILE and 0 <= y < TILE:
                        px[oy + y][ox + x] = shade(base, 0.55 if (dx or dy) else 1.25)


def brass_tile(px, ox, oy, base, rng):
    for y in range(TILE):
        for x in range(TILE):
            band = 1.0 + 0.14 * ((x + y * 2) % 6 < 2) + rng.uniform(-0.04, 0.04)
            if y < 2 or y > TILE - 3:
                band *= 0.72
            px[oy + y][ox + x] = shade(base, band)


def rubber_tile(px, ox, oy, base, rng):
    for y in range(TILE):
        for x in range(TILE):
            v = 0.95 + rng.uniform(-0.06, 0.06)
            # vertical tread grooves
            if x % 8 in (0, 1):
                v *= 0.55
            if y < 3 or y > TILE - 4:
                v *= 0.6
            px[oy + y][ox + x] = shade(base, v)


def glass_tile(px, ox, oy, base, rng):
    for y in range(TILE):
        for x in range(TILE):
            # vertical cool gradient + diagonal highlight streak
            t = y / (TILE - 1)
            v = 1.15 - 0.5 * t
            if abs((x + y) - 52) < 5 or abs((x + y) - 70) < 3:
                v += 0.35
            if y in (0, TILE - 1):
                v *= 0.6
            px[oy + y][ox + x] = shade(base, v + rng.uniform(-0.03, 0.03))


def grime_tile(px, ox, oy, base, rng):
    for y in range(TILE):
        for x in range(TILE):
            v = 0.9 + rng.uniform(-0.12, 0.12)
            # heavier spatter toward the bottom (where mud lands)
            if y > TILE * 0.45 and rng.random() < (y / TILE) * 0.5:
                v *= rng.uniform(0.45, 0.75)
            px[oy + y][ox + x] = shade(base, v)


def lens_tile(px, ox, oy, base, rng):
    cx = cy = TILE / 2
    for y in range(TILE):
        for x in range(TILE):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / (TILE / 2)
            v = 1.25 - 0.45 * d
            if d > 0.92:
                v *= 0.5  # dark rim
            px[oy + y][ox + x] = shade(base, v + rng.uniform(-0.03, 0.03))


def hub_tile(px, ox, oy, base, rng):
    cx = cy = TILE / 2
    for y in range(TILE):
        for x in range(TILE):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / (TILE / 2)
            v = 1.1 - 0.25 * d + rng.uniform(-0.04, 0.04)
            if 0.45 < d < 0.6:
                v *= 0.7  # lug ring
            if d > 0.94:
                v *= 0.55
            px[oy + y][ox + x] = shade(base, v)


def hazard_tile(px, ox, oy, yellow, ink, rng):
    for y in range(TILE):
        for x in range(TILE):
            c = yellow if ((x + y) // 8) % 2 == 0 else ink
            px[oy + y][ox + x] = shade(c, 1.0 + rng.uniform(-0.05, 0.05))


def write_png(path, px):
    raw = b"".join(b"\x00" + bytes(v for pixel in row for v in pixel) for row in px)

    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        return out + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    body = chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + body)


def main():
    rng = random.Random(5)
    px = [[(0, 0, 0)] * SIZE for _ in range(SIZE)]

    def at(col, row):
        return col * TILE, row * TILE

    cart, truck, race = (126, 168, 88), (232, 178, 58), (214, 76, 74)
    ink, cream, metal = (29, 21, 38), (243, 233, 208), (158, 162, 170)
    brass, glassy, mud = (212, 165, 74), (172, 208, 222), (94, 72, 50)

    paint_tile(px, *at(0, 0), cart, rng)
    paint_tile(px, *at(1, 0), cart, rng, worn=True)
    paint_tile(px, *at(2, 0), truck, rng)
    paint_tile(px, *at(3, 0), truck, rng, worn=True)
    paint_tile(px, *at(0, 1), race, rng)
    paint_tile(px, *at(1, 1), race, rng, worn=True)
    paint_tile(px, *at(2, 1), ink, rng, worn=False)
    fill_tile(px, *at(3, 1), cream, rng)
    metal_tile(px, *at(0, 2), metal, rng)
    brass_tile(px, *at(1, 2), brass, rng)
    rubber_tile(px, *at(2, 2), (24, 22, 26), rng)
    glass_tile(px, *at(3, 2), glassy, rng)
    grime_tile(px, *at(0, 3), mud, rng)
    lens_tile(px, *at(1, 3), (255, 236, 170), rng)
    hub_tile(px, *at(2, 3), (190, 196, 204), rng)
    hazard_tile(px, *at(3, 3), (250, 204, 61), (30, 26, 22), rng)

    out = Path("assets/vehicles/vehicle_atlas.png")
    out.parent.mkdir(parents=True, exist_ok=True)
    write_png(out, px)
    print("wrote", out, out.stat().st_size, "bytes")


if __name__ == "__main__":
    main()