"""Builds every Karmabook image from shapes, so the marks can be tweaked and
rebuilt instead of hand-edited.

Run from the repo root:  python3 Art/src/make_art.py [--banner]

Writes:
  Media/YinYang.tga        minimap button and addon list icon (128px)
  Media/Initial.tga        the K badge in the book's title, gold rim (128px)
  Media/Stamp.tga          faint swirl stamp on the empty right page (256px)
  Media/RibbonTail.tga     notched end of the bookmark ribbon, white, tinted in game
  Media/TabCorner.tga      rounded corner for the index tabs, white, tinted in game
  Media/TabArc.tga         one-pixel corner line for the tabs' edges and trim
  Art/icon-large.png       the swirl mark, 512px, for anywhere big
  Art/curseforge-logo.png  CurseForge project logo, 400px (uploaded by hand)
With --banner it also stamps the swirl mark onto the heart in
Art/description-banner.webp. That re-encodes the webp, so it's opt-in.

Needs Pillow. WoW wants TGA textures uncompressed, 32-bit, power-of-two sizes.
"""

import math
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

# Palette, taken from the CurseForge heart art
ORCHID = (233, 154, 208, 255)   # the heart
CREAM = (252, 240, 216, 255)    # "I Will Always" lettering
PLUM = (94, 16, 94, 255)        # outlines
PURPLE = (122, 52, 140, 255)    # the yin-yang on the heart, the icon's disc
GOLD = (168, 128, 48, 255)      # Theme.GOLD, the cover's trim
GOLD_LIGHT = (209, 168, 79, 255)
INK = (40, 22, 10, 255)
GLOW = (233, 120, 200, 255)

# Working canvas for the marks. The yin-yang's center, the inner radius of its
# ring, and its outer edge.
N = 1024
CX = CY = 509
RIN = 446
ROUT = 508
# The two dots sit where a yin-yang's dots always do: halfway out from the
# center, in the middle of each head
DOT_T, DOT_B = (CX, CY - 224), (CX, CY + 224)


def solid(color):
    return Image.new("RGBA", (N, N), color)


def disc(box, size=N):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse(box, fill=255)
    return mask


def dilate(mask, w):
    """Grows a mask by about w px with round corners."""
    return mask.filter(ImageFilter.GaussianBlur(w / 2)).point(lambda v: 255 if v > 6 else 0)


def smooth(mask, r):
    """Rounds off a mask's sharp corners."""
    return mask.filter(ImageFilter.GaussianBlur(r)).point(lambda v: 255 if v > 127 else 0)


def save_tga(img, path):
    img.convert("RGBA").save(path, compression=None)


def yin_yang(scale=4):
    """The yin-yang with no dots, drawn at 4x and scaled down for clean edges.
    Purple on the left with its head at the top, cream on the right."""
    n, c, ri = N * scale, CX * scale, RIN * scale
    h, ro = ri / 2, ROUT * scale
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([c - ro, c - ro, c + ro, c + ro], fill=PLUM)
    d.ellipse([c - ri, c - ri, c + ri, c + ri], fill=CREAM)
    d.pieslice([c - ri, c - ri, c + ri, c + ri], 90, 270, fill=PURPLE)
    d.ellipse([c - h, c - ri, c + h, c], fill=PURPLE)
    d.ellipse([c - h, c, c + h, c + ri], fill=CREAM)
    return im.resize((N, N), Image.LANCZOS)


def k_mark(background, cream_half, theta_deg=38, dot_r=70, w=26, stem_w=150, bar_w=138,
           top=212, top_dot=CREAM, bottom_dot=ORCHID):
    """Draws the K with its two dots over background.

    The K is built around the dots: its upright and its arm (and upright and
    leg) meet at the angle where each dot fits snugly in the crook, sharing
    one outline. Where the K crosses cream_half it's orchid, elsewhere cream,
    so the yin-yang's swirl runs through the letter.
    """
    t = math.radians(theta_deg)
    clear = dot_r + w                       # dot center to the K's fill edge
    dx, dy = DOT_T
    xs1 = dx - clear                        # upright's right edge touches the dot
    xs0 = xs1 - stem_w
    ya = dy + clear * (1 + math.sin(t)) / math.cos(t)   # where the arm meets the upright
    bottom = 2 * CY - top

    k = Image.new("L", (N, N), 0)
    kd = ImageDraw.Draw(k)
    kd.rectangle([xs0, top, xs1, bottom], fill=255)
    for sign in (-1, 1):                    # -1 arm (up-right), 1 leg (down-right)
        y0 = ya if sign < 0 else 2 * CY - ya
        ux, uy = math.cos(t), sign * math.sin(t)
        nx, ny = math.sin(t), -sign * math.cos(t)
        back = (xs1 - xs0 - 10) / math.cos(t)
        a = (xs1 - ux * back, y0 - uy * back)
        b = (xs1 + ux * 900, y0 + uy * 900)
        kd.polygon([a, b, (b[0] + nx * bar_w, b[1] + ny * bar_w),
                    (a[0] + nx * bar_w, a[1] + ny * bar_w)], fill=255)
    # Arm and leg end along a circle inside the ring; the upright keeps square ends
    clip = disc([CX - (RIN - w - 34), CY - (RIN - w - 34), CX + (RIN - w - 34), CY + (RIN - w - 34)])
    ImageDraw.Draw(clip).rectangle([0, top, xs1, bottom], fill=255)
    k = ImageChops.multiply(k, clip)
    left = Image.new("L", (N, N), 0)
    ImageDraw.Draw(left).rectangle([xs0, 0, N, N], fill=255)
    k = smooth(ImageChops.multiply(k, left), 4)

    dot_t = disc([DOT_T[0] - dot_r, DOT_T[1] - dot_r, DOT_T[0] + dot_r, DOT_T[1] + dot_r])
    dot_b = disc([DOT_B[0] - dot_r, DOT_B[1] - dot_r, DOT_B[0] + dot_r, DOT_B[1] + dot_r])
    outline = ImageChops.lighter(dilate(k, w), dilate(ImageChops.lighter(dot_t, dot_b), w))
    # Close the hairline gaps where a dot's outline meets the K's
    grown = outline.filter(ImageFilter.GaussianBlur(3)).point(lambda v: 255 if v > 30 else 0)
    closed = ImageChops.invert(ImageChops.invert(grown).filter(ImageFilter.GaussianBlur(3))
                               .point(lambda v: 255 if v > 30 else 0))
    outline = ImageChops.lighter(outline, closed)

    im = background.copy()
    im.paste(solid(PLUM), mask=outline)
    im.paste(solid(ORCHID), mask=ImageChops.multiply(k, cream_half))
    im.paste(solid(CREAM), mask=ImageChops.multiply(k, ImageChops.invert(cream_half)))
    im.paste(solid(top_dot), mask=dot_t)
    im.paste(solid(bottom_dot), mask=dot_b)
    return im


def swirl_mark():
    """The full mark: the K through the yin-yang. Used big (logo, stamp)."""
    base = yin_yang()
    inside = disc([CX - RIN, CY - RIN, CX + RIN, CY + RIN])
    cream_half = ImageChops.multiply(base.convert("L").point(lambda v: 255 if v > 180 else 0), inside)
    return k_mark(base, cream_half)


def small_mark():
    """The simple mark for tiny sizes: a cream K with orchid dots on a plain
    purple disc. No swirl, and the art's own ring is left off, since the
    minimap's gold border already gives it one."""
    no_cream = Image.new("L", (N, N), 0)
    k = k_mark(Image.new("RGBA", (N, N), (0, 0, 0, 0)), no_cream, w=36, dot_r=66, top_dot=ORCHID)
    # Center the K between its box and its visual weight, which sits left
    # because the upright is heavier than the arm's tip
    left, _, right, _ = k.getbbox()
    alpha = k.split()[3].resize((128, 128))
    px = alpha.load()
    total = sum_x = 0
    for y in range(128):
        for x in range(128):
            total += px[x, y]
            sum_x += px[x, y] * x
    mass_x = sum_x / total * N / 128
    shift = round(CX - (mass_x + (left + right) / 2) / 2)
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    ImageDraw.Draw(im).ellipse([CX - RIN - 60, CY - RIN - 60, CX + RIN + 60, CY + RIN + 60], fill=PURPLE)
    im.alpha_composite(ImageChops.offset(k, shift, 0))
    r = RIN - 4
    im = im.crop((CX - r, CY - r, CX + r, CY + r)).resize((N, N), Image.LANCZOS)
    im.putalpha(ImageChops.multiply(im.split()[3], disc([0, 0, N - 1, N - 1])))
    return im


def initial(mark):
    """The small mark in a gold rim, to stand in for the K of the book's title."""
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([0, 0, N - 1, N - 1], fill=INK)
    d.ellipse([22, 22, N - 23, N - 23], fill=GOLD)
    d.ellipse([40, 40, N - 41, N - 200], fill=GOLD_LIGHT)   # light on the upper rim
    d.ellipse([40, 60, N - 41, N - 41], fill=GOLD)
    d.ellipse([92, 92, N - 93, N - 93], fill=INK)
    im.alpha_composite(mark.resize((N - 208, N - 208), Image.LANCZOS), (104, 104))
    im.putalpha(ImageChops.multiply(im.split()[3], disc([0, 0, N - 1, N - 1])))
    return im


def stamp(mark):
    """The swirl mark in one plum ink, a little worn, like a rubber stamp.
    Ink is how far a pixel is from cream, so the light orchid still prints.
    The game sets how faint it is."""
    diff = ImageChops.difference(mark.convert("RGB"), Image.new("RGB", (N, N), CREAM[:3])).convert("L")
    ink = ImageChops.multiply(diff.point(lambda v: max(0, min(255, int((v - 8) * 2.2)))), mark.split()[3])
    rng = random.Random(7)
    noise = Image.frombytes("L", (N, N), rng.randbytes(N * N)).filter(ImageFilter.GaussianBlur(1.2))
    ink = ImageChops.multiply(ink, noise.point(lambda v: 255 if v > 55 else 150))
    im = solid(PLUM)
    im.putalpha(ink)
    return im.resize((256, 256), Image.LANCZOS)


def ribbon_tail(w=64, h=128):
    """The ribbon's notched end, white with darker edges so it looks rounded.
    Its plain top doubles as the ribbon's body."""
    shape = Image.new("L", (w, h), 0)
    ImageDraw.Draw(shape).polygon([(0, 0), (w, 0), (w, h), (w // 2, h - 40), (0, h)], fill=255)
    shape = shape.filter(ImageFilter.GaussianBlur(0.6))
    shade = Image.new("L", (w, 1))
    for x in range(w):
        f = abs(x - w / 2) / (w / 2)
        shade.putpixel((x, 0), int(255 * (1.0 - 0.45 * f * f)))
    shade = shade.resize((w, h))
    return Image.merge("RGBA", (shade, shade, shade, shape))


def quarter(inner, size=32, ss=8):
    """A quarter circle centered on the bottom-left, so placed at a tab's
    top-right it rounds that corner. inner > 0 makes it a ring."""
    n = size * ss
    mask = Image.new("L", (n, n), 0)
    px = mask.load()
    for y in range(n):
        for x in range(n):
            d = ((x + 0.5) ** 2 + (n - y - 0.5) ** 2) ** 0.5
            if inner * ss <= d <= n:
                px[x, y] = 255
    im = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    im.putalpha(mask.resize((size, size), Image.LANCZOS))
    return im


def curseforge_logo(mark):
    """The swirl mark with a soft pink glow on black, like the old heart logo."""
    m, d = 1600, 1180
    off = (m - d) // 2
    bg = Image.new("RGBA", (m, m), (0, 0, 0, 255))
    halo = disc([off, off, off + d, off + d], size=m)
    for blur, strength in ((140, 0.55), (60, 0.8)):
        glow = Image.new("RGBA", (m, m), GLOW)
        glow.putalpha(halo.filter(ImageFilter.GaussianBlur(blur)).point(lambda v: int(v * strength)))
        bg.alpha_composite(glow)
    logo = bg.resize((400, 400), Image.LANCZOS)
    size, at = round(d / 4), round(off / 4)
    logo.alpha_composite(mark.resize((size, size), Image.LANCZOS), (at, at))
    return logo.convert("RGB")


def stamp_banner(mark, path="Art/description-banner.webp"):
    """Puts the swirl mark on the heart, centered under its mouth where the
    old yin-yang sat. Slightly larger than the old badge so none of it shows."""
    banner = Image.open(path).convert("RGBA")
    cx, cy, r = 768, 562, 40
    scale = (r * 2) / (ROUT * 2)
    size = round(N * scale)
    small = mark.resize((size, size), Image.LANCZOS)
    banner.alpha_composite(small, (round(cx - CX * scale), round(cy - CY * scale)))
    banner.save(path, quality=95, method=6)


def main():
    swirl = swirl_mark()
    small = small_mark()

    save_tga(small.resize((128, 128), Image.LANCZOS), "Media/YinYang.tga")
    save_tga(initial(small).resize((128, 128), Image.LANCZOS), "Media/Initial.tga")
    save_tga(stamp(swirl), "Media/Stamp.tga")
    save_tga(ribbon_tail(), "Media/RibbonTail.tga")
    save_tga(quarter(0), "Media/TabCorner.tga")
    save_tga(quarter(32 - 32 / 6), "Media/TabArc.tga")   # one pixel thick when drawn 6px
    swirl.resize((512, 512), Image.LANCZOS).save("Art/icon-large.png", optimize=True)
    curseforge_logo(swirl).save("Art/curseforge-logo.png", optimize=True)
    if "--banner" in sys.argv:
        stamp_banner(swirl)


if __name__ == "__main__":
    main()
