"""英语题库生成器：english_bank.json → lib/data/english.dart + 音频清单。

用法：
    python -I tool/gen_english.py            # 只生成 Dart 题库与音频清单
    python -I tool/gen_english.py --audio    # 同时合成音频（需 requests 与 ffmpeg）

音频用阿里云百炼 qwen-audio-3.1-tts-plus（2026-11-21 起，替代 edge-tts Jenny——
与拼音科目统一音色）。API Key 只从 stdin 读入，不落盘：

    python -I tool/gen_english.py --audio <<'EOF'
    sk-...
    EOF

字母直接喂原字母「A.」让模型读字母名（实测 10 个刁钻字母 20/20 全对），
不再写字母名改写表——那是 edge-tts 时代「C. A. T. 丢尾字母」的绕路方案。
上传路径带版本段（en/v2/），换音色必须顺延版本：CDN 对 .opus 缓存一年、
手机按 key 永久缓存，同名覆盖两边都不生效。

为什么用脚本生成 Dart 而不是手写：
题库里的英文与音频文件名必须一一对应。手写 40 个词、26 个字母、14 个句子，
只要有一处拼错，播放时就会静默无声或读到别的词——这类错误在代码里看不出来。
生成器让「文本」成为唯一事实来源，Dart 与音频都由它派生。
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "tool" / "english_bank.json"
DART_OUT = ROOT / "lib" / "data" / "english.dart"
AUDIO_OUT = ROOT / "assets" / "audio" / "en"

TTS_MODEL = "qwen-audio-3.1-tts-plus"
VOICE = "longanfengyue_v3.1"
TTS_INSTRUCTION = (
    "Speak in clear, natural American English, like a friendly teacher reading to a child. "
    "Use a normal speaking pace. Do not exaggerate or add any words. Read only the given text."
)

# 字母名改写表：edge-tts 时代合成用；Qwen 直接读原字母后仅作读音参考保留。
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
        # grade 从 JSON 取（缺省 2，兼容早期只收二年级句子的题库）。
        add(
            "  Poem(title: {}, author: {}, dynasty: {}, grade: {}, lines: <String>[{}]),".format(
                dart_str(item["en"]), dart_str(item["zh"]), dart_str(item["theme"]),
                item.get("grade", 2), dart_str(item["zh"]),
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
    add("/// 句子条目的英文文本，按题库顺序。**由生成器产出，不要手改**。")
    add("///")
    add("/// 句子音频键是 `sentence_00`、`sentence_01`……，靠位置对应：这张表与")
    add("/// `kEnglishSentences` 的顺序必须完全一致，否则播放会串到别的句子。")
    add("/// 新增句子只能追加到末尾，插中间会让其后所有句子的音频全部错位。")
    add("const List<String> kEnglishSentenceTexts = <String>[")
    for item in bank["sentences"]:
        add("  {},".format(dart_str(item["en"])))
    add("];")
    add("")
    return "\n".join(lines)


def audio_jobs(bank: dict) -> list[tuple[str, str]]:
    """(文件名, 要朗读的文本)。文件名同时是 App 里查音频的键。

    个别文本形态风悦读不稳（裸词 egg 被读成字母、Key/Rice/Rain 大写开头
    元音漂移），合成时改用 TEXT_OVERRIDES 的文本——均经 ASR 逐字复验通过
    后固化，见 verify_english_audio.py 全量校验。
    """
    jobs: list[tuple[str, str]] = []

    def text_for(name: str, text: str) -> str:
        return TEXT_OVERRIDES.get(name, text)

    for item in bank["letters"]:
        u = item["u"]
        # Qwen 直接读原字母就是字母名（实测 20/20 全对），不再走字母名改写。
        # 唯一例外 N：风悦把「N.」稳定读成 /ʌn/（五个 seed 复验一致），
        # 该条沿用旧 Jenny 音频，synth 会跳过它，见 TEXT_OVERRIDES 注释。
        if u != "N":
            jobs.append((f"letter_{u.lower()}", text_for(f"letter_{u.lower()}", f"{u}.")))
        jobs.append((f"letterword_{item['example']}", text_for(
            f"letterword_{item['example']}", item["example"].capitalize() + ".",
        )))
    for item in bank["words"]:
        jobs.append((f"word_{item['w']}", text_for(
            f"word_{item['w']}", item["w"].capitalize() + ".",
        )))
        jobs.append((f"sent_{item['w']}", text_for(f"sent_{item['w']}", item["sentence"])))
    for i, item in enumerate(bank["sentences"]):
        jobs.append((f"sentence_{i:02d}", text_for(f"sentence_{i:02d}", item["en"])))
    return jobs


# 合成文本改写表：键是音频键。egg 的裸词形态（「Egg.」）该模型稳定读成
# 字母「A-G」，带冠词的「The egg.」ASR 逐字复验通过；Key/Rice/Rain 用
# 小写原速形式通过（大写开头会读偏）。
TEXT_OVERRIDES = {
    "letterword_egg": "The egg.",
    "word_egg": "The egg.",
    "letterword_key": "key.",
    "word_rice": "rice.",
    "word_rain": "rain.",
    # 三年级词：大写开头读偏（与 key/rice/rain 同一类），改小写原形。
    "word_windy": "windy.",
    "word_sing": "sing.",
    "word_busy": "busy.",
    # 极短问候语：`Hi!` 的感叹号让风悦稳定读成 "Bye"（同 seed 四次复验一致，
    # 命中的是「感叹号 + 单音节」这个组合）。改句号后两次复验都读对 `Hi!`，
    # 且转码链路无关——`Hi.` 的 mp3 与同款 32k opus 都识别为 Hi。
    # 只改合成文本，题库与题面仍是 `Hi!`。
    "sentence_25": "Hi.",
}

# 与 TEXT_OVERRIDES 同步的期望文本表由 verify_english_audio.py 单独维护，
# 新增改写时两边都要加，否则校验会按题库原文比对而误报。

# 直接要服务端原生 opus 的条目（值是语速）。本地「mp3 → ffmpeg libopus 32k」
# 转码会削掉个别浊音瞬态：sent_bread 的 b 在 32k~128k 本地转码下全读成
# /p/（mp3 原文件正确），服务端原生 opus 用 rate 1.05 渲染才逐字通过。
NATIVE_OPUS_RATES = {
    "sent_bread": 1.05,
}


def synth(jobs: list[tuple[str, str]], out_dir: Path, api_key: str, seed: int = 42) -> None:
    """固定音色生成英语语音；失败可续跑，不因单条超时空等整批。"""
    from concurrent.futures import ThreadPoolExecutor

    endpoint = (
        f"https://{WORKSPACE}.{TTS_REGION}.maas.aliyuncs.com"
        "/api/v1/services/audio/tts/SpeechSynthesizer"
    )
    out_dir.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []

    def one(job: tuple[str, str]) -> None:
        name, text = job
        # letter_n 沿用旧 Jenny 音频（风悦把「N.」稳定读成 /ʌn/，见 audio_jobs）；
        # 文件缺失时本条被跳过，由 AGENTS.md 记录的备份流程补回。
        if name == "letter_n":
            return
        # 已有 opus 就跳过：合成一条要几秒，150 条全重跑是几分钟。
        # 要重新生成某条，删掉对应文件即可。
        if (out_dir / f"{name}.opus").exists() or (out_dir / f"{name}.mp3").exists():
            return
        payload = {
            "model": TTS_MODEL,
            "input": {
                "text": text,
                "voice": VOICE,
                "format": "opus" if name in NATIVE_OPUS_RATES else "mp3",
                "sample_rate": 24000,
                "rate": NATIVE_OPUS_RATES.get(name, 1.0),
                "seed": seed,
                "instruction": TTS_INSTRUCTION,
                "language_hints": ["en"],
            },
        }
        for attempt in range(3):
            try:
                response = requests.post(
                    endpoint,
                    headers={
                        "Authorization": f"Bearer {api_key}",
                        "Content-Type": "application/json",
                    },
                    json=payload,
                    timeout=(12, 65),
                )
                data = response.json()
                audio = data.get("output", {}).get("audio", {})
                if not response.ok or not audio.get("url"):
                    raise RuntimeError(
                        f"HTTP {response.status_code} "
                        f'{data.get("code", "")} {data.get("message", "")}'
                    )
                url = audio["url"]
                if url.startswith("http://"):
                    url = "https://" + url[len("http://"):]
                if name in NATIVE_OPUS_RATES:
                    # 服务端原生 opus 直接落盘，不走 mp3 中转与本地转码。
                    with requests.get(url, stream=True, timeout=(12, 45)) as download:
                        download.raise_for_status()
                        with (out_dir / f"{name}.opus").open("wb") as f:
                            for chunk in download.iter_content(65536):
                                f.write(chunk)
                    print(f"  synth {name} (native opus)", flush=True)
                    return
                mp3_path = out_dir / f"{name}.mp3"
                with requests.get(url, stream=True, timeout=(12, 45)) as download:
                    download.raise_for_status()
                    with mp3_path.open("wb") as f:
                        for chunk in download.iter_content(65536):
                            f.write(chunk)
                print(f"  synth {name}", flush=True)
                return
            except (requests.RequestException, RuntimeError, OSError) as exc:
                print(f"  retry {name}: {type(exc).__name__}", flush=True)
        failures.append(name)

    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(one, jobs))
    if failures:
        print(f"合成失败 {len(failures)} 条，重跑可续传：{failures}", flush=True)


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
    ap.add_argument("--seed", type=int, default=42, help="合成种子；换 seed 重渲染可判别识别抖动")
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
        api_key = sys.stdin.readline().strip()
        if not api_key:
            sys.exit("未从 stdin 读到 API Key")
        synth(jobs, AUDIO_OUT, api_key, seed=args.seed)
        n = to_opus(AUDIO_OUT)
        print(f"转码 {n} 条 opus")
        if not args.keep_mp3:
            for mp3 in AUDIO_OUT.glob("*.mp3"):
                mp3.unlink()
        write_manifest()
    return 0


WORKSPACE = "llm-n1xmigv57szjb64o"
TTS_REGION = "cn-beijing"


def write_manifest() -> None:
    """写 manifest.json：App 靠它知道云端有哪些音频（「全部下载」用）。

    必须与实际生成的文件一一对应，所以直接从目录列出来，不重新推算文件名。
    """
    files = sorted(p.stem for p in AUDIO_OUT.glob("*.opus"))
    manifest = {
        "voice": f"{TTS_MODEL}/{VOICE}",
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
