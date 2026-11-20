"""英语题库生成器：english_bank.json → lib/data/english.dart + 音频清单。

用法：
    python -I tool/gen_english.py            # 只生成 Dart 题库与音频清单
    python -I tool/gen_english.py --audio    # 同时合成音频（需 edge-tts 与 ffmpeg）

为什么用脚本生成 Dart 而不是手写：
题库里的英文与音频文件名必须一一对应。手写 40 个词、26 个字母、14 个句子，
只要有一处拼错，播放时就会静默无声或读到别的词——这类错误在代码里看不出来。
生成器让「文本」成为唯一事实来源，Dart 与音频都由它派生。
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "tool" / "english_bank.json"
DART_OUT = ROOT / "lib" / "data" / "english.dart"
AUDIO_OUT = ROOT / "assets" / "audio" / "en"

# 音色：Jenny 的元音最稳（实测 cat 与其自身 /æ/ 参照偏离 4.3%，
# Aria 同样条件下偏离 55.8%，孤立单词会把 /æ/ 读成 /e/）。
VOICE = "en-US-JennyNeural"

# 逐字母朗读必须写字母名，不能写「C. A. T.」：
# 后者会被切掉最后一个字母，只读两个（实测 2 个音节）。
LETTER_NAMES = {
    "A": "ay", "B": "bee", "C": "see", "D": "dee", "E": "ee", "F": "ef",
    "G": "jee", "H": "aitch", "I": "eye", "J": "jay", "K": "kay", "L": "el",
    "M": "em", "N": "en", "O": "oh", "P": "pee", "Q": "cue", "R": "ar",
    "S": "ess", "T": "tee", "U": "you", "V": "vee", "W": "double you",
    "X": "ex", "Y": "why", "Z": "zee",
}


def load_bank() -> dict:
    with BANK.open(encoding="utf-8") as f:
        return json.load(f)


def check_bank(bank: dict) -> list[str]:
    """返回问题列表。空列表表示题库可用。"""
    problems: list[str] = []

    letters = bank["letters"]
    if len(letters) != 26:
        problems.append(f"字母应为 26 个，实际 {len(letters)}")
    seen_u = set()
    for item in letters:
        u = item["u"]
        if u in seen_u:
            problems.append(f"字母重复：{u}")
        seen_u.add(u)
        if item["l"] != u.lower():
            problems.append(f"字母大小写不配对：{u} / {item['l']}")
        if not item.get("phoneme", "").startswith("/"):
            problems.append(f"字母 {u} 的音标格式不对：{item.get('phoneme')}")

    words = bank["words"]
    seen_w = set()
    for item in words:
        w = item["w"]
        if w in seen_w:
            problems.append(f"单词重复：{w}")
        seen_w.add(w)
        if w != w.lower():
            problems.append(f"单词应全小写：{w}")
        if not item.get("sentence"):
            problems.append(f"单词 {w} 缺例句")
        elif w not in item["sentence"].lower():
            # 例句里出现该词（含变形）才值得朗读；否则句子和词对不上。
            stem = w[:-1] if len(w) > 3 else w
            if stem not in item["sentence"].lower():
                problems.append(f"单词 {w} 的例句里没有它：{item['sentence']}")

    seen_s = set()
    for item in bank["sentences"]:
        en = item["en"]
        if en in seen_s:
            problems.append(f"句子重复：{en}")
        seen_s.add(en)

    # 音频文件名由条目内容派生，两个字母共用同一个例词（如 I 与 P 都用 pig）
    # 会让后者覆盖前者的音频，孩子听到的例词就和卡片上的不一致。
    names = [name for name, _ in audio_jobs(bank)]
    dupes = {n for n in names if names.count(n) > 1}
    for n in sorted(dupes):
        problems.append(f"音频文件名重复：{n}（例词在多个字母间重复）")

    return problems


def dart_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def emit_dart(bank: dict) -> str:
    lines: list[str] = []
    add = lines.append

    add("// 由 tool/gen_english.py 从 tool/english_bank.json 生成，不要手改。")
    add("// 改题库请改 JSON 后重跑脚本；文本与音频文件名必须一一对应。")
    add("")
    add("import '../models/poem.dart';")
    add("")
    add("/// 字母条目：`title` 是大写字母，`author` 是小写字母，")
    add("/// `dynasty` 是分组（元音/辅音），`lines` 依次是音标与例词。")
    add("/// 例词单独成行，学习页展开时能看清「哪个字母发哪个音」。")
    add("const List<Poem> kEnglishLetters = <Poem>[")
    for item in bank["letters"]:
        u = item["u"]
        group = "元音字母" if u in "AEIOU" else "辅音字母"
        add(
            "  Poem(title: {}, author: {}, dynasty: {}, grade: 1, lines: <String>[{}, {}]),".format(
                dart_str(u), dart_str(item["l"]), dart_str(group),
                dart_str(item["phoneme"]), dart_str(item["example"]),
            )
        )
    add("];")
    add("")
    add("/// 单词条目：`title` 是英文词，`author` 是中文释义，`dynasty` 是主题分组，")
    add("/// `lines` 是例句（英文一行、中文一行），`grade` 是学龄档。")
    add("///")
    add("/// 例句里含该词，孩子点开就能听到词在句子中的读法。")
    add("const List<Poem> kEnglishWords = <Poem>[")
    for item in bank["words"]:
        add(
            "  Poem(title: {}, author: {}, dynasty: {}, grade: {}, lines: <String>[{}, {}]),".format(
                dart_str(item["w"]), dart_str(item["zh"]), dart_str(item["theme"]),
                item["grade"], dart_str(item["sentence"]), dart_str(item["zhSentence"]),
            )
        )
    add("];")
    add("")
    add("/// 句子条目：`title` 是英文句子，`author` 是中文，`dynasty` 是主题分组。")
    add("/// `lines` 重复放一份中文，让学习页展开时与其它科目结构一致。")
    add("const List<Poem> kEnglishSentences = <Poem>[")
    for item in bank["sentences"]:
        add(
            "  Poem(title: {}, author: {}, dynasty: {}, grade: 2, lines: <String>[{}]),".format(
                dart_str(item["en"]), dart_str(item["zh"]), dart_str(item["theme"]),
                dart_str(item["zh"]),
            )
        )
    add("];")
    add("")
    add("/// 英语题库全集。三个层按学龄递进：字母与自然拼读 → 主题词 → 日常短句。")
    add("const List<Poem> kEnglish = <Poem>[")
    add("  ...kEnglishLetters,")
    add("  ...kEnglishWords,")
    add("  ...kEnglishSentences,")
    add("];")
    add("")
    add("/// 逐字母朗读用的字母名文本（如 C → `see`）。")
    add("///")
    add("/// 直接朗读 `C. A. T.` 会被引擎切掉最后一个字母（实测只剩 2 个音节），")
    add("/// 写字母名才稳定读出 26 个字母。生成音频时用的也是这份表。")
    add("const Map<String, String> kLetterNames = <String, String>{")
    for u, name in LETTER_NAMES.items():
        add("  {}: {},".format(dart_str(u), dart_str(name)))
    add("};")
    add("")
    return "\n".join(lines)


def audio_jobs(bank: dict) -> list[tuple[str, str]]:
    """(文件名, 要朗读的文本)。文件名同时是 App 里查音频的键。"""
    jobs: list[tuple[str, str]] = []
    for item in bank["letters"]:
        u = item["u"]
        jobs.append((f"letter_{u.lower()}", LETTER_NAMES[u] + "."))
        jobs.append((f"letterword_{item['example']}", item["example"].capitalize() + "."))
    for item in bank["words"]:
        jobs.append((f"word_{item['w']}", item["w"].capitalize() + "."))
        jobs.append((f"sent_{item['w']}", item["sentence"]))
    for i, item in enumerate(bank["sentences"]):
        jobs.append((f"sentence_{i:02d}", item["en"]))
    return jobs


async def synth(jobs: list[tuple[str, str]], out_dir: Path) -> None:
    import edge_tts  # 延迟导入：只生成 Dart 时不需要它

    out_dir.mkdir(parents=True, exist_ok=True)
    for name, text in jobs:
        # 已有 opus 就跳过：合成一条要几秒，150 条全重跑是几分钟。
        # 要重新生成某条，删掉对应文件即可。
        if (out_dir / f"{name}.opus").exists() or (out_dir / f"{name}.mp3").exists():
            continue
        await edge_tts.Communicate(text, VOICE).save(str(out_dir / f"{name}.mp3"))
        print(f"  synth {name}")


def to_opus(src_dir: Path) -> int:
    """mp3 → opus（Android 原生支持，体积约为 mp3 的 1/3）。"""
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        print("找不到 ffmpeg，跳过转码")
        return 0
    n = 0
    for mp3 in sorted(src_dir.glob("*.mp3")):
        opus = mp3.with_suffix(".opus")
        if opus.exists():
            continue
        subprocess.run(
            [ffmpeg, "-y", "-loglevel", "error", "-i", str(mp3),
             "-c:a", "libopus", "-b:a", "32k", "-ac", "1", "-ar", "24000", str(opus)],
            check=True,
        )
        n += 1
    return n


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio", action="store_true", help="同时合成音频")
    ap.add_argument("--keep-mp3", action="store_true", help="转 opus 后保留 mp3")
    args = ap.parse_args()

    bank = load_bank()
    problems = check_bank(bank)
    if problems:
        print("题库有问题：")
        for p in problems:
            print("  -", p)
        return 1

    # 显式 newline="\n"：Windows 上 write_text 默认写 CRLF，项目规范是 LF。
    with DART_OUT.open("w", encoding="utf-8", newline="\n") as f:
        f.write(emit_dart(bank))
    print(f"写入 {DART_OUT.relative_to(ROOT)}")

    jobs = audio_jobs(bank)
    print(f"音频任务 {len(jobs)} 条（音色 {VOICE}）")

    if args.audio:
        asyncio.run(synth(jobs, AUDIO_OUT))
        n = to_opus(AUDIO_OUT)
        print(f"转码 {n} 条 opus")
        if not args.keep_mp3:
            for mp3 in AUDIO_OUT.glob("*.mp3"):
                mp3.unlink()
        write_manifest()
    return 0


def write_manifest() -> None:
    """写 manifest.json：App 靠它知道云端有哪些音频（「全部下载」用）。

    必须与实际生成的文件一一对应，所以直接从目录列出来，不重新推算文件名。
    """
    files = sorted(p.stem for p in AUDIO_OUT.glob("*.opus"))
    manifest = {
        "voice": VOICE,
        "count": len(files),
        "files": files,
    }
    out = AUDIO_OUT / "manifest.json"
    with out.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"写入 {out.relative_to(ROOT)}（{len(files)} 条）")


if __name__ == "__main__":
    sys.exit(main())
