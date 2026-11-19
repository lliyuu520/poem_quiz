"""生成 app 图标：朱红方印 + 米白「日知」二字。

「日知」取《论语》「日知其所亡」，两字竖排于方印内。
图标沿用 app 内的配色（宣纸 #F8F2E6 / 朱印 #A63A2E），
字体缺失时退化为几何笔画兜底。
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


def draw_ri(draw, box, fill):
    """字体不可用时的兜底：「日」字——外框 + 中间一横。"""
    x0, y0, x1, y1 = box
    w = x1 - x0
    h = y1 - y0
    t = max(2, int(w * 0.13))
    draw.rectangle([x0, y0, x1, y0 + t], fill=fill)
    draw.rectangle([x0, y1 - t, x1, y1], fill=fill)
    draw.rectangle([x0, y0, x0 + t, y1], fill=fill)
    draw.rectangle([x1 - t, y0, x1, y1], fill=fill)
    mid = y0 + int((h - t) / 2)
    draw.rectangle([x0 + t, mid, x1 - t, mid + t], fill=fill)


def draw_zhi(draw, box, fill):
    """字体不可用时的兜底：「知」字的简化笔画。"""
    x0, y0, x1, y1 = box
    w = x1 - x0
    h = y1 - y0
    t = max(2, int(w * 0.12))
    # 右侧「口」
    rx0 = x0 + int(w * 0.46)
    ry0 = y0 + int(h * 0.30)
    draw.rectangle([rx0, ry0, x1, ry0 + t], fill=fill)
    draw.rectangle([rx0, y1 - t, x1, y1], fill=fill)
    draw.rectangle([rx0, ry0, rx0 + t, y1], fill=fill)
    draw.rectangle([x1 - t, ry0, x1, y1], fill=fill)
    # 左侧「矢」简化：短横、撇、横
    draw.rectangle([x0, y0 + int(h * 0.08), x0 + int(w * 0.48), y0 + int(h * 0.08) + t], fill=fill)
    draw.line(
        [(x0 + int(w * 0.22), y0 + int(h * 0.10)), (x0 + int(w * 0.04), y1 - int(h * 0.08))],
        fill=fill,
        width=t,
    )
    draw.line(
        [(x0 + int(w * 0.14), y0 + int(h * 0.52)), (rx0 + int(t * 0.2), y0 + int(h * 0.52))],
        fill=fill,
        width=t,
    )


def draw_fallback(draw, box, fill):
    """在给定区域内竖排绘制「日」「知」的几何兜底。"""
    x0, y0, x1, y1 = box
    h = y1 - y0
    gap = int(h * 0.06)
    cell_h = (h - gap) // 2
    top = (x0, y0, x1, y0 + cell_h)
    bottom = (x0, y0 + cell_h + gap, x1, y0 + cell_h + gap + cell_h)
    draw_ri(draw, top, fill)
    draw_zhi(draw, bottom, fill)


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

    chars = ["日", "知"]
    font = load_font(int(s * 0.33))
    text_left = inner + int(s * 0.10)
    text_right = s - inner - int(s * 0.10)
    text_top = inner + int(s * 0.08)
    text_bottom = s - inner - int(s * 0.08)

    if font is not None:
        bboxes = [draw.textbbox((0, 0), c, font=font) for c in chars]
        heights = [b[3] - b[1] for b in bboxes]
        widths = [b[2] - b[0] for b in bboxes]
        gap = int(s * 0.01)
        total_h = sum(heights) + gap
        available_h = text_bottom - text_top
        y = text_top + max(0, (available_h - total_h) // 2)
        for c, b, tw, th in zip(chars, bboxes, widths, heights):
            x = (s - tw) / 2 - b[0]
            draw.text((x, y - b[1]), c, font=font, fill=PAPER)
            y += th + gap
    else:
        draw_fallback(draw, (text_left, text_top, text_right, text_bottom), PAPER)

    return img.resize((size, size), Image.LANCZOS)


def main():
    res_root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(__file__), "..", "android", "app", "src", "main", "res"
    )
    for folder, size in SIZES.items():
        out_dir = os.path.join(res_root, folder)
        os.makedirs(out_dir, exist_ok=True)
        img = render(size)
        img.save(os.path.join(out_dir, "ic_launcher.png"))
        print(f"{folder}/ic_launcher.png ({size}x{size})")


if __name__ == "__main__":
    main()
