# 模拟考试功能规划（语文 / 数学 / 英语）

> 状态：**规划中，未实现**（2026-11-23 建立）。本文只定方案与任务分解，不改代码。
> 对应待办表：`docs/development-progress.md`「功能待办表」模拟考试一行；跨功能依赖见该文档「跨功能依赖：语文拆散 → 模拟考试」。
> 范围：在现有答题框架上增加「限时模拟考试」玩法，三科各一张卷，交卷后出成绩单。
> 不含：备考日程 / 倒计时日历 / 学习分析（另案）。

## 0. 需要先确认的假设

以下四点是我按现有代码作出的默认选择，实施前请确认或纠正：

1. **「语文」没有对应科目**。App 里现有的是诗词（`poetry`）、拼音（`pinyin`）、成语（`chengyu`）三个独立科目，没有统一的 `kChineseTopic`。本方案把语文卷设计为**诗词 + 拼音 + 成语三段混合卷**，每段用各自科目的题库与出题规则生成（见 §3.1）。
2. **考试不污染练习统计**。沿用数独「不写最高分/正确率」的先例，考试成绩单独记，不进 `totalAnswered/totalCorrect/bestScore`，避免把练习的正确率拉花。错题是否进各科错题本见 §6 的决策点。
3. **计分沿用「每题 1 分，只算对错」**，满分为卷面题数（建议 10 分），不换算百分制、不设倍率与连击。
4. **时限为题量建议值**（语文 15 分钟 / 数学 10 分钟 / 英语 15 分钟），可调整；倒计时归零强制交卷。
5. **语文拆散功能先行**（`docs/chinese-split-plan.md` D8）：归组导航 + 4 个新子科目与本功能都改 `QuestionKind`，不能并行（WIP=1）；本功能排在其后。数学卷/英语卷不依赖它，可单独排期，但同一时间仍只允许一个功能「实现中」。

## 1. 目标

- 三科各提供一套**固定结构的限时试卷**，与日常练习区分开：考前不泄题、考中不提示对错、考完统一出成绩单。
- 复用现有 `QuizEngine` / `Question` / 答题页 UI，**不重写出题引擎**，不引入新依赖，保持纯离线（英语听力仍走既有 OSS 懒下载链路）。
- 考试记录与练习存档隔离，错题可回流到对应科目错题本供后续复习。
- 沿用宣纸 + 墨 + 朱印视觉与平板双栏布局，触控目标 ≥48dp，首页「整页不滚动」约束不被破坏。

## 2. 当前基线（已实现，作为改造起点）

| 能力 | 现状 | 规划要动的地方 |
|---|---|---|
| 玩法维度 | `GameMode` 只有 `quick`(10题) / `review`(错题10题) / `career`(15题)，见 `lib/pages/home_page.dart:402-443`；chip 遍历生成 `:347-359`，`_ModeChip` `:1432-1525` | 新增第四条 exam 入口 + 考试选科流程 |
| 开局 | `_start()` `home_page.dart:138-189`：调 `buildSession` `:151-164` → `Navigator.push(QuizPage)` `:171-187` → `onFinish` 写存档 `:176-184` | 考试另走一条组卷/跳转路径 |
| 出题 | `buildSession` `lib/data/quiz_session.dart:95-148`、`QuizEngine.generate` `lib/data/quiz_engine.dart:55-91`；一局内每条只出一次；`resolvePracticePlan` `lib/data/practice_scope.dart:264-383` 解析范围与题型权重 | 新增考试蓝图，复用引擎，不改引擎核心 |
| 答题页 | `QuizPage(session, onFinish, store?)` `lib/pages/quiz_page.dart:17-29`；`_reveal` `:87-93` 立即提交并展示对错反馈，`_next` `:95-110` 翻页，`_finish` `:112-121` 跳结算；**无任何计时器** | 加 `isExam` 分支：抑制反馈 + 倒计时 + 交卷 |
| 结算页 | `ResultPage(session, store?)` `lib/pages/result_page.dart:10-17`，数据全来自 `QuizSession`；只有关闭与「返回首页」，无重玩 | 新建考试专用成绩单页，不动原结算页 |
| 会话 | `QuizSession` `lib/data/quiz_session.dart:12-85`：单一 `topic`、`submit/advance`、每题 1 分 | 新建 `ExamSession`（跨科、逐题带科目、计时） |
| 存档 | `ProgressStore` 按 `<topicId>_<字段>` 分科；`toJson/applySnapshot` 是格式边界，`snapshotVersion = 1`，`lib/data/progress_store.dart:142-211` | 新增考试记录字段须同步改两处 + 版本递增 |
| 计时参考 | 数独页 `lib/pages/sudoku_page.dart:86-126` 的 `Timer.periodic` + `dispose` 取消 | 直接复用作息模式 |
| 题库 | 诗词 113 / 拼音 320 / 成语 122 / 英语 135 / 数学 488（规则生成），见 `lib/data/topics.dart:13-183` | 不改题库 |

音频约束（英语）：听力题必须预生成音频，首次播放按条目下载。考试若含听力，须先检查/下载本卷所需音频，否则考中卡住——见 §6 决策点。

## 3. 组卷设计

### 3.1 语文卷：三段混合，逐题带科目

不建「合成 Topic」（那会让 `nameOf/summaryOf/detailOf/marks` 这些科目展示钩子错位）。改为**每段各用原科目生成题目，拼接成一张卷**：

| 段 | 来源 Topic | 题量与题型（建议） |
|---|---|---|
| 诗词 | `kPoetryTopic` | 4 题：`nextLine / author / title / blank` |
| 拼音 | `kPinyinTopic` | 3 题：`pinyinOf / wordOf` |
| 成语 | `kChengyuTopic` | 3 题：`idiomBlank / idiomMeaning / idiomPinyin` |

每段独立调 `buildSession`（传各自的 `topic`、由推荐学龄解析的 `plan`、`kinds` 限定本段题型、`count` 固定），把产出的 `Question` 连同其 `topicId` 一起收进考试卷。这样每题的展示、反馈、错题归属都能取到正确科目的钩子。

> 干扰项仍受科目自身的排除规则保护（作者题排除同作者、拼音排除同读音等），跨段不会混出选项——每段在各自题库内生成。

### 3.2 数学卷

`kMathTopic` 单科 10 题：`mathResult ×4 / mathBlank ×3 / mathCompare ×3`。范围取推荐学龄（`resolvePracticePlan`，scope 跟随推荐），保证出的都是已学年级。

### 3.3 英语卷

`kEnglishTopic` 单科 10 题：`englishListen ×3 / englishMeaning ×2 / englishCase ×1 / englishSpell ×2 / englishSentence ×2`。沿用 `kKindShareCaps` 对 `englishCase` 的占比上限；听力题 `focus` 为空、只显示喇叭，考试页同样适用。

> 英语卷依赖音频：开考前须预检本卷听力条目的本地缓存，缺的先下载（可取消回到首页）；下载失败不允许带缺音频开考。

### 3.4 蓝图数据结构（建议）

新增 `lib/data/exam.dart`（或 `exam_session.dart`），定义：

- `ExamKind { chinese, math, english }` —— 卷种。
- `ExamBlueprint`：卷种、标题、时限秒数、分段配置（来源 `topicId`、题数、限定 `kinds`）。三份静态蓝图常量。
- `ExamQuestion`：包裹 `Question` + 来源 `topicId`（+ 段名），用于展示时反查科目钩子。
- `ExamSession`：持有 `List<ExamQuestion>`、`total`、时限、已用秒数、剩余时间、各段答对统计、交卷状态；`submit/advance` 语义与 `QuizSession` 对齐（提交不翻页，翻页单独调用）。

单科卷（数学/英语）的所有 `ExamQuestion.topicId` 相同；语文卷逐题不同。成绩单按段分组展示时据此切分。

## 4. 交互流程

1. 首页第四条 chip「考试」→ 打开**选科页/底部面板**，列出三张卷（名称、题量、时限、已考次数与最好成绩）。属首页新增入口，chip 横排不破坏「整页不滚动」。
2. 选定卷 → 英语卷先走音频预检/下载；通过后组卷 → `Navigator.push(ExamPage)`。
3. 考试中：
   - 顶栏显示剩余时间（`mm:ss`），最后 1 分钟可变色提醒（`AppColors.seal`），不引入新色值；
   - **不显示即时对错**：答完不弹反馈卡、不显示正确答案与解析，短暂延时后自动进入下一题（或仍由「下一题」按钮推进，但反馈中性化）；
   - 不写错题本、不更新练习统计（交卷时统一处理）；
   - 中途退出需二次确认，确认后本次作废、不记成绩。
4. 交卷条件：答完最后一题自动交卷 / 倒计时归零强制交卷 / 主动「提前交卷」（二次确认）。
5. 交卷 → 跳**考试成绩单页**：显示卷种、得分（如 8/10）、用时、各段正确率、逐题对错与正确答案/解析（此处才允许看解析）；提供「返回首页」与「再考一次」。

> 第 3 步的「不提示对错」是考试与练习的核心差异，要在 `QuizPage` 用 `isExam` 显式分支，不能靠约定——现有 `_reveal` 一定会调反馈逻辑。

## 5. 数据落盘与隔离

- 新增**独立的考试记录存储**：`ExamStore`（建议 `lib/data/exam_store.dart`），用 `exam_` 前缀的裸键，在 `main.dart:27-31` 启动时随其它数据一次加载并向下传（与 `AccountService` 同款注入方式）。避免为了跨科语文卷去改写某一科的 `ProgressStore`。
- 记录内容：每次考试的 `{卷种, 日期, 得分, 总题数, 用时秒数, 交卷方式, 各段正确率}`；保留最近 N 条（建议 20）。另存每种卷的最好成绩与次数供选科页展示。
- `ExamStore` 若纳入云同步，须按 `AGENTS.md` 的存档格式边界处理：`toJson/applySnapshot` 同步改、`snapshotVersion` 递增、补序列化测试；**本期可先只存本地**（符合离线优先），在文档里标注为后续可选项。
- 错题回流（见 §6 决策点）：若采用，按 `ExamQuestion.topicId` 调对应 `ProgressStore.removeWrong/recordSession` 的错题部分，或新增一个「仅写错题」的方法，避免连带污染统计。

## 6. 待决策点（实施前拍板）

| # | 问题 | 建议默认值 | 影响 |
|---|---|---|---|
| D1 | 语文卷是否永久固定为诗词+拼音+成语三段？ | 是；比例写进蓝图常量，后续调 | 改比例=改蓝图，不动引擎；若纳入语文拆散新增的 4 个子科目，须等其题库稳定（见 §0 假设 5） |
| D2 | 考试错题是否进入各科错题本？ | **进**（按题目 `topicId` 回流），但只写错题、不动统计 | 需给 `ProgressStore` 加一个只写错题的方法；不进的话考试与复习脱节 |
| D3 | 英语音频缺失时如何处理？ | 开考前预检并下载，失败则不允许开考 | 关系到听力题可否作答 |
| D4 | 倒计时归零是否自动交卷？ | 是，按已作答计分，未作答计错 | 需要「强制交卷」状态 |
| D5 | 考试记录是否纳入云同步？ | 本期否，只本地 | 纳入则触发存档格式版本升级 |
| D6 | 是否允许成语/拼音单独成卷？ | 本期否，仅作为语文卷组成 | 未来加卷=加一条蓝图，不改架构 |

## 7. 任务分解（按依赖顺序）

| 阶段 | 内容 | 主要文件 | 完成判据 |
|---|---|---|---|
| T1 数据模型 | `ExamKind/ExamBlueprint/ExamQuestion/ExamSession` + 三份蓝图常量 | 新增 `lib/data/exam.dart` | 纯 Dart 单测：三张卷都能生成满 10 题、题数/题型符合蓝图、语文卷逐题科目正确 |
| T2 组卷 | 按蓝图调 `buildSession` 拼卷；英语音频预检逻辑 | 新增 `lib/data/exam_service.dart`（或并入 exam.dart） | 组卷单测：三卷题量与题型分布、同卷内条目不重复；音频预检在有/无缓存两条路径可测 |
| T3 考试页 | 复用答题页视觉，加 `isExam` 分支：无反馈、倒计时、提前/强制交卷、退出确认 | `lib/pages/quiz_page.dart`（加可选参数）或新增 `lib/pages/exam_page.dart` | widget 测试：倒计时递减、归零交卷、答对不显示反馈、退出二次确认 |
| T4 成绩单 | 新建考试结果页：分段正确率、逐题解析、再考一次 | 新增 `lib/pages/exam_result_page.dart` | widget 测试：分数/用时/分段统计渲染正确 |
| T5 存储 | `ExamStore` 记录与读取；错题回流按 D2 | 新增 `lib/data/exam_store.dart`，可能改 `lib/data/progress_store.dart`、`lib/main.dart` | 存储单测：写入/读取/上限截断；若改存档格式，序列化往返用例绿 |
| T6 入口串联 | 首页第四条 chip + 选科页 + 跳转 + 交卷落盘 + 返回 | `lib/pages/home_page.dart` | `layout_test.dart` 遍历玩法 chip 含考试入口；集成路径可跑通 |
| T7 回归 | 全量测试与静态分析 | `flutter test`、`flutter analyze` | 全绿、无 analyze 问题 |

> 排序理由：T1/T2 是纯数据层，可独立验证；T3/T4 依赖 T1 的模型；T5 与 T3/T4 可并行（都只依赖 T1）；T6 最后串联。

## 8. 测试计划

- 新增 `test/exam_test.dart`：蓝图完整性、三卷生成题量与题型、语文卷分段科目标注、同卷不重复。
- 新增 `test/exam_store_test.dart`：考试记录写入/读取/最多 N 条截断、最好成绩更新。
- 扩展 `test/layout_test.dart:75-202`（玩法 chip 遍历在 `:137`）：新增考试入口断言 + 考试页/成绩单在三种窗口宽度下的渲染与平板分栏。
- 扩展 `test/secondary_ui_test.dart:304-376`（结算页用例所在）：成绩单新页面用例。
- 扩展 `test/quiz_engine_test.dart`：组卷业务用例（T2 用到的 `buildSession` 组合）。若 D2/D5 改动存档格式，`test/progress_store_test.dart` 必须补往返用例。
- **改动后 `flutter test` 必须全绿**（项目不变量：题型枚举改动会让整个测试套件编译失败，注意 switch 穷尽）。

## 9. 主要风险与规避

| 风险 | 规避 |
|---|---|
| 跨科混卷的展示钩子错位 | 逐题带 `topicId`，绝不建合成 Topic；T1 单测钉死 |
| 考试反馈泄漏答案 | `isExam` 显式分支 + widget 测试断言「答对不显示反馈卡」 |
| 英语听力考中卡住 | 开考前音频预检/下载（D3），失败不开考 |
| 倒计时与 `setState` 生命周期 | 复用数独页 `Timer.periodic` + `dispose` 取消模式（`sudoku_page.dart:88-126`）；切后台是否暂停按 D4 一并确认 |
| 与练习统计互相污染 | 考试记录独立存储；错题回流只写错题字段（D2） |
| 存档格式不兼容 | 本期考试记录独立存储、不动 `snapshotVersion`（D5=否），零迁移成本 |
| 首页放不下第四种入口 | 仍用横排紧凑 chip（约 68dp），不动整页不滚动结构；选科做成面板而非新首页区块 |

## 10. 完成判据

- 三科各能开一张限时卷、正常作答交卷、出成绩单，离线可用（英语按 D3 预下载）。
- 考试过程不提示对错、不污染练习统计；错题按 D2 回流。
- `flutter test` 全绿、`flutter analyze` 无问题；平板双栏与窄屏布局在 `layout_test.dart` 覆盖。
- 本文 §0 的四个假设与 §6 的 D1–D6 均已获确认或按默认值落地并在交付说明中标注。
