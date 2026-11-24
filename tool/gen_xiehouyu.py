"""歇后语题库生成器：xiehouyu_bank.json → lib/data/xiehouyu.dart。

用法：
    python -I tool/gen_xiehouyu.py

字段映射：
    title   = 前半（题干锚点，用于 id 与去重）
    author  = 后半（答案；「选后半」题从答案池取干扰项）
    dynasty = 分组（谐音/喻事/喻物/故事）
    lines   = [释义与用法]
    grade   = 年级（4-9；0 = 拓展）
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "tool" / "xiehouyu_bank.json"
DART_OUT = ROOT / "lib" / "data" / "xiehouyu.dart"


def load_bank() -> dict:
    with BANK.open(encoding="utf-8") as f:
        return json.load(f)


def check_bank(bank: dict) -> list[str]:
    """返回问题列表。空列表表示题库可用。"""
    problems: list[str] = []
    entries = bank["entries"]
    if not entries:
        return ["题库为空"]

    seen_title = set()
    seen_id = set()
    seen_answer = set()
    for e in entries:
        for key in ("title", "answer", "group", "meaning"):
            if not str(e.get(key, "")).strip():
                problems.append(f"条目缺字段 {key}：{e.get('title')}")

        t = e["title"]
        if t in seen_title:
            problems.append(f"前半重复：{t}")
        seen_title.add(t)

        # 后半必须唯一：「选后半」题的干扰项来自别的后半，
        # 若两条前半共用一个后半，选项里就会出现两个正确答案。
        a = e["answer"]
        if a in seen_answer:
            problems.append(f"后半重复（会产生两个正确答案）：{a}")
        seen_answer.add(a)

        g = e["grade"]
        if not (g == 0 or 4 <= g <= 9):
            problems.append(f"年级越界（只允许 0 或 4-9）：{t} → {g}")

        pid = f"{e['group']}|{e['answer']}|{e['title']}"
        if pid in seen_id:
            problems.append(f"id 重复：{pid}")
        seen_id.add(pid)

    if len(entries) < 4:
        problems.append(f"题库只有 {len(entries)} 条，凑不齐 4 选项题")

    return problems


def dart_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def emit_dart(bank: dict) -> str:
    lines: list[str] = []
    add = lines.append

    add("// 由 tool/gen_xiehouyu.py 从 tool/xiehouyu_bank.json 生成，不要手改。")
    add("// 改题库请改 JSON 后重跑脚本。")
    add("")
    add("import '../models/poem.dart';")
    add("")
    add("/// 歇后语条目：")
    add("/// `title` 是前半，`author` 是后半（答案），`dynasty` 是分组")
    add("/// （谐音/喻事/喻物/故事），`lines` 是释义与用法，`grade` 是年级（4-9；0 = 拓展）。")
    add("///")
    add("/// 后半唯一：两条前半不能共用一个后半，否则「选后半」会出现两个正确答案。")
    add("const List<Poem> kXiehouyu = <Poem>[")
    for e in bank["entries"]:
        add(
            "  Poem(title: {}, author: {}, dynasty: {}, grade: {}, lines: <String>[{}]),".format(
                dart_str(e["title"]),
                dart_str(e["answer"]),
                dart_str(e["group"]),
                e["grade"],
                dart_str(e["meaning"]),
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
