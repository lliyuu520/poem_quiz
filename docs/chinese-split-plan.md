# 语文拆散：归组导航 + 4 个子科目（已拍板）

> 状态：**已实现，待发布**（2026-11-24；test 249 全绿 / analyze 无问题 / release APK 18.3MB 构建通过）。
> 对应 todo：`docs/development-progress.md`「语文拆散：归组导航 + 4 个子科目」。
> 前置「§0 假设与 D1–D8 拍板」已完成，完成判据见 §11。

## §0 事实基线（代码事实，不随决策改变）

- 现状平铺 6 科（`topics.dart:244-251`）：诗词(113) / 拼音(320) / 数学(488) / 英语(135) / 成语(122) / 数独(棋盘)。
  首页一整行 `_TopicTabs` 平铺（`home_page.dart:448`），无分组层级。
- 语文相关原有 3 科（诗词/拼音/成语）；数学/英语/数独非语文。
- `Topic` 是扁平 class（`topic.dart:25-48`）：单一 `entries`/`groupOf`/`kinds`，`id` 即存储前缀。
- 存档键：`<topicId>_<field>`（`progress_store.dart:75`）、`cloud_version_<topicId>` 与 `/api/saves/<topicId>`
  （`account_service.dart:38/137/163`）、`last_topic` 裸键（`main.dart:15`）。**改 id = 旧存档失联**。
- 条目复用 `Poem`，id = `dynasty|author|title`（`poem.dart:26`），唯一性靠数据约定。
- 年级分布：诗词 1-9+拓展18、拼音 1-6、成语 1-6；`resolvePracticePlan`（`practice_scope.dart:264`）
  从 entries 自算 `present/maxSchoolGrade/hasExtension`，与 `Topic` 同名 getter 重复。
- `quiz_engine.dart` 的 `_tryMake` switch 必须穷尽 `QuestionKind`，否则**整个测试套件编译不过**。

## D1–D8 拍板结论

| 项 | 结论 | 理由 |
|---|---|---|
| **D1** 第 4 子科目 | **词语（同义/反义）**，语文 4 科 = 诗词/拼音/成语/词语 | 用户拍板；词语是小学字词基础核心，比文言文更易校验 |
| **D2** 题库来源 | **我来整理**：脚本生成 `lib/data/words.dart`，1-6 年级分档，不手打 | 用户拍板 |
| **D3** 导航形态 | **二级导航**：一级组（语文/其他）→ 二级子科目 | 用户拍板；符合「归组导航」语义 |
| **D4** 是否改 id | **不改任何现有 id**，零迁移。词语是新增 id `words` | 项目无旧存档迁移逻辑；新增键不影响旧存档 |
| **D5** 数据承载 | `Topic` 加 `group: TopicGroup` 字段（默认 `other`）；`kTopics` 仍平铺 `List<Topic>`，导航层按 group 归类 | 不动 `resolvePracticePlan` 与测试里的 `topic.entries` |
| **D6** 首页呈现 | 新增一级组 tab（语文/其他）+ 二级科目 tab；沿用钉顶/ContentFrame/AdaptiveBuilder；「整页不滚动」不变 | 维持现有布局约束 |
| **D7** 词语题型 | 新增 `synonymOf`/`antonymOf` 两种 `QuestionKind`；数据塞进 `Poem`（同义词/反义词条目） | 复用引擎；需同步 `question.dart` label、`isXxx`、`_tryMake` switch |
| **D8** 迁移兼容 | 零迁移；`last_topic` 旧值失效时回落 `kDefaultTopic`（现有 `firstWhere` 已覆盖）；新增 `last_group` 裸键记上次组 | 全部增量改动，可回退 |

## 词表方案（D2 细化）

- **规模**：82 个词条（1-6 年级），286 条人工挑选的关系对（同义 149 / 反义 137）。
- **数据形态**：一个 `Poem` = 一个「词 → 关系词」条目，`dynasty` 存关系类型（`同义词`/`反义词`），
  `author` 存关系词，`title` 存词条，`lines` 存例句，`grade` 存年级。
  `id = dynasty|author|title` 天然唯一（同一词的不同关系/不同关系词不冲突）。
- **生成方式**：`tool/word_bank.json`（源，人工整理）→ `tool/gen_words.py` → `lib/data/words.dart`，
  像拼音/英语题库一样**不手改生成物**。生成物含 `kWords` + `kWordSynonyms`/`kWordAntonyms` 两张闭包表。
- **闭包只用于排除、不用于出题**：题目只取 JSON 里人工挑选的关系对——闭包会带出
  「坏 → 优秀」这类语法通、但对孩子别扭的题；闭包（同义传递、反义沿同义传播）只喂给
  引擎做干扰项排除，确保「找近义词」的选项里不会混进该词的另一个近义词（一题两答案）。
  这是成语「知词义」排除释义里提到的成语的同类坑。

## 实现影响面

| 文件 | 改动 |
|---|---|
| `lib/data/topic.dart` | 加 `TopicGroup` 枚举 + `Topic.group` 字段 |
| `lib/data/topics.dart` | 6 科标 group；新增 `kWordsTopic` |
| `lib/data/words.dart` | 新题库（脚本生成） |
| `tool/word_bank.json` / `tool/gen_words.py` | 词表源与生成器 |
| `lib/models/question.dart` | 加 `synonymOf`/`antonymOf` + label + `isWordKind` |
| `lib/data/quiz_engine.dart` | `_tryMake` switch 加两个 case + 出题函数 |
| `lib/pages/home_page.dart` | `_TopicTabs` 改二级导航；范围卡对新题型适配 |
| `lib/main.dart` | `last_group` 记忆与透传 |
| `test/*` | 词库完整性/唯一性、新题型、分组导航渲染、零迁移回归 |

## §11 完成判据

1. D1–D8 全部拍板（本文已固化）。
2. 词语题库完整性用例绿（id 唯一、每档有题、每种题型可出题、干扰项无多答案），`flutter test` 全绿。
3. 二级导航在 compact/medium/expanded 三档渲染正确，`test/layout_test.dart` 增加用例。
4. 现有 6 科存档、错题本、云同步、last_topic 零迁移仍可用（回归用例绿）。
5. `flutter analyze` 无问题；`flutter build apk --release` 成功、体积未异常增长。
6. 待办表状态流：规划中 → 实现中 → 待发布（发版与提交解耦）。
