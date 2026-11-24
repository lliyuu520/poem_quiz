"""文学常识题库生成器：literature_bank.json → lib/data/literature.dart。

用法：
    python -I tool/gen_literature.py

为什么不手写 Dart：
题库是内容产品，48 条里只要有一条答案抄错、一个 id 撞车，就是给孩子错误输入。
生成器让 JSON 成为唯一事实来源，并在生成前做完整性校验（答案单 token、id 唯一、
题干/答案非空、年级合法），校验不过直接报错退出，不产出半成品。

`Poem` 字段映射：
    title  = 条目名（唯一锚点，用于 id 与去重、列表短名）
    author = 答案（单一 token，干扰项从这里取）
    dynasty = 分组（字号/并称/流派/体裁/文学史/拓展）
    lines  = [题干描述, 解析(note)]；题干是出题主体，note 可为空串占位
    grade  = 年级（7-9；0 = 拓展）
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "tool" / "literature_bank.json"
DART_OUT = ROOT / "lib" / "data" / "literature.dart"


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
    for e in entries:
        for key in ("title", "answer", "group", "prompt"):
            if not str(e.get(key, "")).strip():
                problems.append(f"条目缺字段 {key}：{e}")
        t = e["title"]
        if t in seen_title:
            problems.append(f"title 重复：{t}")
        seen_title.add(t)

        # 答案必须是单一 token：出现「与」「、」多半是「A与B」型并称答案，
        # 会造出「正确答案是 A 与 B，干扰项却是 A」这种半对陷阱。
        a = e["answer"]
        if "与" in a or "、" in a:
            problems.append(f"答案不是单 token（含 与/、）：{t} → {a}")

        g = e["grade"]
        if not (g == 0 or 7 <= g <= 9):
            problems.append(f"年级越界（只允许 0 或 7-9）：{t} → {g}")

        pid = f"{e['group']}|{e['answer']}|{e['title']}"
        if pid in seen_id:
            problems.append(f"id 重复：{pid}")
        seen_id.add(pid)

    # 答案池至少要能凑出一个 4 选项题的干扰项。
    distinct_answers = {e["answer"] for e in entries}
    if len(distinct_answers) < 4:
        problems.append(f"不同答案只有 {len(distinct_answers)} 个，凑不齐 4 选项题")

    return problems


def dart_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def emit_dart(bank: dict) -> str:
    lines: list[str] = []
    add = lines.append

    add("// 由 tool/gen_literature.py 从 tool/literature_bank.json 生成，不要手改。")
    add("// 改题库请改 JSON 后重跑脚本。")
    add("")
    add("import '../models/poem.dart';")
    add("")
    add("/// 文学常识条目：")
    add("/// `title` 是条目短名（唯一锚点，用于 id 与列表），`author` 是答案（单一 token），")
    add("/// `dynasty` 是分组（字号/并称/流派/体裁/文学史/拓展），")
    add("/// `lines` 是 [题干描述, 解析]（解析可为空串），`grade` 是年级（7-9；0 = 拓展）。")
    add("///")
    add("/// 内容边界：只考诗词科目考不到的（并称/字号/流派/体裁/文学史常识），")
    add("/// 不做「名句→作者」——那是诗词科目的 author/title 题型。")
    add("const List<Poem> kLiterature = <Poem>[")
    for e in bank["entries"]:
        note = str(e.get("note", "")).strip()
        add(
            "  Poem(title: {}, author: {}, dynasty: {}, grade: {}, lines: <String>[{}, {}]),".format(
                dart_str(e["title"]),
                dart_str(e["answer"]),
                dart_str(e["group"]),
                e["grade"],
                dart_str(e["prompt"]),
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
