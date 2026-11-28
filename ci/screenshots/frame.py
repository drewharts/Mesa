#!/usr/bin/env python3
"""Compose App Store marketing frames from raw simulator screenshots.

usage: frame.py <raw_dir> <out_dir>
raw_dir holds <size>/<NN_scene>.png (from the screenshots workflow artifacts).
Writes <out_dir>/<size>/<NN_scene>.png at the exact ASC pixel size.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZES = {"6.9": (1320, 2868), "6.5": (1284, 2778)}
HEADLINES = {
    "tonight":   ("Tonight,", "decided in one tap"),
    "pick":      ("Pick together", "everyone votes, Mesa decides"),
    "map_lists": ("Your lists,", "on the map"),
    "list":      ("Save from TikTok", "every spot your feed shows you"),
    "place":     ("Know before you go", "photos, hours and the take"),
    "trips":     ("Plan trips", "with friends, day by day"),
    "profile":   ("Your taste,", "all in one place"),
}
CHARCOAL = (45, 45, 45)
CREAM = (246, 242, 235)
FONT = "/usr/share/fonts/truetype/sand-box/google/Inter/Inter-VariableFont_opsz,wght.ttf"

def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([32, weight])
    except Exception:
        pass
    return f

def frame(src, dst, size, scene):
    W, H = size
    bg = Image.new("RGB", (W, H), CREAM)
    d = ImageDraw.Draw(bg)
    title, sub = HEADLINES.get(scene, (scene.title(), ""))
    tf, sf = font(int(W * 0.085), 750), font(int(W * 0.042), 450)
    y = int(H * 0.06)
    for text, f, color in ((title, tf, CHARCOAL), (sub, sf, (110, 106, 100))):
        if not text:
            continue
        w = d.textlength(text, font=f)
        d.text(((W - w) / 2, y), text, font=f, fill=color)
        y += int(f.size * 1.25)
    shot = Image.open(src).convert("RGB")
    top = y + int(H * 0.03)
    avail_h = H - top - int(H * 0.035)
    scale = min(avail_h / shot.height, (W * 0.84) / shot.width)
    sw, sh = int(shot.width * scale), int(shot.height * scale)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    r = int(sw * 0.11)
    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw, sh), r, fill=255)
    x = (W - sw) // 2
    bezel = int(sw * 0.025)
    shadow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(shadow).rounded_rectangle((x - bezel, top - bezel + 18, x + sw + bezel, top + sh + bezel + 18), r + bezel, fill=90)
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    bg.paste(Image.new("RGB", (W, H), (0, 0, 0)), (0, 0), shadow)
    ImageDraw.Draw(bg).rounded_rectangle((x - bezel, top - bezel, x + sw + bezel, top + sh + bezel), r + bezel, fill=(20, 20, 20))
    bg.paste(shot, (x, top), mask)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    bg.save(dst, "PNG")  # RGB, no alpha: ASC rejects transparency

def main(raw, out):
    for size, dims in SIZES.items():
        d = os.path.join(raw, size)
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if name.endswith(".png"):
                scene = name[3:-4] if name[:2].isdigit() else name[:-4]
                frame(os.path.join(d, name), os.path.join(out, size, name), dims, scene)
                print(os.path.join(out, size, name))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
