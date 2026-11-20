"""英语音频质检：找出读音可疑的条目，供人工试听复核。

为什么需要自动质检：
TTS 的音色好坏可以听出来，但「某个词读错了」很难靠抽查发现——150 条音频里
错一两个词，人工听一遍也会漏。已知的真实案例：Aria 孤立朗读 `cat` 时把 /æ/
读成了接近 /e/ 的音，而同一音色在整句里又是对的。这类错误对孩子是直接的错误输入。

两项检查：
1. **音节数**：单词音频应当只有 1~2 个音节核，句子的音节数应与单词数同量级。
   数字明显偏少说明有词被吞掉（实测 `C. A. T.` 只剩 2 个音节）。
2. **元音共振峰**：把每个单词的元音 F1/F2 与该音色自身同元音的其它单词比对，
   偏离过大就标出来。用「同一音色的其它词」做参照，可以抵消男女声的固有差异。

用法：
    python -I tool/check_english_audio.py            # 全量检查，输出可疑项
    python -I tool/check_english_audio.py --verbose  # 同时打印每条数据
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "assets" / "audio" / "en"
BANK = ROOT / "tool" / "english_bank.json"


def decode(opus: Path, tmp: Path) -> Path | None:
    """opus → 16k 单声道 wav，便于用标准库读取。"""
    out = tmp / (opus.stem + ".wav")
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(opus),
             "-ac", "1", "-ar", "16000", str(out)],
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return out


def read_wav(path: Path) -> tuple[np.ndarray, int]:
    with wave.open(str(path), "rb") as w:
        n = w.getnframes()
        sr = w.getframerate()
        data = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float64) / 32768.0
    return data, sr


def count_syllables(data: np.ndarray, sr: int) -> int:
    """按能量包络数音节核。只用于粗筛，不追求语言学精度。"""
    win = int(0.020 * sr)
    hop = int(0.005 * sr)
    if len(data) < win:
        return 0
    env = np.array([
        np.sqrt(np.mean(data[s:s + win] ** 2))
        for s in range(0, len(data) - win, hop)
    ])
    if env.size == 0 or env.max() < 1e-4:
        return 0
    env /= env.max()
    on = env > 0.15

    count = 0
    start = None
    gap = 0
    for i, voiced in enumerate(on):
        if voiced:
            if start is None:
                start = i
            gap = 0
        elif start is not None:
            gap += 1
            if gap * hop / sr > 0.055:
                count += 1
                start = None
                gap = 0
    if start is not None:
        count += 1
    return count


def formants(seg: np.ndarray, sr: int, order: int = 14) -> list[float]:
    """LPC 求共振峰。返回按频率升序的候选列表。"""
    seg = seg - seg.mean()
    seg = np.append(seg[0], seg[1:] - 0.97 * seg[:-1])
    y = seg * np.hamming(len(seg))
    r = np.correlate(y, y, "full")[len(y) - 1:len(y) + order]
    if r[0] <= 1e-9:
        return []
    mat = np.array([[r[abs(i - j)] for j in range(order)] for i in range(order)])
    try:
        a = np.linalg.solve(mat, -r[1:order + 1])
    except np.linalg.LinAlgError:
        return []
    a = np.concatenate(([1.0], a))
    roots = np.roots(a)
    roots = roots[np.imag(roots) > 0]
    if len(roots) == 0:
        return []
    scale = sr / (2 * np.pi)
    freqs = np.arctan2(np.imag(roots), np.real(roots)) * scale
    bws = -0.5 * scale * np.log(np.abs(roots) + 1e-12)
    keep = sorted(
        (f, b) for f, b in zip(freqs, bws)
        if 200 < f < 3200 and b < 450
    )
    return [f for f, _ in keep]


def vowel_of(data: np.ndarray, sr: int) -> tuple[float, float] | None:
    """估元音共振峰，返回 (F1, F2)。

    取**全部浊音帧的中位数**，而不是能量最大的那一帧：单帧很容易落在音素过渡上
    （词首爆破、词尾鼻音），会把正常的词判成读错。实测 `bee` 取最大能量帧得到
    F1=388/F2=2529（偏离组中位 46%，像读错了），改用浊音帧中位数是 F1=378/F2=2811，
    正是标准的 /iː/——问题在测量方法，不在音频。
    """
    win = int(0.030 * sr)
    hop = int(0.005 * sr)
    frames: list[list[float]] = []
    for s in range(0, len(data) - win, hop):
        seg = data[s:s + win]
        if float(np.sqrt(np.mean(seg ** 2))) < 0.02:
            continue
        f = formants(seg, sr)
        if len(f) >= 2:
            frames.append(f[:2])
    if len(frames) < 3:
        return None
    arr = np.array(frames)
    return float(np.median(arr[:, 0])), float(np.median(arr[:, 1]))


def main() -> int:
    # Windows 控制台默认 GBK，音标里的 ː / ə 等字符会直接抛 UnicodeEncodeError，
    # 把检查结果整个打断。强制 UTF-8 输出。
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    ap = argparse.ArgumentParser()
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--tolerance", type=float, default=0.30,
                    help="元音偏离阈值（相对值），超过则标可疑")
    args = ap.parse_args()

    bank = json.loads(BANK.read_text(encoding="utf-8"))
    words = bank["words"]

    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        rows = []
        for item in words:
            opus = AUDIO / f"word_{item['w']}.opus"
            if not opus.exists():
                print(f"缺音频：{item['w']}")
                continue
            wav = decode(opus, tmp)
            if wav is None:
                continue
            data, sr = read_wav(wav)
            rows.append({
                "w": item["w"],
                "v": item["v"],
                "syl": count_syllables(data, sr),
                "dur": len(data) / sr,
                "fm": vowel_of(data, sr),
            })

    # 音节数：单词音频正常是 1~3 个音节核（含词尾爆破）。
    print("== 音节数异常 ==")
    bad_syl = 0
    for r in rows:
        if r["syl"] < 1 or r["syl"] > 3:
            print(f"  {r['w']:8s} 音节 {r['syl']}  时长 {r['dur']:.2f}s")
            bad_syl += 1
    if bad_syl == 0:
        print("  无")

    # 元音一致性：按标注元音分组，组内与中位数比对。
    groups: dict[str, list[dict]] = {}
    for r in rows:
        if r["fm"]:
            groups.setdefault(r["v"], []).append(r)

    print("\n== 元音偏离 ==")
    flagged = 0
    for vowel, items in sorted(groups.items()):
        if len(items) < 2:
            continue
        f1s = np.array([i["fm"][0] for i in items])
        f2s = np.array([i["fm"][1] for i in items])
        m1, m2 = float(np.median(f1s)), float(np.median(f2s))
        for i in items:
            f1, f2 = i["fm"]
            dev = float(np.hypot((f1 - m1) / m1, (f2 - m2) / m2))
            if dev > args.tolerance:
                print(f"  {i['w']:8s} /{vowel}/  F1={f1:4.0f} F2={f2:4.0f}  "
                      f"组中位 F1={m1:4.0f} F2={m2:4.0f}  偏离 {dev:.0%}")
                flagged += 1
    if flagged == 0:
        print("  无")

    if args.verbose:
        print("\n== 全量 ==")
        for r in rows:
            fm = r["fm"]
            s = f"F1={fm[0]:4.0f} F2={fm[1]:4.0f}" if fm else "F1=  -- F2=  --"
            print(f"  {r['w']:8s} /{r['v']:3s}/ 音节 {r['syl']}  {s}  {r['dur']:.2f}s")

    print(f"\n共 {len(rows)} 个词，音节异常 {bad_syl}，元音可疑 {flagged}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
