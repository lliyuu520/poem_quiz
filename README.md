# 拾（poem_quiz）

古诗词 / 拼音 / 成语 / 文学常识 / 歇后语 / 错别字 / 文言实词 / 词语 / 数学 / 英语 / 数独答题 App。
Flutter 实现，题库内置，进度存本地。自用：APK 手动安装；检查更新走自有 OSS。

## 发布流程

1. 改 `pubspec.yaml` 的 `version`（versionCode++）
2. `flutter build apk --release`（正式签名，需 `android/keystore.properties`）
3. 上传 APK 到 OSS：`apk/<日期>/poem_quiz_<ver>_<code>.apk`
4. 更新 `apk/version.json` 的 versionCode / versionName / apkUrl / notes
5. 刷新 CDN 缓存（**清单与 APK 两条都要刷**，只刷清单会指向新版本但 APK 仍是 CDN 旧文件）：
   ```bash
   aliyun cdn RefreshObjectCaches --profile user-server \
     --ObjectPath "https://oss.lliyuu520.cn/apk/version.json" --ObjectType File
   aliyun cdn RefreshObjectCaches --profile user-server \
     --ObjectPath "https://oss.lliyuu520.cn/apk/<日期>/poem_quiz_<ver>_<code>.apk" --ObjectType File
   ```

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

## 英语与拼音音频

朗读音频**不在 APK 里**，由百炼 `qwen-audio-3.1-tts-plus`（音色 `longanfengyue_v3.1`）预生成后
放 OSS 私有 bucket `lliyuu-shi`（前缀 `shi-private/`），经 CDN `media.lliyuu520.cn` 同账号私有回源，
首次播放时按条目下载到本地缓存，之后离线。英语与拼音共用一条下载/播放链路（`lib/data/speech_audio.dart`）。

- 英语：`shi-private/en/v2/`，键 `letter_<x>` / `sentence_<NN>`
- 拼音：`shi-private/pinyin/v2/`，键按字词 UTF-16 编码生成

**换音色或同名修正必须顺延版本段**（v2 → v3）：CDN 对 `.opus` 缓存一年、手机按 key 永久缓存，
同名覆盖两边都不生效（修正类覆盖还要单独刷对应 URL 的 CDN）。

加词或改题库后（英语）：

1. `python -I tool/gen_english.py --audio`（合成缺失的音频并生成 manifest，API Key 只走 stdin）
2. `python -I tool/verify_english_audio.py`（ASR 全量校验，不通过就别上传）
3. 上传 `assets/audio/en/` 到 `shi-private/en/v2/`

拼音题库与音频由 `tool/gen_pinyin.py`（`--audio`）生成与合成，上传 `shi-private/pinyin/v2/`，
校验用 `python -I tool/verify_pinyin_audio.py`。

## keystore

- 位置 `D:/tools/keys/poem_quiz.keystore`，密码在 `D:/tools/keys/poem_quiz_pwd.txt`
- **丢失 = 无法覆盖安装，只能卸载重装丢存档**，务必备份这两份
- `android/keystore.properties` 不入库；缺失时回落 debug 签名
