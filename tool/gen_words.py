"""词语题库生成器：tool/word_bank.json → lib/data/words.dart。

用法：
    python -I tool/gen_words.py

为什么用脚本生成而不是手打 Dart：
每个词要列出完整的同义词集与反义词集，脚本据此做对称 + 传递闭包，
保证运行时「排除该词的全部同义词/反义词」成立——否则干扰项里会混进
另一个正确答案，给孩子一道有两个说得通答案的题。这和成语「知词义」
排除释义里提到的成语是同一类坑。

数据形态：一条 Poem = 一个「词 → 关系词」条目。
    title   → 词条（如「高兴」）
    author  → 关系词（如「快乐」）
    dynasty → 关系类型（「同义词」/「反义词」）
    lines   → 例句
    grade   → 年级
id = dynasty|author|title，天然唯一，无需改存档契约。
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "tool" / "word_bank.json"
DART_OUT = ROOT / "lib" / "data" / "words.dart"

SYN = "同义词"
ANT = "反义词"


def load_bank() -> list[dict]:
    with BANK.open(encoding="utf-8") as f:
        data = json.load(f)
    return data["words"]


def validate(raw: list[dict]) -> None:
    """入口校验：词条唯一、年级合法、关系不自相矛盾。"""
    subjects: set[str] = set()
    for item in raw:
        word = item["w"]
        if word in subjects:
            raise ValueError(f"词条重复：{word}")
        subjects.add(word)
        if not 1 <= item["g"] <= 6:
            raise ValueError(f"{word} 年级非法：{item['g']}")
        syn, ant = set(item["syn"]), set(item["ant"])
        if word in syn or word in ant:
            raise ValueError(f"{word} 的关系集包含自身")
        if syn & ant:
            raise ValueError(f"{word} 的同义与反义集冲突：{syn & ant}")


def closure(raw: list[dict]) -> tuple[dict[str, set[str]], dict[str, set[str]], dict[str, int]]:
    """对称 + 传递闭包。

    关系词里有些只是答案词、不作为词条单独出题（如「愉快」），它们仍参与闭包，
    否则排除「高兴的全部同义词」时会漏掉它，干扰项里就会混进第二个正确答案。
    只有 `w` 字段声明的词有 grade 与例句、会生成条目；其余只当图节点。

    同义：无向图的连通分量，分量内任意两词互为同义。
    反义：先对称化声明的反义对，再沿同义传播（A 的同义词的反义词也是 A 的反义词）。
    """
    by_word = {item["w"]: item for item in raw}
    grades = {item["w"]: item["g"] for item in raw}
    all_words: set[str] = set(by_word)
    for item in raw:
        all_words |= set(item["syn"]) | set(item["ant"])

    # 同义无向图
    parent: dict[str, str] = {w: w for w in all_words}

    def find(x: str) -> str:
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a: str, b: str) -> None:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    for item in raw:
        for s in item["syn"]:
            union(item["w"], s)

    components: dict[str, set[str]] = {}
    for w in all_words:
        components.setdefault(find(w), set()).add(w)

    syn: dict[str, set[str]] = {}
    for w in all_words:
        syn[w] = components[find(w)] - {w}

    # 反义：对称化声明
    ant: dict[str, set[str]] = {w: set() for w in all_words}
    for item in raw:
        for a in item["ant"]:
            ant[item["w"]].add(a)
            ant[a].add(item["w"])

    # 沿同义传播：同义词的反义词也是自己的反义词，反义词的同义词也是自己的反义词
    changed = True
    while changed:
        changed = False
        for w in all_words:
            extra = set()
            for s in syn[w]:
                extra |= ant[s]
            for a in ant[w]:
                extra |= syn[a]
            extra.discard(w)
            if not extra <= ant[w]:
                ant[w] |= extra
                changed = True

    # 剔除与同义集重叠的反义词（否则同义词题里会出现另一个正确答案）
    for w in by_word:
        conflict = syn[w] & ant[w]
        if conflict:
            raise ValueError(f"{w} 闭包后同义/反义冲突：{conflict}")
    return syn, ant, grades


def dart_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def generate() -> str:
    raw = load_bank()
    validate(raw)
    syn, ant, grades = closure(raw)

    # 题目只从**人工挑选**的关系对生成，不用闭包——闭包会带出「坏→优秀」
    # 这类语法上说得通、但对孩子别扭的题。闭包只用于干扰项排除（见下方 map）。
    entries: list[tuple[int, str]] = []
    for item in raw:
        w = item["w"]
        example = item["ex"]
        for rel_type, key in ((SYN, "syn"), (ANT, "ant")):
            for other in sorted(set(item[key])):
                entries.append((
                    grades[w],
                    f"  Poem(title: {dart_str(w)}, author: {dart_str(other)}, "
                    f"dynasty: {dart_str(rel_type)}, grade: {grades[w]}, "
                    f"lines: <String>[{dart_str(example)}]),",
                ))

    entries.sort(key=lambda e: (e[0], e[1]))
    by_grade: dict[int, list[str]] = {}
    for g, line in entries:
        by_grade.setdefault(g, []).append(line)

    # 闭包关系集：引擎按 title 查它，排除「同义题里另一个也说不通的答案」。
    def emit_relation_map(name: str, relation: dict[str, set[str]]) -> str:
        rows = []
        for w in sorted(by_word_keys(raw)):
            values = ", ".join(dart_str(x) for x in sorted(relation[w]))
            rows.append(f"  {dart_str(w)}: <String>[{values}],")
        return (
            f"const Map<String, List<String>> {name} = <String, List<String>>{{\n"
            + "\n".join(rows)
            + "\n};\n"
        )

    lines = [
        "// 由 tool/gen_words.py 从 tool/word_bank.json 生成，不要手改。",
        "// 题目只取人工挑选的关系对；下面的闭包 map 只用于干扰项排除，",
        "// 保证同义题的选项里不会混进该词的另一个同义词。",
        "",
        "import '../models/poem.dart';",
        "",
        "/// 词语题库：每条是一个「词 → 关系词」。",
        "/// `title` 是词条，`author` 是关系词，`dynasty` 是关系类型（同义词/反义词），",
        "/// `lines` 是例句，`grade` 是年级（1~6）。",
        "/// id = `dynasty|author|title` 自动唯一。",
        "const List<Poem> kWords = <Poem>[",
    ]
    for g in sorted(by_grade):
        lines.append(f"  // ── {g} 年级 ──")
        lines.extend(by_grade[g])
    lines.append("];")
    lines.append("")
    lines.append("/// 每个词的全部同义词（含传递），用于出题时排除干扰项里的第二个正确答案。")
    lines.append(emit_relation_map("kWordSynonyms", syn))
    lines.append("/// 每个词的全部反义词（含传递），用于出题时排除干扰项里的第二个正确答案。")
    lines.append(emit_relation_map("kWordAntonyms", ant))
    return "\n".join(lines)


def by_word_keys(raw: list[dict]) -> set[str]:
    """只有 w 字段声明的词才有题目，闭包 map 也只需为它们生成。"""
    return {item["w"] for item in raw}


if __name__ == "__main__":
    text = generate()
    DART_OUT.write_text(text, encoding="utf-8", newline="\n")
    count = text.count("Poem(title:")
    print(f"生成 {DART_OUT.relative_to(ROOT)}：{count} 条")
