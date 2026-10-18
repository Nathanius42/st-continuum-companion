"""Decode Starfleet Command II's sprites.q3 (Taldren "MDM!" sprite archive) into PNGs.

Worked out from the file itself (no published format):
  record  = u16 width, u16 height, u16 hotspot x, u16 hotspot y, u16 0, u16 16 (bits per pixel),
            u16 0x00FF, u16 2, u32 data length, data
  data    = height x u32 row offsets (in 16-bit words from the start of the token stream),
            then a token stream per row:
              0xC000 | n   skip n transparent pixels
              0x4000 | n   repeat the next pixel n times
              n            n literal pixels follow
  pixels  = 16-bit colour (565 or 555, chosen with --555)

Usage: python q3sprites.py <sprites.q3> <out dir> [--555] [--limit N]
"""
import re
import struct
import sys
from pathlib import Path

from PIL import Image

MARKER = bytes.fromhex("1000ff000200")


def colour(v, five55):
    if five55:
        r, g, b = (v >> 10) & 31, (v >> 5) & 31, v & 31
        return (r * 255 // 31, g * 255 // 31, b * 255 // 31, 255)
    r, g, b = (v >> 11) & 31, (v >> 5) & 63, v & 31
    return (r * 255 // 31, g * 255 // 63, b * 255 // 31, 255)


def decode(buf, start, w, h, length, five55):
    rows = struct.unpack_from(f"<{h}I", buf, start)
    stream = start + 4 * h
    end = start + length
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y, off in enumerate(rows):
        i, x = stream + 2 * off, 0
        while x < w and i + 2 <= end:
            t = struct.unpack_from("<H", buf, i)[0]
            i += 2
            kind, n = t & 0xC000, t & 0x3FFF
            if kind == 0xC000:
                x += n
            elif kind == 0x4000:
                c = colour(struct.unpack_from("<H", buf, i)[0], five55)
                i += 2
                for _ in range(n):
                    if x < w:
                        px[x, y] = c
                    x += 1
            elif n == 0:
                break
            else:
                for _ in range(n):
                    if x < w and i + 2 <= end:
                        px[x, y] = colour(struct.unpack_from("<H", buf, i)[0], five55)
                    i += 2
                    x += 1
    return img


def records(buf):
    for m in re.finditer(re.escape(MARKER), buf):
        p = m.start()
        w, h, hx, hy = struct.unpack_from("<4H", buf, p - 10)
        length = struct.unpack_from("<I", buf, p + 6)[0]
        if 0 < w <= 2048 and 0 < h <= 2048 and 4 * h <= length:
            yield p - 10, w, h, p + 10, length


def main():
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    five55 = "--555" in sys.argv
    limit = int(sys.argv[sys.argv.index("--limit") + 1]) if "--limit" in sys.argv else None
    buf = src.read_bytes()
    out.mkdir(parents=True, exist_ok=True)
    n = bad = 0
    for k, (rec, w, h, data, length) in enumerate(records(buf)):
        if limit and n >= limit:
            break
        try:
            img = decode(buf, data, w, h, length, five55)
        except Exception:
            bad += 1
            continue
        img.save(out / f"{k:05d}_{w}x{h}.png")
        n += 1
    print(f"{n} sprites written to {out}, {bad} failed")


if __name__ == "__main__":
    main()
