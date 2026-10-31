# -*- coding: utf-8 -*-
import subprocess
from pathlib import Path

import arabic_reshaper
import numpy as np
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
W, H = 1080, 1920
FPS = 30
DURATION = 19.766667
NFRAMES = int(round(DURATION * FPS))
FONT = ImageFont.truetype(r"C:\Windows\Fonts\trado.ttf", 78)
PHOTO_SIZE = 1080
PHOTO_Y = (H - PHOTO_SIZE) // 2

CAPTIONS = [
    (0.40, 1.45, "أيدري القبر من فيه؟"),
    (1.95, 4.05, "فيه الفؤاد ومن بالروح أفديه"),
    (4.75, 6.45, "لولا الإله وإيمان أدين به"),
    (6.95, 8.75, "لكنت قربك أشفي ما ألاقيه"),
    (9.75, 11.55, "لكنها سنة الله التي سلفت"),
    (12.35, 14.25, "إن الإله لما قد شاء ممضيه"),
    (15.05, 16.95, "كم من فواجع شتى قد بليت بها"),
    (17.45, 19.55, "لكن موتك لا شيء يدانيه"),
]


def shape(text: str) -> str:
    return get_display(arabic_reshaper.reshape(text))


def make_base() -> Image.Image:
    src = Image.open(ROOT / "photo_2026-10-10_16-39-43.jpg").convert("RGB")
    scale = max(W / src.width, H / src.height)
    bg = src.resize(
        (round(src.width * scale) + 2, round(src.height * scale) + 2),
        Image.Resampling.LANCZOS,
    )
    left = (bg.width - W) // 2
    top = (bg.height - H) // 2
    bg = bg.crop((left, top, left + W, top + H)).filter(ImageFilter.GaussianBlur(42))
    bg = Image.blend(bg, Image.new("RGB", (W, H), (12, 10, 8)), 0.45)
    photo = src.resize((PHOTO_SIZE, PHOTO_SIZE), Image.Resampling.LANCZOS)
    bg.paste(photo, (0, PHOTO_Y))
    return bg.convert("RGBA")


def make_caption(text: str) -> np.ndarray:
    visual = shape(text)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    bbox = draw.textbbox((0, 0), visual, font=FONT)
    cx = (W - (bbox[2] - bbox[0])) // 2 - bbox[0]
    cy = (PHOTO_Y + PHOTO_SIZE // 2) - (bbox[1] + bbox[3]) // 2

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((cx, cy + 3), visual, font=FONT, fill=(0, 0, 0, 210), stroke_width=2)
    shadow = shadow.filter(ImageFilter.GaussianBlur(3))
    ImageDraw.Draw(layer).text(
        (cx, cy),
        visual,
        font=FONT,
        fill=(255, 255, 255, 255),
        stroke_width=2,
        stroke_fill=(0, 0, 0, 180),
    )
    return np.array(Image.alpha_composite(shadow, layer))


def fade_alpha(t: float, start: float, end: float) -> float:
    fin, fout = 0.32, 0.24
    if t < start or t >= end:
        return 0.0
    if t < start + fin:
        return (t - start) / fin
    if t > end - fout:
        return max(0.0, (end - t) / fout)
    return 1.0


def main() -> None:
    base = np.array(make_base().convert("RGB")).astype(np.float32)
    layers = [(a, b, make_caption(text)) for a, b, text in CAPTIONS]
    preview_times = {1.0: "p1", 3.0: "p2", 5.5: "p3", 7.8: "p4", 10.5: "p5", 13.2: "p6", 16.1: "p7", 18.6: "p8"}

    cmd = [
        "ffmpeg", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
        "-i", str(ROOT / "vid.mp4"),
        "-map", "0:v:0", "-map", "1:a:0",
        "-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p",
        "-c:a", "copy",
        "-shortest",
        "-movflags", "+faststart",
        str(ROOT / "final.mp4"),
    ]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    assert proc.stdin is not None

    for i in range(NFRAMES):
        t = i / FPS
        frame = base.copy()
        for start, end, layer in layers:
            alpha = fade_alpha(t, start, end)
            if alpha <= 0:
                continue
            src = layer[:, :, :3].astype(np.float32)
            a = (layer[:, :, 3:4].astype(np.float32) / 255.0) * alpha
            frame = src * a + frame * (1.0 - a)
        out = np.clip(frame, 0, 255).astype(np.uint8)
        for stamp, name in list(preview_times.items()):
            if abs(t - stamp) < (0.5 / FPS):
                Image.fromarray(out).save(ROOT / f"{name}.jpg", quality=90)
                del preview_times[stamp]
        proc.stdin.write(out.tobytes())
        if i % 100 == 0:
            print(f"frame {i}/{NFRAMES}", flush=True)

    proc.stdin.close()
    code = proc.wait()
    if code != 0:
        raise SystemExit(code)
    print("done", NFRAMES)


if __name__ == "__main__":
    main()
