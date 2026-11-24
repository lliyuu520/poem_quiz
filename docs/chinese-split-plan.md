# 语文拆散：归组导航 + 4 个子科目

> 对应待办表：`docs/development-progress.md`「功能待办表」第一行
> 最后更新：2026-11-24（拍板顶层导航：**数独偏游戏、独立入口**，主 tab 收敛为语文 / 数学 / 英语三科）

## 0. 需要先确认的假设

- **A1**：现在的「诗词 / 拼音 / 成语」已经是语文拆出来的三块，本功能是「再拆四块 + 给它们一个归组入口」，不是重做科目抽象。
- **A2**：归组是**纯 UI 分组**——底层 `Topic` 仍扁平、`kTopics` 仍是单一列表，存档隔离 / 出题引擎 / 根壳切换逻辑都不动。加一层导航不是为了改数据结构。
- **A2b**：数独偏游戏，**从主 tab 拿掉**，改为首页独立入口；主 tab 只留语文 / 数学 / 英语三科。数独仍是 `kTopics` 里的一个 `Topic`（`mode=sudoku`）、进度仍按 `sudoku` 前缀隔离，改动只在导航呈现层：`_TopicTabs` 不再渲染数独，首页另给一个「玩数独」按钮直达其棋盘关卡页。
- **A3**：四个新科目全部出**选择题**（`options` + `answerIndex`），不做主观题、填空题、作文——现有引擎只能客观判分，且干扰项靠同类条目池互取（`quiz_engine.dart:897` `_pickFromOthers`）。
- **A4**：所有新条目复用 `Poem`：`title`=条目名、`author`=答案/副信息、`dynasty`=分组值、`lines`=例句/释义。字段不够用时再建类型，不提前抽象（AGENTS.md 既定约束）。
- **A5**：新题库**由脚本生成**，源数据放 `tool/<name>_bank.json`，不手改生成的 dart 文件——内容产品手敲 150+ 条必出错（拼音/英语已踩过）。
- **A6**：WIP=1。当前无「实现中」功能（英语一年级句子池是「待发布」），本功能可依次推进；每个 T 阶段收口后再开下一个。

## 1. 目标

把语文从三个孤立科目扩成一组有层级的内容：主 tab 收敛为「语文 / 数学 / 英语」三科，语文下挂八个可切换的子科目（诗词、拼音、成语 + 本方案新增四个 + 后并入的词语）；数独偏游戏，从主 tab 拿掉、改首页独立入口。孩子不必在平铺 tab 里找学科，家长也能一眼看出哪些是语文、哪里是玩。

## 2. 当前基线（改造起点）

| 位置 | 现状 |
|---|---|
| `lib/data/topic.dart` | `Topic` 有 `id/name/entries/kinds/groupOf/metaOf/...`，无「学科组」概念 |
| `lib/data/topics.dart` | `kTopics` 平铺 6 个科目，`kPoetryTopic` 等 |
| `lib/pages/home_page.dart:448` | `_TopicTabs` 遍历 `kTopics`，一行 `Expanded` 平铺 |
| `lib/main.dart:78` | `switchTopic()` 换 `_topic`/`_store` 指针，`last_topic` 缓存具体科目 id |
| `lib/models/question.dart` | `QuestionKind` 17 类，每科题型随 `Topic.kinds` 走 |
| 验证基线 | `flutter test` 231 全绿（账号接入时计数），改前先跑一遍确认 |

## 3. 归组设计

### 3.1 数据层

`Topic` 加两个可选字段，其余科目不受影响：

```dart
final String group;        // 学科组 id，默认 'other'
final String? tabLabel;    // 二级 tab 短名，默认 = name
```

`topics.dart` 加组定义：

```dart
const kSubjectGroups = <({String id, String name})>[
  (id: 'chinese', name: '语文'),
  (id: 'math',    name: '数学'),
  (id: 'english', name: '英语'),
];
```

现有科目挂 `group`：诗词/拼音/成语 → `chinese`，数学 → `math`，英语 → `english`。数独是游戏，**不进主 tab、不挂学科组**，从 `kSubjectGroups` 里排除。新科目挂 `group: 'chinese'` 自动归位。

### 3.2 导航层（`_TopicTabs` 改两层 + 数独独立入口）

- 一级行：3 个 `Expanded`，遍历 `kSubjectGroups`（语文 / 数学 / 英语）；点击 = 切到该组「记住的子科目」（默认第一个）。数独**不在这一行**。
- 二级行：**仅当该组科目数 > 1 时渲染**（当前只有语文触发），遍历该组 topic，文字用 `displayTabLabel`。8 个科目用**块状方格**（`Wrap`）而非等分 tab：窄屏四列两行、44dp 高，宽屏 48dp。
- 数独入口：主 tab 之外，在首页给一个独立按钮（如标题区或玩法区旁的「玩数独」），点击 = 切到数独 topic（走 `widget.onSwitchTopic` 同一路径，根壳照常只换 `_topic`/`_store` 指针）。数独页仍是现有棋盘关卡 UI（`_SudokuStages` + 盘面），不改玩法。这样主 tab 是三个学科、数独是与学科并列的「玩」入口，语义清晰。
- 每组记住上次选中的子科目：`Map<String,String>` 存在 `_HomePageState`（不落盘，重启回默认即可），避免从数学切回语文总落在诗词。
- 选中态规则：一级组高亮 = 当前科目所属组；二级 tab 高亮 = 当前科目 id。仍用 `AppColors.seal`，不按组换色（AGENTS.md 视觉规范）。数独入口选中态：当前 `topic.isBoardGame` 时高亮。
- 语文二级 tab 用两字短名：诗词 / 拼音 / 成语 / 常识 / 文言 / 错字 / 歇后。**T2 阶段只有前 3 个**（诗词/拼音/成语），后 4 个随 T3~T6 加科目时挂 `group: 'chinese'` + `tabLabel` 自动出现在二级行——二级行按 `groupTopics.length > 1` 渲染，条目数由题库决定，T2 不预先造空壳 tab。

### 3.3 根壳（不改）

`last_topic` 仍缓存具体科目 id，`main.dart` 用 `kTopics.firstWhere` 定位；首页据 `topic.group` 高亮一级组。`switchTopic()` 逻辑原样保留——切换仍无磁盘 IO。

## 4. 四个子科目设计

条目字段映射统一：

| 字段 | 含义 |
|---|---|
| `title` | 条目名（问题锚点/词条/前半句） |
| `author` | 答案或副信息 |
| `dynasty` | 分组值（如「并称」「字号」「寓言」「动物」） |
| `lines` | 例句/释义/后半句/辨析，多段用 `join('\n')` 展开 |

### 4.1 文学常识（`literature`）

**内容边界：考诗词科目考不到的。** 不做「名句→作者」（诗词已有 `author`/`title` 题型），专做：
- 并称与字号：李杜 / 苏辛 / 青莲居士 / 东坡居士
- 流派与体裁：豪放派 / 婉约派 / 古体诗 / 近体诗 / 词牌
- 文学史常识：史家之绝唱、唐宋八大家等

题型：
- `literaturePick`：题干 = 并称/字号/流派描述，选项 = 人物或流派名
- 干扰项必须排除同答案条目（`_pickFromOthers` 的 `excludePoem` 按 `author` 排除）

年级：7-9 + 拓展（跟随诗词高年级池）。

### 4.2 歇后语 / 谚语（`xiehouyu`）

- 条目：`title`=前半（"外甥打灯笼"）、`author`=后半（"照旧（舅）"）、`lines`=释义与用法。
- 题型 `xiehouyuLink`：给前半选后半，复用接句题的选项渲染；干扰项排除同条。
- 年级：4-9 + 拓展。

### 4.3 错别字 / 形近字（`typo`）

- 条目：`title`=正确词形（"部署"）、`author`=易错提示（"不写'布署'"）、`lines`=辨析。
- 题型：
  - `typoCorrect`：给语境选正确写法，干扰项来自别的条目**且排除同字词**
  - `homophonePick`：给语境选正字（与拼音科目互补，此处考字形）
- 年级：4-9 + 拓展。

### 4.4 文言实词（`wenyan`）

- 条目：`title`=文言词（"之"）、`author`=释义/用法、`dynasty`=虚实类别、`lines`=教材例句。
- 题型：
  - `wenyanMeaning`：给词选释义，干扰项排除同释义条目
  - `wenyanUsage`：给例句选出用法相同的一句（长例句挂 `Question.isLongPrompt` 走正文字号）
- 年级：7-9 + 拓展。内容校验最重，排最后做。

## 5. 数据落盘与隔离

- 每个新科目一个 `id` → `ProgressStore` 天然按 `<topicId>_` 前缀分键，进度/错题本自动隔离，无需改 `progress_store.dart`。
- 不用新增存档字段（`toJson`/`applySnapshot`/`snapshotVersion` 都不动）。
- 若某个新科目题库只跨一个年级，`Topic.graded` 自动为 false，首页隐藏学龄选择——不是错误。
- 云同步：`sync_page.dart` 遍历 `kTopics`，新科目自动出现在列表里，无需改。

## 6. 待决策点（实施前一次性拍板）

| # | 决策点 | 建议 | 影响 |
|---|---|---|---|
| D1 | 文学常识题库归属 | **独立条目**（并称/字号/流派），不从 `kPoems` 派生 | 决定要不要新题库；派生会和诗词题型重复 |
| D2 | 四个科目的收词范围 | 文言/错字**只收教材篇目与高频错例**，歇后语收常用 120~150 条 | 内容产品，范围大了审校成本爆炸 |
| D3 | 题库生成方式 | 每科一个 `tool/<name>_bank.json` + 生成脚本，源数据人审 | 手改 dart 会在下次生成时丢失 |
| D4 | 题型数量 | 每科先 1~2 类选择题，验证链路后再扩 | 题型越多 `_tryMake` switch 越重，测试面越大 |
| D5 | 二级 tab 溢出 | 两字短名；**8 个时改为块状方格**（`Wrap`，窄屏四列两行、44dp 高，宽屏 48dp），不再横滑 | 一行 8 格每格仅约 40dp 读不清；块状在窄屏可两行排完且不牺牲首屏不滚动。原计划的横滑会让首屏多一条不可见内容的行 |
| D6 | 归组是否落盘 | **不落盘**，每组记住的子科目只在内存 | 落盘要给 `Topic` 加存档字段，得不偿失 |
| D7 | 发布批次 | 归组骨架 + 前两个科目打一包，后两个科目下一包 | 攒 2~3 个功能打一包（AGENTS.md 节奏） |
| D8 | 与模拟考试的前后关系 | **本功能先行**；模拟考试若要用这些子科目，等它们稳定后再接 | 两个功能都动 `QuestionKind`，同时做会撞车 |
| D9 | 数独独立入口的位置 | 主 tab 之外，在首页**标题区**给一个「玩数独」按钮，仍走 `onSwitchTopic` 切到数独 topic（已定：标题区按钮，不在 tab 行） | 数独偏游戏、不属学科；主 tab 收敛为三科。入口不回主 tab |

> 这些点已有建议值。实施前若无异议按建议走；有改动在 T1 开始前一次性确认，带悬而未决的决策进实现 = 返工。**D1/D2 已由用户 2026-11-24 拍板：D1 独立建题库、D2 按建议收词范围**；D9（数独独立入口）与 A2b 亦已拍板。

## 7. 任务分解（薄层切片，每阶段独立可验）

| 阶段 | 内容 | 独立完成判据 | WIP |
|---|---|---|---|
| T1 | 数据层：`Topic.group`/`tabLabel` + `kSubjectGroups`（三组，不含数独）+ 现有 5 个学科挂 group | `flutter analyze` 无问题；现有测试不挂；`kTopics` 长度不变 | ✅ 已落地（`e187959`） |
| T2 | UI：两层 `_TopicTabs`（一级三组）+ 标题区「玩数独」独立入口 + 每组记住子科目 + `layout_test.dart` 三档宽度 | 三组一级 tab 高亮正确；语文二级现有 3 个 tab 可切（7 个待 T3~T6）；数独从 tab 拿掉、标题区入口直达棋盘页；窄/中/宽屏不溢出；`flutter test` 全绿 | ✅ 已落地（`e187959`，待 D1/D2 再开 T3~T6） |
| T3 | 文学常识：`tool/literature_bank.json` + 生成脚本 + 题库 + 题型 + `Topic` + 测试 | 独立科目可出满一局；干扰项无双答案；全绿 | ✅ 已落地（未提交，48 条，`literaturePick`） |
| T4 | 歇后语：同 T3 套路 | 同上 | ✅ 已落地（49 条，`xiehouyuLink`） |
| T5 | 错别字/形近字：同 T3 套路 | 同上 | ✅ 已落地（47 条，`typoCorrect`；方案 §4.3 的 `typoCorrect`/`homophonePick` 合并为单一 `typoCorrect`，选项含本条错写真陷阱） |
| T6 | 文言实词：同 T3 套路，例句逐条人审 | 同上 + 长例句渲染正确 | ✅ 已落地（40 条，`wenyanMeaning`；例句锚定一词多义） |
| T7 | 回归：`flutter test` + `flutter analyze` + `flutter build apk --release` + 文档收口 | 三条机械验证全过；待办表状态改「待发布」 | |
| T8 | 发布：版本号 + APK + OSS 上传 + `version.json` + 刷 CDN | 真机更新闭环确认 | 单独批次 |

每阶段停下时 App 都处于可运行状态。T3 完成后即可验证「归组 + 新科目」整条链路，T4~T6 是重复套路。

## 8. 测试计划

**归组（T2）**
- `test/layout_test.dart`：三档宽度（compact/medium/expanded）下首页主 tab（三组）不溢出；二级行现有 3 个 tab 可点（7 个待 T3~T6）；数独不在 tab 行、标题区独立入口可见。
- 切组记住子科目：语文「拼音」切到数学再切回语文，仍停在「拼音」（`_SwitchableHome` 有状态外壳真实切科验证）。
- 一级组高亮跟随当前科目所属 `group`；点标题区「玩数独」经 `onSwitchTopic` 切到棋盘科目。

**每个新科目（T3~T6，各自 `test/<name>_test.dart`）**
- 题库 id 三元组唯一（`朝代|作者|标题`）。
- 每条都能出目标题型；不因干扰项不足退化成空题。
- **干扰项唯一性**：每个题型枚举若干条目，断言选项中不会出现两个正确答案（这是最容易漏、也最伤孩子的 bug）。
- 按年级分档时，每档题池非空、能出满一局。
- `QuestionKind` switch 穷尽：新增题型必须同时在 `quiz_engine.dart:191` 的 `_tryMake` 加分支，否则整套测试编译不过（已记录在 AGENTS.md）。

**机械验证（T7）**
- `flutter test` 全绿；`flutter analyze` 无问题；`flutter build apk --release` 能出包。

## 9. 主要风险与规避

| 风险 | 规避 |
|---|---|
| 首页加一行 tab 后垂直空间不够（首页整页不滚动是硬约束） | 主 tab 只三组、二级行只在语文组显示且压到 48dp 触控下限；数独独立入口不占 tab 行；必要时缩短标题区，不改滚动 |
| 内容出错（文言释义、歇后后半、错别字正字） | 源 JSON 逐条人审；生成脚本做唯一性/格式校验；测试钉死干扰项与题池 |
| 新题型与「模拟考试」功能同时改 `QuestionKind` 撞车 | D8 定本功能先行；新增题型一次性加齐，后续模拟考试只是消费 |
| 文学常识和诗词出成同一类题 | D1 定独立条目，只做并称/字号/流派，不做名句→作者 |
| 二级 tab 切回时状态丢 | 每组记住子科目在 `_HomePageState` 内存里；`didUpdateWidget` 不动它 |
| 新科目存档与旧科目混键 | `Topic.id` 唯一且前缀独立，`ProgressStore.load(topicId:)` 显式传参 |

## 10. 发布与批次

- T1~T3 一批（归组骨架 + 文学常识，最小可验证闭环）；T4~T5 一批；T6 单独或并入下一批。
- 每批一个 commit；发布攒 2~3 个功能打一个包，走 `AGENTS.md`「交付门禁」发布清单（版本号 + APK + OSS + `version.json` + 刷 CDN）。
- 与「英语一年级句子池」（当前待发布）合并进 0.5.0 批次，或顺延到 0.6.0——按 T7 时的待发布队列决定。

## 11. 完成判据

- [ ] D1–D9 已拍板（D9/A2b 数独独立入口已定），无悬而未决决策进入实现
- [ ] `Topic` 有 `group`/`tabLabel`，`kSubjectGroups` 定义存在（语文/数学/英语三组，**不含数独**），现有 5 个学科挂好 group，`kTopics` 长度未变
- [ ] 首页两层 tab：一级三组、二级仅语文组现有 3 个（7 个待 T3~T6）；数独从主 tab 拿掉、标题区有「玩数独」独立入口；切组记住子科目；三档宽度不溢出
- [ ] 四个子科目的题库、题型、`Topic` 定义、`test/<name>_test.dart` 齐全
- [ ] 每个新科目的干扰项唯一性测试通过，无双正确答案
- [ ] `flutter test` 全绿 + `flutter analyze` 无问题 + `flutter build apk --release` 能出包
- [ ] 真机上可切换并实现「语文 → 各子科目」完整路径，进度按科目隔离
- [ ] `docs/development-progress.md` 待办表状态更新为「待发布」，科目与题库表补入 4 行
- [ ] 收尾汇报五件事：改了什么 / 验证了什么 / 未验证什么及原因 / 关键默认值 / 遗留风险

## 12. 词语科目（同义 / 反义，2026-11-24 并入）

原 `feat/chinese-split` 分支的「词语」子科目，合并时改造为 main 的归组结构后并入。

| 项 | 内容 |
|---|---|
| 科目 id | `words`（存储键前缀独立，不影响其他科目存档） |
| 二级 tab | `tabLabel: '词语'`，挂 `group: 'chinese'` |
| 题型 | `synonymOf`（找近义词）/ `antonymOf`（找反义词），共 2 种 |
| 题库 | `lib/data/words.dart`（`tool/gen_words.py` 从 `tool/word_bank.json` 生成，不要手改） |
| 条目 | 82 个词条 / 286 条关系对（同义 149 / 反义 137），1-6 年级分档 |
| 干扰项 | 查生成器算好的闭包 `kWordSynonyms` / `kWordAntonyms`，排除该词全部同义/反义词，防止一题两答案 |

语文子科目因此为 8 个：诗词 / 拼音 / 成语 / 文学常识 / 歇后语 / 错别字 / 文言实词 / 词语。
`QuestionKind` 总数 23 类（原 21 + 词语 2）。
