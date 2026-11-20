# 拾（poem_quiz）

古诗词 / 拼音 / 数学 / 英语 / 成语 / 数独答题 App。Flutter 实现，题库内置，进度存本地。
自用：APK 手动安装；检查更新走自有 OSS。

## 发布流程

1. 改 `pubspec.yaml` 的 `version`（versionCode++）
2. `flutter build apk --release`（正式签名，需 `android/keystore.properties`）
3. 上传 APK 到 OSS：`apk/<日期>/poem_quiz_<ver>_<code>.apk`
4. 更新 `apk/version.json` 的 versionCode / versionName / apkUrl / notes
5. 刷新 CDN 缓存（必须，否则用户仍拿到旧清单）：
   `aliyun cdn RefreshObjectCaches --profile user-server --ObjectPath "https://oss.lliyuu520.cn/apk/version.json" --ObjectType File`

### OSS 上传命令

```bash
ossutil cp build/app/outputs/flutter-apk/app-release.apk \
  oss://lliyuu520/apk/<日期>/poem_quiz_<ver>_<code>.apk \
  -c <临时配置> -e oss-cn-chengdu.aliyuncs.com --region cn-chengdu -f
```

- 覆盖上传必须带 `-f`，否则会卡在交互确认。
- 临时配置的 AK 取自 `~/.aliyun/config.json` 的 `user-server` profile。
- **单一来源**：不再有 dist 仓库 / jsDelivr 兜底。jsDelivr 对同名文件的缓存
  极其顽固，长期返回旧清单，已弃用。

## 下载与更新

- 浏览器下载：`https://oss.lliyuu520.cn/apk/<日期>/poem_quiz_<ver>_<code>.apk`
- App 内：设置 → 关于 → 检查更新（仅点击时联网，清单地址见 `lib/data/update_service.dart`）

## 英语音频

英语朗读音频不在 APK 里，托管在 `oss://lliyuu520/en-audio/`（CDN `oss.lliyuu520.cn/en-audio`），
首次播放时按条目下载到本地缓存。

加词或改题库后：

1. `python -I tool/gen_english.py --audio`（合成缺失的音频并生成 manifest）
2. `python -I tool/verify_english_audio.py`（ASR 全量校验，不通过就别上传）
3. 上传 `assets/audio/en/` 到 `oss://lliyuu520/en-audio/`

## keystore

- 位置 `D:/tools/keys/poem_quiz.keystore`，密码在 `D:/tools/keys/poem_quiz_pwd.txt`
- **丢失 = 无法覆盖安装，只能卸载重装丢存档**，务必备份这两份
- `android/keystore.properties` 不入库；缺失时回落 debug 签名
