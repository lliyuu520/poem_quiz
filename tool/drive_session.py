"""驱动一局答题到结束，返回过程中出现过的诗名，用于验证生涯模式不重复出诗。

只做 UI 自动化，不改被测代码。用法：
    python -I drive_session.py <adb> <max_steps>
"""

import re
import subprocess
import sys
import time

ADB = sys.argv[1]
MAX_STEPS = int(sys.argv[2]) if len(sys.argv) > 2 else 80


def sh(args):
    return subprocess.run(
        [ADB] + args, capture_output=True, text=True, encoding="utf-8", errors="replace"
    ).stdout


def nodes():
    sh(["shell", "uiautomator dump /sdcard/ui.xml"])
    xml = sh(["shell", "cat /sdcard/ui.xml"])
    out = []
    for m in re.finditer(
        r'content-desc="([^"]*)"([^>]*?)bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', xml
    ):
        desc, rest = m.group(1), m.group(2)
        x1, y1, x2, y2 = map(int, m.groups()[2:])
        out.append(
            {
                "desc": desc,
                "clickable": 'clickable="true"' in rest,
                "cx": (x1 + x2) // 2,
                "cy": (y1 + y2) // 2,
            }
        )
    return out


def tap(x, y):
    sh(["shell", f"input tap {x} {y}"])


seen_titles = []
for step in range(MAX_STEPS):
    ns = nodes()

    if any("从头再来" in n["desc"] or "腹有诗书" in n["desc"] or "渐入佳境" in n["desc"]
           or "尚需温习" in n["desc"] or "出口成章" in n["desc"] for n in ns):
        print("reached result page")
        break

    # 记录当前题目里出现的诗名（反馈区形如「唐 · 王翰《凉州词》」）
    for n in ns:
        for m in re.finditer(r"《([^》]+)》", n["desc"]):
            t = m.group(1)
            if t not in seen_titles:
                seen_titles.append(t)

    nxt = [n for n in ns if n["clickable"] and ("下一题" in n["desc"] or "查看结果" in n["desc"])]
    if nxt:
        tap(nxt[0]["cx"], nxt[0]["cy"])
        time.sleep(1.1)
        continue

    # 字块优先（单字），否则点第一个选项。
    # 注意：uiautomator 输出里的换行是 XML 实体 &#10;，不是真实换行符。
    chars = [n for n in ns if n["clickable"] and len(n["desc"].strip()) == 1 and "\n" not in n["desc"]]
    if chars:
        for n in chars[:4]:
            tap(n["cx"], n["cy"])
            time.sleep(0.4)
        time.sleep(1.0)
        continue

    opts = [
        n for n in ns
        if n["clickable"] and ("&#10;" in n["desc"] or "\n" in n["desc"])
        and "退出" not in n["desc"] and "已选" not in n["desc"]
        and "学习模式" not in n["desc"] and "错题本" not in n["desc"]
    ]
    if opts:
        tap(opts[0]["cx"], opts[0]["cy"])
        time.sleep(1.1)
        continue

    print(f"step {step}: no action, stop")
    break

print("titles seen:", len(seen_titles))
for t in seen_titles:
    print(" -", t)
