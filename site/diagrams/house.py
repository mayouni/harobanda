"""The house style of the Harobanda site diagrams, in code.

The palette and the primitives here were read off diagrams 1, 2 and 3 --
which were authored by hand -- so a drawn diagram sits beside them without
announcing that it was generated. `site/DIAGRAMS.md` is the register and
holds the brief each composition answers.

Everything is written in LOGICAL pixels on a 1376 x 768 canvas. Drawing
happens at S times that and is downsampled on save, because PIL does not
anti-alias lines or polygons -- supersampling is what keeps an edge clean.
"""
import math, random, pathlib
from PIL import Image, ImageDraw, ImageFont

W, H = 1376, 768
S = 3
FONTS = pathlib.Path(__file__).resolve().parent / "fonts"
OUT = pathlib.Path(__file__).resolve().parent.parent

# ---- palette -------------------------------------------------------------
BG        = (245, 239, 225)   # the diagram's own ground, warmer than the page
INK       = (40, 51, 71)
MUTED     = (122, 118, 107)
OLD_FILL  = (228, 223, 211)   # what an ordinary system carries
OLD_LINE  = (203, 195, 180)
OLD_TEXT  = (103, 103, 108)
NEW_FILL  = (180, 191, 193)   # the machine is always the emphasised box
NEW_LINE  = (78, 97, 108)
NEW_TEXT  = (32, 45, 58)
NEW_SUB   = (66, 86, 98)
ORANGE    = (240, 157, 123)   # used ONCE per diagram, on what matters most
BRICK     = (169, 85, 42)     # refusal only: a crossed path, a NOT KEPT
KERN_FILL = (231, 226, 214)
KERN_LINE = (198, 191, 176)
HAIR      = (213, 205, 189)


def sans(sz, w="Regular"):
    return ImageFont.truetype(str(FONTS / ("IBMPlexSans-%s.woff" % w)), int(sz * S))


def mono(sz, w="Regular"):
    return ImageFont.truetype(str(FONTS / ("IBMPlexMono-%s.woff" % w)), int(sz * S))


def canvas(seed):
    """A seeded canvas: the wobble is random, but the diagram is reproducible."""
    random.seed(seed)
    img = Image.new("RGB", (W * S, H * S), BG)
    return img, ImageDraw.Draw(img)


def save(img, name, quality=93):
    p = OUT / name
    img.resize((W, H), Image.LANCZOS).save(p, "JPEG", quality=quality, subsampling=0)
    return p


# ---- shapes --------------------------------------------------------------
def rr_path(x0, y0, x1, y1, r, steps=10):
    """A rounded rectangle as a point list, in DEVICE units."""
    pts = []
    for cx, cy, a0 in ((x1-r, y0+r, -90), (x1-r, y1-r, 0), (x0+r, y1-r, 90), (x0+r, y0+r, 180)):
        for i in range(steps + 1):
            a = math.radians(a0 + 90 * i / steps)
            pts.append((cx + r*math.cos(a), cy + r*math.sin(a)))
    return pts


def wobble(pts, amp=1.1):
    """Offset along the path normal at low frequency: a drawn line, not a jagged one."""
    f1, p1 = 1.6, random.uniform(0, 6.283)
    f2, p2 = 3.4, random.uniform(0, 6.283)
    n, out = len(pts), []
    for i, (x, y) in enumerate(pts):
        t = i / n
        d = amp * S * (math.sin(2*math.pi*f1*t + p1) + 0.55*math.sin(2*math.pi*f2*t + p2))
        px, py = pts[(i+1) % n]
        qx, qy = pts[(i-1) % n]
        tx, ty = px-qx, py-qy
        L = math.hypot(tx, ty) or 1
        out.append((x - ty/L*d, y + tx/L*d))
    return out


def band(d, x, y, w, h, r, fill, line, lw=2.0, amp=1.1):
    """A filled rounded rectangle with a hand-drawn outline. Logical units."""
    base = rr_path(x*S, y*S, (x+w)*S, (y+h)*S, r*S)
    d.polygon(base, fill=fill)
    o = wobble(base, amp)
    d.line(o + [o[0]], fill=line, width=int(lw*S), joint="curve")


def dashed(d, pts, fill, width, dash=13, gapd=9):
    """Walk a closed DEVICE-unit path in dash/gap segments -- this family's mark for absence."""
    pts = pts + [pts[0]]
    on, left = True, dash*S
    for i in range(len(pts)-1):
        (x0, y0), (x1, y1) = pts[i], pts[i+1]
        seg = math.hypot(x1-x0, y1-y0)
        t = 0.0
        while t < seg:
            step = min(left, seg - t)
            if on:
                a = (x0 + (x1-x0)*t/seg,        y0 + (y1-y0)*t/seg)
                b = (x0 + (x1-x0)*(t+step)/seg, y0 + (y1-y0)*(t+step)/seg)
                d.line([a, b], fill=fill, width=width)
            t += step
            left -= step
            if left <= 0:
                on = not on
                left = (dash if on else gapd) * S


def rule(d, x0, y0, x1, y1, fill=HAIR, lw=1.6):
    d.line([(x0*S, y0*S), (x1*S, y1*S)], fill=fill, width=int(lw*S))


# ---- text ----------------------------------------------------------------
# No small text to signal lesser importance: a secondary label is monospace
# and grey, never smaller than it can be read at.
def ls_w(font, t, ls):
    return sum(font.getlength(c) for c in t) + ls*S*(len(t)-1) if t else 0


def ls_text(d, x, y, t, font, fill, ls, anchor="ls"):
    """Letterspaced text, DEVICE units, drawn a character at a time."""
    for c in t:
        d.text((x, y), c, font=font, fill=fill, anchor=anchor)
        x += font.getlength(c) + ls*S


def centre_ls(d, cx, y, t, font, fill, ls):
    ls_text(d, cx*S - ls_w(font, t, ls)/2, y*S, t, font, fill, ls)


def text(d, x, y, t, font, fill, anchor="lm"):
    """Plain text at a LOGICAL position."""
    d.text((x*S, y*S), t, font=font, fill=fill, anchor=anchor)
