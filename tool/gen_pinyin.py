"""生成拼音题库 Dart 源文件。

设计要点：
- 声调一律由 pypinyin 计算，不手打——手打 800 条必然出错，一个声调错就是一道错题。
- 多音字按「词」而非单字取音，pypinyin 会按词组自动选音（长大 zhǎng、银行 háng）。
- 少数 pypinyin 处理不了的（儿化音「花儿」→ huā r、轻声）在 OVERRIDES 里定向修正。
- 每个词标注年级，按「一年级→六年级」难度递增编排。

用法：
    python -I tool/gen_pinyin.py            # 只生成 Dart 题库
    python -I tool/gen_pinyin.py --audio    # 同时合成音频（需 edge-tts 与 ffmpeg）

音频不打进 APK，按字词生成稳定文件名，上传 OSS 后首次播放时下载。
"""

import argparse
import asyncio
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

from pypinyin import Style, pinyin

ROOT = Path(__file__).resolve().parent.parent
AUDIO_OUT = ROOT / 'assets' / 'audio' / 'pinyin'
VOICE = 'zh-CN-XiaoxiaoNeural'


def audio_key(word: str) -> str:
    """与 lib/data/pinyin_audio.dart 一致：按 UTF-16 编码，与列表位置无关。"""
    return 'py_' + ''.join(format(ord(ch), '04x') for ch in word)


def audio_jobs() -> list[tuple[str, str]]:
    jobs = []
    for groups in GRADES.values():
        for words in groups.values():
            jobs.extend((audio_key(word), word) for word in words)
    return list(dict.fromkeys(jobs))

# pypinyin 按词取音仍会出错的，在这里定向修正（键为汉字词，值为读音列表）。
OVERRIDES = {
    '花儿': ['huā', 'r'],          # 儿化，不自成音节
    '一会儿': ['yī', 'huì', 'r'],
    '哪儿': ['nǎ', 'r'],
    '小孩儿': ['xiǎo', 'hái', 'r'],
    '面条儿': ['miàn', 'tiáo', 'r'],
    '闹钟': ['nào', 'zhōng'],

    # 亲属称谓的叠词：第二字一律轻声（《现代汉语词典》口径）。
    # pypinyin 对「弟弟/伯伯/婆婆」给了轻声，但对下面这几个给了原调，故定向修正。
    '爸爸': ['bà', 'ba'],
    '妈妈': ['mā', 'ma'],
    '哥哥': ['gē', 'ge'],
    '姐姐': ['jiě', 'jie'],
    '妹妹': ['mèi', 'mei'],

    # 口语轻声：衣服的「服」读 fu，不读 fú。
    '衣服': ['yī', 'fu'],

    '算了': ['suàn', 'le'],        # 轻声
    '好了': ['hǎo', 'le'],
    '对的': ['duì', 'de'],
    '地': ['dì'],                  # 单字取常用音，避免 pypinyin 给 de
    '啊': ['a'],                   # 语气词轻声
    '呢': ['ne'],
    '吧': ['ba'],
    '吗': ['ma'],
}

# 年级 → (词表, 分组)。分组是该词的语音特征，用于学习页筛选与干扰项构造。
# 内容按拼音教学规律组织，不声称出自某一册教材。
GRADES = {
    1: {
        '单韵母与声母': ['爸妈', '大米', '土地', '马路', '哥哥', '弟弟', '姐姐', '妹妹',
                    '爸爸', '妈妈', '伯伯', '婆婆', '木马', '梨', '皮', '笔', '米',
                    '鼻', '鸡', '七', '西', '衣', '鱼', '五', '屋', '雨', '玉',
                    '马', '木', '土', '大', '口', '手', '日', '月',
                    '山', '田', '水', '火', '云', '风', '鸟', '虫', '花'],
        '拼读词语': ['爸爸', '妈妈', '大米', '马路', '土地', '哥哥', '弟弟', '衣服',
                 '飞机', '气球', '西瓜', '母鸡', '毛笔', '图画', '读书', '桌子',
                 '椅子', '乌鸦', '鲤鱼', '雨衣', '苹果', '白菜', '大门', '毛衣',
                 '河水', '白云', '午饭', '课本', '花朵', '小鱼'],
    },
    2: {
        '复韵母与鼻韵母': ['白菜', '黑板', '排队', '杯子', '飞机', '乌龟', '书包',
                     '小猫', '小牛', '写字', '月亮', '云朵', '高山', '台灯', '光明',
                     '中国', '苹果', '太阳', '雪花', '春天', '江河', '森林', '朋友',
                     '彩笔', '外婆', '铃铛', '风筝', '池塘', '海鸥', '熊猫',
                     '葡萄', '香蕉', '草莓', '蜻蜓', '蝴蝶', '蚂蚁'],
        '轻声与儿化': ['桌子', '椅子', '包子', '馒头', '石头', '木头', '花儿', '哪儿',
                  '一会儿', '小孩儿', '面条儿', '盒子', '肚子', '舌头', '枕头',
                  '帽子', '被子', '筷子', '袜子', '鞋子', '风筝', '口袋', '窗户'],
    },
    3: {
        '平翘舌音': ['自己', '紫色', '刺猬', '四个', '知识', '织毛衣', '吃饭', '老师',
                 '日子', '字典', '词语', '四季', '手指', '长城', '上班', '认真',
                 '写字', '十几', '实际', '认真', '扇子', '舒展', '总是', '擦桌子',
                 '草房子', '蛐蛐', '嘴唇', '树枝', '实在'],
        '前后鼻音': ['班级', '早晨', '金子', '困难', '军人', '白云', '帮忙', '朋友',
                 '听讲', '明天', '东西', '红花', '黑板', '森林', '春天', '长城',
                 '均匀', '灵魂', '健康', '强壮', '行李', '眼睛', '神情', '英雄',
                 '北方', '乒乓球', '灯光', '奋勇'],
    },
    4: {
        '易错声母': ['牛奶', '老牛', '河流', '暖和', '南方', '蓝色', '绿色', '努力',
                 '女子', '老师', '鼻子', '李子', '山顶', '闪电', '节约', '钥匙',
                 '脑袋', '老少', '泥土', '糯米', '冷热', '年龄', '练字', '篮球',
                 '朗读', '柠檬', '肉类', '柔软'],
        '易错韵母': ['学校', '学习', '月亮', '约定', '圆圈', '公园', '白云', '运动',
                 '英雄', '穷苦', '熊猫', '涌泉', '永恒', '游泳', '勇敢', '永远',
                 '选择', '宣传', '旋转', '宣言', '悬崖', '询问', '训练', '迅速',
                 '轮渡', '伦敦', '温和', '温暖'],
    },
    5: {
        '多音字·常用': ['长大', '长短', '银行', '行走', '重要', '重复', '快乐', '音乐',
                   '好奇', '爱好', '数学', '数一数', '中间', '中奖', '得到', '觉得',
                   '知了', '了解', '积累', '劳累', '煮饭', '曲折', '歌曲', '宝藏',
                   '收藏', '种树', '播种'],
        '多音字·进阶': ['喝水', '喝彩', '答应', '回答', '睡觉', '感觉', '班级', '播种',
                   '散步', '散文', '传说', '传记', '便宜', '方便', '处理', '到处',
                   '打更', '更换', '归还', '还是', '还书', '快乐', '乐器',
                   '等待', '待遇'],
    },
    6: {
        '多音字·辨析': ['等待', '待遇', '单于', '单独', '调节', '调皮', '恶习', '厌恶',
                   '方便', '便宜', '供应', '应该', '几乎', '几个', '假期', '真假',
                   '结巴', '结束', '看见', '看守', '蒙骗', '蒙古', '蒙着', '附和',
                   '和平', '和面', '泊船', '湖泊', '倔强', '强壮', '强迫'],
        '进阶易错音': ['塑料', '的确', '处理', '矗立', '教诲', '憎恶', '潜力', '强迫',
                  '勉强', '折腾', '剥削', '同胞', '浸透', '朴素', '隐蔽', '绚烂',
                  '倔强', '切磋', '徘徊', '憧憬', '堕落', '静谧', '玷污', '吞噬',
                  '咀嚼', '浸润', '凝重', '忏悔'],
    },
}


def reading_of(word: str) -> list[str]:
    if word in OVERRIDES:
        return OVERRIDES[word]
    return [x[0] for x in pinyin(word, style=Style.TONE, heteronym=False)]


def dart_escape(s: str) -> str:
    return s.replace("'", r"\'")


def build(audio: bool = False):
    entries = []
    seen = set()
    problems = []

    for grade in sorted(GRADES):
        for group, words in GRADES[grade].items():
            for w in words:
                if w in seen:
                    continue
                # 过滤掉混入的非汉字（防止词表里出现占位或英文）
                if not all('\u4e00' <= ch <= '\u9fff' for ch in w):
                    problems.append(f'非汉字词，跳过：{w}')
                    continue
                reading = reading_of(w)
                # 读音音节数必须与汉字数一致（儿化除外：花儿 huā r 两个音节两个字符）
                if len(reading) != len(w) and 'r' not in reading:
                    problems.append(f'音节数不符：{w} → {reading}')
                    continue
                seen.add(w)
                entries.append({
                    'word': w,
                    'reading': ' '.join(reading),
                    'group': group,
                    'grade': grade,
                })

    lines = [
        "import '../models/poem.dart';",
        "",
        "/// 拼音题库：按小学年级难度递增组织。",
        "///",
        "/// **来源说明**：内容按拼音教学规律编写（一年级声韵母与拼读、二年级复韵母与轻声、",
        "/// 三年级平翘舌与前后鼻音、四年级易错声韵母、五六年级多音字与进阶易错音），",
        "/// 不声称出自某一册教材。读音由 pypinyin 按词组计算，多音字取词内读音。",
        "///",
        "/// 条目复用 [Poem]：`title` 是字词、`author` 是带调拼音、`dynasty` 是分组、",
        "/// `lines` 是提示（该词属于哪类语音现象）。",
        "const List<Poem> kPinyin = <Poem>[",
    ]

    last_grade = None
    last_group = None
    for e in entries:
        if e['grade'] != last_grade:
            lines.append(f"  // ── {e['grade']} 年级 ──")
            last_grade = e['grade']
            last_group = None
        if e['group'] != last_group:
            lines.append(f"  // {e['group']}")
            last_group = e['group']
        word = dart_escape(e['word'])
        reading = dart_escape(e['reading'])
        group = dart_escape(e['group'])
        lines.append(
            f"  Poem(title: '{word}', author: '{reading}', "
            f"dynasty: '{group}', grade: {e['grade']}, lines: ['{group}']),"
        )
    lines.append("];")
    lines.append("")

    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       'lib', 'data', 'pinyin.dart')
    with open(out, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines))

    by_grade = {}
    for e in entries:
        by_grade[e['grade']] = by_grade.get(e['grade'], 0) + 1
    print(f'写入 {out}')
    print(f'条目 {len(entries)} 条，按年级：{by_grade}')
    if problems:
        print(f'跳过 {len(problems)} 条：')
        for p in problems:
            print('  ', p)

    if audio:
        asyncio.run(synth(entries))


async def synth(entries: list[dict]) -> None:
    """固定中文音色生成字词语音；失败可续跑，不因单条超时空等整批。"""
    import edge_tts

    AUDIO_OUT.mkdir(parents=True, exist_ok=True)
    semaphore = asyncio.Semaphore(4)
    failures = []

    async def one(entry: dict) -> None:
        name = audio_key(entry['word'])
        if (AUDIO_OUT / f'{name}.opus').exists() or (AUDIO_OUT / f'{name}.mp3').exists():
            return
        async with semaphore:
            for attempt in range(3):
                try:
                    await asyncio.wait_for(
                        edge_tts.Communicate(entry['word'], VOICE, rate='-15%').save(
                            str(AUDIO_OUT / f'{name}.mp3')
                        ),
                        timeout=30,
                    )
                    print(f"  synth {name}: {entry['word']}", flush=True)
                    return
                except (TimeoutError, OSError) as exc:
                    print(f"  retry {name}: {type(exc).__name__}", flush=True)
            failures.append(entry['word'])

    await asyncio.gather(*(one(entry) for entry in entries))
    if failures:
        print(f'合成失败 {len(failures)} 条，重跑可续传：{failures}', flush=True)

    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        raise RuntimeError('找不到 ffmpeg，无法生成 opus')
    for mp3 in AUDIO_OUT.glob('*.mp3'):
        opus = mp3.with_suffix('.opus')
        if not opus.exists():
            subprocess.run(
                [ffmpeg, '-y', '-loglevel', 'error', '-i', str(mp3),
                 '-c:a', 'libopus', '-b:a', '32k', '-ac', '1', '-ar', '24000', str(opus)],
                check=True,
            )
    manifest = {
        'voice': VOICE,
        'count': len(entries),
        'files': [audio_key(entry['word']) for entry in entries],
        'words': {audio_key(entry['word']): entry['word'] for entry in entries},
    }
    with (AUDIO_OUT / 'manifest.json').open('w', encoding='utf-8', newline='\n') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f'音频 {len(entries)} 条，写入 {AUDIO_OUT.relative_to(ROOT)}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--audio', action='store_true', help='合成字词点读音频')
    parser.add_argument('--keep-mp3', action='store_true', help='转码后保留 mp3')
    args = parser.parse_args()
    build(audio=args.audio)
    if args.audio and len(list(AUDIO_OUT.glob('*.opus'))) != len(audio_jobs()):
        sys.exit('音频未生成齐全，请重跑补齐后再上传')
    if args.audio and not args.keep_mp3:
        for mp3 in AUDIO_OUT.glob('*.mp3'):
            mp3.unlink()
