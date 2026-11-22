# AGENTS.md — poem_quiz（拾）

古诗词 / 拼音 / 数学 / 英语 / 成语 / 数独答题 App。Flutter 实现，纯离线（题库内置于代码，进度存本地），**只面向自己使用**，也给孩子玩。

## 定位与边界

- 交付形态：**只有 Android APK**，自用。web 平台已于 2026-11-18 移除（`web/`、`build/web/`、`analysis_options` 的 exclude 一并清理）。
- 不做微信小程序 / 小游戏：微信按注册形态判类目，个人主体没有能承载交互式答题的类目，小游戏需换 Cocos/Canvas 重写。不要再提议 Taro/uni-app/小游戏迁移，也不要重新加 web 平台。
- 默认纯离线：题库内置、进度存本地、无账号体系。**联网点只有两类**，都由用户主动触发：设置页「检查更新」（下载版本清单与新 APK），英语与拼音音频首次播放时按条目懒下载（之后离线）。不做后台轮询、不发统计数据。新增功能默认保持离线。

## 常用命令

```bash
flutter test                          # 全部用例，改引擎/学龄/范围/题型/布局必跑
flutter analyze                       # analysis_options 已 exclude build/ android/
flutter run                           # 调试
flutter build apk --release           # → build/app/outputs/flutter-apk/app-release.apk（约 17MB）
```

- **用例数不要写死在本文件里**：题库扩容时用例数会变，写死必然过期。判据是「全绿」。
- **体积约束**：默认构建只打 `arm64-v8a`（`android/app/build.gradle.kts` 的 `abiFilters` + `android/gradle.properties` 的 `disable-abi-filtering=true`，两者缺一不可——Flutter 插件会在 `afterEvaluate` 里 `abiFilters.clear()` 覆盖你的配置）。三 ABI 全打是 48MB，不要回退。
- 剩余体积地板：`libflutter.so` 11.2MB + `libapp.so` 3.9MB，引擎占比 70%，再优化只能靠升级 Flutter 版本。
- 需要在 32 位老设备上跑时，改用 `--split-per-abi` 分包，不要改回默认全平台。

## 目录职责

| 路径 | 内容 |
|---|---|
| `lib/data/topic.dart` | **科目抽象** `Topic`：题库 + 分组维度 + 题型集合 + 存储键前缀；`TopicMode`（quiz / sudoku） |
| `lib/data/topics.dart` | `kTopics`（诗词、拼音、数学、英语、成语、数独）、`kDefaultTopic`；新增科目在这里加一条 |
| `lib/data/practice_scope.dart` | **练习范围 + 难度策略**：`PracticeScope` / `ScopeKind` / `ChallengeTier` / `PracticePlan`，把范围选择解析成出题计划 |
| `lib/data/pinyin.dart` | 拼音题库 `kPinyin`：320 条，年级 1-6 分档（**由 `tool/gen_pinyin.py` 生成，不要手改**） |
| `lib/data/math.dart` | 数学题库 `kMath`：358 条规则生成（一年级 196 / 二年级 162）；`MathExpr` 解析算式 |
| `lib/data/chengyu.dart` | 成语题库 `kChengyu`：74 条，年级 1-6 分档，选字补全 |
| `lib/data/english.dart` | 英语题库 `kEnglish`：82 条（字母 26 / 主题词 / 短句），年级 1-2（**由 `tool/gen_english.py` 生成，不要手改**） |
| `lib/data/english_audio.dart` | 英语音频键与缓存入口；共用 `speech_audio.dart` 的下载与播放 |
| `lib/data/pinyin_audio.dart` | 拼音点读音频键：按字词 UTF-16 编码生成稳定文件名 |
| `lib/data/speech_audio.dart` | 英语 / 拼音音频共用播放与缓存：**音频不在 APK 里**，按条目从 OSS 懒下载到本地 |
| `lib/data/poems.dart` | 诗词题库 `kPoems`：109 首，唐 65 / 宋 34 / 其余零散 |
| `lib/data/grade.dart` | 学龄档位 + `gradeForBirth()` 推算 + **题池加权** `cumulativeWeights()` / `rangeWeights()` / `fullCurriculumWeights()`；`ReviewMode`（off / standard 1/3 / reinforced 1/2） |
| `lib/data/profile.dart` | 全局个人档案 `UserProfile`：出生年月存裸键（不带科目前缀），学龄由它推算 |
| `lib/data/quiz_engine.dart` | 出题：15 类题型 + 干扰项选取 + 填空挖空；`poems` 为必填参数 |
| `lib/data/sudoku.dart` | 数独：五档难度（一星~五星，逐级解锁）+ 固定终盘合法置换 + 挖空（每挖一格校验唯一解）；支持 4×4 与 9×9 |
| `lib/data/quiz_session.dart` | 一局状态：进度、计分 |
| `lib/data/progress_store.dart` | 存档：SharedPreferences + JSON 字符串，**按科目分键** `<topicId>_<字段>` |
| `lib/data/update_service.dart` | 检查更新：单一来源 OSS CDN（`manifestUrl`） |
| `lib/models/` | `Poem` / `Question` 数据结构；`QuestionKind` 15 类题型（诗词 4 / 拼音 2 / 数学 3 / 成语 1 / 英语 5） |
| `lib/pages/` | 首页 / 答题 / 结算 / 学习 / 错题本 / 设置 / 数独，页面内私有 Widget 就地定义 |
| `lib/widgets/adaptive.dart` | 断点（600/840）+ `ContentFrame` 限宽容器，平板适配的唯一入口 |
| `lib/widgets/english_art.dart` | 英语内置矢量插图（`EnglishArt`），不引外部图片资源 |
| `lib/theme/app_theme.dart`、`lib/widgets/common.dart` | 宣纸 + 墨 + 朱印视觉体系；`AppColors` 全部色值 |
| `test/quiz_engine_test.dart` | 题库完整性、出题正确性、计分、学龄题池与加权、生涯模式 |
| `test/grade_test.dart` | 出生年月 → 学龄档位推算规则（入学分界、学年跨年、拓展档兜底） |
| `test/practice_scope_test.dart` | 范围/策略解析、题池权重、选项数与题型配比 |
| `test/progress_store_test.dart` | 存档键隔离、范围与策略持久化、生涯与错题本 |
| `test/layout_test.dart` | 三种窗口宽度下的渲染与横屏分栏（布局改动必跑） |
| `test/pinyin_test.dart` | 拼音题库完整性、声调标注、分年级题池、两种拼音题型 |
| `test/math_test.dart` | 数学题库、算式解析、三种算式题型、评语与摘要格式 |
| `test/sudoku_test.dart` | 数独终盘合法性、题面唯一解、档位映射、首页与盘面渲染 |
| `tool/` | 一次性辅助脚本（图标、拼音题库、英语题库与音频校验、adb 驱动答题），不参与构建 |

## 多科目架构

同一 app 内切换科目，进度与错题本**按科目隔离**。

- 页面一律从 `Topic` 取数，**不再直接引用 `kPoems`**。`kPoems` 只应出现在 `topics.dart` 的科目定义里。
- **科目切换入口是首页顶部的 `_TopicTabs`**（遍历 `kTopics` 横排），不是设置页。切换只换根壳里的 `_topic` / `_store` 指针——启动时所有科目的 `ProgressStore` 已一次读齐，切换路径上没有磁盘 IO。
- 新增科目 = 在 `topics.dart` 加一个 `Topic`：给 `id`（存储键前缀）、`entries`、`groupOf`（学习页分组维度）、`metaOf`（列表副标题）、`kinds`（本科目能出的题型）、`tagline`/`intro`（首页文案）、`unit`/`searchHint` 等文案。`seal` 仍是必填构造参数（填个两行字应付即可），但**不要给 `accent`/`accentSoft`/`seal` 接 UI**——字段保留兼容，界面已统一朱红。
- **题型随科目走，不随玩法走**：`Topic.kinds` 决定本科目能出哪些题型，`buildSession` 不传 `kinds` 时自动取科目题型，不会跨科目混题。玩法只决定题数与是否用错题本/生涯。
- **学龄分档**：诗词、拼音、数学、成语都按学龄分档，`buildSession` 的 `grade` 必填。拼音的年级不是「几年级学拼音」（拼音集中在一上教完），而是**题目难度分档**：一年级声韵母与拼读、二年级复韵母与轻声、三年级平翘舌与前后鼻音、四年级易错声韵母、五六年级多音字与进阶易错音。
- **学龄由出生年月推算，不是用户选择的**（2026-11-19 改）：`gradeForBirth(birthYear, birthMonth)` 按 9 月 1 日入学分界推出在读年级，九年级以上与未入学都落拓展档。出生年月存 `UserProfile`（裸键 `birth_year` / `birth_month`，全局一份，不属于任何科目），设置页修改。**首页没有 `_GradeCard` 了**——推算结果只作为练习范围的默认值。
- **练习范围与难度策略是两个正交维度**（2026-11-20 改）：`PracticeScope` 决定「出哪些年级的条目」（跟随推荐 / 指定年级 / 年级区间 / 教材全覆盖 / 仅拓展 / 全库），`ChallengeTier` 决定「怎么考」（轻松 / 标准 / 挑战，三档均为 A、B、C、D 四个选项；轻松多认读 / 挑战多回忆）。两者按科目存在 `ProgressStore` 的 `practice_scope` / `challenge_tier` 键，由 `resolvePracticePlan()` 解析成 `PracticePlan`（`weights` + `optionCount` + `kindWeights` + 干扰项偏好），再喂给 `QuizEngine.generate`。**不要在 UI 里重算计划**，首页只调 `resolvePracticePlan()`。
- **`Topic.graded` 由题库推导，不是构造参数**：`entries` 跨两个年级以上才为 true。数学题库含一、二年级条目（`graded` 自动为 true），推算档高于题库最高年级时题池只含低年级条目，由题池累加加权自然兜底，无需特判。
- **展示文案全走科目**：`nameOf` / `summaryOf` / `detailOf` / `summaryFromId` / `marks` 都是可选钩子，页面一律调 `displayNameOf()` / `displaySummaryOf()` / `displayDetailOf()` / `summaryOfId()` / `markFor()`，不要自己拼书名号或写死评语。诗词是「《静夜思》」与「唐 · 李白《静夜思》」，拼音是「重」与「重 · zhòng」，数学是「3 + 4」与「3 + 4 = 7」，成语是「一心一意」与「一心一意 · yì xīn yí yì」。
- `Topic` 的条目暂复用 `Poem`：`title` 当条目名，`author` 当副信息，`dynasty` 当分组值，`lines` 当正文。字段真的不够用时再建新类型，不提前抽象。
- **棋盘玩法科目（数独）**：`Topic.mode = TopicMode.sudoku`，`entries` 与 `kinds` 为空。盘面由 `Sudoku.open(difficulty)` 按难度档现生成，不走 `QuizEngine`。这类科目 `graded` 恒为 true（空题库推导），首页把练习范围卡换成**难度关卡列表**（一星~五星），并隐藏玩法卡、学习模式与错题本——它们都建立在题库之上。新增棋盘类玩法时复用 `TopicMode` 与首页的 `isBoardGame` 分支，不要再往题库抽象里塞。
- **数独与年级无关，靠逐级解锁推进**：`SudokuDifficulty` 五档，一星恒开，其余档要上一档完成 `unlockAfter` 局才开（3/3/4/4）。一星是 **4×4** 小盘面，其余为 9×9。完成数存 `ProgressStore.stageCleared`（键是枚举名 `one`~`five`），走 `recordSudokuClear()`，**不写最高分/正确率**——数独没有对错率，混进问答科目的统计会互相干扰。另有 `stageBestSeconds` 记录单局最快用时。解锁门槛与判据都在 `SudokuDifficulty.unlockedBy()` 里，首页与页面都只调它，不要在 UI 里重算。
- **数独盘面必须唯一解**：`lib/data/sudoku.dart` 挖空时每挖一格都跑一次回溯计数（上限 2），不唯一就补回去。`test/sudoku_test.dart` 会独立重算解数校验。改挖空策略后必须重跑该用例——运行时校验是与终盘逐格比对（`sudoku_page.dart` 的 `_validate`），多解盘面会让另一种正确填法被判成错格。
- **数独平时不提示对错**（2026-11-22 改）：无实时红字冲突、数字键不显示剩余数——实时提示等于逐格报答案。填满最后一格才统一校验：全对结算，有错把错格标红（SnackBar 提示），改对红格自动再校验，**没有显式提交按钮，填满即校验**。顶栏「错 N」是当前红格数，不实时计每步错填；结算弹窗的「填错 N 次」才按总账。不要加回实时提示或剩余计数。
- **`detailOf` 不能省**：`Poem.fullText` 是 `lines.join()`，对拼音（逐字组词）、数学（算式 + 思路）、英语（例句两行）会挤成一行，所以这几种科目的展开正文各自 `join('\n')`。
- `QuizEngine` 的 `poems` 是必填参数——故意不给默认值，避免新科目忘记传题库时静默出成诗词题。
- `ProgressStore.load(topicId:)` 必须显式传科目 id。**没有旧存档迁移逻辑**（开发阶段，不兼容无前缀的历史键）。

### 拼音语音

- 两种题型、学习页与错题本都有喇叭，朗读当前字词，不新增听音题型；音频失败不挡作答。
- `tool/gen_pinyin.py --audio` 用百炼 `qwen-audio-3.1-tts-plus`、音色 `longanfengyue_v3.1` 生成 320 条 Opus（API Key 只走 stdin，`hot_fix.pronunciation` 按题库读音钉死多音字与轻声，儿化交给模型），上传至 `lliyuu-shi` 的 `shi-private/pinyin/v2/`；文件名按字词 UTF-16 编码，不依赖列表位置。**换音色必须顺延版本段**（v2→v3）：CDN 对 .opus 缓存一年、手机按 key 永久缓存，同名覆盖两边都不生效——**修正类同名覆盖也一样，必须刷对应 URL 的 CDN**。`hot_fix` 不是万能：觉得的 `de5` 标注反而把模型带偏成「觉梦/觉嘛」（四形态 × 多 seed 复验一致），该词在 `HOT_FIX_SKIP` 里跳过 hot_fix、靠模型默认读音（四 seed ASR 全对）；遇到 hot_fix 后读错的高频词，先试去掉 hot_fix。
- `python -I tool/verify_pinyin_audio.py` 全量检查文件与解码；可选 `--asr --model <本地目录>` 辅助列疑点。**短单字 ASR 误报多、不能可靠区分声调**，多音字与轻声要结合题库标注试听，损坏音频不上传。
- 音频仍不入 APK；`lib/data/speech_audio.dart` 与英语共用缓存和下载逻辑，英语 URL、缓存目录与 `files/en_audio_trace.log` 保持不变。

### 英语科目

- **以听为主**：听音选词（`englishListen`）与听句选义（`englishSentence`）的 `Question.focus` 为空串，答题页只渲染喇叭按钮。判题后题干**仍只留喇叭**（文案变「再听一遍」），原文与释义由反馈卡和高亮选项负责，不重复露出（2026-11-21 改，AGENTS.md 旧句「判题后才露出原文」已过期）。改答题页时不要假设 `focus` 非空。
- **音频不在 APK 里**：英语全靠听，设备自带 TTS 在中文 ROM 上常缺英文音色或读错元音（实测 Aria 孤立朗读 `cat` 时 /æ/ 偏离自身参照 56%，接近 /e/），所以音频用百炼 `qwen-audio-3.1-tts-plus`、音色 `longanfengyue_v3.1` 预生成（2026-11-21 起，与拼音统一音色），放 OSS `lliyuu-shi` 的 `shi-private/en/v2/`（CDN `media.lliyuu520.cn`），首次播放时按条目下载到本地缓存，之后离线。**换音色必须顺延版本段**（v2→v3，拼音同理）：CDN 对 .opus 缓存一年、手机按 key 永久缓存，同名覆盖两边都不生效。
- `pubspec.yaml` **逐个声明**三个音效 wav，不写目录——目录写法会把 `assets/audio/en/` 一起收进包（Flutter 的目录声明是递归的，早期注释写的「不递归」是错的）。本地 `assets/audio/en/` 只是上传 OSS 前的源文件，不该进包。
- 加了新词之后要跑：`python -I tool/gen_english.py --audio`（API Key 只走 stdin）→ `python -I tool/verify_english_audio.py`（ASR 全量校验）→ 上传 `shi-private/en/v2/`。校验不通过就别上传，一个错读音就是给孩子的错误输入。字母合成直接喂原字母「A.」，Qwen 自己读对字母名；**唯一例外 N**——风悦把「N.」稳定读成 /ʌn/（五种 seed 复验一致），`letter_n.opus` 沿用旧 Jenny 音频，重新生成后若缺失要从备份补回（`.wip_backup/english_jenny_opus/letter_n.opus`）。个别裸词形态读不稳的在 `gen_english.py` 的 `TEXT_OVERRIDES` 里改写（egg 带冠词、Key/Rice/Rain 用小写），改写文本都经 ASR 逐字复验后才固化。**sent_bread 必须走服务端原生 opus**（`NATIVE_OPUS_RATES`，rate 1.05）：本地「mp3 → ffmpeg libopus」转码会把 is bread 的 /b/ 浊音瞬态削成 /p/，32k~128k 全中，服务端编码器没这个问题。
- `QuizEngine._tryMake` 的 switch 必须覆盖 `QuestionKind` 全部成员（含 5 个 `english*`），否则 switch 不穷尽会让**整个测试套件编译不过**，表现为「loading ...」后直接失败，而不是某条用例红。
- **英语干扰项要排除字母条目**：字母也是纯小写英文，混进「听音选词」会变成「听 cat 选 H」。`_englishListen` 的 `excludePoem` 里已排除 `_isEnglishLetter`。
- 拼单词（`englishSpell`）属于填空题：`Question.isBlank` 包含它，`_BlankPrompt` 对它走「单行紧贴显示」（`c□t`）而不是诗句的上下分行，否则看不出是个词。
- **下载不能用 `HttpClient`**：两个已踩的坑——① 它的 `connectionFactory` 在 HTTPS 下会把 SNI 退化成 IP，CDN 直接回 400；② 默认路径在无 IPv6 出口的网络（模拟器、部分移动网络）会先试 AAAA 记录并长时间挂起。`_httpsGet()` 因此手写：IPv4 建 TCP + 域名做 SNI，再自己拼 HTTP。改这块时两者都要保住。
- **不要给下载做 in-flight 去重**：`_inflight[key] ??= fetch().whenComplete(...)` 会让调用方的 `await` 在下载完成后仍不返回（表现为「下载成功但播放不触发」，trace 只到 done 就断）。连点重复下载的代价可接受。
- **`SpeakButton` 用 `GestureDetector` 而不是只靠 `InkWell`**：它会被放进不在 Material 上下文里的父级（填空题干、列表项），InkWell 会静默失效。
- **`AudioPlayer` 的每个调用都加超时**：`setReleaseMode` / `setSource` / `resume` 在设备上可能不回调，`await` 会挂住。用 `setSource` + `resume` 而不是 `play(DeviceFileSource)`，每步单独超时。
- **诊断靠落文件，不靠 logcat**：release 与 debug 包的 `debugPrint` 都不进 logcat。`EnglishAudio.trace()` 写到 `files/en_audio_trace.log`，用 `adb shell run-as com.lyu.poem_quiz cat files/en_audio_trace.log` 读。
- **模拟器验证要临时改 ABI**：`android/app/build.gradle.kts` 的 `abiFilters` 只有 `arm64-v8a`，`gradle.properties` 的 `disable-abi-filtering=true` 会覆盖它。在 x86_64 模拟器上验证要先临时改成 `listOf("arm64-v8a", "x86_64")` 且把 `disable-abi-filtering` 设为 false，验完**必须改回来**（否则 release 包会变 48MB）。

## 启动前状态

`main.dart` 是**有状态根壳**：启动时读 `last_topic`（SharedPreferences 里的裸键，不带科目前缀）决定默认科目，**一次把 `kTopics` 里所有科目的 `ProgressStore` 读齐**，再 `await UserProfile.load()` 后 `runApp`。切换科目时根壳只换 `_topic` / `_store` 指针并 `setState`，`last_topic` 后台 fire-and-forget 写入。

**不再用 `ValueKey(topic.id)` 强制整树重建**——那会让切换卡顿。`HomePage` 在 `didUpdateWidget` 里自行同步引擎、难度档、练习范围、难度策略与玩法。

`ProgressStore`、`UserProfile` 和 `Topic` 通过构造函数一路传给页面，页面用 `setState` + `AnimatedBuilder(animation: store)` 刷新，**没有 Provider/Riverpod/GetX**，不要为此引入状态管理库。

## 数据与算法约束（改代码前必读）

- **`Poem.lines` 按「句」拆分，标点留在句尾**。接句题靠 `lines[i]` → `lines[i+1]` 定位，合并或去标点会直接破坏出题。
- `Poem.id = '朝代|作者|标题'`，是错题本和生涯进度的唯一键。**新增条目必须保证三元组唯一**（`test` 里有 id 唯一性用例）。
- `grade`：1~9 对应一年级~九年级（成都现行统编版教材），**0 = 拓展**（教材未收的课外名篇与高中篇目），默认 0。漏标时宁可落进拓展档，也不混进低年级题池。
- 题池**累加 + 加权**，实现在 `grade.dart`：选 N 年级时池为 1..N，本年级权重 1、低一档 1/3、再低 1/9（`ReviewMode.standard`）；`reinforced` 改用 1/2，`off` 只留目标年级。衰减取 1/3 而非 1/2，是因为低年级条目本来就多（一年级 8 首对六年级累计 71 首），1/2 会让低年级题反超本年级。拓展档不参与年级累加，按顶层权重的 1/3 叠加。
- 诗词年级分布：一 8 / 二 11 / 三 13 / 四 12 / 五 15 / 六 12 / 七 8 / 八 7 / 九 5 / 拓展 18。单年级池小是正常的，一局题数自适应（`total` 取实际题数）。
- **拼音题库由脚本生成，不要手改 `pinyin.dart`**：`python -I tool/gen_pinyin.py` 用 pypinyin 按词组算声调（多音字取词内读音，如「长大 zhǎng」「银行 háng」「倔强 jiàng」），儿化与轻声在脚本的 `OVERRIDES` 里定向修正。手写 300+ 条必然出现声调错误，一个错调就是一道错题。
- **pypinyin 不保证轻声**：亲属叠词「爸爸/妈妈/哥哥/姐姐/妹妹」它给原调，「衣服」给 fú，只有「弟弟/伯伯/婆婆」给对了。这些已写进 `OVERRIDES`。测试分两层——白名单查「有没有调号」，`亲属叠词与常见轻声词读音符合规范` 逐条钉死「调号对不对」，只靠白名单会把轻声错误放过去。
- **英语题库同样由脚本生成**：`tool/english_bank.json` 是源，`tool/gen_english.py` 生成 `lib/data/english.dart`；音频用 `tool/check_english_audio.py` / `tool/verify_english_audio.py` 校验。字母合成直接喂原字母「C.」，Qwen 会读出字母名（edge-tts 时代「C. A. T. 丢尾字母」才需要改写成 `see`，方案已淘汰）。
- 拼音题库**字词与读音都必须唯一**：同音字（如「木/目」都是 mù）会让「选字词」题出现两个正确选项，测试会拦。
- 干扰项必须来自**别的条目**，且作者题排除同作者、标题题排除同名、拼音「选读音」排除同读音、「选字词」排除同字词，否则选项里会出现重复正确答案。拼音接入时漏掉这一条，诗词题库下会抽出两个「李白」。
- 填空题：字池需能精确拼出答案（同一字出现几次就放几次），干扰字不得与答案字重复；`_plain()` 的正则负责去标点，长度计算、挖空、字池都依赖它——改正则要同时检查 `_minLineLength` 与 `blankLen` 分支。
- 计分：**每题 1 分，只算对错**，年级与难度策略不影响得分（2026-11-19 取消倍率与连击加成）。答错不倒扣。**不做连击**（2026-11-20 移除局内连击条、反馈文案、结算「最高连击」与 `best_combo` 存档键），不要加回。
- 一局内每条目只出一次题；`preferPoemIds`（错题优先）只影响前 3 题，其余打乱。

## 关键不变量

- **算式题（数学科目）**：`Poem.title` 是「3 + 4」、`author` 是得数，由 `MathExpr.of()` 解析；解析不出的条目出不了算式题（返回 null 而不是崩）。干扰项按数值接近程度取（7 的邻居比 90 更有迷惑性）。
- **`_pickFromOthers` 先去重再截窗口**：算式题里同一得数被几十条共用（整十数只有 10 种得数），若先按距离截窗口再去重，会凑不齐选项而整类题退化成另一种问法。`test/math_test.dart` 里有对应用例。
- **成语题（`idiomBlank`）**：挖掉四字中的一字，从字池选字补全。字池需能拼出原成语，干扰字不得与正确字重复。
- 题库或出题逻辑改动后，`flutter test` 必须全绿——测试断言了「每档都能出满实际题池容量」与「每个年级都有篇目」，把某年级的篇目清空或收紧干扰项条件会导致失败。
- 诗词原文与作者、标题需准确；这是内容产品，错字比 UI 瑕疵严重。
- 新增诗词顺延 `// ── 唐 · 李白 ──` 这样的分组注释，保持文件可按朝代作者浏览。

## 平台注意事项

- 仅 Android。`minSdk`/`targetSdk` 走 `flutter.*` 默认值，未额外指定。
- **正式签名**：release 用 `D:/tools/keys/poem_quiz.keystore`（30 年有效期），配置在 `android/keystore.properties`（不入库，缺失时回落 debug 签名）。**keystore 或密码丢失 = 无法覆盖安装，只能卸载重装丢全部存档**，务必异地备份。
- **分发：单一来源，只用自有 OSS**（`oss://lliyuu520/apk/`，CDN `oss.lliyuu520.cn`）。曾用 `poem_quiz-dist` 仓库 + jsDelivr 兜底，已弃用——jsDelivr 对同名文件的缓存极其顽固，长期返回两三个版本之前的旧清单，刷新也不生效，维护成本高于收益。`UpdateService.manifestUrl` 是单个常量，不要加回多源回退。改清单后必须刷新 CDN 缓存。
- **App 内检查更新**：设置页「关于」区。安装走 `PackageInstaller`（新版系统不允许直接 `ACTION_VIEW` 拉起 APK）。四个已踩的坑：
  - commit 的 `PendingIntent` **必须 MUTABLE**。用 `FLAG_IMMUTABLE` 会报「The commit() status receiver should come from a mutable PendingIntent」，装不上。
  - Manifest 必须声明 `REQUEST_INSTALL_PACKAGES`，否则 commit 之后系统不弹安装框。
  - 该权限还要用户在系统设置里单独开启。**未开启时 commit() 不报错、系统静默丢弃请求**，用户永远等不到弹窗（vivo 实测：APK 已下载进 cache，界面却停在「请在系统弹窗中确认安装」）。所以安装前必须 `UpdateService.canInstall()` 先查，未授权就显示「去开启授权」按钮（`openInstallSettings`）。
  - **`STATUS_PENDING_USER_ACTION` 是 -1，不是失败**——`STATUS_FAILURE` 实际是 1。commit 成功后系统先发 -1，确认弹窗的 Intent 在 `EXTRA_INTENT` 里，receiver 必须 `startActivity` 拉起它；漏掉这个分支会误报「安装失败（-1）」且永远看不到确认页（0.4.1 上实测）。通用失败时把 `EXTRA_STATUS_MESSAGE` 一并展示，那才是真实原因。
  - 排障时看 `cache/` 有没有 `poem_quiz_<code>.apk`：有就说明下载成功、问题在安装授权那一步。
- **应用名「拾」**（2026-11-20 由「日知」改）：`android:label`、`MaterialApp.title`、设置页版本前缀、`pubspec.yaml` description 四处要同步。包名 `com.lyu.poem_quiz` 与仓库名 `poem_quiz` 未改。
- **图标由 `tool/gen_icon.py` 生成，改图标重跑脚本而不是手改 png**。`CHAR = "拾"` 是唯一的字面变量，换名字只改这一处。脚本同时产出：旧式 `ic_launcher.png` / `ic_launcher_round.png` 五档，以及自适应图标（`mipmap-anydpi-v26/` + `ic_launcher_foreground.png` + `drawable/ic_launcher_background.xml`）。**自适应前景必须按 66dp 安全圆的内接正方形算字号**（`s*33/108/√2`），按画布比例直接铺会让圆形蒙版切掉字角。
- 字号仍硬编码（`serif(32)` 之类），**不做随窗口等比缩放**；响应式用于「限宽、分栏与各页的宽屏布局」，宽屏档的放大字号（题干 34pt、提示 19pt 等）是写死的固定值，不是缩放系数。
- **平板适配**（2026-11-22 重设计）：断点集中在 `lib/widgets/adaptive.dart`（compact <600 / medium 600~839 / expanded ≥840）。窄屏一律单列 + `ContentFrame` 限宽居中；宽屏各页有专属布局——答题页双栏舞台（题干左栏垂直居中、选项右栏居中、反馈卡+主按钮收右栏底部走 AnimatedSize，判题前后题干纹丝不动）、首页标题页签钉顶+玩法簇垂直居中（超高竖屏切 roomy 变体放大玩法卡）、学习页/错题本双列分摊、设置/结算双栏、数独关卡一行横排+盘面 560dp。题干卡的提示语（「出自哪一首诗？」）是 16/19pt 墨色加粗正文，不是辅助小字——拼音/英语题干只有一个字或一个词，提示语是孩子唯一能读懂的任务说明；算式题 focus 里的 □ 由 `_plainFocus` 渲染成写字格，不是纯字符。新增页面：窄屏套 `ContentFrame` 即可，宽屏要专门排布局，且 **AdaptiveBuilder 必须放在 ContentFrame 外侧**（内侧量到的是限宽减边距后的宽度，会把 840+ 的窗口误判成 medium）。三个渲染坑：含 `LayoutBuilder` 的子树不能进 `IntrinsicHeight`（用 `ConstrainedBox(minHeight)`+`Center` 模式居中）；松约束里的 `Row(crossAxisAlignment: stretch)` 必须包 `IntrinsicHeight`；宽屏首页的主区域不要用 scroll 包 Expanded。
- 方向锁在平板上**无效**：`targetSdk = 36`，Android 16 对 smallestWidth ≥600dp 的设备忽略 `screenOrientation`。横竖屏必须靠真布局适配，不要试图用 manifest 锁方向。
- 触控目标保持 ≥48dp，**不要用 `VisualDensity.compact`**（会把 48 压到 40）。
- `kSerifFallback` 依赖设备上的思源/宋体字体；Android 上一般能命中 Noto Serif CJK，缺失时会退到系统默认衬线。内容正文用内置 `WenKai`（霞鹜文楷子集），拉丁部分是单层 ɑ/ɡ，与教材拼音一致。

## 视觉规范

宣纸底（`#F8F2E6`）+ 墨色文字 + 朱印（`#A63A2E`）点缀，衬线字体、字距 1~6、无强阴影、卡片用 1px 描边而非 elevation。颜色一律取 `AppColors` 常量，不写裸色值。

- **全科目统一朱红**：tab 选中线、主按钮、chip 都用 `AppColors.seal`，不按科目换色——切科目换整套配色会让人觉得换了另一个 App。
- `AppColors` 里仍有科目色（`pinyin` 青 / `math` 赭 / `sudoku` 靛 / `chengyu` 绛紫 / `english` 靛青），以及 `Topic.accent` / `Topic.accentSoft` / `Topic.seal` 字段。**这些当前不接 UI**，保留兼容；新增科目不用管它们。
- **首页整页不滚动**：窄屏 `Column + Expanded + Spacer`，玩法是横排三个紧凑 `_ModeChip`（约 68dp）；宽屏标题与页签钉顶、玩法簇整体垂直居中（`_wideHomeBody`，玩法簇内部才允许滚动），超高竖屏切 roomy 变体。没有「关卡/练习范围/玩法」分隔标题。加区块前先确认整页放得下，优先压缩而不是改成滚动。
- 首页右上角是书本图标 `Icons.auto_stories_outlined`，不再有印章文案。
