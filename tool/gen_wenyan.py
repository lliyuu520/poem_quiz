"""文言实词题库生成器：wenyan_bank.json → lib/data/wenyan.dart。

用法：
    python -I tool/gen_wenyan.py

字段映射：
    title   = 文言词（如「之」；用于 id，故带例句序号保证唯一）
    author  = 该词在本句中的意思（答案，单一释义）
    dynasty = 实虚类别（实词 / 虚词）
    lines   = [例句（目标词用〈〉标出）, 解析]
    grade   = 年级（7-9；0 = 拓展）

一词多义靠例句锚定：同一个「之」在不同句里意思不同，所以 title 不是裸「之」，
而是「之@例句」，保证 id 唯一、题干也带上下文。
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "tool" / "wenyan_bank.json"
DART_OUT = ROOT / "lib" / "data" / "wenyan.dart"


def load_bank() -> dict:
    with BANK.open(encoding="utf-8") as f:
        return json.load(f)


def check_bank(bank: dict) -> list[str]:
    """返回问题列表。空列表表示题库可用。"""
    problems: list[str] = []
    entries = bank["entries"]
    if not entries:
        return ["题库为空"]

    seen_sentence = set()
    seen_id = set()
    for e in entries:
        for key in ("sentence", "word", "meaning", "usage"):
            if not str(e.get(key, "")).strip():
                problems.append(f"条目缺字段 {key}：{e.get('sentence')}")

        if "〈" not in e["sentence"] or "〉" not in e["sentence"]:
            problems.append(f"例句缺〈〉目标词标注：{e['sentence']}")

        s = e["sentence"]
        if s in seen_sentence:
            problems.append(f"例句重复：{s}")
        seen_sentence.add(s)

        g = e["grade"]
        if not (g == 0 or 7 <= g <= 9):
            problems.append(f"年级越界（只允许 0 或 7-9）：{s} → {g}")

        # id 用「类别|释义|词@例句」，例句唯一即 id 唯一。
        pid = f"{e['usage']}|{e['meaning']}|{e['word']}@{s}"
        if pid in seen_id:
            problems.append(f"id 重复：{pid}")
        seen_id.add(pid)

    # 不同释义 ≥ 4 才能凑出 4 选项题的干扰项。
    distinct = {e["meaning"] for e in entries}
    if len(distinct) < 4:
        problems.append(f"不同释义只有 {len(distinct)} 个，凑不齐 4 选项题")

    return problems


def dart_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def emit_dart(bank: dict) -> str:
    lines: list[str] = []
    add = lines.append

    add("// 由 tool/gen_wenyan.py 从 tool/wenyan_bank.json 生成，不要手改。")
    add("// 改题库请改 JSON 后重跑脚本。")
    add("")
    add("import '../models/poem.dart';")
    add("")
    add("/// 文言实词条目（一词多义靠例句锚定）：")
    add("/// `title` 是「词@例句」（保证 id 唯一、题干带上下文），")
    add("/// `author` 是该词在本句中的意思（答案），`dynasty` 是实虚类别，")
    add("/// `lines` 是 [例句（目标词用〈〉标出）, 解析]，`grade` 是年级（7-9；0 = 拓展）。")
    add("const List<Poem> kWenyan = <Poem>[")
    for e in bank["entries"]:
        note = str(e.get("note", "")).strip()
        add(
            "  Poem(title: {}, author: {}, dynasty: {}, grade: {}, lines: <String>[{}, {}]),".format(
                dart_str(f"{e['word']}@{e['sentence']}"),
                dart_str(e["meaning"]),
                dart_str(e["usage"]),
                e["grade"],
                dart_str(e["sentence"]),
                dart_str(note),
            )
        )
    add("];")
    add("")
    return "\n".join(lines)


def main() -> int:
    bank = load_bank()
    problems = check_bank(bank)
    if problems:
        print("题库校验未通过：")
        for p in problems:
            print("  -", p)
        return 1
    DART_OUT.write_text(emit_dart(bank), encoding="utf-8", newline="\n")
    print(f"已生成 {DART_OUT.relative_to(ROOT)}（{len(bank['entries'])} 条）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())