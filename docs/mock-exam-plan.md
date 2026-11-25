# 模拟考试（语文 / 数学 / 英语）方案

> 状态：规划中（2026-11-24 建立；2026-11-25 收束时确认仍为最新版）
> 本轮交付：**仅本文档，不动业务代码**（用户 2026-11-24 拍板：本轮只出方案；下一轮先做导航骨架）。
> 前置：§0 假设 + §3 的 D1–D6 拍板；其中语文卷的阻塞项「语文拆散」**已随 0.5.0+13 落地**（语文 8 个子科目），D1 不再阻塞，只待拍板组成。
> 完成判据：§10。实施时按待办表 WIP=1，状态「规划中 → 实现中」。

## 0. 本轮结论与假设

**已拍板（2026-11-24）：**

- 核心形态：**导航骨架先行**——先立入口、页面结构、状态机与数据模型，组卷/判分的精细逻辑留到填充阶段。
- 本轮范围：只出本文档，不改任何业务代码。
- 语文口径：**等「语文拆散」D1/D2 拍板后再定**。本方案对语文只预留「组 → 子科目」挂接点，不定义语文卷具体由哪几个子科目组成。

**前提假设（未拍板，按最小可逆默认推进，实施前复核）：**

- 模拟考试是**独立玩法**，不复用「快问快答 / 错题重练 / 生涯」它们的存档统计口径。
- 数学、英语卷不依赖「语文拆散」，可先于语文落地；骨架阶段只接通这两科。
- 试卷沿用内置题库与现有 `Question` 结构，不引入新题型、新依赖或联网。

**阻塞项（2026-11-25 更新）：**

- ~~语文卷 = 待「语文拆散」确定「4 个子科目是谁」及归组方式~~ 该阻塞已解除：「语文拆散」已随 0.5.0+13 发布（语文 8 个子科目 + 块状导航）。语文卷由哪些子科目组成只剩 D1 拍板，实施前确认即可。

## 1. 目标与非目标

### 目标

- 在现有「练」之外提供一条「考」的路径：一科一张卷，统一作答、统一交卷、统一出成绩。
- 先把**导航与状态骨架**立住：入口在哪、有哪些页面、状态如何流转、数据长什么样——下一轮照此实现即可跑通。
- 全程离线、纯内置题库，复用 `Poem / Topic / QuizEngine / Question / QuizPage` 现有体系，不重造题。

### 非目标（本轮及骨架轮不做）

- 不定义语文卷的具体题目来源（阻塞于 D1）。
- 不做三科连考总分、不做限时倒计时、不做成绩历史与趋势分析（后者属「逐题埋点 / 学习分析」待办）。
- 不提取/重构 `QuizPage` 内的私有 Widget；骨架阶段考试页自己渲染最小卷面，共用组件的提取留到填充阶段评估。
- 不改任何现有 `Topic.id`——它是存档前缀，改则旧档全丢（项目无迁移逻辑）。

## 2. 当前基线（可复用架构）

| 现有件 | 考试可复用的部分 | 不能直接复用的部分 |
|---|---|---|
| `Topic` / `TopicMode` | 题库、题型集合 `kinds`、展示文案钩子 | 无「考试卷」概念；语文是多 Topic 的组合，需按 §7 挂接 |
| `QuizEngine.generate()` | 出题、干扰项、题型配比、加权 | 面向「一局 10~15 题」，卷的题数与配比要由 `ExamSpec` 另行装配 |
| `PracticePlan` / `resolvePracticePlan()` | 范围 × 策略 → 权重/选项数 | 考试范围口径是否等同练习范围见 D4 |
| `Question` / `QuestionKind` | 卷面题目结构，17 类题型 | 无「考试专用」字段；填空答案的记录方式见 §9 |
| `QuizSession` / `QuizPage` | 题目推进、喇叭、答题交互、反馈渲染 | `QuizSession` 逐题判分+反馈，考试要「答完不判、交卷统一判」，状态机不同，另建 `ExamSession` |
| `ResultPage` | 统计卡、错题清单的视觉样式 | 数据来自 `QuizSession`；考试报告另取 `ExamSession` |
| `ProgressStore` | 按 `<topicId>_` 分键的存档机制 | 不把考试分混进 `best_score` / 总正确率（见 D5） |
| 首页 `_SecondaryEntries` | 学习模式 / 错题本旁的入口区 | 首页整页不滚动，加入口必须复用现有空位（见 §4.1） |

## 3. 待拍板决策 D1–D6

> 状态标记：**已定** = 本轮或后续已拍板；**待定** = 实施前需用户确认；**阻塞** = 等外部决策。
> 待定项默认取「建议」列的最小可逆方案推进，但涉及存档口径与语文内容的须先确认。

| 编号 | 决策 | 建议 | 当前状态 |
|---|---|---|---|
| **D1** | 语文卷由哪些子科目组成？ | 等「语文拆散」确定 4 子科目与归组后，语文卷按「语文组」整体出，不拆到子科目粒度 | **阻塞**：依赖「语文拆散」D1/D2 |
| **D2** | 一次考一科还是三科连考？ | 骨架按「一次一科一张卷」设计；连考作为后续扩展位（状态机里预留 `ExamRun` 容器），本轮不做 | **已定**：先导航骨架，单科先行 |
| **D3** | 每卷题数与是否限时？ | 每卷 20 题；**不倒计时**（低龄不做时间压力），可做正计时仅作展示。题数写进 `ExamSpec.count`，不写死在 UI | **待定**：建议 20 题 / 不限时 |
| **D4** | 组卷范围与配比口径？ | 复用 `resolvePracticePlan()` 的范围 × 策略解析，`ExamSpec` 再叠加以「题型配比」为主的卷配置；不新造范围维度 | **待定**：建议复用练习范围口径 |
| **D5** | 考试分是否进入现有存档统计？ | **隔离**：不写 `best_score` / 总正确率 / 生涯掌握，仿数独 `stageCleared` 单记。历史成绩延后（与「学习分析」对齐） | **待定**：建议隔离 |
| **D6** | 考试答错是否进错题本？ | 骨架阶段不回流；待组卷与判分定稿后，按「进错题本」对齐练习体验，但要标来源以区分练习错与考试错 | **待定**：建议延后决定 |

## 4. 导航骨架（下一轮实现目标）

### 4.1 入口

首页整页不滚动、空间紧张（见 AGENTS.md「首页整页不滚动」）。**不新增独立 tab**，在现有 `_SecondaryEntries` 区加第三枚入口 chip「模拟考试」，与「学习模式 / 错题本」并排。点击后 push 到考试选择页。

- 数独（棋盘玩法）不显示该入口——它没有题库题型，考试不适用。
- 语文入口在 D1 阻塞期间置灰，标注「待开放」，不给出可点击的假入口。

### 4.2 页面与状态机

三页 + 一个状态对象，骨架阶段只保证「进得去、答得了、交得了、看得到分」：

```
首页 _SecondaryEntries
  └─(tap)─> ExamEntryPage  选择科目（语文/数学/英语）+ 每卷说明 + 开始
              └─(开始)─> ExamSessionPage  卷面：逐题作答，不判分不反馈
                            └─(交卷)─> ExamResultPage  分数 + 逐题对错 + 错题清单
```

- **ExamEntryPage**：三科卡片；语文按 §4.1 置灰；数学/英语可进。显示题数与「不倒计时」说明（D3 定稿后更新）。
- **ExamSessionPage**：复用 `Question` 渲染；顶部显示「第 i / N 题」与「已答 N」；答题只记录选择，不给对错反馈；底部常驻「交卷」按钮（未答完允许交卷，未答题计错）；退出需二次确认（仿 `QuizPage` 的 `_confirmLeave`）。
- **ExamResultPage**：分数、正确率、逐题对错列表；视觉沿用 `ResultPage` 的统计卡与错题清单样式，但数据源为 `ExamSession`。

### 4.3 数据模型（草案，仅签名，骨架阶段不实现细节）

```dart
/// 考试科。语文是「组」，具体内容待「语文拆散」D1/D2 拍板。
enum ExamSubject { chinese, math, english }

/// 一次考试的组卷配置。骨架阶段只定字段，组卷细节见 §5。
class ExamSpec {
  const ExamSpec({
    required this.subject,
    required this.topicIds,   // 语文可能跨多个 topic id（D1）
    required this.kinds,
    required this.count,
    this.optionCount = 4,
    this.title = '',
  });
  final ExamSubject subject;
  final List<String> topicIds;
  final Set<QuestionKind> kinds;
  final int count;
  final int optionCount;
  final String title;
}

/// 一卷考试的运行状态。与 QuizSession 的关键区别：
/// 答题阶段不判分、不反馈、不推进错题本；交卷后统一结算。
class ExamSession extends ChangeNotifier {
  ExamSession({required this.spec, required this.questions});

  final ExamSpec spec;
  final List<Question> questions;

  /// 题号 -> 选择的选项下标。填空题的记录方式见 §9，骨架阶段先只支持选择型。
  final Map<int, int> answers = <int, int>{};

  int index = 0;
  bool submitted = false;

  Question get current => questions[index];
  bool get answered => answers.containsKey(index);

  void answer(int optionIndex) { /* 骨架：记录并 notifyListeners */ }
  void submit() { /* 骨架：统一判分，填 correctCount / wrongIds */ }

  late final int correctCount;
  late final List<String> wrongQuestionKeys;

  int get score => correctCount;          // 每题 1 分，与练习一致
  double get accuracy => questions.isEmpty ? 0 : correctCount / questions.length;
}
```

### 4.4 复用边界与明确不碰的东西

- `ExamSession` **另建**，不继承 `QuizSession`：两者「何时判分」的语义不同，硬合并会把练习的逐题反馈搅乱。
- 卷面渲染骨架阶段自己写最小版本（用现有 `Question` 字段），**不提取** `QuizPage` 私有组件；提取共用留到填充阶段单独评估，避免大范围重构 `quiz_page.dart`（1125 行）。
- 不出入新的状态管理库（项目无 Provider/Riverpod/GetX），`ExamSession extends ChangeNotifier` + `setState` 即可。
- 不新增依赖、不联网、不改存档键前缀。

## 5. 组卷（填充阶段；骨架阶段只留接口）

骨架阶段允许「借道」现有路径出卷：`buildSession(engine: , topic: , count: spec.count, ...)` 取 `questions` 塞进 `ExamSession`。这样下一轮能立刻跑通，不必先写专用组卷器。

填充阶段再补 `ExamSpec → List<Question>` 的专用装配：

- 以 `resolvePracticePlan()` 解析范围与策略（D4），得到 `weights / optionCount / kindWeights`。
- 按卷的配置覆盖题型配比：语文偏「接句 / 补句 / 成语 / 拼音」，数学偏「算得数 / 填数 / 比大小」，英语偏「听音 / 认义 / 拼词 / 听句」——配比表写进 `ExamSpec` 或独立常量，不散落 UI。
- 同一卷内条目不重复（沿用 `QuizEngine` 的 `seenKeys`）；一科池子不足时按实际题数出卷，不硬凑 20。
- 英语卷仍需音频懒下载链路；语文卷的子科目题型决定要不要挂喇叭（见 D1 与项目「成语拼音题干不挂喇叭」约束）。

## 6. 计分、存档与错题回流

- 计分：每题 1 分、只算对错，与练习一致；不因科目或难度加分。
- 存档：按 D5 建议**隔离**——考试结果不写 `best_score` / 总正确率 / 生涯掌握。骨架阶段甚至可以不落盘，只在 `ExamResultPage` 展示当次分数。若 D5 改为记录，新增独立裸键 `exam_<subject>_last`（不进 `ProgressStore.toJson/applySnapshot`，避免动云同步快照契约），并同步文档说明。
- 错题回流：按 D6，骨架阶段不写错题本；定稿后若要回流，需给错题记录加「来源=考试」标记，否则与练习错混淆。

## 7. 语文卷挂接（阻塞依赖）

「语文拆散」当前卡在 D1/D2（4 个子科目是谁、是否新增子科目），方案文档为草案。本方案对此的处理：

- `ExamSpec.topicIds` 设计为 `List<String>`，允许语文跨多个 topic id 抽题——无论最终 4 子科目是谁，挂接点都不变。
- 考试选择页的语文入口在 D1 落地前置灰；`ExamSubject.chinese` 在骨架里保留但不产出试卷。
- D1 拍板后，只需在「科目 → ExamSpec」的装配处补一条语文配置，不改导航骨架、不改状态机。
- 注意「语文拆散」的二级导航是「组 → 子科目」；考试入口应挂在**组**这一层（与科目 tab 同级语义），不要塞进子科目内部，避免架构错位。

## 8. 里程碑

| 里程碑 | 内容 | 前置 |
|---|---|---|
| **M0（本轮）** | 出本文档；待办表保持「规划中」 | 无 |
| **M1（骨架轮）** | 首页入口 + `ExamEntryPage`/`ExamSessionPage`/`ExamResultPage` 三页 + `ExamSpec`/`ExamSession` 数据模型与状态机；数学/英语能出卷、答题、交卷、看分；`ExamSession` 单测覆盖状态机 | D2/D3/D5 拍板；语文入口置灰 |
| **M2（填充轮）** | 专用组卷器（题型配比）、正计时展示、考试分落盘与历史（若 D5 改） | D3/D4/D5 拍板 |
| **M3（语文接入）** | 语文卷按「语文拆散」结论接通 | D1 解除阻塞 |
| **M4（可选）** | 三科连考与总分报告、错题回流（D6） | M2 + 用户确认需要 |

## 9. 验证与风险

**验证（每轮改动后）：**

- `flutter test` 全绿；骨架轮重点看新增的 `exam_session_test.dart`（未答跳过、交卷幂等、判分正确、空卷不崩）与 `test/layout_test.dart`（新增入口后三种窗口宽度仍能渲染）。
- `flutter analyze` 无问题。
- 真机/模拟器走一遍：首页进考试 → 选数学/英语 → 答几题 → 交卷 → 看成绩；语文入口确认置灰。

**风险与未决：**

- **填空题答案记录**：`Question` 的填空题用 `answerChars` + `charPool`，不是选项下标；`ExamSession.answers` 用 `Map<int,int>` 只覆盖选择题。骨架阶段先让考试卷只出选择题型，填空题的记录与判分在填充阶段补（可扩展 `Map<int, Object>` 或独立 `Map<int, List<String>>`）。
- **首页空间**：加第三枚入口 chip 后，窄屏与 Super Narrow 窗口需实测不溢出；若放不下，优先压缩 chip 文案而非改成滚动（项目硬约束）。
- **组卷池不足**：数学/英语年级池小（英语一年级 52 条）时 20 题会回收已练条目——考试是否允许重复、是否与「未练优先」冲突，属 D4 细节，填充阶段定。
- **语文拆散推进顺序**：两个功能都「规划中」，WIP=1；数学/英语骨架不依赖语文，可先做，但考试整体完成需等 D1。

## 10. 完成判据

本功能标记「完成」需全部满足：

- [ ] D1–D6 均已拍板或按建议默认落地并在 §3 更新状态。
- [ ] 首页能从 `_SecondaryEntries` 进入考试选择页；数独页无此入口；语文入口按 D1 结果呈现（阻塞期置灰）。
- [ ] 数学、英语各能生成一张卷、逐题作答、交卷、看到分数与逐题对错（骨架阶段允许借道 `buildSession` 出卷）。
- [ ] `ExamSession` 有单元测试覆盖：未答题计错、交卷幂等、判分正确、空卷不崩。
- [ ] 考试结果不污染练习统计（D5 结论落地）；若落盘，不改动 `ProgressStore` 云同步快照契约。
- [ ] `flutter test` 全绿、`flutter analyze` 无问题；`test/layout_test.dart` 覆盖的新入口在三种窗口宽度下不溢出。
- [ ] 本文档状态从「规划中」更新，完成判据勾选完毕；语文卷若仍阻塞，单独标注未完成项而非整体标记完成。
