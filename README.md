# 拾（poem_quiz）

古诗词/拼音/数学答题 App。Flutter 实现，题库内置，进度存本地。
自用：APK 手动安装；检查更新走 dist 仓库。

## 发布流程

1. 改 `pubspec.yaml` 的 `version`（versionCode++）
2. `flutter build apk --release`（正式签名，需 `android/keystore.properties`）
3. APK 拷到 dist 仓库（poem_quiz-dist，public），命名 `poem_quiz_<ver>.apk`
4. 更新 `version.json` 与 `version-2.json` 的 versionCode/Name/apkUrl/notes
5. dist 仓库 push；jsDelivr 有缓存，新增文件名（version-N.json）最稳

## 下载与更新

- 浏览器下载：`https://cdn.jsdelivr.net/gh/lliyuu520/poem_quiz-dist@main/poem_quiz_0.2.0.apk`
- App 内：设置 → 关于 → 检查更新（仅点击时联网）

## keystore

- 位置 `D:/tools/keys/poem_quiz.keystore`，密码在 `D:/tools/keys/poem_quiz_pwd.txt`
- **丢失 = 无法覆盖安装，只能卸载重装丢存档**，务必备份这两份
- `android/keystore.properties` 不入库；缺失时回落 debug 签名
