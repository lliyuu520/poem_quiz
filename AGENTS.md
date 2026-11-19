# AGENTS.md — poem_quiz

古诗词答题 App。Flutter 实现，纯离线（题库内置于代码，进度存本地），**只面向自己使用**。

## 定位与边界

- 交付形态：**只有 Android APK**，自用。web 平台已于 2026-11-18 移除（`web/`、`build/web/`、`analysis_options` 的 exclude 一并清理）。
- 不做微信小程序 / 小游戏：微信按注册形态判类目，个人主体没有能承载交互式答题的类目，小游戏需换 Cocos/Canvas 重写。不要再提议 Taro/uni-app/小游戏迁移，也不要重新加 web 平台。
- 无后端、无网络请求、无账号体系。新增功能默认也保持这一点。

## 常用命令

```bash
flutter test                          # 42 个用例，改引擎/学龄/布局必跑
flutter analyze                       # analysis_options 已 exclude build/ android/
flutter run                           # 调试
flutter build apk --release           # → build/app/outputs/flutter-apk/app-release.apk（约 17MB）
```

- **体积约束**：默认构建只打 `arm64-v8a`（`android/app/build.gradle.kts` 的 `abiFilters` + `android/gradle.properties` 的 `disable-abi-filtering=true`，两者缺一不可——Flutter 插件会在 `afterEvaluate` 里 `abiFilters.clear()` 覆盖你的配置）。三 ABI 全打是 48MB，不要回退。
- 剩余体积地板：`libflutter.so` 11.2MB + `libapp.so` 3.9MB，引擎占比 70%，再优化只能靠升级 Flutter 版本。
- 需要在 32 位老设备上跑时，改用 `--split-per-abi` 分包，不要改回默认全平台。

## 目录职责

| 路径 | 内容 |
|---|---|
| `lib/data/topic.dart` | **科目抽象** `Topic`：题库 + 分组维度 + 搜索提示 + 存储键前缀 |
| `lib/data/topics.dart` | `kTopics`（当前只有诗词）、`kDefaultTopic`；新增科目在这里加一条 |
| `lib/data/poems.dart` | 诗词题库 `kPoems`：109 首，唐 65 / 宋 34 / 其余零散 |
| `lib/data/grade.dart` | 学龄档位：一年级~九年级 + 拓展，**只收窄题池范围，不过滤题型** |
| `lib/data/quiz_engine.dart` | 出题：四类题型 + 干扰项选取 + 填空挖空；`poems` 为必填参数 |
| `lib/data/quiz_session.dart` | 一局状态：进度、连击、计分 |
| `lib/data/progress_store.dart` | 存档：SharedPreferences + JSON 字符串，**按科目分键** `<topicId>_<字段>` |
| `lib/models/` | `Poem` / `Question` 数据结构 |
| `lib/pages/` | 首页 / 答题 / 结算 / 学习 / 错题本 / 设置，页面内私有 Widget 就地定义 |
| `lib/widgets/adaptive.dart` | 断点（600/840）+ `ContentFrame` 限宽容器，平板适配的唯一入口 |
| `lib/theme/app_theme.dart`、`lib/widgets/common.dart` | 宣纸 + 墨 + 朱印视觉体系 |
| `test/quiz_engine_test.dart` | 题库完整性、出题正确性、计分、学龄题池与加权、生涯模式 |
| `test/layout_test.dart` | 三种窗口宽度下的渲染与横屏分栏（布局改动必跑） |
| `tool/` | 一次性辅助脚本（图标生成、adb 驱动答题），不参与构建 |

## 多科目架构（拼音/成语/算术待接入）

同一 app 内切换科目，进度与错题本**按科目隔离**。

- 页面一律从 `Topic` 取数，**不再直接引用 `kPoems`**。`kPoems` 只应出现在 `topics.dart` 的科目定义里。
- 科目切换入口在**设置页**（首页右上角齿轮）。设置页切换后 `popUntil` 回首页，因为当前页的 store 已属于旧科目。
- 新增科目 = 在 `topics.dart` 加一个 `Topic`：给 `id`（存储键前缀）、`entries`、`groupOf`（学习页分组维度）、`metaOf`（列表副标题）、`unit`/`searchHint` 等文案。
- `Topic` 的条目暂复用 `Poem`：`title` 当条目名，`author` 当副信息，`dynasty` 当分组值，`lines` 当正文。字段真的不够用时再建新类型，不提前抽象。
- `QuizEngine` 的 `poems` 是必填参数——故意不给默认值，避免新科目忘记传题库时静默出成诗词题。
- `ProgressStore.load(topicId:)` 必须显式传科目 id。**没有旧存档迁移逻辑**（开发阶段，不兼容无前缀的历史键）。


## 启动前状态

`main.dart` 是**有状态根壳**：启动时读 `last_topic`（SharedPreferences 里的裸键，不带科目前缀）决定默认科目，`await ProgressStore.load(topicId:)` 后 `runApp`。切换科目时根壳重建 `ProgressStore` 并 `setState`，`HomePage` 用 `ValueKey(topic.id)` 强制整棵重建，避免残留上一个科目的选中态。

`ProgressStore` 和 `Topic` 通过构造函数一路传给页面，页面用 `setState` + `AnimatedBuilder(animation: store)` 刷新，**没有 Provider/Riverpod/GetX**，不要为此引入状态管理库。

## 数据与算法约束（改代码前必读）

- **`Poem.lines` 按「句」拆分，标点留在句尾**。接句题靠 `lines[i]` → `lines[i+1]` 定位，合并或去标点会直接破坏出题。
- `Poem.id = '朝代|作者|标题'`，是错题本和生涯进度的唯一键。**新增诗必须保证三元组唯一**（`test` 里有 id 唯一性用例）。
- `grade`：1~9 对应一年级~九年级（成都现行统编版教材），**0 = 拓展**（教材未收的课外名篇与高中篇目），默认 0。漏标时宁可落进拓展档，也不混进低年级题池。
- 题池**累加 + 加权**：选 N 年级时池为 1..N，本年级权重 1、低一档 1/3、再低 1/9，依次递减。衰减取 1/3 而非 1/2，是因为低年级条目本来就多（一年级 8 首对六年级累计 71 首），1/2 会让低年级题反超本年级。拓展档不参与年级累加。
- 年级分布：一 8 / 二 11 / 三 13 / 四 12 / 五 15 / 六 12 / 七 8 / 八 7 / 九 5 / 拓展 18。单年级池小是正常的，一局题数自适应（`total` 取实际题数）。
- 干扰项必须来自**别的诗**，且作者题排除同作者、标题题排除同名，否则选项里会出现重复正确答案。
- 填空题：字池需能精确拼出答案（同一字出现几次就放几次），干扰字不得与答案字重复；`_plain()` 的正则负责去标点，长度计算、挖空、字池都依赖它——改正则要同时检查 `_minLineLength` 与 `blankLen` 分支。
- 计分：**每题 1 分，只算对错**，年级不影响得分（2026-11-19 取消倍率与连击加成）。答错不倒扣、连击清零，连击仅用于展示。
- 一局内每首诗只出一次题；`preferPoemIds`（错题优先）只影响前 3 题，其余打乱。

## 关键不变量

- 题库或出题逻辑改动后，`flutter test` 必须全绿——测试断言了「每档都能出满实际题池容量」与「每个年级都有篇目」，把某年级的篇目清空或收紧干扰项条件会导致失败。
- 诗词原文与作者、标题需准确；这是内容产品，错字比 UI 瑕疵严重。
- 新增诗词顺延 `// ── 唐 · 李白 ──` 这样的分组注释，保持文件可按朝代作者浏览。

## 平台注意事项

- 仅 Android。`minSdk`/`targetSdk` 走 `flutter.*` 默认值，未额外指定。
- release 包目前用 debug 签名（`signingConfig = debug`），自用可接受；若要长期安装升级，应先建自己的 keystore，否则换机重装会丢本地存档。
- `android:label="诗词问答"`，图标由 `tool/gen_icon.py` 生成（朱印方章），改图标重跑该脚本而不是手改 png。
- 字号仍硬编码（`serif(32)` 之类），**不做等比缩放**；响应式只用于「限宽」与「横屏分栏」，见下条。
- **平板适配**：断点集中在 `lib/widgets/adaptive.dart`（compact <600 / medium 600~839 / expanded ≥840）。页面用 `ContentFrame` 限宽居中，答题页在 expanded 下走左右双栏（左题干、右作答 + 常驻按钮）。新增页面套 `ContentFrame` 即可，不要另写断点。
- 方向锁在平板上**无效**：`targetSdk = 36`，Android 16 对 smallestWidth ≥600dp 的设备忽略 `screenOrientation`。横竖屏必须靠真布局适配，不要试图用 manifest 锁方向。
- 触控目标保持 ≥48dp，**不要用 `VisualDensity.compact`**（会把 48 压到 40）。
- `kSerifFallback` 依赖设备上的思源/宋体字体；Android 上一般能命中 Noto Serif CJK，缺失时会退到系统默认衬线。

## 视觉规范

宣纸底（`#F8F2E6`）+ 墨色文字 + 朱印（`#A63A2E`）点缀，衬线字体、字距 1~6、无强阴影、卡片用 1px 描边而非 elevation。颜色一律取 `AppColors` 常量，不写裸色值。
