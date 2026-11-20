"""生成 app 图标：朱红方印 + 米白「拾」字。

「拾」单字方印：双关拾取 / 十题一局。印章沿用宣纸 #F8F2E6 / 朱印 #A63A2E。
同时生成：
- 旧式 mipmap-*/ic_launcher.png（完整印章）
- 自适应图标前景 mipmap-*/ic_launcher_foreground.png（仅印面字，透明底）
- 自适应图标背景 drawable/ic_launcher_background.xml 与前景矢量兜底
- mipmap-anydpi-v26/ic_launcher.xml、ic_launcher_round.xml
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SEAL = (166, 58, 46, 255)
SEAL_DARK = (138, 45, 35, 255)
PAPER = (248, 242, 230, 255)
TRANSPARENT = (0, 0, 0, 0)

CHAR = "拾"

LEGACY_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# 108dp adaptive canvas
FOREGROUND_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

FONT_CANDIDATES = [
    r"C:\Windows\Fonts\STZHONGS.TTF",  # 华文中宋，印章感较好
    r"C:\Windows\Fonts\simhei.ttf",
    r"C:\Windows\Fonts\msyhbd.ttc",
    r"C:\Windows\Fonts\simsun.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc",
]


def load_font(size: int):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return None


def _measure(draw: ImageDraw.ImageDraw, text: str, font):
    b = draw.textbbox((0, 0), text, font=font)
    return b[2] - b[0], b[3] - b[1], b


def _draw_centered_text(draw: ImageDraw.ImageDraw, box, text: str, fill, font, scale: float = 1.0):
    """在 box 内居中绘制单字。scale<1 时按视觉略缩以留呼吸。"""
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    if font is None:
        # 兜底：简单方块占位
        pad = int(min(bw, bh) * 0.22)
        draw.rectangle([x0 + pad, y0 + pad, x1 - pad, y1 - pad], outline=fill, width=max(2, int(min(bw, bh) * 0.1)))
        return
    # 迭代找合适字号，让字形落在 box 的 scale 比例内
    target = min(bw, bh) * scale
    # 从较大字号开始试
    base = int(target * 1.25)
    best_font = font
    for sz in range(base, max(8, base // 3), -2):
        try:
            f = ImageFont.truetype(font.path, sz) if hasattr(font, "path") else font.font_variant(size=sz)
        except Exception:
            try:
                f = ImageFont.truetype(getattr(font, "path", ""), sz)
            except Exception:
                f = best_font
                break
        tw, th, b = _measure(draw, text, f)
        if max(tw, th) <= target:
            best_font = f
            break
        best_font = f
    tw, th, b = _measure(draw, text, best_font)
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    x = cx - (b[0] + tw / 2)
    y = cy - (b[1] + th / 2)
    draw.text((x, y), text, font=best_font, fill=fill)


def render_legacy(size: int) -> Image.Image:
    """旧式完整印章图标（圆角方印 + 内描边 + 单字）。"""
    s = size * 4
    img = Image.new("RGBA", (s, s), TRANSPARENT)
    draw = ImageDraw.Draw(img)

    margin = int(s * 0.06)
    radius = int(s * 0.18)

    draw.rounded_rectangle(
        [margin, margin, s - margin, s - margin],
        radius=radius,
        fill=SEAL,
        outline=SEAL_DARK,
        width=max(2, int(s * 0.02)),
    )

    inner = margin + int(s * 0.045)
    draw.rounded_rectangle(
        [inner, inner, s - inner, s - inner],
        radius=max(1, radius - int(s * 0.04)),
        outline=(255, 255, 255, 110),
        width=max(1, int(s * 0.008)),
    )

    font = load_font(int(s * 0.46))
    # 保持与字体 path 兼容：load_font 返回 truetype 带 path
    pad = int(s * 0.17)
    _draw_centered_text(draw, (inner + pad, inner + pad, s - inner - pad, s - inner - pad), CHAR, PAPER, font, scale=0.98)

    return img.resize((size, size), Image.LANCZOS)


def render_foreground(size: int) -> Image.Image:
    """自适应图标前景：透明底 + 米白单字，居中落在安全区内。108dp 画布。

    关键：字形 bbox 的半对角线必须落在 66dp 安全圆内，否则圆形蒙版会切角。
    安全圆半径 33dp => 内接正方形半边 33/√2 ≈ 23.33dp (画布的 21.6%)。
    """
    s = size * 4
    img = Image.new("RGBA", (s, s), TRANSPARENT)
    draw = ImageDraw.Draw(img)
    safe_r = s * (33 / 108)
    inscribed = safe_r / 1.4142
    cx = cy = s / 2
    box = (cx - inscribed, cy - inscribed, cx + inscribed, cy + inscribed)
    font = load_font(int(s * 0.26))
    _draw_centered_text(draw, box, CHAR, PAPER, font, scale=0.98)
    return img.resize((size, size), Image.LANCZOS)


def write_xml(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main():
    res_root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "android" / "app" / "src" / "main" / "res"

    # Legacy icons
    for folder, size in LEGACY_SIZES.items():
        out_dir = res_root / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        render_legacy(size).save(out_dir / "ic_launcher.png")
        # 圆形变体：同图即可（大多数 launcher 接受）
        render_legacy(size).save(out_dir / "ic_launcher_round.png")
        print(f"{folder}/ic_launcher.png + ic_launcher_round.png ({size}x{size})")

    # Adaptive foregrounds
    for folder, size in FOREGROUND_SIZES.items():
        out_dir = res_root / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        render_foreground(size).save(out_dir / "ic_launcher_foreground.png")
        print(f"{folder}/ic_launcher_foreground.png ({size}x{size})")

    # Background drawable (solid seal color)
    write_xml(
        res_root / "drawable" / "ic_launcher_background.xml",
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n'
        '    <solid android:color="#A63A2E"/>\n'
        '</shape>\n',
    )
    print("drawable/ic_launcher_background.xml")

    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@drawable/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )
    write_xml(res_root / "mipmap-anydpi-v26" / "ic_launcher.xml", adaptive)
    write_xml(res_root / "mipmap-anydpi-v26" / "ic_launcher_round.xml", adaptive)
    print("mipmap-anydpi-v26/ic_launcher.xml + ic_launcher_round.xml")


if __name__ == "__main__":
    main()
