/**
 * 思维拓展题 T1/T2/T3 串行实现。每功能：实现 → 门禁(test+analyze) ∥ 独立评审 → 修复轮 → 提交推送；收尾统一出包 + 更新待办表。
 * 遵守项目 AGENTS.md：WIP=1、提交只纳入本功能文件（工作区起点干净，status 即本功能改动）、提交格式 <type>(scope): <summary>。
 */

interface FixOutcome {
  /** 一句话：这一轮改了什么。 */
  change: string;
  /** 修复后门禁是否全绿。 */
  gatesGreen: boolean;
  /** 仍存在的问题（空串 = 无）。 */
  remaining: string;
}

interface GateResult {
  /** flutter test 退出码。 */
  testExit: number;
  /** flutter analyze 退出码（test 失败时未跑，为 0）。 */
  analyzeExit: number;
  /** 失败输出摘要（全绿则空串）。 */
  tail: string;
}

interface ReviewFinding {
  /** 仓库相对路径，带行号如 "lib/data/quiz_engine.dart:120"。 */
  where: string;
  /** 一句话：哪里没满足判据。 */
  problem: string;
  /** 对照判据 / AGENTS.md 依据的说明。 */
  evidence: string;
  /** high = 答案可多解、解析失败、整类题出不来。 */
  severity: "low" | "medium" | "high";
}

interface Review {
  findings: ReviewFinding[];
  /** 一句话：对照判据的总体结论。 */
  verdict: string;
}

interface ImplResult {
  /** 本次功能改动的文件列表（仓库相对路径，供汇报；提交以 git status 实际结果为准）。 */
  files: string[];
  /** 一句话：实现内容。 */
  summary: string;
  /** 提交信息，一行，格式 <type>(scope): <summary>，中文动词开头 ≤50 字，不加句号。 */
  commitMessage: string;
  /** 需要注意 / 决策的事项（空串 = 无）。 */
  caveats: string;
}

interface T3Design {
  /** 方案总述：场景体系与干扰项选取规则。 */
  overview: string;
  /** 诗词场景选句标注：poemKey 必须与 poems.dart 条目 id（朝代|作者|标题）完全一致，quoteLine 逐字取自该条 lines。 */
  poemScenes: Array<{ poemKey: string; scene: string; quoteLine: string; distractorHint: string }>;
  /** 成语情境套用标注：成语必须在 chengyu.dart 122 条内，情境句口语化且答案唯一。 */
  idiomContexts: Array<{ idiom: string; context: string; distractorHint: string }>;
  /** 取舍说明：哪些条目拿不准没标、为什么。 */
  notes: string;
}

interface CommitOutcome {
  committed: boolean;
  pushed: boolean;
}

const REPO = "D:/tools/poem_quiz";

/** 跑两条门禁：flutter test 全量 + flutter analyze（test 挂了就不再跑 analyze）。 */
async function runGates(): Promise<GateResult> {
  const t = await world.run("cmd", ["/c", "flutter test"], { timeoutMs: 420000, output: { tail: 16384 } });
  if (t.exitCode !== 0) {
    return { testExit: t.exitCode, analyzeExit: 0, tail: t.stdout.slice(-2500) };
  }
  const a = await world.run("cmd", ["/c", "flutter analyze"], { timeoutMs: 180000, output: { tail: 8192 } });
  return { testExit: t.exitCode, analyzeExit: a.exitCode, tail: a.exitCode === 0 ? "" : (a.stdout + a.stderr).slice(-2500) };
}

function gateFailText(g: GateResult): string {
  if (g.testExit !== 0) {
    return "flutter test 退出码 " + g.testExit + "（输出可能是乱码：中文被 GBK 控制台转码；定位不了就自己跑单个相关测试文件取输出）：\n" + g.tail;
  }
  if (g.analyzeExit !== 0) {
    return "flutter analyze 退出码 " + g.analyzeExit + "：\n" + g.tail;
  }
  return "";
}

/** 门禁或评审失败 → 修复轮（上限 4 轮，每轮改完重跑全量门禁）。 */
async function fixUntilGreen(failText: string, fixerName: string): Promise<FixOutcome> {
  const fixAgent = agent(fixerName, "你是 poem_quiz（D:/tools/poem_quiz）的 Flutter 修复工程师，孩子用的离线答题 App。收到失败输出后：定位根因、读相关代码与项目 AGENTS.md 约束、修复、按需更新测试断言。遵守项目约束（最小改动、LF 行尾、数学题库顺序确定生成、MathExpr 只支持单得数）。不要 git commit 或 push——提交由脚本统一执行。不要跑全量 flutter test 与 flutter analyze——脚本会跑；失败输出乱码影响定位时，可用自己终端跑单个相关测试文件复现。如果约束冲突或问题确实无法修复，escalate 说清楚，不要绕过或伪造通过。");
  let feedback = failText;
  for (let round = 1; round <= 4; round++) {
    log("修复轮 " + round + "/4");
    await fixAgent.ask("门禁或评审未过，请修复：\n" + feedback + "\n\n改动只限当前功能范围，不要引入无关重构。");
    const g = await runGates();
    if (g.testExit === 0 && g.analyzeExit === 0) {
      return { change: "第 " + round + " 轮修复后门禁全绿", gatesGreen: true, remaining: "" };
    }
    feedback = gateFailText(g);
  }
  return { change: "4 轮修复后门禁仍红", gatesGreen: false, remaining: feedback };
}

/** 工作区相对仓库根的全部改动路径（起点干净，即本功能文件）。 */
async function workingTreePaths(): Promise<string[]> {
  const st = await git.status();
  return [...st.staged, ...st.unstaged, ...st.untracked];
}

/** 提交并推送；返回是否提交、是否推送成功。 */
async function commitAndPush(message: string): Promise<CommitOutcome> {
  const paths = await workingTreePaths();
  if (paths.length === 0) {
    log("没有可提交的改动（异常：实现者未落盘？）");
    return { committed: false, pushed: false };
  }
  log("提交 " + paths.length + " 个文件：" + paths.join(", "));
  await world.run("git", ["-C", REPO, "add", ...paths]);
  await world.run("git", ["-C", REPO, "commit", "-m", message]);
  const p = await world.run("git", ["-C", REPO, "push"], { timeoutMs: 120000 });
  return { committed: true, pushed: p.exitCode === 0 };
}

// 进度看板：三个功能各一张卡
artifact.board("progress", {
  title: "思维题三功能进度",
  key: "feature",
  status: "status",
  columns: ["已提交", "未通过"],
  cardTitle: "feature",
  detail: [{ field: "commit", label: "提交" }],
});

// ───────────────────────── T1 诗词线索猜诗 ─────────────────────────

phase("T1：实现线索猜诗题型");
log("T1 开始：诗词线索猜诗（poemRiddle）");
const t1Impl = await agent("T1实现工程师", "你是 poem_quiz（D:/tools/poem_quiz）的 Flutter 实现工程师，孩子用的离线答题 App。动手前先读 AGENTS.md 与 docs/development-progress.md 的「思维拓展题」节，严格遵守约束。最小改动、匹配项目现有风格（LF 行尾、中文行内注释）。不要 git commit 或 push——提交由脚本统一执行。不要跑全量 flutter test / flutter analyze——脚本会跑全量门禁。如果需求有矛盾或约束无法两全，escalate 说清楚，不要静默变通。")
  .ask<ImplResult>(`实现 T1「诗词线索猜诗」新题型 poemRiddle，需求见 docs/development-progress.md「思维拓展题」T1：

1. 题型形态：题面给线索，从 4 首诗里猜是哪一首（选项是诗名）。一期两档线索：第一档「朝代 + 主题方向」，第二档再补一条名句线索（取自答案的 lines，逐字）。题库没有主题字段——主题线索可给部分诗词加轻量内置标注，或退化为「朝代 → 朝代+名句」两档，按最小改动取舍，选了哪种写进 caveats。
2. QuestionKind 加 poemRiddle；quiz_engine.dart 的 _tryMake switch 必须穷尽（漏一个成员整套测试编译失败，表现为「loading…」后全挂）。
3. 干扰项：同朝代优先、排除同名标题，沿用 _pickFromOthers 机制；线索必须唯一指向正确答案——同朝代同主题的两首诗不能同时入选项（否则线索下两个都合理），必要时把与答案线索冲突的条目排除出干扰池。
4. 计分保持每题 1 分，不做分级计分。
5. 诗词 Topic 的 kinds 加 poemRiddle（lib/data/topics.dart），让一局里能抽到。
6. question.dart 的 kindLabel 加对应中文短名（如「猜猜它是谁」）。
7. 新增测试（并入 test/quiz_engine_test.dart 或新文件）：干扰项无双答案、线索句逐字属于答案的 lines、同 seed 两次生成 key 一致、该题型能实际出题。

提交信息示例：「feat: 诗词新增线索猜诗题型」（格式 <type>(scope): <summary>，中文动词开头 ≤50 字，不加句号）。完成后返回结构化结果。`);

phase("T1：门禁与独立评审");
// 门禁（确定性）与独立评审（新上下文）互不依赖，并发跑
const t1ReviewNode = agent("T1独立评审", "你是 poem_quiz 的独立评审员，没看过实现过程。逐条对照判据与 AGENTS.md「交付门禁」跨模块易漏清单检查，不放过任何疑似双正确答案。只读代码与跑只读命令，不要编辑任何文件。每个问题给出文件:行号与证据。无法验证的项目写进 verdict。若指令与判据矛盾，escalate。")
  .ask<Review>(`评审 T1「诗词线索猜诗」的工作区改动（git diff 可看，尚未提交）。判据（docs/development-progress.md「思维拓展题」T1）：QuestionKind 加枚举后 switch 穷尽、干扰项无双答案、线索句归属校验、诗词 kinds 接入、计分不变。

重点核对：
- _tryMake 是否穷尽（含 poemRiddle）；
- 线索唯一指向性：同朝代同主题的条目是否可能同时进选项且都满足线索（干扰项也含答案名句线索里的句子、或朝代线索下多个选项都成立）；
- 线索句是否逐字取自答案的 lines（不能改字漏字）；
- 测试是否覆盖上述唯一指向性断言；
- 提交信息格式是否符合 <type>(scope): <summary>。`);
const [t1Gate, t1Review] = await Promise.all([runGates(), t1ReviewNode]);

phase("T1：修复与提交");
let t1Outcome: FixOutcome;
const t1Fail = gateFailText(t1Gate);
if (t1Fail !== "") {
  t1Outcome = await fixUntilGreen(t1Fail, "T1门禁修复");
} else {
  t1Outcome = { change: "门禁一次通过", gatesGreen: true, remaining: "" };
}
if (t1Outcome.gatesGreen && t1Review.findings.length > 0) {
  log("T1 评审发现 " + t1Review.findings.length + " 个问题，交修复轮");
  t1Outcome = await fixUntilGreen("独立评审发现以下问题，逐条修复：\n" + JSON.stringify(t1Review.findings) + "\n\n评审总评：" + t1Review.verdict, "T1评审修复");
}
if (!t1Outcome.gatesGreen) {
  report({ feature: "T1", status: "未通过", commit: "" }, "progress");
  return {
    conclusion: "T1 门禁未通过，未提交，后续 T2/T3 未开始（WIP=1，工作区留有 T1 未提交改动）。卡点：" + t1Outcome.remaining.slice(0, 400),
    findings: t1Review.findings.map((f) => ({ where: f.where, what: f.problem, evidence: f.evidence, status: "unconfirmed", severity: f.severity })),
    verified: ["门禁由脚本以 world.run 实跑（cmd /c flutter test 与 analyze），未采信任何口头通过"],
    notCovered: ["T2/T3 未实施", "真机验证", "出包"],
    commits: [] as Array<{ feature: string; message: string; pushed: boolean }>,
  };
}
const t1Commit = await commitAndPush(t1Impl.commitMessage);
if (!t1Commit.committed) {
  return {
    conclusion: "T1 门禁全绿但工作区没有改动可提交（实现者未落盘？），中止后续功能。",
    findings: [],
    verified: ["门禁由脚本以 world.run 实跑"],
    notCovered: ["T2/T3 未实施"],
    commits: [],
  };
}
report({ feature: "T1", status: "已提交", commit: t1Impl.commitMessage }, "progress");
log("T1 完成：" + t1Impl.summary + (t1Commit.pushed ? "（已推送）" : "（推送失败，稍后处理）"));
const t1Pushed = t1Commit.pushed;

// ───────────────────────── T2 数学逆向与情境题 ─────────────────────────

phase("T2：实现数学逆向与情境题");
log("T2 开始：数学逆向与情境题（mathReverse / mathWord）");
const t2Impl = await agent("T2实现工程师", "你是 poem_quiz（D:/tools/poem_quiz）的 Flutter 实现工程师，孩子用的离线答题 App。动手前先读 AGENTS.md（尤其「数据与算法约束」）与 docs/development-progress.md 的「思维拓展题」节，严格遵守约束。最小改动、匹配项目现有风格（LF 行尾、中文行内注释）。不要 git commit 或 push——提交由脚本统一执行。不要跑全量 flutter test / flutter analyze——脚本会跑全量门禁。如果需求有矛盾或约束无法两全，escalate 说清楚，不要静默变通。")
  .ask<ImplResult>(`实现 T2「数学逆向与情境题」，需求见 docs/development-progress.md「思维拓展题」T2：

1. 新增两题型：mathReverse（逆向思维：如「7 − 4 = □ + 3」等式平衡填空，保证未知数解唯一；或「□ + □ = 7」选出一组合适的数）与 mathWord（文字应用题：一句话情境 + 四选一得数）。估算/数感题不在本轮范围。
2. 题库由 lib/data/math.dart 规则生成器扩类：顺序确定，不能用 Random（错题本与生涯按 id 存，每次启动重建必须完全一致）。
3. MathExpr 只支持单个得数，「7 ÷ 2 = 3 余 1」进不来，不要为它扩解析器。
4. mathWord 情境模板内嵌在 math.dart 生成器：情境句放 lines（detailOf 会逐行展示），title 保持「3 + 4」算式形式、author 是得数（MathExpr.of 依赖这两个约定）。情境一句话为限（一年级孩子要能读懂）。
5. QuestionKind 加 mathReverse / mathWord；_tryMake switch 穷尽；kindLabel 加中文短名；数学 Topic 的 kinds 加两题型。
6. 干扰项：mathReverse 的错误选项是数值相近的其他数（保证唯一正确）；mathWord 用数值接近得数（沿用现有 numericHint 近邻机制）。
7. 测试（test/math_test.dart 扩）：两题型各年级能出满实际题池容量、干扰项无双答案、顺序确定（生成器重建结果一致）、mathWord 情境句一句话（宽松长度断言即可）。
8. 年级池靠题池累加加权自然兜底，无需特判。

提交信息示例：「feat(math): 新增逆向填空与情境应用题」。完成后返回结构化结果。`);

phase("T2：门禁与独立评审");
const t2ReviewNode = agent("T2独立评审", "你是 poem_quiz 的独立评审员，没看过实现过程。逐条对照判据与 AGENTS.md「交付门禁」跨模块易漏清单检查，不放过任何疑似双正确答案。只读代码与跑只读命令，不要编辑任何文件。每个问题给出文件:行号与证据。无法验证的项目写进 verdict。若指令与判据矛盾，escalate。")
  .ask<Review>(`评审 T2「数学逆向与情境题」的工作区改动（git diff 可看，尚未提交）。判据（docs/development-progress.md「思维拓展题」T2）：两类题型各年级能出满实际题池容量、math_test.dart 覆盖解析与干扰项、门禁全绿。

重点核对：
- _tryMake 是否穷尽（含 mathReverse / mathWord）；
- mathReverse 每道题未知数解是否唯一（等式两侧平衡后只有一个填法；「□+□=7」型正确选项唯一）；
- 顺序确定性：math.dart 扩展后两次重建的 id 集与顺序完全一致（无 Random 泄入）；
- mathWord 情境句是否一句话、语义无歧义（歧义会导致另一个得数也合理）；
- 测试是否断言各年级题池容量出满、不空档。`);
const [t2Gate, t2Review] = await Promise.all([runGates(), t2ReviewNode]);

phase("T2：修复与提交");
let t2Outcome: FixOutcome;
const t2Fail = gateFailText(t2Gate);
if (t2Fail !== "") {
  t2Outcome = await fixUntilGreen(t2Fail, "T2门禁修复");
} else {
  t2Outcome = { change: "门禁一次通过", gatesGreen: true, remaining: "" };
}
if (t2Outcome.gatesGreen && t2Review.findings.length > 0) {
  log("T2 评审发现 " + t2Review.findings.length + " 个问题，交修复轮");
  t2Outcome = await fixUntilGreen("独立评审发现以下问题，逐条修复：\n" + JSON.stringify(t2Review.findings) + "\n\n评审总评：" + t2Review.verdict, "T2评审修复");
}
if (!t2Outcome.gatesGreen) {
  report({ feature: "T2", status: "未通过", commit: "" }, "progress");
  return {
    conclusion: "T2 门禁未通过，未提交（T1 已提交），T3 未开始。工作区留有 T2 未提交改动。卡点：" + t2Outcome.remaining.slice(0, 400),
    findings: t2Review.findings.map((f) => ({ where: f.where, what: f.problem, evidence: f.evidence, status: "unconfirmed", severity: f.severity })),
    verified: ["门禁由脚本以 world.run 实跑（cmd /c flutter test 与 analyze），未采信任何口头通过"],
    notCovered: ["T3 未实施", "真机验证", "出包"],
    commits: [{ feature: "T1", message: t1Impl.commitMessage, pushed: t1Pushed }],
  };
}
const t2Commit = await commitAndPush(t2Impl.commitMessage);
if (!t2Commit.committed) {
  return {
    conclusion: "T2 门禁全绿但工作区没有改动可提交（实现者未落盘？），中止 T3。",
    findings: [],
    verified: ["门禁由脚本以 world.run 实跑"],
    notCovered: ["T3 未实施"],
    commits: [{ feature: "T1", message: t1Impl.commitMessage, pushed: t1Pushed }],
  };
}
report({ feature: "T2", status: "已提交", commit: t2Impl.commitMessage }, "progress");
log("T2 完成：" + t2Impl.summary + (t2Commit.pushed ? "（已推送）" : "（推送失败，稍后处理）"));
const t2Pushed = t2Commit.pushed;

// ───────────────────────── T3 情境运用 ─────────────────────────

phase("T3：设计内容标注方案");
log("T3 开始：先设计标注方案，再实现");
const t3Design = await agent("T3内容设计", "你是 K-12 语文教育内容设计者，为 poem_quiz（D:/tools/poem_quiz，孩子用的离线答题 App）设计情境题内容。质量优先于数量：宁少勿滥，每条都要经得起推敲。引用诗句必须先读 D:/tools/poem_quiz/lib/data/poems.dart，逐字取自对应条目的 lines，不得凭记忆写；成语必须先读 D:/tools/poem_quiz/lib/data/chengyu.dart 确认在库。只读这两个文件与相关文档，不要编辑任何文件。")
  .ask<T3Design>(`为 T3「情境运用」设计内容标注，两类：

A. 诗词场景选句（sceneQuote）：给一个生活场景（如「送别朋友时」），从 4 句中选最合适的一句。从 poems.dart 113 首里挑 30 首左右标注（覆盖送别/思乡/咏物/节令/边塞等典型场景）；quoteLine 逐字取自该条 lines。distractorHint 写干扰项选取约束（同场景其他诗句、排除意涵高度重合的句）。

B. 成语情境套用（idiomContext）：给一句话情境（如「妹妹整天不出门，哪儿都不肯去」），从 4 个成语里选最适用的。成语范围限 chengyu.dart 在库条目，情境句要口语化、答案唯一（不能有第二个在库成语同样贴合）；distractorHint 写要排除的近义成语。

poemKey 用条目 id（朝代|作者|标题，与 poems.dart 完全一致）。数量质量权衡：拿不准的条目宁可不标，把理由写进 notes。`);

phase("T3：实现情境运用题型");
const t3Impl = await agent("T3实现工程师", "你是 poem_quiz（D:/tools/poem_quiz）的 Flutter 实现工程师，孩子用的离线答题 App。动手前先读 AGENTS.md 与 docs/development-progress.md 的「思维拓展题」节，严格遵守约束。最小改动、匹配项目现有风格（LF 行尾、中文行内注释）。不要 git commit 或 push——提交由脚本统一执行。不要跑全量 flutter test / flutter analyze——脚本会跑全量门禁。如果需求有矛盾或约束无法两全，escalate 说清楚，不要静默变通。")
  .ask<ImplResult>(`实现 T3「情境运用」两题型：sceneQuote（诗词场景选句）与 idiomContext（成语情境套用）。标注方案（照此落库）：
${JSON.stringify(t3Design)}

关键需求：
1. QuestionKind 加 sceneQuote / idiomContext；_tryMake switch 穷尽；kindLabel 中文短名；诗词 kinds 加 sceneQuote、成语 kinds 加 idiomContext。
2. 标注以「按条目 id 关联的附注表」实现（复用 poems/chengyu 现有条目，不新增条目、不影响学习页结构）；附注表与引擎的连接按现状最小侵入（Topic 可选字段或 generate 可选参数均可），选了哪种写进 caveats。参考 AGENTS.md：条目复用 Poem、字段不够再建新类型、不提前抽象；展示文案走 displayNameOf 等钩子。
3. 干扰项：sceneQuote 从同场景其他标注条目的关键句取、排除意涵高度重合（按方案 distractorHint）；idiomContext 排除近义成语（参考 idiomMeaning 已有的释义引用排除机制）。每题 4 选项唯一正确。
4. 测试（并入现有测试文件或新文件）：附注 id 都能在对应题库找到（防笔误）、干扰项无双答案、题型能实际出题、sceneQuote 选项句逐字来自题库 lines。
5. 估算题不在本轮范围。

提交信息示例：「feat: 诗词与成语新增情境运用题型」。完成后返回结构化结果。`);

phase("T3：门禁与独立评审");
const t3ReviewNode = agent("T3独立评审", "你是 poem_quiz 的独立评审员，没看过实现过程。逐条对照判据与 AGENTS.md「交付门禁」跨模块易漏清单检查，不放过任何疑似双正确答案。只读代码与跑只读命令，不要编辑任何文件。每个问题给出文件:行号与证据。无法验证的项目写进 verdict。若指令与判据矛盾，escalate。")
  .ask<Review>(`评审 T3「情境运用」的工作区改动（git diff 可看，尚未提交）。判据（docs/development-progress.md「思维拓展题」T3）：题库 id 唯一、每档有题、干扰项无双答案、题型接入工程完整（_tryMake 穷尽、kinds 接入）。

重点核对：
- 附注表里的 poemKey / 成语是否都能在 lib/data/poems.dart / lib/data/chengyu.dart 找到原条目；
- 诗句引用逐字一致（读附注数据与 poems.dart 比对，改字/漏标点都是 high——这是内容产品，错字比 UI 瑕疵严重）；
- 场景选句干扰项意涵重叠（同一场景下两句都高度适用会让答案不唯一）；
- idiomContext 干扰项是否排除了近义/同样适用的成语（情境句下两个成语都通顺 = 双答案）；
- 情境句语义是否无歧义；
- _tryMake 穷尽与 kinds 接入。`);
const [t3Gate, t3Review] = await Promise.all([runGates(), t3ReviewNode]);

phase("T3：修复与提交");
let t3Outcome: FixOutcome;
const t3Fail = gateFailText(t3Gate);
if (t3Fail !== "") {
  t3Outcome = await fixUntilGreen(t3Fail, "T3门禁修复");
} else {
  t3Outcome = { change: "门禁一次通过", gatesGreen: true, remaining: "" };
}
if (t3Outcome.gatesGreen && t3Review.findings.length > 0) {
  log("T3 评审发现 " + t3Review.findings.length + " 个问题，交修复轮");
  t3Outcome = await fixUntilGreen("独立评审发现以下问题，逐条修复：\n" + JSON.stringify(t3Review.findings) + "\n\n评审总评：" + t3Review.verdict, "T3评审修复");
}
if (!t3Outcome.gatesGreen) {
  report({ feature: "T3", status: "未通过", commit: "" }, "progress");
  return {
    conclusion: "T3 门禁未通过，未提交（T1/T2 已提交）。工作区留有 T3 未提交改动。卡点：" + t3Outcome.remaining.slice(0, 400),
    findings: t3Review.findings.map((f) => ({ where: f.where, what: f.problem, evidence: f.evidence, status: "unconfirmed", severity: f.severity })),
    verified: ["门禁由脚本以 world.run 实跑（cmd /c flutter test 与 analyze），未采信任何口头通过"],
    notCovered: ["真机验证", "出包"],
    commits: [
      { feature: "T1", message: t1Impl.commitMessage, pushed: t1Pushed },
      { feature: "T2", message: t2Impl.commitMessage, pushed: t2Pushed },
    ],
  };
}
const t3Commit = await commitAndPush(t3Impl.commitMessage);
if (!t3Commit.committed) {
  return {
    conclusion: "T3 门禁全绿但工作区没有改动可提交（实现者未落盘？）。",
    findings: [],
    verified: ["门禁由脚本以 world.run 实跑"],
    notCovered: ["真机验证"],
    commits: [
      { feature: "T1", message: t1Impl.commitMessage, pushed: t1Pushed },
      { feature: "T2", message: t2Impl.commitMessage, pushed: t2Pushed },
    ],
  };
}
report({ feature: "T3", status: "已提交", commit: t3Impl.commitMessage }, "progress");
log("T3 完成：" + t3Impl.summary + (t3Commit.pushed ? "（已推送）" : "（推送失败，稍后处理）"));
const t3Pushed = t3Commit.pushed;

// ───────────────────────── 收尾：出包验证 ─────────────────────────

phase("收尾：出包验证");
log("跑 flutter build apk --release 补齐交付门禁第三条");
let buildOk = false;
let buildMsg = "";
for (let round = 1; round <= 3; round++) {
  const b = await world.run("cmd", ["/c", "flutter build apk --release"], { timeoutMs: 900000, output: { tail: 8192 } });
  if (b.exitCode === 0) {
    buildOk = true;
    break;
  }
  buildMsg = "flutter build apk --release 退出码 " + b.exitCode + "：\n" + (b.stdout + b.stderr).slice(-2000);
  log("出包失败，修复轮 " + round + "/3");
  const note = await agent("出包修复-" + round, "你是 poem_quiz（D:/tools/poem_quiz）的 Flutter 修复工程师。build 失败输出在后，定位根因并修复。只修 build 阻塞，不做无关改动。不要 git commit 或 push——脚本会在全绿后统一提交。修不了就 escalate 说清楚，不要伪造。")
    .ask<string>("出包失败，请修复（只修 build 阻塞）：\n" + buildMsg);
  buildMsg = "上轮修复说明：" + note.slice(0, 200) + "\n最新失败输出：\n" + buildMsg;
}
if (!buildOk) {
  return {
    conclusion: "T1/T2/T3 全部实现并提交，但收尾出包未通过——release 构建仍红，交付门禁第三条未满足。",
    findings: [{ where: "flutter build apk --release", what: "release 构建失败", evidence: buildMsg.slice(0, 500), status: "verified", severity: "high" }],
    verified: ["每功能门禁 test+analyze 由 world.run 实跑", "收尾 build apk 实跑（未通过）"],
    notCovered: ["真机验证", "应用内更新闭环"],
    commits: [
      { feature: "T1", message: t1Impl.commitMessage, pushed: t1Pushed },
      { feature: "T2", message: t2Impl.commitMessage, pushed: t2Pushed },
      { feature: "T3", message: t3Impl.commitMessage, pushed: t3Pushed },
    ],
  };
}
// 出包修复若有代码改动（工作区非干净），补一个 fix 提交
const fixPaths = await workingTreePaths();
let buildFixCommit = "";
if (fixPaths.length > 0) {
  log("出包修复改了 " + fixPaths.length + " 个文件，补提交");
  await world.run("git", ["-C", REPO, "add", ...fixPaths]);
  await world.run("git", ["-C", REPO, "commit", "-m", "fix: 修复思维题实现阻碍出包的问题"]);
  await world.run("git", ["-C", REPO, "push"], { timeoutMs: 120000 });
  buildFixCommit = "fix: 修复思维题实现阻碍出包的问题";
}

phase("收尾：更新待办表");
await agent("待办表更新", "你是 poem_quiz（D:/tools/poem_quiz）的文档维护者。只改 docs/development-progress.md，遵守文件既有格式。不要动其他文件，不要 git 操作。")
  .ask<string>(`思维题三功能（T1/T2/T3）已实现并提交，门禁全绿（test + analyze + build apk），待真机验证后进入发布批次。请更新 docs/development-progress.md：
1. 功能待办表：三行思维题（T1 诗词线索猜诗 / T2 数学逆向与情境题 / T3 情境运用）状态改为「待发布」，完成判据列注明「flutter test 全绿 ✓ + analyze ✓ + build apk ✓（待真机验证）」。
2. 顶部「最后更新」改为：2026-11-26（思维拓展题 T1-T3 实现完成：诗词线索猜诗 / 数学逆向与情境 / 情境运用，待发布）。
3. 「一句话状态」补一句：思维拓展题三功能（T1/T2/T3）已实现并提交，待发布。
4. 不要动「发布状态」等其他章节。返回一句话改动摘要。`);

// 待办表文档改动补提交
const docPaths = await workingTreePaths();
let docCommit = "";
if (docPaths.length > 0) {
  await world.run("git", ["-C", REPO, "add", ...docPaths]);
  await world.run("git", ["-C", REPO, "commit", "-m", "docs: 思维题三功能进入待发布"]);
  await world.run("git", ["-C", REPO, "push"], { timeoutMs: 120000 });
  docCommit = "docs: 思维题三功能进入待发布";
}

return {
  conclusion: "T1（诗词线索猜诗）、T2（数学逆向与情境）、T3（情境运用）全部完成：各自独立提交，test + analyze + release 出包三门禁全绿。T1 备注：" + (t1Impl.caveats || "无") + "。T2 备注：" + (t2Impl.caveats || "无") + "。T3 备注：" + (t3Impl.caveats || "无"),
  findings: [],
  verified: [
    "每功能门禁由 world.run 实跑（cmd /c flutter test 全量 + flutter analyze），失败经最多 4 轮修复后复跑确认",
    "每功能一轮独立评审（新上下文、只读），发现的问题进修复轮后复跑门禁",
    "收尾 flutter build apk --release 实跑通过（交付门禁三条全过）",
    "提交文件列表来自 git status（工作区起点干净），提交信息格式 <type>(scope): <summary>",
  ],
  notCovered: ["真机验证（平板布局、题型实际渲染）", "应用内更新闭环（属发布批次）"],
  commits: [
    { feature: "T1", message: t1Impl.commitMessage, pushed: t1Pushed },
    { feature: "T2", message: t2Impl.commitMessage, pushed: t2Pushed },
    { feature: "T3", message: t3Impl.commitMessage, pushed: t3Pushed },
    ...(buildFixCommit ? [{ feature: "出包修复", message: buildFixCommit, pushed: true }] : []),
    ...(docCommit ? [{ feature: "待办表", message: docCommit, pushed: true }] : []),
  ],
};
