"""重写 AndroidManifest.xml（检查更新所需的权限与 FileProvider）。

一次性脚本：manifest 在此前被多次截断，用本脚本保存完整内容并恢复。
"""

HEAD = (
    '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <!-- 默认离线；仅设置页手动「检查更新」时联网（下载版本清单与新 APK）。 -->\n'
    '    <uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <application\n'
    '        android:label="诗词问答"\n'
    '        android:name="${applicationName}"\n'
    '        android:icon="@mipmap/ic_launcher">\n'
    '        <activity\n'
    '            android:name=".MainActivity"\n'
    '            android:exported="true"\n'
    '            android:launchMode="singleTop"\n'
    '            android:taskAffinity=""\n'
    '            android:theme="@style/LaunchTheme"\n'
    '            android:configChanges="orientation|keyboardHidden|keyboard|screenSize'
    '|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"\n'
    '            android:hardwareAccelerated="true"\n'
    '            android:windowSoftInputMode="adjustResize">\n'
    '            <meta-data\n'
    '              android:name="io.flutter.embedding.android.NormalTheme"\n'
    '              android:resource="@style/NormalTheme"\n'
    '              />\n'
    '            <intent-filter>\n'
    '                <action android:name="android.intent.action.MAIN"/>\n'
    '                <category android:name="android.intent.category.LAUNCHER"/>\n'
)

TAIL = (
    '            </intent-filter>\n'
    '        </activity>\n'
    '        <!-- Flutter 工具用它生成 GeneratedPluginRegistrant，不要删。 -->\n'
    '        <meta-data\n'
    '            android:name="flutterEmbedding"\n'
    '            android:value="2" />\n'
    '\n'
    '        <!-- 检查更新：把缓存目录的 APK 交给系统安装器。 -->\n'
    '        <provider\n'
    '            android:name="androidx.core.content.FileProvider"\n'
    '            android:authorities="${applicationId}.fileprovider"\n'
    '            android:exported="false"\n'
    '            android:grantUriPermissions="true">\n'
    '            <meta-data\n'
    '                android:name="android.support.FILE_PROVIDER_PATHS"\n'
    '                android:resource="@xml/file_paths"/>\n'
    '        </provider>\n'
    '    </application>\n'
    '    <queries>\n'
    '        <intent>\n'
    '            <action android:name="android.intent.action.PROCESS_TEXT"/>\n'
    '            <data android:mimeType="text/plain"/>\n'
    '        </intent>\n'
    '    </queries>\n'
    '</manifest>\n'
)

with open('android/app/src/main/AndroidManifest.xml', 'w', encoding='utf-8', newline='\n') as f:
    f.write(HEAD + TAIL)
print('manifest rewritten:', len(HEAD) + len(TAIL), 'chars')

