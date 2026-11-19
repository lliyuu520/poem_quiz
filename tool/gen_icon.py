"""生成 app 图标：朱红方印 + 米白「诗」字。

图标沿用 app 内的配色（宣纸 #F8F2E6 / 朱印 #A63A2E），
字体缺失时退化为几何笔画，保证任何环境都能产出图。
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont

SEAL = (166, 58, 46, 255)
SEAL_DARK = (138, 45, 35, 255)
PAPER = (248, 242, 230, 255)

SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\simhei.ttf",
    r"C:\Windows\Fonts\msyhbd.ttc",
    r"C:\Windows\Fonts\simsun.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
]


def load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return None


def draw_glyph(draw, box, fill):
    """字体不可用时的兜底：用矩形笔画拼一个「诗」字的意象。"""
    x0, y0, x1, y1 = box
    w = x1 - x0
    h = y1 - y0
    t = max(2, int(w * 0.11))
    # 左半：三横一竖，取「讠」的骨架
    for i in range(3):
        y = y0 + int(h * (0.18 + i * 0.24))
        draw.rectangle([x0, y, x0 + int(w * 0.30), y + t], fill=fill)
    draw.rectangle([x0 + int(w * 0.02), y0 + int(h * 0.15), x0 + int(w * 0.02) + t, y1 - int(h * 0.1)], fill=fill)
    # 右半：方形框架，取「寺」的骨架
    rx0 = x0 + int(w * 0.42)
    rx1 = x1
    for i in range(2):
        y = y0 + int(h * (0.22 + i * 0.30))
        draw.rectangle([rx0, y, rx1, y + t], fill=fill)
    draw.rectangle([rx0 + int((rx1 - rx0) * 0.45), y0 + int(h * 0.22), rx0 + int((rx1 - rx0) * 0.45) + t, y1 - int(h * 0.05)], fill=fill)
    draw.rectangle([rx0, y1 - int(h * 0.12), rx1, y1 - int(h * 0.12) + t], fill=fill)


def render(size):
    # 4x 超采样后缩小，边缘更干净
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    margin = int(s * 0.06)
    radius = int(s * 0.18)

    # 印章主体：深色描边 + 朱红填充
    draw.rounded_rectangle(
        [margin, margin, s - margin, s - margin],
        radius=radius,
        fill=SEAL,
        outline=SEAL_DARK,
        width=max(2, int(s * 0.02)),
    )

    # 内框细线，模拟印章边框
    inner = margin + int(s * 0.045)
    draw.rounded_rectangle(
        [inner, inner, s - inner, s - inner],
        radius=max(1, radius - int(s * 0.04)),
        outline=(255, 255, 255, 110),
        width=max(1, int(s * 0.008)),
    )

    font = load_font(int(s * 0.52))
    if font is not None:
        text = "诗"
        bbox = draw.textbbox((0, 0), text, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        draw.text(
            ((s - tw) / 2 - bbox[0], (s - th) / 2 - bbox[1]),
            text,
            font=font,
            fill=PAPER,
        )
    else:
        pad = int(s * 0.26)
        draw_glyph(draw, (pad, pad, s - pad, s - pad), PAPER)

    return img.resize((size, size), Image.LANCZOS)


def main():
    res_root = sys.argv[1]
    for folder, size in SIZES.items():
        out_dir = os.path.join(res_root, folder)
        os.makedirs(out_dir, exist_ok=True)
        img = render(size)
        img.save(os.path.join(out_dir, "ic_launcher.png"))
        print(f"{folder}/ic_launcher.png ({size}x{size})")


if __name__ == "__main__":
    main()
