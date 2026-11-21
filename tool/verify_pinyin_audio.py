"""拼音音频校验：默认全量检查文件与解码，可选中文 ASR 辅助排查。

短单字 ASR 误报很多（「笔」识别为空），不能把回读一致当成声调验收，
也不能把不一致直接当成音频坏。多音字和轻声应结合题库标注试听。

用法：
    python -I tool/verify_pinyin_audio.py             # 全量完整性与解码
    python -I tool/verify_pinyin_audio.py --asr --model <本地模型目录>

依赖：ffmpeg；使用 --asr 时另需 faster-whisper、numpy 与中文模型。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / 'assets' / 'audio' / 'pinyin'
os.environ.setdefault('HF_ENDPOINT', 'https://hf-mirror.com')
# 本机 Xet 下载曾停在半部模型不再推进，普通 HTTPS 可直连，校验不依赖 Xet。
os.environ.setdefault('HF_HUB_DISABLE_XET', '1')


def normalize(text: str) -> str:
    """中文 ASR 比对只关心字，不比较空白、标点与繁简体字形以外的格式。"""
    return re.sub(r'[^一-鿿]+', '', text)


def to_wav(src: Path, tmp: Path) -> Path | None:
    out = tmp / (src.stem + '.wav')
    try:
        subprocess.run(
            ['ffmpeg', '-y', '-loglevel', 'error', '-i', str(src),
             '-ac', '1', '-ar', '16000', str(out)],
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    with wave.open(str(out), 'rb') as wav:
        if wav.getnframes() == 0:
            return None
    return out


def read_pcm(path: Path):
    """读 16k 单声道 wav；直接传波形，绕开 faster-whisper 对 av 的参数兼容问题。"""
    import numpy as np

    with wave.open(str(path), 'rb') as wav:
        data = np.frombuffer(wav.readframes(wav.getnframes()), dtype=np.int16)
    return data.astype('float32') / 32768.0


def main() -> int:
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    parser = argparse.ArgumentParser()
    parser.add_argument('--verbose', action='store_true')
    parser.add_argument('--asr', action='store_true', help='附加中文 ASR 回读（短音频误报较多）')
    parser.add_argument(
        '--model',
        default='small',
        help='模型名或本地 faster-whisper 目录；本机默认模型下载不稳时可传本地目录',
    )
    args = parser.parse_args()

    with (AUDIO / 'manifest.json').open(encoding='utf-8') as f:
        manifest = json.load(f)
    words: dict[str, str] = manifest['words']
    if len(words) != manifest['count']:
        print('清单条数不一致')
        return 1

    model = None
    if args.asr:
        from faster_whisper import WhisperModel

        print(f'加载模型 {args.model}，校验 {len(words)} 条 …', flush=True)
        model = WhisperModel(args.model, device='cpu', compute_type='int8')
    else:
        print(f'检查 {len(words)} 条音频的完整性与解码 …', flush=True)
    fails = []
    asr_mismatches = []
    with tempfile.TemporaryDirectory() as td:
        tmp = Path(td)
        for index, (key, expected) in enumerate(words.items(), 1):
            src = AUDIO / f'{key}.opus'
            if not src.exists():
                fails.append((key, expected, '缺文件'))
                continue
            wav = to_wav(src, tmp)
            if wav is None:
                fails.append((key, expected, '无法解码或空音频'))
                continue
            if model is not None:
                segments, _ = model.transcribe(read_pcm(wav), language='zh', beam_size=5)
                got = normalize(''.join(segment.text for segment in segments))
                if got != expected:
                    print(f'  ASR 不一致 [{index}/{len(words)}] {expected} → {got}', flush=True)
                    asr_mismatches.append((key, expected, got))
                elif args.verbose:
                    print(f'  [{index}/{len(words)}] ok {expected}', flush=True)
            elif args.verbose:
                print(f'  [{index}/{len(words)}] 可解码 {expected}', flush=True)

    print(f'\n共 {len(words)} 条，缺失/损坏 {len(fails)} 条，ASR 疑点 {len(asr_mismatches)} 条')
    for key, expected, got in fails:
        print(f'  {key}: 期望 {expected!r}，实际 {got!r}')
    print('ASR 对短单字常误报，不能证明声调；多音字与轻声需试听复核。')
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
