"""错别字/形近字题库生成器：typo_bank.json → lib/data/typo.dart。

用法：
    python -I tool/gen_typo.py

字段映射：
    title   = 正确词形（唯一锚点 + 正确答案），如「部署」
    author  = 本条错写（用「|」连接，如「布署」）；出题时作为真陷阱选项
    dynasty = 分组（同音/形近/成语易错）
    lines   = [语境句, 辨析提示]
    grade   = 年级（4-9；0 = 拓展）

选项构成：正确词 + 本条错写 + 别的条目的正确词补齐 4 项。错写是本条的真实陷阱，
其余干扰来自别的条目（排除同词），既不跨义也不泄题。
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "tool" / "typo_bank.json"
DART_OUT = ROOT / "lib" / "data" / "typo.dart"

# 错写在 Poem.author 里用这个分隔符连接，引擎按它 split。
WRONG_SEP = "|"


def load_bank() -> dict:
    with BANK.open(encoding="utf-8") as f:
        return json.load(f)


def check_bank(bank: dict) -> list[str]:
    """返回问题列表。空列表表示题库可用。"""
    problems: list[str] = []
    entries = bank["entries"]
    if not entries:
        return ["题库为空"]

    seen_word = set()
    seen_id = set()
    for e in entries:
        for key in ("word", "context", "hint", "group"):
            if not str(e.get(key, "")).strip():
                problems.append(f"条目缺字段 {key}：{e.get('word')}")

        w = e["word"]
        if w in seen_word:
            problems.append(f"正确词重复：{w}")
        seen_word.add(w)

        wrongs = e.get("wrong", [])
        if not wrongs:
            problems.append(f"缺错写：{w}")
        if w in wrongs:
            problems.append(f"错写列表含正确词：{w}")
        if len(set(wrongs)) != len(wrongs):
            problems.append(f"错写有重复：{w} → {wrongs}")
        # 错写里不能混入分隔符，否则 author 解析会错位。
        if any(WRONG_SEP in x for x in wrongs):
            problems.append(f"错写含分隔符「{WRONG_SEP}」：{w}")

        g = e["grade"]
        if not (g == 0 or 4 <= g <= 9):
            problems.append(f"年级越界（只允许 0 或 4-9）：{w} → {g}")

        pid = f"{e['group']}|{e['word']}|{e['word']}"
        if pid in seen_id:
            problems.append(f"id 重复：{pid}")
        seen_id.add(pid)

    # 至少 3 条别的正确词可用来补干扰项。
    if len(entries) < 4:
        problems.append(f"题库只有 {len(entries)} 条，凑不齐 4 选项题")

    return problems


def dart_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def emit_dart(bank: dict) -> str:
    lines: list[str] = []
    add = lines.append

    add("// 由 tool/gen_typo.py 从 tool/typo_bank.json 生成，不要手改。")
    add("// 改题库请改 JSON 后重跑脚本。")
    add("")
    add("import '../models/poem.dart';")
    add("")
    add("/// 错别字条目：")
    add("/// `title` 是正确词形（唯一锚点 + 正确答案），`author` 是错写（多个用 `|` 连接），")
    add("/// `dynasty` 是分组（同音/形近/成语易错），`lines` 是 [语境句, 辨析提示]，")
    add("/// `grade` 是年级（4-9；0 = 拓展）。")
    add("///")
    add("/// 出题时选项 = 正确词 + 本条错写（真陷阱）+ 别的条目正确词补齐，")
    add("/// 错写是孩子最容易犯的错，留在选项里才有辨析价值。")
    add("const List<Poem> kTypo = <Poem>[")
    for e in bank["entries"]:
        wrongs = WRONG_SEP.join(e["wrong"])
        add(
            "  Poem(title: {}, author: {}, dynasty: {}, grade: {}, lines: <String>[{}, {}]),".format(
                dart_str(e["word"]),
                dart_str(wrongs),
                dart_str(e["group"]),
                e["grade"],
                dart_str(e["context"]),
                dart_str(e["hint"]),
            )
        )
    add("];")
    add("")
    add("/// 错写在 `Poem.author` 里的分隔符，引擎按它切分。")
    add(f"const String kTypoWrongSep = '{WRONG_SEP}';")
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